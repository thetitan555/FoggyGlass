extends SceneTree

## QA-owned determinism/serialization regression net for the P2 re-gate
## (2026-07-17). Tenet 1 is a hard gate regardless of which content lands it
## in a new state shape — this file closes the specific round-trip cases the
## re-gate's fix cycle introduced that the existing suite does not directly
## exercise:
##   - STATE_SLIDE_L / STATE_SLIDE_H (JC-112 sibling states; the existing
##     `_test_slide_mid_active_round_trip` in test_character_b_air.gd only
##     ever drove the unchanged M-strength STATE_SLIDE).
##   - A divekick's landing-recovery state (AD-050's new
##     `MoveState.landing_state_id` redirect) — a state shape that did not
##     exist before this cycle.
##   - STATE_AIR_RESET (B's new AD-049 catch-up reaction) mid-stun.
##   - A full match round-tripped THROUGH an entire sudden-death cycle to
##     MATCH_END — the exact path AD-048's sudden-death fix (82fb2a4) made
##     reachable; the existing full-match golden/determinism proofs use a
##     KO+timeout script that never enters sudden death.
##
## Each case: snapshot mid-state, restore, confirm identical canonical hash,
## then confirm CONTINUING both the original and the restored copy for
## several more ticks (through to the state's own resolution, not just one
## tick) produces identical hashes throughout — the harder bar than a single
## post-restore tick, consistent with this suite's own established
## convention (`_test_divekick_mid_flight_round_trip` et al.).
##
## Run:  godot --headless --path game -s res://tests/test_qa_p2_regate_determinism.gd

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	ProjectileRegistry.clear()
	if _failures == 0:
		print("[test_qa_p2_regate_determinism] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_qa_p2_regate_determinism] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	_test_slide_l_mid_active_round_trip()
	_test_slide_h_mid_active_round_trip()
	_test_divekick_landing_recovery_round_trip()
	_test_air_reset_mid_stun_round_trip()
	_test_full_sudden_death_cycle_round_trip()


# -----------------------------------------------------------------------------
# Setup helpers (mirror test_character_b_air.gd / test_match_state.gd conventions)
# -----------------------------------------------------------------------------

func _install_b() -> void:
	MoveRegistry.install({CharacterB.CHAR_ID: CharacterB.build_character()})


func _cleanup() -> void:
	MoveRegistry.clear()
	ProjectileRegistry.clear()


func _two_char_state_b(gap_units: int = 40) -> SimState:
	_install_b()
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-800), FP.from_int(800), 0)
	s.players[0].character_id = CharacterB.CHAR_ID
	s.players[0].state_id = CharacterB.STATE_IDLE
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = CharacterB.CHAR_ID
	s.players[1].state_id = CharacterB.STATE_IDLE
	s.players[1].pos_x = FP.from_int(gap_units)
	s.players[1].facing = -1
	return s


## Round-trip a mid-state SimState: snapshot, restore, confirm equal hash, then
## continue both for `settle_ticks` more real steps and confirm the hash
## trajectories stay identical the whole way (not just immediately post-restore).
func _assert_round_trip_settles(s: SimState, label: String, settle_ticks: int = 20) -> void:
	var hash_before: int = s.hash_state()
	var blob: Dictionary = s.to_dict()
	var restored: SimState = SimState.from_dict(blob)
	_eq(restored.hash_state(), hash_before, "%s: snapshot restores to an identical canonical hash" % label)
	var orig := s
	var rest := restored
	for k in range(settle_ticks):
		orig = SimState.step(orig, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		rest = SimState.step(rest, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		_eq(rest.hash_state(), orig.hash_state(), "%s: restored copy matches original hash at settle-tick %d" % [label, k + 1])


# -----------------------------------------------------------------------------
# STATE_SLIDE_L / STATE_SLIDE_H mid-active round trip (JC-112 sibling states).
# -----------------------------------------------------------------------------

func _test_slide_l_mid_active_round_trip() -> void:
	var s := _two_char_state_b(95)
	s.players[0].state_id = CharacterB.STATE_SLIDE_L
	s.players[0].frame_in_state = CharacterB.SLIDE_STARTUP   # entering the active window next tick
	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.DOWN | InputFrame.RIGHT)
	_eq(s.players[0].state_id, CharacterB.STATE_SLIDE_L, "still in STATE_SLIDE_L (setup)")
	_assert_round_trip_settles(s, "mid-active STATE_SLIDE_L")
	_cleanup()


func _test_slide_h_mid_active_round_trip() -> void:
	var s := _two_char_state_b(95)
	s.players[0].state_id = CharacterB.STATE_SLIDE_H
	s.players[0].frame_in_state = CharacterB.SLIDE_STARTUP
	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.DOWN | InputFrame.RIGHT)
	_eq(s.players[0].state_id, CharacterB.STATE_SLIDE_H, "still in STATE_SLIDE_H (setup)")
	_assert_round_trip_settles(s, "mid-active STATE_SLIDE_H")
	_cleanup()


# -----------------------------------------------------------------------------
# Divekick landing-recovery state round trip (AD-050's new
# MoveState.landing_state_id redirect target — a state shape that did not
# exist before this cycle). Drives the M divekick into the ground for real
# (not a direct state injection) so the round trip covers the actual _land
# precedence resolution, then snapshots mid-recovery.
# -----------------------------------------------------------------------------

