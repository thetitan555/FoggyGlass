class_name Actionability
extends RefCounted

## The ONE definition of "is this player actionable" (combat-resolution.md → "Stun &
## actionability"; inspection-surface.md → PlayerView.actionable). All static — no
## state. Single-sourced so the inspection surface and the sim's own transition /
## advantage logic agree (they call THIS, never re-derive).
##
## RULE (combat-resolution.md): a player is actionable when
##   stun == 0  AND  hitstop == 0  AND  not in a committed recovery state.
## - stun (hitstun/blockstun) blocks action until it expires.
## - hitstop freezes the character in place (AD-010): frozen frames are not
##   actionable frames — a character in hitstop cannot act (the freeze is a true
##   freeze; buffered commands execute on the first UNFROZEN tick, AD-017).
## - "committed recovery" = a non-looping move state that has not yet reached its
##   duration. A looping state (idle/walk) is always actionable when not stunned; a
##   move that plays once commits the character until it ends.


## True iff the player is actionable given its current state and (optionally) the
## MoveState it is in. `move` may be null (roster not supplied to a view, or an
## engine-level default) — then only stun/hitstop gate actionability, which is the
## safe minimum (a null move is treated as not committing recovery).
static func is_actionable(p: PlayerState, move: MoveState) -> bool:
	if p.stun > 0:
		return false
	if p.hitstop > 0:
		return false
	if move == null:
		return true
	# Stun-category states are never actionable while occupied (they end via stun
	# expiry, handled above once stun hits 0 and the state returns to idle).
	if move.category == MoveState.CATEGORY_HITSTUN or move.category == MoveState.CATEGORY_BLOCKSTUN:
		return false
	# A looping state (idle/walk) is actionable; a once-through move commits recovery
	# until frame_in_state reaches its duration.
	if move.loop:
		return true
	return p.frame_in_state >= move.duration


## Frames until the player becomes actionable in its CURRENT situation (used by the
## live advantage formula, AD-008 — "actual frames until actionable"). This is the
## raw situational count from state, NOT accounting for a committed cancel (the
## cancel-aware reduction is applied by Advantage using cancel state, TKT-P0-08).
##   - If already actionable: 0.
##   - In stun: stun frames remain (plus any hitstop that still freezes them).
##   - In committed recovery: frames left in the move (duration - frame_in_state),
##     plus any active hitstop freeze.
static func frames_to_actionable(p: PlayerState, move: MoveState) -> int:
	# Hitstop freezes counters (AD-010): while frozen, the countdown does not run, so
	# the remaining frozen frames are added on top of whatever comes after.
	var frozen: int = p.hitstop
	if p.stun > 0:
		return frozen + p.stun
	if move == null or move.loop:
		return frozen
	if move.category == MoveState.CATEGORY_HITSTUN or move.category == MoveState.CATEGORY_BLOCKSTUN:
		# Stun categories with stun already 0 fall through to actionable next tick.
		return frozen
	var remaining: int = move.duration - p.frame_in_state
	if remaining < 0:
		remaining = 0
	return frozen + remaining
