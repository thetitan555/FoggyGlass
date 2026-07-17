class_name ReactionMapEntry
extends Resource

## One entry in Character.reaction_map (move-format.md -> Character.reaction_map;
## AD-049). Maps an engine-level ReactionKind (MoveState.REACTION_*) to THIS
## character's OWN state_id -- the mechanism that lets a reaction named by
## someone else (the opponent's HitBox, or the engine's landing/throw paths)
## resolve to a real, character-local state without a raw id ever crossing a
## character boundary (move-format.md "The character-namespace rule").
##
## Packaged as a typed Resource list (mirrors ButtonMapEntry / CancelGroup)
## rather than a bare Dictionary so the .tres stays diffable/golden-able like
## every other authored collection (JC-079's precedent) -- internal storage
## shape only; Character.reaction_state(kind) is the one resolution path.

## Which reaction this entry maps (MoveState.REACTION_*).
@export var kind: int = MoveState.REACTION_HITSTUN

## This character's OWN state_id that reaction resolves to.
@export var state_id: int = 0


## Convenience constructor (mirrors Box.make).
static func make(reaction_kind: int, reaction_state_id: int) -> ReactionMapEntry:
	var e := ReactionMapEntry.new()
	e.kind = reaction_kind
	e.state_id = reaction_state_id
	return e
