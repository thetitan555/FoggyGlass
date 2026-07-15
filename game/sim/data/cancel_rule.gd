class_name CancelRule
extends Resource

## One typed cancel rule in a MoveState.cancels list (move-format.md → CancelRule;
## AD-015). NOT one opaque field: move classes are EXPRESSED, not special-cased —
## gatling/chain = on_contact to another normal within a window; special-cancel =
## requires_tag granted by the connecting hitbox; whiff-cancel = on_whiff.
##
## Evaluated in phase 2 (TKT-P0-08); the schema is authored/serialized here at P0.

## Destination state_id, or a tag/group id naming a set of states (interpretation
## fixed by `target_is_group`).
##
## GROUP TARGETS (AD-044, `target_is_group == true`): `target` names a
## `Character.cancel_groups` entry's `id`, not a state_id. Resolution differs from
## a concrete target: there is no single destination to gate one `input` command
## against, so `input` is authored `0` (no gate) and CancelEval instead scans the
## character's `button_map` for WHICHEVER group-member command is buffered this
## tick, resolving to that entry's concrete `target_state_id` (see
## CancelEval._group_cancel_target). Character B's gatling ladder is authored
## this way (move-format.md → CancelRule; character-b.md).
@export var target: int = 0
@export var target_is_group: bool = false

## When the cancel is allowed (CONDITION_* below).
@export var condition: int = CONDITION_ALWAYS

## Frame range within the move the cancel is allowed. Default (both 0) means
## first-active -> end (resolved against the move at evaluation time).
@export var window_start: int = 0
@export var window_end: int = 0

## Required command to take the cancel (a button/motion command id; 0 = none).
@export var input: int = 0

## Optional cancel tag that must be present (granted by a connecting HitBox's
## cancel_tags). 0 = no tag required.
@export var requires_tag: int = 0

# --- condition values (move-format.md) --------------------------------------
const CONDITION_ON_HIT: int = 0
const CONDITION_ON_BLOCK: int = 1
const CONDITION_ON_CONTACT: int = 2   # hit OR block
const CONDITION_ON_WHIFF: int = 3
const CONDITION_ALWAYS: int = 4
