class_name FP
extends RefCounted

## Fixed-point scalar math for the deterministic sim (AD-014, technical-tenets §1).
##
## One scalar type: a 64-bit signed integer (GDScript `int`) interpreted as a
## fixed-point value with fractional scale 2^16. So 1 game unit == 65536
## sub-units. All sim positions, velocities, and geometry are values of this
## kind (AD-005); floats appear only in the view (fixed -> float for rendering).
##
## This helper owns the fixed-point ops so the convention lives in exactly one
## place. It is pure integer math: no floats reach any function here except the
## explicit authoring-time bakes (`from_float`, `from_units`), which are for the
## off-hot-path float->fixed bake only (AD-014) and must NEVER be called inside
## `step`.
##
## No transcendentals (AD-014): no trig, sqrt, normalize, pow, log. The slice's
## movement and box overlap are integer add / compare only, so none are needed.
## This class deliberately provides none.
##
## All functions are static — `FP` carries no state and is never instantiated.

## Fractional bits. Scale = 2^SHIFT. Power-of-two so mul/div are shifts.
const SHIFT: int = 16
const SCALE: int = 1 << SHIFT          # 65536
const HALF: int = 1 << (SHIFT - 1)     # 32768, for round-to-nearest

# ----------------------------------------------------------------------------
# Named constants (baked once, here — not recomputed on the hot path).
# ----------------------------------------------------------------------------

const ZERO: int = 0
const ONE: int = SCALE                 # 1.0
const NEG_ONE: int = -SCALE            # -1.0
const HALF_ONE: int = SCALE >> 1       # 0.5

# ----------------------------------------------------------------------------
# Whole-integer construction / extraction.
# ----------------------------------------------------------------------------

## Wrap a whole integer (game units) as fixed-point. Pure integer, hot-path safe.
static func from_int(n: int) -> int:
	return n << SHIFT

## Truncate toward zero to a whole integer (drops the fraction). Hot-path safe.
static func to_int(a: int) -> int:
	# Arithmetic shift on a signed int floors toward negative infinity, which is
	# NOT truncation for negatives. Do explicit truncation toward zero so the
	# rounding behaviour is single-sourced and documented (round-to-nearest ties
	# away from zero is applied by `round_to_int`; this one truncates).
	if a >= 0:
		return a >> SHIFT
	return -((-a) >> SHIFT)

## Round to the nearest whole integer, ties away from zero (the AD-014 rule).
static func round_to_int(a: int) -> int:
	if a >= 0:
		return (a + HALF) >> SHIFT
	return -(((-a) + HALF) >> SHIFT)

# ----------------------------------------------------------------------------
# Authoring-time bakes (float -> fixed). OFF the hot path only (AD-014).
# Never call these inside `step`; move/physics data is baked to integers once,
# at author/load time, and only integers reach the runtime.
# ----------------------------------------------------------------------------

## Bake a float value (in game units) to fixed-point, round-to-nearest ties away
## from zero. Authoring/load only — never inside `step` (AD-014).
static func from_float(v: float) -> int:
	if v >= 0.0:
		return int(v * float(SCALE) + 0.5)
	return -int(-v * float(SCALE) + 0.5)

## Alias for `from_float`, named for the authoring call site (friendly units in,
## baked fixed-point out). Authoring/load only.
static func from_units(v: float) -> int:
	return from_float(v)

## Fixed-point -> float, for the VIEW only (rendering). Not sim math; a view may
## call this to project to pixels. Never feed the result back into `step`.
static func to_float(a: int) -> float:
	return float(a) / float(SCALE)

# ----------------------------------------------------------------------------
# Core arithmetic. add/sub are plain integer ops (same scale); provided as
# named helpers for call-site clarity and to keep all FP ops in one vocabulary.
# ----------------------------------------------------------------------------

static func add(a: int, b: int) -> int:
	return a + b

static func sub(a: int, b: int) -> int:
	return a - b

static func neg(a: int) -> int:
	return -a

static func abs_fp(a: int) -> int:
	return a if a >= 0 else -a

## Multiply two fixed-point values: (a * b) >> SHIFT, round-to-nearest ties away
## from zero. Result stays fixed-point.
##
## OVERFLOW NOTE: the intermediate product a*b is computed at 64 bits before the
## shift, so both operands together must fit ~64 bits of significance. For the
## slice's magnitudes (positions/velocities within a stage; box dims), this is
## far inside range. Guarding/widening beyond 64-bit is out of TKT-P0-01 scope
## and would need an Architect contract if the sim ever approaches the limit —
## see the judgment-call log entry for this ticket.
static func mul(a: int, b: int) -> int:
	var prod: int = a * b
	# Round-to-nearest, ties away from zero, on the >> SHIFT.
	if prod >= 0:
		return (prod + HALF) >> SHIFT
	return -(((-prod) + HALF) >> SHIFT)

## Divide two fixed-point values: (a << SHIFT) / b, round-to-nearest ties away
## from zero. Result stays fixed-point. Caller must not divide by zero (asserts
## in debug; behaviour otherwise is a hard error, by design — the slice has no
## divide-by-zero gameplay path).
static func div(a: int, b: int) -> int:
	assert(b != 0, "FP.div: divide by zero")
	# Scale the numerator up, then divide. Do rounding on the quotient by adding
	# half the divisor's magnitude before the integer division, sign-corrected.
	var num: int = a << SHIFT
	var neg_result: bool = (a < 0) != (b < 0)
	var n: int = num if num >= 0 else -num
	var d: int = b if b >= 0 else -b
	var q: int = (n + (d >> 1)) / d
	return -q if neg_result else q

# ----------------------------------------------------------------------------
# Comparison / clamp helpers (pure integer; provided for call-site clarity).
# ----------------------------------------------------------------------------

static func min_fp(a: int, b: int) -> int:
	return a if a < b else b

static func max_fp(a: int, b: int) -> int:
	return a if a > b else b

static func clamp_fp(a: int, lo: int, hi: int) -> int:
	if a < lo:
		return lo
	if a > hi:
		return hi
	return a

## Sign: -1, 0, or +1 (as plain ints, not fixed-point).
static func sign_fp(a: int) -> int:
	if a > 0:
		return 1
	if a < 0:
		return -1
	return 0
