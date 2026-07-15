extends SceneTree

## Headless test for TKT-P2-01 (airborne physics — gravity, persistent velocity,
## the continuous ground clamp fused with landing, and knockdown-into-ground;
## AD-043). Serves `combat-resolution.md` criterion 15, `move-format.md`
## criterion 13, and `simulation.md`'s determinism/round-trip/hash criteria for
## the new `velocity` meaning + `players[i].air_action_used` field.
##
## Exercises the mechanism directly (driving `state_id`/`frame_in_state` by
## hand, mirroring test_character_a.gd's existing convention for isolating
## engine behavior from command recognition) through the real
## `SimState.step`/`PlayerState` surface — not a re-derivation of step_phases.gd's
## own logic.
##
## Run:  godot --headless --path game -s res://tests/test_airborne_physics.gd
## Exits non-zero on any failure so a harness/CI can gate on it.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	if _failures == 0:
		print("[test_airborne_physics] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_airborne_physics] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _install() -> void:
	MoveRegistry.install({CharacterA.CHAR_ID: CharacterA.build_character()})
	ProjectileRegistry.install(CharacterA.build_projectile_registry())


func _cleanup() -> void:
	MoveRegistry.clear()
	ProjectileRegistry.clear()


func _two_char_state(gap_units: int = 300) -> SimState:
	_install()
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


func _run() -> void:
	_test_gravity_is_nonzero_and_baked_fixed_point()
	_test_grounded_state_never_accrues_gravity()
	_test_velocity_persists_across_airborne_state_transition()
	_test_launched_hitstun_lands_into_knockdown_not_idle()
	_test_air_action_used_defaults_false_and_resets_on_landing()
	_test_air_action_used_is_hashed_and_round_trips()


# --- gravity is a real, baked fixed-point per-character constant ------------

func _test_gravity_is_nonzero_and_baked_fixed_point() -> void:
	var c := CharacterA.build_character()
	_true(c.physics.gravity > 0, "character A's physics.gravity is a real positive constant (AD-043)")
	_eq(c.physics.gravity, FP.from_units(1.0), "gravity is the tuned value logged in judgment-log.md (1.0 unit/tick)")


# --- a GROUNDED state never accrues vertical velocity/gravity ---------------
# The trickiest invariant AD-043 depends on: gravity/the clamp gate on GENUINE
# physical airborne-ness, not on category alone, precisely so an ordinary
# standing state (idle here; the same holds for a standing hit/block reaction,
# category HITSTUN/BLOCKSTUN, sharing the launched reaction's category label)
# never accretes gravity turn after turn.

func _test_grounded_state_never_accrues_gravity() -> void:
	var s := _two_char_state()
	for _k in range(120):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(s.players[0].vel_y, 0, "an idle (GROUNDED) character never accrues vel_y over 120 ticks")
	_eq(s.players[0].pos_y, 0, "an idle (GROUNDED) character's pos_y never drifts off ground_y")
	_cleanup()


# --- persistent velocity across an airborne state transition (AD-043) ------
# "An air normal carries the fall" — the fix TKT-P2-01 names. Drive JUMP_N mid-
# flight (falling, in this case since 15 ticks already exceeds the ~7-tick
# rise-to-apex under the tuned gravity/takeoff), then simulate a cancel into
# j.L (STATE_JL) the way CancelEval's own _enter_state does (state_id/
# frame_in_state set, vel_x zeroed, vel_y UNTOUCHED) and confirm vel_y/pos_y
# continue integrating from where they were — not reset — across the
# transition, exactly like an uninterrupted jump would.

func _test_velocity_persists_across_airborne_state_transition() -> void:
	var s := _two_char_state()
	s.players[0].state_id = CharacterA.STATE_JUMP_N
	s.players[0].frame_in_state = 0
	for _k in range(15):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(s.players[0].state_id, CharacterA.STATE_JUMP_N, "still mid-flight after 15 ticks")
	var vy_before_cancel: int = s.players[0].vel_y
	var py_before_cancel: int = s.players[0].pos_y
	_true(vy_before_cancel != 0, "mid-flight vel_y is nonzero (still falling/rising under gravity)")

	# Simulate the cancel (mirrors StepPhases._enter_state's own vel_x=0/vel_y-
	# untouched contract — this test isolates the PHYSICS carry-over, not
	# CancelEval's own recognition, matching test_character_a.gd's convention).
	s.players[0].state_id = CharacterA.STATE_JL
	s.players[0].frame_in_state = 1
	s.players[0].vel_x = 0

	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	var gravity: int = CharacterA.build_character().physics.gravity
	_eq(s.players[0].vel_y, vy_before_cancel + gravity,
		"vel_y carries over into the air normal and gravity keeps accumulating on it (not reset to 0)")
	_true(s.players[0].pos_y != py_before_cancel,
		"pos_y keeps integrating from the carried velocity across the state transition")
	_cleanup()


# --- a launched (airborne HITSTUN) character lands into a knockdown reaction,
# not idle (AD-043) --------------------------------------------------------
# DP_L's single hit launches the defender (hb1.launch, STATE_HITSTUN_LAUNCH).
# Exact tick numbers below were derived by actual headless replay (not hand-
# derived), mirroring this tree's established methodology.

func _test_launched_hitstun_lands_into_knockdown_not_idle() -> void:
	var s := _two_char_state(30)
	s.players[0].state_id = CharacterA.STATE_DP_L
	s.players[0].frame_in_state = 0

	var reached_hitstun_launch: bool = false
	var min_py: int = 0
	var landed_tick_still_in_launch: int = -1
	for k in range(60):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[1].state_id == CharacterA.STATE_HITSTUN_LAUNCH:
			reached_hitstun_launch = true
			if s.players[1].pos_y < min_py:
				min_py = s.players[1].pos_y
			if s.players[1].pos_y == 0 and min_py < 0 and landed_tick_still_in_launch == -1:
				landed_tick_still_in_launch = k + 1
	_true(reached_hitstun_launch, "DP_L's launch forces the defender into STATE_HITSTUN_LAUNCH")
	_true(min_py < 0, "the launched defender genuinely goes airborne (pos_y < ground_y) at some point")
	_true(landed_tick_still_in_launch != -1,
		"the defender's pos_y returns to EXACTLY ground_y while STILL in STATE_HITSTUN_LAUNCH -- " +
		"the knockdown reaction (AD-043: 'no new engine category or destination state'), not a transition to idle")

	# Continue until the authored stun naturally expires -- THEN (and only
	# then) does the character become actionable again (STATE_IDLE).
	var reached_idle: bool = false
	for _k in range(60):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[1].state_id == CharacterA.STATE_IDLE:
			reached_idle = true
			break
	_true(reached_idle, "the knocked-down defender eventually wakes up to STATE_IDLE once stun expires")
	_eq(s.players[1].vel_y, 0, "landing zeroed vertical velocity (still true once idle)")
	_cleanup()


# --- air_action_used: default, and reset on landing (AD-046 field only; its
# CONSUMPTION — spending it on an air dash/double jump — is TKT-P2-02's scope) -

func _test_air_action_used_defaults_false_and_resets_on_landing() -> void:
	var s := _two_char_state()
	_eq(s.players[0].air_action_used, false, "air_action_used defaults false on a fresh player")

	# Force it true mid-flight (as if an air action had been spent) and confirm
	# the continuous clamp's landing transition resets it, per AD-043's
	# "Landing resets air_action_used" / AD-046.
	s.players[0].state_id = CharacterA.STATE_JUMP_N
	s.players[0].frame_in_state = 0
	s.players[0].air_action_used = true
	var landed: bool = false
	for _k in range(50):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[0].state_id == CharacterA.STATE_IDLE:
			landed = true
			break
	_true(landed, "the jump lands within 50 ticks")
	_eq(s.players[0].air_action_used, false, "landing resets air_action_used to false")
	_cleanup()


# --- serialization / hash coverage for the new field (simulation.md determinism/
# round-trip/hash criteria, extended to air_action_used) --------------------

func _test_air_action_used_is_hashed_and_round_trips() -> void:
	var s := _two_char_state()
	s.players[0].air_action_used = true

	var d: Dictionary = s.to_dict()
	_eq(int(d["players"][0]["air_action_used"]), 1, "to_dict serializes air_action_used as 1 when true")

	var restored: SimState = SimState.from_dict(d)
	_true(restored != null, "from_dict restores a dict carrying air_action_used")
	_eq(restored.players[0].air_action_used, true, "air_action_used survives a round-trip")
	_eq(restored.hash_state(), s.hash_state(), "round-trip reproduces an identical canonical hash")

	# Total coverage (AD-023): a state differing ONLY in air_action_used must
	# hash DIFFERENTLY, proving the field is actually folded into the hash
	# (not silently ignored).
	var s2: SimState = s.clone()
	s2.players[0].air_action_used = false
	_true(s.hash_state() != s2.hash_state(),
		"two states differing only in air_action_used hash DIFFERENTLY (AD-023 total coverage)")

	# clone() deep-copies the field too (AD-004 non-mutation discipline).
	var s3: SimState = s.clone()
	s3.players[0].air_action_used = false
	_eq(s.players[0].air_action_used, true, "clone() does not let mutating the clone reach back into the original")
	_cleanup()
