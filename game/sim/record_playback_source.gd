class_name RecordPlaybackSource
extends InputSource

## The training-mode record/playback dummy (training-mode.md → "Record / playback
## dummy"; input.md producers table; Tenet 2 — an INPUT SOURCE, not an AI).
##
## Implements InputSource with three modes over a single raw InputFrame buffer:
##   PASSTHROUGH — yields the live device frames for its player (no recording).
##   RECORDING   — yields live frames AND appends each to the buffer.
##   PLAYBACK    — yields buffered frames in order, LOOPING at the end.
##
## Mode switches are deterministic (a plain field write, no engine/wall-clock
## input); the buffer is the recorded raw InputFrame stream — the dummy has NO
## behavior/AI of its own. Any "reaction" is recorded or scripted input flowing
## through this one interface, exactly like every other InputSource.
##
## DUMBNESS (input.md criterion 4). This source reads ONLY its own buffer, its
## injected live-frame Callable (for PASSTHROUGH/RECORDING), and its own playback
## cursor. It never touches facing, character state, or SimState.
##
## FRAME DISCIPLINE / PRODUCE-BEFORE-QUERY (input.md "owned invariant"). Like
## LocalDeviceSource, this source must PRODUCE a frame before the driver queries
## it. `produce_next()` is the one place a frame is produced each tick — the
## driver (training-mode harness / tick host wiring) calls it once per tick,
## mirroring LocalDeviceSource.sample_next(). get_input(frame) then answers only
## already-produced frames.
##
## PASSTHROUGH / RECORDING both need a live per-tick frame from SOMEWHERE (a real
## device in a 2P local match, or the training-mode's own device sampling). That
## is supplied via an injected Callable — same "no compile-time engine dependency,
## stays dumb" pattern as LocalDeviceSource — so this class has zero knowledge of
## Godot's Input singleton.
##
## RESTORABLE PLAYBACK POSITION (AD-020; training-mode.md "Reset restores sim AND
## playback position"). `_produced_count` and, in PLAYBACK, `_playback_cursor` are
## the dummy's position; `get_playback_position()` / `set_playback_position()`
## expose them read/write so the training-mode reset harness (TKT-P1-03) can
## snapshot and restore them alongside the sim StateBlob — the coordination lives
## in that harness, not here and not in the sim (Tenet 2 stays intact: the sim
## still knows nothing about sources).

enum Mode { PASSTHROUGH, RECORDING, PLAYBACK }

## Current mode. A plain field switch — deterministic, no hidden state machine.
var mode: int = Mode.PASSTHROUGH

## The recorded/authored raw frames, index == frame number recorded, oldest first.
## In PASSTHROUGH this stays whatever was previously recorded (untouched); in
## RECORDING it grows by one per produce_next(); in PLAYBACK it is read, never
## appended.
var _buffer: PackedInt32Array = PackedInt32Array()

## How many frames THIS SOURCE has produced (answerable range [0, _produced_count)
## for get_input — the InputSource contract's frame-indexed history). In
## PASSTHROUGH/RECORDING this equals the number of produce_next() calls so far
## (each tick emits a fresh, never-before-seen frame in the source's own answer
## history, even though PASSTHROUGH does not grow `_buffer`). In PLAYBACK it also
## counts produce_next() calls; the VALUE returned loops over `_buffer` via
## `_playback_cursor`, but every call is still a genuinely new "produced" frame
## for reproducibility purposes (see get_input notes below).
var _produced_count: int = 0

## Answers already produced, index == frame number (parallel to _produced_count).
## Populated by every produce_next() call regardless of mode, so get_input has one
## uniform reproducible history to read back — mirroring LocalDeviceSource, whose
## `_buffer` IS this answer history. Kept distinct from `_buffer` (the RECORDING
## artifact / PLAYBACK script) because in PLAYBACK the two differ once the script
## loops (the answer history keeps growing; the script is fixed-length and reread).
var _answers: PackedInt32Array = PackedInt32Array()

## Playback cursor: index into `_buffer` for the NEXT frame PLAYBACK will emit.
## Loops (wraps to 0) once it reaches the end of a non-empty buffer. This is the
## "playback position" AD-020 requires be readable/restorable.
var _playback_cursor: int = 0

## The live-frame source for PASSTHROUGH / RECORDING: a Callable returning the raw
## InputFrame value for the frame about to be produced (e.g. a real device sampler,
## or another InputSource's current-tick value in a 2P local match). Injected so
## this class has no compile-time device dependency. If null, live frames sample
## NEUTRAL — a safe default for headless tests / an idle dummy.
var _live_sampler: Callable


## Construct with an optional live-frame sampler (used by PASSTHROUGH/RECORDING)
## and a starting mode (default PASSTHROUGH — an idle dummy is a plain pass-through
## until switched).
func _init(live_sampler: Callable = Callable(), start_mode: int = Mode.PASSTHROUGH) -> void:
	_live_sampler = live_sampler
	mode = start_mode


# ---------------------------------------------------------------------------
# Mode switches (training-mode.md: "Mode switches are deterministic").
# ---------------------------------------------------------------------------

func set_mode(new_mode: int) -> void:
	mode = new_mode


func get_mode() -> int:
	return mode


# ---------------------------------------------------------------------------
# Production (called once per tick by the driver, before the sim queries the
# current frame — input.md "produce-before-query", owned by the driver/harness).
# ---------------------------------------------------------------------------

