class_name LiveStatePanelModel
extends RefCounted

## Pure view-model for TKT-P1-08 (live-state panel). training-mode.md →
## Readout: live state; criteria 7 and 9. Per player: state + category +
## frame/duration; hitstop; stun + kind; actionable; damage/combo
## (hit_count, scaling_pct, damage_total); and `PlayerView.invuln`
## (AD-031) — live, so "this frame is invulnerable" is readable in-mode.
##
## Reads ONLY InspectionView.player(i) — no sim-internal type. Plain
## Dictionary output, headlessly testable (no Node/Control API here).

const STUN_KIND_NAMES: PackedStringArray = ["none", "hit", "block"]


static func build(view: InspectionView) -> Array:
	var out: Array = []
	for i in range(2):
		out.append(_for_player(view, i))
	return out


static func _for_player(view: InspectionView, i: int) -> Dictionary:
	var pv: PlayerView = view.player(i)
	return {
		"player": i,
		"state_id": pv.state_id,
		"state_category": pv.state_category,
		"frame_in_state": pv.frame_in_state,
		"state_duration": pv.state_duration,
		"hitstop_remaining": pv.hitstop_remaining,
		"stun_remaining": pv.stun_remaining,
		"stun_kind": pv.stun_kind,
		"actionable": pv.actionable,
		"invuln_strike": bool(pv.invuln["strike"]),
		"invuln_throw": bool(pv.invuln["throw"]),
		"hit_count": pv.combo["hit_count"],
		"scaling_pct": pv.combo["scaling_pct"],
		"damage_total": pv.combo["damage_total"],
	}


## Human-readable category name for display (a plain view-only lookup — the
## sim's category ints are the canonical truth, this only labels them).
static func category_name(category: int) -> String:
	match category:
		MoveState.CATEGORY_GROUNDED: return "grounded"
		MoveState.CATEGORY_AIRBORNE: return "airborne"
		MoveState.CATEGORY_HITSTUN: return "hitstun"
		MoveState.CATEGORY_BLOCKSTUN: return "blockstun"
		MoveState.CATEGORY_HITSTOP: return "hitstop"
		_: return "?"


static func stun_kind_name(stun_kind: int) -> String:
	if stun_kind >= 0 and stun_kind < STUN_KIND_NAMES.size():
		return STUN_KIND_NAMES[stun_kind]
	return "?"


## A one-line human-readable rendering for one player's row.
static func format_row(row: Dictionary) -> String:
	var invuln_str: String = ""
	if row["invuln_strike"] or row["invuln_throw"]:
		var parts: PackedStringArray = PackedStringArray()
		if row["invuln_strike"]:
			parts.append("strike")
		if row["invuln_throw"]:
			parts.append("throw")
		invuln_str = "  invuln[%s]" % "+".join(parts)
	return "P%d  state %d (%s) f%d/%d  hitstop %d  stun %d(%s)  actionable %s%s  hits %d scaling %d%% dmg %d" % [
		row["player"], row["state_id"], category_name(row["state_category"]),
		row["frame_in_state"], row["state_duration"],
		row["hitstop_remaining"],
		row["stun_remaining"], stun_kind_name(row["stun_kind"]),
		str(row["actionable"]), invuln_str,
		row["hit_count"], row["scaling_pct"], row["damage_total"],
	]
