extends Node2D
class_name GeometryOverlay

## TKT-P1-06 — the geometry overlay (training-mode.md → Readout: geometry;
## criterion 5). Draws every player's resolved `BoxView`s (and live
## projectiles' hit boxes, AD-021) in world space, color-coded by `kind`
## (hurt/hit/throw/push), with active hitboxes visually distinct from a
## resting hurtbox.
##
## SEAM DISCIPLINE (criterion 10). This node reads ONLY `InspectionView` (via
## the `TrainingMode` shell handed in at `set_source`) — `BoxView.rect` is
## already fixed-point world-space AABB truth; pixel conversion happens ONLY
## through `InspectionView.px_rect` (the render-only projection, AD-019). No
## SimState/PlayerState/ResolvedBox type is named anywhere in this file.
##
## VISUAL VERIFICATION NOTE. Exact color/pixel-placement correctness is a
## QA in-mode visual check (training-mode.md: "the overlays are visual ...
## pixel-exact rendering is verified in-mode at the feature audit"). What is
## unit-testable headlessly is the VIEW-MODEL this draws from — see
## `GeometryOverlayModel` below, which turns an InspectionView into the plain
## list of (color, px_rect) draw instructions without touching any Node2D/
## drawing API, so a headless test can assert "this BoxView produced this
## color for this kind" without a running renderer.

## The shell this overlay reads through (duck-typed to `inspection_view()` —
## kept as the concrete TrainingMode type since that IS the one seam-owning
## class other tickets also depend on; the overlay itself still only calls
## the one read method, never anything sim-internal).
var _source: TrainingMode = null


func set_source(source: TrainingMode) -> void:
	_source = source
	if _source != null and not _source.ticked.is_connected(_on_ticked):
		_source.ticked.connect(_on_ticked)


func _on_ticked(_tick: int) -> void:
	queue_redraw()


# =============================================================================
# TKT-P1.1-01 Part B — AD-035 render framing.
#
# A render-only world->screen transform applied to THIS node's own Transform2D
# (position + scale) — the "equivalent offset/zoom applied to the
# world-drawing node" AD-035 names as an alternative to a Camera2D. Because
# it's a transform on this node alone (not a viewport-wide Camera2D), the four
# screen-anchored HUD panels — SIBLINGS of this node under TrainingMode, never
# children of it — are completely unaffected "for free": no CanvasLayer
# restructuring needed to keep them screen-anchored (AD-035: "panels stay
# screen-anchored HUD, not moved by the framing").
#
# RENDER-ONLY (Tenet 1 / AD-019 / AD-035). This only ever sets this Node2D's
# `position`/`scale` — pure render/view state, never a SimState field. It is
# recomputed from the viewport size and the placeholder stage geometry below,
# and writes nothing back to the sim. The draw LIST this node renders
# (`GeometryOverlayModel.build_draw_list`) has no parameter and no dependency
# on this transform at all — a golden of that list, and of any SimState hash,
# is byte-identical whether or not this framing runs (see
# `test_geometry_overlay.gd`'s framing tests).
#
# PLACEHOLDER STAGE GEOMETRY (Developer's, like tuning — both the ticket and
# AD-035 call the exact numbers placeholder). These mirror
# `StageState.new_initial()`'s actual defaults (wall_left=-400, wall_right=400,
# ground_y=0, game units) but are plain literals here, not a read through
# `StageState`, because `StageState` is a sim-internal type this file's seam
# discipline excludes (see header). Recorded in the judgment log: if the seam
# later grows a live stage-bounds accessor, this should read it instead of
# assuming the shell's fixed initial stage — not needed for this ticket, since
# the acceptance bar (AD-035) is specifically the symmetric START positions,
# which sit well inside these bounds regardless of a future non-default stage.
const STAGE_WALL_LEFT: float = -400.0
const STAGE_WALL_RIGHT: float = 400.0
const STAGE_GROUND_Y: float = 0.0

## Horizontal fraction of the viewport width the stage width fills — the
## "margin" AD-035 asks for around the fitted stage width.
const WIDTH_FILL_FRACTION: float = 0.85

## Where the ground line sits vertically in the viewport, as a fraction of
## viewport height from the top — "seated in the lower portion of the view"
## (AD-035). Low enough that a standing character's hurtbox/pushbox (which
## extends below `ground_y` in this engine's box convention) stays clear of
## the panels, which occupy screen y ~16..380 (training_mode.tscn).
const GROUND_LINE_FRACTION: float = 0.78


func _ready() -> void:
	_apply_world_framing()
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_apply_world_framing):
		vp.size_changed.connect(_apply_world_framing)


## Pure computation (headlessly testable without a live viewport/window,
## `test_geometry_overlay.gd`): given a viewport size in pixels, the
## `position`/`scale` this node should carry so the stage
## (`STAGE_WALL_LEFT..STAGE_WALL_RIGHT`, `STAGE_GROUND_Y`) is centered
## horizontally, the ground line sits low, and the stage width fits with
## margin (AD-035). Returns `{"position": Vector2, "scale": Vector2}`.
static func compute_world_framing(viewport_size: Vector2) -> Dictionary:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return {"position": Vector2.ZERO, "scale": Vector2.ONE}
	var stage_width: float = STAGE_WALL_RIGHT - STAGE_WALL_LEFT
	var zoom: float = (viewport_size.x * WIDTH_FILL_FRACTION) / stage_width
	var stage_center_x: float = (STAGE_WALL_LEFT + STAGE_WALL_RIGHT) * 0.5
	var framed_position := Vector2(
		viewport_size.x * 0.5 - stage_center_x * zoom,
		viewport_size.y * GROUND_LINE_FRACTION - STAGE_GROUND_Y * zoom)
	return {"position": framed_position, "scale": Vector2(zoom, zoom)}


## Apply `compute_world_framing` to this node's own transform against the
## CURRENT viewport size. Called at `_ready()` and again on `size_changed` so
## a resized window stays framed. No-op if there is no viewport yet.
func _apply_world_framing() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var framing: Dictionary = compute_world_framing(vp.get_visible_rect().size)
	position = framing["position"]
	scale = framing["scale"]


func _draw() -> void:
	if _source == null:
		return
	var view: InspectionView = _source.inspection_view()
	var draws: Array = GeometryOverlayModel.build_draw_list(view)
	for d in draws:
		var rect: Rect2 = d["rect"]
		var color: Color = d["color"]
		if d["filled"]:
			draw_rect(rect, color, true)
		draw_rect(rect, color, false, d["border_width"])
