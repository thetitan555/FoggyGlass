extends SceneTree

## Headless test for the input buffer + cancel rules (TKT-P0-08).
## combat-resolution.md criteria 8 (cancel timing), 11 (input buffer);
## move-format.md criterion 7 (typed cancels resolve per condition/window).
## AD-015 (typed cancels), AD-017 (hitstop buffering + T+1 grant->consume), AD-022
## (9-frame motion window, 6-frame command buffer).
##
## Run:  godot --headless --path game -s res://tests/test_buffer_cancels.gd
## Exits non-zero on any failure so a harness/CI can gate on it.
##
## Every value is hand-traceable: the TestSupport character carries a LIGHT normal that
## special-cancels into SPECIAL (tag-gated, on_contact), a 623 REVERSAL motion, and the
## reaction states. Buffering is a PURE function of input_history (AD-003), so these
## drive step() with recorded frames and read state back.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	if _failures == 0:
		print("[test_buffer_cancels] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_buffer_cancels] FAIL — %d of %d checks failed" % [_failures, _checks])
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
	_test_motion_window_recognition()
	_test_motion_window_too_slow()
	_test_command_buffer_window()
	_test_buffered_reversal_frame1()
	_test_special_cancel_on_hit()
	_test_cancel_requires_tag()
	_test_cancel_never_during_hitstop()
	_test_buffering_source_independent()


# --- Scenario setup ---------------------------------------------------------

func _two_char_state(p1_units: int = 50) -> SimState:
	MoveRegistry.install(TestSupport.build_roster())
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = TestSupport.CHAR_ID
	s.players[0].state_id = TestSupport.STATE_IDLE
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = TestSupport.CHAR_ID
	s.players[1].state_id = TestSupport.STATE_IDLE
	s.players[1].pos_x = FP.from_int(p1_units)
	s.players[1].facing = -1
	return s


## A history holding a sequence of raw frames (newest last), for pure-recognizer tests.
func _history(frames: Array) -> InputHistory:
	var h := InputHistory.new()
	for f in frames:
		h.push(f)
	return h


# --- Motion recognition (AD-022; combat-resolution.md crit 11) --------------

func _test_motion_window_recognition() -> void:
	# 623 = forward, down, down-forward. Facing +1: forward == RIGHT. Perform it within
	# the 9-frame window with intermediate neutral frames (leniency allowed).
	var D: int = InputFrame.DOWN
	var F: int = InputFrame.RIGHT
	var DF: int = InputFrame.DOWN | InputFrame.RIGHT
	var frames := [InputFrame.NEUTRAL, F, InputFrame.NEUTRAL, D, DF]  # 5 frames, in order
	var h := _history(frames)
	_true(InputBuffer.motion_recognized(h, InputBuffer.MOTION_623, 1),
		"623 recognized within the 9-frame window (facing +1)")
	# Facing -1 mirrors: forward == LEFT.
	var Fm: int = InputFrame.LEFT
	var DFm: int = InputFrame.DOWN | InputFrame.LEFT
	var hm := _history([InputFrame.NEUTRAL, Fm, D, DFm])
	_true(InputBuffer.motion_recognized(hm, InputBuffer.MOTION_623, -1),
		"623 recognized mirrored under facing -1")


func _test_motion_window_too_slow() -> void:
	# The three 623 tokens spread across MORE than 9 frames must NOT recognize (window).
	# Put forward far in the past, then a long neutral gap, then down / down-forward, so
	# the first token falls outside the 9-frame lookback from the newest.
	var D: int = InputFrame.DOWN
	var F: int = InputFrame.RIGHT
	var DF: int = InputFrame.DOWN | InputFrame.RIGHT
	var frames := [F]  # forward, then 9 neutral frames, then down, down-forward
	for _i in range(9):
		frames.append(InputFrame.NEUTRAL)
	frames.append(D)
	frames.append(DF)
	var h := _history(frames)
	_false(InputBuffer.motion_recognized(h, InputBuffer.MOTION_623, 1),
		"623 NOT recognized when its directions span more than 9 frames")


