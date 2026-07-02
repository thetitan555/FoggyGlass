class_name PlayerState
extends RefCounted

## Per-player simulation state (simulation.md → players[i]; AD-001, AD-005/014).
##
## Plain data only. Every gameplay quantity is a fixed-point integer (AD-005) or a
## plain int / bool — NO floats anywhere (simulation.md criterion 8). Positions and
## velocities are FP-scaled 64-bit ints (see fp.gd). Derived geometry (resolved
## hit/hurt boxes) is NOT stored here — it is computed each tick from move data +
## (state_id, frame_in_state, facing, position) per AD-001; this struct is the
## minimal single-sourced state the sim persists.
##
## NON-MUTATION (AD-004). `step` never writes into a live PlayerState; it clones
## the previous state (`clone()`), mutates only the clone, and returns it inside a
## new SimState. `input_history` is a reference-type sub-object, so `clone()`
## deep-copies it (not just the reference) — otherwise mutating next-state history
## would reach back into prev-state history and break purity (hash(prev) would
## change). This deep-copy discipline is what makes AD-004 structurally true.
##
## SERIALIZATION. to_dict/from_dict are exact inverses over plain-data values, so
## a PlayerState round-trips byte-identically (simulation.md criterion 3). Field
## order in to_dict is fixed so the canonical hash (SimState.hash_state) is stable.

# --- Movement (fixed-point, AD-005/014) -------------------------------------

## World position, fixed-point (FP scale). x/y are game units * 2^16.
var pos_x: int = 0
var pos_y: int = 0

## Velocity, fixed-point (FP scale) per tick.
var vel_x: int = 0
var vel_y: int = 0

# --- Facing -----------------------------------------------------------------

## +1 = facing right, -1 = facing left. The raw->forward/back conversion (AD-002,
## sim-side) uses this. Plain int (not FP): it is a direction sign, not a distance.
var facing: int = 1

# --- Vitals / combat counters (plain ints; frames and health are whole) ------

## Current health. Whole units (not FP): health is an integer resource.
var health: int = 0

## Current state-machine state id and the frame within it (move-format.md).
## Both are plain frame/id integers, resolved against move data (TKT-P0-05+).
var state_id: int = 0
var frame_in_state: int = 0

## Remaining hitstop frames (AD-010). While > 0 the character is frozen in-state:
## counters do not advance, but the sim loop keeps ticking (hitstop is in-state,
## not a loop pause).
var hitstop: int = 0

## Remaining hitstun/blockstun frames. 0 == actionable.
var stun: int = 0

## Combo accounting: hit count and current damage-scaling numerator (FP-scaled).
## scaling is fixed-point so proportional scaling stays integer math (AD-014).
var combo_hits: int = 0
var combo_scaling: int = 65536   # FP.ONE — 1.0 scaling at combo start (no floats)

# --- Input substrate --------------------------------------------------------

## Ring buffer of recent RAW InputFrame values — the substrate buffering / motion
## recognition reads (AD-003, AD-022). Reference-type: clone() deep-copies it.
var input_history: InputHistory = null


func _init() -> void:
	# A fresh player starts with an empty history. SimState.new_initial wires
	# real starting position/health/facing; this keeps the bare object valid.
	input_history = InputHistory.new()


## Deep copy for step's non-mutating clone (AD-004). Every reference-type member
## is itself cloned so the returned PlayerState shares NO mutable state with the
## original — mutating the clone can never reach back into the input state.
func clone() -> PlayerState:
	var p := PlayerState.new()
	p.pos_x = pos_x
	p.pos_y = pos_y
	p.vel_x = vel_x
	p.vel_y = vel_y
	p.facing = facing
	p.health = health
	p.state_id = state_id
	p.frame_in_state = frame_in_state
	p.hitstop = hitstop
	p.stun = stun
	p.combo_hits = combo_hits
	p.combo_scaling = combo_scaling
	p.input_history = input_history.clone()
	return p


## Serialize to a plain-data dict. Field order fixed for canonical hashing. The
## nested input_history serializes to its own plain-data dict. No floats.
func to_dict() -> Dictionary:
	return {
		"pos_x": pos_x,
		"pos_y": pos_y,
		"vel_x": vel_x,
		"vel_y": vel_y,
		"facing": facing,
		"health": health,
		"state_id": state_id,
		"frame_in_state": frame_in_state,
		"hitstop": hitstop,
		"stun": stun,
		"combo_hits": combo_hits,
		"combo_scaling": combo_scaling,
		"input_history": input_history.to_dict(),
	}


## Restore from a plain-data dict. Exact inverse of to_dict.
static func from_dict(d: Dictionary) -> PlayerState:
	var p := PlayerState.new()
	p.pos_x = int(d["pos_x"])
	p.pos_y = int(d["pos_y"])
	p.vel_x = int(d["vel_x"])
	p.vel_y = int(d["vel_y"])
	p.facing = int(d["facing"])
	p.health = int(d["health"])
	p.state_id = int(d["state_id"])
	p.frame_in_state = int(d["frame_in_state"])
	p.hitstop = int(d["hitstop"])
	p.stun = int(d["stun"])
	p.combo_hits = int(d["combo_hits"])
	p.combo_scaling = int(d["combo_scaling"])
	p.input_history = InputHistory.from_dict(d["input_history"])
	return p
