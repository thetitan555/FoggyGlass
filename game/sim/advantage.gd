class_name Advantage
extends RefCounted

## The ONE advantage computation (combat-resolution.md → "Advantage"; AD-008). One
## formula, two surfaced values — a static pinned move property and a live
## cancel-aware readout. All static functions; no state. Single-sourced: the
## inspection surface's advantage()/frame_data() read THESE, never a
## re-implementation (inspection-surface.md criterion 3).
##
## THE FORMULA (AD-008):
##   advantage = defender_remaining_stun - attacker_remaining_recovery
## where attacker_remaining_recovery is the attacker's ACTUAL frames-to-actionable
## in the situation — including any committed cancel (cancels land TKT-P0-08; at P0
## there are none, so it is the raw frames-to-actionable).
##
## Positive => attacker actionable first (plus). Negative => defender first (punish).


# ---------------------------------------------------------------------------
# Static advantage (AD-008 pinned reference): contact on the move's FIRST ACTIVE
# frame, attacker UNCANCELLED. A property of the move in isolation — what a
# frame-data display reads. Computed purely from the move's own timeline + the
# hit's stun values, so it needs no live SimState.
#
# At the pinned reference the attacker connects on the first active frame; its
# remaining recovery from that contact is (recovery + (active - 1)) — i.e. the rest
# of the active window after first contact, plus the move's recovery. The defender's
# remaining stun is the hit's hitstun (on hit) or blockstun (on block). Both parties
# share the same hitstop on contact, so hitstop cancels out of the difference and is
# omitted (it delays both equally — AD-010).
#
#   on_hit_adv   = hitstun   - (recovery + active - 1)
#   on_block_adv = blockstun - (recovery + active - 1)
# ---------------------------------------------------------------------------

## Fill a FrameData's static on_hit_adv / on_block_adv from its move's timeline and
## the move's first active hitbox. Called by MoveData.frame_data so the static
## advantage lives in the ONE advantage file. A move with no hitbox leaves both 0.
static func fill_static(fd: FrameData, move: MoveState) -> void:
	var first_hit: HitBox = _first_active_hitbox(move)
	if first_hit == null:
		fd.on_hit_adv = 0
		fd.on_block_adv = 0
		return
	# Attacker frames-to-actionable from FIRST-ACTIVE contact, uncancelled:
	# the remaining active frames after the first (active - 1) plus recovery.
	var attacker_recovery: int = fd.recovery + (fd.active - 1)
	fd.on_hit_adv = first_hit.hitstun - attacker_recovery
	fd.on_block_adv = first_hit.blockstun - attacker_recovery


## The first active hitbox in timeline order (the one the pinned static reference
## uses). Null if the move has no hitboxes.
static func _first_active_hitbox(move: MoveState) -> HitBox:
	var best_frame: int = 0
	var best: HitBox = null
	for kf in move.timeline:
		if kf.hitboxes.is_empty():
			continue
		if best == null or kf.frame_start < best_frame:
			best_frame = kf.frame_start
			best = kf.hitboxes[0]
	return best


# ---------------------------------------------------------------------------
# Live advantage (AD-008): the same formula on the REAL situation. The defender is
# the player currently in stun; the attacker is the other. attacker_remaining_
# recovery is the attacker's actual frames-to-actionable now (Actionability), so it
# reflects late contact and (once cancels land, TKT-P0-08) any committed cancel.
#
# PARTY IDENTIFICATION (JC-012): the live value reads the parties FROM STATE — the
# player with stun > 0 is the defender, the other the attacker. When neither is in
# stun there is no live interaction to be plus/minus on, so the value is 0, no
# plus_player, and neutral (both actionable => neutral_restored true this tick).
# ---------------------------------------------------------------------------

## Live advantage for the current SimState. `roster` maps character_id -> Character
## so each player's MoveState can be resolved for frames-to-actionable; if a player's
## move is unknown the actionability read falls back to stun/hitstop only (safe).
static func live(state: SimState, roster: Dictionary = {}) -> AdvantageView:
	var p0: PlayerState = state.players[0]
	var p1: PlayerState = state.players[1]
	var m0: MoveState = _move_for(p0, roster)
	var m1: MoveState = _move_for(p1, roster)

	var a0: bool = Actionability.is_actionable(p0, m0)
	var a1: bool = Actionability.is_actionable(p1, m1)

	# Identify defender (in stun) and attacker (the other).
	var defender: int = -1
	if p0.stun > 0 and p1.stun > 0:
		# Both stunned (e.g. a trade): pick the one with MORE remaining stun as the
		# defender of the current advantage read (the later-recovering party). This is
		# a deterministic tiebreak; true trades are rare in the P0 slice.
		defender = 0 if p0.stun >= p1.stun else 1
	elif p0.stun > 0:
		defender = 0
	elif p1.stun > 0:
		defender = 1

	var value: int = 0
	var plus_player: int = AdvantageView.PLUS_NONE
	if defender != -1:
		var attacker: int = 1 - defender
		var def_p: PlayerState = state.players[defender]
		var atk_p: PlayerState = state.players[attacker]
		var def_stun: int = Actionability.frames_to_actionable(def_p, _move_for(def_p, roster))
		var atk_rec: int = Actionability.frames_to_actionable(atk_p, _move_for(atk_p, roster))
		# advantage is expressed from the ATTACKER's point of view (positive = attacker
		# plus). value = defender_remaining_stun - attacker_remaining_recovery.
		value = def_stun - atk_rec
		if value > 0:
			plus_player = attacker
		elif value < 0:
			plus_player = defender

	# frames_to_neutral: max of each player's frames-to-actionable.
	var f0: int = Actionability.frames_to_actionable(p0, m0)
	var f1: int = Actionability.frames_to_actionable(p1, m1)
	var frames_to_neutral: int = f0 if f0 > f1 else f1

	# neutral_restored is flagged by the sim on the exact tick both become actionable
	# (combat-resolution.md criterion 5). The sim owns that edge (a per-tick flag in
	# state); here we report the current both-actionable condition, which the sim's
	# phase-6 neutral update sets precisely on the transition tick. For the live view
	# we surface both-actionable AND the sim's recorded transition flag.
	var both_actionable: bool = a0 and a1
	var neutral_restored: bool = both_actionable and state.neutral_restored_this_tick

	return AdvantageView.make(value, plus_player, frames_to_neutral, neutral_restored)


static func _move_for(p: PlayerState, roster: Dictionary) -> MoveState:
	if roster.has(p.character_id):
		var c: Character = roster[p.character_id]
		return c.get_state(p.state_id)
	return null
