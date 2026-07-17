class_name MatchState
extends RefCounted

## The 1v1 match layer (match-flow.md, AD-048). Wraps SimState with round/match
## bookkeeping and is advanced by the pure `match_step(match_state, in_p1, in_p2)`,
## itself layered ABOVE `SimState.step` — whose signature stays untouched
## (AD-024/AD-048; simulation.md criterion 2 of match-flow.md).
##
## Tenet 1 holds per MATCH, not just per frame: every match field below is
## serialized, deep-cloned, and canonically hashed with the same discipline as
## SimState (AD-023), composed with SimState's own hash. No wall-clock, no
## `_process`, no `delta` drives the round timer or any transition — everything
## here is frame-counted, serialized game state (match-flow.md "The constraint
## this brief exists to protect").
##
## SHAPE (match-flow.md → "MatchState shape").
##   sim                    — the wrapped SimState (carries per-player `health`,
##                             the combat truth this layer reads but never
##                             re-derives).
##   round_wins[2]          — per-player round wins (the pips).
##   round_timer            — frames remaining in the round; counts down on the
##                             fixed tick during ACTIVE only.
##   round_index            — which round (best-of / sudden-death).
##   match_phase            — ROUND_START / ACTIVE / ROUND_END / MATCH_END.
##   sudden_death           — true while the tie-at-match-point final round is
##                             live.
##   phase_timer            — deterministic transition counter for the
##                             non-ACTIVE phases.
##   last_round_end_reason  — KO / TIMEOUT / DOUBLE_KO / NONE — serialized truth,
##                             so *why* a round ended is legible on its face, not
##                             a render inference.
##
## RNG reuses SimState.rng (carried, never reset per round — the slice draws
## none, but the seed lives in serialized state regardless, Tenet 1).

# --- match_phase values (match-flow.md → "The round/match state machine") ----
const PHASE_ROUND_START: int = 0
const PHASE_ACTIVE: int = 1
const PHASE_ROUND_END: int = 2
const PHASE_MATCH_END: int = 3

# --- last_round_end_reason values --------------------------------------------
const REASON_NONE: int = 0
const REASON_KO: int = 1
const REASON_TIMEOUT: int = 2
const REASON_DOUBLE_KO: int = 3

# --- Rules (match-flow.md → "Rules (defaults)"; JC-073) ----------------------
## First to this many round wins takes the match (best-of-3).
const ROUND_WIN_THRESHOLD: int = 2

## Round length in frames: ~99 in-game seconds @ 60 Hz (match-flow.md's own
## stated default), frame-counted per Tenet 1. JC-073.
const ROUND_LENGTH_TICKS: int = 5940

## Transition-beat lengths — a plain, unproduced "ready"/"result" beat, not
## presentation (brief: "no produced intro"). Provisional feel; JC-073.
const ROUND_START_BEAT_TICKS: int = 60
const ROUND_END_BEAT_TICKS: int = 90

## Tuned full health (match-flow.md "Health"; TKT-P2-08; JC-096). Replaces the
## prior 1000 placeholder (which only mirrored SimState.new_initial()'s OWN
## untuned P0 scaffold value, "data, not feel" — that scaffold default is left
## alone; it backs unrelated P0/P1 sandbox tests against the generic test
## character, not this match layer's real health).
##
## TUNED AGAINST BOTH CHARACTERS' AUTHORED DAMAGE (character-a.md / character-
## b.md's own `hb.damage` values, game/content/character_{a,b}.gd) so "a couple
## of good touches decide a round" (match-flow.md's own stated target) holds for
## BOTH sides of the matchup, not just whichever character hits harder:
##   - A's real hit-confirmed combos land in the 180-270 range (e.g.
##     2M(70) xx DP-M(130 scaled ~90% ~117) ~= 187; a deep jump-in
##     jH(80) -> 2M(70*.9~63) xx DP-H(160*.8~128) ~= 271) — one or two such
##     combos should plausibly close a round.
##   - B has no comparable single-move payoff (2H's launch has no juggle
##     follow-up, matching A's own 2H; B's damage lives in its LADDER): B's own
##     spec-given worked example, the full ladder
##     `5L 2L 2L 5M 2M 2H 5H` (character-b.md "Cancel model"), scaled hit-by-hit
##     (DamageScaling, 10%-step/10%-floor) totals ~155-160 — B's own
##     "couple of good touches" is 2-3 such landed strings, not one.
## 500 is the value where BOTH readings land in "a couple" (2-3 real
## hit-confirmed touches, not a long footsie/poke grind): A's best single combo
## is ~half of 500 (two touches plausibly close it out); B's full-ladder BnB is
## ~30% of 500 (three such strings close it out). A single uncomboed poke
## (B's 5L=20, A's 5L=30) alone still needs ~15-25 hits to kill — deliberately
## NOT a fast poke-race, so combo/confirm play (not thirty pokes) is what
## actually decides a round, per the brief. A round, clean number (matches a
## health BAR reading cleanly at quarter/half marks) rather than an arbitrary
## back-solved value. Provisional — a feel value, tunable at the human gate
## like every other slice-provisional number (character-b.md's own header).
const FULL_HEALTH: int = 500

