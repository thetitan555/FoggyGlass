extends SceneTree

## Headless test for TKT-P1-09 (input display / history).
## training-mode.md → Readout: input; criterion 8; AD-032 (command schema).
##
## Drives the PURE view-model (`InputHistoryPanelModel`) over hand-built
## SimState/InspectionView — no Control/Label API touched. Confirms the
## decode of the raw InputFrame the sim actually consumed (Tenet 2: input is
## never the hidden variable), and that the jump/throw recognizer projection
## is a pure function of PlayerView.input_history (same InputBuffer function
## the sim itself calls), reachable from bare frames with no CharacterA
## dependency.
##
## Run:  godot --headless --path game -s res://tests/test_input_history_panel.gd

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	if _failures == 0:
		print("[test_input_history_panel] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_input_history_panel] FAIL — %d of %d checks failed" % [_failures, _checks])
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
	_test_decode_neutral()
	_test_decode_direction_bits()
	_test_decode_buttons_lmh_and_reserved()
	_test_decode_matches_exact_frame_the_sim_consumed()
	_test_history_scrolls_oldest_to_newest_and_caps()
	_test_recognizer_jump_from_held_up()
	_test_recognizer_throw_from_lh_chord_same_frame()
	_test_bare_l_still_reaches_light_not_shadowed_by_chord_recognition()
	_test_recognized_absent_when_neither_satisfied()


func _install() -> void:
	MoveRegistry.install(TestSupport.build_roster())


func _teardown() -> void:
	MoveRegistry.clear()


# --- decode --------------------------------------------------------------------

func _test_decode_neutral() -> void:
	var d: Dictionary = InputHistoryPanelModel.decode_frame(InputFrame.NEUTRAL)
	_eq(d["direction"], "N", "a neutral frame decodes direction as N")
	_true(d["buttons"].is_empty(), "a neutral frame decodes no buttons")
	_eq(InputHistoryPanelModel.format_decoded(d), "N", "format_decoded(neutral) is just 'N'")


func _test_decode_direction_bits() -> void:
	_eq(InputHistoryPanelModel.decode_frame(InputFrame.UP)["direction"], "U", "UP decodes as U")
	_eq(InputHistoryPanelModel.decode_frame(InputFrame.DOWN)["direction"], "D", "DOWN decodes as D")
	_eq(InputHistoryPanelModel.decode_frame(InputFrame.LEFT)["direction"], "L", "LEFT decodes as L")
	_eq(InputHistoryPanelModel.decode_frame(InputFrame.RIGHT)["direction"], "R", "RIGHT decodes as R")
	_eq(InputHistoryPanelModel.decode_frame(InputFrame.UP | InputFrame.RIGHT)["direction"], "UR",
		"UP+RIGHT decodes as UR")
	# Raw, pre-SOCD (input.md: raw bits stay raw for replay fidelity) -- the
	# panel shows exactly what the source emitted, not the cleaned intent.
	_eq(InputHistoryPanelModel.decode_frame(InputFrame.LEFT | InputFrame.RIGHT)["direction"], "LR",
		"raw LEFT+RIGHT decodes as the raw LR pair, not SOCD-cleaned neutral")


func _test_decode_buttons_lmh_and_reserved() -> void:
	var d0: Dictionary = InputHistoryPanelModel.decode_frame(InputFrame.BUTTON_0)
	_eq(d0["buttons"], PackedStringArray(["L"]), "BUTTON_0 decodes as L (AD-018 slice-wide label)")
	var d1: Dictionary = InputHistoryPanelModel.decode_frame(InputFrame.BUTTON_1)
	_eq(d1["buttons"], PackedStringArray(["M"]), "BUTTON_1 decodes as M")
	var d2: Dictionary = InputHistoryPanelModel.decode_frame(InputFrame.BUTTON_2)
	_eq(d2["buttons"], PackedStringArray(["H"]), "BUTTON_2 decodes as H")
	var chord: Dictionary = InputHistoryPanelModel.decode_frame(InputFrame.BUTTON_0 | InputFrame.BUTTON_2)
	_eq(chord["buttons"], PackedStringArray(["L", "H"]), "a same-frame L+H chord decodes both buttons")
	_eq(InputHistoryPanelModel.format_decoded(chord), "N L+H", "format_decoded joins multiple buttons with '+'")
	var reserved: Dictionary = InputHistoryPanelModel.decode_frame(InputFrame.BUTTON_3)
	_eq(reserved["buttons"], PackedStringArray(["B3"]),
		"a reserved button bit still decodes visibly (as B3), never silently dropped (Tenet 2)")


