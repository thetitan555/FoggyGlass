extends Node2D
class_name TrainingMode

## TKT-P1-05 — the training-mode shell (training-mode.md "Architecture
## placement" + "Control layer"). Wires a match with two input sources
## (P1 = local device, P2 = the RecordPlaybackSource dummy), mounts the
## frame-control / reset / record-playback controls (TKT-P1-02/03/04, all
## landed on TickHost/TrainingHarness/RecordPlaybackSource in Batch 1), and
## provides the ONE surface the readout overlays render into.
##
## SEAM DISCIPLINE (criterion 10 — the load-bearing one QA checks). This node
## and everything it mounts reads sim truth ONLY through `inspection_view()`
## (an InspectionView) and drives the sim ONLY through the control contracts
## (`TickHost.set_paused/is_paused/step_once`, `TrainingHarness.capture_reset/
## do_reset`, `RecordPlaybackSource.set_mode/get_mode`). No overlay, and this
## shell itself, ever imports or type-hints `SimState`, `PlayerState`, or any
## other sim-internal type — grep for `SimState`/`PlayerState`/`ResolvedBox` in
## this file and the overlay scripts should turn up nothing. This is verifiable
## by inspection of dependencies (training-mode.md criterion 10).
##
## PLACEMENT. This scene is additive to `scenes/main.tscn` (the P0 scaffold),
## not a replacement — `main.tscn` stays the plain sim-runner other tests/tools
## may still target, while this scene is the actual debug/technical training
## mode a developer or QA opens to observe the sim (training-mode.md "what it
## is"). Not wired as `run/main_scene` (a judgment call — see docs/judgment-log.md).
##
## WHAT THIS OWNS (mirrors AD-020's "the training-mode harness sits above the
## sim and owns both the runner and the sources"):
##   - the TickHost (the runner)
##   - the two InputSources (P1 device passthrough via a RecordPlaybackSource in
##     PASSTHROUGH mode so the SAME control surface can flip P1 into RECORDING/
##     PLAYBACK too if a session wants to script P1; P2 is the dedicated dummy)
##   - the TrainingHarness (snapshot/restore + the single reset slot, coordinating
##     the sim state and both sources' playback positions, AD-020)
##   - the character roster (MoveRegistry/ProjectileRegistry install) this
##     session's InspectionView resolves frame data / boxes against
##
## CHARACTER-AGNOSTIC WIRING, CHARACTER-A DEFAULT. `_install_roster()` installs
## character A (the P1 done-bar's real, complete subject) by default; a test or
## a future session can call `configure()` before `_ready()` runs (or rebuild
## the scene) to point at a different roster — the shell itself has no
## character-specific branch beyond which id it defaults to.

## Emitted after every sim tick (mirrors TickHost.ticked) so mounted overlays
## can refresh from the fresh InspectionView. Overlays are expected to redraw
## '_process'/'_draw' driven, but tests / a non-visual driver can hook this.
signal ticked(tick: int)

@onready var _tick_host: TickHost = $TickHost

## The training-mode control harness (TKT-P1-02/03/04's home, per AD-020's
## "the training-mode harness" naming) — snapshot/restore, the single reset
## slot, and dummy-position coordination. Built over _tick_host once it exists.
var _harness: TrainingHarness = null

## P1's source. A RecordPlaybackSource in PASSTHROUGH by default (yields the
## local device) so the one control surface (mode switch) can also record/
## script P1 if a session wants a fully scripted 2P sequence — still exactly
## the one InputSource interface (Tenet 2), no special-cased "P1 is different"
## type.
var _source_p1: RecordPlaybackSource = null

## P2's source: the record/playback dummy (training-mode.md "Control layer" →
## dummy). Starts in PLAYBACK against an empty buffer (silently NEUTRAL) so a
## session is immediately steppable before anything is recorded.
var _source_p2: RecordPlaybackSource = null

## The character roster this session's InspectionView resolves against
## (character_id -> Character). Installed into MoveRegistry/ProjectileRegistry
## at _ready AND kept here so inspection_view() can hand it to InspectionView
## directly (mirrors how test code threads the roster) without a second global
## read path.
var _roster: Dictionary = {}

