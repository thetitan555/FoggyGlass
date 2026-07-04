extends SceneTree

## Headless test for the training-mode harness (TKT-P1-03): situation
## snapshot/restore + the single reset slot, and its coordination with the
## record/playback dummy's position (AD-020). training-mode.md criteria 3
## (reset) and 12 (reset re-syncs the dummy).
##
## Run:  godot --headless --path game -s res://tests/test_training_harness.gd
## Exits non-zero on any failure so a harness/CI can gate on it.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	if _failures == 0:
		print("[test_training_harness] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_training_harness] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	_test_snapshot_restore_round_trip()
	_test_reset_repeats_exact_state()
	_test_reset_resyncs_dummy_playback()


func _pre_produce(src: LocalDeviceSource, n: int) -> void:
	for _k in range(n):
		src.sample_next()


# --- snapshot/restore (the sim-only primitive) -------------------------------

func _test_snapshot_restore_round_trip() -> void:
	var host := TickHost.new()
	var s1 := LocalDeviceSource.new()
	var s2 := LocalDeviceSource.new()
	_pre_produce(s1, 16)
	_pre_produce(s2, 16)
	host.setup(SimState.new_initial(5), s1, s2)
	var harness := TrainingHarness.new(host)

	for _k in range(4):
		host.step_once()
	var blob: Dictionary = harness.snapshot()
	var hash_at_snapshot: int = host.get_state().hash_state()

	for _k in range(6):
		host.step_once()
	_true(host.get_state().hash_state() != hash_at_snapshot,
		"advancing past the snapshot changes the state hash (sanity)")

	harness.restore(blob)
	_eq(host.get_state().hash_state(), hash_at_snapshot,
		"restore(snapshot()) returns to the exact snapshotted state (hash equal)")
	host.free()


# --- criterion 3: reset (single slot) ----------------------------------------

func _test_reset_repeats_exact_state() -> void:
	var host := TickHost.new()
	var s1 := LocalDeviceSource.new()
	var s2 := LocalDeviceSource.new()
	_pre_produce(s1, 32)
	_pre_produce(s2, 32)
	host.setup(SimState.new_initial(9), s1, s2)
	var harness := TrainingHarness.new(host)

	for _k in range(3):
		host.step_once()
	harness.capture_reset()
	var hash_at_capture: int = host.get_state().hash_state()
	_true(harness.has_reset_point(), "has_reset_point true after capture_reset")

	# Rep 1: play forward, then reset.
	for _k in range(10):
		host.step_once()
	_true(host.get_state().hash_state() != hash_at_capture, "playing forward changes the hash (sanity)")
	harness.do_reset()
	_eq(host.get_state().hash_state(), hash_at_capture,
		"do_reset() returns to the exact captured state (hash equal) — rep 1")

	# Rep 2: reps are REPEATABLE — play forward differently, reset again, same result.
	for _k in range(5):
		host.step_once()
	harness.do_reset()
	_eq(host.get_state().hash_state(), hash_at_capture,
		"a second do_reset() also returns to the exact captured state — rep 2 (repeatable)")

	# A single slot: capturing again overwrites it (no multi-slot / no history).
	for _k in range(2):
		host.step_once()
	harness.capture_reset()
	var new_capture_hash: int = host.get_state().hash_state()
	_true(new_capture_hash != hash_at_capture, "the new capture is at a different state (sanity)")
	for _k in range(4):
		host.step_once()
	harness.do_reset()
	_eq(host.get_state().hash_state(), new_capture_hash,
		"capture_reset overwrites the single slot; do_reset restores the LATEST capture")
	host.free()


# --- criterion 12: reset re-syncs the dummy (AD-020) -------------------------

func _test_reset_resyncs_dummy_playback() -> void:
	# Record a dummy sequence, capture_reset(), play forward, do_reset() -> the
	# dummy replays the IDENTICAL inputs from the reset point and the whole rep is
	# bit-identical on repeat (training-mode.md criterion 12).
	MoveRegistry.install(TestSupport.build_roster())

	var host := TickHost.new()
	var p1_src := LocalDeviceSource.new()
	_pre_produce(p1_src, 64)

	# The dummy: pre-load an authored script and put it in PLAYBACK so the whole
	# scenario is deterministic and self-contained (no live device needed).
	var dummy := RecordPlaybackSource.new()
	dummy.set_recorded_buffer(PackedInt32Array([
		InputFrame.NEUTRAL, InputFrame.LEFT, InputFrame.NEUTRAL,
		InputFrame.RIGHT, InputFrame.NEUTRAL, InputFrame.BUTTON_0,
	]))
	dummy.mode = RecordPlaybackSource.Mode.PLAYBACK

	var state := SimState.new_initial()
	state.players[0].character_id = TestSupport.CHAR_ID
	state.players[0].state_id = TestSupport.STATE_IDLE
	state.players[1].character_id = TestSupport.CHAR_ID
	state.players[1].state_id = TestSupport.STATE_IDLE
	host.setup(state, p1_src, dummy)

	var harness := TrainingHarness.new(host)
	harness.register_source("p2_dummy", dummy)

	# Advance a couple of ticks first (the dummy has already played back some of
	# its script), THEN capture the reset point mid-playback — the interesting
	# case: the reset point must remember the dummy's CURSOR position, not just
	# "start of script." harness.step_once() is the driver: it produces the
	# dummy's current frame (input.md produce-before-query) THEN advances the sim.
	for _k in range(2):
		harness.step_once()
	harness.capture_reset()
	var hash_at_capture: int = host.get_state().hash_state()
	var dummy_produced_at_capture: int = dummy.produced_count()

	# Rep 1: play forward past the capture, then reset.
	for _k in range(8):
		harness.step_once()
	harness.do_reset()
	_eq(host.get_state().hash_state(), hash_at_capture,
		"do_reset restores the exact sim state at capture time")
	_eq(dummy.produced_count(), dummy_produced_at_capture,
		"do_reset restores the dummy's playback cursor to the captured position")

	# Continue the rep deterministically from the reset point and record the
	# resulting hash trace.
	var trace_1: Array = []
	for _k in range(8):
		harness.step_once()
		trace_1.append(host.get_state().hash_state())

	# Rep 2: reset again and replay the SAME number of ticks — must reproduce the
	# IDENTICAL InputFrame stream from the dummy and an IDENTICAL hash trace
	# (the whole rep is bit-identical on repeat, training-mode.md criterion 12).
	harness.do_reset()
	_eq(host.get_state().hash_state(), hash_at_capture, "second do_reset also restores exactly")
	_eq(dummy.produced_count(), dummy_produced_at_capture,
		"second do_reset also restores the dummy's cursor")
	var trace_2: Array = []
	for _k in range(8):
		harness.step_once()
		trace_2.append(host.get_state().hash_state())

	_eq(trace_1.size(), trace_2.size(), "both reps ran the same number of ticks")
	for i in range(trace_1.size()):
		_eq(trace_2[i], trace_1[i],
			"rep 2 tick %d hash matches rep 1 (bit-identical repeat, dummy re-synced)" % i)

	host.free()
	MoveRegistry.clear()
