class_name TrainingHarness
extends RefCounted

## The training-mode control-layer harness (training-mode.md → "Control layer");
## TKT-P1-02 (frame control, on TickHost directly) + TKT-P1-03 (situation
## save/restore + the single reset slot) + TKT-P1-04 (the dummy it coordinates
## resets against).
##
## THIS is "the training-mode harness" AD-020 and training-mode.md name as owning
## the reset coordination: it sits ABOVE the sim, holds both the TickHost (the
## runner) and the RecordPlaybackSource(s) (the sources), and is the one place
## "restore snapshot + rewind cursor" happens as a single operation. The sim
## itself still knows NOTHING about input sources (Tenet 2 intact) — this class
## is external wiring, not sim state, exactly like TickHost's own `_source_p1`/
## `_source_p2` fields are external wiring.
##
## STATEBLOB (training-mode.md: "snapshot() -> StateBlob / restore(StateBlob)").
## A StateBlob is the plain serialized-state Dictionary SimState.to_dict()/
## from_dict() already define — this harness does not invent a new format, it
## wraps the existing round-trip (SimHarness.dump_state/load_state) so
## snapshot/restore is exactly "serialize -> restore" (simulation.md
## "Serialization"; Tenet 1).
##
## SINGLE RESET SLOT (training-mode.md: "a single reset slot ... capture_reset()
## stores the reset point; do_reset() restores it"). No multi-slot: `_reset_point`
## is one Dictionary or null, overwritten wholesale by every capture_reset() call.
##
## RESET RESTORES SIM *AND* PLAYBACK POSITION (AD-020). The reset point bundles
## the sim StateBlob AND each RecordPlaybackSource's playback position (keyed by
## the source's own identity, e.g. "p1"/"p2" — a plain, order-independent key so
## the bundle is diffable/inspectable). do_reset() restores BOTH atomically: the
## TickHost's state, then every registered source's position — so a recorded
## sequence replays IN SYNC every rep (the dummy does not desync from a reset
## sim). Coordination lives HERE, in the harness, never in the sim (Tenet 2) and
## never pushed into RecordPlaybackSource itself (a source only knows its own
## position, never that a "reset" is happening around it).

## The tick host this harness drives frame control on and reads state from.
var _host: TickHost = null

## Registered RecordPlaybackSource instances, keyed by a caller-chosen string id
## (e.g. "p1", "p2") — NOT by player index alone, so a harness can register any
## number of dummies (the slice uses at most one P2 dummy, but the mechanism does
## not hardcode player count). Only RecordPlaybackSources are meaningful here;
## a plain LocalDeviceSource/ReplaySource has no "position" concept to restore.
var _sources: Dictionary = {}   # id (String) -> RecordPlaybackSource

## The single reset slot: null (nothing captured yet) or a Dictionary of
## { "sim": StateBlob, "sources": { id: position_dict, ... } }. Overwritten
## wholesale by every capture_reset() call (training-mode.md: "single reset
## slot", "additive to multi-slot, not a redesign").
var _reset_point = null


func _init(host: TickHost) -> void:
	_host = host


## Register a RecordPlaybackSource under a caller-chosen id so the reset point can
## capture/restore its playback position (AD-020). A harness with no dummy
## registered simply resets the sim alone — registration is opt-in, matching a
## 2P-local match with no dummy present.
func register_source(id: String, source: RecordPlaybackSource) -> void:
	_sources[id] = source


func unregister_source(id: String) -> void:
	_sources.erase(id)


## Produce the current tick's frame for every registered RecordPlaybackSource,
## THEN advance the sim exactly one tick (step_once). This is the harness acting
## as the "driver" input.md's produce-before-query ordering names (owned by
## whatever layer holds both the sources and the runner — here, this harness):
## a RecordPlaybackSource, unlike a scaffold LocalDeviceSource sampled by tree
## order (JC-009), has no engine hook of its own producing it every physics
## frame, so the layer that owns it must call produce_next() before the host
## queries get_input() for the same tick. Any OTHER source wired into the host
## (e.g. a real local device for P1) is expected to already have produced its
## current frame by whatever means it uses (device polling, tree order) before
## this is called — this method only drives the sources THIS harness owns.
func step_once() -> void:
	for id in _sources:
		var src: RecordPlaybackSource = _sources[id]
		src.produce_next()
	_host.step_once()


# ---------------------------------------------------------------------------
# Situation save / restore (training-mode.md: "snapshot() -> StateBlob /
# restore(StateBlob) — full serializable state round-trip", Tenet 1). This is
# the SIM-ONLY primitive (no source coordination) — capture_reset/do_reset below
# are what bundle it with playback positions for the training-mode reset point.
# ---------------------------------------------------------------------------

## Snapshot the host's current SimState as a plain StateBlob (Dictionary). Thin
## wrapper over SimState.to_dict() (via SimHarness) so the one snapshot format is
## shared with QA's harness (no second serialization path).
func snapshot() -> Dictionary:
	return SimHarness.dump_state(_host.get_state())


## Restore the host to a previously snapshotted StateBlob. Full serializable
## state round-trip (simulation.md criterion 3): resuming after a restore
## produces the sim as if it had been running from the restored state all along.
## Does NOT touch any source's playback position — this is the sim-only
## primitive; do_reset() below is what restores both together.
func restore(blob: Dictionary) -> void:
	_host.set_state(SimHarness.load_state(blob))


# ---------------------------------------------------------------------------
# Single reset slot (training-mode.md "Reset"; AD-020). capture_reset() stores
# ONE reset point — the sim StateBlob plus every registered source's playback
# position; do_reset() restores BOTH atomically. Repeated capture_reset() calls
# overwrite the one slot (no multi-slot, no history).
# ---------------------------------------------------------------------------

## Capture the current situation as the (single) reset point: the sim's
## StateBlob and every registered source's playback position, bundled together
## (AD-020) so a later do_reset() re-syncs both. Overwrites any previously
## captured reset point (single slot).
func capture_reset() -> void:
	var source_positions: Dictionary = {}
	for id in _sources:
		var src: RecordPlaybackSource = _sources[id]
		source_positions[id] = src.get_playback_position()
	_reset_point = {
		"sim": snapshot(),
		"sources": source_positions,
	}


## Restore the sim AND every registered source to the captured reset point
## (AD-020), as one operation — so a recorded dummy sequence replays identically
## from the reset point on every rep. A no-op if no reset point has been
## captured yet (nothing to restore to).
func do_reset() -> void:
	if _reset_point == null:
		return
	restore(_reset_point["sim"])
	var source_positions: Dictionary = _reset_point["sources"]
	for id in source_positions:
		if _sources.has(id):
			var src: RecordPlaybackSource = _sources[id]
			src.set_playback_position(source_positions[id])


## Whether a reset point has been captured (so a caller can guard do_reset(),
## e.g. disabling a "reset" control until one exists).
func has_reset_point() -> bool:
	return _reset_point != null