## Which character to install by default (character-a.md's CharacterA — P1's
## real, complete subject). Overridable via configure() before _ready() runs.
var _character_id: int = 0
var _character_builder: Callable = Callable()
var _projectile_registry_builder: Callable = Callable()


func _ready() -> void:
	if _character_builder.is_valid():
		_install_roster()
	else:
		_configure_default_character_a()
		_install_roster()

	_source_p1 = RecordPlaybackSource.new(Callable(self, "_sample_device_p1"))
	# TKT-P1.1R2-01 (AD-040): the dummy carries its OWN injected live sampler
	# (a distinct key set from P1's, see _sample_device_dummy below) so
	# RECORDING actually captures a human's input instead of silently emitting
	# NEUTRAL (the D1 defect — the dummy source previously had no live sampler
	# at all, so PASSTHROUGH/RECORDING both answered NEUTRAL and cycling `M`
	# was inert-in-effect). Starts in PASSTHROUGH, same default as before.
	_source_p2 = RecordPlaybackSource.new(Callable(self, "_sample_device_dummy"))

	var state := SimState.new_initial()
	_init_players_as_installed_character(state)
	_tick_host.setup(state, _source_p1, _source_p2)
	_tick_host.ticked.connect(_on_ticked)

	_harness = TrainingHarness.new(_tick_host)
	_harness.register_source("p1", _source_p1)
	_harness.register_source("p2", _source_p2)

	_wire_overlays()


## Auto-wire any mounted overlay child that exposes `set_source(TrainingMode)`
## (GeometryOverlay/FrameDataPanel/LiveStatePanel/InputHistoryPanel — TKT-P1-06..09).
## This is the shell "providing the surface the overlays render into"
## (training-mode.md "Architecture placement"): a `training_mode.tscn` session
## mounts whichever overlay children it wants as direct children of this node,
## and each is wired to read through THIS shell's `inspection_view()` without a
## test or scene author having to call set_source on every overlay by hand.
## Duck-typed on the method name (not a common base class) — a plain, minimal
## convention rather than a new interface type, since every overlay's only
## shared shape is "one method taking the shell."
func _wire_overlays() -> void:
	for child in get_children():
		if child.has_method("set_source"):
			child.call("set_source", self)


## Configure a non-default character roster before this node enters the tree
## (e.g. a test scene that wants the P0 test character instead of A). Not
## required for normal use — character A is the default (see header note).
func configure(character_id: int, builder: Callable, projectile_registry_builder: Callable = Callable()) -> void:
	_character_id = character_id
	_character_builder = builder
	_projectile_registry_builder = projectile_registry_builder


func _configure_default_character_a() -> void:
	_character_id = CharacterA.CHAR_ID
	_character_builder = Callable(CharacterA, "build_character")
	_projectile_registry_builder = Callable(CharacterA, "build_projectile_registry")


func _install_roster() -> void:
	var character: Resource = _character_builder.call()
	_roster = {_character_id: character}
	MoveRegistry.install(_roster)
	if _projectile_registry_builder.is_valid():
		ProjectileRegistry.install(_projectile_registry_builder.call())
	else:
		ProjectileRegistry.install({})


## TKT-P1.1-01 Part A (player-init code defect; training-mode.md "Players start
## as the installed character"). `SimState.new_initial()` alone leaves both
## players at the generic default `character_id 0 / state_id 0`, which the
## installed roster (keyed on `_character_id`, e.g. CharacterA.CHAR_ID = 2)
## never resolves — so `PlayerView.move` is null, `boxes == []`, and every
## frame-data/state readout reads zero/empty (the 2026-07-08 finding). Set both
## players to the installed character's id and its idle state so the roster
## lookup resolves from tick 0. CHARACTER-AGNOSTIC: reads `_character_id` and
## the roster's own `Character.idle_state_id` — no character-A-specific branch
## (works identically if `configure()` points the shell at a different roster).
func _init_players_as_installed_character(state: SimState) -> void:
	var character: Character = _roster[_character_id]
	for p in state.players:
		p.character_id = _character_id
		p.state_id = character.idle_state_id


