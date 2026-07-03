class_name SimState
extends RefCounted

## The serializable simulation root (Tenet 1, simulation.md → SimState; AD-001,
## AD-004, AD-005). A single plain-data graph: tick, seeded RNG, two players, a
## projectile list, and stage state. NO live node references, NO floats
## (simulation.md criterion 8) — every gameplay quantity is a plain int or a
## fixed-point int (AD-005/014).
##
## This is the one mechanism behind frame-step, situation-reset, replay, and
## rollback: they are all "snapshot (to_dict), advance (step), maybe restore
## (from_dict)". Because `step` is pure and non-mutating (AD-004), a snapshot taken
## before a step is provably unaffected by the step.
##
## FIELDS (simulation.md → SimState root):
##   tick        — monotonic tick counter; the authoritative clock (AD-004).
##   rng         — seeded RNG state, INSIDE the snapshot (Tenet 1). P0 draws none,
##                 but it is part of state from the start so determinism is provable
##                 end-to-end now and later randomness draws from an already-
##                 serialized source.
##   players[2]  — per-player state (PlayerState).
##   projectiles — live projectile entities (AD-021). Empty in P0 (none spawn yet);
##                 present as a list so the shape is fixed and 05+/P1 fill it.
##   stage       — stage bounds / walls / ground affecting the sim.

var tick: int = 0
var rng: RngState = null
var players: Array[PlayerState] = []
## Projectile entities (AD-021). Each entry is a Projectile plain-data object; P0
## spawns none so this stays empty, but the type + clone/serialize are wired so a
## non-empty list round-trips and hashes canonically the moment spawns land.
var projectiles: Array[Projectile] = []
var stage: StageState = null

## The most recently resolved hit, or null if none has resolved this run
## (inspection-surface.md → InspectionView.last_hit()). Recorded by hit resolution
## (TKT-P0-07, phase 5) and read out through the inspection surface. It is a plain
## HitRecord (not a HitEvent view) living IN serialized state so last_hit survives
## snapshot/restore and is covered by the canonical hash (F-002, AD-023 total
## coverage). Null until the first hit resolves.
var last_hit: HitRecord = null

## Set true by phase 6 (advantage/neutral update) EXACTLY on the tick both players
## transition to actionable (combat-resolution.md criterion 5: "not before, not
## after"), cleared every other tick. The inspection surface (AdvantageView) reads
## it so "when neutral returns" is observable. In serialized state so it round-trips
## and is hashed (total coverage, AD-023). Set at TKT-P0-07.
var neutral_restored_this_tick: bool = false


func _init() -> void:
	# A bare SimState is not yet a valid initial state — use new_initial() to build
	# a runnable one. This keeps sub-objects non-null so clone()/to_dict() are safe
	# even on a default-constructed instance.
	rng = RngState.new(0)
	stage = StageState.new()


## Build a valid initial state: tick 0, seeded RNG, two players at symmetric
## starting positions facing each other, an empty projectile list, a placeholder
## stage. Starting positions/health are placeholder P0 geometry (data, not feel) so
## the sim has a valid, symmetric setup to advance and to hand-trace determinism
## against; authored spawn data lands with the test character (TKT-P0-10).
static func new_initial(p_seed: int = 0) -> SimState:
	var s := SimState.new()
	s.tick = 0
	s.rng = RngState.new(p_seed)
	s.stage = StageState.new_initial()

	var p1 := PlayerState.new()
	p1.pos_x = FP.from_int(-100)
	p1.pos_y = s.stage.ground_y
	p1.facing = 1               # P1 starts on the left, facing right
	p1.health = 1000

	var p2 := PlayerState.new()
	p2.pos_x = FP.from_int(100)
	p2.pos_y = s.stage.ground_y
	p2.facing = -1              # P2 starts on the right, facing left
	p2.health = 1000

	var ps: Array[PlayerState] = [p1, p2]
	s.players = ps
	s.projectiles = []
	return s


