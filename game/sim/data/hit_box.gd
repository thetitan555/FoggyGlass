class_name HitBox
extends Resource

## A Box plus hit data (move-format.md → HitBox; AD-006, AD-008, AD-010, AD-016).
##
## Geometry (the AABB) carried alongside everything the sim needs to resolve a
## connect: damage, stun, hitstop, pushback, the forced reaction states, cancel-tag
## grants, single-hit grouping, and the optional rehit cadence. All fixed-point
## geometry / whole-frame values are integers (baked fixed-point where spatial —
## AD-014); no floats reach the runtime (move-format.md criterion 9).

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

## Throw flag (AD-016). If true this box is a throwbox: on connect it bypasses
## blockstun and enters the throw resolution path (combat-resolution.md).
@export var is_throw: bool = false