## Top-level format-version stamp for the WRAPPER shape (AD-034 "extends to the
## wrapper" — match-flow.md). Governs MatchState's own fields; the nested `sim`
## dict carries SimState's OWN "v" independently (no sub-object carries a
## redundant version, per AD-034's own rule — this is the wrapper's version, not
## a duplicate of the sim's).
const FORMAT_VERSION: int = 1

var sim: SimState = null
var round_wins: PackedInt32Array = PackedInt32Array([0, 0])
var round_timer: int = 0
var round_index: int = 0
var match_phase: int = PHASE_ROUND_START
var sudden_death: bool = false
var phase_timer: int = 0
var last_round_end_reason: int = REASON_NONE


func _init() -> void:
	# A bare MatchState is not yet a valid initial match — use new_match() to
	# build a runnable one. Keeps sub-objects non-null so clone()/to_dict() are
	# safe even on a default-constructed instance (mirrors SimState's own _init).
	sim = SimState.new()


## Build a valid initial match: round 0, ROUND_START (a fresh round already
## built, matching what a ROUND_START->ROUND_START reset would produce), no
## round wins, no sudden death. Fixed A-vs-B side assignment is a WIRING
## CONSTANT (match-flow.md) — the caller supplies which `character_id` sits on
## each side; this layer does not choose it.
static func new_match(char_id_p1: int, char_id_p2: int, p_seed: int = 0) -> MatchState:
	var ms := MatchState.new()
	ms.sim = fresh_round_sim(char_id_p1, char_id_p2, 0, RngState.new(p_seed), StageState.new_initial())
	ms.round_wins = PackedInt32Array([0, 0])
	ms.round_timer = ROUND_LENGTH_TICKS
	ms.round_index = 0
	ms.match_phase = PHASE_ROUND_START
	ms.sudden_death = false
	ms.phase_timer = ROUND_START_BEAT_TICKS
	ms.last_round_end_reason = REASON_NONE
	return ms


## Build the canonical "fresh round" SimState: both players reset to symmetric
## starting positions and full health (facing each other), no projectiles, no
## last_hit, cleared per-move counters — everything a round-start reset touches.
## `tick`/`rng`/`stage` are CARRIED, not reset (the match's clock and RNG seed
## are match-wide per Tenet 1, not per-round; the arena doesn't change either).
## `character_id` per side is a parameter, not chosen here (AD-048 wiring
## constant lives at the caller). Deliberately mirrors SimState.new_initial()'s
## own placeholder spawn geometry rather than calling it, so the match layer
## does not couple SimState's P0 constructor to a match-layer concern (it takes
## no character-id/tick/rng/stage parameters and isn't meant to grow them for
## this).
##
## PUBLIC (not `_`-prefixed) so both `MatchState` itself and a test/QA harness
## can build the independent "canonical fresh-round state" match-flow.md
## criterion 7 calls for, to hash-compare against an actual in-match transition.
static func fresh_round_sim(char_id_p1: int, char_id_p2: int, p_tick: int, p_rng: RngState, p_stage: StageState) -> SimState:
	var s := SimState.new()
	s.tick = p_tick
	s.rng = p_rng.clone()
	s.stage = p_stage.clone()

	var p1 := PlayerState.new()
	p1.pos_x = FP.from_int(-100)
	p1.pos_y = s.stage.ground_y
	p1.facing = 1
	p1.health = FULL_HEALTH
	p1.character_id = char_id_p1
	p1.state_id = _idle_state_id(char_id_p1)

	var p2 := PlayerState.new()
	p2.pos_x = FP.from_int(100)
	p2.pos_y = s.stage.ground_y
	p2.facing = -1
	p2.health = FULL_HEALTH
	p2.character_id = char_id_p2
	p2.state_id = _idle_state_id(char_id_p2)

	var ps: Array[PlayerState] = [p1, p2]
	s.players = ps
	s.projectiles = []
	s.last_hit = null
	s.neutral_restored_this_tick = false
	return s


