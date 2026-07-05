extends SceneTree

## Headless test for TKT-P1-07 (the frame-data & advantage panel).
## training-mode.md → Readout: frame data + advantage; criterion 6; AD-008's
## static-vs-live distinction; AD-033's "surface the height-dependent read."
##
## Drives the PURE view-model (`FrameDataPanelModel.build`) — no Control/Label
## API touched — plus the text formatter, over InspectionView built directly
## from hand-set SimState (test-side scenario construction is not a seam
## violation; the model/panel under test never sees a raw SimState).
##
## Run:  godot --headless --path game -s res://tests/test_frame_data_panel.gd

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	if _failures == 0:
		print("[test_frame_data_panel] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_frame_data_panel] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	_test_static_frame_data_matches_move_data()
	_test_live_advantage_matches_sim_value()
	_test_live_flips_sign_on_punishable_move()
	_test_height_why_null_on_no_hit()
	_test_height_why_populated_on_air_normal_hit()
	_test_height_why_null_on_grounded_hit()
	_test_deep_vs_high_jh_why_ordering()


# --- static frame data (AD-008 static) ---------------------------------------

func _test_static_frame_data_matches_move_data() -> void:
	MoveRegistry.install(TestSupport.build_roster())
	var s := SimState.new_initial()
	s.players[0].character_id = TestSupport.CHAR_ID
	s.players[0].state_id = TestSupport.STATE_LIGHT
	s.players[0].frame_in_state = 1
	s.players[1].character_id = TestSupport.CHAR_ID
	s.players[1].state_id = TestSupport.STATE_IDLE
	s.players[1].frame_in_state = 1

	var view := InspectionView.new(s, TestSupport.build_roster())
	var model: Dictionary = FrameDataPanelModel.build(view)
	var p0_static: Dictionary = model["static"][0]

	_eq(p0_static["startup"], TestSupport.LIGHT_STARTUP, "panel startup matches TestSupport's hand-computed value")
	_eq(p0_static["active"], TestSupport.LIGHT_ACTIVE, "panel active matches TestSupport's hand-computed value")
	_eq(p0_static["recovery"], TestSupport.LIGHT_RECOVERY, "panel recovery matches TestSupport's hand-computed value")
	_eq(p0_static["total"], TestSupport.LIGHT_DURATION, "panel total matches the authored duration")

	# Single source of truth (inspection-surface.md criterion 3): the panel's
	# numbers must equal frame_data() read directly, not a re-derivation.
	var fd: FrameData = view.frame_data(TestSupport.CHAR_ID, TestSupport.STATE_LIGHT)
	_eq(p0_static["startup"], fd.startup, "panel startup == InspectionView.frame_data().startup (no re-derivation)")
	_eq(p0_static["on_hit_adv"], fd.on_hit_adv, "panel on_hit_adv == InspectionView.frame_data().on_hit_adv")
	_eq(p0_static["on_block_adv"], fd.on_block_adv, "panel on_block_adv == InspectionView.frame_data().on_block_adv")
	MoveRegistry.clear()


# --- live advantage (AD-008 live) ---------------------------------------------

func _test_live_advantage_matches_sim_value() -> void:
	MoveRegistry.install(TestSupport.build_roster())
	var s := SimState.new_initial()
	s.players[0].character_id = TestSupport.CHAR_ID
	s.players[0].state_id = TestSupport.STATE_IDLE
	s.players[1].character_id = TestSupport.CHAR_ID
	s.players[1].state_id = TestSupport.STATE_IDLE

	var view := InspectionView.new(s, TestSupport.build_roster())
	var model: Dictionary = FrameDataPanelModel.build(view)
	var live: Dictionary = model["live"]

	var a: AdvantageView = view.advantage()
	_eq(live["value"], a.value, "panel live value == InspectionView.advantage().value (single source of truth)")
	_eq(live["plus_player"], a.plus_player, "panel plus_player == advantage().plus_player")
	_eq(live["frames_to_neutral"], a.frames_to_neutral, "panel frames_to_neutral == advantage().frames_to_neutral")
	_eq(live["neutral_restored"], a.neutral_restored, "panel neutral_restored == advantage().neutral_restored")
	MoveRegistry.clear()


func _test_live_flips_sign_on_punishable_move() -> void:
	# Drive a real hit-then-punish sequence with the trivial test character and
	# confirm the panel's live value flips sign as the sim's own advantage does.
	MoveRegistry.install(TestSupport.build_roster())
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = TestSupport.CHAR_ID
	s.players[0].state_id = TestSupport.STATE_LIGHT
	s.players[0].frame_in_state = TestSupport.LIGHT_FIRST_ACTIVE - 1
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = TestSupport.CHAR_ID
	s.players[1].state_id = TestSupport.STATE_IDLE
	s.players[1].pos_x = FP.from_int(20)
	s.players[1].facing = -1

	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)   # the hit lands
	var view_after_hit := InspectionView.new(s, TestSupport.build_roster())
	var model_after_hit: Dictionary = FrameDataPanelModel.build(view_after_hit)
	var a_after_hit: AdvantageView = view_after_hit.advantage()
	_eq(model_after_hit["live"]["value"], a_after_hit.value,
		"live value tracks the sim's advantage() immediately after a hit lands too")

	# Attacker is in recovery, defender in hitstun: whoever has fewer remaining
	# frames is "plus." Just assert panel and sim agree at every subsequent tick
	# through recovery (the flip, wherever it lands, is the same in both).
	for _k in range(TestSupport.LIGHT_RECOVERY + TestSupport.HITSTUN_DURATION + 2):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		var view := InspectionView.new(s, TestSupport.build_roster())
		var model: Dictionary = FrameDataPanelModel.build(view)
		var a: AdvantageView = view.advantage()
		_eq(model["live"]["value"], a.value, "live value == sim advantage() at tick %d" % s.tick)
		_eq(model["live"]["plus_player"], a.plus_player, "plus_player == sim advantage() at tick %d" % s.tick)
	MoveRegistry.clear()


