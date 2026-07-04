class_name ProjectileData
extends Resource

## The AUTHORED projectile shell (move-format.md -> `Projectile`; AD-021), spawned
## by a Keyframe's `spawn` action. Named `ProjectileData` (not `Projectile`) to
## avoid colliding with the RUNTIME entity class `Projectile` (game/sim/
## projectile.gd, a RefCounted plain-data object living in SimState.projectiles) -
## see the packaging judgment-call log entry for this ticket. This is the
## `.tres`-authorable DESIGN of a projectile; the runtime `Projectile` is one
## LIVE INSTANCE of it, spawned into SimState.
##
## FIELD SPLIT FROM move-format.md's `Projectile` TABLE. That table lists
## `owner, position, velocity, hitbox, lifetime, max_per_owner`. Of these, `owner`
## is the spawning player's index (known only at spawn time, from SimState - not
## authorable), and the INITIAL `position`/`velocity` are already carried on the
## spawning Keyframe (`spawn_offset_x/y`, `spawn_velocity_x/y` - move-format.md
## Keyframe.spawn: "{ projectile, offset, velocity }"). So the fields that are
## genuinely PART OF THE PROJECTILE'S OWN DESIGN - independent of who spawns it or
## from where - are exactly what this Resource authors: its hitbox (geometry + hit
## data), how long it lives, and its live-instance cap per owner.

## Stable identifier resolved through ProjectileRegistry (mirrors Character.id /
## MoveRegistry). A live Projectile entity in SimState carries this id (a plain
## int, serialized) rather than a direct HitBox reference - authored content stays
## out of serialized state (AD-024) - so a restore re-attaches `hitbox` by looking
## this id up in ProjectileRegistry, exactly like character_id resolves through
## MoveRegistry.
@export var id: int = 0

## The hitbox (geometry + hit data) the projectile carries. Character-local at
## spawn (offset by the keyframe's spawn_offset, then travels independently -
## AD-021); resolved to world space each tick via Projectile.resolve_hitbox().
@export var hitbox: HitBox = null

## Frames the projectile persists before despawning (consumed on hit/block or once
## elapsed - AD-021, combat-resolution.md "Projectiles").
@export var lifetime: int = 60

## Live cap per owner (AD-021: "the slice caps one live projectile per owner").
## A spawn while the owner is already at this cap is suppressed (move-format.md
## Keyframe.spawn: "if the cap is full the spawn is suppressed").
@export var max_per_owner: int = 1
