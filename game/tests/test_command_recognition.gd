extends SceneTree

## Headless test for command recognition: pure-direction command + two-button
## chord (TKT-P1-12, AD-032). move-format.md (ButtonMapEntry.chord_button_index
## + command-recognition contract); input.md; character-a.md criterion 8
## (extended: jump reachable, L+H throws, 5L/5M/5H each still reachable).
##
## Run:  godot --headless --path game -s res://tests/test_command_recognition.gd
## Exits non-zero on any failure so a harness/CI can gate on it.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	if _failures == 0:
		print("[test_command_recognition] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_command_recognition] FAIL — %d of %d checks failed" % [_failures, _checks])
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
	_test_pure_direction_recognized_by_recognizer()
	_test_pure_direction_needs_no_button()
	_test_chord_requires_same_frame()
	_test_chord_not_satisfied_by_bare_button()
	_test_recognizer_pure_function_of_history()
	_test_character_a_bare_l_reaches_5l()
	_test_character_a_bare_m_reaches_5m()
	_test_character_a_bare_h_reaches_5h()
	_test_character_a_chord_reaches_throw_ordered_first()
	_test_character_a_jump_reachable_end_to_end()


# --- Scenario setup ----------------------------------------------------------

## A history holding a sequence of raw frames (newest last), for pure-recognizer tests.
func _history(frames: Array) -> InputHistory:
	var h := InputHistory.new()
	for f in frames:
		h.push(f)
	return h


func _install_a() -> void:
	MoveRegistry.install({CharacterA.CHAR_ID: CharacterA.build_character()})


func _two_char_state(gap_units: int = 200) -> SimState:
	_install_a()
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = CharacterA.CHAR_ID
	s.players[0].state_id = CharacterA.STATE_IDLE
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = CharacterA.CHAR_ID
	s.players[1].state_id = CharacterA.STATE_IDLE
	s.players[1].pos_x = FP.from_int(gap_units)
	s.players[1].facing = -1
	return s


func _cleanup() -> void:
	MoveRegistry.clear()


# --- Pure recognizer unit tests -----------------------------------------------

## button_index == -1, motion == 0: recognized by required_direction alone, held
## within the last COMMAND_BUFFER frames — no button at all.
func _test_pure_direction_recognized_by_recognizer() -> void:
	var e := ButtonMapEntry.new()
	e.button_index = -1
	e.chord_button_index = -1
	e.required_direction = InputFrame.UP
	e.motion = 0
	e.target_state_id = 999
	# UP held on the newest frame only, well within the 6-frame buffer.
	var hist := _history([InputFrame.NEUTRAL, InputFrame.NEUTRAL, InputFrame.NEUTRAL,
		InputFrame.NEUTRAL, InputFrame.NEUTRAL, InputFrame.UP])
	_true(InputBuffer.entry_satisfied(hist, e, 1), "pure-direction UP recognized when held on a recent frame")
	# Never held at all: not recognized.
	var hist_no := _history([InputFrame.NEUTRAL, InputFrame.NEUTRAL, InputFrame.NEUTRAL,
		InputFrame.NEUTRAL, InputFrame.NEUTRAL, InputFrame.NEUTRAL])
	_false(InputBuffer.entry_satisfied(hist_no, e, 1), "pure-direction UP not recognized when never held")


## A pure-direction command must NOT require any button bit — button_buffered's
## old "button_index < 0 -> false outright" behavior must not leak into this path.
func _test_pure_direction_needs_no_button() -> void:
	var e := ButtonMapEntry.new()
	e.button_index = -1
	e.chord_button_index = -1
	e.required_direction = InputFrame.UP
	e.motion = 0
	e.target_state_id = 999
	var hist := _history([InputFrame.UP])   # UP alone, no button, single buffered frame
	_true(InputBuffer.entry_satisfied(hist, e, 1), "pure-direction command satisfied with no button pressed at all")


## Chord: both bits must be on the SAME frame — an L on one frame and an H six
## frames apart must NOT satisfy it (the exact false-positive AD-032 rules out).
func _test_chord_requires_same_frame() -> void:
	var e := ButtonMapEntry.new()
	e.button_index = 0   # BUTTON_0
	e.chord_button_index = 2   # BUTTON_2
	e.required_direction = 0
	e.motion = 0
	e.target_state_id = 999
	var same_frame := _history([InputFrame.NEUTRAL, InputFrame.NEUTRAL, InputFrame.NEUTRAL,
		InputFrame.NEUTRAL, InputFrame.NEUTRAL, InputFrame.BUTTON_0 | InputFrame.BUTTON_2])
	_true(InputBuffer.entry_satisfied(same_frame, e, 1), "chord satisfied when both buttons held on the same frame")

	var separated := _history([InputFrame.BUTTON_0, InputFrame.NEUTRAL, InputFrame.NEUTRAL,
		InputFrame.NEUTRAL, InputFrame.NEUTRAL, InputFrame.BUTTON_2])
	_false(InputBuffer.entry_satisfied(separated, e, 1),
		"chord NOT satisfied when the two buttons are pressed on separate frames within the window")


