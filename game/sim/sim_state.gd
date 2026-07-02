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
## Projectile entities (AD-021). Each entry is a plain-data object once the
## projectile type lands (TKT-P0-05/P1); for P0 this stays empty. Typed loosely as
## Array so the projectile resource can be added without reshaping SimState.
var projectiles: Array = []
var stage: StageState = null


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
	# Projectiles are empty in P0; clone element-wise once a projectile type with
	# its own clone() lands (AD-021). Duplicate the array so the list reference is
	# distinct even while empty.
	s.projectiles = projectiles.duplicate()
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
	# Projectiles empty in P0; serialize element dicts once the type lands.
	var projectile_dicts: Array = []
	for pr in projectiles:
		projectile_dicts.append(pr.to_dict())
	return {
		"tick": tick,
		"rng": rng.to_dict(),
		"players": player_dicts,
		"projectiles": projectile_dicts,
		"stage": stage.to_dict(),
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
	# Projectiles empty in P0.
	s.projectiles = []
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
		h = _fold(h, int(pd["facing"]))
		h = _fold(h, int(pd["health"]))
		h = _fold(h, int(pd["state_id"]))
		h = _fold(h, int(pd["frame_in_state"]))
		h = _fold(h, int(pd["hitstop"]))
		h = _fold(h, int(pd["stun"]))
		h = _fold(h, int(pd["combo_hits"]))
		h = _fold(h, int(pd["combo_scaling"]))
		# Input history: length then each frame, oldest->newest (canonical order).
		var hist: Dictionary = pd["input_history"]
		var frames: PackedInt32Array = hist["frames"]
		h = _fold(h, frames.size())
		for f in frames:
			h = _fold(h, f)

	# Projectiles: count only in P0 (none present). Folding the count fixes the
	# shape so a future non-empty list changes the hash.
	h = _fold(h, projectiles.size())
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
# P0 CONTENT. The full intra-tick phase order (AD-009: inputs -> state machine /
# buffering / cancels -> movement -> overlap -> hit resolution -> advantage ->
# advance counters) is filled in by TKT-P0-06/07. What `step` does NOW, and what
# is load-bearing for the backbone tenet proof:
#   Phase 1 (inputs): record each player's raw InputFrame into their input_history
#     (the substrate later buffering reads, AD-003). Inputs are recorded every tick
#     unconditionally (AD-017: even during hitstop).
#   Advance counters: tick += 1.
# Movement/overlap/hit/advantage are intentionally absent until their tickets; the
# seam here is the fixed structure those phases slot into, in the AD-009 order.
# ---------------------------------------------------------------------------

## Pure, non-mutating tick advance. `in_p1` / `in_p2` are RAW InputFrame values
## (ints; see input_frame.gd). Returns a NEW SimState; `state` is not mutated.
static func step(state: SimState, in_p1: int, in_p2: int) -> SimState:
	# Distinct output object (AD-004). All mutation below is on `next`, never on
	# `state`, so the input snapshot is provably untouched.
	var next: SimState = state.clone()

	# --- Phase 1: inputs (AD-009) -------------------------------------------
	# Record raw frames into each player's history. Recorded every tick, including
	# during hitstop (AD-017): phase 1 always runs. SOCD is NOT applied here — it is
	# a separate sim-side normalization (AD-003) that lands in phase 1's expansion
	# at TKT-P0-06; raw bits stay raw in history for replay fidelity.
	next.players[0].input_history.push(in_p1)
	next.players[1].input_history.push(in_p2)

	# --- Phases 2..6 (AD-009): state machine / buffering / cancels, movement,
	# overlap, hit resolution, advantage/neutral. Filled by TKT-P0-06/07. The
	# fixed phase order is the seam; nothing here yet so the backbone stays a pure
	# clock+input advance the determinism proof can hand-verify. ---------------

	# --- Advance counters ----------------------------------------------------
	next.tick = state.tick + 1

	return next
