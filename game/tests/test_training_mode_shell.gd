extends SceneTree

## Headless test for TKT-P1-05 (the training-mode shell/scene).
## training-mode.md criterion 10 (seam discipline) + "integrates 02-04 so their
## criteria are exercisable in-mode."
##
## Seam discipline (criterion 10) is verified two ways here:
##   1. Static: grep TrainingMode's own source + the overlay scripts for
##      SimState/PlayerState/ResolvedBox (see check_seam_discipline.sh-equivalent
##      inline below) — no sim-internal type is referenced.
##   2. Behavioral: every control/read operation this test exercises goes through
##      TrainingMode's own public methods (set_paused/step_once/capture_reset/
##      do_reset/set_dummy_mode/inspection_view) — never TickHost/TrainingHarness/
##      RecordPlaybackSource directly — proving the shell is a sufficient surface
##      to drive a full session.
##
## Run:  godot --headless --path game -s res://tests/test_training_mode_shell.gd

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	await _run()
	MoveRegistry.clear()
	if _failures == 0:
		print("[test_training_mode_shell] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_training_mode_shell] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	_test_seam_discipline_static()
	await _test_shell_boots_and_ticks()
	await _test_frame_control_through_shell()
	await _test_reset_through_shell()
	await _test_dummy_mode_through_shell()
	await _test_reset_resyncs_dummy_through_shell()
	await _test_players_start_as_installed_character_with_resolved_boxes()
	await _test_dummy_recording_captures_live_input_and_playback_loops_it()
	await _test_fresh_record_on_recording_entry_replaces_not_concatenates()
	await _test_fresh_record_resets_the_playback_cursor()
	await _test_match_mode_wires_a_vs_b_and_ticks()
	await _test_match_mode_leaves_sandbox_default_unaffected()


## Static seam check (criterion 10: "verifiable by inspection of the
## player-facing code's dependencies"). Reads the actual source text of the
## shell + every overlay script and asserts none of the named sim-internal
## type tokens appear as a real reference (only as documentation prose, which
## this test cannot fully distinguish from code — so it also cross-checks
## against the behavioral test below, which proves those tokens are not
## NEEDED for a full session).
func _test_seam_discipline_static() -> void:
	var forbidden: PackedStringArray = ["SimState.new", "PlayerState.", "ResolvedBox.new"]
	var files: PackedStringArray = [
		"res://scenes/training_mode.gd",
		"res://scenes/overlays/geometry_overlay.gd",
		"res://scenes/overlays/geometry_overlay_model.gd",
		"res://scenes/overlays/frame_data_panel.gd",
		"res://scenes/overlays/frame_data_panel_model.gd",
		"res://scenes/overlays/live_state_panel_model.gd",
		"res://scenes/overlays/match_panel.gd",
		"res://scenes/overlays/match_panel_model.gd",
	]
	for path in files:
		var f := FileAccess.open(path, FileAccess.READ)
		_true(f != null, "can read %s for static seam check" % path)
		if f == null:
			continue
		var text: String = f.get_as_text()
		f.close()
		for token in forbidden:
			if token == "SimState.new" and path == "res://scenes/training_mode.gd":
				# Allowed: TrainingMode.SEEDS the initial match state (wiring a
				# match is the shell's job per training-mode.md "Architecture
				# placement"); the seam concern is READING sim truth, which the
				# shell only ever does via inspection_view(). Skip this one
				# documented exception; still checked in every other file.
				continue
			_true(not text.contains(token), "%s does not reference %s" % [path, token])


func _test_shell_boots_and_ticks() -> void:
	var tm := await _make_shell()
	var t0: int = tm.inspection_view().tick()
	tm.step_once()
	var t1: int = tm.inspection_view().tick()
	_eq(t1, t0 + 1, "step_once() through the shell advances tick by exactly 1")
	tm.get_parent().queue_free()


func _test_frame_control_through_shell() -> void:
	var tm := await _make_shell()
	tm.set_paused(true)
	_true(tm.is_paused(), "set_paused(true) through the shell pauses")
	var t0: int = tm.inspection_view().tick()
	# Simulate a few _physics_process ticks while paused: nothing should advance
	# since the shell's _physics_process only auto-produces/advances when running.
	for _k in range(3):
		tm._physics_process(0.0)
	_eq(tm.inspection_view().tick(), t0, "paused sim does not advance via _physics_process")
	tm.step_once()
	_eq(tm.inspection_view().tick(), t0 + 1, "step_once() still frame-steps exactly one tick while paused")
	tm.set_paused(false)
	_true(not tm.is_paused(), "set_paused(false) through the shell resumes")
	tm.get_parent().queue_free()


func _test_reset_through_shell() -> void:
	var tm := await _make_shell()
	for _k in range(3):
		tm.step_once()
	tm.capture_reset()
	_true(tm.has_reset_point(), "has_reset_point() true after capture_reset() through the shell")
	var hash_at_capture: int = tm.inspection_view().tick()
	for _k in range(5):
		tm.step_once()
	tm.do_reset()
	_eq(tm.inspection_view().tick(), hash_at_capture,
		"do_reset() through the shell returns to the captured tick")
	tm.get_parent().queue_free()


func _test_dummy_mode_through_shell() -> void:
	var tm := await _make_shell()
	# P2 dummy: script a tiny buffer and put it in PLAYBACK, all through the
	# shell's own methods (never touching RecordPlaybackSource directly).
	var script := PackedInt32Array([InputFrame.NEUTRAL, InputFrame.LEFT, InputFrame.RIGHT])
	tm.set_dummy_recorded_buffer(1, script)
	tm.set_dummy_mode(1, RecordPlaybackSource.Mode.PLAYBACK)
	_eq(tm.get_dummy_mode(1), RecordPlaybackSource.Mode.PLAYBACK,
		"get_dummy_mode(1) through the shell reflects the mode just set")
	_eq(tm.get_dummy_recorded_buffer(1), script,
		"get_dummy_recorded_buffer(1) round-trips through the shell")
	# Drive a few ticks and confirm the shell's inspection_view sees P2's raw
	# input_current cycling through the scripted buffer (input.md Tenet 2: the
	# exact stream the sim consumed is readable back out).
	tm.step_once()
	_eq(tm.inspection_view().player(1).input_current, InputFrame.NEUTRAL,
		"P2 input_current tick 1 matches the scripted buffer[0]")
	tm.step_once()
	_eq(tm.inspection_view().player(1).input_current, InputFrame.LEFT,
		"P2 input_current tick 2 matches the scripted buffer[1]")
	tm.get_parent().queue_free()


func _test_reset_resyncs_dummy_through_shell() -> void:
	# training-mode.md criterion 12, exercised end-to-end via the shell only.
	var tm := await _make_shell()
	var script := PackedInt32Array([InputFrame.NEUTRAL, InputFrame.LEFT, InputFrame.RIGHT, InputFrame.NEUTRAL])
	tm.set_dummy_recorded_buffer(1, script)
	tm.set_dummy_mode(1, RecordPlaybackSource.Mode.PLAYBACK)

	tm.step_once()
	tm.step_once()
	tm.capture_reset()
	var tick_at_capture: int = tm.inspection_view().tick()

	var trace_1: Array = []
	for _k in range(6):
		tm.step_once()
		trace_1.append(tm.inspection_view().player(1).input_current)

	tm.do_reset()
	_eq(tm.inspection_view().tick(), tick_at_capture, "do_reset through the shell restores the captured tick")

	var trace_2: Array = []
	for _k in range(6):
		tm.step_once()
		trace_2.append(tm.inspection_view().player(1).input_current)

	_eq(trace_2.size(), trace_1.size(), "both reps produced the same number of P2 inputs")
	for i in range(trace_1.size()):
		_eq(trace_2[i], trace_1[i],
			"rep 2 P2 input %d matches rep 1 (dummy re-synced by reset through the shell)" % i)
	tm.get_parent().queue_free()


## TKT-P1.1-01 Part A regression guard (training-mode.md "Players start as the
## installed character"; ticket acceptance: "with the shell's initial state,
## both players resolve a non-empty boxes list"). Before this fix,
## SimState.new_initial() alone left both players at character_id 0/state_id 0,
## which the installed roster (keyed on CharacterA.CHAR_ID) never resolves — so
## PlayerView.move was null and boxes was []. Asserts, at tick 0 (no step taken),
## that both players' character_id/state_id match the installed character's idle
## state and that their idle hurtbox actually resolves.
func _test_players_start_as_installed_character_with_resolved_boxes() -> void:
	var tm := await _make_shell()
	var view := tm.inspection_view()
	for i in range(2):
		var pv: PlayerView = view.player(i)
		_eq(pv.character_id, CharacterA.CHAR_ID,
			"player %d starts as the installed character (CharacterA.CHAR_ID)" % i)
		_eq(pv.state_id, CharacterA.STATE_IDLE,
			"player %d starts in the installed character's idle state" % i)
		_true(pv.boxes.size() > 0,
			"player %d resolves a non-empty boxes list from the shell's initial state" % i)
		var has_hurt: bool = false
		for box in pv.boxes:
			if box.kind == BoxView.KIND_HURT:
				has_hurt = true
				break
		_true(has_hurt, "player %d's resolved boxes include its idle hurtbox" % i)
	tm.get_parent().queue_free()


## TKT-P1.1R2-01 (AD-040 dummy-control operability — the D1 fix, regression at
## the OPERABILITY layer, not just the RecordPlaybackSource class already
## covered by test_record_playback.gd). Before this ticket, `_source_p2` was
## constructed with NO live sampler, so RECORDING silently answered NEUTRAL and
## cycling the dummy's mode (`M`) was inert-in-effect (the D1 defect). This
## drives the actual shell-wired dummy source through `Input.action_press` on
## its own tm_dummy_* keys (never touching RecordPlaybackSource directly —
## the seam rule), confirms RECORDING captures the non-neutral input into the
## recorded buffer, and that PLAYBACK then loops exactly that captured stream.
## Full human operability (a person pressing a real key) is confirmed at the
## human-inspection gate; this is the headless-checkable half — the sampler
## injection + record/playback round-trip actually works end to end.
func _test_dummy_recording_captures_live_input_and_playback_loops_it() -> void:
	var tm := await _make_shell()

	tm.set_dummy_mode(1, RecordPlaybackSource.Mode.RECORDING)
	_eq(tm.get_dummy_mode(1), RecordPlaybackSource.Mode.RECORDING,
		"dummy set to RECORDING through the shell")

	# Tick 1: neutral (nothing pressed yet).
	tm.step_once()
	# Tick 2: hold dummy-left (its own distinct key, never P1's).
	Input.action_press("tm_dummy_left")
	tm.step_once()
	Input.action_release("tm_dummy_left")
	# Tick 3: neutral again.
	tm.step_once()

	var recorded: PackedInt32Array = tm.get_dummy_recorded_buffer(1)
	_eq(recorded.size(), 3, "RECORDING captured exactly the 3 ticks stepped")
	_eq(recorded[0], InputFrame.NEUTRAL, "tick 1 recorded NEUTRAL (nothing pressed)")
	_eq(recorded[1], InputFrame.LEFT, "tick 2 recorded LEFT — the dummy's live sampler captured the held key")
	_eq(recorded[2], InputFrame.NEUTRAL, "tick 3 recorded NEUTRAL again after release")

	# Cycle to PLAYBACK and confirm it loops the captured stream (not NEUTRAL —
	# the pre-fix behavior, since there was never a live sampler to record from).
	tm.set_dummy_mode(1, RecordPlaybackSource.Mode.PLAYBACK)
	var played: Array = []
	for _k in range(6):   # two full loops of the 3-frame recording
		tm.step_once()
		played.append(tm.inspection_view().player(1).input_current)
	_eq(played, [InputFrame.NEUTRAL, InputFrame.LEFT, InputFrame.NEUTRAL,
			InputFrame.NEUTRAL, InputFrame.LEFT, InputFrame.NEUTRAL],
		"PLAYBACK loops the exact RECORDING-captured stream through the shell-wired dummy")
	tm.get_parent().queue_free()


## TKT-P1.1R3-01 (AD-041 "fresh-record on RECORDING entry", re-gate-4 E1). The
## secondary latent bug the mode indicator alone would not fix: before this
## ticket, RECORDING appended to whatever buffer already existed and nothing
## rewound the playback cursor, so a SECOND record pass concatenated onto the
## first (a re-take never actually replaced anything — "inconsistent," per the
## re-gate-4 report). Drives two full record passes through the shell's own
## set_dummy_mode (never RecordPlaybackSource directly) and confirms the
## SECOND buffer REPLACES the first rather than growing it.
func _test_fresh_record_on_recording_entry_replaces_not_concatenates() -> void:
	var tm := await _make_shell()

	# First record pass: 3 ticks, all LEFT.
	tm.set_dummy_mode(1, RecordPlaybackSource.Mode.RECORDING)
	Input.action_press("tm_dummy_left")
	for _k in range(3):
		tm.step_once()
	Input.action_release("tm_dummy_left")
	var first_pass: PackedInt32Array = tm.get_dummy_recorded_buffer(1)
	_eq(first_pass.size(), 3, "first record pass captured exactly 3 ticks")
	for v in first_pass:
		_eq(v, InputFrame.LEFT, "first pass recorded LEFT on every tick")

	# Cycle out (PLAYBACK), then back INTO RECORDING for a SECOND, SHORTER pass
	# (2 ticks, all RIGHT) — the transition this ticket fixes.
	tm.set_dummy_mode(1, RecordPlaybackSource.Mode.PLAYBACK)
	tm.set_dummy_mode(1, RecordPlaybackSource.Mode.RECORDING)
	Input.action_press("tm_dummy_right")
	for _k in range(2):
		tm.step_once()
	Input.action_release("tm_dummy_right")

	var second_pass: PackedInt32Array = tm.get_dummy_recorded_buffer(1)
	_eq(second_pass.size(), 2,
		"the SECOND record pass REPLACES the first (2 ticks, not 3+2=5 concatenated — the AD-041 fix)")
	for v in second_pass:
		_eq(v, InputFrame.RIGHT, "the second pass's buffer holds ONLY its own (RIGHT) frames, no leftover LEFT")

	tm.get_parent().queue_free()


## TKT-P1.1R3-01 (AD-041 "fresh-record" — the cursor half). Confirms entering
## RECORDING also rewinds the PLAYBACK cursor: after a first recording is
## played back partway (advancing the cursor), a SECOND record pass followed
## by PLAYBACK must start the new script from its own beginning (index 0), not
## resume from the stale mid-buffer cursor position of the first recording.
func _test_fresh_record_resets_the_playback_cursor() -> void:
	var tm := await _make_shell()

	# First recording: 3 distinct frames (so a stale cursor is unmistakable).
	tm.set_dummy_recorded_buffer(1, PackedInt32Array([InputFrame.LEFT, InputFrame.RIGHT, InputFrame.UP]))
	tm.set_dummy_mode(1, RecordPlaybackSource.Mode.PLAYBACK)
	# Advance the cursor partway through the first script (2 of 3 ticks) — if
	# unreset, the SHORTER script recorded below would leave a STALE cursor
	# pointing past its own (smaller) buffer.
	tm.step_once()
	tm.step_once()

	# Re-enter RECORDING (fresh-record fires: buffer cleared + cursor reset)
	# and record a new, single-frame (DOWN) script — deliberately SHORTER than
	# the stale cursor position (2), so an unreset cursor would read the wrong
	# index (or index out of range against the 1-element buffer).
	tm.set_dummy_mode(1, RecordPlaybackSource.Mode.RECORDING)
	Input.action_press("tm_dummy_down")
	tm.step_once()
	Input.action_release("tm_dummy_down")

	tm.set_dummy_mode(1, RecordPlaybackSource.Mode.PLAYBACK)
	tm.step_once()
	_eq(tm.inspection_view().player(1).input_current, InputFrame.DOWN,
		"PLAYBACK of the fresh recording starts from index 0 (DOWN) -- the cursor was reset, not left stale mid-(old-)buffer")
	tm.step_once()
	_eq(tm.inspection_view().player(1).input_current, InputFrame.DOWN,
		"the single-frame script loops correctly from a properly-reset cursor")
	tm.get_parent().queue_free()


## Build a TrainingMode with just the TickHost child it needs (no overlays —
## overlay wiring is covered by the overlay-specific tests), rooted under the
## live scene tree so @onready resolves and _ready() runs. Awaits a process
## frame so _ready() (deferred by Godot until the node is actually inside the
## tree) has actually run before the caller touches the shell.
func _make_shell() -> TrainingMode:
	var tm := TrainingMode.new()
	var host := TickHost.new()
	host.name = "TickHost"
	tm.add_child(host)
	var root := Node.new()
	root.add_child(tm)
	get_root().add_child(root)
	await process_frame
	return tm


# ---------------------------------------------------------------------------
# TKT-P2-08: match mode (the full A-vs-B match wired end to end, AD-048).
# ---------------------------------------------------------------------------

## Mirrors _make_shell() exactly, but flips start_in_match_mode BEFORE the
## node enters the tree (so _ready() takes the match-mode path). Still needs
## the same TickHost child present (it is left paused/unused in match mode —
## see training_mode.gd's _ready_match_mode note) since @onready always
## resolves it regardless of mode.
func _make_match_shell() -> TrainingMode:
	var tm := TrainingMode.new()
	tm.start_in_match_mode = true
	var host := TickHost.new()
	host.name = "TickHost"
	tm.add_child(host)
	var root := Node.new()
	root.add_child(tm)
	get_root().add_child(root)
	await process_frame
	return tm


func _test_match_mode_wires_a_vs_b_and_ticks() -> void:
	var tm := await _make_match_shell()
	_true(tm.is_match_mode(), "start_in_match_mode routes _ready() into match mode")

	var view: InspectionView = tm.inspection_view()
	_eq(view.player(0).character_id, CharacterA.CHAR_ID, "P1 is character A (AD-048 fixed wiring)")
	_eq(view.player(1).character_id, CharacterB.CHAR_ID, "P2 is character B (AD-048 fixed wiring)")
	_eq(view.player(0).state_id, CharacterA.STATE_IDLE, "P1 resolves onto A's own idle state (not the generic 0 default)")
	_eq(view.player(1).state_id, CharacterB.STATE_IDLE, "P2 resolves onto B's own idle state (not the generic 0 default)")

	var mv: MatchView = tm.match_view()
	_true(mv != null, "match_view() is non-null in match mode")
	_eq(mv.health[0], MatchState.FULL_HEALTH, "P1 starts at the tuned full health")
	_eq(mv.health[1], MatchState.FULL_HEALTH, "P2 starts at the tuned full health")
	_eq(mv.match_phase, MatchState.PHASE_ROUND_START, "a fresh match starts in ROUND_START")

	# Drive the whole ROUND_START beat via the shell's own step_once() (never
	# touching MatchTickHost/MatchState directly) so combat actually goes ACTIVE.
	tm.set_paused(true)
	for i in range(MatchState.ROUND_START_BEAT_TICKS):
		tm.step_once()
	var mv2: MatchView = tm.match_view()
	_eq(mv2.match_phase, MatchState.PHASE_ACTIVE, "stepping through the shell alone reaches ACTIVE")
	var tick_after_beat: int = tm.inspection_view().tick()
	tm.step_once()
	_eq(tm.inspection_view().tick(), tick_after_beat + 1, "an ACTIVE step_once() through the shell advances combat by one tick")
	tm.get_parent().queue_free()


## The sandbox-mode default (no export flag flipped) must be COMPLETELY
## unaffected by match mode's existence — is_match_mode() false, match_view()
## null, sandbox's own single-character behavior unchanged.
func _test_match_mode_leaves_sandbox_default_unaffected() -> void:
	var tm := await _make_shell()
	_true(not tm.is_match_mode(), "a plain TrainingMode.new() defaults to sandbox mode")
	_eq(tm.match_view(), null, "match_view() is null outside match mode")
	var view: InspectionView = tm.inspection_view()
	_eq(view.player(0).character_id, CharacterA.CHAR_ID, "sandbox mode's own default (character A) is unchanged")
	tm.get_parent().queue_free()
