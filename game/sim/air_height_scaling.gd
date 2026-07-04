class_name AirHeightScaling
extends RefCounted

## The ONE air-normal height-dependent hitstun definition (combat-resolution.md
## "Air-normal height-dependent advantage"; AD-033). All static — no state.
## Mirrors `DamageScaling`'s single-definition packaging (JC-016 precedent):
## the mechanism (depth -> signed hitstun delta, applied pre-stun, clamped,
## surfaced) is the contract; the four numbers below are slice-provisional
## placeholder tuning (feel is the Strategist's via the spec).
##
## depth = ground_y - attacker.pos_y (fixed-point; screen convention up = -y, so
## an airborne attacker has pos_y < ground_y, depth > 0; depth == 0 at the floor).
## `hitstun_delta(depth)` returns a signed WHOLE-FRAME delta (plain int, not
## fixed-point) added to a hit's authored base hitstun:
##   depth <= 0             -> +DEEP_BONUS   (deepest: at/below ground)
##   depth >= HIGH_REF_DEPTH -> -HIGH_PENALTY (~the jump apex or higher)
##   between                -> linearly interpolated
##
## Applied hitstun = max(base_hitstun + delta, MIN_HITSTUN) — a floor so a high
## hit still leaves the defender in real (if brief) hitstun, never zero/negative.
## No upper clamp is needed: delta <= +DEEP_BONUS by construction (linear
## interpolation between the two clamped endpoints never exceeds them).
##
## Integer/fixed-point only (AD-014): `depth` and `HIGH_REF_DEPTH` are
## fixed-point; the interpolation is integer FP math; the returned delta is a
## whole frame count (plain int). No floats reach the runtime.

## Signed hitstun delta at the DEEPEST contact (depth <= 0): the maximum bonus.
## Slice-provisional (feel is the Strategist's, like DamageScaling's step/floor).
const DEEP_BONUS: int = 6

## Signed hitstun PENALTY at or above the reference height (depth >= HIGH_REF_DEPTH):
## the maximum malus, subtracted (so the delta there is -HIGH_PENALTY).
const HIGH_PENALTY: int = 8

## Reference depth (fixed-point units) at/above which the penalty is fully applied
## — "~the jump apex." Character A's jump arc rises ~132 units (22 frames * 6
## units/frame, game/content/character_a.gd's jump-arc constants) before falling;
## this reference is set a bit below the full apex so a jump-in connecting anywhere
## near the top of the arc reads as "high" without requiring the exact peak frame.
const HIGH_REF_DEPTH: int = 6881280   # FP.from_int(105), baked (105 << 16)

## Floor: applied hitstun never drops below this many frames, however high the
## contact (so a high air hit is still a real, if brief, hit — never 0/negative).
const MIN_HITSTUN: int = 4


## The signed hitstun delta for a contact at fixed-point `depth` (attacker's
## ground_y - pos_y at the moment of connect). A pure function of depth alone
## (independent of the base hitstun) — so `air_height_hitstun_delta` on the hit
## record is exactly height's own contribution, nothing else folded in.
static func hitstun_delta(depth: int) -> int:
	if depth <= 0:
		return DEEP_BONUS
	if depth >= HIGH_REF_DEPTH:
		return -HIGH_PENALTY
	# Linear interpolation between (0, +DEEP_BONUS) and (HIGH_REF_DEPTH, -HIGH_PENALTY).
	# total_span is the full signed swing (DEEP_BONUS - (-HIGH_PENALTY)); integer FP
	# math only (AD-014) -- depth/HIGH_REF_DEPTH are fixed-point, the intermediate
	# product/division is fixed-point, and the final result is rounded to a whole
	# frame count (round-to-nearest, ties away from zero, per FP's one rounding rule).
	var total_span: int = DEEP_BONUS + HIGH_PENALTY
	var depth_fp: int = depth   # already fixed-point
	var frac: int = FP.div(depth_fp, HIGH_REF_DEPTH)   # 0.0 (deep) .. 1.0 (at/above ref), FP-scaled
	var drop_fp: int = FP.mul(FP.from_int(total_span), frac)   # how far below DEEP_BONUS, FP-scaled
	var drop: int = FP.round_to_int(drop_fp)
	return DEEP_BONUS - drop
