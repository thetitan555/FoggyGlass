class_name HitRecord
extends RefCounted

## The serialized record of one resolved hit (SimState.last_hit; F-002).
##
## This is plain-data sim state — it lives INSIDE SimState so `last_hit` survives
## snapshot/restore and is covered by the canonical hash (AD-023 total coverage).
## The inspection surface projects it to a read-only HitEvent view
## (inspection-surface.md → HitEvent); this class is the sim-side truth, that class
## is the seam-side view.
##
## Written by hit resolution (TKT-P0-07, phase 5) each time a hit or block resolves;
## `last_hit` always holds the MOST RECENT one. All fields are plain ints
## (indices, whole damage, integer percent, tick) — no floats (AD-005/019).

## Player indices.
var attacker: int = 0
var defender: int = 0

## Damage actually applied (whole units, after scaling). `was_block` true if blocked.
var damage_dealt: int = 0
var was_block: bool = false

## Damage scaling in effect at the time, as a whole percent (integer; e.g. 80 == 80%).
## Kept as an integer percent so it stays snapshot-able / float-free.
var scaling_applied_pct: int = 100

## Combo count AFTER this hit was counted.
var combo_count_after: int = 0

## The tick this hit resolved on.
var tick: int = 0

## Canonical hash field order (AD-023). SimState.hash_state folds these in order.
const HASH_FIELDS: Array[String] = [
	"attacker", "defender", "damage_dealt", "was_block_int",
	"scaling_applied_pct", "combo_count_after", "tick",
]


func clone() -> HitRecord:
	var r := HitRecord.new()
	r.attacker = attacker
	r.defender = defender
	r.damage_dealt = damage_dealt
	r.was_block = was_block
	r.scaling_applied_pct = scaling_applied_pct
	r.combo_count_after = combo_count_after
	r.tick = tick
	return r


## Serialize to plain-data. `was_block` is stored as an int (0/1) under
## `was_block_int` so both to_dict and the hash walk see a pure-integer stream.
func to_dict() -> Dictionary:
	return {
		"attacker": attacker,
		"defender": defender,
		"damage_dealt": damage_dealt,
		"was_block_int": 1 if was_block else 0,
		"scaling_applied_pct": scaling_applied_pct,
		"combo_count_after": combo_count_after,
		"tick": tick,
	}


static func from_dict(d: Dictionary) -> HitRecord:
	var r := HitRecord.new()
	r.attacker = int(d["attacker"])
	r.defender = int(d["defender"])
	r.damage_dealt = int(d["damage_dealt"])
	r.was_block = int(d["was_block_int"]) != 0
	r.scaling_applied_pct = int(d["scaling_applied_pct"])
	r.combo_count_after = int(d["combo_count_after"])
	r.tick = int(d["tick"])
	return r
