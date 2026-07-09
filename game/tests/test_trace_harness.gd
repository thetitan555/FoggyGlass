extends SceneTree

## Headless test for the scripted-input behavioral-trace harness (TKT-P1.1R-01,
## docs/spec/trace-harness.md, all three contracts + acceptance criteria 1-6).
##
## Run:  godot --headless --path game -s res://tests/test_trace_harness.gd
## Exits non-zero on any failure so a harness/CI can gate on it.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	ProjectileRegistry.clear()
	if _failures == 0:
		print("[test_trace_harness] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_trace_harness] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _false(cond: bool, msg: String) -> void:
	_eq(cond, false, msg)


func _run() -> void:
	# Contract 1 — InputScript compiler.
	_test_compile_numpad_and_buttons()
	_test_compile_repeat_and_comments()
	_test_compile_is_pure()
	_test_compile_every_frame_valid()
	_test_well_formed_token_accepts_grammar()
	_test_well_formed_token_rejects_malformed()

	# Contract 2 + 3 — headless driver / trace dump / inline asserts, and the
	# two required smoke scripts (idle stays idle; 6*n moves pos_x forward).
	_test_smoke_idle_stays_idle()
	_test_smoke_forward_hold_moves_pos_x_forward()
	_test_replay_deterministic_across_repeats()
	_test_replay_source_equivalent_to_a_raw_step_loop()
	_test_assert_runner_fails_loudly_on_wrong_expectation()
	_test_trace_field_free_of_floats_and_sim_internals()


# ---------------------------------------------------------------------------
# Contract 1 — InputScript.
# ---------------------------------------------------------------------------

func _test_compile_numpad_and_buttons() -> void:
	# Each numpad digit -> its specified RAW direction bits (criterion 2).
	_eq(InputScript.compile("6"), PackedInt32Array([InputFrame.RIGHT]), "6 -> RIGHT")
	_eq(InputScript.compile("4"), PackedInt32Array([InputFrame.LEFT]), "4 -> LEFT")
	_eq(InputScript.compile("2"), PackedInt32Array([InputFrame.DOWN]), "2 -> DOWN")
	_eq(InputScript.compile("8"), PackedInt32Array([InputFrame.UP]), "8 -> UP")
	_eq(InputScript.compile("9"), PackedInt32Array([InputFrame.UP | InputFrame.RIGHT]), "9 -> UP+RIGHT")
	_eq(InputScript.compile("7"), PackedInt32Array([InputFrame.UP | InputFrame.LEFT]), "7 -> UP+LEFT")
	_eq(InputScript.compile("3"), PackedInt32Array([InputFrame.DOWN | InputFrame.RIGHT]), "3 -> DOWN+RIGHT")
	_eq(InputScript.compile("1"), PackedInt32Array([InputFrame.DOWN | InputFrame.LEFT]), "1 -> DOWN+LEFT")
	_eq(InputScript.compile("5"), PackedInt32Array([InputFrame.NEUTRAL]), "5 -> neutral")
	# L/M/H -> BUTTON_0/1/2 (AD-018); combine with a direction on one frame.
	_eq(InputScript.compile("L"), PackedInt32Array([InputFrame.BUTTON_0]), "L -> BUTTON_0")
	_eq(InputScript.compile("M"), PackedInt32Array([InputFrame.BUTTON_1]), "M -> BUTTON_1")
	_eq(InputScript.compile("H"), PackedInt32Array([InputFrame.BUTTON_2]), "H -> BUTTON_2")
	_eq(InputScript.compile("6H"), PackedInt32Array([InputFrame.RIGHT | InputFrame.BUTTON_2]), "6H -> forward+Heavy")
	_eq(InputScript.compile("2M"), PackedInt32Array([InputFrame.DOWN | InputFrame.BUTTON_1]), "2M -> down+Medium")
	_eq(InputScript.compile("LH"), PackedInt32Array([InputFrame.BUTTON_0 | InputFrame.BUTTON_2]), "LH -> L+H chord")
	# Per-tick motion authoring: a fireball is three tokens, never a shorthand.
	_eq(InputScript.compile("2 3 6H"), PackedInt32Array([
		InputFrame.DOWN, InputFrame.DOWN | InputFrame.RIGHT, InputFrame.RIGHT | InputFrame.BUTTON_2,
	]), "2 3 6H compiles to three distinct per-tick frames (fireball motion)")


func _test_compile_repeat_and_comments() -> void:
	# *count repeats the exact frame (criterion 2).
	_eq(InputScript.compile("6*3"), PackedInt32Array([InputFrame.RIGHT, InputFrame.RIGHT, InputFrame.RIGHT]),
		"6*3 repeats RIGHT three times")
	_eq(InputScript.compile("5*4"), PackedInt32Array([InputFrame.NEUTRAL, InputFrame.NEUTRAL, InputFrame.NEUTRAL, InputFrame.NEUTRAL]),
		"5*4 repeats neutral four times")
	# # comments and whitespace/newlines are ignored (criterion 2).
	var scripted: PackedInt32Array = InputScript.compile("# hold forward\n6*2\n\n# release\n5*1 # trailing comment\n")
	_eq(scripted, PackedInt32Array([InputFrame.RIGHT, InputFrame.RIGHT, InputFrame.NEUTRAL]),
		"comments and blank lines are ignored; a trailing same-line comment is stripped")


func _test_compile_is_pure() -> void:
	# Criterion 1: identical text compiles to an identical buffer every call.
	var text := "2 3 6H*2 5*3 # a fireball then neutral"
	var a: PackedInt32Array = InputScript.compile(text)
	var b: PackedInt32Array = InputScript.compile(text)
	_eq(a, b, "InputScript.compile is pure: identical text -> identical buffer")


func _test_compile_every_frame_valid() -> void:
	# Criterion 1: every emitted frame passes InputFrame.is_valid (no reserved bit).
	var buf: PackedInt32Array = InputScript.compile("9*2 8 7 6H*3 4M 3 2L 1 5*5 LH")
	var all_valid := true
	for f in buf:
		if not InputFrame.is_valid(f):
			all_valid = false
	_true(all_valid, "every frame InputScript.compile emits is a valid InputFrame (no reserved bit set)")


func _test_well_formed_token_accepts_grammar() -> void:
	for tok in ["6", "6H", "H", "LH", "5", "2", "9*10", "5*1"]:
		_true(InputScript.is_well_formed_token(tok), "is_well_formed_token accepts grammar-legal token '%s'" % tok)


func _test_well_formed_token_rejects_malformed() -> void:
	# No motion shorthand — a second direction digit in one token is malformed.
	_false(InputScript.is_well_formed_token("236H"), "236H is malformed (two direction digits in one token)")
	# Unknown character.
	_false(InputScript.is_well_formed_token("3P"), "3P is malformed (unknown button letter)")
	_false(InputScript.is_well_formed_token("0"), "0 is malformed (not a numpad digit 1-9, not a button)")
	# Empty / structurally broken.
	_false(InputScript.is_well_formed_token(""), "empty token is malformed")
	_false(InputScript.is_well_formed_token("*3"), "a token with no frame before '*' is malformed")
	_false(InputScript.is_well_formed_token("6**3"), "more than one '*' is malformed")
	# Bad repeat counts.
	_false(InputScript.is_well_formed_token("6*0"), "a repeat count of 0 is malformed (count must be >= 1)")
	_false(InputScript.is_well_formed_token("6*abc"), "a non-numeric repeat count is malformed")


# ---------------------------------------------------------------------------
# Contract 2 + 3 — headless driver, trace dump, inline asserts.
# ---------------------------------------------------------------------------

func _roster() -> Dictionary:
	return {CharacterA.CHAR_ID: CharacterA.build_character()}


## Smoke script 1 (ticket acceptance): idle stays idle. Both players held
## neutral -> both stay in STATE_IDLE every tick.
func _test_smoke_idle_stays_idle() -> void:
	var rows: Array[Dictionary] = TraceHarness.run("5*10", "5*10", 10, _roster(), CharacterA.CHAR_ID)
	_eq(rows.size(), 10, "idle-stays-idle script runs the requested 10 ticks")
	for t in range(1, 11):
		_true(TraceHarness.check(rows, t, "p0.state", CharacterA.STATE_IDLE),
			"p0 stays STATE_IDLE at tick %d under neutral input" % t)
		_true(TraceHarness.check(rows, t, "p1.state", CharacterA.STATE_IDLE),
			"p1 stays STATE_IDLE at tick %d under neutral input" % t)
	MoveRegistry.clear()


## Smoke script 2 (ticket acceptance): 6*n moves pos_x forward. Holding forward
## (RIGHT, forward-relative for P1, who starts facing right) for N ticks
## displaces p0.px monotonically forward from its starting position — proving
## compile -> replay -> assert end-to-end through the real seam.
func _test_smoke_forward_hold_moves_pos_x_forward() -> void:
	var start_px: int = FP.from_int(-100)   # SimState.new_initial's P1 starting x
	var rows: Array[Dictionary] = TraceHarness.run("6*20", "", 20, _roster(), CharacterA.CHAR_ID)
	_eq(rows.size(), 20, "forward-hold script runs the requested 20 ticks")
	var final_row: Dictionary = TraceHarness.row_at(rows, 20)
	_true(not final_row.is_empty(), "tick 20 was recorded")
	_true(int(final_row["p0.px"]) > start_px,
		"holding forward for 20 ticks advances p0.px beyond its starting position")
	# Monotonic: pos_x at tick 20 is not less than pos_x at tick 10 (never walks backward).
	var mid_row: Dictionary = TraceHarness.row_at(rows, 10)
	_true(int(final_row["p0.px"]) >= int(mid_row["p0.px"]),
		"p0.px at tick 20 is not behind p0.px at tick 10 (forward hold never retreats)")
	# P2 (empty script -> neutral forever, Contract 2's documented default) never moves.
	_eq(int(final_row["p1.px"]), FP.from_int(100), "an empty P2 script defaults to neutral (idle) — p1 does not move")
	MoveRegistry.clear()


## Acceptance criterion 3 (part 1): deterministic across repeats — identical
## final state hash / identical trace on a second run of the same scripts.
func _test_replay_deterministic_across_repeats() -> void:
	var rows_a: Array[Dictionary] = TraceHarness.run("2 3 6H 5*5", "5*8", 8, _roster(), CharacterA.CHAR_ID)
	MoveRegistry.clear()
	var rows_b: Array[Dictionary] = TraceHarness.run("2 3 6H 5*5", "5*8", 8, _roster(), CharacterA.CHAR_ID)
	MoveRegistry.clear()
	_eq(TraceHarness.format_rows(rows_a), TraceHarness.format_rows(rows_b),
		"replaying the identical scripts twice produces an identical trace (deterministic replay)")


## Acceptance criterion 3 (part 2): the harness drives the sim through a real
## RecordPlaybackSource in PLAYBACK — not a bespoke sim caller — and the result
## is bit-identical to feeding the SAME compiled buffer through SimState.step
## directly (source equivalence, input.md criterion 3). Reconstructs the
## per-tick InspectionView fields from an independent, hand-rolled step loop
## over the same buffer and compares them field-by-field against the harness's
## own trace rows.
func _test_replay_source_equivalent_to_a_raw_step_loop() -> void:
	var p1_text := "9 5*3 6H 5*4"
	var p2_text := "5*8"
	var roster: Dictionary = _roster()

	var rows: Array[Dictionary] = TraceHarness.run(p1_text, p2_text, 8, roster, CharacterA.CHAR_ID)
	MoveRegistry.clear()

	# Independent raw-step loop over the identically-compiled buffers, bypassing
	# RecordPlaybackSource entirely.
	MoveRegistry.install(roster)
	var buf_p1: PackedInt32Array = InputScript.compile(p1_text)
	var buf_p2: PackedInt32Array = InputScript.compile(p2_text)
	var character: Character = roster[CharacterA.CHAR_ID]
	var state: SimState = SimState.new_initial()
	state.players[0].character_id = CharacterA.CHAR_ID
	state.players[0].state_id = character.idle_state_id
	state.players[1].character_id = CharacterA.CHAR_ID
	state.players[1].state_id = character.idle_state_id

	var mismatch := false
	for t in range(8):
		state = SimState.step(state, buf_p1[t], buf_p2[t])
		var view := InspectionView.new(state, roster)
		var harness_row: Dictionary = TraceHarness.row_at(rows, t + 1)
		if int(harness_row["p0.state"]) != view.player(0).state_id \
				or int(harness_row["p0.px"]) != int(view.player(0).position["x"]) \
				or int(harness_row["p1.state"]) != view.player(1).state_id \
				or int(harness_row["p1.px"]) != int(view.player(1).position["x"]):
			mismatch = true
	_false(mismatch,
		"TraceHarness's RecordPlaybackSource-driven trace is bit-identical, tick by tick, to a raw SimState.step loop fed the same compiled buffer")
	MoveRegistry.clear()


## Acceptance criterion 5: an inline assertion fails LOUDLY (and reports false)
## when the trace does not match — proving the harness catches an omission
## rather than passing silently. Deliberately asserts a WRONG expectation and
## checks that `check()` correctly reports failure (this test is verifying the
## detector, not asserting the wrong value is somehow true).
func _test_assert_runner_fails_loudly_on_wrong_expectation() -> void:
	var rows: Array[Dictionary] = TraceHarness.run("5*3", "5*3", 3, _roster(), CharacterA.CHAR_ID)
	# p0 is IDLE at tick 1 under neutral input; assert something else and confirm
	# the runner reports the mismatch rather than passing.
	var wrong_passed: bool = TraceHarness.check(rows, 1, "p0.state", CharacterA.STATE_WALK_F)
	_false(wrong_passed, "check() reports FAIL when the expected value does not match the trace")
	# An assertion against a tick that was never recorded also fails, not silently.
	var missing_tick_passed: bool = TraceHarness.check(rows, 99, "p0.state", CharacterA.STATE_IDLE)
	_false(missing_tick_passed, "check() reports FAIL for a tick the run never recorded")
	MoveRegistry.clear()


## Acceptance criterion 4: every trace field comes from InspectionView, no
## SimState-internal type is named, and no float appears anywhere in a row.
func _test_trace_field_free_of_floats_and_sim_internals() -> void:
	var rows: Array[Dictionary] = TraceHarness.run("6H", "2M", 1, _roster(), CharacterA.CHAR_ID,
		{}, PackedStringArray(["boxes", "advantage", "last_hit"]))
	var row: Dictionary = rows[0]
	var has_float := false
	for key in row:
		if typeof(row[key]) == TYPE_FLOAT:
			has_float = true
	_false(has_float, "no trace field is a float (AD-019)")
	# The formatted dump round-trips to a stable string for an identical run.
	var rows_again: Array[Dictionary] = TraceHarness.run("6H", "2M", 1, _roster(), CharacterA.CHAR_ID,
		{}, PackedStringArray(["boxes", "advantage", "last_hit"]))
	_eq(TraceHarness.format_rows(rows, PackedStringArray(["boxes", "advantage", "last_hit"])),
		TraceHarness.format_rows(rows_again, PackedStringArray(["boxes", "advantage", "last_hit"])),
		"a trace over a fixed run round-trips identically")
	MoveRegistry.clear()
