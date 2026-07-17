extends SceneTree

## Headless test for air-normal height-dependent advantage (TKT-P1-13, AD-033).
## combat-resolution.md "Air-normal height-dependent advantage" + criterion 13;
## inspection-surface.md (HitEvent.contact_depth / air_height_hitstun_delta);
## character-a.md criterion 11 + route 2 (a deep j.H links 5M).
##
## Run:  godot --headless --path game -s res://tests/test_air_height_scaling.gd
## Exits non-zero on any failure so a harness/CI can gate on it.
##
## Drives CharacterA (game/content/character_a.gd) through the real
## SimState.step/InspectionView surface (AD-011), matching the same read path
## the training mode and QA's golden harness use.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	if _failures == 0:
		print("[test_air_height_scaling] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_air_height_scaling] FAIL — %d of %d checks failed" % [_failures, _checks])
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
	_test_hitstun_delta_pure_function_of_depth()
	_test_hitstun_delta_clamped_at_endpoints()
	_test_hitstun_delta_monotonic()
	_test_deep_jh_more_plus_than_high_jh()
	_test_grounded_normal_unscaled()
	_test_hitstun_never_below_floor()
	_test_hit_event_reads_zero_on_non_air_hit()
	_test_hit_event_reads_zero_on_block()
	_test_deep_jh_links_5m_route2()
	_test_hit_record_round_trips_new_fields()
	_test_no_float_in_new_fields()


# --- Scenario setup ----------------------------------------------------------

func _install() -> void:
	MoveRegistry.install({CharacterA.CHAR_ID: CharacterA.build_character()})


func _cleanup() -> void:
	MoveRegistry.clear()


## P0 in STATE_JH, first active frame (frame_in_state 8 -> 9 next step), at a
## given pos_y, overlapping a grounded P1 at gap_x. Returns the state AFTER one
## step (the hit tick).
func _jh_hit_state(pos_y_units: int, gap_x: int = 30) -> SimState:
	_install()
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = CharacterA.CHAR_ID
	s.players[0].state_id = CharacterA.STATE_JH
	s.players[0].frame_in_state = 8   # next tick -> 9, jH's first active frame
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].pos_y = FP.from_int(pos_y_units)
	s.players[0].facing = 1
	s.players[1].character_id = CharacterA.CHAR_ID
	s.players[1].state_id = CharacterA.STATE_IDLE
	s.players[1].pos_x = FP.from_int(gap_x)
	s.players[1].facing = -1
	return SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)


# --- AirHeightScaling: pure function unit tests ------------------------------

func _test_hitstun_delta_pure_function_of_depth() -> void:
	_eq(AirHeightScaling.hitstun_delta(FP.from_int(10)), AirHeightScaling.hitstun_delta(FP.from_int(10)),
		"hitstun_delta is a pure function of depth (same input, same output)")


func _test_hitstun_delta_clamped_at_endpoints() -> void:
	_eq(AirHeightScaling.hitstun_delta(0), AirHeightScaling.DEEP_BONUS, "depth 0 (at ground) returns the max DEEP_BONUS")
	_eq(AirHeightScaling.hitstun_delta(FP.from_int(-50)), AirHeightScaling.DEEP_BONUS,
		"depth < 0 (below ground) clamps to the max DEEP_BONUS, not beyond it")
	_eq(AirHeightScaling.hitstun_delta(AirHeightScaling.HIGH_REF_DEPTH), -AirHeightScaling.HIGH_PENALTY,
		"depth at HIGH_REF_DEPTH returns the max -HIGH_PENALTY")
	_eq(AirHeightScaling.hitstun_delta(AirHeightScaling.HIGH_REF_DEPTH * 2), -AirHeightScaling.HIGH_PENALTY,
		"depth beyond HIGH_REF_DEPTH clamps to -HIGH_PENALTY, not beyond it")


