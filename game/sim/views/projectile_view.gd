class_name ProjectileView
extends RefCounted

## Read-only view of one live projectile (inspection-surface.md → ProjectileView;
## AD-021).
##
## Plain-data projection of SimState.projectiles[idx]. Fixed-point position (sim
## truth; snapshot-able, no floats — AD-019); the hitbox is a BoxView (HIT) drawn by
## the geometry overlay. P0 spawns no projectiles; the shape is fixed here so P1
## (TKT-P1-0P) fills the runtime with no seam change.

var owner: int = 0
var position: Dictionary = {"x": 0, "y": 0}   # fixed-point
var box: BoxView = null
var lifetime_remaining: int = 0


func _init(state: SimState, idx: int) -> void:
	var pr: Projectile = state.projectiles[idx]
	owner = pr.owner
	position = {"x": pr.pos_x, "y": pr.pos_y}
	lifetime_remaining = pr.lifetime_remaining
	# The projectile's hitbox resolved to world space, as a HIT BoxView.
	var rb: ResolvedBox = pr.resolve_hitbox()
	if rb != null:
		box = BoxView.from_resolved(rb)
