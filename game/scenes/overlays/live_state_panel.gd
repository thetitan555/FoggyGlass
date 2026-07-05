extends Control
class_name LiveStatePanel

## TKT-P1-08 — the live-state panel (training-mode.md → Readout: live state;
## criteria 7 and 9). Renders `LiveStatePanelModel`'s computed per-player rows
## as text: state + category + frame/duration, hitstop, stun + kind,
## actionable, invuln (AD-031), and damage/combo (hit_count, scaling_pct,
## damage_total).
##
## SEAM DISCIPLINE. This node has no sim-internal type reference; it only ever
## touches `InspectionView`/`PlayerView` (via the model) — mirrors
## `FrameDataPanel`'s pattern exactly (same shell, same one-Label rendering).

var _source: TrainingMode = null

@onready var _label: Label = $Label


func set_source(source: TrainingMode) -> void:
	_source = source
	if _source != null and not _source.ticked.is_connected(_on_ticked):
		_source.ticked.connect(_on_ticked)


func _on_ticked(_tick: int) -> void:
	_refresh()


func _refresh() -> void:
	if _source == null or _label == null:
		return
	var view: InspectionView = _source.inspection_view()
	var rows: Array = LiveStatePanelModel.build(view)
	_label.text = _format(rows)


static func _format(rows: Array) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("-- Live State --")
	for row in rows:
		lines.append(LiveStatePanelModel.format_row(row))
	return "\n".join(lines)
