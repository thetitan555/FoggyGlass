class_name CancelGroup
extends Resource

## A named set of state_ids a CancelRule.target may reference as a GROUP
## (move-format.md → Character.cancel_groups; AD-044). Authored data — character
## content, not engine code — resolved by CancelEval when a CancelRule's
## `target_is_group` is true (`CancelRule.target` then holds this group's `id`,
## not a state_id; the two are disambiguated by `target_is_group`, an already-
## existing field — AD-044 adds no new CancelRule field).
##
## Character B's gatling ladder authors one (or a few, where sets coincide) of
## these per source normal: the set of legal DESTINATION states that normal may
## cancel into (higher strength, or same-strength opposite stance, or — for
## lights — any light including self). See character-b.md / AD-044's precise rule.

## Stable identifier this group is referenced by (a `CancelRule.target` when
## `target_is_group` is true).
@export var id: int = 0

## The member state_ids. A buffered command whose destination state_id is in
## this set satisfies a group-target cancel (AD-044).
@export var members: Array[int] = []


## True iff `state_id` is a member of this group.
func has_member(state_id: int) -> bool:
	return members.has(state_id)
