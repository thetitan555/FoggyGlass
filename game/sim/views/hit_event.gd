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
	return e
