class_name HitBox
extends Resource

## A Box plus hit data (move-format.md → HitBox; AD-006, AD-008, AD-010, AD-016).
##
## Geometry (the AABB) carried alongside everything the sim needs to resolve a
## connect: damage, stun, hitstop, pushback, the forced reaction states, cancel-tag
## grants, single-hit grouping, and the optional rehit cadence. All fixed-point
## geometry / whole-frame values are integers (baked fixed-point where spatial —
## AD-014); no floats reach the runtime (move-format.md criterion 9).

## Contact category (AD-031): STRIKE / THROW / PROJECTILE. Determines which of a
## defender's invuln_* flags gates this box in phase 4 (STRIKE and PROJECTILE are
## whiffed by invuln_strike; THROW by invuln_throw — a projectile is a strike
## delivered at range, so the same immunity beats both). The CANONICAL category;
## the legacy `is_throw` flag below is exactly `hit_kind == THROW` (same fact, two
## names for continuity with the shipped throw path, which keys on `is_throw`).
## Authoring may set either; they must agree. Default STRIKE.
@export var hit_kind: int = HIT_KIND_STRIKE

const HIT_KIND_STRIKE: int = 0
const HIT_KIND_THROW: int = 1
const HIT_KIND_PROJECTILE: int = 2

## The AABB (character-local, fixed-point).
@export var box: Box = null

## Base damage (whole units).
@export var damage: int = 0

## Frames of stun inflicted on hit / on block.
@export var hitstun: int = 0
@export var blockstun: int = 0

## Freeze frames applied to BOTH parties on contact (AD-010).
@export var hitstop: int = 0

## Positional pushback, fixed-point (applied along the facing axis).
@export var pushback_hit: int = 0
@export var pushback_block: int = 0

## Launch velocity, fixed-point (0 = no launch). Optional.
@export var launch: int = 0

## Which defender state_id the hit forces (category HITSTUN / BLOCKSTUN). The
## defender enters `hit_reaction` on hit, `block_reaction` on block.
@export var hit_reaction: int = 0
@export var block_reaction: int = 0

## Cancel tags this hitbox grants the ATTACKER on connect (enables special-cancels).
## An array of tag ids (ints). Granted in phase 5 of tick T, usable T+1 (AD-017).
@export var cancel_tags: PackedInt32Array = PackedInt32Array()

## Groups hitboxes of one attack so a single attack hits once (AD-016 single-hit).
## Overlapping boxes sharing an id_group register ONE hit.
@export var id_group: int = 0

## Optional cadenced multi-hit (AD-016). If > 0, this id_group may hit the same
## target again after this many frames. 0 (unset) => one hit per contact.
@export var rehit_interval: int = 0

## Throw flag (AD-016/AD-031). A COMPUTED property backed by `hit_kind` — reading
## it returns `hit_kind == HIT_KIND_THROW`; writing it sets/clears `hit_kind`
## to/from THROW. This keeps the legacy name working for the shipped throw path
## (combat-resolution.md, step_phases.gd) and for existing authored content that
## sets `is_throw = true` directly, while `hit_kind` stays the single underlying
## fact (no two fields to drift apart — AD-031 "authoring may set either but they
## must agree" is enforced by construction, not by convention).
var is_throw: bool:
	get:
		return hit_kind == HIT_KIND_THROW
	set(value):
		hit_kind = HIT_KIND_THROW if value else HIT_KIND_STRIKE

## Throw tech-window length, in frames (AD-029; AD-016 tech window). The number of
## frames after this throw connects during which the thrown defender may tech it
## (both to neutral, no damage). Meaningful ONLY on a throwbox (`is_throw`); a throw
## is never blocked, so this is its own dedicated field, NOT a reuse of `blockstun`.
## 0 = none / not a throw window. Read on connect by the throw path (step_phases.gd
## `_resolve_throw`), which copies it into the defender's `throw_tech_window`.
@export var tech_window: int = 0
