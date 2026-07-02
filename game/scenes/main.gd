extends Node2D

## Root of the running game (TKT-P0-01 scaffold; wired to the real sim at
## TKT-P0-03).
##
## Wires the tick host with a real initial SimState and two input sources (Tenet 2,
## AD-001: state is data wired in, not a global). P1 reads the local device; P2 is
## an idle local source for now (a second controller / CPU / replay source drops in
## here later, all the same InputSource interface). The host advances the sim in
## _physics_process; this node only wires and renders FROM state (never advances
## it).
##
## Each tick the device sources must PRODUCE the current frame before the host
## queries it (no future reads, input.md). We sample the device on physics_process
## with the SAME cadence the host advances, ahead of the host's own advance. To
## guarantee ordering, this node's physics_process runs before the host samples by
## sampling here and relying on Godot's node order; if a future ticket needs a hard
## ordering guarantee, the host will own sampling directly. For P0 the device
## source is present and idle-safe (null sampler -> NEUTRAL) so nothing breaks.

@onready var _tick_host: TickHost = $TickHost

var _source_p1: LocalDeviceSource = null
var _source_p2: LocalDeviceSource = null


func _ready() -> void:
	# P1: local device. The sampler reads Godot Input and packs a raw InputFrame.
	# Kept as a Callable so the source has no compile-time engine-Input dependency
	# and stays dumb (input.md criterion 4).
	_source_p1 = LocalDeviceSource.new(Callable(self, "_sample_device_p1"))
	# P2: idle local source for the scaffold (no second device wired yet).
	_source_p2 = LocalDeviceSource.new()

	var state := SimState.new_initial()
	_tick_host.setup(state, _source_p1, _source_p2)
	_tick_host.ticked.connect(_on_ticked)


func _physics_process(_delta: float) -> void:
	# Produce the current frame for each source BEFORE the host advances (the host
	# is a child node; produce here at the parent so frames exist when the host
	# queries state.tick). Sampling is a device read, not sim math — it never enters
	# `step`, which consumes only the already-recorded frame via the source.
	if not _tick_host.running:
		return
	_source_p1.sample_next()
	_source_p2.sample_next()


func _sample_device_p1() -> int:
	# Read Godot's Input into a RAW InputFrame (physical directions, held buttons).
	# View-side device poll, OUTSIDE the sim (Tenet 2): the sim only ever sees the
	# recorded frame. Actions are project-input-map names; absent maps read as 0,
	# so this is safe before an input map is authored.
	var frame: int = InputFrame.NEUTRAL
	if Input.is_action_pressed("ui_up"):
		frame |= InputFrame.UP
	if Input.is_action_pressed("ui_down"):
		frame |= InputFrame.DOWN
	if Input.is_action_pressed("ui_left"):
		frame |= InputFrame.LEFT
	if Input.is_action_pressed("ui_right"):
		frame |= InputFrame.RIGHT
	# Attack buttons are authored into the project input map later; none bound yet.
	return InputFrame.mask(frame)


func _on_ticked(tick: int) -> void:
	# Render-side read only: reflect the sim clock. Never advances state.
	var label := get_node_or_null("TickLabel") as Label
	if label != null:
		label.text = "sim tick: %d" % tick
