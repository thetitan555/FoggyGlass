class_name PlayerView
extends RefCounted

## Read-only view of one player's sim truth (inspection-surface.md → PlayerView).
##
## A plain-data projection over SimState.players[i]. Carries ONLY fixed-point
## integer / plain-int truth — NO floats (AD-019, inspection-surface.md criterion
## 4): every field here is snapshot-able and lands in QA goldens without float
## drift. Pixel projection is the InspectionView render helper, never a field here.
##
## Every field is copied out of state at construction, so this view is a stable
## snapshot of one tick that a caller cannot use to reach into and mutate sim
## internals (read-only by construction, criterion 2).
##
## SCOPE (TKT-P0-04). The core fields (identity, position/velocity, facing, health,
## stun, hitstop, frame, inputs, combo) are live now. `boxes` (resolved BoxViews)
## is populated once move data (TKT-P0-05) and overlap resolution (TKT-P0-06) land;
## until then it is an empty typed array. `state_category`, `state_duration`, and
## `actionable` read through move data where available, with a safe default when the
## roster has no entry for the current state (so the view is always well-formed).
##
## F-013 / AD-028 (TKT-P1-01). Four batch-2 legibility fields are surfaced READ-ONLY
## from the corresponding PlayerState truth, straight projection — no re-derivation:
## `move_contact`, `cancel_tags`, `throw_tech_window`, `thrown_by`. These back "did my
## move connect/whiff," "is a cancel window open," and "who threw whom, how long can I
## tech" (inspection-surface.md criterion 1). All plain int / PackedInt32Array — no
## floats, snapshot-able (AD-019).

# --- Identity + state machine ----------------------------------------------
var character_id: int = 0
var state_id: int = 0
var state_category: int = MoveState.CATEGORY_GROUNDED
var frame_in_state: int = 0
var state_duration: int = 0
var actionable: bool = false

# --- Movement (fixed-point truth) ------------------------------------------
var position: Dictionary = {"x": 0, "y": 0}   # fixed-point ints
var velocity: Dictionary = {"x": 0, "y": 0}   # fixed-point ints
var facing: int = 1

# --- Vitals / counters ------------------------------------------------------
var health: int = 0
var hitstop_remaining: int = 0
var stun_remaining: int = 0
var stun_kind: int = STUN_NONE

# --- Combo ------------------------------------------------------------------
## { hit_count, scaling_pct, damage_total }. scaling_pct is an integer percent
## (fixed-point projected to whole percent) so it stays snapshot-able / float-free.
var combo: Dictionary = {"hit_count": 0, "scaling_pct": 100, "damage_total": 0}

# --- Batch-2 legibility (F-013 / AD-028) — read-only projection of PlayerState ----

## This player's CURRENT-move outcome as attacker (AD-028): CONTACT_NONE / _HIT /
## _BLOCK / _WHIFF (mirrors PlayerState.CONTACT_* — plain int enum 0/1/2/3). Backs
## "did my move connect / whiff" and gates which cancels are live.
var move_contact: int = PlayerState.CONTACT_NONE

## The cancel tags this player currently holds AS ATTACKER (AD-017/028) — an open
## cancel window: the set of tags a buffered cancel can consume this tick. Empty =>
## no cancel window open. Snapshot-able PackedInt32Array.
var cancel_tags: PackedInt32Array = PackedInt32Array()

## Frames remaining in which this player (as thrown DEFENDER) may still tech the
## throw (AD-016/028). 0 => not in a tech window; >0 => the live tech-frame count.
var throw_tech_window: int = 0

## The attacker index that threw this player, or -1 if not currently thrown (AD-028).
var thrown_by: int = -1

# --- Inputs -----------------------------------------------------------------
var input_current: int = InputFrame.NEUTRAL
var input_history: PackedInt32Array = PackedInt32Array()   # oldest -> newest

# --- Resolved geometry (BoxView list; populated at TKT-P0-05/06) ------------
var boxes: Array[BoxView] = []

# --- stun_kind values (inspection-surface.md: hit / block / none) -----------
const STUN_NONE: int = 0
const STUN_HIT: int = 1
const STUN_BLOCK: int = 2


func _init(state: SimState, i: int, roster: Dictionary = {}) -> void:
	var p: PlayerState = state.players[i]
	character_id = p.character_id
	state_id = p.state_id
	frame_in_state = p.frame_in_state

	position = {"x": p.pos_x, "y": p.pos_y}
	velocity = {"x": p.vel_x, "y": p.vel_y}
	facing = p.facing
	health = p.health
	hitstop_remaining = p.hitstop
	stun_remaining = p.stun

	# stun_kind is derived from which stun the player is in. P0 records it on the
	# player (stun_kind field lands with reactions at TKT-P0-07); default none.
	stun_kind = p.stun_kind

	combo = {
		"hit_count": p.combo_hits,
		# scaling stored fixed-point (FP.ONE == 100%); project to a whole percent
		# for the snapshot-able view (integer, float-free).
		"scaling_pct": FP.round_to_int(FP.mul(p.combo_scaling, FP.from_int(100))),
		"damage_total": p.combo_damage,
	}

	# F-013 / AD-028: straight read-only projection of the corresponding SimState
	# truth — no re-derivation (inspection-surface.md "Single source of truth").
	move_contact = p.move_contact
	cancel_tags = p.cancel_tags.duplicate()
	throw_tech_window = p.throw_tech_window
	thrown_by = p.thrown_by

	input_current = p.input_history.newest()
	input_history = _history_oldest_to_newest(p.input_history)

	# State-machine reads that need move data. Resolve against the roster when it is
	# present; otherwise fall back to safe defaults so the view is always well-formed
	# (character-agnostic, criterion 5 — no character-specific branch).
	var move: MoveState = null
	var pushbox: Box = null
	if roster.has(character_id):
		var character: Character = roster[character_id]
		move = character.get_state(state_id)
		pushbox = character.pushbox_for(move)
	if move != null:
		state_category = move.category
		state_duration = move.duration
		boxes = _resolve_boxes(p, move, pushbox)
	else:
		state_category = MoveState.CATEGORY_GROUNDED
		state_duration = 0
		boxes = []

	# actionable: stun == 0 AND not in committed recovery (inspection-surface.md).
	# Committed-recovery determination reads move data; the sim's canonical
	# actionability lives in Actionability (TKT-P0-06/07). Use it so the view and the
	# sim agree (single source of truth).
	actionable = Actionability.is_actionable(p, move)


## The input history projected oldest -> newest as a plain PackedInt32Array (the
## canonical serialized order — matches InputHistory storage). Snapshot-able.
static func _history_oldest_to_newest(hist: InputHistory) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var n: int = hist.size()
	# at(age): age 0 is newest. Walk from oldest (age n-1) to newest (age 0).
	for age in range(n - 1, -1, -1):
		out.append(hist.at(age))
	return out


## Resolve the player's active boxes this tick from move data (derived, not stored —
## AD-001). Delegates to the sim's box resolver so the view shows exactly the boxes
## the sim tests for overlap (single source of truth). Empty until move data lands.
static func _resolve_boxes(p: PlayerState, move: MoveState, pushbox: Box) -> Array[BoxView]:
	var out: Array[BoxView] = []
	if move == null:
		return out
	var resolved: Array = MoveData.resolve_boxes(
		move, p.frame_in_state, p.facing, p.pos_x, p.pos_y, pushbox)
	for rb in resolved:
		out.append(BoxView.from_resolved(rb))
	return out