func _physics_process(_delta: float) -> void:
	# Produce-before-query (input.md "owned invariant"): both sources must have
	# produced the current frame before the host's next step_once()/_advance
	# queries it. Mirrors main.gd's pattern (parent samples before the child
	# TickHost advances), extended to BOTH players since both are
	# RecordPlaybackSources here (Tenet 2 — same interface either way).
	#
	# Only auto-produce/advance while the host is RUNNING (not paused) — while
	# paused, frame-step is the ONLY way ticks happen (training-mode.md
	# criterion 2: "a paused sim does not advance"), driven explicitly via
	# step_once() below, which itself calls _harness.step_once() (produce +
	# advance as one op) rather than relying on this per-frame hook.
	if not _tick_host.running:
		return
	_source_p1.produce_next()
	_source_p2.produce_next()


## TKT-P1.1-02 (training-mode.md "Complete the P1 device sampler"; AD-018).
## Samples directions AND the three attack buttons into ONE raw InputFrame —
## still exactly the one InputSource shape (Tenet 2): no "P1 is special" type,
## no move/button-label semantics here (those live in the character's
## button_map, AD-018/AD-002). The three tm_button_* actions are placeholder
## key bindings (project.godot; see docs/judgment-log.md).
func _sample_device_p1() -> int:
	var frame: int = InputFrame.NEUTRAL
	if Input.is_action_pressed("ui_up"):
		frame |= InputFrame.UP
	if Input.is_action_pressed("ui_down"):
		frame |= InputFrame.DOWN
	if Input.is_action_pressed("ui_left"):
		frame |= InputFrame.LEFT
	if Input.is_action_pressed("ui_right"):
		frame |= InputFrame.RIGHT
	if Input.is_action_pressed("tm_button_0"):
		frame |= InputFrame.BUTTON_0
	if Input.is_action_pressed("tm_button_1"):
		frame |= InputFrame.BUTTON_1
	if Input.is_action_pressed("tm_button_2"):
		frame |= InputFrame.BUTTON_2
	return InputFrame.mask(frame)


## TKT-P1.1R2-01 (AD-040 "dummy-control operability model"). The dummy's own
## live-device sampler, mirroring _sample_device_p1's shape exactly (same
## InputFrame construction, same three-button convention) but on a DISTINCT
## key set (tm_dummy_*, project.godot) — a deliberate Developer latitude call
## (AD-040 offered "reuse P1's sampler" or "a dedicated dummy sampler";
## recorded in docs/judgment-log.md): a dedicated key set lets a human record
## a dummy sequence (e.g. hold down-back to crouch-block) WITHOUT also driving
## P1 on the same keys, and still resume driving P1 normally afterward — the
## AD-040 workflow ("the dummy loops it while the human resumes driving P1")
## reads cleanest when the two are never on the same physical keys. Still
## exactly the one InputSource shape (Tenet 2): no move/button semantics here.
func _sample_device_dummy() -> int:
	var frame: int = InputFrame.NEUTRAL
	if Input.is_action_pressed("tm_dummy_up"):
		frame |= InputFrame.UP
	if Input.is_action_pressed("tm_dummy_down"):
		frame |= InputFrame.DOWN
	if Input.is_action_pressed("tm_dummy_left"):
		frame |= InputFrame.LEFT
	if Input.is_action_pressed("tm_dummy_right"):
		frame |= InputFrame.RIGHT
	if Input.is_action_pressed("tm_dummy_button_0"):
		frame |= InputFrame.BUTTON_0
	if Input.is_action_pressed("tm_dummy_button_1"):
		frame |= InputFrame.BUTTON_1
	if Input.is_action_pressed("tm_dummy_button_2"):
		frame |= InputFrame.BUTTON_2
	return InputFrame.mask(frame)


func _on_ticked(tick: int) -> void:
	ticked.emit(tick)


# ---------------------------------------------------------------------------
# TKT-P1.1-02 — human control surface (training-mode.md "Human control
# surface" + criterion 13). Binds each control operation to a device/keyboard
# control (the tm_* input-map actions, project.godot), routed EXCLUSIVELY
# through this shell's own control methods below (never TickHost/
# TrainingHarness/RecordPlaybackSource directly — mirrors the read-only rule
# on the inspection side, criterion 10). Key choice is placeholder latitude
# (docs/judgment-log.md).
# ---------------------------------------------------------------------------