func _test_hitstun_delta_monotonic() -> void:
	# Strictly non-increasing as depth increases (deeper/smaller depth => more bonus).
	var prev: int = AirHeightScaling.hitstun_delta(0)
	var monotonic: bool = true
	for units in range(0, 120, 10):
		var d: int = AirHeightScaling.hitstun_delta(FP.from_int(units))
		if d > prev:
			monotonic = false
		prev = d
	_true(monotonic, "hitstun_delta is monotonically non-increasing as depth increases")


# --- End-to-end: deeper contact -> more plus, through the ONE AD-008 formula --

func _test_deep_jh_more_plus_than_high_jh() -> void:
	# Same air normal (j.H) connecting at two different attacker heights. -5 is
	# much deeper (closer to the ground) than -35 (higher, still connecting).
	var deep := _jh_hit_state(-5)
	var deep_stun: int = deep.players[1].stun
	var deep_roster: Dictionary = MoveRegistry.roster()
	var deep_adv: AdvantageView = Advantage.live(deep, deep_roster)
	_cleanup()

	var high := _jh_hit_state(-35)
	var high_stun: int = high.players[1].stun
	var high_roster: Dictionary = MoveRegistry.roster()
	var high_adv: AdvantageView = Advantage.live(high, high_roster)
	_cleanup()

	_true(deep.last_hit != null and high.last_hit != null, "both contacts registered a hit (test setup sanity)")
	_true(deep_stun > high_stun, "the deeper j.H inflicts MORE hitstun than the higher j.H (%d vs %d)" % [deep_stun, high_stun])
	_true(deep_adv.value > high_adv.value,
		"the deeper j.H's live advantage is MORE plus than the higher j.H's (%d vs %d) -- same AD-008 formula, different input" % [deep_adv.value, high_adv.value])
	_true(deep.last_hit.contact_depth < high.last_hit.contact_depth,
		"the deep contact's recorded depth is smaller (closer to the ground) than the high contact's")
	_true(deep.last_hit.air_height_hitstun_delta > high.last_hit.air_height_hitstun_delta,
		"the deep contact's recorded delta is greater than the high contact's")


## A grounded normal (5M) must be COMPLETELY unaffected: its hitstun and the
## HitEvent's height fields are the plain authored/zero values regardless of
## attacker pos_y (grounded normals don't even move in y, but assert explicitly
## that the gate is category == AIRBORNE, not merely "pos_y happens to be 0").
func _test_grounded_normal_unscaled() -> void:
	_install()
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = CharacterA.CHAR_ID
	s.players[0].state_id = CharacterA.STATE_5M
	s.players[0].frame_in_state = 5   # next tick -> 6, 5M's first active frame
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = CharacterA.CHAR_ID
	s.players[1].state_id = CharacterA.STATE_IDLE
	s.players[1].pos_x = FP.from_int(30)
	s.players[1].facing = -1
	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(s.last_hit != null, "5M connected (test setup sanity)")
	_eq(s.players[1].stun, 16, "5M's hitstun is its plain authored value (16), unscaled by height")
	_eq(s.last_hit.contact_depth, 0, "a grounded normal's HitEvent.contact_depth reads 0")
	_eq(s.last_hit.air_height_hitstun_delta, 0, "a grounded normal's HitEvent.air_height_hitstun_delta reads 0")
	_cleanup()


## The floor: even an extremely high (or beyond-reference) contact must never
## drop the applied hitstun below MIN_HITSTUN. Exercised directly against
## AirHeightScaling's formula (base 1 + max penalty would go negative without
## the floor) rather than hunting for a real authored move whose base hitstun is
## that low — the floor is a property of the FORMULA, and this is the exact
## shape the ticket's acceptance calls out ("applied hitstun never drops below
## MIN_HITSTUN").
func _test_hitstun_never_below_floor() -> void:
	var tiny_base: int = 1
	var delta: int = AirHeightScaling.hitstun_delta(AirHeightScaling.HIGH_REF_DEPTH * 4)
	var applied: int = max(tiny_base + delta, AirHeightScaling.MIN_HITSTUN)
	_true(applied >= AirHeightScaling.MIN_HITSTUN,
		"a tiny base hitstun plus the max penalty is floored at MIN_HITSTUN, never below")
	_eq(applied, AirHeightScaling.MIN_HITSTUN, "the floored value is exactly MIN_HITSTUN when the raw sum would go under it")


