extends SceneTree

## Headless test for the SimState top-level format-version field (TKT-P1.1-03,
## AD-034). simulation.md -> Serialization; Tenet 1.
##
## Run:  godot --headless --path game -s res://tests/test_serialization_version.gd
## Exits non-zero on any failure so a harness/CI can gate on it.
##
## Acceptance covered here (p1.1-finish-instrument.md -> TKT-P1.1-03):
##   - to_dict/from_dict round-trip stays exact: "v" survives the trip and
##     reads back as SimState.FORMAT_VERSION.
##   - hash_state() is unchanged by the field's presence/absence: two dicts
##     differing ONLY in whether/what "v" they carry (absent vs. current)
##     restore to states with an IDENTICAL hash, proving hash_state() never
##     reads "v" at all (AD-034's "not hashed" exclusion).
##   - a dict without "v" still restores (absent => 1, legacy = current shape).
##   - a dict with an unrecognized "v" (e.g. 2) hits the fail-fast guard
##     (from_dict returns null rather than silently mis-parsing).

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	if _failures == 0:
		print("[test_serialization_version] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_serialization_version] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	_test_v_emitted_at_top_level_only()
	_test_round_trip_preserves_v()
	_test_absent_v_restores_as_legacy_v1()
	_test_hash_unaffected_by_v_presence()
	_test_unrecognized_v_fails_loudly()


## Build a non-trivial state (a few ticks advanced) so round-trip/hash checks
## are not vacuous.
func _sample_state() -> SimState:
	var s := SimState.new_initial(555)
	for f in range(5):
		var a: int = [InputFrame.NEUTRAL, InputFrame.RIGHT, InputFrame.RIGHT | InputFrame.BUTTON_0][f % 3]
		var b: int = [InputFrame.LEFT, InputFrame.NEUTRAL, InputFrame.BUTTON_2][f % 3]
		s = SimState.step(s, a, b)
	return s


func _test_v_emitted_at_top_level_only() -> void:
	var s := _sample_state()
	var d: Dictionary = s.to_dict()
	_true(d.has("v"), "top-level to_dict() carries a \"v\" key")
	_eq(d["v"], SimState.FORMAT_VERSION, "\"v\" equals SimState.FORMAT_VERSION")
	_eq(SimState.FORMAT_VERSION, 1, "FORMAT_VERSION is 1 (the only version that exists yet)")

	# No sub-object dict gains its own version (AD-034: one version governs the
	# whole graph).
	_true(not (d["rng"] as Dictionary).has("v"), "rng sub-dict carries no \"v\"")
	_true(not (d["stage"] as Dictionary).has("v"), "stage sub-dict carries no \"v\"")
	for pd in (d["players"] as Array):
		_true(not (pd as Dictionary).has("v"), "player sub-dict carries no \"v\"")


func _test_round_trip_preserves_v() -> void:
	var s := _sample_state()
	var d: Dictionary = s.to_dict()
	var restored: SimState = SimState.from_dict(d)
	_true(restored != null, "from_dict on a current-version dict returns a state, not null")
	var d2: Dictionary = restored.to_dict()
	_eq(d2["v"], SimState.FORMAT_VERSION, "\"v\" survives a full round-trip")
	_eq(restored.hash_state(), s.hash_state(), "round-trip through a versioned dict reproduces an identical hash")


func _test_absent_v_restores_as_legacy_v1() -> void:
	var s := _sample_state()
	var d: Dictionary = s.to_dict()
	var d_legacy: Dictionary = d.duplicate(true)
	d_legacy.erase("v")
	_true(not d_legacy.has("v"), "sanity: legacy dict has no \"v\" key")

	var restored: SimState = SimState.from_dict(d_legacy)
	_true(restored != null, "from_dict restores a dict with no \"v\" (absent => 1)")
	_eq(restored.hash_state(), s.hash_state(),
		"a legacy (no \"v\") dict restores to the same state as the current one")


func _test_hash_unaffected_by_v_presence() -> void:
	# Two dicts differing ONLY in their "v" (one absent, one == FORMAT_VERSION)
	# must restore to states with an IDENTICAL hash -- proving hash_state()
	# never reads "v" (AD-034's exclusion; same class as AD-019/AD-024).
	var s := _sample_state()
	var d_with_v: Dictionary = s.to_dict()
	var d_without_v: Dictionary = d_with_v.duplicate(true)
	d_without_v.erase("v")

	var restored_with: SimState = SimState.from_dict(d_with_v)
	var restored_without: SimState = SimState.from_dict(d_without_v)
	_eq(restored_with.hash_state(), restored_without.hash_state(),
		"hash_state() is identical whether the source dict carried \"v\" or not")


func _test_unrecognized_v_fails_loudly() -> void:
	var s := _sample_state()
	var d_bad: Dictionary = s.to_dict()
	d_bad["v"] = 2   # a version this code does not understand
	var result: SimState = SimState.from_dict(d_bad)
	_eq(result, null,
		"from_dict on an unrecognized \"v\" fails loudly (returns null) rather than mis-parsing")
