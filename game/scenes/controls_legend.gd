extends Control
class_name ControlsLegend

## TKT-P1.1-02 — minimal on-screen controls legend (training-mode.md "Human
## control surface" + criterion 13: "The bound controls are surfaced on
## screen"). Lists every bound control so a human can discover them without
## reading code.
##
## NOT a readout overlay (training-mode.md's "Readout layer" is all
## InspectionView-derived sim truth). This is operability UI: it reads only
## Godot's own InputMap for the action -> key text, never InspectionView or
## any sim-internal type — so it carries no seam dependency at all (there is
## nothing here for criterion 10's grep to catch). Reading InputMap directly
## (rather than hardcoding key names) also means the legend can never drift
## out of sync with the actual bindings in project.godot.
##
## Kept deliberately minimal per the ticket's scope guard ("legibility of the
## instrument, not UI polish"): one Label, static text, no interactivity.

## Action name -> short description, in the order the legend renders them.
## Directions aren't one of THIS ticket's bindings (ui_up/down/left/right are
## Godot's pre-existing built-in actions, already sampled by
## TrainingMode._sample_device_p1), but a human needs both to operate a
## session, so "Move" is listed as a plain leading line below, not looked up
## via InputMap.
const _ACTIONS: Array = [
	["tm_pause", "Pause / Resume"],
	["tm_step", "Frame-step (while paused)"],
	["tm_capture_reset", "Capture reset point"],
	["tm_do_reset", "Reset to captured point"],
	["tm_dummy_mode_cycle", "Cycle P2 dummy mode (Passthrough -> Recording -> Playback)"],
	["tm_button_0", "Attack - Button 0"],
	["tm_button_1", "Attack - Button 1"],
	["tm_button_2", "Attack - Button 2"],
]

@onready var _label: Label = $Label


func _ready() -> void:
	_label.text = build_legend_text()


## Pure text builder (headlessly testable without a live Label node): one line
## per bound action, plus the built-in movement keys, with key names read
## straight from Godot's InputMap.
static func build_legend_text() -> String:
	var lines: PackedStringArray = PackedStringArray(["CONTROLS", "Move: Arrow Keys"])
	for entry in _ACTIONS:
		var action: String = entry[0]
		var desc: String = entry[1]
		lines.append("%s: %s" % [desc, key_names_for(action)])
	return "\n".join(lines)


## The human-readable key name(s) bound to an action, joined with "/" (an
## action may carry more than one event). "(unbound)" if project.godot's input
## map doesn't define the action at all, so a misconfigured map shows up in
## the legend itself instead of silently rendering blank.
static func key_names_for(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "(unbound)"
	var names: PackedStringArray = PackedStringArray()
	for event in InputMap.action_get_events(action):
		names.append(event.as_text())
	if names.is_empty():
		return "(unbound)"
	return "/".join(names)
