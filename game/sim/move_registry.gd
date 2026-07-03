class_name MoveRegistry
extends RefCounted

## The immutable authored-move-data registry the deterministic step reads (F-004).
##
## `step(state, in1, in2)` is a pure function of (state, inputs) GIVEN the fixed
## authored content — the move data, like the game's rules, is static input to the
## whole simulation, not mutable per-tick state (so it is not part of SimState —
## AD-001 keeps SimState the minimal mutable graph). This registry holds the
## character roster the sim resolves boxes / transitions / frame data against.
##
## DETERMINISM (Tenet 1). The registry is set ONCE at scenario/match wiring and is
## immutable during a run: every tick reads the same data, so `step` stays a
## deterministic function of (state, inputs). It is the same "authored content is a
## fixed input, not sim state" reasoning that keeps input SOURCES external. Because
## the data never changes mid-run, a snapshot/restore/replay reproduces identical
## results (the same registry is present) — the registry carries no per-tick state
## to serialize.
##
## RAISED AS FLAG F-004: how the deterministic step reaches authored move data is a
## contract-adjacent decision (it shapes the sim's data-access model QA and future
## devs build against). Implemented as a process-wide static roster set at wiring;
## the Architect may prefer threading the roster through `step` explicitly or another
## model — a localized change here + at the call sites.
##
## All static — a namespace over one static roster.

## character_id -> Character. Immutable during a run; replaced wholesale at wiring.
static var _roster: Dictionary = {}

## Install-generation token (AD-024, F-009 resolution; simulation.md crit 11). A
## monotonic counter bumped on EVERY `install`/`clear`, so the install-once /
## immutable-during-a-run precondition is CHECKABLE rather than only watched-for. The
## owned invariant QA asserts: the token observed at a run's first `step` is identical
## at every subsequent `step` of that run — a mid-run mutation bumps it and is
## detectable, not silent. This is wiring/precondition state, NOT `SimState`: it is the
## fixed-content precondition AD-024 keeps OUT of state (Tenet 2 / AD-001), so it is
## deliberately NOT serialized, cloned, or hashed — only observable via
## `install_generation()`.
static var _install_generation: int = 0


## Install the authored roster (character_id -> Character). Called once by whatever
## wires the match/scenario/test, BEFORE the first `step`. Replacing it mid-run is a
## determinism hazard and not done by the sim. Bumps the install-generation token.
static func install(roster: Dictionary) -> void:
	_roster = roster
	_install_generation += 1


## Clear the roster (test isolation between scenarios). Not called during a run.
## Bumps the install-generation token (a fresh roster starts a fresh run — the
## per-run token capture is re-taken; AD-024, simulation.md crit 11).
static func clear() -> void:
	_roster = {}
	_install_generation += 1


## The current install-generation token (AD-024, simulation.md crit 11). Observable
## precondition state, NOT sim state — read to assert the install-once/immutable
## invariant across a run's steps. Never serialized or hashed.
static func install_generation() -> int:
	return _install_generation


## The Character for an id, or null if unknown. `step` and the inspection surface
## resolve move data through this.
static func character(character_id: int) -> Character:
	if _roster.has(character_id):
		return _roster[character_id]
	return null


## The whole roster (for the inspection surface, which takes a roster). Returns the
## live dict; callers must treat it read-only.
static func roster() -> Dictionary:
	return _roster
