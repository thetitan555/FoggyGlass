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
