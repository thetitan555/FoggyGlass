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

# --- Identity ---------------------------------------------------------------

## Which character this player is (Character.id). Sourced from authored data and
## carried in state so the sim (and the inspection surface, which exposes
## PlayerView.character_id) can resolve this player's move data without a global
## lookup. Plain int id (move-format.md → Character.id). Added TKT-P0-04/05
## (JC-010): PlayerView requires it and box/frame resolution needs each player's
## character; the SimState player table did not name it, so it is a genuine gap the
## inspection contract implies. Serialized + hashed like every other field.
var character_id: int = 0

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

## What kind of stun the player is in (inspection-surface.md → PlayerView.stun_kind).
## 0 none / 1 hit / 2 block. Mirrors PlayerView.STUN_* constants. Set by hit
## resolution (TKT-P0-07) and cleared when stun expires; carried in state so the
## inspection surface reports it without re-deriving. Added with the identity gap
## (JC-010).
var stun_kind: int = 0

## Combo accounting: hit count, current damage-scaling numerator (FP-scaled), and
## cumulative damage dealt this combo. scaling is fixed-point so proportional
## scaling stays integer math (AD-014); damage is whole units. combo_damage backs
## PlayerView.combo.damage_total. Added with the identity gap (JC-010).
var combo_hits: int = 0
var combo_scaling: int = 65536   # FP.ONE — 1.0 scaling at combo start (no floats)
var combo_damage: int = 0

## The hitbox id_groups that have ALREADY connected during the CURRENT move (as the
## attacker). Backs single-hit integrity ACROSS active frames (AD-016: "one hit per
## group per contact"): a hitbox whose id_group is in this set does not re-hit — so a
## multi-frame active window lands ONE hit, not one per active frame. Cleared on every
## state entry (a new move is a new "contact"). Cadenced re-hit (rehit_interval) is
## TKT-P0-09; at P0 this set stays populated for the move's life. Serialized/hashed
## like every other field so the single-hit decision survives snapshot/restore and is
## deterministic. Raised as flag F-005 (a SimState shape addition, Architect-owned).
var active_hit_ids: PackedInt32Array = PackedInt32Array()

## PARALLEL to active_hit_ids (index i is the tick active_hit_ids[i] last connected).
## Backs cadenced re-hit (HitBox.rehit_interval, AD-016): a rehit_interval hitbox may
## re-hit the same target only once `rehit_interval` frames have elapsed since that
## id_group last connected. Kept length-synced with active_hit_ids (appended/cleared
## together). Serialized/cloned/hashed as a variable-length run like active_hit_ids.
## Raised in flag F-010 (a SimState shape addition, Architect-owned; TKT-P0-09).
var active_hit_frames: PackedInt32Array = PackedInt32Array()

# --- Cancels / buffered commands (TKT-P0-08; AD-015/017/022) -----------------

## Cancel tags granted to this player (AS ATTACKER) by a connecting hitbox in phase 5
## of tick T (HitBox.cancel_tags). Available to the cancel phase (phase 2) starting
## tick T+1 — the AD-017 grant->consume latency, which falls out for free because phase
## 2 precedes phase 5 in the fixed order. Cleared on every state entry (a new move's
## tags are its own). Serialized/cloned/hashed as a variable-length run. Raised in flag
## F-010 (a SimState shape addition, Architect-owned; TKT-P0-08).
var cancel_tags: PackedInt32Array = PackedInt32Array()

## Outcome of this player's CURRENT move, for CancelRule.condition evaluation (AD-015):
## 0 none / 1 hit / 2 block / 3 whiff-resolved. Set on the ATTACKER in phase 5 on
## connect (hit or block), and set to whiff once the move's last active frame passes
## with no connect (so `on_whiff` cancels can fire). Cleared on state entry. Plain int.
## Raised in flag F-010 (a SimState shape addition, Architect-owned; TKT-P0-08).
var move_contact: int = 0

## move_contact values (CancelRule.condition maps onto these).
const CONTACT_NONE: int = 0
const CONTACT_HIT: int = 1
const CONTACT_BLOCK: int = 2
const CONTACT_WHIFF: int = 3

# --- Throws (TKT-P0-09; AD-016) ---------------------------------------------

## Frames remaining in which this player (as the thrown DEFENDER) may TECH the throw
## (input a throw to escape to neutral with no damage — AD-016). Set on throw connect,
## decremented in phase 7 (a throw connect applies no mutual hitstop at P0, so the
## window is not frozen). 0 = not in a tech window. Raised in flag F-010 (Architect-
## owned; TKT-P0-09).
var throw_tech_window: int = 0

## The attacker index that threw this player, or -1 if not thrown. Used for tech
## resolution and combo attribution. Cleared when the tech window closes / the throw
## resolves. Raised in flag F-010 (Architect-owned; TKT-P0-09).
var thrown_by: int = -1

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
	p.character_id = character_id
	p.facing = facing
	p.health = health
	p.state_id = state_id
	p.frame_in_state = frame_in_state
	p.hitstop = hitstop
	p.stun = stun
	p.stun_kind = stun_kind
	p.combo_hits = combo_hits
	p.combo_scaling = combo_scaling
	p.combo_damage = combo_damage
	p.active_hit_ids = active_hit_ids.duplicate()
	p.active_hit_frames = active_hit_frames.duplicate()
	p.cancel_tags = cancel_tags.duplicate()
	p.move_contact = move_contact
	p.throw_tech_window = throw_tech_window
	p.thrown_by = thrown_by
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
		"character_id": character_id,
		"facing": facing,
		"health": health,
		"state_id": state_id,
		"frame_in_state": frame_in_state,
		"hitstop": hitstop,
		"stun": stun,
		"stun_kind": stun_kind,
		"combo_hits": combo_hits,
		"combo_scaling": combo_scaling,
		"combo_damage": combo_damage,
		"active_hit_ids": active_hit_ids.duplicate(),
		"active_hit_frames": active_hit_frames.duplicate(),
		"cancel_tags": cancel_tags.duplicate(),
		"move_contact": move_contact,
		"throw_tech_window": throw_tech_window,
		"thrown_by": thrown_by,
		"input_history": input_history.to_dict(),
	}


## Restore from a plain-data dict. Exact inverse of to_dict.
static func from_dict(d: Dictionary) -> PlayerState:
	var p := PlayerState.new()
	p.pos_x = int(d["pos_x"])
	p.pos_y = int(d["pos_y"])
	p.vel_x = int(d["vel_x"])
	p.vel_y = int(d["vel_y"])
	p.character_id = int(d["character_id"])
	p.facing = int(d["facing"])
	p.health = int(d["health"])
	p.state_id = int(d["state_id"])
	p.frame_in_state = int(d["frame_in_state"])
	p.hitstop = int(d["hitstop"])
	p.stun = int(d["stun"])
	p.stun_kind = int(d["stun_kind"])
	p.combo_hits = int(d["combo_hits"])
	p.combo_scaling = int(d["combo_scaling"])
	p.combo_damage = int(d["combo_damage"])
	var ids: PackedInt32Array = d["active_hit_ids"]
	p.active_hit_ids = ids.duplicate()
	var ahf: PackedInt32Array = d["active_hit_frames"]
	p.active_hit_frames = ahf.duplicate()
	var ct: PackedInt32Array = d["cancel_tags"]
	p.cancel_tags = ct.duplicate()
	p.move_contact = int(d["move_contact"])
	p.throw_tech_window = int(d["throw_tech_window"])
	p.thrown_by = int(d["thrown_by"])
	p.input_history = InputHistory.from_dict(d["input_history"])
	return p