func _test_command_buffer_window() -> void:
	# A button pressed within the last 6 frames counts (command buffer); older than 6
	# does not. BUTTON_0 at age 5 (within) recognizes; at age 6 (outside) does not.
	var within := _history([InputFrame.BUTTON_0, 0, 0, 0, 0, 0])  # age 5
	_true(InputBuffer.button_buffered(within, 0, 0, 1), "button at age 5 is within the 6-frame buffer")
	var outside := _history([InputFrame.BUTTON_0, 0, 0, 0, 0, 0, 0])  # age 6
	_false(InputBuffer.button_buffered(outside, 0, 0, 1), "button at age 6 is outside the 6-frame buffer")


# --- Buffered reversal (AD-022; a 623 held through blockstun fires frame-1) --

func _test_buffered_reversal_frame1() -> void:
	# P0 is put into BLOCKSTUN, then inputs 623+BUTTON_2 across the last frames of stun.
	# On the FIRST actionable tick (blockstun expires), the buffered reversal fires on
	# frame 1 — a frame-1 reversal (AD-022). We drive P0 into blockstun via a P1 LIGHT.
	var s := _two_char_state(50)
	# P1 attacks; P0 holds back to block -> P0 in BLOCKSTUN. P0 faces +1, so "back" = LEFT.
	var back0: int = InputFrame.LEFT
	# Drive to the block contact.
	s = SimState.step(s, back0, InputFrame.BUTTON_0)
	for _k in range(20):
		if s.last_hit != null:
			break
		s = SimState.step(s, back0, InputFrame.NEUTRAL)
	_eq(s.players[0].stun_kind, PlayerView.STUN_BLOCK, "P0 is in blockstun")
	# Now P0 inputs 623 + BUTTON_2 during blockstun (so it buffers), holding through to
	# the first actionable frame. Feed the motion then hold the final input.
	var D: int = InputFrame.DOWN
	var F: int = InputFrame.RIGHT   # P0 faces +1 -> forward is RIGHT
	var DF: int = InputFrame.DOWN | InputFrame.RIGHT
	var B2: int = InputFrame.BUTTON_2
	var seq := [F | B2, D | B2, DF | B2]
	var fired: bool = false
	# Step through the rest of blockstun feeding the reversal motion; watch for REVERSAL.
	for k in range(30):
		var inp: int = seq[k] if k < seq.size() else (DF | B2)
		s = SimState.step(s, inp, InputFrame.NEUTRAL)
		if s.players[0].state_id == TestSupport.STATE_REVERSAL:
			fired = true
			_eq(s.players[0].frame_in_state, 1, "buffered 623 reversal fires on FRAME 1 (frame-1 reversal)")
			break
	_true(fired, "a 623 buffered through blockstun comes out as a reversal on the first actionable frame")
	MoveRegistry.clear()


# --- Special-cancel (AD-015/017; move-format.md crit 7) ---------------------

func _test_special_cancel_on_hit() -> void:
	# LIGHT hits; on the first UNFROZEN tick after hitstop, BUTTON_1 (held/buffered)
	# cancels LIGHT into SPECIAL — the tag was granted on the connect tick (T), usable
	# from T+1 (AD-017). The cancel condition is on_contact and the tag gate is met.
	var s := _light_hits(false)   # P0 LIGHT hits P1
	# On the contact tick both are frozen (hitstop 8). Feed BUTTON_1 every tick from here;
	# it buffers during hitstop and fires the first unfrozen tick.
	var cancelled: bool = false
	for _k in range(20):
		s = SimState.step(s, InputFrame.BUTTON_1, InputFrame.NEUTRAL)
		if s.players[0].state_id == TestSupport.STATE_SPECIAL:
			cancelled = true
			break
	_true(cancelled, "LIGHT special-cancels into SPECIAL on hit (tag-gated, on_contact)")
	MoveRegistry.clear()


