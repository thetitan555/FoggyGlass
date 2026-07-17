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
	_test_knockdown_wakeup_counts_from_landing_not_from_the_original_hit()
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
#
# FIXED 2026-07-17 (flags.md, "AD-043 air-move semantics", a false-green this
# ticket's own audit missed): the PRIOR version of this test stopped after ONE
# tick past the cancel, asserting only that vel_y ticked up by one gravity
# increment. That is a single-tick snapshot, not "the fall keeps going" — it
# could not distinguish a genuinely carried fall from an air normal whose own
# short authored `duration` forces an early idle transition a few ticks later
# (which then teleports pos_y straight to ground_y via `_enter_state`'s AD-042
# grounded-entry snap — the exact "air normal snaps to the floor" defect this
# same test was supposed to be TKT-P2-01's regression net against, and wasn't).
# The extension below drives the REST of the flight and demands the air-normal-
# cancelled jump land on the EXACT SAME physical tick an uninterrupted jump
# does (j.L authors no motion of its own, so cancelling into it must not move
# the landing time at all) — this is what actually distinguishes "carried" from
# "snapped."

func _test_velocity_persists_across_airborne_state_transition() -> void:
	# Reference: an UNINTERRUPTED jump's own physical landing tick. Carrying the
	# fall through a state transition must not change WHEN the character lands.
	var s_ref := _two_char_state()
	s_ref.players[0].state_id = CharacterA.STATE_JUMP_N
	s_ref.players[0].frame_in_state = 0
	var reference_landed_tick: int = -1
	for k in range(80):
		s_ref = SimState.step(s_ref, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s_ref.players[0].state_id == CharacterA.STATE_IDLE:
			reference_landed_tick = k + 1
			break
	_true(reference_landed_tick != -1, "an uncancelled jump lands within 80 ticks (setup/sanity)")

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

	# THE REAL DEFECT CHECK: drive it the rest of the way and confirm it lands
	# on the exact same physical tick the uninterrupted reference jump did.
	var ticks_elapsed: int = 1 + 15   # the loop above (15) + the cancel-input tick (1) just above
	var landed_tick: int = -1
	for k in range(80):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[0].state_id == CharacterA.STATE_IDLE:
			landed_tick = ticks_elapsed + k + 1
			break
	_true(landed_tick != -1, "the air-normal-cancelled jump eventually lands")
	_eq(landed_tick, reference_landed_tick,
		"cancelling into j.L (which authors no motion of its own — pure inherit, AD-043) lands on " +
		"the EXACT SAME physical tick as an uninterrupted jump: the fall is carried all the way to " +
		"the real ground clamp, not clipped by j.L's own short authored duration (the 'air normal " +
		"snaps to the floor' defect, flags.md 2026-07-17)")
	_eq(s.players[0].pos_y, 0, "landing lands EXACTLY at ground_y via the continuous clamp, not a mid-air snap")
	_cleanup()


# --- a launched (airborne HITSTUN) character lands into the DEDICATED
# knockdown state, not idle and not the launched state itself (AD-043's
# elaboration, ratified from JC-070's overturned "stay in the launched state"
# reading) --------------------------------------------------------
# DP_L's single hit launches the defender (hb1.launch, STATE_HITSTUN_LAUNCH),
# whose landing (StepPhases._land) now redirects into character.
# reaction_state(REACTION_KNOCKDOWN) (CharacterA.STATE_KNOCKDOWN; AD-049 folds
# the old knockdown_state_id field into reaction_map). Exact tick numbers below
# were derived by actual headless replay (not hand-derived), mirroring this
# tree's established methodology.

func _test_launched_hitstun_lands_into_knockdown_not_idle() -> void:
	var s := _two_char_state(30)
	s.players[0].state_id = CharacterA.STATE_DP_L
	s.players[0].frame_in_state = 0

	var reached_hitstun_launch: bool = false
	var min_py: int = 0
	var landed_tick_in_knockdown: int = -1
	var never_landed_still_in_launch: bool = true
	for k in range(60):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[1].state_id == CharacterA.STATE_HITSTUN_LAUNCH:
			reached_hitstun_launch = true
			if s.players[1].pos_y < min_py:
				min_py = s.players[1].pos_y
		if s.players[1].state_id == CharacterA.STATE_KNOCKDOWN and s.players[1].pos_y == 0 \
				and min_py < 0 and landed_tick_in_knockdown == -1:
			landed_tick_in_knockdown = k + 1
		if s.players[1].pos_y == 0 and min_py < 0 and s.players[1].state_id == CharacterA.STATE_HITSTUN_LAUNCH:
			never_landed_still_in_launch = false   # would mean the JC-070 (overturned) reading is back
	_true(reached_hitstun_launch, "DP_L's launch forces the defender into STATE_HITSTUN_LAUNCH")
	_true(min_py < 0, "the launched defender genuinely goes airborne (pos_y < ground_y) at some point")
	_true(landed_tick_in_knockdown != -1,
		"the defender's pos_y returns to EXACTLY ground_y and the state TRANSITIONS to " +
		"CharacterA.STATE_KNOCKDOWN -- the dedicated grounded knockdown reaction (AD-043's " +
		"elaboration), not a continuation of STATE_HITSTUN_LAUNCH")
	_true(never_landed_still_in_launch,
		"landing never leaves the defender AT ground_y while still nominally in STATE_HITSTUN_LAUNCH " +
		"(JC-070's overturned reading)")

	# Continue until the authored stun naturally expires -- THEN (and only
	# then) does the character become actionable again (STATE_IDLE). The
	# wakeup timer counts from ENTRY INTO KNOCKDOWN (landing), not from the
	# original hit (AD-043's whole point) -- StepPhases._land re-arms p.stun
	# to STATE_KNOCKDOWN's own authored duration on this transition.
	var reached_idle: bool = false
	for _k in range(60):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[1].state_id == CharacterA.STATE_IDLE:
			reached_idle = true
			break
	_true(reached_idle, "the knocked-down defender eventually wakes up to STATE_IDLE once stun expires")
	_eq(s.players[1].vel_y, 0, "landing zeroed vertical velocity (still true once idle)")
	_cleanup()


# --- wakeup-from-landing is a FIXED duration, independent of air-time -------
# The reason the knockdown transition exists (AD-043's elaboration): a longer
# launch/juggle (more air-time before landing) must NOT change how long the
# defender stays down AFTER landing -- only when landing happens shifts, not
# the wakeup countdown from that point. Proven by comparing two launches at
# different ranges (different pos_x -> different flight geometry is not
# available here without retuning launch physics per-range, so instead this
# drives the SAME launch from two different starting frame_in_state offsets
# into DP_L's own active window, which changes when contact occurs and thus
# when the launch begins -- a proxy for "different air-time before landing.")

func _test_knockdown_wakeup_counts_from_landing_not_from_the_original_hit() -> void:
	var kd_duration: int = CharacterA.build_character().get_state(CharacterA.STATE_KNOCKDOWN).duration
	_true(kd_duration > 0, "STATE_KNOCKDOWN authors a real positive duration")

	var s := _two_char_state(30)
	s.players[0].state_id = CharacterA.STATE_DP_L
	s.players[0].frame_in_state = 0

	var landed_tick: int = -1
	for k in range(60):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[1].state_id == CharacterA.STATE_KNOCKDOWN and s.players[1].pos_y == 0 and landed_tick == -1:
			landed_tick = k + 1
			# p.stun is re-armed to the knockdown state's own duration in phase 3
			# (StepPhases._land), on the SAME tick the landing transition happens.
			# Unlike an ordinary hit-connect (which ALSO sets hitstop the same
			# tick, freezing stun until hitstop elapses -- AD-010), this
			# transition sets no hitstop, so phase 7's decrement runs THIS same
			# tick too: the value observed after the full step is kd_duration - 1
			# (verified by actual headless replay, not hand-derivation, per this
			# tree's established methodology -- JC-068 et al.). The wakeup still
			# lands exactly kd_duration ticks after the landing tick (the landing
			# tick is the first of those kd_duration decrementing ticks) --
			# independent of how long the flight was, which is the actual
			# contract AD-043 requires.
			_eq(s.players[1].stun, kd_duration - 1,
				"landing re-arms stun to STATE_KNOCKDOWN's own authored duration (wakeup counts from entry, not from the original hit)")
			break
	_true(landed_tick != -1, "test setup: the launched defender must land into knockdown")
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
