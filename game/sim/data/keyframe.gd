class_name Keyframe
extends Resource

## A frame range within a MoveState (move-format.md → Keyframe; AD-006).
##
## Timelines are KEYFRAMED, not per-frame (AD-006): a keyframe declares the boxes /
## motion / invuln active over an INCLUSIVE frame range, 1-indexed by
## `frame_in_state`. The sim resolves the exact per-frame box set from these ranges
## (derived, not stored — AD-001), so authoring stays compact while per-frame truth
## is exact.

## Inclusive range within the state, 1-indexed by frame_in_state.
@export var frame_start: int = 1
@export var frame_end: int = 1

## Boxes active this range.
@export var hurtboxes: Array[Box] = []
@export var hitboxes: Array[HitBox] = []
@export var throwboxes: Array[Box] = []

# --- Optional per-range movement (move-format.md → Keyframe.motion) ----------
## If `has_motion`, apply this per-tick velocity (fixed-point) while in range.
## Kept as explicit fields (not a nested Resource) so the .tres stays flat and
## diffable and the runtime reads plain ints.
@export var has_motion: bool = false
@export var motion_vel_x: int = 0
@export var motion_vel_y: int = 0

# --- Optional invulnerability (move-format.md → Keyframe.invuln) -------------
@export var invuln_strike: bool = false
@export var invuln_throw: bool = false

# --- Optional projectile spawn (move-format.md → Keyframe.spawn; AD-021) -----
## If `has_spawn`, spawn `spawn_projectile` this range (subject to the owner's cap).
## Only the FIRST frame of this keyframe's range that is reached while `has_spawn`
## is true actually spawns (StepPhases fires the spawn action once per keyframe
## entry, not once per covered frame — see the spawn action, TKT-P1-0P).
@export var has_spawn: bool = false
@export var spawn_projectile: ProjectileData = null   # the authored projectile shell
@export var spawn_offset_x: int = 0
@export var spawn_offset_y: int = 0
@export var spawn_velocity_x: int = 0
@export var spawn_velocity_y: int = 0


## True iff `frame` (1-indexed frame_in_state) falls in this keyframe's range.
func covers(frame: int) -> bool:
	return frame >= frame_start and frame <= frame_end
