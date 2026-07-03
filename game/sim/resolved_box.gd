class_name ResolvedBox
extends RefCounted

## A box resolved to WORLD SPACE for one tick (the output of box resolution —
## MoveData.resolve_boxes). Derived, not stored (AD-001): computed each tick from
## move data + (state_id, frame_in_state, facing, position), never persisted in
## SimState. This is the geometry the sim tests for AABB overlap (phase 4) and the
## geometry BoxView projects for the inspection surface — one source, so the debug
## overlay shows exactly what the sim tested.
##
## Fixed-point integer world-space AABB. No floats (AD-019). For HIT/THROW boxes the
## originating HitBox is carried (for hit data / single-hit grouping); HURT/PUSH
## carry none.

## World-space AABB, fixed-point.
var x: int = 0
var y: int = 0
var w: int = 0
var h: int = 0

## BoxView.KIND_* — HURT / HIT / THROW / PUSH.
var kind: int = 0

## For HIT / THROW: the originating HitBox (hit data + id_group). Null for HURT/PUSH.
var hit: HitBox = null


static func make(p_kind: int, p_x: int, p_y: int, p_w: int, p_h: int, p_hit: HitBox = null) -> ResolvedBox:
	var r := ResolvedBox.new()
	r.kind = p_kind
	r.x = p_x
	r.y = p_y
	r.w = p_w
	r.h = p_h
	r.hit = p_hit
	return r


## AABB overlap test against another ResolvedBox (integer compare — AD-012/014).
## Touching edges do NOT count as overlap (strict), so a box exactly adjacent to a
## hurtbox does not register — a deterministic, single-sourced convention.
func overlaps(other: ResolvedBox) -> bool:
	return x < other.x + other.w \
		and x + w > other.x \
		and y < other.y + other.h \
		and y + h > other.y