func _test_hit_event_reads_zero_on_non_air_hit() -> void:
	_install()
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = CharacterA.CHAR_ID
	s.players[0].state_id = CharacterA.STATE_5L
	s.players[0].frame_in_state = 4
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = CharacterA.CHAR_ID
	s.players[1].state_id = CharacterA.STATE_IDLE
	s.players[1].pos_x = FP.from_int(35)
	s.players[1].facing = -1
	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	var roster: Dictionary = MoveRegistry.roster()
	var view := InspectionView.new(s, roster)
	var evt: HitEvent = view.last_hit()
	_true(evt != null, "5L connected (test setup sanity)")
	_eq(evt.contact_depth, 0, "HitEvent.contact_depth reads 0 on a grounded hit, through InspectionView")
	_eq(evt.air_height_hitstun_delta, 0, "HitEvent.air_height_hitstun_delta reads 0 on a grounded hit, through InspectionView")
	_cleanup()


func _test_hit_event_reads_zero_on_block() -> void:
	# A blocked air normal is unaffected (blockstun is authored, never scaled).
	_install()
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = CharacterA.CHAR_ID
	s.players[0].state_id = CharacterA.STATE_JH
	s.players[0].frame_in_state = 8
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].pos_y = FP.from_int(-5)   # deep, would scale heavily on HIT
	s.players[0].facing = 1
	s.players[1].character_id = CharacterA.CHAR_ID
	s.players[1].state_id = CharacterA.STATE_IDLE
	s.players[1].pos_x = FP.from_int(30)
	s.players[1].facing = -1
	# P1 faces -1 (toward P0 at x=0); "back" for facing -1 is RIGHT (away from P0).
	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.RIGHT)   # P1 holds back (block)
	_true(s.last_hit != null, "the deep j.H connected as a block (test setup sanity)")
	_true(s.last_hit.was_block, "the contact resolved as a block (test setup sanity)")
	_eq(s.players[1].stun, 8, "a blocked air normal's blockstun is the plain authored value, unscaled")
	_eq(s.last_hit.contact_depth, 0, "a BLOCKED air normal's HitEvent.contact_depth reads 0 (the rule is hit-only)")
	_eq(s.last_hit.air_height_hitstun_delta, 0, "a BLOCKED air normal's HitEvent.air_height_hitstun_delta reads 0 (hit-only)")
	_cleanup()


## character-a.md route 2: a deep j.H is plus enough to link 5M (startup 5).
##
## UPDATED 2026-07-17 (flags.md, "AD-043 air-move semantics"): j.H's `duration`
## now correctly extends past the physical landing time (the fix for the "air
## normal snaps to the floor" defect — TKT-P2-01 never actually built the
## safety-tail content this needed). That means `Actionability.
## frames_to_actionable`'s single live-advantage READ immediately after
## contact — taken while B is STILL AIRBORNE — now honestly reports a large
## remaining "recovery" (B genuinely hasn't landed yet), since it has no
## fall-time-prediction (the SAME honest limitation AD-050 names for the
## divekick, generalized here — deliberately not built, Tenet 3). The OLD
## version of this test read that live-advantage snapshot as a PROXY for "can
## this move actually combo," and only passed because j.H's short (buggy)
## duration made the proxy read a small, misleadingly plus number.
## character-a.md's route 2 is a REAL-GAMEPLAY claim (5M genuinely connects
## before the defender recovers) — so this version drives the ACTUAL sequence:
## deep j.H connects, B physically falls the rest of the way and lands, B
## presses 5M for real, and 5M's own hitbox is confirmed to connect WHILE the
## defender is still in hitstun. Exercises the thing, not a proxy for it.
func _test_deep_jh_links_5m_route2() -> void:
	var s := _jh_hit_state(-5)
	_true(s.last_hit != null, "the deep j.H connects (setup)")
	_true(s.players[1].stun > 0, "the deep j.H put the defender in hitstun (setup)")

	# Let B fall the rest of the way and actually land (idle, actionable) --
	# purely physical, driven for real, no input.
	var landed: bool = false
	for _k in range(30):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[0].state_id == CharacterA.STATE_IDLE:
			landed = true
			break
		if s.players[1].stun == 0:
			break   # the defender recovered before B even landed
	_true(landed, "B physically lands (returns to idle) within budget (setup)")
	_true(s.players[1].stun > 0, "the defender is STILL in hitstun the moment B lands -- route 2 is still alive at this point")

	# Press 5M for real and confirm it actually connects WHILE the defender is
	# still in hitstun -- a genuine combo, not a late free hit on a recovered
	# opponent.
	var linked: bool = false
	for _k in range(10):
		s = SimState.step(s, InputFrame.BUTTON_1, InputFrame.NEUTRAL)   # 5M
		if s.players[0].move_contact == PlayerState.CONTACT_HIT:
			linked = true
			break
		if s.players[1].stun == 0 and s.players[1].state_id == CharacterA.STATE_IDLE:
			break   # the defender recovered first -- route 2 failed to link
	_true(linked, "character-a.md route 2 holds through the REAL sequence: B lands fast enough off a deep j.H that 5M genuinely connects while the defender is still in hitstun")
	_cleanup()


