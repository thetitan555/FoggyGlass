class_name HitEvent
extends RefCounted

## Read-only view of the most recent resolved hit (inspection-surface.md → HitEvent).
##
## A plain-data projection of SimState.last_hit (a HitRecord). Carries only integer
## truth (indices, damage, integer percent, tick) plus a bool — no floats
## (AD-019), so it is snapshot-able for QA goldens. Read-only by construction:
## fields are copied out at build, so a caller cannot reach the live sim record.

var attacker: int = 0
var defender: int = 0
var damage_dealt: int = 0
var was_block: bool = false
## Scaling at the time, as a whole percent (integer).
var scaling_applied: int = 100
var combo_count_after: int = 0
var tick: int = 0

## Air-normal height-dependent advantage readout (AD-033; TKT-P1-13). The
## attacker's depth above ground at connect (fixed-point) and the signed
## whole-frame hitstun delta it produced through AirHeightScaling — both `0` on
## any non-air-normal hit (blocked, thrown, or a grounded attacker), so "why" a
## deep jump-in is more plus is readable without back-computation.
var contact_depth: int = 0
var air_height_hitstun_delta: int = 0

## Directional-block attribution (AD-045; TKT-P2-03; inspection-surface.md
## criterion 8). `guard_height` is the connecting attack's block-height
## requirement (HitBox.GUARD_HIGH/LOW/MID); `block_valid` is whether the
## defender's block was stance-valid for it. When the defender held back but in
## the wrong stance (`block_valid == false`, `was_block == false`), the training
## mode shows *why* the hit landed — an overhead that beat a crouch, a low that
## beat a stand-block.
var guard_height: int = 0
var block_valid: bool = true


## Build a view from the sim's serialized HitRecord. The single source of truth is
## the record in state; this only re-shapes it for the seam.
static func from_record(rec: HitRecord) -> HitEvent:
	var e := HitEvent.new()
	e.attacker = rec.attacker
	e.defender = rec.defender
	e.damage_dealt = rec.damage_dealt
	e.was_block = rec.was_block
	e.scaling_applied = rec.scaling_applied_pct
	e.combo_count_after = rec.combo_count_after
	e.tick = rec.tick
	e.contact_depth = rec.contact_depth
	e.air_height_hitstun_delta = rec.air_height_hitstun_delta
	e.guard_height = rec.guard_height
	e.block_valid = rec.block_valid
	return e