## Deep copy of the whole data graph (AD-004). Used to build the distinct output
## state `step` writes into, and by snapshotting. Every reference-type member is
## itself cloned, so the returned SimState shares NO mutable state with the
## original — this is what makes `step` structurally non-mutating: mutating the
## clone can never reach back into the input state.
func clone() -> SimState:
	var s := SimState.new()
	s.tick = tick
	s.rng = rng.clone()
	s.stage = stage.clone()
	var cloned_players: Array[PlayerState] = []
	for p in players:
		cloned_players.append(p.clone())
	s.players = cloned_players
	# Deep-copy projectiles element-wise (AD-004): each is its own plain-data object,
	# so a shallow array duplicate would alias the entities. Empty in P0.
	var cloned_projectiles: Array[Projectile] = []
	for pr in projectiles:
		cloned_projectiles.append(pr.clone())
	s.projectiles = cloned_projectiles
	# last_hit is a plain record; deep-copy so the clone owns its own copy.
	s.last_hit = last_hit.clone() if last_hit != null else null
	s.neutral_restored_this_tick = neutral_restored_this_tick
	return s


# ---------------------------------------------------------------------------
# Serialization (simulation.md → Serialization; criterion 3).
# to_dict / from_dict are exact inverses over plain-data values. Field order is
# fixed so the canonical hash is stable. No floats anywhere.
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var player_dicts: Array = []
	for p in players:
		player_dicts.append(p.to_dict())
	var projectile_dicts: Array = []
	for pr in projectiles:
		projectile_dicts.append(pr.to_dict())
	return {
		"tick": tick,
		"rng": rng.to_dict(),
		"players": player_dicts,
		"projectiles": projectile_dicts,
		"stage": stage.to_dict(),
		# null last_hit serializes as an empty dict marker; from_dict restores null.
		"last_hit": last_hit.to_dict() if last_hit != null else {},
		"neutral_restored_this_tick": 1 if neutral_restored_this_tick else 0,
	}


static func from_dict(d: Dictionary) -> SimState:
	var s := SimState.new()
	s.tick = int(d["tick"])
	s.rng = RngState.from_dict(d["rng"])
	s.stage = StageState.from_dict(d["stage"])
	var restored_players: Array[PlayerState] = []
	for pd in d["players"]:
		restored_players.append(PlayerState.from_dict(pd))
	s.players = restored_players
	var restored_projectiles: Array[Projectile] = []
	for prd in d["projectiles"]:
		restored_projectiles.append(Projectile.from_dict(prd))
	s.projectiles = restored_projectiles
	# An empty last_hit dict means "no hit recorded" -> null.
	var lhd: Dictionary = d["last_hit"]
	s.last_hit = HitRecord.from_dict(lhd) if not lhd.is_empty() else null
	s.neutral_restored_this_tick = int(d["neutral_restored_this_tick"]) != 0
	return s


# ---------------------------------------------------------------------------
# Canonical state hash (simulation.md criteria 1, 2, 3; TKT-P0-11 hook).
#
# Purity, determinism, and round-trip are all checked by "do two states hash the
# same?", so the hash MUST be a deterministic, platform-independent function of the
# state's DATA — never of object identity or Dictionary iteration order. We build a
# canonical ordered stream of the state's integer values (walking to_dict in fixed
# field order) and fold it with 64-bit FNV-1a. Pure integer, no floats, no reliance
# on Godot's hash()/Dictionary ordering. Two states with identical logical content
# hash identically; any differing field changes the hash.
# ---------------------------------------------------------------------------

const _FNV_OFFSET: int = -3750763034362895579   # 0xCBF29CE484222325 as signed 64-bit
const _FNV_PRIME: int = 1099511628211            # 0x100000001B3