## TKT-P2-08 integration fix (found while wiring the real A-vs-B match; logged
## docs/judgment-log.md). A bare `PlayerState` defaults `state_id = 0` — fine
## for `TestSupport`'s own P0 test character (its idle state IS id 0, by
## convention), but WRONG for a real character (A's idle is 100, B's is 300):
## every ROUND_START would park both players on an unresolvable state_id, the
## same class of defect TKT-P1.1-01 Part A already fixed once for the sandbox
## training-mode path (`training_mode.gd._init_players_as_installed_character`).
## Resolves through `MoveRegistry` — the SAME single source of truth every
## other character-id -> state lookup in this codebase already uses — so a
## round start lands the character on its OWN authored idle, whatever that id
## is. Falls back to `0` when the roster has no entry for `char_id` (no
## installed roster at all, e.g. many of this file's own unit tests that never
## call `MoveRegistry.install()` first) — identical to the prior UNRESOLVED
## behavior in that case, so every existing match-layer test's hash is
## unaffected (TestSupport.CHAR_ID's idle IS 0 wherever a roster happens to be
## installed too, so this is a strict no-op for every already-green test; only
## a REAL, non-test character actually observes a different value).
static func _idle_state_id(char_id: int) -> int:
	var character: Character = MoveRegistry.character(char_id)
	return character.idle_state_id if character != null else 0


## Deep copy (mirrors SimState.clone's non-mutation discipline, AD-004 applied
## at the match layer — match_step must not mutate its input either).
func clone() -> MatchState:
	var ms := MatchState.new()
	ms.sim = sim.clone()
	ms.round_wins = round_wins.duplicate()
	ms.round_timer = round_timer
	ms.round_index = round_index
	ms.match_phase = match_phase
	ms.sudden_death = sudden_death
	ms.phase_timer = phase_timer
	ms.last_round_end_reason = last_round_end_reason
	return ms


# ---------------------------------------------------------------------------
# Serialization (match-flow.md "MatchState shape"; AD-034 stamp extends here).
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"v": FORMAT_VERSION,
		"sim": sim.to_dict(),
		"round_wins": round_wins.duplicate(),
		"round_timer": round_timer,
		"round_index": round_index,
		"match_phase": match_phase,
		"sudden_death": 1 if sudden_death else 0,
		"phase_timer": phase_timer,
		"last_round_end_reason": last_round_end_reason,
	}


static func from_dict(d: Dictionary) -> MatchState:
	var v: int = int(d.get("v", FORMAT_VERSION))
	if v != FORMAT_VERSION:
		push_error("MatchState.from_dict: unsupported format version %d (expected %d); refusing to parse." % [v, FORMAT_VERSION])
		return null
	var ms := MatchState.new()
	ms.sim = SimState.from_dict(d["sim"])
	var rw: PackedInt32Array = d["round_wins"]
	ms.round_wins = rw.duplicate()
	ms.round_timer = int(d["round_timer"])
	ms.round_index = int(d["round_index"])
	ms.match_phase = int(d["match_phase"])
	ms.sudden_death = int(d["sudden_death"]) != 0
	ms.phase_timer = int(d["phase_timer"])
	ms.last_round_end_reason = int(d["last_round_end_reason"])
	return ms


