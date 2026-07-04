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
