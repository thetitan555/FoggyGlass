class_name GeometryOverlayModel
extends RefCounted

## Pure view-model for TKT-P1-06 (the geometry overlay). Turns an
## `InspectionView` into a plain list of draw instructions — no Node2D, no
## `_draw()`, no engine drawing API — so the color/kind mapping and box
## selection are headlessly testable (training-mode.md: pixel-exact
## rendering itself is a QA in-mode visual check; this view-model logic is
## not).
##
## COLOR-CODING (training-mode.md → Readout: geometry). Color-coded by `kind`
## (hurt/hit/throw/push); active hitboxes are visually distinct. `HitBox.
## hit_kind` (AD-031) is available on a HIT box's `hit` dict indirectly — but
## BoxView does not carry hit_kind directly (inspection-surface.md's BoxView
## table has `kind` = HURT/HIT/THROW/PUSH only). A PROJECTILE's hitbox surfaces
## through `ProjectileView.box`, which is always `KIND_HIT` per inspection-
## surface.md ("box: A BoxView (HIT) for its hitbox") — so this view-model
## gives projectile hitboxes their OWN distinct color by construction (drawn
## from `projectiles()`, not from a per-box hit_kind field the seam does not
## expose at the BoxView level), which is the finer color-coding the ticket
## invites ("if you want finer color-coding") without requiring a seam change.
##
## Colors are plain named constants here (render concern only — no sim truth).

const COLOR_HURT: Color = Color(0.2, 0.6, 1.0, 0.35)      # translucent blue
const COLOR_HIT: Color = Color(1.0, 0.2, 0.2, 0.55)        # red
const COLOR_THROW: Color = Color(1.0, 0.85, 0.1, 0.55)     # yellow
const COLOR_PUSH: Color = Color(0.6, 0.6, 0.6, 0.25)       # translucent gray
const COLOR_PROJECTILE: Color = Color(1.0, 0.5, 0.9, 0.55) # magenta — projectile hitbox, distinct from a character's HIT box

const BORDER_HURT: float = 1.0
const BORDER_PUSH: float = 1.0
## Active hit/throw boxes get a thicker border so they read as visually
## distinct from a resting hurtbox (training-mode.md: "active hitboxes are
## visually distinct" / criterion 5).
const BORDER_ACTIVE: float = 2.5


## Build the plain draw-instruction list for the current tick: one entry per
## resolved box across both players plus every live projectile's hitbox. Each
## entry is `{ "rect": Rect2, "color": Color, "filled": bool, "border_width":
## float, "kind": int }` — `kind`/`filled` exposed so a test can assert on the
## semantic classification without inspecting a Color value.
static func build_draw_list(view: InspectionView) -> Array:
	var out: Array = []
	for i in range(2):
		var pv: PlayerView = view.player(i)
		for box in pv.boxes:
			out.append(_draw_entry_for_box(box))
	for proj in view.projectiles():
		if proj.box != null:
			out.append(_draw_entry_for_projectile_box(proj.box))
	return out


static func _draw_entry_for_box(box: BoxView) -> Dictionary:
	var color: Color
	var filled: bool
	var border: float
	match box.kind:
		BoxView.KIND_HURT:
			color = COLOR_HURT
			filled = false
			border = BORDER_HURT
		BoxView.KIND_HIT:
			color = COLOR_HIT
			filled = true
			border = BORDER_ACTIVE
		BoxView.KIND_THROW:
			color = COLOR_THROW
			filled = true
			border = BORDER_ACTIVE
		BoxView.KIND_PUSH:
			color = COLOR_PUSH
			filled = false
			border = BORDER_PUSH
		_:
			color = COLOR_HURT
			filled = false
			border = BORDER_HURT
	return {
		"rect": InspectionView.px_rect(box.rect),
		"color": color,
		"filled": filled,
		"border_width": border,
		"kind": box.kind,
	}


## A projectile's carried hitbox is always BoxView.KIND_HIT (inspection-
## surface.md), but is drawn with its own color (COLOR_PROJECTILE) so it reads
## distinctly from a character's own active hitbox — the finer color-coding
## TKT-P1-06 invites, expressed at the draw-list level (the seam's BoxView
## shape is untouched).
static func _draw_entry_for_projectile_box(box: BoxView) -> Dictionary:
	return {
		"rect": InspectionView.px_rect(box.rect),
		"color": COLOR_PROJECTILE,
		"filled": true,
		"border_width": BORDER_ACTIVE,
		"kind": box.kind,
	}
