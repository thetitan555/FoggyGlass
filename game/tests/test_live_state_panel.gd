extends SceneTree

## Headless test for TKT-P1-08 (the live-state panel).
## training-mode.md → Readout: live state; criteria 7 and 9; AD-031's
## PlayerView.invuln surfaced live.
##
## Drives the PURE view-model (`LiveStatePanelModel.build`/`format_row`) over
## hand-built SimState/InspectionView — no Control/Label API touched.
##
## Run:  godot --headless --path game -s res://tests/test_live_state_panel.gd

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	if _failures == 0:
		print("[test_live_state_panel] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_live_state_panel] FAIL — %d of %d checks failed" % [_failures, _checks])
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
	_test_state_frame_hitstop_stun_actionable()
	_test_damage_combo_fields()
	_test_invuln_true_on_covering_frame_false_off_it()
	_test_two_rows_one_per_player()
	_test_format_row_mentions_invuln_when_active()
	_test_air_action_used_field()
	_test_format_row_mentions_air_action_state()


func _two_char_state(gap_x: int = 45) -> SimState:
	MoveRegistry.install({CharacterA.CHAR_ID: CharacterA.build_character()})
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = CharacterA.CHAR_ID
	s.players[0].state_id = CharacterA.STATE_IDLE
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = CharacterA.CHAR_ID
	s.players[1].state_id = CharacterA.STATE_IDLE
	s.players[1].pos_x = FP.from_int(gap_x)
	s.players[1].facing = -1
	return s


# --- criterion 7: state/hitstop/stun/actionable -------------------------------

func _test_state_frame_hitstop_stun_actionable() -> void:
	var s := _two_char_state()
	s.players[0].state_id = CharacterA.STATE_5M
	s.players[0].frame_in_state = 2
	var roster: Dictionary = MoveRegistry.roster()
	var view := InspectionView.new(s, roster)
	var rows: Array = LiveStatePanelModel.build(view)
	var row0: Dictionary = rows[0]
	var pv: PlayerView = view.player(0)

	_eq(row0["state_id"], pv.state_id, "panel state_id == PlayerView.state_id")
	_eq(row0["state_category"], pv.state_category, "panel state_category == PlayerView.state_category")
	_eq(row0["frame_in_state"], pv.frame_in_state, "panel frame_in_state == PlayerView.frame_in_state")
	_eq(row0["state_duration"], pv.state_duration, "panel state_duration == PlayerView.state_duration")
	_eq(row0["hitstop_remaining"], pv.hitstop_remaining, "panel hitstop_remaining == PlayerView.hitstop_remaining")
	_eq(row0["stun_remaining"], pv.stun_remaining, "panel stun_remaining == PlayerView.stun_remaining")
	_eq(row0["stun_kind"], pv.stun_kind, "panel stun_kind == PlayerView.stun_kind")
	_eq(row0["actionable"], pv.actionable, "panel actionable == PlayerView.actionable")
	MoveRegistry.clear()


func _test_damage_combo_fields() -> void:
	var s := _two_char_state()
	s.players[1].combo_hits = 3
	s.players[1].combo_scaling = FP.from_units(0.7)
	s.players[1].combo_damage = 120
	var roster: Dictionary = MoveRegistry.roster()
	var view := InspectionView.new(s, roster)
	var rows: Array = LiveStatePanelModel.build(view)
	var row1: Dictionary = rows[1]
	var pv: PlayerView = view.player(1)

	_eq(row1["hit_count"], pv.combo["hit_count"], "panel hit_count == PlayerView.combo.hit_count")
	_eq(row1["hit_count"], 3, "panel hit_count reflects the hand-set combo_hits")
	_eq(row1["scaling_pct"], pv.combo["scaling_pct"], "panel scaling_pct == PlayerView.combo.scaling_pct")
	_eq(row1["damage_total"], pv.combo["damage_total"], "panel damage_total == PlayerView.combo.damage_total")
	_eq(row1["damage_total"], 120, "panel damage_total reflects the hand-set combo_damage")
	MoveRegistry.clear()


