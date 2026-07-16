class_name FrameDataPanelModel
extends RefCounted

## Pure view-model for TKT-P1-07 (frame-data & advantage panel).
## training-mode.md → Readout: frame data + advantage; criterion 6; AD-008's
## static-vs-live distinction; AD-033's height-dependent read.
##
## Reads ONLY through InspectionView (the seam) — `frame_data()`,
## `advantage()`, `player()`, `last_hit()` — and produces a plain Dictionary of
## display-ready fields. No Node/Control/Label API here, so the values this
## computes are headlessly testable without a running scene tree (what the
## batch's "how to work" section calls out as testable: "the values each panel
## computes from InspectionView").
##
## STATIC VS LIVE (AD-008). `static_p0`/`static_p1` are the pinned
## startup/active/recovery/on_hit_adv/on_block_adv for whatever move each
## player is CURRENTLY in (`FrameData`, looked up via `player(i).state_id` —
## the "moves in play" the ticket names, read live off the state machine, not
## a fixed move picked ahead of time). `live` is the cancel-aware
## AdvantageView (value / who's plus / frames_to_neutral / neutral_restored).
##
## HEIGHT-DEPENDENT READ (AD-033; "surface the height-dependent read").
## `last_hit_why` is null when there is no recorded hit, or when the last hit
## was not an air normal (both contact_depth/air_height_hitstun_delta are 0 —
## inspection-surface.md), and otherwise a plain Dictionary carrying
## `contact_depth` / `air_height_hitstun_delta` plus the attacker/defender
## indices, so a caller can render "connected deep (depth X) -> +N hitstun."


static func build(view: InspectionView) -> Dictionary:
	var out: Dictionary = {}
	out["static"] = [
		_static_for_player(view, 0),
		_static_for_player(view, 1),
	]
	out["live"] = _live(view)
	out["last_hit_why"] = _last_hit_why(view)
	out["last_hit_guard"] = _last_hit_guard(view)
	return out


static func _static_for_player(view: InspectionView, i: int) -> Dictionary:
	var pv: PlayerView = view.player(i)
	var fd: FrameData = view.frame_data(pv.character_id, pv.state_id)
	return {
		"player": i,
		"state_id": pv.state_id,
		"startup": fd.startup,
		"active": fd.active,
		"recovery": fd.recovery,
		"total": fd.total,
		"on_hit_adv": fd.on_hit_adv,
		"on_block_adv": fd.on_block_adv,
	}


static func _live(view: InspectionView) -> Dictionary:
	var a: AdvantageView = view.advantage()
	return {
		"value": a.value,
		"plus_player": a.plus_player,
		"frames_to_neutral": a.frames_to_neutral,
		"neutral_restored": a.neutral_restored,
	}


## The "why" a deep jump-in is more plus (AD-033): contact_depth and
## air_height_hitstun_delta from the most recent hit, or null if there is no
## last hit, or the last hit carries no height contribution (both fields 0 —
## a grounded/blocked/thrown contact per inspection-surface.md). Returning
## null in that case (rather than a zero-valued dict) keeps the panel able to
## distinguish "no air-height story to tell" from "a height delta of exactly
## zero" at the display layer without re-deriving anything.
static func _last_hit_why(view: InspectionView):
	var hit: HitEvent = view.last_hit()
	if hit == null:
		return null
	if hit.contact_depth == 0 and hit.air_height_hitstun_delta == 0:
		return null
	return {
		"attacker": hit.attacker,
		"defender": hit.defender,
		"contact_depth": hit.contact_depth,
		"air_height_hitstun_delta": hit.air_height_hitstun_delta,
	}


## A one-line human-readable rendering of the height "why," for the panel's
## text label. Returns "" if there is nothing to show (mirrors _last_hit_why's
## null case). Kept as a pure string formatter so it is testable alongside the
## data it formats.
static func format_last_hit_why(why) -> String:
	if why == null:
		return ""
	var depth: int = why["contact_depth"]
	var delta: int = why["air_height_hitstun_delta"]
	var sign_str: String = "+" if delta >= 0 else ""
	return "connected deep (depth %d) -> %s%d hitstun" % [depth, sign_str, delta]


## HIGH/LOW BLOCK ATTRIBUTION (TKT-P2-08; AD-045; inspection-surface.md
## criterion 8). The most recent hit's `guard_height`/`block_valid`
## (HitEvent), so "was this an overhead, a low, or a mid — and did the
## defender's stance actually cover it" is readable regardless of whether the
## hit carries an air-height story (unlike `_last_hit_why` above, this is NOT
## gated on contact_depth/air_height_hitstun_delta being nonzero — a grounded
## overhead/low is exactly the case this readout exists for). Returns null
## when there is no recorded hit at all (mirrors `_last_hit_why`'s null case).
static func _last_hit_guard(view: InspectionView):
	var hit: HitEvent = view.last_hit()
	if hit == null:
		return null
	return {
		"attacker": hit.attacker,
		"defender": hit.defender,
		"guard_height": hit.guard_height,
		"was_block": hit.was_block,
		"block_valid": hit.block_valid,
	}


## Human-readable name for a HitBox.GUARD_* value.
static func guard_height_name(guard_height: int) -> String:
	match guard_height:
		HitBox.GUARD_HIGH: return "HIGH"
		HitBox.GUARD_LOW: return "LOW"
		HitBox.GUARD_MID: return "MID"
		_: return "?"


## A one-line human-readable rendering of the high/low attribution, for the
## panel's text label. Returns "" if there is no last hit to report (mirrors
## format_last_hit_why's null case). Three readable outcomes (character-b.md's
## mixup layer / inspection-surface.md criterion 8):
##   - the hit was BLOCKED -> "P_ blocked a HIGH/LOW/MID hit from P_"
##   - the hit CONNECTED because the defender's stance did not cover it
##     (was_block == false AND block_valid == false) -> names WHY it beat the
##     guard ("wrong stance") rather than leaving it an unexplained non-block
##     (charter: "find out what happened and why"; no knowledge checks).
##   - the hit CONNECTED because the defender simply was not blocking at all
##     (was_block == false AND block_valid == true — nothing to attribute to
##     stance) -> a plain connect line, no stance claim.
static func format_last_hit_guard(guard) -> String:
	if guard == null:
		return ""
	var gh_name: String = guard_height_name(guard["guard_height"])
	var attacker: int = guard["attacker"]
	var defender: int = guard["defender"]
	if guard["was_block"]:
		return "P%d blocked a %s hit from P%d" % [defender, gh_name, attacker]
	if not guard["block_valid"]:
		return "P%d's %s hit beat P%d's guard (wrong stance -- no block)" % [attacker, gh_name, defender]
	return "P%d's %s hit connected on P%d" % [attacker, gh_name, defender]