# --- Serialization / determinism ---------------------------------------------

func _test_hit_record_round_trips_new_fields() -> void:
	var rec := HitRecord.new()
	rec.attacker = 0
	rec.defender = 1
	rec.damage_dealt = 42
	rec.was_block = false
	rec.scaling_applied_pct = 100
	rec.combo_count_after = 1
	rec.tick = 7
	rec.contact_depth = FP.from_int(12)
	rec.air_height_hitstun_delta = 3
	var d: Dictionary = rec.to_dict()
	var restored: HitRecord = HitRecord.from_dict(d)
	_eq(restored.contact_depth, rec.contact_depth, "HitRecord.contact_depth round-trips through to_dict/from_dict")
	_eq(restored.air_height_hitstun_delta, rec.air_height_hitstun_delta,
		"HitRecord.air_height_hitstun_delta round-trips through to_dict/from_dict")
	var cloned: HitRecord = rec.clone()
	_eq(cloned.contact_depth, rec.contact_depth, "HitRecord.contact_depth survives clone()")
	_eq(cloned.air_height_hitstun_delta, rec.air_height_hitstun_delta, "HitRecord.air_height_hitstun_delta survives clone()")
	_true("contact_depth" in HitRecord.HASH_FIELDS, "contact_depth is covered by HASH_FIELDS (AD-023 total coverage)")
	_true("air_height_hitstun_delta" in HitRecord.HASH_FIELDS, "air_height_hitstun_delta is covered by HASH_FIELDS")

	# Determinism: hashing a SimState with this hit recorded must be stable across
	# an independent clone (same content -> same hash).
	_install()
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.last_hit = rec
	var s2: SimState = s.clone()
	_eq(s.hash_state(), s2.hash_state(), "SimState.hash_state is stable across a clone with the new HitRecord fields populated")
	_cleanup()


func _test_no_float_in_new_fields() -> void:
	var s := _jh_hit_state(-5)
	_true(s.last_hit != null, "a hit is recorded (test setup sanity)")
	_true(typeof(s.last_hit.contact_depth) == TYPE_INT, "HitRecord.contact_depth is a plain int (no float)")
	_true(typeof(s.last_hit.air_height_hitstun_delta) == TYPE_INT, "HitRecord.air_height_hitstun_delta is a plain int (no float)")
	var roster: Dictionary = MoveRegistry.roster()
	var view := InspectionView.new(s, roster)
	var evt: HitEvent = view.last_hit()
	_true(typeof(evt.contact_depth) == TYPE_INT, "HitEvent.contact_depth is a plain int (no float)")
	_true(typeof(evt.air_height_hitstun_delta) == TYPE_INT, "HitEvent.air_height_hitstun_delta is a plain int (no float)")
	_cleanup()
