class_name TickHost
extends Node

## The fixed 60 Hz tick host (AD-004, simulation.md "The tick model").
##
## Responsibility: advance the simulation exactly ONE sim tick per intended
## tick, inside `physics_process`, off a tick counter that lives in sim state —
## never scaled by `delta`, never driven by the render clock. Render (`_process`
## / drawing) reads state and never advances it.
##
## SEAM CLOSED (TKT-P0-03). TKT-P0-01 landed this host with the fixed-tick clock
## discipline pinned against a minimal `_advance` seam over an `int` tick-only
## stand-in, because `SimState` / the pure `step(state, in_p1, in_p2)` and the
## InputSource contract did not yet exist (ratified JC-004; the 01->03 order is
## intended, not a defect). TKT-P0-03 now closes that seam:
##   - `_sim_state` is the real `SimState` (was an `int` stand-in).
##   - `_advance` calls `SimState.step(state, in1, in2)`, sourcing in1/in2 through
##     the InputSource contract (TKT-P0-02) — one call per source per tick, for the
##     current frame only (no future reads).
## The clock-authority discipline established at 01 is UNCHANGED by this swap
## (JC-004's binding constraint): still one `_advance` per `_physics_process`, the
## authoritative tick still read from state (`state.tick`), `delta` still never
## scales anything.
##
## What is load-bearing and preserved from 01:
##   1. The authoritative tick count is read from state (`_sim_state.tick`), not
##      from an engine frame counter (simulation.md criterion 5).
##   2. `_physics_process` runs gameplay; `delta` is never used to scale it.
##   3. Exactly one `_advance` per `_physics_process` call. Godot pins
##      physics_process to a fixed cadence (physics_ticks_per_second=60); if the
##      engine coalesces or drops physics steps, we still advance one tick per
##      call and never multiply by delta — so a render-rate change cannot change
##      sim outcomes.

## Emitted after each sim tick, so a view can refresh. Carries the new tick
## count (read from state) — views render from state, never advance it.
signal ticked(tick: int)

## Whether the host is advancing the sim. A view/menu can pause by clearing this;
## pausing is a host-level concern and does NOT touch determinism (no ticks run).
var running: bool = true

## The sim-state handle — the real serializable SimState (TKT-P0-03). The clock is
## `_sim_state.tick`, read via current_tick(); the host never keeps a separate
## engine-derived counter.
var _sim_state: SimState = null

## The two input sources (P1, P2), one per player (Tenet 2, input.md). The host
## holds them and calls each once per tick for the current frame; NOTHING here
## knows which concrete source it holds (local device, replay, ...). They are
## OUTSIDE SimState (sources are external to the sim, Tenet 2 / AD-020), so they
## are the host's members, not sim state.
var _source_p1: InputSource = null
var _source_p2: InputSource = null


func _ready() -> void:
	# Physics cadence is owned by project.godot (physics_ticks_per_second=60),
	# not asserted here — the host trusts the configured fixed cadence and only
	# guarantees one sim tick per physics_process call.
	# If no state was configured (e.g. host added to a scene with no explicit
	# setup), fall back to a valid initial state so the host is always runnable.
	if _sim_state == null:
		_sim_state = SimState.new_initial()


## Configure the host with a starting state and the two input sources. Called by
## whatever wires the match/scenario (the running game, a test, the QA harness).
## Keeping this explicit (not an autoload) matches AD-001: state is data wired in,
## not a global.
func setup(initial_state: SimState, source_p1: InputSource, source_p2: InputSource) -> void:
	_sim_state = initial_state
	_source_p1 = source_p1
	_source_p2 = source_p2


func _physics_process(_delta: float) -> void:
	# `_delta` is intentionally unused. Gameplay advancement must not depend on
	# it (technical-tenets §1, simulation.md tick model). It is named with a
	# leading underscore to make the non-use explicit and to satisfy the linter.
	if not running:
		return
	_sim_state = _advance(_sim_state)
	ticked.emit(current_tick())


## The single place one sim tick happens (TKT-P0-03: the seam is now the real
## step). Sources the current frame's input for each player through the InputSource
## contract, then advances via the pure, non-mutating `SimState.step`. The current
## frame is the state's own tick counter (`state.tick`), so a source is only ever
## asked for the frame the sim is about to run — never a future frame (input.md
## "no future reads"). The tick-authority discipline (one advance per call, clock
## from state, no delta) is unchanged from TKT-P0-01.
func _advance(state: SimState) -> SimState:
	var frame: int = state.tick
	var in_p1: int = _source_p1.get_input(frame) if _source_p1 != null else InputFrame.NEUTRAL
	var in_p2: int = _source_p2.get_input(frame) if _source_p2 != null else InputFrame.NEUTRAL
	return SimState.step(state, in_p1, in_p2)


## The authoritative sim tick count, read FROM STATE (simulation.md criterion 5).
## Not derived from Engine.get_physics_frames() or any engine counter.
func current_tick() -> int:
	return _sim_state.tick if _sim_state != null else 0


## The current sim state handle, for a view/harness to read (never to advance
## through — advancement is the host's job). Read-through to the real inspection
## surface lands at TKT-P0-04.
func get_state() -> SimState:
	return _sim_state


## Restore the host to a given state (serialize -> restore -> resume; TKT-P0-03,
## simulation.md criterion 3). A harness snapshots via state.to_dict(), later
## restores via SimState.from_dict(...) and hands the result here. Sources'
## playback position is coordinated by the training-mode harness above the sim
## (AD-020), not here — the host owns only the sim clock.
func set_state(state: SimState) -> void:
	_sim_state = state
