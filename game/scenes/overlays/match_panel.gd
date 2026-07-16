extends Control
class_name MatchPanel

## The MATCH PANEL (TKT-P2-08; match-flow.md "Legibility" — health, round wins,
## the clock, phase, and *why* a round/match ended, all as serialized truth).
## Renders `MatchPanelModel`'s computed fields as text. Mirrors
## `LiveStatePanel`/`FrameDataPanel`'s exact shell shape (one Label, refreshed
## on `ticked`).
##
## SEAM DISCIPLINE. This node has no sim-internal type reference; it only ever
## touches `MatchView` (via the model) through `TrainingMode.match_view()` —
## never `MatchState`/`SimState` directly.
##
## MOUNTABLE IN EITHER MODE. `TrainingMode.match_view()` returns null outside
## match mode (sandbox sessions have no MatchState) — this panel renders the
## model's explicit "no match" placeholder rather than a blank/broken label in
## that case (the P1 lesson this ticket's brief names: a readout must actually
## render something a human can see, never a silently-inert surface).

var _source: TrainingMode = null

@onready var _label: Label = $Label


func set_source(source: TrainingMode) -> void:
	_source = source
	if _source != null and not _source.ticked.is_connected(_on_ticked):
		_source.ticked.connect(_on_ticked)
	_refresh()


func _on_ticked(_tick: int) -> void:
	_refresh()


func _refresh() -> void:
	if _source == null or _label == null:
		return
	var mv: MatchView = _source.match_view()
	var model: Dictionary = MatchPanelModel.build(mv)
	_label.text = MatchPanelModel.format(model)
