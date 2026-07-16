extends SceneTree

## Headless test for the MATCH PANEL's pure view-model (TKT-P2-08;
## match-flow.md "Legibility"; inspection-surface.md → MatchView, AD-048).
##
## Drives `MatchPanelModel.build`/`format` directly over a hand-built
## `MatchView` (and the `null` no-match case) — no Control/Label API touched,
## mirrors test_live_state_panel.gd / test_frame_data_panel.gd's own pattern.
##
## Run:  godot --headless --path game -s res://tests/test_match_panel.gd

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	if _failures == 0:
		print("[test_match_panel] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_match_panel] FAIL — %d of %d checks failed" % [_failures, _checks])
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
	_test_no_match_shape()
	_test_no_match_formats_a_placeholder_not_blank()
	_test_populated_shape_matches_match_view()
	_test_format_mentions_health_pips_clock_phase()
	_test_format_omits_reason_line_when_none()
	_test_format_includes_reason_line_when_a_round_ended()
	_test_format_marks_sudden_death()
	_test_phase_and_reason_names()


func _active_match_state(h0: int, h1: int, timer: int, wins0: int = 0, wins1: int = 0) -> MatchState:
	var ms := MatchState.new_match(TestSupport.CHAR_ID, TestSupport.CHAR_ID, 1)
	ms = ms.clone()
	ms.match_phase = MatchState.PHASE_ACTIVE
	ms.round_timer = timer
	ms.round_wins[0] = wins0
	ms.round_wins[1] = wins1
	ms.sim.players[0].health = h0
	ms.sim.players[1].health = h1
	return ms


func _test_no_match_shape() -> void:
	var model: Dictionary = MatchPanelModel.build(null)
	_eq(model["has_match"], false, "a null MatchView -> has_match false")


func _test_no_match_formats_a_placeholder_not_blank() -> void:
	var model: Dictionary = MatchPanelModel.build(null)
	var text: String = MatchPanelModel.format(model)
	_true(text != "", "the no-match render is never a blank string (P1 lesson: a readout must show SOMETHING)")
	_true(text.contains("Match"), "the placeholder still identifies itself as the match panel")
	_true(text.to_lower().contains("sandbox") or text.to_lower().contains("no match"),
		"the placeholder explicitly says there is no match running (not a silently-blank surface)")


func _test_populated_shape_matches_match_view() -> void:
	var ms := _active_match_state(300, 150, 200, 1, 0)
	var mv := MatchView.new(ms)
	var model: Dictionary = MatchPanelModel.build(mv)
	_eq(model["has_match"], true, "a real MatchView -> has_match true")
	_eq(model["health"][0], mv.health[0], "model health[0] == MatchView.health[0]")
	_eq(model["health"][1], mv.health[1], "model health[1] == MatchView.health[1]")
	_eq(model["round_wins"][0], mv.round_wins[0], "model round_wins[0] == MatchView.round_wins[0]")
	_eq(model["round_timer"], mv.round_timer, "model round_timer == MatchView.round_timer")
	_eq(model["match_phase"], mv.match_phase, "model match_phase == MatchView.match_phase")
	_eq(model["sudden_death"], mv.sudden_death, "model sudden_death == MatchView.sudden_death")
	_eq(model["last_round_end_reason"], mv.last_round_end_reason,
		"model last_round_end_reason == MatchView.last_round_end_reason")
	_eq(model["round_index"], mv.round_index, "model round_index == MatchView.round_index")


func _test_format_mentions_health_pips_clock_phase() -> void:
	var ms := _active_match_state(300, 150, 600, 1, 0)
	var mv := MatchView.new(ms)
	var model: Dictionary = MatchPanelModel.build(mv)
	var text: String = MatchPanelModel.format(model)
	_true(text.contains("300"), "the rendered text shows p0's health")
	_true(text.contains("150"), "the rendered text shows p1's health")
	_true(text.contains("Round wins"), "the rendered text shows the round-pip line")
	_true(text.contains("ACTIVE"), "the rendered text names the current match phase")
	_true(text.contains("Clock"), "the rendered text shows the clock")


func _test_format_omits_reason_line_when_none() -> void:
	var ms := _active_match_state(300, 150, 600)
	var mv := MatchView.new(ms)
	var model: Dictionary = MatchPanelModel.build(mv)
	var text: String = MatchPanelModel.format(model)
	_false(text.contains("Last round ended"), "no round has ended yet -- no 'why' line is shown")


func _test_format_includes_reason_line_when_a_round_ended() -> void:
	var ms := _active_match_state(500, 0, 3000)
	var next := MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	var mv := MatchView.new(next)
	var model: Dictionary = MatchPanelModel.build(mv)
	var text: String = MatchPanelModel.format(model)
	_true(text.contains("Last round ended: KO"),
		"a KO'd round shows the SERIALIZED reason, not a render guess (match-flow.md 'Legibility')")


func _test_format_marks_sudden_death() -> void:
	var ms := _active_match_state(0, 0, 3000, 1, 1)   # both already at 1 win
	var next := MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)   # double-KO -> both to 2
	for i in range(MatchState.ROUND_END_BEAT_TICKS):
		next = MatchState.match_step(next, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	var mv := MatchView.new(next)
	var model: Dictionary = MatchPanelModel.build(mv)
	var text: String = MatchPanelModel.format(model)
	_true(text.contains("SUDDEN DEATH"), "a sudden-death round is legibly marked in the rendered text")


func _test_phase_and_reason_names() -> void:
	_eq(MatchPanelModel.phase_name(MatchState.PHASE_ROUND_START), "ROUND_START", "phase_name(ROUND_START)")
	_eq(MatchPanelModel.phase_name(MatchState.PHASE_ACTIVE), "ACTIVE", "phase_name(ACTIVE)")
	_eq(MatchPanelModel.phase_name(MatchState.PHASE_ROUND_END), "ROUND_END", "phase_name(ROUND_END)")
	_eq(MatchPanelModel.phase_name(MatchState.PHASE_MATCH_END), "MATCH_END", "phase_name(MATCH_END)")
	_eq(MatchPanelModel.reason_name(MatchState.REASON_NONE), "NONE", "reason_name(NONE)")
	_eq(MatchPanelModel.reason_name(MatchState.REASON_KO), "KO", "reason_name(KO)")
	_eq(MatchPanelModel.reason_name(MatchState.REASON_TIMEOUT), "TIMEOUT", "reason_name(TIMEOUT)")
	_eq(MatchPanelModel.reason_name(MatchState.REASON_DOUBLE_KO), "DOUBLE_KO", "reason_name(DOUBLE_KO)")
