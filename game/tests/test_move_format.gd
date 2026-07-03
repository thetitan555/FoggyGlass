extends SceneTree

## Headless test for the move format + derivation (TKT-P0-05). move-format.md
## criteria 1, 2, 3, 6, 9 (5/7/8 land with 07-09; 4 fully checkable at character A).
##
## Run:  godot --headless --path game -s res://tests/test_move_format.gd
##
## Covered:
##   1 Data-only authoring — a move resolves to the correct active box set per frame.
##   2 Derivation correctness — startup/active/recovery match hand-specified values.
##   3 Golden-able — resolved data is deterministic (two resolutions match); box
##                   geometry is stable across identical inputs.
##   6 One pattern — every state declares a valid engine-level category.
##   9 Fixed-point data — all resolved geometry values are ints (no float).
## Plus facing flip (box mirrors about origin) and single-hit id_group grouping.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	if _failures == 0:
		print("[test_move_format] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_move_format] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	_test_frame_data_derivation()
	_test_per_frame_box_resolution()
	_test_facing_flip()
	_test_single_hit_grouping()
	_test_categories_valid()
	_test_no_floats_in_resolved()


func _light() -> MoveState:
	return TestSupport.build_test_character().get_state(TestSupport.STATE_LIGHT)


func _test_frame_data_derivation() -> void:
	# Criterion 2: startup/active/recovery/total match hand-computed values.
	var fd: FrameData = MoveData.frame_data(_light())
	_eq(fd.startup, TestSupport.LIGHT_STARTUP, "light startup = 3 (first active frame 4)")
	_eq(fd.active, TestSupport.LIGHT_ACTIVE, "light active = 3 (frames 4..6)")
	_eq(fd.recovery, TestSupport.LIGHT_RECOVERY, "light recovery = 6 (frame 6 -> 12)")
	_eq(fd.total, TestSupport.LIGHT_DURATION, "light total = 12 (duration)")

	# A non-attacking state (idle) has zero startup/active/recovery, total = duration.
	var idle: MoveState = TestSupport.build_test_character().get_state(TestSupport.STATE_IDLE)
	var ifd: FrameData = MoveData.frame_data(idle)
	_eq(ifd.startup, 0, "idle startup 0")
	_eq(ifd.active, 0, "idle active 0")
	_eq(ifd.recovery, 0, "idle recovery 0")
	_eq(ifd.total, 1, "idle total = duration 1")


func _test_per_frame_box_resolution() -> void:
	# Criterion 1: the active box set is correct on each frame of the range.
	var light := _light()
	# Facing +1, at origin. Frame 2 (startup): hurt only, no hit.
	var f2: Array = MoveData.resolve_boxes(light, 2, 1, 0, 0)
	_eq(_count_kind(f2, BoxView.KIND_HIT), 0, "frame 2 (startup) has no hitbox")
	_true(_count_kind(f2, BoxView.KIND_HURT) >= 1, "frame 2 has a hurtbox")

	# Frame 5 (active): hurt + two hitboxes.
	var f5: Array = MoveData.resolve_boxes(light, 5, 1, 0, 0)
	_eq(_count_kind(f5, BoxView.KIND_HIT), 2, "frame 5 (active) has two hitboxes")
	_true(_count_kind(f5, BoxView.KIND_HURT) >= 1, "frame 5 has a hurtbox")

	# Frame 9 (recovery): hurt only.
	var f9: Array = MoveData.resolve_boxes(light, 9, 1, 0, 0)
	_eq(_count_kind(f9, BoxView.KIND_HIT), 0, "frame 9 (recovery) has no hitbox")

	# Criterion 3: resolving the same frame twice yields identical geometry.
	var a: Array = MoveData.resolve_boxes(light, 5, 1, FP.from_int(100), FP.from_int(0))
	var b: Array = MoveData.resolve_boxes(light, 5, 1, FP.from_int(100), FP.from_int(0))
	_true(_boxes_equal(a, b), "identical inputs resolve to identical boxes (deterministic)")


func _test_facing_flip() -> void:
	# A hitbox at local x=30,w=30 (occupies local [30,60)). Facing +1 at pos 0:
	# world x = 30. Facing -1 at pos 0: mirror -> world x = -(30+30) = -60.
	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(30), FP.from_int(0), FP.from_int(30), FP.from_int(20))
	var right: ResolvedBox = MoveData.resolve_hit_box(hb, 1, 0, 0)
	_eq(right.x, FP.from_int(30), "facing +1: hitbox world x = local x")
	var left: ResolvedBox = MoveData.resolve_hit_box(hb, -1, 0, 0)
	_eq(left.x, FP.from_int(-60), "facing -1: hitbox mirrors about origin (world x = -60)")
	# Width is unchanged by the flip.
	_eq(left.w, FP.from_int(30), "facing flip preserves width")
	# Offsetting by position shifts both.
	var right_offset: ResolvedBox = MoveData.resolve_hit_box(hb, 1, FP.from_int(100), 0)
	_eq(right_offset.x, FP.from_int(130), "position offset adds to world x")


func _test_single_hit_grouping() -> void:
	# Criterion 5 (foundation): the two active hitboxes share one id_group, so the
	# hit-resolution single-hit rule (07) counts them once. Here we assert the DATA
	# supports it: both active hitboxes carry the same id_group.
	var f5: Array = MoveData.resolve_boxes(_light(), 5, 1, 0, 0)
	var groups := {}
	for rb in f5:
		if rb.kind == BoxView.KIND_HIT:
			groups[rb.hit.id_group] = true
	_eq(groups.size(), 1, "both active hitboxes share a single id_group")
	_true(groups.has(TestSupport.LIGHT_ID_GROUP), "the shared id_group is the authored one")


func _test_categories_valid() -> void:
	# Criterion 6: every state declares a valid engine-level category.
	var c := TestSupport.build_test_character()
	for s in c.states:
		_true(s.has_valid_category(), "state %d declares a valid category" % s.id)


func _test_no_floats_in_resolved() -> void:
	# Criterion 9: resolved geometry is pure integer (baked fixed-point).
	var f5: Array = MoveData.resolve_boxes(_light(), 5, -1, FP.from_int(50), FP.from_int(10))
	for rb in f5:
		_true(typeof(rb.x) == TYPE_INT, "resolved box x is int")
		_true(typeof(rb.y) == TYPE_INT, "resolved box y is int")
		_true(typeof(rb.w) == TYPE_INT, "resolved box w is int")
		_true(typeof(rb.h) == TYPE_INT, "resolved box h is int")


# --- helpers ----------------------------------------------------------------

func _count_kind(boxes: Array, kind: int) -> int:
	var n := 0
	for rb in boxes:
		if rb.kind == kind:
			n += 1
	return n


func _boxes_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i].x != b[i].x or a[i].y != b[i].y or a[i].w != b[i].w or a[i].h != b[i].h \
				or a[i].kind != b[i].kind:
			return false
	return true