## Which player index the dummy-mode-cycle control affects. P2 (index 1) is
## "the dummy" (training-mode.md "Control layer" → Record/playback dummy) —
## P1 stays the human's own passthrough source. A future session that wants to
## cycle P1's mode instead can still do so via set_dummy_mode(0, ...) directly
## (unaffected by this binding).
const _DUMMY_CONTROL_PLAYER_INDEX: int = 1

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tm_pause"):
		set_paused(not is_paused())
	elif event.is_action_pressed("tm_step"):
		step_once()
	elif event.is_action_pressed("tm_capture_reset"):
		capture_reset()
	elif event.is_action_pressed("tm_do_reset"):
		do_reset()
	elif event.is_action_pressed("tm_dummy_mode_cycle"):
		_cycle_dummy_mode()


## Cycles the dummy's mode PASSTHROUGH -> RECORDING -> PLAYBACK -> PASSTHROUGH
## on each press — "dummy record/playback mode-switch" as a single reachable
## control (the ticket's one operation), rather than three separate keys.
## Routed through this shell's own set_dummy_mode/get_dummy_mode (never
## RecordPlaybackSource directly).
func _cycle_dummy_mode() -> void:
	var modes: Array = [
		RecordPlaybackSource.Mode.PASSTHROUGH,
		RecordPlaybackSource.Mode.RECORDING,
		RecordPlaybackSource.Mode.PLAYBACK,
	]
	var current: int = get_dummy_mode(_DUMMY_CONTROL_PLAYER_INDEX)
	var next_idx: int = (modes.find(current) + 1) % modes.size()
	set_dummy_mode(_DUMMY_CONTROL_PLAYER_INDEX, modes[next_idx])


# ---------------------------------------------------------------------------
# The ONE surface overlays read (criterion 10). A fresh InspectionView per
# call — cheap, read-only, and guarantees every caller sees the CURRENT tick's
# state (an overlay must not cache a view across ticks).
# ---------------------------------------------------------------------------

func inspection_view() -> InspectionView:
	return InspectionView.new(_tick_host.get_state(), _roster)


# ---------------------------------------------------------------------------
# Control layer passthrough (training-mode.md "Control layer"). Overlays / a
# control UI call these — never TickHost/TrainingHarness/RecordPlaybackSource
# directly bypassing this shell — so the shell stays the one place the sim is
# driven from (mirrors the read-only rule on the inspection side).
# ---------------------------------------------------------------------------

## Frame control (TKT-P1-02).
func set_paused(paused: bool) -> void:
	_tick_host.set_paused(paused)


func is_paused() -> bool:
	return _tick_host.is_paused()


## Advance exactly one tick. While paused this is a manual frame-step
## (training-mode.md criterion 1); it is routed through the harness so P2's
## dummy always produces its frame first (produce-before-query), matching
## _physics_process's running-loop behavior exactly (same phase pipeline, same
## input sourcing — AD-010's "frame-step crosses hitstop one tick per call").
func step_once() -> void:
	_harness.step_once()


## Situation save/restore + the single reset slot (TKT-P1-03; AD-020).
func capture_reset() -> void:
	_harness.capture_reset()


func do_reset() -> void:
	_harness.do_reset()


func has_reset_point() -> bool:
	return _harness.has_reset_point()


## Record/playback dummy mode switch (TKT-P1-04) for player index 0/1. Routed
## through the shell's own sources so a caller never touches
## RecordPlaybackSource directly from outside this node.
func set_dummy_mode(player_index: int, mode: int) -> void:
	_source_for(player_index).set_mode(mode)


func get_dummy_mode(player_index: int) -> int:
	return _source_for(player_index).get_mode()


func set_dummy_recorded_buffer(player_index: int, buffer: PackedInt32Array) -> void:
	_source_for(player_index).set_recorded_buffer(buffer)


func get_dummy_recorded_buffer(player_index: int) -> PackedInt32Array:
	return _source_for(player_index).get_recorded_buffer()


func _source_for(player_index: int) -> RecordPlaybackSource:
	return _source_p1 if player_index == 0 else _source_p2
