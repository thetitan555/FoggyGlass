class_name Character
extends Resource

## A character: a state machine referencing move data (move-format.md → Character;
## AD-006, AD-007). Authored purely as `.tres` data — authoring a character touches
## data, never engine code (move-format.md criterion 1). Every character uses the
## ONE state-machine pattern (AD-007); this resource is just the data.

## Stable identifier (stored in PlayerState.character_id).
@export var id: int = 0

## The MoveStates this character has.
@export var states: Array[MoveState] = []

## Maps generic BUTTON_n (+ direction/motion) -> state_id. The ONLY place buttons
## gain meaning (move-format.md; AD-018 keeps the input layer semantically blank).
## Modeled as a list of ButtonMapEntry so it serializes as stable `.tres` text.
@export var button_map: Array[ButtonMapEntry] = []

## Walk/dash/jump/gravity constants, baked fixed-point integers (AD-014). Kept as a
## flat resource so the .tres stays diffable and the runtime reads plain ints.
@export var physics: CharacterPhysics = null

## Default pushbox (character-local, fixed-point) used by any MoveState that does
## not override it (move-format.md → Box pushbox note).
@export var default_pushbox: Box = null

## Named cancel-group sets a `CancelRule.target` may reference when
## `target_is_group` is true (move-format.md → Character.cancel_groups; AD-044).
## Optional — empty for a character with no group-target cancels (character A).
## Character B's gatling ladder is authored against these (the format-generality
## capability AD-044 builds: group-target resolution, deferred since JC-023).
@export var cancel_groups: Array[CancelGroup] = []

## The state_id the character returns to when a move ends / becomes actionable
## (idle). Authored so the sim knows the neutral state without a hardcoded id.
## Idle is NOT a reaction (AD-049) -- this field is unaffected by that change.
@export var idle_state_id: int = 0

## REQUIRED (AD-049). Maps every engine-level ReactionKind (MoveState.REACTION_*)
## to THIS character's OWN state_id -- move-format.md -> "Reactions" /
## Character.reaction_map. This is how a state named by someone else (the
## opponent's HitBox, or the engine's land/throw resolution) is reached without
## a raw state_id ever crossing a character boundary (the character-namespace
## rule). Every character must author EVERY kind -- not every kind it inflicts,
## every kind it can RECEIVE (a character with no launcher of its own still
## gets launched by one that has one) -- checked statically by
## move-format.md criterion 15. Folds in the old `knockdown_state_id` field
## (retired) as `reaction_map[REACTION_KNOCKDOWN]`.
@export var reaction_map: Array[ReactionMapEntry] = []


## The MoveState with the given id, or null if the character has no such state.
## Character-agnostic lookup (no per-character branch — move-format.md criterion 4).
func get_state(state_id: int) -> MoveState:
	for s in states:
		if s.id == state_id:
			return s
	return null


## The pushbox in effect for a given move: the move's own pushbox if set, else the
## character default. May be null if neither is authored (caller treats as no push).
func pushbox_for(move: MoveState) -> Box:
	if move != null and move.pushbox != null:
		return move.pushbox
	return default_pushbox


## The CancelGroup with the given id, or null if this character declares no such
## group (AD-044). Character-agnostic lookup, mirrors get_state.
func cancel_group(group_id: int) -> CancelGroup:
	for g in cancel_groups:
		if g.id == group_id:
			return g
	return null


## Resolve an engine-level ReactionKind to THIS character's OWN state_id
## (move-format.md "Reactions" -> the resolution floor; AD-049). This is the
## ONLY path a defender-facing reaction lookup takes -- never a raw state_id
## read against another character's data (the character-namespace rule;
## combat-resolution.md phase 5 / criterion 17).
##
## Resolution floor (a guardrail against a content hole, NOT an authoring
## fallback -- move-format.md criterion 15 catches a missing kind statically,
## before this floor would ever fire in play): `kind -> REACTION_HITSTUN ->
## idle_state_id`. Content that fires this floor has already failed the static
## completeness check; do not author against it.
func reaction_state(kind: int) -> int:
	for e in reaction_map:
		if e.kind == kind:
			return e.state_id
	if kind != MoveState.REACTION_HITSTUN:
		for e in reaction_map:
			if e.kind == MoveState.REACTION_HITSTUN:
				return e.state_id
	return idle_state_id


## True iff this character maps a given ReactionKind (has an authored entry --
## distinct from reaction_state's floor, which always returns SOME int). Used by
## move-format.md criterion 15's static roster completeness check.
func has_reaction(kind: int) -> bool:
	for e in reaction_map:
		if e.kind == kind:
			return true
	return false


## Every ReactionKind this character does NOT author (move-format.md criterion
## 15's static check: a non-empty result is a content error over the roster).
func missing_reactions() -> Array[int]:
	var missing: Array[int] = []
	for kind in MoveState.VALID_REACTION_KINDS:
		if not has_reaction(kind):
			missing.append(kind)
	return missing
