class_name CharacterPhysics
extends Resource

## Walk/dash/jump/gravity constants for a character (move-format.md →
## Character.physics; AD-014). BAKED FIXED-POINT INTEGERS — no floats reach the
## runtime (move-format.md criterion 9). Authoring may use friendly units; the
## float->fixed bake happens once off the hot path (FP.from_units), never in `step`.
##
## Kept as a flat resource of plain ints so the `.tres` is stable/diffable (criterion
## 3) and `step` reads only integers.

## Ground walk speed per tick (fixed-point). Applied along facing forward/back.
@export var walk_speed: int = 0

## Gravity per tick (fixed-point, applied to vel_y each airborne tick). 0 for a
## purely grounded slice character.
@export var gravity: int = 0

## Initial jump velocity (fixed-point, upward). 0 if the character cannot jump.
@export var jump_velocity: int = 0

## Air-dash horizontal speed (fixed-point, AD-046/TKT-P2-02) — the velocity SET
## (forward-relative, applied along facing) when the one-air-action economy's air
## dash fires. 0 if the character has no air dash (spending the action still
## latches `air_action_used`, just with no horizontal effect — a character without
## this kit simply never authors the double-tap-while-airborne interaction
## meaningfully; the engine mechanism itself is universal, per-character-value-gated
## like `gravity`/`jump_velocity`).
@export var air_dash_speed: int = 0

## Double-jump upward re-impulse (fixed-point, AD-046/TKT-P2-02) — the vel_y SET
## (upward, i.e. negative in this engine's screen-space convention, matching
## `jump_velocity`'s own sign) when the one-air-action economy's double jump fires.
## 0 if the character has no double jump.
@export var double_jump_velocity: int = 0