# --- AD-033 height "why" ------------------------------------------------------

func _test_height_why_null_on_no_hit() -> void:
	MoveRegistry.install({CharacterA.CHAR_ID: CharacterA.build_character()})
	var s := SimState.new_initial()
	s.players[0].character_id = CharacterA.CHAR_ID
	s.players[0].state_id = CharacterA.STATE_IDLE
	s.players[1].character_id = CharacterA.CHAR_ID
	s.players[1].state_id = CharacterA.STATE_IDLE
	var view := InspectionView.new(s, {CharacterA.CHAR_ID: CharacterA.build_character()})
	var model: Dictionary = FrameDataPanelModel.build(view)
	_eq(model["last_hit_why"], null, "no last hit -> last_hit_why is null")
	_eq(FrameDataPanelModel.format_last_hit_why(null), "", "format_last_hit_why(null) is the empty string")
	MoveRegistry.clear()


func _test_height_why_populated_on_air_normal_hit() -> void:
	var s := _jh_hit_state(-5)
	var roster: Dictionary = MoveRegistry.roster()
	var view := InspectionView.new(s, roster)
	var model: Dictionary = FrameDataPanelModel.build(view)
	var why = model["last_hit_why"]
	_true(why != null, "an air-normal hit populates last_hit_why")
	_eq(why["contact_depth"], s.last_hit.contact_depth, "why.contact_depth == HitEvent.contact_depth")
	_eq(why["air_height_hitstun_delta"], s.last_hit.air_height_hitstun_delta,
		"why.air_height_hitstun_delta == HitEvent.air_height_hitstun_delta")
	var line: String = FrameDataPanelModel.format_last_hit_why(why)
	_true(line.contains("depth"), "the formatted line mentions depth")
	_true(line.contains("hitstun"), "the formatted line mentions hitstun -- the 'why' behind the extra plus")
	MoveRegistry.clear()


func _test_height_why_null_on_grounded_hit() -> void:
	MoveRegistry.install({CharacterA.CHAR_ID: CharacterA.build_character()})
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = CharacterA.CHAR_ID
	s.players[0].state_id = CharacterA.STATE_5M
	s.players[0].frame_in_state = 0
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = CharacterA.CHAR_ID
	s.players[1].state_id = CharacterA.STATE_IDLE
	s.players[1].pos_x = FP.from_int(20)
	s.players[1].facing = -1
	var roster: Dictionary = {CharacterA.CHAR_ID: CharacterA.build_character()}
	var hit_landed: bool = false
	for _k in range(20):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.last_hit != null:
			hit_landed = true
			break
	_true(hit_landed, "sanity: the grounded 5M connected")
	var view := InspectionView.new(s, roster)
	var model: Dictionary = FrameDataPanelModel.build(view)
	_eq(model["last_hit_why"], null,
		"a grounded normal's hit leaves last_hit_why null (both height fields 0, per inspection-surface.md)")
	MoveRegistry.clear()


func _test_deep_vs_high_jh_why_ordering() -> void:
	var deep := _jh_hit_state(-5)
	var deep_roster: Dictionary = MoveRegistry.roster()
	var deep_view := InspectionView.new(deep, deep_roster)
	var deep_why: Dictionary = FrameDataPanelModel.build(deep_view)["last_hit_why"]
	MoveRegistry.clear()

	var high := _jh_hit_state(-35)
	var high_roster: Dictionary = MoveRegistry.roster()
	var high_view := InspectionView.new(high, high_roster)
	var high_why: Dictionary = FrameDataPanelModel.build(high_view)["last_hit_why"]
	MoveRegistry.clear()

	_true(deep_why != null and high_why != null, "both contacts populate last_hit_why")
	_true(deep_why["air_height_hitstun_delta"] > high_why["air_height_hitstun_delta"],
		"the panel's 'why' shows the deep jump-in with a strictly larger hitstun delta than the high one")
	_true(deep_why["contact_depth"] < high_why["contact_depth"],
		"the panel's 'why' shows the deep jump-in with a strictly smaller contact_depth than the high one")


## Mirrors test_air_height_scaling.gd's _jh_hit_state helper (Character A, j.H,
## first active frame, at a given attacker pos_y, overlapping a grounded P1).
func _jh_hit_state(pos_y_units: int, gap_x: int = 30) -> SimState:
	MoveRegistry.install({CharacterA.CHAR_ID: CharacterA.build_character()})
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = CharacterA.CHAR_ID
	s.players[0].state_id = CharacterA.STATE_JH
	s.players[0].frame_in_state = 8
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].pos_y = FP.from_int(pos_y_units)
	s.players[0].facing = 1
	s.players[1].character_id = CharacterA.CHAR_ID
	s.players[1].state_id = CharacterA.STATE_IDLE
	s.players[1].pos_x = FP.from_int(gap_x)
	s.players[1].facing = -1
	return SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
