extends SceneTree

## Headless test for the inspection surface (TKT-P0-04). inspection-surface.md
## criteria 2 and 4 for the implemented reads (1/3/5 complete at TKT-P1-01; the
## frame_data/advantage/last_hit wiring is exercised by test_combat.gd at 07).
##
## Run:  godot --headless --path game -s res://tests/test_inspection_view.gd
##
## Criteria covered here:
##   2 Read-only    — no method mutates SimState; the state hash is unchanged after
##                    any sequence of inspection calls; no mutator is exposed.
##   4 Snapshot-stable, fixed-point only — PlayerView / HitEvent truth views contain
##                    NO float fields (a recursive scan of their exported data).
## Plus: the core PlayerView reads return the sim's own values (state+frame,
## position, stun, hitstop, health, inputs), and px projection is a helper, never a
## truth-view field (criterion 6 spot-check).

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	if _failures == 0:
		print("[test_inspection_view] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_inspection_view] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	_test_read_only()
	_test_core_reads()
	_test_no_floats_in_truth_views()
	_test_stubs_typed()
	_test_f013_legibility_fields()


func _test_read_only() -> void:
	# Criterion 2: no inspection call mutates state; the hash is unchanged after a
	# sequence of reads.
	var s := SimState.new_initial(7)
	# Advance a few ticks so there is non-trivial state to read.
	for f in range(5):
		s = SimState.step(s, InputFrame.RIGHT, InputFrame.LEFT)
	var before: int = s.hash_state()

	var view := InspectionView.new(s)
	# Exercise every read the surface offers.
	var _t: int = view.tick()
	var pv0: PlayerView = view.player(0)
	var pv1: PlayerView = view.player(1)
	var _pr: Array = view.projectiles()
	var _fd: FrameData = view.frame_data(0, 0)
	var _adv: AdvantageView = view.advantage()
	var _lh: HitEvent = view.last_hit()
	# Touch the returned views' fields too.
	var _x: int = pv0.position["x"]
	var _y: int = pv1.stun_remaining

	_eq(s.hash_state(), before, "state hash unchanged after a sequence of inspection reads")


func _test_core_reads() -> void:
	# The core PlayerView reads must equal the sim's own values (single source).
	var s := SimState.new_initial(3)
	s.players[0].health = 777
	s.players[0].stun = 12
	s.players[0].hitstop = 3
	s.players[0].pos_x = FP.from_int(-50)
	s.players[0].state_id = 4
	s.players[0].frame_in_state = 6
	s.players[0].facing = 1
	s = SimState.step(s, InputFrame.DOWN | InputFrame.BUTTON_1, InputFrame.NEUTRAL)

	var view := InspectionView.new(s)
	_eq(view.tick(), 1, "tick() reads state.tick")
	var pv: PlayerView = view.player(0)
	_eq(pv.health, 777, "PlayerView.health reads state")
	# stun holds at 12: hitstop was positive at tick start, so phase 7 freezes stun
	# (combat-resolution.md criterion 4 — stun does not advance while hitstop > 0).
	_eq(pv.stun_remaining, 12, "PlayerView.stun_remaining reads state (frozen under hitstop)")
	# hitstop of 3 was ALREADY active at tick start (was_frozen), so the one step counts
	# it down by one to 2 (combat-resolution.md criterion 4: hitstop is countdown state the
	# loop advances one tick per step; AD-010). The view reads whatever the sim holds — the
	# single-source check is that the view equals the sim's own post-step value, below.
	_eq(pv.hitstop_remaining, s.players[0].hitstop, "PlayerView.hitstop_remaining reads state (single source)")
	_eq(pv.hitstop_remaining, 2, "hitstop counted down one tick (pre-set 3 -> 2 after one step)")
	_eq(pv.position["x"], FP.from_int(-50), "PlayerView.position.x reads state (fixed-point)")
	_eq(pv.state_id, 4, "PlayerView.state_id reads state")
	_eq(pv.frame_in_state, 6, "PlayerView.frame_in_state reads state")
	# input_current is the raw frame recorded this tick.
	_eq(pv.input_current, InputFrame.DOWN | InputFrame.BUTTON_1,
		"PlayerView.input_current reads the recorded raw frame")
	# input_history is oldest -> newest, one frame recorded.
	_eq(pv.input_history.size(), 1, "PlayerView.input_history has the one recorded frame")
	_eq(pv.input_history[0], InputFrame.DOWN | InputFrame.BUTTON_1,
		"PlayerView.input_history[0] is the recorded frame")
	# With no roster, actionability falls back to stun/hitstop (stun 12 -> not actionable).
	_eq(pv.actionable, false, "PlayerView.actionable false while stunned (no-roster fallback)")


func _test_no_floats_in_truth_views() -> void:
	# Criterion 4: truth views carry no floats. Scan every exported field.
	var s := SimState.new_initial(1)
	s = SimState.step(s, InputFrame.RIGHT, InputFrame.LEFT)
	var view := InspectionView.new(s)
	var pv: PlayerView = view.player(0)

	_true(not _object_has_float(pv), "PlayerView contains no float field")

	# HitEvent (built from a HitRecord) also carries no float.
	var rec := HitRecord.new()
	rec.attacker = 0
	rec.defender = 1
	rec.damage_dealt = 40
	rec.scaling_applied_pct = 80
	var he := HitEvent.from_record(rec)
	_true(not _object_has_float(he), "HitEvent contains no float field")

	# px projection IS a float — but it is a helper, not a truth-view field
	# (criterion 6). Confirm it is not a member of the PlayerView.
	_true(not ("position_px" in pv), "PlayerView has no px field (px is render-only)")
	# And the helper produces a float, as expected for rendering.
	var px_val: float = InspectionView.px(FP.from_int(2))
	_true(typeof(px_val) == TYPE_FLOAT, "InspectionView.px returns a float (render-only helper)")


func _test_stubs_typed() -> void:
	# The 05/07-wired reads return typed, well-formed results before their data lands.
	var s := SimState.new_initial(1)
	var view := InspectionView.new(s)   # no roster
	var fd: FrameData = view.frame_data(0, 0)
	_true(fd != null, "frame_data returns a typed FrameData (empty) with no roster")
	_eq(fd.startup, 0, "empty frame_data has zero startup")
	var adv: AdvantageView = view.advantage()
	_true(adv != null, "advantage returns a typed AdvantageView")
	_eq(view.last_hit(), null, "last_hit is null before any hit resolves")
	_eq(view.projectiles().size(), 0, "projectiles empty in P0")


func _test_f013_legibility_fields() -> void:
	# TKT-P1-01 / F-013 / AD-028: move_contact, cancel_tags, throw_tech_window,
	# thrown_by are surfaced read-only through PlayerView as a straight projection of
	# the corresponding SimState truth (inspection-surface.md criterion 1) — no
	# re-derivation. Exercise real non-default values via TestSupport's authored
	# throw + special-cancel-granting light attack, and check the view equals the
	# sim's own fields exactly (single source of truth, criterion 3's spirit).
	MoveRegistry.install(TestSupport.build_roster())

	# Defaults: a fresh idle player has no open cancel window, no contact, no throw.
	var s0 := SimState.new_initial()
	s0.players[0].character_id = TestSupport.CHAR_ID
	s0.players[0].state_id = TestSupport.STATE_IDLE
	var view0 := InspectionView.new(s0, TestSupport.build_roster())
	var pv0: PlayerView = view0.player(0)
	_eq(pv0.move_contact, PlayerState.CONTACT_NONE, "default move_contact is NONE")
	_eq(pv0.cancel_tags.size(), 0, "default cancel_tags is empty (no open cancel window)")
	_eq(pv0.throw_tech_window, 0, "default throw_tech_window is 0 (not teching)")
	_eq(pv0.thrown_by, -1, "default thrown_by is -1 (not thrown)")

	# LIGHT connects on hit and grants TAG_SPECIAL (cancel_tags) + move_contact HIT,
	# visible starting the tick AFTER the hit resolves (AD-017 grant->consume latency).
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = TestSupport.CHAR_ID
	s.players[0].state_id = TestSupport.STATE_LIGHT
	s.players[0].frame_in_state = 0   # first step enters frame 1 cleanly
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = TestSupport.CHAR_ID
	s.players[1].state_id = TestSupport.STATE_IDLE
	s.players[1].pos_x = FP.from_int(40)
	s.players[1].facing = -1

	var hit_tick: int = -1
	for _k in range(10):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[0].move_contact == PlayerState.CONTACT_HIT:
			hit_tick = s.tick
			break
	_true(hit_tick != -1, "LIGHT connected (move_contact reached HIT)")

	var view_atk := InspectionView.new(s, TestSupport.build_roster())
	var pv_atk: PlayerView = view_atk.player(0)
	_eq(pv_atk.move_contact, s.players[0].move_contact,
		"PlayerView.move_contact equals sim truth (single source)")
	_eq(pv_atk.move_contact, PlayerState.CONTACT_HIT, "attacker's move_contact reads HIT")
	_true(pv_atk.cancel_tags.size() > 0, "attacker's cancel_tags is non-empty (open cancel window)")
	_eq(pv_atk.cancel_tags[0], TestSupport.TAG_SPECIAL,
		"cancel_tags carries the granted TAG_SPECIAL (straight projection)")
	# cancel_tags must equal the sim's own array content exactly.
	_eq(pv_atk.cancel_tags.size(), s.players[0].cancel_tags.size(),
		"cancel_tags size matches sim truth")

	# Throw: drive P0's throw to connect on P1, then read the defender's tech state
	# through the view and check it matches sim truth exactly.
	MoveRegistry.clear()
	MoveRegistry.install(TestSupport.build_roster())
	var st := SimState.new_initial()
	st.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	st.players[0].character_id = TestSupport.CHAR_ID
	st.players[0].state_id = TestSupport.STATE_IDLE
	st.players[0].pos_x = FP.from_int(0)
	st.players[0].facing = 1
	st.players[1].character_id = TestSupport.CHAR_ID
	st.players[1].state_id = TestSupport.STATE_IDLE
	st.players[1].pos_x = FP.from_int(40)
	st.players[1].facing = -1
	var throw_cmd: int = InputFrame.BUTTON_2 | InputFrame.DOWN
	st = SimState.step(st, throw_cmd, InputFrame.NEUTRAL)
	for _k in range(6):
		if st.players[1].state_id == TestSupport.STATE_THROWN:
			break
		st = SimState.step(st, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(st.players[1].state_id, TestSupport.STATE_THROWN, "throw connected (pre-check)")

	var view_def := InspectionView.new(st, TestSupport.build_roster())
	var pv_def: PlayerView = view_def.player(1)
	_eq(pv_def.throw_tech_window, st.players[1].throw_tech_window,
		"throw_tech_window equals sim truth (single source)")
	_true(pv_def.throw_tech_window > 0, "thrown defender has an open tech window")
	_eq(pv_def.thrown_by, 0, "thrown_by names the attacker index (P0 threw P1)")
	_eq(pv_def.thrown_by, st.players[1].thrown_by, "thrown_by equals sim truth (single source)")

	# The attacker (thrower) is NOT thrown: thrown_by stays -1 for them.
	var pv_thrower: PlayerView = view_def.player(0)
	_eq(pv_thrower.thrown_by, -1, "the thrower's own thrown_by stays -1")

	# All four fields are plain int / PackedInt32Array — float-free (AD-019), covered
	# again here as a targeted F-013 check (not just the general scan above).
	_true(typeof(pv_def.throw_tech_window) == TYPE_INT, "throw_tech_window is a plain int")
	_true(typeof(pv_def.thrown_by) == TYPE_INT, "thrown_by is a plain int")
	_true(typeof(pv_atk.move_contact) == TYPE_INT, "move_contact is a plain int")
	_true(pv_atk.cancel_tags is PackedInt32Array, "cancel_tags is a PackedInt32Array")

	MoveRegistry.clear()


# --- helpers ----------------------------------------------------------------

## True if the object has any float-valued exported/script property, recursively
## through Dictionaries / Arrays it holds.
func _object_has_float(obj: Object) -> bool:
	for prop in obj.get_property_list():
		# Only inspect script variables (not built-in RefCounted noise).
		if not (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var v = obj.get(prop["name"])
		if _has_float(v):
			return true
	return false


func _has_float(v) -> bool:
	var t := typeof(v)
	if t == TYPE_FLOAT:
		return true
	if t == TYPE_PACKED_FLOAT32_ARRAY or t == TYPE_PACKED_FLOAT64_ARRAY:
		return true
	if t == TYPE_DICTIONARY:
		for k in v:
			if _has_float(k) or _has_float(v[k]):
				return true
		return false
	if t == TYPE_ARRAY:
		for e in v:
			if _has_float(e):
				return true
		return false
	return false
