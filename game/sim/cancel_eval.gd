class_name CancelEval
extends RefCounted

## CancelRule evaluation (move-format.md → CancelRule; combat-resolution.md phase 2;
## AD-015/017/022). All static — no state. Given a player's current move and state,
## finds the first legal cancel whose INPUT is buffered, and returns its target state
## (or -1 for none). Phase 2 applies the transition.
##
## A cancel is legal on this tick iff ALL of:
##   - condition holds against the attacker's move_contact (on_hit/on_block/on_contact/
##     on_whiff/always) — the outcome of the current move (PlayerState.move_contact).
##   - frame_in_state is within the rule's window (default: first-active → end).
##   - requires_tag (if set) is present in the player's granted cancel_tags (AD-017:
##     a tag granted phase 5 of tick T is visible here starting T+1, since phase 2
##     precedes phase 5 — the grant→consume latency falls out of the phase order).
##   - the rule's `input` command is buffered within its window (InputBuffer).
##
## HITSTOP (AD-017). A character under hitstop is FROZEN in phase 2: the caller does
## not evaluate cancels while hitstop > 0. Inputs are still recorded (phase 1 always
## runs), so a command buffers during hitstop and this evaluation fires on the first
## unfrozen tick — the buffer window (InputBuffer.COMMAND_BUFFER) carries it across.
##
## Move classes are EXPRESSED, not special-cased (AD-015): gatling = on_contact within
## a window; special-cancel = requires_tag granted by the hit; whiff-cancel = on_whiff.
## Rehit/multi-hit is NOT a cancel (that is HitBox.rehit_interval, TKT-P0-09).


## The target state_id of the first legal, input-buffered cancel for this player, or -1
## if none. `move` is the player's current MoveState; `character` its owner (to map the
## cancel's `input` command through the button_map, so a cancel's input is recognized by
## the same buffering the neutral state uses). Rules are evaluated in authored order
## (deterministic); the first satisfied one wins.
static func find_cancel(p: PlayerState, move: MoveState, character: Character) -> int:
	if move == null or move.cancels.is_empty():
		return -1
	for rule in move.cancels:
		if not _condition_holds(rule, p):
			continue
		if not _in_window(rule, move, p.frame_in_state):
			continue
		if rule.requires_tag != 0 and not _has_tag(p, rule.requires_tag):
			continue
		if not _input_buffered(rule, p, character):
			continue
		# A group target (target_is_group) names a SET of states; at P0 we resolve a
		# group to nothing actionable (no groups authored in the slice) — treat a plain
		# state target only. A concrete state target transitions directly.
		if rule.target_is_group:
			continue
		if rule.target == p.state_id:
			continue
		return rule.target
	return -1


## The cancel's condition vs the attacker's current-move contact outcome (AD-015).
static func _condition_holds(rule: CancelRule, p: PlayerState) -> bool:
	var contact: int = p.move_contact
	match rule.condition:
		CancelRule.CONDITION_ALWAYS:
			return true
		CancelRule.CONDITION_ON_HIT:
			return contact == PlayerState.CONTACT_HIT
		CancelRule.CONDITION_ON_BLOCK:
			return contact == PlayerState.CONTACT_BLOCK
		CancelRule.CONDITION_ON_CONTACT:
			return contact == PlayerState.CONTACT_HIT or contact == PlayerState.CONTACT_BLOCK
		CancelRule.CONDITION_ON_WHIFF:
			return contact == PlayerState.CONTACT_WHIFF
	return false


## Whether frame_in_state is inside the rule's window. Default (both 0) = first-active
## frame → end of the move (move-format.md: "default first-active→end"). An explicit
## window uses [window_start, window_end] inclusive.
static func _in_window(rule: CancelRule, move: MoveState, frame: int) -> bool:
	var start: int = rule.window_start
	var end: int = rule.window_end
	if start == 0 and end == 0:
		start = _first_active_frame(move)
		if start == 0:
			# A move with no hitbox has no "first active"; default the window to the
			# whole move so an `always`/`on_whiff` cancel on a non-attacking state works.
			start = 1
		end = move.duration
	return frame >= start and frame <= end


## First frame any hitbox is active (mirrors MoveData; local to avoid a cross-dep on
## MoveData's private helper). 0 if the move has no hitboxes.
static func _first_active_frame(move: MoveState) -> int:
	var first: int = 0
	for kf in move.timeline:
		if kf.hitboxes.is_empty():
			continue
		if first == 0 or kf.frame_start < first:
			first = kf.frame_start
	return first


## True iff the granted cancel tag is present in the player's cancel_tags (AD-017).
static func _has_tag(p: PlayerState, tag: int) -> bool:
	for t in p.cancel_tags:
		if t == tag:
			return true
	return false


## Whether the rule's `input` command is buffered. The cancel's `input` is a command id
## that must match a button_map entry (so the same recognizer resolves it); we find the
## button_map entry whose target is the rule's target and check its command is buffered.
## If no matching entry exists, fall back to treating `input` as a raw button index so a
## cancel can name a bare button without a button_map round-trip. Deterministic.
static func _input_buffered(rule: CancelRule, p: PlayerState, character: Character) -> bool:
	if character != null:
		for entry in character.button_map:
			if entry.target_state_id == rule.target:
				return InputBuffer.entry_satisfied(p.input_history, entry, p.facing)
	# Fallback: `input` names a raw button bit index (0..7); check the command buffer.
	if rule.input >= InputFrame.BUTTON_0:
		# `input` carried as a raw bitmask -> derive the index.
		for idx in range(8):
			if rule.input == (1 << (4 + idx)):
				return InputBuffer.button_buffered(p.input_history, idx, 0, p.facing)
	return false
