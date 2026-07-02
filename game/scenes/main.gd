extends Node2D

## Root of the running game (TKT-P0-01 scaffold).
##
## For P0-01 this exists only to give the tick host a live home inside the
## engine's physics loop, and to be the anchor a future view renders under
## (AD-001: nodes render FROM sim state; they are not the state). It deliberately
## does almost nothing yet — the sim (03), inputs (02), and any real rendering
## land in later tickets.

@onready var _tick_host: TickHost = $TickHost


func _ready() -> void:
	# The host advances itself in _physics_process; nothing else to wire yet.
	# A debug label lets us eyeball that the state-owned clock is ticking at the
	# fixed cadence without depending on render timing.
	_tick_host.ticked.connect(_on_ticked)


func _on_ticked(tick: int) -> void:
	# Render-side read only: reflect the sim clock. Never advances state.
	var label := get_node_or_null("TickLabel") as Label
	if label != null:
		label.text = "sim tick: %d" % tick
