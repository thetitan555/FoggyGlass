extends SceneTree

## Headless test for the determinism/serialization harness hooks (TKT-P0-11).
## simulation.md criteria 1, 2, 3 runnable end-to-end via the hooks;
## inspection-surface.md criteria 4, 6 (truth dump is float-free, px-free).
##
## Run:  godot --headless --path game -s res://tests/test_harness.gd
##
## QA owns the harness verdicts; this only proves the HOOKS behave:
##   - dump_state/load_state round-trip preserves the canonical hash (criterion 3).
##   - run_replay is deterministic: same start + same streams -> same final hash,
##     twice (criterion 2); and matches an inline step loop (criterion 1 purity).
##   - a snapshot mid-replay, loaded and resumed, reaches the same final hash as the
##     uninterrupted replay (criterion 3, the real one).
##   - dump_inspection_truth is a plain, float-free, px-free Dictionary (criteria
##     4/6) and is stable across identical states.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	if _failures == 0:
		print("[test_harness] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_harness] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	_test_snapshot_round_trip()
	_test_replay_determinism()
	_test_snapshot_resume_matches()
	_test_truth_dump_float_free()


func _stream_p1() -> PackedInt32Array:
	var a := PackedInt32Array()
	for f in range(30):
		a.append([InputFrame.NEUTRAL, InputFrame.RIGHT, InputFrame.RIGHT | InputFrame.BUTTON_0][f % 3])
	return a


func _stream_p2() -> PackedInt32Array:
	var a := PackedInt32Array()
	for f in range(30):
		a.append([InputFrame.LEFT, InputFrame.NEUTRAL, InputFrame.BUTTON_2][f % 3])
	return a


func _test_snapshot_round_trip() -> void:
	var s := SimState.new_initial(555)
	s = SimHarness.run_replay(s, _stream_p1(), _stream_p2())
	var h: int = s.hash_state()
	var snap: Dictionary = SimHarness.dump_state(s)
	var restored: SimState = SimHarness.load_state(snap)
	_eq(restored.hash_state(), h, "dump_state -> load_state preserves canonical hash")
	# No float anywhere in the snapshot.
	_true(not _has_float(snap), "snapshot Dictionary is float-free")


func _test_replay_determinism() -> void:
	# Criterion 2: same start + same streams -> identical final hash, run twice.
	var start_seed: int = 4242
	var h1: int = SimHarness.replay_final_hash(SimState.new_initial(start_seed), _stream_p1(), _stream_p2())
	var h2: int = SimHarness.replay_final_hash(SimState.new_initial(start_seed), _stream_p1(), _stream_p2())
	_eq(h1, h2, "replay_final_hash is deterministic across two runs")

	# And matches an inline step loop (the harness adds no divergence).
	var s := SimState.new_initial(start_seed)
	var p1 := _stream_p1()
	var p2 := _stream_p2()
	for f in range(min(p1.size(), p2.size())):
		s = SimState.step(s, p1[f], p2[f])
	_eq(s.hash_state(), h1, "harness replay matches an inline step loop")


func _test_snapshot_resume_matches() -> void:
	# Criterion 3: snapshot mid-replay, load, resume -> same final hash as uninterrupted.
	var p1 := _stream_p1()
	var p2 := _stream_p2()
	var gold: int = SimHarness.replay_final_hash(SimState.new_initial(9), p1, p2)

	# Run to tick j, snapshot, load, resume.
	var j: int = 12
	var s := SimState.new_initial(9)
	for f in range(j):
		s = SimState.step(s, p1[f], p2[f])
	var snap: Dictionary = SimHarness.dump_state(s)
	s = SimHarness.load_state(snap)
	for f in range(j, min(p1.size(), p2.size())):
		s = SimState.step(s, p1[f], p2[f])
	_eq(s.hash_state(), gold, "snapshot-resume mid-replay matches uninterrupted replay")

	# Per-tick trace has the right length and its endpoints match.
	var trace: PackedInt64Array = SimHarness.replay_hash_trace(SimState.new_initial(9), p1, p2)
	_eq(trace.size(), min(p1.size(), p2.size()) + 1, "hash trace length = ticks + 1")
	_eq(trace[trace.size() - 1], gold, "hash trace final entry == final hash")


func _test_truth_dump_float_free() -> void:
	# Criteria 4/6: the inspection truth dump is plain, float-free, and px-free.
	var roster := TestSupport.build_roster()
	var s := SimState.new_initial(1)
	s.players[0].character_id = TestSupport.CHAR_ID
	s.players[1].character_id = TestSupport.CHAR_ID
	s.players[0].state_id = TestSupport.STATE_LIGHT
	s.players[0].frame_in_state = 5    # active frame -> a hitbox resolves
	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)

	var dump: Dictionary = SimHarness.dump_inspection_truth(s, roster)
	_true(not _has_float(dump), "inspection truth dump is float-free (AD-019)")
	# px is not present anywhere in the dump (render-only, criterion 6).
	_true(not _dict_has_key_substring(dump, "px"), "truth dump has no px field")
	# Stable across identical states.
	var dump2: Dictionary = SimHarness.dump_inspection_truth(s, roster)
	_eq(str(dump), str(dump2), "inspection truth dump is stable across identical states")


# --- helpers ----------------------------------------------------------------

func _has_float(v) -> bool:
	var t := typeof(v)
	if t == TYPE_FLOAT:
		return true
	if t == TYPE_PACKED_FLOAT32_ARRAY or t == TYPE_PACKED_FLOAT64_ARRAY:
		return true
	if t == TYPE_DICTIONARY:
		for k in v:
			if _has_float(k) or _has_float(v[k]):
				return true
		return false
	if t == TYPE_ARRAY:
		for e in v:
			if _has_float(e):
				return true
		return false
	return false


func _dict_has_key_substring(v, needle: String) -> bool:
	var t := typeof(v)
	if t == TYPE_DICTIONARY:
		for k in v:
			if typeof(k) == TYPE_STRING and String(k).contains(needle):
				return true
			if _dict_has_key_substring(v[k], needle):
				return true
		return false
	if t == TYPE_ARRAY:
		for e in v:
			if _dict_has_key_substring(e, needle):
				return true
		return false
	return false