## A bare press of just one of the chord's two buttons must never satisfy the chord.
func _test_chord_not_satisfied_by_bare_button() -> void:
	var e := ButtonMapEntry.new()
	e.button_index = 0
	e.chord_button_index = 2
	e.required_direction = 0
	e.motion = 0
	e.target_state_id = 999
	var bare_l := _history([InputFrame.BUTTON_0])
	_false(InputBuffer.entry_satisfied(bare_l, e, 1), "a bare press of button_index alone does not satisfy the chord")
	var bare_h := _history([InputFrame.BUTTON_2])
	_false(InputBuffer.entry_satisfied(bare_h, e, 1), "a bare press of chord_button_index alone does not satisfy the chord")


## Buffering stays a pure function of input_history (AD-003/input.md criterion 2):
## the SAME history recognized identically regardless of what "produced" it.
func _test_recognizer_pure_function_of_history() -> void:
	var e := ButtonMapEntry.new()
	e.button_index = 0
	e.chord_button_index = 2
	e.required_direction = 0
	e.motion = 0
	e.target_state_id = 999
	var hist_a := _history([InputFrame.BUTTON_0 | InputFrame.BUTTON_2])
	var hist_b := _history([InputFrame.BUTTON_0 | InputFrame.BUTTON_2])   # identical content, distinct object
	_eq(InputBuffer.entry_satisfied(hist_a, e, 1), InputBuffer.entry_satisfied(hist_b, e, 1),
		"identical history recognized identically (source-independent)")


# --- Character A end-to-end (live SimState.step) -----------------------------

func _test_character_a_bare_l_reaches_5l() -> void:
	var s := _two_char_state()
	s = SimState.step(s, InputFrame.BUTTON_0, InputFrame.NEUTRAL)
	_eq(s.players[0].state_id, CharacterA.STATE_5L, "a bare L press reaches 5L")
	_cleanup()


func _test_character_a_bare_m_reaches_5m() -> void:
	var s := _two_char_state()
	s = SimState.step(s, InputFrame.BUTTON_1, InputFrame.NEUTRAL)
	_eq(s.players[0].state_id, CharacterA.STATE_5M, "a bare M press reaches 5M")
	_cleanup()


func _test_character_a_bare_h_reaches_5h() -> void:
	var s := _two_char_state()
	s = SimState.step(s, InputFrame.BUTTON_2, InputFrame.NEUTRAL)
	_eq(s.players[0].state_id, CharacterA.STATE_5H, "a bare H press reaches 5H (the chord does not shadow it)")
	_cleanup()


## The throw entry is authored BEFORE the bare normals (first-match-wins), so a
## same-frame L+H resolves to the throw, not 5L/5H.
func _test_character_a_chord_reaches_throw_ordered_first() -> void:
	var s := _two_char_state()
	s = SimState.step(s, InputFrame.BUTTON_0 | InputFrame.BUTTON_2, InputFrame.NEUTRAL)
	_eq(s.players[0].state_id, CharacterA.STATE_THROW, "same-frame L+H resolves to the throw (ordered before 5L/5H)")
	# Sanity: the throw entry is authored earlier in button_map than either bare entry.
	var c: Character = MoveRegistry.character(CharacterA.CHAR_ID)
	var throw_idx: int = -1
	var l_idx: int = -1
	var h_idx: int = -1
	for i in range(c.button_map.size()):
		var e: ButtonMapEntry = c.button_map[i]
		if e.target_state_id == CharacterA.STATE_THROW:
			throw_idx = i
		elif e.target_state_id == CharacterA.STATE_5L and e.chord_button_index < 0 and e.motion == 0:
			l_idx = i
		elif e.target_state_id == CharacterA.STATE_5H and e.chord_button_index < 0 and e.motion == 0:
			h_idx = i
	_true(throw_idx >= 0 and l_idx >= 0 and h_idx >= 0, "throw/5L/5H entries all found in button_map")
	_true(throw_idx < l_idx, "the throw chord entry is authored before the bare 5L entry")
	_true(throw_idx < h_idx, "the throw chord entry is authored before the bare 5H entry")
	_cleanup()


## End-to-end: holding UP reaches PREJUMP then the neutral jump arc (STATE_JUMP_N),
## through live input only — no state injection.
func _test_character_a_jump_reachable_end_to_end() -> void:
	var s := _two_char_state()
	var reached_prejump: bool = false
	var reached_jump_n: bool = false
	for _k in range(10):
		s = SimState.step(s, InputFrame.UP, InputFrame.NEUTRAL)
		if s.players[0].state_id == CharacterA.STATE_PREJUMP:
			reached_prejump = true
		if s.players[0].state_id == CharacterA.STATE_JUMP_N:
			reached_jump_n = true
			break
	_true(reached_prejump, "holding UP reaches STATE_PREJUMP")
	_true(reached_jump_n, "holding UP carries through PREJUMP into the neutral jump arc (STATE_JUMP_N), live-input only")
	_cleanup()
