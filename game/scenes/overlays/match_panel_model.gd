class_name MatchPanelModel
extends RefCounted

## Pure view-model for the MATCH PANEL (TKT-P2-08; match-flow.md "Legibility";
## inspection-surface.md → MatchView, AD-048). Mirrors the P1 overlay pattern
## exactly (JC-040's view/(pure)view-model split): this class does all the
## `MatchView` reads and produces plain, display-ready data; the sibling
## `MatchPanel` (a thin Node/Label) only formats and draws it.
##
## Reads ONLY `MatchView` (via `TrainingMode.match_view()`, itself read-only
## over `MatchState`) — no sim-internal type. Plain Dictionary output,
## headlessly testable (no Node/Control API here), exactly like
## `LiveStatePanelModel`/`FrameDataPanelModel`.
##
## WHY THIS IS ITS OWN PANEL rather than folded into an existing one: `MatchView`
## is a DISTINCT read-only root from `InspectionView` (inspection-surface.md's
## own note — "a caller holding a MatchState builds InspectionView... AND
## MatchView... the two seams compose, neither reaches into the other's
## internals") — a match-level readout (health/round-wins/timer/phase/reason)
## is a genuinely different truth than any per-player `PlayerView` field, so it
## gets its own panel rather than being smuggled into one that reads a
## different view type.
##
## `match_view` may be null (sandbox-mode training-mode sessions have no
## MatchState at all) — `build()` returns a plain "no match" marker Dictionary
## in that case rather than raising, so the SAME panel can be mounted in either
## mode without the caller special-casing it.

const PHASE_NAMES: PackedStringArray = ["ROUND_START", "ACTIVE", "ROUND_END", "MATCH_END"]
const REASON_NAMES: PackedStringArray = ["NONE", "KO", "TIMEOUT", "DOUBLE_KO"]


static func build(match_view) -> Dictionary:
	if match_view == null:
		return {"has_match": false}
	var mv: MatchView = match_view
	return {
		"has_match": true,
		"health": [mv.health[0], mv.health[1]],
		"round_wins": [mv.round_wins[0], mv.round_wins[1]],
		"round_timer": mv.round_timer,
		"match_phase": mv.match_phase,
		"sudden_death": mv.sudden_death,
		"last_round_end_reason": mv.last_round_end_reason,
		"round_index": mv.round_index,
	}


static func phase_name(match_phase: int) -> String:
	if match_phase >= 0 and match_phase < PHASE_NAMES.size():
		return PHASE_NAMES[match_phase]
	return "?"


static func reason_name(reason: int) -> String:
	if reason >= 0 and reason < REASON_NAMES.size():
		return REASON_NAMES[reason]
	return "?"


## Frames -> whole seconds at 60Hz (render-only formatting; matches the fixed-
## tick discipline's own cadence, never used as a gameplay value). Rounds UP
## so the clock never reads "0" while a tick remains (a legibility nicety —
## the clock and the SERIALIZED round_timer truth agree at 0 either way).
static func timer_seconds(round_timer: int) -> int:
	return int(ceil(float(round_timer) / 60.0))


## A multi-line human-readable rendering of the whole match state (health,
## round pips, clock, phase, and — whenever a round/match has actually ended —
## the WHY, as serialized truth, never a render guess; match-flow.md
## "Legibility"). "" is never returned; a no-match session renders an explicit
## placeholder line instead (P1's lesson: a blank overlay reads as broken, not
## as "nothing to show").
static func format(model: Dictionary) -> String:
	if not model["has_match"]:
		return "-- Match --\n(sandbox mode -- no match running)"
	var lines: PackedStringArray = PackedStringArray()
	lines.append("-- Match --  round %d%s" % [
		model["round_index"] + 1,
		"  [SUDDEN DEATH]" if model["sudden_death"] else "",
	])
	lines.append("P0 health %d   |   P1 health %d" % [model["health"][0], model["health"][1]])
	lines.append("Round wins  P0: %d   P1: %d" % [model["round_wins"][0], model["round_wins"][1]])
	lines.append("Clock: %ds (%d ticks)   Phase: %s" % [
		timer_seconds(model["round_timer"]), model["round_timer"], phase_name(model["match_phase"]),
	])
	var reason: int = model["last_round_end_reason"]
	if reason != MatchState.REASON_NONE:
		lines.append("Last round ended: %s" % reason_name(reason))
	return "\n".join(lines)
