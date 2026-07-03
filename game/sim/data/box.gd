class_name Box
extends Resource

## An AABB in character-local space (move-format.md → Box; AD-006, AD-014).
##
## Fixed-point integer units (AD-014) — NO floats reach the runtime (move-format.md
## criterion 9). At authoring time a `.tres` may carry friendly values, but the
## float->fixed bake happens once off the hot path; the runtime consumes integers.
## The box is character-local; the sim flips it by `facing` and offsets it by
## `position` to resolve world-space geometry each tick (derived, not stored —
## AD-001).
##
## `.tres` STABILITY (move-format.md criterion 3). @export'd plain-int fields
## serialize to stable, diffable text so QA can golden-file resolved data.

## AABB in character-local space, fixed-point units. `x`/`y` is the box origin
## (pre-flip, pre-offset); `w`/`h` are extents. Stored as ints (baked fixed-point).
@export var x: int = 0
@export var y: int = 0
@export var w: int = 0
@export var h: int = 0


static func make(p_x: int, p_y: int, p_w: int, p_h: int) -> Box:
	var b := Box.new()
	b.x = p_x
	b.y = p_y
	b.w = p_w
	b.h = p_h
	return b
