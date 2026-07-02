class_name LocalDeviceSource
extends InputSource

## Local-device input source (input.md → producers table, criteria 2, 3, 4).
##
## Samples a device each tick and RECORDS the sampled value into a buffer indexed
## by frame, so past frames stay answerable (the contract's reproducibility +
## no-future-reads guarantees). This is the concrete source that reads real
## hardware in the running game; in tests/headless a scripted device function is
## injected so the source is exercised without an engine input poll.
##
## DUMBNESS (input.md criterion 4). This source reads ONLY its injected device
## sampler and its own recorded buffer. It never touches facing, character state,
## or SimState. The device sampler it calls is expected to produce a raw
## InputFrame value (directions as physically pressed, buttons as held); SOCD is
## NOT cleaned here (that is sim-side, AD-003).
##
## FRAME DISCIPLINE.
##   - The source produces frames strictly in order starting at 0. `sample_next()`
##     advances the internal cursor, sampling and recording the next frame. The
##     tick host calls `sample_next()` once per tick (this is how a Local source
##     "produces frame N" — by sampling it).
##   - get_input(frame) answers ONLY frames already produced (0 .. produced-1).
##     Re-querying a produced frame returns the identical recorded value
##     (criterion 2). Querying a not-yet-produced frame is a contract violation
##     (asserts; returns NEUTRAL in release).
##
## The recorded buffer is exactly the artifact the Replay source reads back
## (input.md: "A replay is just a Local-device recording fed back through the
## Replay source — they must produce identical streams"). `get_recorded_buffer()`
## hands it over; feeding it to a ReplaySource yields a bit-identical stream
## (criterion 3).

## The recorded raw frames, index == frame number. Grows by one per sample_next().
var _buffer: PackedInt32Array = PackedInt32Array()

## The device sampler: a Callable returning the raw InputFrame value for the frame
## about to be produced. Injected so hardware polling stays outside the source's
## own logic (and outside the sim entirely — engine polling is done by the caller
## that constructs this, never inside the sim). If null, samples NEUTRAL (useful
## for a source that is present but idle).
var _sampler: Callable


## Construct with an optional device sampler. In the running game the caller wires
## a sampler that reads Godot's Input singleton and packs it into an InputFrame;
## in tests a deterministic function is injected. Kept as a Callable so this
## source has no compile-time dependency on the engine Input API and stays dumb.
func _init(sampler: Callable = Callable()) -> void:
	_sampler = sampler


## Produce (sample + record) the next frame in order. Called once per tick by the
## host. Returns the value just produced. The sampled value is validated at the
## boundary (input.md criterion 6) before being recorded, so no invalid frame
## ever enters the buffer or the sim.
func sample_next() -> int:
	var raw: int = InputFrame.NEUTRAL
	if _sampler.is_valid():
		raw = int(_sampler.call())
	var frame_value: int = validate(raw)
	_buffer.append(frame_value)
	return frame_value


## How many frames this source has produced so far. Frames [0, produced_count)
## are answerable; frame == produced_count and beyond are not yet produced.
func produced_count() -> int:
	return _buffer.size()


## The InputSource contract. Answers only already-produced frames, reproducibly.
## A future read (frame >= produced_count) is a contract violation.
func get_input(frame: int) -> int:
	assert(frame >= 0, "LocalDeviceSource.get_input: negative frame %d" % frame)
	assert(frame < _buffer.size(),
		"LocalDeviceSource.get_input: future read — frame %d not yet produced (produced %d)"
		% [frame, _buffer.size()])
	if frame < 0 or frame >= _buffer.size():
		return InputFrame.NEUTRAL
	return _buffer[frame]


## The recorded buffer, for feeding to a ReplaySource (a "replay" is exactly this
## recording played back). Returned as a copy so a consumer cannot mutate this
## source's history and break reproducibility.
func get_recorded_buffer() -> PackedInt32Array:
	return _buffer.duplicate()
