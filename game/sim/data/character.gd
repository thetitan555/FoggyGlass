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
@export var idle_state_id: int = 0


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
