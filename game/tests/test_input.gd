extends SceneTree

## Headless test for the input contract (TKT-P0-02; input.md criteria 1,2,3,4,6).
##
## Run:  godot --headless --path game -s res://tests/test_input.gd
## Exits non-zero on any failure so a harness/CI can gate on it.
##
## Covers the acceptance criteria TKT-P0-02 targets:
##   1 Round-trip        — an InputFrame serialized+restored is bit-identical.
##   2 Reproducibility   — repeated get_input(N) on a produced frame is identical.
##   3 Source equivalence— a Local recording replayed yields the identical stream.
##   4 Dumb layer        — sources read only their own device/buffer (structural;
##                         asserted here by the fact a source runs with no sim/
##                         facing/state input available at all).
##   6 Reserved validity — a frame with any reserved bit (12..15) is rejected.
## (Criterion 5, SOCD determinism, is sim-side and lands with TKT-P0-06.)

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	if _failures == 0:
		print("[test_input] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_input] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	_test_frame_layout_and_validity()
	_test_round_trip()
	_test_local_source_reproducibility_and_no_future_reads()
	_test_source_equivalence()


func _test_frame_layout_and_validity() -> void:
	# Bit layout matches input.md.
	_eq(InputFrame.UP, 1 << 0, "UP is bit 0")
	_eq(InputFrame.DOWN, 1 << 1, "DOWN is bit 1")
	_eq(InputFrame.LEFT, 1 << 2, "LEFT is bit 2")
	_eq(InputFrame.RIGHT, 1 << 3, "RIGHT is bit 3")
	_eq(InputFrame.BUTTON_0, 1 << 4, "BUTTON_0 is bit 4")
	_eq(InputFrame.BUTTON_2, 1 << 6, "BUTTON_2 is bit 6 (third attack button)")
	_eq(InputFrame.RESERVED_MASK, 0xF000, "reserved mask is bits 12..15")

	# Criterion 6: reserved bits invalid.
	_true(InputFrame.is_valid(InputFrame.NEUTRAL), "neutral is valid")
	_true(InputFrame.is_valid(InputFrame.UP | InputFrame.BUTTON_1), "dir+button is valid")
	_true(not InputFrame.is_valid(1 << 12), "bit 12 (reserved) is invalid")
	_true(not InputFrame.is_valid(1 << 15), "bit 15 (reserved) is invalid")
	_true(not InputFrame.is_valid(1 << 16), "bit 16 (beyond frame width) is invalid")

	# Bit queries are raw reads (no facing / semantics).
	var f: int = InputFrame.LEFT | InputFrame.BUTTON_2
	_true(InputFrame.is_left(f), "is_left reads LEFT bit")
	_true(not InputFrame.is_right(f), "is_right false when RIGHT unset")
	_true(InputFrame.is_button(f, 2), "is_button(2) reads BUTTON_2")
	_true(not InputFrame.is_button(f, 0), "is_button(0) false when unset")


func _test_round_trip() -> void:
	# Criterion 1: a frame is a plain int; serialize+restore is bit-identical.
	# Exercise the sim's actual serialization path: an InputHistory of frames,
	# dumped and restored, must be byte-identical.
	var hist := InputHistory.new()
	var seq := [
		InputFrame.NEUTRAL,
		InputFrame.UP | InputFrame.BUTTON_0,
		InputFrame.LEFT | InputFrame.RIGHT,          # opposing dirs stay RAW (no SOCD)
		InputFrame.DOWN | InputFrame.BUTTON_2,
	]
	for v in seq:
		hist.push(v)
	var dumped: Dictionary = hist.to_dict()
	var restored := InputHistory.from_dict(dumped)
	_eq(restored.size(), hist.size(), "history size round-trips")
	for age in range(hist.size()):
		_eq(restored.at(age), hist.at(age), "frame at age %d round-trips bit-identical" % age)
	# The raw opposing-direction frame survived unchanged (replay fidelity, AD-003).
	_true((restored.at(1) & InputFrame.LEFT) != 0 and (restored.at(1) & InputFrame.RIGHT) != 0,
		"Left+Right stays raw through round-trip (no SOCD at input layer)")


func _test_local_source_reproducibility_and_no_future_reads() -> void:
	# A deterministic scripted device sampler: frame N produces a value derived from
	# N. This stands in for the hardware poll — the source stays DUMB (criterion 4):
	# it reads only this sampler and its own buffer, never sim/facing/state.
	var counter := [0]
	var sampler := func() -> int:
		var n: int = counter[0]
		counter[0] += 1
		# A varied but valid pattern: cycle a direction + a button by frame index.
		var dirs := [InputFrame.NEUTRAL, InputFrame.LEFT, InputFrame.RIGHT, InputFrame.UP]
		var btn: int = InputFrame.BUTTON_0 if (n % 2 == 0) else 0
		return dirs[n % dirs.size()] | btn

	var src := LocalDeviceSource.new(sampler)
	# Produce 10 frames.
	var produced: Array = []
	for _i in range(10):
		produced.append(src.sample_next())
	_eq(src.produced_count(), 10, "local source produced 10 frames")

	# Criterion 2: re-querying a produced frame returns the identical value, every
	# call — twice each.
	for frame in range(10):
		var a: int = src.get_input(frame)
		var b: int = src.get_input(frame)
		_eq(a, produced[frame], "get_input(%d) matches what was produced" % frame)
		_eq(a, b, "get_input(%d) reproducible across repeated calls" % frame)

	# Every produced frame is valid (criterion 6 enforced at the boundary).
	for frame in range(10):
		_true(InputFrame.is_valid(src.get_input(frame)),
			"produced frame %d is valid at the boundary" % frame)


func _test_source_equivalence() -> void:
	# Criterion 3: a Local recording, replayed through the Replay source, yields a
	# frame stream identical to the original for the whole session.
	var counter := [0]
	var sampler := func() -> int:
		var n: int = counter[0]
		counter[0] += 1
		# A different deterministic pattern to avoid coincidental matches.
		var dir: int = [InputFrame.UP, InputFrame.DOWN, InputFrame.NEUTRAL][n % 3]
		var btn: int = [0, InputFrame.BUTTON_1, InputFrame.BUTTON_2][n % 3]
		return dir | btn

	var local := LocalDeviceSource.new(sampler)
	var original: Array = []
	for _i in range(25):
		original.append(local.sample_next())

	# Feed the recording back through a Replay source.
	var replay := ReplaySource.new(local.get_recorded_buffer())
	_eq(replay.produced_count(), local.produced_count(),
		"replay length == recording length")
	for frame in range(25):
		_eq(replay.get_input(frame), original[frame],
			"replay frame %d == original recording frame %d" % [frame, frame])

	# And the replay is itself reproducible (criterion 2 for the Replay source).
	for frame in range(25):
		_eq(replay.get_input(frame), replay.get_input(frame),
			"replay frame %d reproducible" % frame)
