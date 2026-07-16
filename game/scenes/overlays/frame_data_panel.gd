extends Control
class_name FrameDataPanel

## TKT-P1-07 — the frame-data & advantage panel (training-mode.md → Readout:
## frame data + advantage; criterion 6). Renders `FrameDataPanelModel`'s
## computed fields as text. All values come from the ONE InspectionView the
## shell hands over — this node has no sim-internal type reference; it only
## ever touches `InspectionView`/`FrameData`/`AdvantageView`/`HitEvent` (the
## view types) via the model.

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
	var model: Dictionary = FrameDataPanelModel.build(view)
	_label.text = _format(model)


static func _format(model: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("-- Frame Data --")
	for s in model["static"]:
		lines.append("P%d state %d  startup %d / active %d / recovery %d (total %d)  onHit %+d onBlock %+d" % [
			s["player"], s["state_id"], s["startup"], s["active"], s["recovery"], s["total"],
			s["on_hit_adv"], s["on_block_adv"],
		])
	var live: Dictionary = model["live"]
	var plus_str: String = "none" if live["plus_player"] == AdvantageView.PLUS_NONE else "P%d" % live["plus_player"]
	lines.append("Live advantage: %+d  plus=%s  toNeutral=%d  neutralRestored=%s" % [
		live["value"], plus_str, live["frames_to_neutral"], str(live["neutral_restored"]),
	])
	var why: String = FrameDataPanelModel.format_last_hit_why(model["last_hit_why"])
	if why != "":
		lines.append(why)
	var guard_line: String = FrameDataPanelModel.format_last_hit_guard(model["last_hit_guard"])
	if guard_line != "":
		lines.append(guard_line)
	return "\n".join(lines)
