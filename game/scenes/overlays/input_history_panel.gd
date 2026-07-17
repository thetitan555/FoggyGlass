extends Control
class_name InputHistoryPanel

## TKT-P1-09 — input display / history (training-mode.md → Readout: input;
## criterion 8). Per player: the current `InputFrame` decoded (directions +
## buttons) and a scrolling history of recent raw frames — the single input
## representation surfaced directly (Tenet 2), so input is never the hidden
## variable.
##
## SEAM DISCIPLINE. This node has no sim-internal type reference; it only
## ever touches `InspectionView`/`PlayerView` (via `InputHistoryPanelModel`) —
## mirrors `FrameDataPanel`/`LiveStatePanel`'s pattern exactly.

var _source: TrainingMode = null

@onready var _label: Label = $Label

## How many of the most recent history frames to render (display-only cap;
## see InputHistoryPanelModel.build). Lowered from 16 (docs/flags.md
## 2026-07-17 "re: HUD (round 2)") — at 16 rows this panel's REAL rendered
## text (both players' full history, wrapped) needed ~207px in the left
## column's available width, which didn't fit the safe vertical budget
## (`TrainingMode.HUD_LEFT_COLUMN_SAFE_MAX_Y`) alongside FrameDataPanel/
## LiveStatePanel. 8 rows is still a meaningful recent-input window for a
## debug readout and fits with real margin (verified in test_hud_layout.gd).
var max_rows: int = 8


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
	var rows: Array = InputHistoryPanelModel.build(view, max_rows)
	_label.text = _format(rows)


static func _format(rows: Array) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("-- Input --")
	for row in rows:
		lines.append(InputHistoryPanelModel.format_current(row))
		lines.append("  hist: %s" % InputHistoryPanelModel.format_history(row))
	return "\n".join(lines)
