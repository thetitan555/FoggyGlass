class_name MatchTickHost
extends Node

## The fixed 60 Hz tick host FOR THE MATCH LAYER (TKT-P2-08 integration; mirrors
## `TickHost` (AD-004, simulation.md "The tick model") exactly, one level up —
## over `MatchState`/`MatchState.match_step` instead of `SimState`/`SimState.step`.
##
## WHY A SEPARATE CLASS RATHER THAN GENERALIZING TickHost (latitude; logged
## docs/judgment-log.md). `TickHost` is a landed, tested contract other code
## (the sandbox training-mode path, `TrainingHarness`, every existing overlay
## test's `_make_shell()` helper) depends on as SimState-specific; broadening it
## to also carry a MatchState would touch a stable seam other roles rely on for
## no benefit to THIS ticket's scope (integration/tuning/readouts only, no new
## mechanics). A small, self-contained twin — same fixed-tick discipline, same
## one-tick-per-`_advance` guarantee, same "clock lives in state" rule, just
## walking `MatchState.match_step` instead of `SimState.step` — is the smaller,
## safer move and leaves `TickHost` completely untouched (Tenet 3: prefer the
## reading that leaves more doors open, here "don't disturb a working seam").
##
## Preserves every load-bearing discipline `TickHost`'s own header documents:
##   1. The authoritative tick count is read from state (`_match_state.sim.tick`),
##      never an engine frame counter (simulation.md criterion 5, extended to
##      match-flow.md's per-match determinism bar).
##   2. `_physics_process` runs gameplay; `delta` is never used to scale it.
##   3. Exactly one `_advance` per `_physics_process` call.

## Emitted after each match tick (mirrors TickHost.ticked), carrying the
## wrapped sim's tick count (read from state).
signal ticked(tick: int)

## Whether the host is advancing the match. A view/menu can pause by clearing
## this; pausing never touches determinism (no ticks run while paused).
var running: bool = true

## The match-state handle (TKT-P2-07, AD-048). The clock is
## `_match_state.sim.tick`, read via current_tick().
var _match_state: MatchState = null

## The two input sources (P1, P2) — Tenet 2, input.md — held exactly like
## TickHost's own (external to the match/sim state, never serialized here).
var _source_p1: InputSource = null
var _source_p2: InputSource = null


func _ready() -> void:
	# Mirrors TickHost's own fallback: a host added to a tree with no explicit
	# setup() call is still runnable (a valid, if fixed-id-agnostic, match).
	if _match_state == null:
		_match_state = MatchState.new_match(0, 0)


## Configure the host with a starting MatchState and the two input sources.
## Called by whatever wires the match (training-mode's match mode, a test).
func setup(initial_state: MatchState, source_p1: InputSource, source_p2: InputSource) -> void:
	_match_state = initial_state
	_source_p1 = source_p1
	_source_p2 = source_p2


func _physics_process(_delta: float) -> void:
	# `_delta` intentionally unused — see TickHost's identical note (technical-
	# tenets §1, simulation.md tick model).
	if not running:
		return
	_match_state = _advance(_match_state)
	ticked.emit(current_tick())


## The single place one MATCH tick happens: source the current frame's input
## for each player (the current frame is the WRAPPED sim's own tick counter,
## `state.sim.tick` — a source is only ever asked for the frame the match is
## about to run, input.md "no future reads"), then advance via the pure,
## non-mutating `MatchState.match_step`. During non-ACTIVE match phases,
## `match_step` itself does not advance combat (match-flow.md) — this host
## does not special-case that; it always calls match_step exactly once,
## and the match layer's own state machine decides what that tick means.
func _advance(state: MatchState) -> MatchState:
	var frame: int = state.sim.tick
	var in_p1: int = _source_p1.get_input(frame) if _source_p1 != null else InputFrame.NEUTRAL
	var in_p2: int = _source_p2.get_input(frame) if _source_p2 != null else InputFrame.NEUTRAL
	return MatchState.match_step(state, in_p1, in_p2)


## The authoritative match-sim tick count, read FROM STATE (mirrors TickHost.
## current_tick exactly, one level up).
func current_tick() -> int:
	return _match_state.sim.tick if _match_state != null else 0


## The current match-state handle, for a view/harness to read (never to
## advance through — advancement is this host's job, same rule as TickHost).
func get_match_state() -> MatchState:
	return _match_state


## Restore the host to a given MatchState (serialize -> restore -> resume;
## match-flow.md criterion 1). Mirrors TickHost.set_state exactly.
func set_match_state(state: MatchState) -> void:
	_match_state = state


# ---------------------------------------------------------------------------
# Frame control (mirrors TickHost's own — training-mode.md "Control layer" →
# Frame control; AD-010 — extended one level up to the match wrapper).
# ---------------------------------------------------------------------------

func set_paused(paused: bool) -> void:
	running = not paused


func is_paused() -> bool:
	return not running


## While paused, advance the match by EXACTLY ONE tick on demand — the SAME
## `_advance` `_physics_process` would call (mirrors TickHost.step_once exactly).
func step_once() -> void:
	_match_state = _advance(_match_state)
	ticked.emit(current_tick())
