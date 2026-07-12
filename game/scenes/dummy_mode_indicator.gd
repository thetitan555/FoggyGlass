extends Control
class_name DummyModeIndicator

## TKT-P1.1R3-01 (AD-041 "Dummy-mode observability + fresh-record", re-gate-4
## E1). A minimal, LIVE on-screen readout of the P2 dummy's current mode
## (PASSTHROUGH / RECORDING / PLAYBACK), with a distinct RECORDING TELL
## ("* REC") -- the charter's observability standard. Root cause of E1: a
## human cycled tm_dummy_mode_cycle blind through three modes with ZERO
## feedback, so "only control P1 in PLAYBACK" (a neutral buffer) was
## indistinguishable from a broken feature.
##
## SEAM PLACEMENT. Mode lives on the RecordPlaybackSource, OUTSIDE SimState --
## not sim truth. Reads it via the shell's `get_dummy_mode` (never
## RecordPlaybackSource directly), so, like `ControlsLegend` (ratified
## JC-045), this sits OUTSIDE the InspectionView seam: criterion 10's
## seam-grep does not apply here (no InspectionView/SimState-internal type is
## ever touched -- verifiable by inspection).
##
## LIVE, NOT TICK-GATED. Unlike the InspectionView-backed overlays (which
## refresh on TrainingMode.ticked, since sim truth only changes on a tick),
## the dummy's mode can change via the `M` cycle key WHILE THE SIM IS PAUSED
## (no tick fires) -- so this polls every frame in `_process` rather than
## waiting for `ticked`, or a human pausing to inspect a captured recording
## would see a stale mode label (the same "invisible while paused" failure
## E1 already hit once). Cheap (one dictionary lookup + a label-text write),
## so a per-frame poll costs nothing worth avoiding here.
##
## Kept deliberately minimal (one Label, one static pure text builder --
## headlessly testable without a live Label/TrainingMode node, mirroring
## ControlsLegend's build_legend_text()) per the ticket's scope guard:
## legibility of the instrument, not UI polish.

const _MODE_NAMES: Dictionary = {
	RecordPlaybackSource.Mode.PASSTHROUGH: "PASSTHROUGH",
	RecordPlaybackSource.Mode.RECORDING: "RECORDING",
	RecordPlaybackSource.Mode.PLAYBACK: "PLAYBACK",
}

## Which player index this indicator reads: P2, the dummy TrainingMode's own
## mode-cycle control affects (mirrors that shell's
## _DUMMY_CONTROL_PLAYER_INDEX; kept a plain literal here rather than reaching
## into the shell's private constant -- this indicator has no other reason to
## depend on it).
const _DUMMY_PLAYER_INDEX: int = 1

var _source: TrainingMode = null

@onready var _label: Label = $Label


func set_source(source: TrainingMode) -> void:
	_source = source
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _source == null or _label == null:
		return
	_label.text = build_indicator_text(_source.get_dummy_mode(_DUMMY_PLAYER_INDEX))


## Pure text builder (headlessly testable without a live Label/TrainingMode):
## one line naming the mode, plus a distinct recording tell on RECORDING.
static func build_indicator_text(mode: int) -> String:
	var name: String = _MODE_NAMES.get(mode, "UNKNOWN")
	var line: String = "Dummy: %s" % name
	if mode == RecordPlaybackSource.Mode.RECORDING:
		line += "  * REC"
	return line