# ---------------------------------------------------------------------------
# Canonical state hash (match-flow.md criterion 1; composed with SimState's own
# hash per AD-048 — "AD-023 discipline, composed with the SimState hash"). Same
# FNV-1a fold as SimState.hash_state (duplicated, not shared, matching this
# tree's existing convention of one self-contained hash per serializable root).
# ---------------------------------------------------------------------------

const _FNV_OFFSET: int = -3750763034362895579   # 0xCBF29CE484222325 as signed 64-bit
const _FNV_PRIME: int = 1099511628211            # 0x100000001B3


func hash_state() -> int:
	var h: int = _FNV_OFFSET
	h = _fold(h, match_phase)
	h = _fold(h, round_index)
	h = _fold(h, round_timer)
	h = _fold(h, phase_timer)
	h = _fold(h, 1 if sudden_death else 0)
	h = _fold(h, last_round_end_reason)
	# round_wins: count-then-values (order-committing, AD-023), same discipline
	# as every variable-length run SimState.hash_state folds.
	h = _fold(h, round_wins.size())
	for w in round_wins:
		h = _fold(h, w)
	# Compose with the wrapped SimState's OWN canonical hash rather than
	# re-walking its fields here — single source of truth for combat's hash
	# (SimState.hash_state), the wrapper only adds match truth on top.
	h = _fold(h, sim.hash_state())
	return h


static func _fold(h: int, value: int) -> int:
	for i in range(8):
		var byte: int = (value >> (i * 8)) & 0xFF
		h = (h ^ byte) * _FNV_PRIME
	return h


# ---------------------------------------------------------------------------
# The pure match_step (match-flow.md "The layer (AD-048)"; AD-024/048).
#
#   match_step(match_state, in_p1, in_p2) -> MatchState
#
# PURE + NON-MUTATING, same discipline as SimState.step: writes into a DISTINCT
# clone, `match_state` is left untouched. `SimState.step`'s own signature is
# NEVER changed by this wrapper (AD-024) — it is called with exactly
# `(sim, in_p1, in_p2)`, unmodified, only during ACTIVE.
# ---------------------------------------------------------------------------

## Pure, non-mutating match-tick advance. `in_p1`/`in_p2` are RAW InputFrame
## values (ints), same substrate `SimState.step` takes. Returns a NEW
## MatchState; `match_state` is not mutated.
static func match_step(match_state: MatchState, in_p1: int, in_p2: int) -> MatchState:
	var next: MatchState = match_state.clone()
	match next.match_phase:
		PHASE_ROUND_START:
			_step_round_start(next)
		PHASE_ACTIVE:
			_step_active(next, in_p1, in_p2)
		PHASE_ROUND_END:
			_step_round_end(next)
		PHASE_MATCH_END:
			pass   # terminal; combat not advanced, no transition counter runs
	return next


## ROUND_START: the fresh-round reset already happened at the MOMENT this phase
## was entered (new_match / _enter_next_round below build the fresh SimState
## right then) — this function's only job per tick is to run the deterministic
## "ready" beat (phase_timer) and hand off to ACTIVE when it elapses. Combat is
## NOT advanced here (match-flow.md: "Combat is not advanced outside ACTIVE").
static func _step_round_start(next: MatchState) -> void:
	next.phase_timer -= 1
	if next.phase_timer <= 0:
		next.match_phase = PHASE_ACTIVE


