class_name DamageScaling
extends RefCounted

## The ONE damage-scaling definition (combat-resolution.md "Combo & damage
## accounting": "Damage scaling applies from a single scaling definition ... before
## damage is subtracted — deterministic and surfaced"). All static — no state.
## Single-sourced so every hit scales the same way (no per-move/per-character variant,
## the consistency guard).
##
## SCALING BY HIT COUNT. Returns a fixed-point multiplier (FP scale; FP.ONE == 100%)
## for a given combo hit count. The FIRST hit of a combo is unscaled (100%); each
## subsequent hit scales down by a fixed step, floored at a minimum. Integer/fixed-
## point only (AD-014) — no floats reach the runtime.
##
## VALUES ARE SLICE-PROVISIONAL. The step and floor are placeholder tuning (feel
## belongs to the Strategist via the Architect's spec); combat-resolution.md fixes the
## MECHANISM (a single scaling definition applied before subtraction), not the numbers.
## The done-bar's single hit is unscaled (100%), so its damage is exactly the base — a
## hand-checkable value independent of the step/floor chosen here.

## Fixed-point scaling table by combo hit count (1-indexed). Index 1 = first hit.
## Expressed as whole-percent points baked to fixed-point once (off the hot path is
## not required here — these are constants, computed at class load, never per tick).
const _FIRST_HIT_PCT: int = 100
const _STEP_PCT: int = 10       # each hit after the first scales 10% lower
const _FLOOR_PCT: int = 10      # never scale below 10%


## The fixed-point damage multiplier for the given combo hit count (>= 1). Hit 1 is
## 100% (FP.ONE); each further hit subtracts _STEP_PCT, floored at _FLOOR_PCT.
## Returns a fixed-point value (FP scale).
static func scaling_for_hit_count(hit_count: int) -> int:
	if hit_count <= 1:
		return FP.ONE
	var pct: int = _FIRST_HIT_PCT - (hit_count - 1) * _STEP_PCT
	if pct < _FLOOR_PCT:
		pct = _FLOOR_PCT
	# Convert whole percent to a fixed-point multiplier: pct/100 in FP.
	# FP.div(from_int(pct), from_int(100)) == pct/100 at FP scale, integer math only.
	return FP.div(FP.from_int(pct), FP.from_int(100))
