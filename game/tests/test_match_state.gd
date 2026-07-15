extends SceneTree

## Headless tests for the match layer: MatchState + match_step + MatchView
## (TKT-P2-07, AD-048, match-flow.md criteria 1-8).
##
## Run:  godot --headless --path game -s res://tests/test_match_state.gd
## Exits non-zero on any failure so a harness/CI can gate on it.
##
## Criteria covered here (match-flow.md):
##   1 Deterministic per match  — a full match (>=2 rounds, a KO, a timeout)
##                                 serialized mid-match, restored, and resumed
##                                 yields the same final MatchState hash as the
##                                 uninterrupted run.
##   2 `step` untouched          — match_step calls SimState.step with its
##                                 signature unchanged (structural: every call
##                                 site in match_state.gd passes exactly
##                                 (sim, in_p1, in_p2), exercised throughout).
##   3 KO resolution             — health <= 0 ends the round (KO); simultaneous
##                                 both-to-zero -> DOUBLE_KO, awarded to both.
##   4 Timeout resolution        — round_timer == 0 -> higher health wins;
##                                 equal health -> both (tie).
##   5 Scoring + match end       — first to 2 round wins -> MATCH_END; a tie
##                                 pushing both to 2 -> one sudden_death round.
##   6 Legibility (seam)         — MatchView exposes health/round_wins/timer/
##                                 phase/reason as serialized truth.
##   7 Round reset               — ROUND_START restores fresh symmetric
##                                 positions/health, hash-comparable to an
##                                 independently-built canonical fresh-round state.
##   8 No new combat / no float  — MatchState's serialized graph is float-free.
##
## Some preconditions (a KO's zero health, a round's timeout) are INJECTED
## directly onto a cloned MatchState between match_step calls rather than
## produced by a slow, fully-authored combo/real-time-timeout script — the
## SAME "spot-mutate a clone, then exercise the real transition logic" economy
## test_sim_state.gd's _test_hash_sensitivity already uses. The state-machine
## code under test (scoring, phase transitions, reset, hashing) always runs for
## real through match_step; only the precipitating health/timer VALUE is
## injected, documented at each call site below.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()   # test isolation (matches test_sim_state's convention)
	if _failures == 0:
		print("[test_match_state] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_match_state] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	_test_new_match_shape()
	_test_no_combat_advance_outside_active()
	_test_round_start_transitions_to_active_after_beat()
	_test_active_calls_step_and_decrements_timer()
	_test_ko_ends_round()
	_test_double_ko_awards_both()
	_test_timeout_higher_health_wins()
	_test_timeout_equal_health_ties()
	_test_match_end_on_threshold()
	_test_sudden_death_on_simultaneous_threshold()
	_test_round_reset_matches_canonical_fresh_round()
	_test_match_view_legibility()
	_test_purity_and_non_mutation()
	_test_serialization_round_trip()
	_test_no_floats()
	_test_full_match_determinism_round_trip()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## An ACTIVE-phase MatchState with the given health/timer/round-wins, built by
## cloning a real new_match() and overriding fields directly — the isolated
## KO/timeout/scoring unit tests below exercise the transition logic in
## isolation from the ROUND_START beat, matching test_sim_state.gd's own
## direct-field-injection convention.
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


# ---------------------------------------------------------------------------
# Shape / construction
# ---------------------------------------------------------------------------

func _test_new_match_shape() -> void:
	var ms := MatchState.new_match(TestSupport.CHAR_ID, TestSupport.CHAR_ID, 0)
	_eq(ms.match_phase, MatchState.PHASE_ROUND_START, "a new match starts in ROUND_START")
	_eq(ms.phase_timer, MatchState.ROUND_START_BEAT_TICKS, "ROUND_START beat starts at its full length")
	_eq(ms.round_wins[0], 0, "no round wins yet (p0)")
	_eq(ms.round_wins[1], 0, "no round wins yet (p1)")
	_eq(ms.round_index, 0, "round index starts at 0")
	_true(not ms.sudden_death, "not in sudden death at match start")
	_eq(ms.round_timer, MatchState.ROUND_LENGTH_TICKS, "round timer starts at the full round length")
	_eq(ms.sim.players[0].health, MatchState.FULL_HEALTH, "p0 starts at full health")
	_eq(ms.sim.players[1].health, MatchState.FULL_HEALTH, "p1 starts at full health")
	_true(ms.sim.players[0].pos_x < ms.sim.players[1].pos_x, "p0 starts left of p1 (symmetric start)")


func _test_no_combat_advance_outside_active() -> void:
	var ms := MatchState.new_match(TestSupport.CHAR_ID, TestSupport.CHAR_ID, 9)
	var tick_before: int = ms.sim.tick
	var next := MatchState.match_step(ms, InputFrame.RIGHT, InputFrame.LEFT)
	_eq(next.sim.tick, tick_before, "sim.tick does not advance during ROUND_START (combat not advanced)")
	_eq(next.match_phase, MatchState.PHASE_ROUND_START, "still in ROUND_START (beat not yet elapsed)")
	_eq(next.phase_timer, ms.phase_timer - 1, "the ROUND_START beat itself does count down")


func _test_round_start_transitions_to_active_after_beat() -> void:
	var ms := MatchState.new_match(TestSupport.CHAR_ID, TestSupport.CHAR_ID, 3)
	for i in range(MatchState.ROUND_START_BEAT_TICKS):
		ms = MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(ms.match_phase, MatchState.PHASE_ACTIVE, "ROUND_START beat elapsed -> ACTIVE")
	_eq(ms.sim.tick, 0, "sim.tick is still 0 -- combat had not advanced during the whole beat")


func _test_active_calls_step_and_decrements_timer() -> void:
	var ms := _active_match_state(500, 500, 100)
	var next := MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(next.sim.tick, ms.sim.tick + 1, "ACTIVE calls SimState.step (sim.tick advances)")
	_eq(next.round_timer, ms.round_timer - 1, "ACTIVE decrements round_timer")
	_eq(next.match_phase, MatchState.PHASE_ACTIVE, "no round-ending condition -> stays ACTIVE")


# ---------------------------------------------------------------------------
# KO / timeout / scoring (match-flow.md criteria 3, 4, 5)
# ---------------------------------------------------------------------------

func _test_ko_ends_round() -> void:
	# health injected directly (see file header) -- the KO/scoring transition
	# below runs for real.
	var ms := _active_match_state(500, 0, 3000)
	var next := MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(next.last_round_end_reason, MatchState.REASON_KO, "health<=0 resolves as KO")
	_eq(next.round_wins[0], 1, "the surviving player is awarded the round")
	_eq(next.round_wins[1], 0, "the KO'd player is not awarded the round")
	_eq(next.match_phase, MatchState.PHASE_ROUND_END, "a KO moves the round to ROUND_END")
	_eq(next.phase_timer, MatchState.ROUND_END_BEAT_TICKS, "ROUND_END beat starts at its full length")


func _test_double_ko_awards_both() -> void:
	var ms := _active_match_state(0, 0, 3000)
	var next := MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(next.last_round_end_reason, MatchState.REASON_DOUBLE_KO, "simultaneous zero health is a DOUBLE_KO")
	_eq(next.round_wins[0], 1, "double-KO awards the round to p0 too")
	_eq(next.round_wins[1], 1, "double-KO awards the round to p1 too")
	_eq(next.match_phase, MatchState.PHASE_ROUND_END, "a double-KO moves the round to ROUND_END")


func _test_timeout_higher_health_wins() -> void:
	# round_timer injected to 1 so the ACTIVE decrement lands it on 0 this tick.
	var ms := _active_match_state(600, 300, 1)
	var next := MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(next.round_timer, 0, "timer reaches exactly 0")
	_eq(next.last_round_end_reason, MatchState.REASON_TIMEOUT, "timer==0 resolves as TIMEOUT")
	_eq(next.round_wins[0], 1, "higher-health player (p0) wins the round on timeout")
	_eq(next.round_wins[1], 0, "lower-health player (p1) does not win the round")


func _test_timeout_equal_health_ties() -> void:
	var ms := _active_match_state(400, 400, 1)
	var next := MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(next.last_round_end_reason, MatchState.REASON_TIMEOUT, "timer==0 resolves as TIMEOUT")
	_eq(next.round_wins[0], 1, "equal-health timeout awards the round to p0 too")
	_eq(next.round_wins[1], 1, "equal-health timeout awards the round to p1 too")


func _test_match_end_on_threshold() -> void:
	var ms := _active_match_state(500, 0, 3000, 1, 0)   # p0 already has 1 win
	var next := MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(next.round_wins[0], 2, "the KO pushes p0 to the match-win threshold")
	for i in range(MatchState.ROUND_END_BEAT_TICKS):
		next = MatchState.match_step(next, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(next.match_phase, MatchState.PHASE_MATCH_END, "2 round wins ends the match")
	_true(not next.sudden_death, "a clean single-winner match end is not sudden death")


func _test_sudden_death_on_simultaneous_threshold() -> void:
	var ms := _active_match_state(0, 0, 3000, 1, 1)   # both already at 1 win
	var next := MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(next.round_wins[0], 2, "the double-KO pushes p0 to threshold")
	_eq(next.round_wins[1], 2, "the double-KO pushes p1 to threshold too, simultaneously")
	for i in range(MatchState.ROUND_END_BEAT_TICKS):
		next = MatchState.match_step(next, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(next.sudden_death, "a simultaneous tie at match point triggers sudden death")
	_eq(next.match_phase, MatchState.PHASE_ROUND_START, "sudden death is one more round, not MATCH_END")
	_eq(next.round_index, 1, "round index advances into the sudden-death round")


# ---------------------------------------------------------------------------
# Round reset (match-flow.md criterion 7)
# ---------------------------------------------------------------------------

func _test_round_reset_matches_canonical_fresh_round() -> void:
	MoveRegistry.install(TestSupport.build_roster())
	var ms := MatchState.new_match(TestSupport.CHAR_ID, TestSupport.CHAR_ID, 42)
	for i in range(MatchState.ROUND_START_BEAT_TICKS):
		ms = MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	# A few real ACTIVE ticks so tick/rng have genuinely moved -- a non-trivial
	# reset target, not a coincidental match against a still-zero clock.
	for i in range(4):
		ms = MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	# Inject the KO precondition (see file header), then let the real KO/
	# scoring/reset transition run.
	ms = ms.clone()
	ms.sim.players[1].health = 0
	ms = MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(ms.match_phase, MatchState.PHASE_ROUND_END, "round 1 ends on the injected KO")
	for i in range(MatchState.ROUND_END_BEAT_TICKS):
		ms = MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(ms.match_phase, MatchState.PHASE_ROUND_START, "round 2 begins in a fresh ROUND_START")
	_eq(ms.round_index, 1, "round index advanced into round 2")

	# The independently-built canonical comparison state (criterion 7): same
	# character ids, and the SAME tick/rng/stage the transition actually
	# carried forward.
	var canonical: SimState = MatchState.fresh_round_sim(
		TestSupport.CHAR_ID, TestSupport.CHAR_ID, ms.sim.tick, ms.sim.rng, ms.sim.stage)
	_eq(ms.sim.hash_state(), canonical.hash_state(),
		"the round-start reset produces exactly the canonical fresh-round state")
	_eq(ms.round_timer, MatchState.ROUND_LENGTH_TICKS, "round timer reset to the full round length")
	_eq(ms.sim.players[0].health, MatchState.FULL_HEALTH, "p0 health reset to full")
	_eq(ms.sim.players[1].health, MatchState.FULL_HEALTH, "p1 health reset to full")
	MoveRegistry.clear()


# ---------------------------------------------------------------------------
# MatchView legibility (match-flow.md criterion 6 / inspection-surface.md 7)
# ---------------------------------------------------------------------------

func _test_match_view_legibility() -> void:
	var ms := _active_match_state(700, 0, 3000, 1, 0)
	var next := MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	var view := MatchView.new(next)
	_eq(view.health[0], 700, "MatchView exposes p0 health")
	_eq(view.health[1], 0, "MatchView exposes p1 health")
	_eq(view.round_wins[0], 2, "MatchView exposes round wins")
	_eq(view.match_phase, MatchState.PHASE_ROUND_END, "MatchView exposes the current match phase")
	_eq(view.last_round_end_reason, MatchState.REASON_KO, "MatchView exposes WHY the round ended, as serialized truth")


# ---------------------------------------------------------------------------
# Purity / non-mutation / serialization / floats
# ---------------------------------------------------------------------------

func _test_purity_and_non_mutation() -> void:
	var ms := MatchState.new_match(TestSupport.CHAR_ID, TestSupport.CHAR_ID, 5)
	var before: int = ms.hash_state()
	var a: int = InputFrame.RIGHT
	var b: int = InputFrame.LEFT
	var next1 := MatchState.match_step(ms, a, b)
	_eq(ms.hash_state(), before, "match_step did not mutate its input (hash(prev) unchanged)")
	_true(next1 != ms, "match_step returns a distinct object")
	var next2 := MatchState.match_step(ms, a, b)
	_eq(next1.hash_state(), next2.hash_state(), "match_step(ms,a,b) twice yields identical hashes (purity)")


func _test_serialization_round_trip() -> void:
	MoveRegistry.install(TestSupport.build_roster())
	var ms := MatchState.new_match(TestSupport.CHAR_ID, TestSupport.CHAR_ID, 123)
	for i in range(10):
		ms = MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	var h_before: int = ms.hash_state()
	var dumped: Dictionary = ms.to_dict()
	var restored: MatchState = MatchState.from_dict(dumped)
	_eq(restored.hash_state(), h_before, "serialize->restore reproduces an identical MatchState hash")
	var restored2: MatchState = MatchState.from_dict(restored.to_dict())
	_eq(restored2.hash_state(), h_before, "double round-trip is stable")
	MoveRegistry.clear()


func _test_no_floats() -> void:
	MoveRegistry.install(TestSupport.build_roster())
	var ms := MatchState.new_match(TestSupport.CHAR_ID, TestSupport.CHAR_ID, 7)
	for i in range(5):
		ms = MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	var d: Dictionary = ms.to_dict()
	_true(not _has_float(d), "serialized MatchState contains no float value anywhere (criterion 8)")
	MoveRegistry.clear()


# ---------------------------------------------------------------------------
# Full-match determinism round trip (match-flow.md criterion 1 — the per-match
# proof P2 is for).
# ---------------------------------------------------------------------------

## A fixed, fully deterministic script: ROUND_START beat -> a few real ACTIVE
## ticks -> an injected KO (round 1, reason KO) -> ROUND_END beat -> round 2's
## ROUND_START beat -> a few real ACTIVE ticks -> an injected near-timeout
## (round 2, reason TIMEOUT, decided by an injected health gap) -> ROUND_END
## beat -> MATCH_END -> a couple of terminal no-op ticks. Two full rounds,
## one KO, one timeout, ending in a legible 2-0 match win — criterion 1's
## "whole match, >=2 rounds, a KO, and a timeout."
func _full_match_script() -> Array:
	var script: Array = []
	for i in range(MatchState.ROUND_START_BEAT_TICKS):
		script.append(["step"])
	for i in range(5):
		script.append(["step"])
	script.append(["inject_health", 1, 0])         # round 1: p1 KO'd
	script.append(["step"])
	for i in range(MatchState.ROUND_END_BEAT_TICKS):
		script.append(["step"])
	for i in range(MatchState.ROUND_START_BEAT_TICKS):
		script.append(["step"])
	for i in range(5):
		script.append(["step"])
	script.append(["inject_health", 1, 900])       # round 2: p1 takes some damage
	script.append(["inject_timer", 1])             # round 2: timer about to expire
	script.append(["step"])                        # timer hits 0 -> TIMEOUT, p0 (full hp) wins
	for i in range(MatchState.ROUND_END_BEAT_TICKS):
		script.append(["step"])
	for i in range(3):
		script.append(["step"])                    # MATCH_END: a few terminal no-ops
	return script


func _apply_action(ms: MatchState, action: Array) -> MatchState:
	match action[0]:
		"step":
			return MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		"inject_health":
			var m2 := ms.clone()
			m2.sim.players[action[1]].health = action[2]
			return m2
		"inject_timer":
			var m2 := ms.clone()
			m2.round_timer = action[1]
			return m2
		_:
			return ms


func _run_script(start: MatchState, script: Array, from_idx: int, to_idx: int) -> MatchState:
	var ms := start
	for i in range(from_idx, to_idx):
		ms = _apply_action(ms, script[i])
	return ms


func _test_full_match_determinism_round_trip() -> void:
	MoveRegistry.install(TestSupport.build_roster())
	var script := _full_match_script()

	var uninterrupted := MatchState.new_match(TestSupport.CHAR_ID, TestSupport.CHAR_ID, 777)
	uninterrupted = _run_script(uninterrupted, script, 0, script.size())
	_eq(uninterrupted.match_phase, MatchState.PHASE_MATCH_END, "the scripted match reaches MATCH_END")
	_eq(uninterrupted.round_wins[0], 2, "p0 wins the match 2-0")
	_eq(uninterrupted.round_wins[1], 0, "p1 does not win a round")
	_eq(uninterrupted.last_round_end_reason, MatchState.REASON_TIMEOUT, "the match-deciding round ends in TIMEOUT")
	_true(not uninterrupted.sudden_death, "a clean 2-0 match is not sudden death")
	var gold: int = uninterrupted.hash_state()

	# Interrupted: run to a snapshot point PARTWAY THROUGH round 1's ACTIVE
	# ticks (before the round-1 KO injection), serialize, restore, and resume
	# the SAME remaining script from the restored state.
	var split: int = MatchState.ROUND_START_BEAT_TICKS + 3
	var interrupted := MatchState.new_match(TestSupport.CHAR_ID, TestSupport.CHAR_ID, 777)
	interrupted = _run_script(interrupted, script, 0, split)
	var snapshot: Dictionary = interrupted.to_dict()
	interrupted = MatchState.from_dict(snapshot)
	interrupted = _run_script(interrupted, script, split, script.size())
	_eq(interrupted.hash_state(), gold,
		"mid-match snapshot/restore/resume reproduces the identical final MatchState hash (criterion 1)")

	MoveRegistry.clear()
