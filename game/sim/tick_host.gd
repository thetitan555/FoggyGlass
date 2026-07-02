class_name TickHost
extends Node

## The fixed 60 Hz tick host (AD-004, simulation.md "The tick model").
##
## Responsibility: advance the simulation exactly ONE sim tick per intended
## tick, inside `physics_process`, off a tick counter that lives in sim state —
## never scaled by `delta`, never driven by the render clock. Render (`_process`
## / drawing) reads state and never advances it.
##
## SEAM NOTE (TKT-P0-01): `SimState` and the pure `step(state, in_p1, in_p2)`
## function are TKT-P0-03; the input contract is TKT-P0-02. This host therefore
## advances against a minimal seam it does not own the far side of:
##   - `_sim_state`   : opaque state handle (an `int` tick-only stand-in for now;
##                      becomes the real `SimState` at 03).
##   - `_advance(state) -> next_state` : the single place a tick happens.
## When 03 lands, `_advance` becomes `SimStim.step(state, in1, in2)` sourced
## through the InputSource contract (02); the host's tick-authority logic here
## does not change. The point of landing the host now is to pin the clock
## discipline (fixed tick, state-owned counter, no delta) before any gameplay
## fills it in.
##
## What is load-bearing and MUST survive into 03:
##   1. The authoritative tick count is read from state, not from an engine
##      frame counter (simulation.md criterion 5).
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

## The sim-state handle. TKT-P0-01 stand-in: an integer holding only the tick
## count, exercising the "clock lives in state" discipline end-to-end without a
## real SimState. TKT-P0-03 replaces the type with `SimState` and this init with
## a real initial state.
var _sim_state: int = 0


func _ready() -> void:
	# Physics cadence is owned by project.godot (physics_ticks_per_second=60),
	# not asserted here — the host trusts the configured fixed cadence and only
	# guarantees one sim tick per physics_process call.
	pass


func _physics_process(_delta: float) -> void:
	# `_delta` is intentionally unused. Gameplay advancement must not depend on
	# it (technical-tenets §1, simulation.md tick model). It is named with a
	# leading underscore to make the non-use explicit and to satisfy the linter.
	if not running:
		return
	_sim_state = _advance(_sim_state)
	ticked.emit(current_tick())


## The single place one sim tick happens. TKT-P0-01 stand-in: advance the
## tick-only state by one. TKT-P0-03 replaces the body with the pure step:
##   return SimSim.step(state, in1, in2)
## sourcing in1/in2 through the InputSource contract (TKT-P0-02). Kept as one
## function so the tick-authority discipline above is unchanged by that swap.
func _advance(state: int) -> int:
	return state + 1


## The authoritative sim tick count, read FROM STATE (simulation.md criterion 5).
## Not derived from Engine.get_physics_frames() or any engine counter. When 03
## lands this reads `state.tick`; here the stand-in state IS the tick.
func current_tick() -> int:
	return _sim_state


## Reset the host's clock to a given tick-state. Real state restore is TKT-P0-03
## (serialize -> restore -> resume); this exists so the seam is exercised and a
## harness can set a known starting point.
func set_state(state: int) -> void:
	_sim_state = state
