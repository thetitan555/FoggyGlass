extends SceneTree

## Headless test for FP fixed-point math (TKT-P0-01, AD-014).
##
## Run:  godot --headless --path game -s res://tests/test_fp.gd
## Exits non-zero on any failure so a harness/CI can gate on it. These are the
## fully-verifiable-NOW checks for TKT-P0-01 (the FP data path); the tick host's
## acceptance (simulation.md criterion 5) is fully checkable once TKT-P0-03 lands
## and is covered by test_tick_host.gd's placeholder + an inline reasoning note.
##
## Deliberately pure-integer assertions except where a float bake is under test:
## every value that would reach `step` at runtime is an integer here too.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	if _failures == 0:
		print("[test_fp] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_fp] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _run() -> void:
	# --- Constants / scale ---------------------------------------------------
	_eq(FP.SCALE, 65536, "SCALE is 2^16")
	_eq(FP.ONE, 65536, "ONE == SCALE")
	_eq(FP.HALF_ONE, 32768, "HALF_ONE == 0.5")
	_eq(FP.SHIFT, 16, "SHIFT is 16")

	# --- Whole-integer construction / extraction -----------------------------
	_eq(FP.from_int(1), 65536, "from_int(1) == ONE")
	_eq(FP.from_int(-3), -3 * 65536, "from_int(-3)")
	_eq(FP.to_int(FP.from_int(7)), 7, "to_int(from_int(7)) round-trips")
	_eq(FP.to_int(FP.from_int(-7)), -7, "to_int(from_int(-7)) round-trips")

	# to_int TRUNCATES toward zero (not floor): 1.9 -> 1, -1.9 -> -1.
	var one_point_nine: int = FP.ONE + 58982   # 1.0 + ~0.9
	_eq(FP.to_int(one_point_nine), 1, "to_int truncates 1.9 -> 1")
	_eq(FP.to_int(-one_point_nine), -1, "to_int truncates -1.9 -> -1 (toward zero)")

	# round_to_int: round-to-nearest, ties away from zero (the AD-014 rule).
	_eq(FP.round_to_int(FP.ONE + FP.HALF), 2, "round 1.5 -> 2 (tie away)")
	_eq(FP.round_to_int(-(FP.ONE + FP.HALF)), -2, "round -1.5 -> -2 (tie away)")
	_eq(FP.round_to_int(FP.HALF), 1, "round 0.5 -> 1 (tie away)")
	_eq(FP.round_to_int(-FP.HALF), -1, "round -0.5 -> -1 (tie away)")
	_eq(FP.round_to_int(FP.HALF - 1), 0, "round just-under-0.5 -> 0")
	_eq(FP.round_to_int(one_point_nine), 2, "round 1.9 -> 2")

	# --- add / sub / neg / abs ----------------------------------------------
	_eq(FP.add(FP.from_int(2), FP.from_int(3)), FP.from_int(5), "2+3 == 5")
	_eq(FP.sub(FP.from_int(2), FP.from_int(5)), FP.from_int(-3), "2-5 == -3")
	_eq(FP.neg(FP.from_int(4)), FP.from_int(-4), "neg(4) == -4")
	_eq(FP.abs_fp(FP.from_int(-4)), FP.from_int(4), "abs(-4) == 4")

	# --- mul -----------------------------------------------------------------
	# 2 * 3 == 6
	_eq(FP.mul(FP.from_int(2), FP.from_int(3)), FP.from_int(6), "mul 2*3 == 6")
	# 0.5 * 0.5 == 0.25
	_eq(FP.mul(FP.HALF_ONE, FP.HALF_ONE), 16384, "mul 0.5*0.5 == 0.25")
	# 1.5 * 4 == 6
	_eq(FP.mul(FP.ONE + FP.HALF, FP.from_int(4)), FP.from_int(6), "mul 1.5*4 == 6")
	# sign: -2 * 3 == -6
	_eq(FP.mul(FP.from_int(-2), FP.from_int(3)), FP.from_int(-6), "mul -2*3 == -6")
	# -0.5 * -0.5 == 0.25
	_eq(FP.mul(-FP.HALF_ONE, -FP.HALF_ONE), 16384, "mul -0.5*-0.5 == 0.25")
	# mul rounding is symmetric: a tiny value squared rounds the same either sign.
	_eq(FP.mul(3, 3), FP.mul(-3, -3), "mul rounding sign-symmetric (pos*pos == neg*neg)")

	# --- div -----------------------------------------------------------------
	# 6 / 3 == 2
	_eq(FP.div(FP.from_int(6), FP.from_int(3)), FP.from_int(2), "div 6/3 == 2")
	# 1 / 2 == 0.5
	_eq(FP.div(FP.ONE, FP.from_int(2)), FP.HALF_ONE, "div 1/2 == 0.5")
	# 1 / 4 == 0.25
	_eq(FP.div(FP.ONE, FP.from_int(4)), 16384, "div 1/4 == 0.25")
	# sign: -6 / 3 == -2
	_eq(FP.div(FP.from_int(-6), FP.from_int(3)), FP.from_int(-2), "div -6/3 == -2")
	# -6 / -3 == 2
	_eq(FP.div(FP.from_int(-6), FP.from_int(-3)), FP.from_int(2), "div -6/-3 == 2")
	# div rounds to nearest, ties away: 1/3 in fixed-point == 21845.33.. -> 21845
	_eq(FP.div(FP.ONE, FP.from_int(3)), 21845, "div 1/3 rounds to nearest (21845)")

	# mul/div inverse within rounding: (a * b) / b ~= a for exact-ish values.
	var a: int = FP.from_int(7)
	var b: int = FP.from_int(3)
	_eq(FP.div(FP.mul(a, b), b), a, "div(mul(7,3),3) round-trips to 7")

	# --- comparison / clamp / sign ------------------------------------------
	_eq(FP.min_fp(FP.from_int(2), FP.from_int(5)), FP.from_int(2), "min(2,5)==2")
	_eq(FP.max_fp(FP.from_int(2), FP.from_int(5)), FP.from_int(5), "max(2,5)==5")
	_eq(FP.clamp_fp(FP.from_int(9), FP.from_int(0), FP.from_int(5)), FP.from_int(5), "clamp 9 into [0,5]==5")
	_eq(FP.clamp_fp(FP.from_int(-2), FP.from_int(0), FP.from_int(5)), FP.from_int(0), "clamp -2 into [0,5]==0")
	_eq(FP.sign_fp(FP.from_int(3)), 1, "sign(3)==1")
	_eq(FP.sign_fp(FP.from_int(-3)), -1, "sign(-3)==-1")
	_eq(FP.sign_fp(0), 0, "sign(0)==0")

	# --- authoring bakes (float -> fixed), off-hot-path only -----------------
	# from_float/from_units are the ONLY float entry points; verify the bake
	# matches the documented rounding and produces the SAME integers step sees.
	_eq(FP.from_float(1.0), FP.ONE, "from_float(1.0) == ONE")
	_eq(FP.from_float(0.5), FP.HALF_ONE, "from_float(0.5) == 0.5")
	_eq(FP.from_float(-0.5), -FP.HALF_ONE, "from_float(-0.5) == -0.5")
	_eq(FP.from_units(2.5), FP.from_int(2) + FP.HALF_ONE, "from_units(2.5) == 2.5")
	# Determinism of the bake: same input -> same integer, every call.
	_eq(FP.from_float(3.14159), FP.from_float(3.14159), "from_float deterministic")
