class_name ReplaySource
extends InputSource

## Replay input source (input.md → producers table, criteria 2, 3, 4).
##
## Reads a recorded buffer frame by frame. The buffer is exactly what a
## LocalDeviceSource recorded (see LocalDeviceSource.get_recorded_buffer): a
## "replay" is just a Local-device recording fed back through this source, and the
## two MUST produce identical streams for the same session (input.md criterion 3).
##
## DUMBNESS (input.md criterion 4). This source reads ONLY its own buffer. No
## facing, no character state, no SimState.
##
## FRAME DISCIPLINE. Unlike the Local source, a Replay already "has produced"
## every frame in its buffer the moment it is constructed (the recording exists in
## full). So get_input(frame) answers any frame in [0, size); a frame past the end
## of the recording is a future read (contract violation) — the recording simply
## does not contain it.
##
## Reproducibility (criterion 2) is trivially satisfied: the buffer is fixed at
## construction and get_input is a pure indexed read, so repeated get_input(N)
## always returns the identical value.

## The recorded raw frames, index == frame number. Fixed at construction.
var _buffer: PackedInt32Array = PackedInt32Array()


## Construct from a recorded buffer (typically LocalDeviceSource.get_recorded_
## buffer()). The buffer is duplicated so later mutation of the caller's copy
## cannot change this source's stream. Every entry is validated at construction so
## a corrupt recording is caught at the boundary (input.md criterion 6) rather
## than mid-run.
func _init(recorded_buffer: PackedInt32Array = PackedInt32Array()) -> void:
	_buffer = recorded_buffer.duplicate()
	for i in range(_buffer.size()):
		# Validate each recorded frame; validate() asserts in debug and strips to a
		# safe value in release, so a malformed recording cannot inject an invalid
		# frame into the sim.
		_buffer[i] = validate(_buffer[i])


## How many frames the recording contains. Frames [0, produced_count) are
## answerable; the recording does not extend past that.
func produced_count() -> int:
	return _buffer.size()


## The InputSource contract. Pure indexed read over the fixed buffer, so it is
## reproducible by construction. Reading past the end of the recording is a future
## read (the recording has no such frame) — a contract violation.
func get_input(frame: int) -> int:
	assert(frame >= 0, "ReplaySource.get_input: negative frame %d" % frame)
	assert(frame < _buffer.size(),
		"ReplaySource.get_input: frame %d past end of recording (length %d)"
		% [frame, _buffer.size()])
	if frame < 0 or frame >= _buffer.size():
		return InputFrame.NEUTRAL
	return _buffer[frame]