func _test_decode_matches_exact_frame_the_sim_consumed() -> void:
	_install()
	var s := SimState.new_initial()
	s.players[0].character_id = TestSupport.CHAR_ID
	s.players[0].state_id = TestSupport.STATE_IDLE
	s.players[1].character_id = TestSupport.CHAR_ID
	s.players[1].state_id = TestSupport.STATE_IDLE
	var p1_frame: int = InputFrame.mask(InputFrame.UP | InputFrame.BUTTON_1)
	s = SimState.step(s, p1_frame, InputFrame.NEUTRAL)

	var view := InspectionView.new(s, TestSupport.build_roster())
	var rows: Array = InputHistoryPanelModel.build(view)
	_eq(rows[0]["current"]["raw"], view.player(0).input_current,
		"panel's decoded raw value == PlayerView.input_current (exactly what the sim consumed)")
	_eq(view.player(0).input_current, p1_frame,
		"sanity: PlayerView.input_current is the exact frame P1's source emitted")
	_teardown()


# --- scrolling history ----------------------------------------------------------

func _test_history_scrolls_oldest_to_newest_and_caps() -> void:
	_install()
	var s := SimState.new_initial()
	s.players[0].character_id = TestSupport.CHAR_ID
	s.players[0].state_id = TestSupport.STATE_IDLE
	s.players[1].character_id = TestSupport.CHAR_ID
	s.players[1].state_id = TestSupport.STATE_IDLE

	var fed: Array = [InputFrame.NEUTRAL, InputFrame.LEFT, InputFrame.RIGHT, InputFrame.UP, InputFrame.DOWN]
	for f in fed:
		s = SimState.step(s, f, InputFrame.NEUTRAL)

	var view := InspectionView.new(s, TestSupport.build_roster())
	var rows: Array = InputHistoryPanelModel.build(view, 3)   # cap to the last 3
	var hist: Array = rows[0]["history"]
	_eq(hist.size(), 3, "history is capped to max_rows (3) most-recent entries")
	# The last 3 fed frames were RIGHT, UP, DOWN, oldest -> newest.
	_eq(hist[0]["direction"], "R", "capped history's oldest shown entry is RIGHT")
	_eq(hist[1]["direction"], "U", "capped history's middle entry is UP")
	_eq(hist[2]["direction"], "D", "capped history's newest entry is DOWN (matches input_current)")
	_eq(hist[2]["raw"], view.player(0).input_current, "the newest history entry equals input_current")
	_teardown()


# --- recognizer: pure function of input_history (AD-032) ------------------------

func _test_recognizer_jump_from_held_up() -> void:
	var hist_dict: Dictionary = {"frames": PackedInt32Array([InputFrame.UP, InputFrame.UP, InputFrame.UP])}
	var pv := PlayerView.new(SimState.new_initial(), 0)   # facing default; history overwritten below
	pv.input_history = hist_dict["frames"]
	pv.facing = 1
	var rec: Dictionary = InputHistoryPanelModel.recognized_commands(pv)
	_true(rec["jump"], "held UP within the command buffer window recognizes as jump")
	_false(rec["throw"], "held UP alone does not recognize as throw")


func _test_recognizer_throw_from_lh_chord_same_frame() -> void:
	var pv := PlayerView.new(SimState.new_initial(), 0)
	pv.input_history = PackedInt32Array([InputFrame.NEUTRAL, InputFrame.BUTTON_0 | InputFrame.BUTTON_2])
	pv.facing = 1
	var rec: Dictionary = InputHistoryPanelModel.recognized_commands(pv)
	_true(rec["throw"], "L+H held on the SAME buffered frame recognizes as throw (AD-032 chord)")
	_false(rec["jump"], "an L+H chord does not also recognize as jump")


func _test_bare_l_still_reaches_light_not_shadowed_by_chord_recognition() -> void:
	# TKT-P1-12's own acceptance: the throw chord must not shadow a bare L
	# press. Here: a bare L (no H) must NOT recognize as throw, proving the
	# panel's throw-recognition itself requires the same-frame chord, not
	# just "L pressed somewhere."
	var pv := PlayerView.new(SimState.new_initial(), 0)
	pv.input_history = PackedInt32Array([InputFrame.BUTTON_0])
	pv.facing = 1
	var rec: Dictionary = InputHistoryPanelModel.recognized_commands(pv)
	_false(rec["throw"], "a bare L press (no H) does not recognize as throw -- the chord does not shadow it")
	_false(rec["jump"], "a bare L press does not recognize as jump either")


func _test_recognized_absent_when_neither_satisfied() -> void:
	var pv := PlayerView.new(SimState.new_initial(), 0)
	pv.input_history = PackedInt32Array([InputFrame.NEUTRAL])
	pv.facing = 1
	var row: Dictionary = {
		"player": 0,
		"current": InputHistoryPanelModel.decode_frame(InputFrame.NEUTRAL),
		"history": [],
		"recognized": InputHistoryPanelModel.recognized_commands(pv),
	}
	var line: String = InputHistoryPanelModel.format_current(row)
	_false(line.contains("["), "format_current shows no recognized-command clause when neither is satisfied")