## Canonical 64-bit hash of this state's data. Deterministic across runs/platforms:
## folds the state's integer value stream in a fixed order with FNV-1a. GDScript
## ints are 64-bit and wrap on overflow, matching FNV-1a's modular arithmetic.
func hash_state() -> int:
	var h: int = _FNV_OFFSET
	# Walk fields in a FIXED order. Each value is an int (or nested ints); order and
	# content are what the hash commits to.
	h = _fold(h, tick)

	# RNG: seed + internal state.
	var rng_d: Dictionary = rng.to_dict()
	h = _fold(h, int(rng_d["seed"]))
	h = _fold(h, int(rng_d["state"]))

	# Stage.
	var st_d: Dictionary = stage.to_dict()
	h = _fold(h, int(st_d["wall_left"]))
	h = _fold(h, int(st_d["wall_right"]))
	h = _fold(h, int(st_d["ground_y"]))

	# Players, in order. A separator (player count then each player's fields) so two
	# different field groupings can't collide.
	h = _fold(h, players.size())
	for p in players:
		var pd: Dictionary = p.to_dict()
		h = _fold(h, int(pd["pos_x"]))
		h = _fold(h, int(pd["pos_y"]))
		h = _fold(h, int(pd["vel_x"]))
		h = _fold(h, int(pd["vel_y"]))
		h = _fold(h, int(pd["character_id"]))
		h = _fold(h, int(pd["facing"]))
		h = _fold(h, int(pd["health"]))
		h = _fold(h, int(pd["state_id"]))
		h = _fold(h, int(pd["frame_in_state"]))
		h = _fold(h, int(pd["hitstop"]))
		h = _fold(h, int(pd["stun"]))
		h = _fold(h, int(pd["stun_kind"]))
		h = _fold(h, int(pd["combo_hits"]))
		h = _fold(h, int(pd["combo_scaling"]))
		h = _fold(h, int(pd["combo_damage"]))
		# Active-hit id_groups: length then each id (order-committing, AD-023). A
		# variable-length run, so its count is folded before the elements (F-005).
		var ah: PackedInt32Array = pd["active_hit_ids"]
		h = _fold(h, ah.size())
		for gid in ah:
			h = _fold(h, gid)
		# Input history: length then each frame, oldest->newest (canonical order).
		var hist: Dictionary = pd["input_history"]
		var frames: PackedInt32Array = hist["frames"]
		h = _fold(h, frames.size())
		for f in frames:
			h = _fold(h, f)

	# Projectiles: count then each projectile's fields (order-committing, AD-023).
	# P0 spawns none, so the loop is empty and only the count (0) is folded.
	h = _fold(h, projectiles.size())
	for pr in projectiles:
		var prd: Dictionary = pr.to_dict()
		for key in Projectile.HASH_FIELDS:
			h = _fold(h, int(prd[key]))

	# last_hit record (AD-023 total coverage; F-002). A presence flag (0/1) is folded
	# first so a state with no hit and a state with a hit can never collide, then the
	# record's integer fields in fixed order when present.
	if last_hit == null:
		h = _fold(h, 0)
	else:
		h = _fold(h, 1)
		var lhd: Dictionary = last_hit.to_dict()
		for key in HitRecord.HASH_FIELDS:
			h = _fold(h, int(lhd[key]))

	# neutral-restored edge flag (AD-023 total coverage).
	h = _fold(h, 1 if neutral_restored_this_tick else 0)
	return h


## Fold one 64-bit integer value into an FNV-1a accumulator, one byte at a time so
## the fold is order- and value-sensitive and platform-independent. GDScript int
## wrap-on-overflow gives the modular 2^64 arithmetic FNV-1a specifies.
static func _fold(h: int, value: int) -> int:
	# Process all 8 bytes of the 64-bit value, low byte first (fixed order).
	for i in range(8):
		var byte: int = (value >> (i * 8)) & 0xFF
		h = (h ^ byte) * _FNV_PRIME
	return h


