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


## Install the authored roster (character_id -> Character). Called once by whatever
## wires the match/scenario/test, BEFORE the first `step`. Replacing it mid-run is a
## determinism hazard and not done by the sim.
static func install(roster: Dictionary) -> void:
	_roster = roster


## Clear the roster (test isolation between scenarios). Not called during a run.
static func clear() -> void:
	_roster = {}


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
