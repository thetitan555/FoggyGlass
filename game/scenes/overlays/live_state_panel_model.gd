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
##
## AIR-ACTION ECONOMY READOUT (TKT-P2-08; AD-046; inspection-surface.md
## `PlayerView.air_action_used`). A straight read-through of the ALREADY-
## surfaced field (no new sim-side plumbing) — B's whole "one air dash OR one
## double jump per jump" economy (character-b.md) is otherwise invisible on
## screen, so this panel is where a session reads "has this player already
## spent their air action this jump."
##
## STATE IDENTITY, NOT JUST CATEGORY (`docs/flags.md` 2026-07-17, "re: reaction
## legibility" — the P2-gate headline fix). `state_category` is an engine-level
## BUCKET; several distinct, differently-answered reactions share one bucket
## (`STATE_KNOCKDOWN`/`STATE_HITSTUN_LAUNCH`/`STATE_AIR_RESET`/ordinary hitstun
## are all `CATEGORY_HITSTUN`). `identity_name()` reads `PlayerView.reaction_kind`
## (the state's own `ReactionKind`, AD-049) and leads the row with THAT —
## "knockdown"/"launch"/"air reset" read apart on sight — with category kept
## alongside, never dropped.

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
		"air_action_used": pv.air_action_used,
		"reaction_kind": pv.reaction_kind,
	}


## Human-readable category name for display (a plain view-only lookup — the
## sim's category ints are the canonical truth, this only labels them).
## NOTE: category is the engine-level BUCKET, not the state's own identity —
## `STATE_KNOCKDOWN`, `STATE_HITSTUN_LAUNCH`, `STATE_AIR_RESET` and ordinary
## hitstun all share `CATEGORY_HITSTUN`, so this alone cannot tell them apart.
## See `identity_name()` below (`docs/flags.md` 2026-07-17, "re: reaction
## legibility") — category is shown ALONGSIDE identity in `format_row`, never
## in place of it.
static func category_name(category: int) -> String:
	match category:
		MoveState.CATEGORY_GROUNDED: return "grounded"
		MoveState.CATEGORY_AIRBORNE: return "airborne"
		MoveState.CATEGORY_HITSTUN: return "hitstun"
		MoveState.CATEGORY_BLOCKSTUN: return "blockstun"
		MoveState.CATEGORY_HITSTOP: return "hitstop"
		_: return "?"


## Human-readable name for a `MoveState.REACTION_*` kind (a plain view-only
## lookup, mirrors `category_name`). This is the state's own IDENTITY — distinct
## from its `category` bucket — resolved from `PlayerView.reaction_kind`.
static func reaction_kind_name(kind: int) -> String:
	match kind:
		MoveState.REACTION_HITSTUN: return "hitstun"
		MoveState.REACTION_LAUNCH: return "launch"
		MoveState.REACTION_AIR_RESET: return "air reset"
		MoveState.REACTION_KNOCKDOWN: return "knockdown"
		MoveState.REACTION_BLOCKSTUN: return "blockstun"
		MoveState.REACTION_CROUCH_BLOCKSTUN: return "crouch blockstun"
		_: return "?"


## The one label the readout leads with: the state's own IDENTITY, not just its
## engine-level category (`docs/flags.md` 2026-07-17, "re: reaction legibility" —
## the headline P2-gate fix). When the current state is one the character
## authored into its `reaction_map` (`row["reaction_kind"] != -1`), that specific
## kind name IS the identity — "knockdown"/"launch"/"air reset" read apart on
## sight instead of collapsing to one "hitstun" word. Otherwise (an ordinary
## move/idle/walk state — not a reaction) the category name already IS the
## identity, so it's used as-is. `category_name` stays available separately —
## this never replaces it, only leads with the finer-grained truth.
static func identity_name(row: Dictionary) -> String:
	var kind: int = row["reaction_kind"]
	if kind != -1:
		return reaction_kind_name(kind)
	return category_name(row["state_category"])


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
	var air_action_str: String = "  air-action: SPENT" if row["air_action_used"] else "  air-action: ready"
	# Identity leads (knockdown/launch/air reset/hitstun/...); category follows,
	# always present but never the only label (docs/flags.md 2026-07-17,
	# "re: reaction legibility" — category alone collapsed four distinct states
	# into one word).
	return "P%d  state %d %s (cat:%s) f%d/%d  hitstop %d  stun %d(%s)  actionable %s%s%s  hits %d scaling %d%% dmg %d" % [
		row["player"], row["state_id"], identity_name(row), category_name(row["state_category"]),
		row["frame_in_state"], row["state_duration"],
		row["hitstop_remaining"],
		row["stun_remaining"], stun_kind_name(row["stun_kind"]),
		str(row["actionable"]), invuln_str, air_action_str,
		row["hit_count"], row["scaling_pct"], row["damage_total"],
	]