# --- AD-031: PlayerView.invuln surfaced live ---------------------------------

func _test_invuln_true_on_covering_frame_false_off_it() -> void:
	var s := _two_char_state()
	s.players[1].state_id = CharacterA.STATE_2H
	s.players[1].frame_in_state = 1   # within 2H's invuln_strike window
	var roster: Dictionary = MoveRegistry.roster()
	var view := InspectionView.new(s, roster)
	var rows: Array = LiveStatePanelModel.build(view)
	_true(rows[1]["invuln_strike"], "panel row shows invuln_strike true on 2H's covering frame")
	_false(rows[1]["invuln_throw"], "panel row shows invuln_throw false (2H is strike-only invuln)")

	s.players[1].frame_in_state = 15   # well past the invuln window
	var view2 := InspectionView.new(s, roster)
	var rows2: Array = LiveStatePanelModel.build(view2)
	_false(rows2[1]["invuln_strike"], "panel row shows invuln_strike false once the covering frame elapses")
	MoveRegistry.clear()


func _test_two_rows_one_per_player() -> void:
	var s := _two_char_state()
	var roster: Dictionary = MoveRegistry.roster()
	var view := InspectionView.new(s, roster)
	var rows: Array = LiveStatePanelModel.build(view)
	_eq(rows.size(), 2, "the panel builds exactly one row per player")
	_eq(rows[0]["player"], 0, "row 0 is player 0")
	_eq(rows[1]["player"], 1, "row 1 is player 1")
	MoveRegistry.clear()


func _test_format_row_mentions_invuln_when_active() -> void:
	var s := _two_char_state()
	s.players[1].state_id = CharacterA.STATE_2H
	s.players[1].frame_in_state = 1
	var roster: Dictionary = MoveRegistry.roster()
	var view := InspectionView.new(s, roster)
	var rows: Array = LiveStatePanelModel.build(view)
	var line1: String = LiveStatePanelModel.format_row(rows[1])
	_true(line1.contains("invuln"), "the formatted row for an invulnerable frame mentions invuln")
	_true(line1.contains("strike"), "the formatted row names WHICH invuln kind is active (strike)")

	var line0: String = LiveStatePanelModel.format_row(rows[0])
	_false(line0.contains("invuln"), "a non-invulnerable player's formatted row omits the invuln clause entirely")
	MoveRegistry.clear()


# --- TKT-P2-08: air-action economy readout (AD-046) --------------------------

func _test_air_action_used_field() -> void:
	var s := _two_char_state()
	s.players[0].air_action_used = false
	s.players[1].air_action_used = true
	var roster: Dictionary = MoveRegistry.roster()
	var view := InspectionView.new(s, roster)
	var rows: Array = LiveStatePanelModel.build(view)
	var pv0: PlayerView = view.player(0)
	var pv1: PlayerView = view.player(1)
	_eq(rows[0]["air_action_used"], pv0.air_action_used, "panel air_action_used == PlayerView.air_action_used (p0)")
	_eq(rows[0]["air_action_used"], false, "p0's air action reads NOT spent")
	_eq(rows[1]["air_action_used"], pv1.air_action_used, "panel air_action_used == PlayerView.air_action_used (p1)")
	_eq(rows[1]["air_action_used"], true, "p1's air action reads SPENT")
	MoveRegistry.clear()


func _test_format_row_mentions_air_action_state() -> void:
	var s := _two_char_state()
	s.players[0].air_action_used = false
	s.players[1].air_action_used = true
	var roster: Dictionary = MoveRegistry.roster()
	var view := InspectionView.new(s, roster)
	var rows: Array = LiveStatePanelModel.build(view)
	var line0: String = LiveStatePanelModel.format_row(rows[0])
	var line1: String = LiveStatePanelModel.format_row(rows[1])
	_true(line0.contains("ready"), "an unspent air action reads 'ready' in the formatted row")
	_true(line1.contains("SPENT"), "a spent air action reads 'SPENT' in the formatted row")
	MoveRegistry.clear()