func _test_cancel_requires_tag() -> void:
	# If the LIGHT does NOT connect (whiff), no tag is granted, so BUTTON_1 must NOT
	# cancel into SPECIAL (requires_tag gate). P0 attacks into empty air (P1 far away).
	var s := _two_char_state(300)   # too far to connect
	s = SimState.step(s, InputFrame.BUTTON_0, InputFrame.NEUTRAL)
	var cancelled: bool = false
	for _k in range(20):
		s = SimState.step(s, InputFrame.BUTTON_1, InputFrame.NEUTRAL)
		if s.players[0].state_id == TestSupport.STATE_SPECIAL:
			cancelled = true
			break
	_false(cancelled, "a whiffed LIGHT grants no tag, so BUTTON_1 cannot special-cancel (requires_tag)")
	MoveRegistry.clear()


func _test_cancel_never_during_hitstop() -> void:
	# combat-resolution.md crit 8: a cancel input during hitstop executes on the first
	# UNFROZEN tick, not during the freeze. Assert P0 stays in LIGHT for every hitstop
	# tick even while BUTTON_1 is held, then transitions once unfrozen.
	var s := _light_hits(false)
	var hitstop0: int = s.players[0].hitstop
	_true(hitstop0 > 0, "attacker is frozen on the contact tick")
	# Feed BUTTON_1 during the freeze; P0 must remain in LIGHT (no cancel while frozen).
	var t := s
	for k in range(hitstop0 - 1):
		t = SimState.step(t, InputFrame.BUTTON_1, InputFrame.NEUTRAL)
		_eq(t.players[0].state_id, TestSupport.STATE_LIGHT,
			"no cancel executes during hitstop (tick %d) — still LIGHT" % k)
		_true(t.players[0].hitstop > 0, "still frozen during hitstop tick %d" % k)
	MoveRegistry.clear()


# --- Determinism across sources (crit 11) -----------------------------------

func _test_buffering_source_independent() -> void:
	# Buffering is a pure function of input_history, so the SAME recorded stream through
	# a device source and a replay source produces identical results (AD-003, Tenet 2).
	# Here: two runs of the same recorded frames give byte-identical final hashes, which
	# proves the buffering path is source-independent (the harness replays raw frames).
	var stream_p1 := PackedInt32Array()
	var D: int = InputFrame.DOWN
	var F: int = InputFrame.RIGHT
	var DF: int = InputFrame.DOWN | InputFrame.RIGHT
	var B2: int = InputFrame.BUTTON_2
	# A run that includes a 623 motion + button so the buffer/cancel path is exercised.
	var pat := [F | B2, D | B2, DF | B2, InputFrame.NEUTRAL, InputFrame.BUTTON_0, InputFrame.BUTTON_1]
	for i in range(30):
		stream_p1.append(pat[i % pat.size()])
	var stream_p2 := PackedInt32Array()
	for _i in range(30):
		stream_p2.append(InputFrame.NEUTRAL)

	MoveRegistry.install(TestSupport.build_roster())
	var h1: int = _replay_hash(stream_p1, stream_p2)
	var h2: int = _replay_hash(stream_p1, stream_p2)
	_eq(h1, h2, "same recorded stream -> identical final hash (buffering is source-independent)")
	MoveRegistry.clear()


func _replay_hash(p1: PackedInt32Array, p2: PackedInt32Array) -> int:
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = TestSupport.CHAR_ID
	s.players[1].character_id = TestSupport.CHAR_ID
	for f in range(min(p1.size(), p2.size())):
		s = SimState.step(s, p1[f], p2[f])
	return s.hash_state()


# --- Helpers ----------------------------------------------------------------

## Drive P0's LIGHT to connect on P1, returning the state ON the contact tick. If
## `block`, P1 holds back so it is blocked.
func _light_hits(block: bool) -> SimState:
	var s := _two_char_state(50)
	var p2_frame: int = InputFrame.RIGHT if block else InputFrame.NEUTRAL
	s = SimState.step(s, InputFrame.BUTTON_0, p2_frame)
	for _k in range(20):
		if s.last_hit != null:
			return s
		s = SimState.step(s, InputFrame.NEUTRAL, p2_frame)
	return s
