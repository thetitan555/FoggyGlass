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
