class_name Projectile
extends RefCounted

## A live projectile sim entity (AD-021; SimState.projectiles). NOT the authored
## `.tres` shell (that's ProjectileData) - this is the runtime plain-data entity
## that lives IN SimState, so it clones / serializes / hashes canonically with the
## rest of the graph.
##
## SCOPE (TKT-P1-0P). Spawned by the `spawn` keyframe action (StepPhases phase 3),
## integrated each tick, tested for overlap (phase 4), resolved on hit/block
## (phase 5), and despawned on consume/lifetime/off-stage. Fixed-point position/
## velocity, whole-frame lifetime; no floats (AD-005/019).
##
## AUTHORED-DATA RESOLUTION (AD-024, mirrors character_id -> MoveRegistry). The
## carried `hitbox` is authored `.tres` content, not mutable sim truth, so it is
## NOT part of the serialized/hashed form. Instead this entity carries `data_id` -
## a stable int resolved through ProjectileRegistry, exactly like a player's
## `character_id` resolves through MoveRegistry - and a restore path re-attaches
## `hitbox` from `ProjectileRegistry.data(data_id).hitbox` rather than serializing
## the HitBox object itself.

## Player index that spawned it (cap, facing, combo attribution).
var owner: int = 0

## The authored ProjectileData id this instance was spawned from (AD-024). Backs
## hitbox re-attachment on restore; serialized/hashed (it IS mutable sim truth in
## the sense that WHICH projectile design is live must survive snapshot/restore,
## even though the authored data behind it does not).
var data_id: int = 0

## Fixed-point position / velocity; integrates each tick independently of the owner.
var pos_x: int = 0
var pos_y: int = 0
var vel_x: int = 0
var vel_y: int = 0

## Facing the projectile travels / hits with (+1 / -1), fixed at spawn from the owner.
var facing: int = 1

## Frames left before despawn; consumed on hit/block or when it elapses.
var lifetime_remaining: int = 0

## The hitbox (geometry + hit data) carried by the projectile. A HitBox resource
## (character-local geometry, offset by pos each tick). Resolved from
## ProjectileRegistry via data_id; NOT itself serialized (AD-024 - authored
## content stays out of state). May be null if data_id resolves to nothing (a
## defensive fallback, not an expected runtime state).
var hitbox: HitBox = null

## Canonical hash field order (AD-023). The mutable scalar fields (owner, WHICH
## projectile design via data_id, pos/vel/facing/lifetime) are what the hash
## commits to; the authored hitbox geometry behind data_id is fixed content
## (AD-024) and is not separately hashed - two states spawning the same data_id
## always carry the same authored hitbox, so hashing the id is sufficient to
## distinguish sim states.
const HASH_FIELDS: Array[String] = [
	"owner", "data_id", "pos_x", "pos_y", "vel_x", "vel_y", "facing", "lifetime_remaining",
]


## Construct a live projectile from an owner and its authored ProjectileData,
## with the given spawn-time position/velocity/facing. The one spawn path
## (StepPhases' spawn action) uses this so every live projectile is built the
## same way.
static func spawn(p_owner: int, p_data_id: int, p_data: ProjectileData,
		p_pos_x: int, p_pos_y: int, p_vel_x: int, p_vel_y: int, p_facing: int) -> Projectile:
	var pr := Projectile.new()
	pr.owner = p_owner
	pr.data_id = p_data_id
	pr.pos_x = p_pos_x
	pr.pos_y = p_pos_y
	pr.vel_x = p_vel_x
	pr.vel_y = p_vel_y
	pr.facing = p_facing
	pr.lifetime_remaining = p_data.lifetime if p_data != null else 0
	pr.hitbox = p_data.hitbox if p_data != null else null
	return pr


func clone() -> Projectile:
	var p := Projectile.new()
	p.owner = owner
	p.data_id = data_id
	p.pos_x = pos_x
	p.pos_y = pos_y
	p.vel_x = vel_x
	p.vel_y = vel_y
	p.facing = facing
	p.lifetime_remaining = lifetime_remaining
	# The hitbox is authored resource data shared by reference (immutable at runtime);
	# not deep-copied because it is never mutated after spawn.
	p.hitbox = hitbox
	return p


func to_dict() -> Dictionary:
	return {
		"owner": owner,
		"data_id": data_id,
		"pos_x": pos_x,
		"pos_y": pos_y,
		"vel_x": vel_x,
		"vel_y": vel_y,
		"facing": facing,
		"lifetime_remaining": lifetime_remaining,
	}


## Restore from plain-data. Re-attaches `hitbox` from ProjectileRegistry by
## `data_id` (AD-024) - the authored hitbox itself is never part of the serialized
## form, mirroring how a restored PlayerState's move data is resolved through
## MoveRegistry by character_id rather than being serialized.
static func from_dict(d: Dictionary) -> Projectile:
	var p := Projectile.new()
	p.owner = int(d["owner"])
	p.data_id = int(d["data_id"])
	p.pos_x = int(d["pos_x"])
	p.pos_y = int(d["pos_y"])
	p.vel_x = int(d["vel_x"])
	p.vel_y = int(d["vel_y"])
	p.facing = int(d["facing"])
	p.lifetime_remaining = int(d["lifetime_remaining"])
	var data: ProjectileData = ProjectileRegistry.data(p.data_id)
	p.hitbox = data.hitbox if data != null else null
	return p


## Resolve the carried hitbox to a world-space ResolvedBox (for ProjectileView / the
## geometry overlay), offset by the projectile's own position and flipped by facing.
## Returns null if no hitbox is attached (e.g. an unresolved data_id).
func resolve_hitbox() -> ResolvedBox:
	if hitbox == null or hitbox.box == null:
		return null
	return MoveData.resolve_hit_box(hitbox, facing, pos_x, pos_y)