## ACTIVE: match_step calls step (combat advances), then decrements
## round_timer, checks KO/timeout, and on a round-ending condition sets
## last_round_end_reason, awards round win(s), and moves to ROUND_END.
static func _step_active(next: MatchState, in_p1: int, in_p2: int) -> void:
	next.sim = SimState.step(next.sim, in_p1, in_p2)
	if next.round_timer > 0:
		next.round_timer -= 1

	var h0: int = next.sim.players[0].health
	var h1: int = next.sim.players[1].health
	var p0_ko: bool = h0 <= 0
	var p1_ko: bool = h1 <= 0

	var reason: int = REASON_NONE
	var p0_won_round: bool = false
	var p1_won_round: bool = false

	# KO takes priority over a same-tick timeout (the health outcome that
	# actually happened this tick is the more specific truth).
	if p0_ko and p1_ko:
		reason = REASON_DOUBLE_KO
		p0_won_round = true
		p1_won_round = true
	elif p0_ko:
		reason = REASON_KO
		p1_won_round = true
	elif p1_ko:
		reason = REASON_KO
		p0_won_round = true
	elif next.round_timer <= 0:
		reason = REASON_TIMEOUT
		if h0 > h1:
			p0_won_round = true
		elif h1 > h0:
			p1_won_round = true
		else:
			p0_won_round = true   # equal-health timeout: award to BOTH (tie)
			p1_won_round = true

	if reason != REASON_NONE:
		next.last_round_end_reason = reason
		if p0_won_round:
			next.round_wins[0] += 1
		if p1_won_round:
			next.round_wins[1] += 1
		next.match_phase = PHASE_ROUND_END
		next.phase_timer = ROUND_END_BEAT_TICKS


## ROUND_END: run phase_timer; once it elapses, resolve the transition. A tie
## that pushed BOTH players to the match-win threshold at once -> a single
## sudden-death round (sudden_death=true, one more ROUND_START, any win takes
## the match — the SAME scoring rule applies to that round too, so a repeat tie
## in sudden death re-triggers another single sudden-death round rather than
## being undefined; see JC-073). Otherwise a single player at/over threshold ->
## MATCH_END; neither -> the next ordinary round.
##
## FIXED 2026-07-17 (flags.md, "match-flow.md (sudden death) criteria 1-8"):
## the PRIOR check was `p0_at_threshold and p1_at_threshold`, comparing each
## side's CUMULATIVE round_wins against the fixed threshold independently.
## That is correct only the FIRST time both sides reach it together (the
## genuine tie-at-match-point that starts sudden death). Once sudden death is
## under way, round_wins[loser] stays >= ROUND_WIN_THRESHOLD forever (wins
## never decrement) — so after an OUTRIGHT single-winner sudden-death round
## (round_wins go e.g. [2,2] -> [3,2]), BOTH sides still separately read as
## "at threshold," and the old check re-entered sudden death again instead of
## ending the match: MATCH_END became unreachable, and every further round
## (of whatever kind) kept incrementing wins without ever resolving. The fix
## compares the two counts to EACH OTHER, not just each to the threshold: at
## or past threshold with the counts STILL EQUAL is a tie (sudden death,
## first entry or a repeat); at or past threshold with the counts UNEQUAL is a
## decisive win (MATCH_END), regardless of which side got there first.
static func _step_round_end(next: MatchState) -> void:
	next.phase_timer -= 1
	if next.phase_timer > 0:
		return

	var at_threshold: bool = next.round_wins[0] >= ROUND_WIN_THRESHOLD or next.round_wins[1] >= ROUND_WIN_THRESHOLD
	if not at_threshold:
		_enter_next_round(next)
		return

	if next.round_wins[0] == next.round_wins[1]:
		# Tied AT OR PAST the threshold: the tie-at-match-point rule (AD-048) —
		# one more sudden-death round, any win takes it. A repeat tie inside
		# sudden death re-triggers this same branch (JC-073).
		next.sudden_death = true
		_enter_next_round(next)
	else:
		# Unequal counts with at least one side at/over threshold: a decisive
		# winner — including the outright resolution of a sudden-death round.
		next.match_phase = PHASE_MATCH_END


## Build the next round's fresh SimState (carrying tick/rng/stage/character_ids
## forward, per fresh_round_sim), reset the round timer, and hand off to a fresh
## ROUND_START beat.
static func _enter_next_round(next: MatchState) -> void:
	var char_id_p1: int = next.sim.players[0].character_id
	var char_id_p2: int = next.sim.players[1].character_id
	next.sim = fresh_round_sim(char_id_p1, char_id_p2, next.sim.tick, next.sim.rng, next.sim.stage)
	next.round_timer = ROUND_LENGTH_TICKS
	next.round_index += 1
	next.match_phase = PHASE_ROUND_START
	next.phase_timer = ROUND_START_BEAT_TICKS