# ---------------------------------------------------------------------------
# The pure step (simulation.md → "The step function"; AD-004, AD-009).
#
#   step(state, in_p1, in_p2) -> SimState
#
# PURE + NON-MUTATING (AD-004). Writes the next state into a DISTINCT object
# (clone of `state`), mutates only that clone, and returns it — `state` is left
# untouched, so hash(state) is unchanged after the call (criterion 9). No reads of
# wall-clock, delta, unseeded RNG, engine input polling, or the scene tree
# (criterion 4): the RNG is in-state, and inputs arrive as arguments.
#
# AUTHORED DATA (F-004). The phase pipeline resolves each player's Character via
# MoveRegistry (an immutable roster installed once at wiring, read every tick), so
# `step` stays a pure function of (state, inputs) GIVEN the fixed content — the same
# "authored content is a fixed input, not sim state" reasoning that keeps input
# SOURCES external and out of SimState (AD-001). A snapshot/restore/replay reproduces
# identically because the same immutable roster is present.
#
# PHASE ORDER (AD-009, combat-resolution.md; implemented in StepPhases). The order is
# LOAD-BEARING and pinned (criterion 2): inputs -> state machine -> movement ->
# overlap -> hit resolution -> advantage/neutral -> advance counters. Each phase is a
# named StepPhases function so the order is explicit here and reorderable-to-fail in a
# test. With an EMPTY roster (no authored data) the pipeline degrades to a pure
# clock+input advance (no character to move/hit), which the backbone determinism
# proof still hand-verifies.
# ---------------------------------------------------------------------------

## Pure, non-mutating tick advance. `in_p1` / `in_p2` are RAW InputFrame values
## (ints; see input_frame.gd). Returns a NEW SimState; `state` is not mutated.
static func step(state: SimState, in_p1: int, in_p2: int) -> SimState:
	# Distinct output object (AD-004). All mutation below is on `next`, never on
	# `state`, so the input snapshot is provably untouched.
	var next: SimState = state.clone()

	# Capture the PRE-STEP both-actionable condition from the INPUT state, so phase 6
	# can detect the rising edge (neutral restored = the tick both BECOME actionable).
	var prev_both_actionable: bool = StepPhases._both_actionable(state)

	# Capture which players were ALREADY in hitstop at tick start (before phase 5 can
	# set it), so phase 7 does not decrement a hitstop first granted THIS tick — a
	# freeze of N frames must last N following ticks (AD-010).
	var was_frozen: Array = [state.players[0].hitstop > 0, state.players[1].hitstop > 0]

	# --- Phase 1: read inputs (AD-009) --------------------------------------
	# Push raw frames into history (recorded every tick, incl. hitstop — AD-017).
	StepPhases.phase1_read_inputs(next, in_p1, in_p2)
	# Resolve each player's SOCD-normalized, facing-relative intent for phase 2 (raw
	# stays raw in history; only the derived intent is cleaned — AD-003).
	var intents: Array = [
		StepPhases.resolve_intent(in_p1, next.players[0].facing),
		StepPhases.resolve_intent(in_p2, next.players[1].facing),
	]

	# --- Phase 2: state machine (direct transitions; buffering stubbed for 08) --
	StepPhases.phase2_state_machine(next, intents)

	# --- Phase 3: movement integration + pushbox/stage resolution -----------
	StepPhases.phase3_movement(next)

	# --- Phase 4: overlap detection (AABB, strict — F-003) ------------------
	var contacts: Array = StepPhases.phase4_overlap(next)

	# --- Phase 5: hit resolution (damage/scaling/combo, reactions, stun, hitstop) --
	StepPhases.phase5_hit_resolution(next, contacts)

	# --- Phase 6: advantage / neutral update --------------------------------
	StepPhases.phase6_advantage_neutral(next, prev_both_actionable)

	# --- Phase 7: advance counters (decrement stun/hitstop; tick += 1) ------
	StepPhases.phase7_advance_counters(next, was_frozen)

	return next
