extends SceneTree

## Headless test for the AABB strict-overlap boundary (F-008; AD-027). Pins the
## touching-edge = NO-hit convention at exact adjacency so a future accidental flip
## of ResolvedBox.overlaps from strict `<`/`>` to `<=`/`>=` is caught. AD-027 makes
## adjacency the load-bearing hit/no-hit decision, so this boundary needs a golden.
##
## Run:  godot --headless --path game -s res://tests/test_overlap_boundary.gd
## Exits non-zero on any failure so a harness/CI can gate on it.
##
## The two pinned cases (AD-027):
##   - Two boxes at `a.x + a.w == b.x` (exact shared edge) do NOT overlap.
##   - A 1-subunit penetration (b shifted left by 1) DOES overlap.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	if _failures == 0:
		print("[test_overlap_boundary] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_overlap_boundary] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _false(cond: bool, msg: String) -> void:
	_eq(cond, false, msg)


func _run() -> void:
	_test_x_edge_boundary()
	_test_y_edge_boundary()
	_test_corner_touch()
	_test_penetration_all_axes()


## Build a ResolvedBox with the given AABB (fixed-point units). Kind/hit are
## irrelevant to overlaps(); use HURT and null.
func _box(x: int, y: int, w: int, h: int) -> ResolvedBox:
	return ResolvedBox.make(BoxView.KIND_HURT, x, y, w, h)


func _test_x_edge_boundary() -> void:
	# a spans x in [0, 100); b starts exactly at a's right edge (x == a.x + a.w).
	# They share the vertical edge and MUST NOT overlap (AD-027, strict).
	var w: int = FP.from_int(100)
	var h: int = FP.from_int(100)
	var a: ResolvedBox = _box(FP.from_int(0), FP.from_int(0), w, h)
	var b_touch: ResolvedBox = _box(FP.from_int(100), FP.from_int(0), w, h)  # a.x + a.w == b.x
	_false(a.overlaps(b_touch), "x-edge exact touch (a.x+a.w == b.x) does NOT overlap")
	_false(b_touch.overlaps(a), "x-edge exact touch is symmetric (b vs a) — no overlap")

	# Shift b LEFT by exactly 1 subunit: now b.x = a.x + a.w - 1, a 1-subunit
	# penetration. This MUST overlap (the strict `<`/`>` becomes true by exactly 1).
	var b_pen: ResolvedBox = _box(FP.from_int(100) - 1, FP.from_int(0), w, h)
	_true(a.overlaps(b_pen), "1-subunit x penetration DOES overlap")
	_true(b_pen.overlaps(a), "1-subunit x penetration is symmetric (b vs a) — overlaps")


func _test_y_edge_boundary() -> void:
	# Same boundary on the vertical axis: b stacked exactly atop a (b.y == a.y + a.h).
	var w: int = FP.from_int(100)
	var h: int = FP.from_int(100)
	var a: ResolvedBox = _box(FP.from_int(0), FP.from_int(0), w, h)
	var b_touch: ResolvedBox = _box(FP.from_int(0), FP.from_int(100), w, h)  # a.y + a.h == b.y
	_false(a.overlaps(b_touch), "y-edge exact touch (a.y+a.h == b.y) does NOT overlap")

	var b_pen: ResolvedBox = _box(FP.from_int(0), FP.from_int(100) - 1, w, h)
	_true(a.overlaps(b_pen), "1-subunit y penetration DOES overlap")


func _test_corner_touch() -> void:
	# Diagonal corner-to-corner contact: b's bottom-left corner exactly at a's
	# top-right corner. Both axes touch, neither penetrates -> no overlap.
	var w: int = FP.from_int(50)
	var h: int = FP.from_int(50)
	var a: ResolvedBox = _box(FP.from_int(0), FP.from_int(0), w, h)
	var b_corner: ResolvedBox = _box(FP.from_int(50), FP.from_int(50), w, h)
	_false(a.overlaps(b_corner), "corner-to-corner exact touch does NOT overlap")

	# Push the corner box 1 subunit into a on BOTH axes -> overlaps.
	var b_pen: ResolvedBox = _box(FP.from_int(50) - 1, FP.from_int(50) - 1, w, h)
	_true(a.overlaps(b_pen), "1-subunit corner penetration on both axes DOES overlap")


func _test_penetration_all_axes() -> void:
	# A fully-contained box overlaps; a box separated by 1 subunit (a real gap) does
	# not. These bracket the boundary from the far side so the strict test isn't
	# vacuously passing.
	var a: ResolvedBox = _box(FP.from_int(0), FP.from_int(0), FP.from_int(100), FP.from_int(100))
	var inside: ResolvedBox = _box(FP.from_int(10), FP.from_int(10), FP.from_int(10), FP.from_int(10))
	_true(a.overlaps(inside), "a fully-contained box overlaps")

	# Gap of exactly 1 subunit on x: b.x = a.x + a.w + 1. No overlap (there is space).
	var gap: ResolvedBox = _box(FP.from_int(100) + 1, FP.from_int(0), FP.from_int(50), FP.from_int(100))
	_false(a.overlaps(gap), "a 1-subunit GAP on x does not overlap")