## Produce (and, in RECORDING, record) the next frame in order. Returns the value
## just produced. The value is validated at the boundary (input.md criterion 6)
## before it is recorded or answered, so an invalid frame can never enter the sim.
func produce_next() -> int:
	var frame_value: int
	match mode:
		Mode.PASSTHROUGH:
			frame_value = validate(_sample_live())
			# PASSTHROUGH does not touch `_buffer` — nothing is recorded.
		Mode.RECORDING:
			frame_value = validate(_sample_live())
			_buffer.append(frame_value)
		Mode.PLAYBACK:
			frame_value = validate(_read_playback_and_advance())
		_:
			frame_value = InputFrame.NEUTRAL
	_answers.append(frame_value)
	_produced_count += 1
	return frame_value


func _sample_live() -> int:
	if _live_sampler.is_valid():
		return int(_live_sampler.call())
	return InputFrame.NEUTRAL


## Read the buffer at the playback cursor and advance it, LOOPING at the end
## (training-mode.md: "PLAYBACK — yields buffered frames in order, looping at the
## end"). An empty buffer plays back as NEUTRAL forever (nothing recorded yet).
func _read_playback_and_advance() -> int:
	if _buffer.is_empty():
		return InputFrame.NEUTRAL
	var value: int = _buffer[_playback_cursor]
	_playback_cursor += 1
	if _playback_cursor >= _buffer.size():
		_playback_cursor = 0
	return value


## How many frames this source has produced so far (answerable range for
## get_input). Mirrors LocalDeviceSource.produced_count().
func produced_count() -> int:
	return _produced_count


# ---------------------------------------------------------------------------
# The InputSource contract.
# ---------------------------------------------------------------------------

## Answers only already-produced frames, reproducibly (input.md criteria 2, 7): a
## produced frame's value never changes on re-query, and a future read (frame >=
## produced_count) is a contract violation.
func get_input(frame: int) -> int:
	assert(frame >= 0, "RecordPlaybackSource.get_input: negative frame %d" % frame)
	assert(frame < _answers.size(),
		"RecordPlaybackSource.get_input: future read — frame %d not yet produced (produced %d)"
		% [frame, _answers.size()])
	if frame < 0 or frame >= _answers.size():
		return InputFrame.NEUTRAL
	return _answers[frame]


# ---------------------------------------------------------------------------
# Recorded buffer access (training-mode.md; input.md "A replay is just a
# Local-device recording fed back through the Replay source").
# ---------------------------------------------------------------------------

## The recorded/authored buffer (RECORDING appends to this; PLAYBACK reads it).
## Returned as a copy so a caller cannot mutate this source's script and break
## reproducibility.
func get_recorded_buffer() -> PackedInt32Array:
	return _buffer.duplicate()


## Replace the buffer wholesale — e.g. to author a scripted PLAYBACK sequence
## directly, or to seed RECORDING from a prior capture. Each entry is validated at
## the boundary (input.md criterion 6) so a corrupt/authored buffer cannot inject
## an invalid frame into the sim. Does not touch the playback cursor or produced
## history — callers typically set the buffer before switching to PLAYBACK.
func set_recorded_buffer(buffer: PackedInt32Array) -> void:
	_buffer = buffer.duplicate()
	for i in range(_buffer.size()):
		_buffer[i] = validate(_buffer[i])


## Reset the PLAYBACK cursor to the start of the buffer (index 0), without
## touching the buffer itself or the produced/answer history (TKT-P1.1R3-01,
## AD-041 "fresh-record"). Used by the training-mode shell on RECORDING entry,
## paired with `set_recorded_buffer(PackedInt32Array())` there, so a re-take
## REPLACES the prior recording (fresh buffer, cursor at 0) instead of
## concatenating onto it. A minimal, dedicated primitive rather than reusing
## `set_playback_position` (which also restores `_produced_count`/`_answers` —
## fields this shell-level operation must NOT disturb, since the source keeps
## producing/answering frames every tick regardless of mode).
func reset_playback_cursor() -> void:
	_playback_cursor = 0


# ---------------------------------------------------------------------------
# Restorable playback position (AD-020; training-mode.md "Reset restores sim AND
# playback position"). The reset harness (TKT-P1-03) snapshots/restores this
# alongside the sim StateBlob so a recorded sequence replays IN SYNC every rep.
# This position is EXTERNAL to SimState (Tenet 2: sources are outside the sim) —
# the coordination lives in the training-mode harness, not here.
# ---------------------------------------------------------------------------

## The full restorable position: playback cursor + how many frames have been
## produced (so get_input's reproducibility range is restored too — a restore
## must make future get_input calls behave exactly as they did at capture time).
## A plain Dictionary of ints — snapshot-able, no floats, no live refs.
func get_playback_position() -> Dictionary:
	return {
		"playback_cursor": _playback_cursor,
		"produced_count": _produced_count,
		"answers": _answers.duplicate(),
	}


## Restore a position captured by get_playback_position(). Restores the playback
## cursor AND the produced-frame answer history, so get_input(frame) for any frame
## in the restored range answers exactly as it did at capture time (reproducibility
## survives the reset, input.md criterion 2) and PLAYBACK resumes from the same
## point in its script. Does not touch `_buffer` (the recorded/authored script
## itself is not reset — only the read/write CURSOR into it is, matching AD-020:
## "restores... the playback position," not the recording).
func set_playback_position(pos: Dictionary) -> void:
	_playback_cursor = int(pos["playback_cursor"])
	_produced_count = int(pos["produced_count"])
	var answers: PackedInt32Array = pos["answers"]
	_answers = answers.duplicate()
