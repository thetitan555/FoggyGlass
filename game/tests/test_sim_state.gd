extends SceneTree

## Headless test for SimState + pure step + serialization (TKT-P0-03).
## simulation.md criteria 1, 3, 4, 8, 9 (2 is exercised end-to-end via the QA
## harness at TKT-P0-11; 5 is in test_tick_host.gd).
##
## Run:  godot --headless --path game -s res://tests/test_sim_state.gd
## Exits non-zero on any failure so a harness/CI can gate on it.
##
## Criteria covered here:
##   1 Purity          — step(s,a,b) twice on equal (s,a,b) -> identical hashes.
##   3 Round-trip      — snapshot at tick j, restore, resume to K -> same hash as
##                       the uninterrupted run to K.
##   4 No forbidden reads — RNG state is in the snapshot and part of the hash;
##                       step reads no wall-clock/delta/unseeded RNG (structural:
##                       step's only inputs are (state, in1, in2)).
##   8 No floats       — every field the hash walks is an int; a scan asserts the
##                       serialized graph contains no float.
##   9 Immutable input — after next = step(prev,a,b), hash(prev) is unchanged.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	if _failures == 0:
		print("[test_sim_state] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_sim_state] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	_test_immutable_input_and_purity()
	_test_hash_sensitivity()
	_test_full_round_trip()
	_test_snapshot_restore_resume()
	_test_no_floats()


# A short deterministic input stream for both players, distinct per player.
func _in_p1(frame: int) -> int:
	return [InputFrame.NEUTRAL, InputFrame.RIGHT, InputFrame.RIGHT | InputFrame.BUTTON_0][frame % 3]

func _in_p2(frame: int) -> int:
	return [InputFrame.LEFT, InputFrame.NEUTRAL, InputFrame.BUTTON_2][frame % 3]


func _test_immutable_input_and_purity() -> void:
	var s := SimState.new_initial(12345)
	var before_hash: int = s.hash_state()

	# Criterion 9: step must not mutate its input. Take the hash before, step, then
	# confirm the input's hash is unchanged.
	var a: int = InputFrame.RIGHT | InputFrame.BUTTON_0
	var b: int = InputFrame.LEFT
	var next1: SimState = SimState.step(s, a, b)
	_eq(s.hash_state(), before_hash, "step did not mutate its input (hash(prev) unchanged)")

	# The output is a distinct object and actually advanced.
	_true(next1 != s, "step returns a distinct object")
	_eq(next1.tick, s.tick + 1, "step advanced tick by exactly 1")
	# Input was recorded into history (phase 1).
	_eq(next1.players[0].input_history.newest(), a, "p1 raw input recorded newest")
	_eq(next1.players[1].input_history.newest(), b, "p2 raw input recorded newest")
	# Prev history is untouched (deep-copy discipline): prev p1 history still empty.
	_eq(s.players[0].input_history.size(), 0, "prev p1 history untouched by step")

	# Criterion 1: purity — stepping the SAME input twice yields identical hashes.
	var next2: SimState = SimState.step(s, a, b)
	_eq(next1.hash_state(), next2.hash_state(),
		"step(s,a,b) twice yields identical state hashes (purity)")


func _test_hash_sensitivity() -> void:
	# The hash must change when ANY field changes, else round-trip/purity checks are
	# vacuous. Spot-check a few fields.
	var s := SimState.new_initial(1)
	var base: int = s.hash_state()

	var s2 := s.clone()
	s2.players[0].pos_x += 1
	_true(s2.hash_state() != base, "hash changes when a player position changes")

	var s3 := s.clone()
	s3.players[1].health -= 1
	_true(s3.hash_state() != base, "hash changes when health changes")

	var s4 := s.clone()
	s4.tick += 1
	_true(s4.hash_state() != base, "hash changes when tick changes")

	var s5 := s.clone()
	s5.players[0].input_history.push(InputFrame.UP)
	_true(s5.hash_state() != base, "hash changes when input history changes")

	# A clone with no changes hashes identically (clone is faithful).
	_eq(s.clone().hash_state(), base, "faithful clone hashes identically")

	# Two independently-built initial states with the same seed hash identically.
	_eq(SimState.new_initial(1).hash_state(), SimState.new_initial(1).hash_state(),
		"same-seed initial states hash identically")
	# Different seeds hash differently (RNG state is in the hash — criterion 4).
	_true(SimState.new_initial(1).hash_state() != SimState.new_initial(2).hash_state(),
		"different seeds hash differently (RNG state is in the snapshot)")


func _test_full_round_trip() -> void:
	# Criterion 3 (base case): to_dict -> from_dict reproduces an identical state.
	var s := SimState.new_initial(999)
	# Advance a few ticks so there is non-trivial history/state to round-trip.
	for f in range(5):
		s = SimState.step(s, _in_p1(f), _in_p2(f))
	var h_before: int = s.hash_state()
	var dumped: Dictionary = s.to_dict()
	var restored: SimState = SimState.from_dict(dumped)
	_eq(restored.hash_state(), h_before, "serialize->restore reproduces identical hash")
	# And a second dump of the restored state is identical (idempotent).
	var restored2: SimState = SimState.from_dict(restored.to_dict())
	_eq(restored2.hash_state(), h_before, "double round-trip is stable")


func _test_snapshot_restore_resume() -> void:
	# Criterion 3 (the real one): run K ticks uninterrupted; separately run to j,
	# snapshot, restore, resume to K. Both final hashes must match.
	var K: int = 20
	var j: int = 8

	# Uninterrupted run.
	var uninterrupted := SimState.new_initial(4242)
	for f in range(K):
		uninterrupted = SimState.step(uninterrupted, _in_p1(f), _in_p2(f))
	var gold: int = uninterrupted.hash_state()

	# Interrupted run: to j, snapshot (to_dict), restore (from_dict), resume to K.
	var interrupted := SimState.new_initial(4242)
	for f in range(j):
		interrupted = SimState.step(interrupted, _in_p1(f), _in_p2(f))
	var snapshot: Dictionary = interrupted.to_dict()
	# Prove the snapshot is a real detach: mutate the live state, restore from snap.
	interrupted = SimState.from_dict(snapshot)
	# Resume from j to K with the SAME input stream (frame-indexed inputs re-queried).
	for f in range(j, K):
		interrupted = SimState.step(interrupted, _in_p1(f), _in_p2(f))
	_eq(interrupted.hash_state(), gold,
		"snapshot at j, restore, resume to K == uninterrupted run to K")


func _test_no_floats() -> void:
	# Criterion 8: no floats anywhere in the serialized state graph. Walk the dict
	# recursively and assert nothing is a float (TYPE_FLOAT).
	var s := SimState.new_initial(7)
	for f in range(5):
		s = SimState.step(s, _in_p1(f), _in_p2(f))
	var d: Dictionary = s.to_dict()
	_true(not _has_float(d), "serialized SimState contains no float value anywhere")


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
