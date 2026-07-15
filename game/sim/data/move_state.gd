class_name MoveState
extends Resource

## One data-defined state in a character's state machine (move-format.md → MoveState;
## AD-006, AD-007). Concrete moves/actions (idle, walk, a normal, a special, a
## throw) each declare which ENGINE-LEVEL CATEGORY they belong to; per-move
## specifics live entirely in data. Every character uses this one pattern — no
## bespoke per-character machines (AD-007). This consistency guard is what lets
## character B be content, not engineering.

## State id (stored in SimState.players[i].state_id).
@export var id: int = 0

## Engine-level category (CATEGORY_* below). The small fixed set the engine
## understands and uses to govern physics and legal transitions (move-format.md).
@export var category: int = CATEGORY_GROUNDED

## Total frames before the state ends / returns to actionable.
@export var duration: int = 1

## Ordered list of Keyframe ranges (the timeline).
@export var timeline: Array[Keyframe] = []

## Typed cancel rules (AD-015). A list, never one opaque field.
@export var cancels: Array[CancelRule] = []

## Whether `duration` loops (idle/walk) or plays once.
@export var loop: bool = false

## Whether this state is a CROUCHING stance (AD-038's "crouch stance" — e.g. the
## held-DOWN loop state, a crouching normal, or a crouch-blockstun reaction).
## Authored content (like `loop`), read by phase 5's directional-block-enforcement
## check (AD-045, combat-resolution.md "Directional block enforcement") to derive
## the defender's stance for `HitBox.guard_height` compatibility — a defender whose
## CURRENT state has `is_crouch == true` is crouching; standing otherwise. Default
## false (every existing non-crouch state is unaffected). No SimState shape change:
## this is authored move data, resolved through the same MoveRegistry lookup that
## already backs `state_id`, exactly like `loop`/`category`/`pushbox`.
@export var is_crouch: bool = false

## Pushbox for this state (character-local, fixed-point). Per move-format.md the
## pushbox is defined per MoveState/category unless a move overrides it. A move with
## a null pushbox uses the character's default (Character.default_pushbox).
@export var pushbox: Box = null

# --- Engine-level state categories (move-format.md; AD-007 slice set) --------
const CATEGORY_GROUNDED: int = 0
const CATEGORY_AIRBORNE: int = 1
const CATEGORY_HITSTUN: int = 2
const CATEGORY_BLOCKSTUN: int = 3
## HITSTOP is a frozen overlay category (move-format.md). A state is not authored AS
## hitstop; hitstop is an in-state freeze (AD-010). Kept in the set for completeness
## and validation (a category value must be one of these).
const CATEGORY_HITSTOP: int = 4

const VALID_CATEGORIES: Array[int] = [
	CATEGORY_GROUNDED, CATEGORY_AIRBORNE, CATEGORY_HITSTUN,
	CATEGORY_BLOCKSTUN, CATEGORY_HITSTOP,
]


## True iff `category` is one of the engine-level categories (move-format.md
## criterion 6: every state declares a VALID engine-level category).
func has_valid_category() -> bool:
	return category in VALID_CATEGORIES


## The keyframes covering `frame` (1-indexed frame_in_state). Multiple keyframes may
## overlap a frame; the box resolver unions their box sets (derived, AD-001).
func keyframes_at(frame: int) -> Array[Keyframe]:
	var out: Array[Keyframe] = []
	for kf in timeline:
		if kf.covers(frame):
			out.append(kf)
	return out
