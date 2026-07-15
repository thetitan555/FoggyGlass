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

## Air-normal height-dependent advantage readout (AD-033; TKT-P1-13). `contact_depth`
## is the attacker's depth above ground at the moment of connect (fixed-point,
## ground_y - attacker.pos_y); `air_height_hitstun_delta` is the signed whole-frame
## hitstun delta AirHeightScaling derived from it. Both `0` on any non-air-normal
## hit (blocked, thrown, or a grounded attacker) — the deterministic default, so a
## ground hit's record reads "no height scaling applied."
var contact_depth: int = 0
var air_height_hitstun_delta: int = 0

## Directional-block attribution (AD-045; TKT-P2-03). `guard_height` is the
## connecting attack's block-height requirement (HitBox.GUARD_HIGH/LOW/MID);
## `block_valid` is whether the defender's block was stance-valid for it — true
## when the defender did not attempt to block at all (no violation to report) or
## attempted a stance-correct block, false only for a wrong-stance back-hold (the
## hit that lands "through" an attempted block). Defaults (GUARD_MID, true) match
## every P1 hit unchanged (move-format.md → HitBox.guard_height default MID).
var guard_height: int = HitBox.GUARD_MID
var block_valid: bool = true

## Canonical hash field order (AD-023). SimState.hash_state folds these in order.
const HASH_FIELDS: Array[String] = [
	"attacker", "defender", "damage_dealt", "was_block_int",
	"scaling_applied_pct", "combo_count_after", "tick",
	"contact_depth", "air_height_hitstun_delta",
	"guard_height", "block_valid_int",
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
	r.contact_depth = contact_depth
	r.air_height_hitstun_delta = air_height_hitstun_delta
	r.guard_height = guard_height
	r.block_valid = block_valid
	return r


## Serialize to plain-data. `was_block` / `block_valid` are stored as ints (0/1)
## under their `_int`-suffixed keys so both to_dict and the hash walk see a
## pure-integer stream.
func to_dict() -> Dictionary:
	return {
		"attacker": attacker,
		"defender": defender,
		"damage_dealt": damage_dealt,
		"was_block_int": 1 if was_block else 0,
		"scaling_applied_pct": scaling_applied_pct,
		"combo_count_after": combo_count_after,
		"tick": tick,
		"contact_depth": contact_depth,
		"air_height_hitstun_delta": air_height_hitstun_delta,
		"guard_height": guard_height,
		"block_valid_int": 1 if block_valid else 0,
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
	r.contact_depth = int(d["contact_depth"])
	r.air_height_hitstun_delta = int(d["air_height_hitstun_delta"])
	# A pre-P2 (v2) dict predates guard_height/block_valid (AD-034 migration,
	# SimState.from_dict); defaults (MID / valid) are correct for a hit recorded
	# before directional-block enforcement existed.
	r.guard_height = int(d.get("guard_height", HitBox.GUARD_MID))
	r.block_valid = int(d.get("block_valid_int", 1)) != 0
	return r