func _test_divekick_landing_recovery_round_trip() -> void:
	var s := _two_char_state_b(300)
	for _k in range(20):
		s = SimState.step(s, InputFrame.UP, InputFrame.NEUTRAL)
	for _k in range(60):
		s = SimState.step(s, InputFrame.DOWN | InputFrame.BUTTON_1, InputFrame.NEUTRAL)
		if s.players[0].state_id == CharacterB.STATE_DIVEKICK_M:
			break
	_eq(s.players[0].state_id, CharacterB.STATE_DIVEKICK_M, "reached M divekick (setup)")
	var reached_recovery: bool = false
	for _k in range(120):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[0].state_id == CharacterB.STATE_DIVEKICK_M_LANDING:
			reached_recovery = true
			break
	_true(reached_recovery, "landed into the M divekick's landing-recovery state (setup, AD-050)")
	if not reached_recovery:
		_cleanup()
		return
	_assert_round_trip_settles(s, "mid-divekick-landing-recovery (STATE_DIVEKICK_M_LANDING)")
	_cleanup()


# -----------------------------------------------------------------------------
# STATE_AIR_RESET mid-stun round trip (B's new AD-049 catch-up reaction —
# authored this cycle specifically because A's 2H inflicts a kind B never
# needed before). Direct-injection setup (mirrors this suite's own established
# hand-driven-state convention for reaction states), since the point here is
# the round trip through the state, not re-proving the hit resolves it
# (test_reaction_map.gd already does that behaviorally).
# -----------------------------------------------------------------------------

func _test_air_reset_mid_stun_round_trip() -> void:
	var s := _two_char_state_b(40)
	s.players[1].state_id = CharacterB.STATE_AIR_RESET
	s.players[1].frame_in_state = 3
	s.players[1].stun = 5
	s.players[1].stun_kind = PlayerView.STUN_HIT
	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(s.players[1].state_id, CharacterB.STATE_AIR_RESET, "still in STATE_AIR_RESET (setup)")
	_assert_round_trip_settles(s, "mid-stun STATE_AIR_RESET", 30)
	_cleanup()


# -----------------------------------------------------------------------------
# Full sudden-death cycle round trip (the exact path AD-048's fix, 82fb2a4,
# made reachable). Snapshots mid-ACTIVE inside the sudden-death round itself,
# restores, and confirms BOTH copies resolve identically all the way through
# to MATCH_END — not just that the phase machine transitions correctly
# (test_match_state.gd's own test proves that), but that a snapshot taken
# INSIDE a sudden-death round round-trips like any other match state.
# -----------------------------------------------------------------------------

func _test_full_sudden_death_cycle_round_trip() -> void:
	# Enter sudden death for real: a double-KO with both players already at 1
	# win pushes both to threshold together (mirrors test_match_state.gd).
	var ms := MatchState.new_match(TestSupport.CHAR_ID, TestSupport.CHAR_ID, 1)
	ms = ms.clone()
	ms.match_phase = MatchState.PHASE_ACTIVE
	ms.round_timer = 3000
	ms.round_wins[0] = 1
	ms.round_wins[1] = 1
	ms.sim.players[0].health = 0
	ms.sim.players[1].health = 0
	ms = MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	for i in range(MatchState.ROUND_END_BEAT_TICKS):
		ms = MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(ms.sudden_death, "entered sudden death (setup)")
	for i in range(MatchState.ROUND_START_BEAT_TICKS):
		ms = MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(ms.match_phase, MatchState.PHASE_ACTIVE, "sudden-death round is ACTIVE (setup)")

	# Step a few real ticks INSIDE the sudden-death round, THEN snapshot —
	# the case that matters is round-tripping a mid-sudden-death sim, not the
	# ROUND_START beat boundary itself.
	for i in range(10):
		ms = MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	var hash_before: int = ms.hash_state()
	var blob: Dictionary = ms.to_dict()
	var restored: MatchState = MatchState.from_dict(blob)
	_eq(restored.hash_state(), hash_before, "mid-sudden-death MatchState snapshot restores to an identical canonical hash")
	_true(restored.sudden_death, "restored copy still reads sudden_death=true")

	# Drive BOTH the original and the restored copy through an outright KO
	# and the ROUND_END beat, and confirm both independently reach MATCH_END
	# with identical hashes at every tick along the way.
	var orig := ms
	var rest := restored
	orig = orig.clone()
	orig.sim.players[1].health = 0
	rest = rest.clone()
	rest.sim.players[1].health = 0
	for i in range(1 + MatchState.ROUND_END_BEAT_TICKS + 5):
		orig = MatchState.match_step(orig, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		rest = MatchState.match_step(rest, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		_eq(rest.hash_state(), orig.hash_state(), "sudden-death resolution tick %d: restored matches original" % i)
	_eq(orig.match_phase, MatchState.PHASE_MATCH_END, "the original run reaches MATCH_END through sudden death (setup/sanity)")
	_eq(rest.match_phase, MatchState.PHASE_MATCH_END, "the restored-and-resumed run ALSO reaches MATCH_END identically")
