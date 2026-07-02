class_name InputHistory
extends RefCounted

## Per-player ring buffer of recent RAW InputFrame values (simulation.md →
## players[i].input_history; AD-003).
##
## This is the substrate the sim's buffering / motion recognition reads (AD-022):
## a fixed-capacity window of the most recent raw frames, newest last. It stores
## RAW frames (SOCD not applied — SOCD is a separate sim-side function, AD-003),
## so replay fidelity is preserved end-to-end.
##
## CAPACITY (latitude, logged JC-008). Capacity is CAP frames. AD-022 fixes the
## slice's buffering windows at 9 (motion) and 6 (command); the history must cover
## the largest lookback any buffering rule needs, with generous headroom so a rule
## added later does not silently outrun the buffer. CAP = 32 covers the 9/6
## windows several times over while keeping the serialized state small. This is an
## internal storage detail (not a contract or a feel value — the WINDOWS are the
## feel values and live in AD-022, sim-side), so it is a latitude call. If a future
## buffering rule needs more lookback than CAP, that is a one-line bump here, not a
## contract change.
##
## SERIALIZATION. Stored as a flat PackedInt32Array plus a size, oldest→newest, so
## the serialized form is canonical (index order == age order) and byte-identical
## on round-trip regardless of the ring's internal write cursor. This keeps the
## state hash stable: two histories with the same logical content hash the same
## even if produced by different push sequences.

const CAP: int = 32

## Frames oldest → newest. Length is min(pushed, CAP). Newest is the last element.
var _frames: PackedInt32Array = PackedInt32Array()


## Push a raw frame as the newest entry, evicting the oldest once at capacity.
## Mutates this instance — `step` calls this only on its freshly-cloned next-state
## history, never on the input state (AD-004 non-mutation is preserved by the
## clone-then-mutate discipline in SimState.clone / step).
func push(frame: int) -> void:
	_frames.append(frame)
	if _frames.size() > CAP:
		_frames.remove_at(0)


## Number of frames currently held (0..CAP).
func size() -> int:
	return _frames.size()


## The frame `age` steps back from newest: at(0) is the newest, at(1) the one
## before, etc. Returns NEUTRAL for an age with no recorded frame yet (before the
## buffer has filled), so buffering rules can look back a fixed window without
## bounds-checking. `age` must be in 0..CAP-1.
func at(age: int) -> int:
	assert(age >= 0 and age < CAP, "InputHistory.at: age %d out of range 0..%d" % [age, CAP - 1])
	var idx: int = _frames.size() - 1 - age
	if idx < 0:
		return InputFrame.NEUTRAL
	return _frames[idx]


## The newest frame (age 0), or NEUTRAL if none pushed yet.
func newest() -> int:
	return at(0)


## Serialize to a plain-data dict (oldest→newest). No floats.
func to_dict() -> Dictionary:
	# Duplicate so the snapshot does not alias this instance's live array.
	return {"frames": _frames.duplicate()}


## Restore from a plain-data dict. Inverse of to_dict; exact round-trip.
static func from_dict(d: Dictionary) -> InputHistory:
	var h := InputHistory.new()
	var arr: PackedInt32Array = d["frames"]
	h._frames = arr.duplicate()
	return h


## Deep copy (for step's non-mutating clone of state).
func clone() -> InputHistory:
	var h := InputHistory.new()
	h._frames = _frames.duplicate()
	return h
