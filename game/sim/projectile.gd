class_name Projectile
extends RefCounted

## A live projectile sim entity (AD-021; SimState.projectiles). NOT the authored
## `.tres` shell — this is the runtime plain-data entity that lives IN SimState, so
## it clones / serializes / hashes canonically with the rest of the graph.
##
## SCOPE (TKT-P0-05). The P0 sim spawns no projectiles, so the list is always empty
## at P0; but the type + clone/to_dict/from_dict/hash-fields are wired now so a
## non-empty list round-trips and hashes canonically the moment spawns land
## (TKT-P1-0P runtime behavior). Fixed-point position/velocity, whole-frame lifetime;
## no floats (AD-005/019).

## Player index that spawned it (cap, facing, combo attribution).
var owner: int = 0

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
## (character-local geometry, offset by pos each tick). May be null in the empty P0
## case.
var hitbox: HitBox = null

## Canonical hash field order (AD-023). Only the integer scalar fields are folded;
## the carried HitBox geometry is authored (static) data, not mutable sim state, so
## the entity's mutable truth (owner/pos/vel/facing/lifetime) is what the hash
## commits to. A spawned projectile always carries the same authored hitbox for its
## id, so hashing the scalars is sufficient to distinguish sim states.
const HASH_FIELDS: Array[String] = [
	"owner", "pos_x", "pos_y", "vel_x", "vel_y", "facing", "lifetime_remaining",
]


func clone() -> Projectile:
	var p := Projectile.new()
	p.owner = owner
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
		"pos_x": pos_x,
		"pos_y": pos_y,
		"vel_x": vel_x,
		"vel_y": vel_y,
		"facing": facing,
		"lifetime_remaining": lifetime_remaining,
	}


static func from_dict(d: Dictionary) -> Projectile:
	var p := Projectile.new()
	p.owner = int(d["owner"])
	p.pos_x = int(d["pos_x"])
	p.pos_y = int(d["pos_y"])
	p.vel_x = int(d["vel_x"])
	p.vel_y = int(d["vel_y"])
	p.facing = int(d["facing"])
	p.lifetime_remaining = int(d["lifetime_remaining"])
	# The authored hitbox is not part of the serialized mutable state; a restore host
	# re-attaches it from move data by projectile id at spawn re-derivation (TKT-P1).
	return p


## Resolve the carried hitbox to a world-space ResolvedBox (for ProjectileView / the
## geometry overlay), offset by the projectile's own position and flipped by facing.
## Returns null if no hitbox is attached (the empty P0 case).
func resolve_hitbox() -> ResolvedBox:
	if hitbox == null or hitbox.box == null:
		return null
	return MoveData.resolve_hit_box(hitbox, facing, pos_x, pos_y)
