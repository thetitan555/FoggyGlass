class_name StepPhases
extends RefCounted

## The intra-tick phase pipeline (combat-resolution.md "The fixed intra-tick phase
## order"; AD-009). All static — no state. SimState.step orchestrates these in the
## FIXED order; splitting each phase into a named function keeps step legible and
## makes the order LOAD-BEARING and testable (combat-resolution.md criterion 2:
## reordering phases changes results).
##
## PHASE ORDER (AD-009), every tick:
##   1. Read inputs      — push raw frames to history; SOCD-normalize; raw->fwd/back.
##   2. State machine    — advance frame_in_state; direct button->state transitions
##                         (buffering/cancels stubbed until TKT-P0-08, per the ticket:
##                         direct transitions are enough for the test character).
##   3. Movement          — per-state/keyframe motion + physics; pushbox/stage bounds.
##   4. Overlap detection — resolve active boxes, AABB-test overlaps (strict, F-003).
##   5. Hit resolution    — damage/scaling/combo, reactions, stun, hitstop, pushback,
##                          cancel-tag grant, single-hit id_group, last_hit record.
##   6. Advantage/neutral — recompute advantage; flag neutral restoration.
##   7. Advance counters  — decrement hitstop/stun (frozen under hitstop); tick += 1.
##
## AUTHORED DATA (F-004). The sim resolves each player's Character via
## MoveRegistry.roster() (an immutable roster installed once at wiring, read every
## tick), so step stays a pure function of (state, inputs) GIVEN the fixed content.
##
## No floats reach here (AD-014/019): every quantity is a baked fixed-point integer
## or a plain frame/id/count int. Movement is integer add; overlap is integer compare.


# ---------------------------------------------------------------------------
# Phase 1: Read inputs (combat-resolution.md phase 1; input.md SOCD).
#
# Push the RAW frame into history (raw stays raw end-to-end for replay fidelity,
# AD-003), then compute the SOCD-normalized + facing-resolved intent the state
# machine consumes. History keeps the raw frame; only the derived intent is cleaned.
# ---------------------------------------------------------------------------

## Push both players' raw frames into their histories (recorded every tick,
## including during hitstop — AD-017: phase 1 always runs).
static func phase1_read_inputs(next: SimState, in_p1: int, in_p2: int) -> void:
	next.players[0].input_history.push(in_p1)
	next.players[1].input_history.push(in_p2)


## SOCD normalization (input.md "SOCD normalization"; AD-003). ONE sim-side function,
## applied identically to every source (the source-agnostic architectural commitment).
## Default rule (tunable HERE, in one place):
##   - Left + Right   -> neutral horizontal (both cancel).
##   - Up   + Down    -> Up priority.
## Operates on a raw InputFrame value, returns a cleaned InputFrame value; buttons and
## reserved bits are untouched.
static func socd_normalize(frame: int) -> int:
	var out: int = frame
	# Left+Right cancel to neutral horizontal.
	if (out & InputFrame.LEFT) != 0 and (out & InputFrame.RIGHT) != 0:
		out &= ~(InputFrame.LEFT | InputFrame.RIGHT)
	# Up+Down -> Up priority (drop Down).
	if (out & InputFrame.UP) != 0 and (out & InputFrame.DOWN) != 0:
		out &= ~InputFrame.DOWN
	return out


## Resolve raw Left/Right to FORWARD/BACK using facing (AD-002, sim-side). Returns a
## small intent record { forward, back, up, down, buttons } as plain bools/int so the
## state machine reads direction by MEANING (forward/back), never by physical L/R.
## facing +1 (right): RIGHT == forward, LEFT == back. facing -1 (left): mirror.
static func resolve_intent(raw_frame: int, facing: int) -> Dictionary:
	var frame: int = socd_normalize(raw_frame)
	var left: bool = (frame & InputFrame.LEFT) != 0
	var right: bool = (frame & InputFrame.RIGHT) != 0
	var forward: bool
	var back: bool
	if facing >= 0:
		forward = right
		back = left
	else:
		forward = left
		back = right
	return {
		"forward": forward,
		"back": back,
		"up": (frame & InputFrame.UP) != 0,
		"down": (frame & InputFrame.DOWN) != 0,
		"buttons": frame & InputFrame.BUTTON_MASK,
	}


# ---------------------------------------------------------------------------
# Phase 2: State machine (combat-resolution.md phase 2). Advance frame_in_state;
# apply DIRECT button->state transitions from the character's button_map. Buffering,
# motion recognition, and CancelRule execution are STUBBED until TKT-P0-08 (the
# ticket: "direct button->state transitions are enough for the test character").
#
# A character under hitstop is FROZEN here (AD-010/AD-017): frame_in_state does not
# advance and no transition executes. Inputs are still recorded (phase 1 always ran),
# so a command may buffer during hitstop and execute on the first unfrozen tick —
# but buffered execution is TKT-P0-08; at P0 a frozen character simply takes no
# transition this tick.
# ---------------------------------------------------------------------------

static func phase2_state_machine(next: SimState, intents: Array) -> void:
	for i in range(2):
		var p: PlayerState = next.players[i]
		# Frozen under hitstop: no frame advance, no transition (AD-010).
		if p.hitstop > 0:
			continue
		var character: Character = MoveRegistry.character(p.character_id)
		if character == null:
			# No authored data: nothing to advance (empty-roster backbone case).
			continue
		var move: MoveState = character.get_state(p.state_id)

		# --- Stun-driven state exit ------------------------------------------
		# A player in a stun category returns to idle the moment stun reaches 0 (stun
		# was decremented in phase 7 of the PREVIOUS tick, so stun==0 here means the
		# stun has fully elapsed). This "become actionable after stun" transition runs
		# before new inputs so a just-recovered player can act this same tick. Entering
		# idle here counts as a fresh entry (frame_in_state = 1), so the advance below
		# is skipped for it.
		var entered_this_tick: bool = false
		if move != null and _is_stun_category(move) and p.stun == 0:
			# Returning to actionable/neutral from HITSTUN ends the combo the DEFENDER was
			# in (combat-resolution.md "Combo state resets when the defender returns to
			# actionable/neutral"). Reset here, on the exit tick, so a fresh subsequent hit
			# starts a new combo. (Only meaningful out of hitstun; a blockstun exit had no
			# combo, so the reset is a harmless no-op there.)
			if move.category == MoveState.CATEGORY_HITSTUN:
				p.combo_hits = 0
				p.combo_damage = 0
				p.combo_scaling = FP.ONE
			_enter_state(p, character, character.idle_state_id)
			move = character.get_state(p.state_id)
			entered_this_tick = true

		# --- Advance the frame within the current (already-active) state -----
		# frame_in_state is 1-indexed (keyframes are 1-indexed). A state freshly entered
		# THIS tick is already on frame 1 (_enter_state sets it); a state that was active
		# last tick advances by one. This ordering is why _enter_state sets frame 1
		# directly instead of relying on a post-advance.
		if not entered_this_tick:
			p.frame_in_state = p.frame_in_state + 1 if p.frame_in_state >= 1 else 1
			# A LOOPING state (idle/walk) wraps at its duration so frame_in_state stays
			# within the authored keyframe range (else box resolution stops matching once
			# frame_in_state exceeds the loop length). 1-indexed wrap: frame in [1,duration].
			if move != null and move.loop and move.duration > 0 and p.frame_in_state > move.duration:
				p.frame_in_state = ((p.frame_in_state - 1) % move.duration) + 1
			# A STUN state's exit is driven by `stun` (not frame_in_state), and a stun can
			# outlast the state's authored duration (blockstun/hitstun tuned independently
			# of the reaction animation's keyframe span). Clamp frame_in_state at duration
			# so the defender's hurtbox keeps resolving through the whole stun (the defender
			# stays a valid target for a continuing combo — TKT-P0-09).
			elif move != null and _is_stun_category(move) and move.duration > 0 \
					and p.frame_in_state > move.duration:
				p.frame_in_state = move.duration

		# --- A once-through move that has run its course returns to idle ------
		# When a non-looping, non-stun move passes its duration, the character becomes
		# actionable and returns to the neutral state (idle) for THIS tick so it can
		# accept a new input below. Looping states (idle/walk) never expire.
		move = character.get_state(p.state_id)
		if move != null and not move.loop and not _is_stun_category(move) \
				and p.frame_in_state > move.duration and p.stun == 0:
			_enter_state(p, character, character.idle_state_id)
			move = character.get_state(p.state_id)
			entered_this_tick = true

		# --- Direct input->state transitions (TKT-P0-06 stub for TKT-P0-08) --
		# Only an ACTIONABLE character may start a new move (stun==0, not in committed
		# recovery). A looping/idle actionable character reads its button_map; a
		# committed once-through move ignores new inputs until it ends (handled above).
		if not Actionability.is_actionable(p, move):
			continue
		var intent: Dictionary = intents[i]
		var target_state: int = _match_button_map(character, intent)
		if target_state != -1 and target_state != p.state_id:
			# Start the new move THIS tick, on its frame 1 (a fresh entry).
			_enter_state(p, character, target_state)


## Match the character's button_map against the resolved intent, returning the target
## state_id or -1 if no entry matches. P0: button + optional raw-direction match only
## (motion recognition is TKT-P0-08). required_direction is compared against the RAW
## direction bits via the intent's up/down/forward/back (forward/back already
## facing-resolved; up/down are absolute).
static func _match_button_map(character: Character, intent: Dictionary) -> int:
	for entry in character.button_map:
		if entry.button_index >= 0:
			var bit: int = 1 << (4 + entry.button_index)
			if (int(intent["buttons"]) & bit) == 0:
				continue
		# Motion commands are sim-side recognition (TKT-P0-08); a nonzero motion entry
		# is not matched at P0 (direct transitions only).
		if entry.motion != 0:
			continue
		# Optional required direction (raw). 0 = none. We match DOWN as the common
		# crouch-normal case; other directions extend the same way at TKT-P0-08.
		if entry.required_direction != 0:
			if (entry.required_direction & InputFrame.DOWN) != 0 and not bool(intent["down"]):
				continue
			if (entry.required_direction & InputFrame.UP) != 0 and not bool(intent["up"]):
				continue
		return entry.target_state_id
	return -1


# ---------------------------------------------------------------------------
# Phase 3: Movement integration (combat-resolution.md phase 3; AD-014). Apply per-
# keyframe motion (velocity sets) to velocity, integrate velocity into position
# (integer add), then resolve stage bounds and pushbox collisions. Fixed-point ints
# only. Projectiles integrate here too (AD-021) — none at P0.
# ---------------------------------------------------------------------------

static func phase3_movement(next: SimState) -> void:
	for i in range(2):
		var p: PlayerState = next.players[i]
		# Frozen under hitstop: no movement (AD-010).
		if p.hitstop > 0:
			continue
		var character: Character = MoveRegistry.character(p.character_id)
		var move: MoveState = character.get_state(p.state_id) if character != null else null

		# Per-keyframe motion sets velocity for this frame (authored fixed-point,
		# applied along facing for horizontal). A keyframe with has_motion overrides
		# velocity; otherwise horizontal velocity decays to 0 (grounded, no slide).
		if move != null:
			_apply_keyframe_motion(p, move)

		# Integrate velocity into position (integer add — AD-014).
		p.pos_x = p.pos_x + p.vel_x
		p.pos_y = p.pos_y + p.vel_y

	# Resolve stage bounds and pushbox AFTER both players integrated, so mutual pushout
	# reads both post-move positions (order-independent for a single symmetric pushout).
	_resolve_stage_and_pushboxes(next)


## Apply a keyframe's authored motion for the current frame to the player's velocity.
## has_motion sets an explicit per-tick velocity (fixed-point), applied along facing
## for the horizontal component (forward is +facing). A frame with no motion keyframe
## zeroes horizontal velocity (grounded characters don't slide at P0; gravity/air is
## post-slice). Uses the FIRST covering keyframe with motion (deterministic order).
static func _apply_keyframe_motion(p: PlayerState, move: MoveState) -> void:
	var vx: int = 0
	var vy: int = 0
	var found: bool = false
	for kf in move.timeline:
		if not kf.covers(p.frame_in_state):
			continue
		if kf.has_motion:
			# Horizontal authored motion is FORWARD-relative; apply along facing.
			vx = kf.motion_vel_x * p.facing
			vy = kf.motion_vel_y
			found = true
			break
	if found:
		p.vel_x = vx
		p.vel_y = vy
	else:
		# No authored motion this frame: grounded rest (no horizontal slide at P0).
		p.vel_x = 0
		p.vel_y = 0


## Clamp each player to the stage walls and resolve pushbox overlap (AD-012, integer
## compare). P0: clamp position so the pushbox stays inside [wall_left, wall_right];
## on mutual pushbox overlap, separate the two symmetrically along x. Vertical stays on
## the ground line (no air at P0).
static func _resolve_stage_and_pushboxes(next: SimState) -> void:
	var boxes: Array = []
	for i in range(2):
		boxes.append(_pushbox_world(next.players[i]))

	# Mutual pushbox separation: if the two pushboxes overlap horizontally, push each
	# out by half the overlap along x (deterministic, symmetric).
	if boxes[0] != null and boxes[1] != null:
		var a: ResolvedBox = boxes[0]
		var b: ResolvedBox = boxes[1]
		if a.overlaps(b):
			# Horizontal overlap amount (both are grounded at the same y, so x drives it).
			var a_right: int = a.x + a.w
			var b_right: int = b.x + b.w
			var overlap: int
			var dir: int
			if a.x <= b.x:
				# a is left of b: overlap = a_right - b.x, push a left / b right.
				overlap = a_right - b.x
				dir = 1
			else:
				overlap = b_right - a.x
				dir = -1
			if overlap > 0:
				var half: int = overlap / 2
				var rem: int = overlap - half   # give odd remainder to the second push
				next.players[0].pos_x -= half * dir
				next.players[1].pos_x += rem * dir

	# Stage wall clamp: keep each pushbox inside [wall_left, wall_right].
	for i in range(2):
		var pb: ResolvedBox = _pushbox_world(next.players[i])
		if pb == null:
			continue
		var p: PlayerState = next.players[i]
		if pb.x < next.stage.wall_left:
			p.pos_x += (next.stage.wall_left - pb.x)
		var pb2: ResolvedBox = _pushbox_world(p)
		if pb2.x + pb2.w > next.stage.wall_right:
			p.pos_x -= (pb2.x + pb2.w - next.stage.wall_right)


## Resolve a player's pushbox to a world-space ResolvedBox, or null if the character /
## its pushbox is unknown (no roster / no authored pushbox).
static func _pushbox_world(p: PlayerState) -> ResolvedBox:
	var character: Character = MoveRegistry.character(p.character_id)
	if character == null:
		return null
	var move: MoveState = character.get_state(p.state_id)
	var pushbox: Box = character.pushbox_for(move)
	if pushbox == null:
		return null
	return MoveData.resolve_box(pushbox, BoxView.KIND_PUSH, p.facing, p.pos_x, p.pos_y)


# ---------------------------------------------------------------------------
# Phase 4: Overlap detection (combat-resolution.md phase 4; AD-012). Resolve each
# player's active hit/hurt/throw boxes (derived, AD-001) and AABB-test each attacker
# hitbox against the defender's hurtboxes. Returns a list of confirmed-contact records
# for phase 5. Uses the STRICT overlap convention (F-003, ResolvedBox.overlaps).
# ---------------------------------------------------------------------------

## Detect all hitbox-vs-hurtbox contacts this tick. Returns an Array of contact dicts:
##   { attacker, defender, hitbox: HitBox } — one per (attacker id_group) that touches
## the defender's hurtbox. id_group single-hit is enforced in phase 5, not here (here
## we may report multiple boxes of one group; phase 5 collapses them).
static func phase4_overlap(next: SimState) -> Array:
	var contacts: Array = []
	for attacker in range(2):
		var defender: int = 1 - attacker
		var atk: PlayerState = next.players[attacker]
		var def: PlayerState = next.players[defender]
		var atk_boxes: Array = _resolved_boxes_for(atk)
		var def_boxes: Array = _resolved_boxes_for(def)
		# Collect defender hurtboxes once.
		var hurts: Array = []
		for rb in def_boxes:
			if rb.kind == BoxView.KIND_HURT:
				hurts.append(rb)
		# Test each attacker hitbox against each hurtbox.
		for rb in atk_boxes:
			if rb.kind != BoxView.KIND_HIT and rb.kind != BoxView.KIND_THROW:
				continue
			var connected: bool = false
			for hb in hurts:
				if rb.overlaps(hb):
					connected = true
					break
			if connected:
				contacts.append({
					"attacker": attacker,
					"defender": defender,
					"hitbox": rb.hit,
				})
	return contacts


## Resolve a player's active boxes this tick (derived, AD-001). Delegates to the ONE
## box resolver so the overlap test uses exactly the geometry the inspection surface
## draws (single source of truth). Empty if the character/state is unknown.
static func _resolved_boxes_for(p: PlayerState) -> Array:
	var character: Character = MoveRegistry.character(p.character_id)
	if character == null:
		return []
	var move: MoveState = character.get_state(p.state_id)
	if move == null:
		return []
	var pushbox: Box = character.pushbox_for(move)
	return MoveData.resolve_boxes(move, p.frame_in_state, p.facing, p.pos_x, p.pos_y, pushbox)


# ---------------------------------------------------------------------------
# Phase 5: Hit resolution (combat-resolution.md phase 5; AD-008/010/016). For each
# confirmed contact (respecting id_group single-hit), determine hit vs block, apply
# damage after scaling, set the defender's reaction state + stun, set hitstop on BOTH
# parties, apply pushback, grant the attacker's cancel_tags, update combo, and record
# last_hit. Throwbox connects take the throw path (TKT-P0-09; not at P0 done-bar).
# ---------------------------------------------------------------------------

static func phase5_hit_resolution(next: SimState, contacts: Array) -> void:
	if contacts.is_empty():
		return
	# Single-hit integrity (AD-016, move-format.md criterion 5). Collapse to ONE hit per
	# (attacker, id_group):
	#   - WITHIN this tick: overlapping boxes sharing an id_group register one hit
	#     (`seen`; first occurrence wins — deterministic, phase 4 emits in fixed order).
	#   - ACROSS active frames: an id_group already in the attacker's `active_hit_ids`
	#     (it connected on an earlier frame of THIS move) does not re-hit — so a
	#     multi-frame active window lands ONE hit, not one per active frame. Cadenced
	#     re-hit via rehit_interval is TKT-P0-09; at P0 (unset) it is one hit per move.
	var seen: Dictionary = {}   # key "attacker:id_group" -> true (this tick)
	for c in contacts:
		var hb: HitBox = c["hitbox"]
		if hb == null:
			continue
		# Throws (TKT-P0-09) are not resolved at P0; skip throwbox contacts.
		if hb.is_throw:
			continue
		var attacker: int = int(c["attacker"])
		var key: String = "%d:%d" % [attacker, hb.id_group]
		if seen.has(key):
			continue
		# Already hit this target with this id_group earlier in the move? Skip (single
		# hit per contact — rehit_interval == 0 means never re-hit).
		if hb.rehit_interval == 0 and _has_active_hit_id(next.players[attacker], hb.id_group):
			continue
		seen[key] = true
		_resolve_one_hit(next, attacker, int(c["defender"]), hb)


## Resolve a single confirmed, deduplicated hit.
static func _resolve_one_hit(next: SimState, attacker: int, defender: int, hb: HitBox) -> void:
	var atk: PlayerState = next.players[attacker]
	var def: PlayerState = next.players[defender]
	var character_def: Character = MoveRegistry.character(def.character_id)

	# --- Hit vs block (combat-resolution.md "Hit vs block") ------------------
	# The defender blocks iff holding BACK (raw resolved to back relative to the
	# attacker) in a blockable state. "Blockable" at P0 = the defender is actionable
	# or already in blockstun (a grounded, non-stunned defender may block). A defender
	# already in hitstun cannot block (combo).
	var blocking: bool = _defender_is_blocking(def, attacker, next)

	var reaction_state: int
	var stun_frames: int
	var stun_kind: int
	if blocking:
		reaction_state = hb.block_reaction
		stun_frames = hb.blockstun
		stun_kind = PlayerView.STUN_BLOCK
	else:
		reaction_state = hb.hit_reaction
		stun_frames = hb.hitstun
		stun_kind = PlayerView.STUN_HIT

	# --- Combo accounting + damage scaling (combat-resolution.md) ------------
	# On a fresh hit (defender not already in a hitstun-chained state) the combo
	# starts; a continuing hit increments. Scaling applies BEFORE damage subtract.
	var is_continuing: bool = (not blocking) and def.stun_kind == PlayerView.STUN_HIT and def.stun > 0
	if not blocking:
		if is_continuing:
			def.combo_hits += 1
		else:
			def.combo_hits = 1
			def.combo_damage = 0
			def.combo_scaling = FP.ONE
	# Scaling is single-sourced through DamageScaling; blocked hits deal chip-free 0 at
	# P0 (no chip in the slice), so damage is only applied on hit.
	var applied_damage: int = 0
	var scaling_pct: int = 100
	if not blocking:
		def.combo_scaling = DamageScaling.scaling_for_hit_count(def.combo_hits)
		scaling_pct = FP.round_to_int(FP.mul(def.combo_scaling, FP.from_int(100)))
		applied_damage = FP.round_to_int(FP.mul(FP.from_int(hb.damage), def.combo_scaling))
		def.health -= applied_damage
		def.combo_damage += applied_damage

	# --- Reaction state + stun ----------------------------------------------
	if character_def != null and reaction_state != 0:
		_enter_state(def, character_def, reaction_state)
	def.stun = stun_frames
	def.stun_kind = stun_kind

	# --- Hitstop on BOTH parties (AD-010) -----------------------------------
	atk.hitstop = hb.hitstop
	def.hitstop = hb.hitstop

	# --- Pushback (fixed-point, along the axis from attacker to defender) ----
	var push: int = hb.pushback_block if blocking else hb.pushback_hit
	# Defender is pushed AWAY from the attacker: sign is from attacker toward defender.
	var away: int = 1 if def.pos_x >= atk.pos_x else -1
	def.pos_x += push * away
	# Launch (vertical) — 0 at P0 test character.
	if hb.launch != 0 and not blocking:
		def.vel_y = hb.launch

	# --- Cancel-tag grant (AD-017: granted phase 5 tick T, usable T+1) -------
	# The attacker records the granted tags; consumption (T+1) is TKT-P0-08. At P0 we
	# store them so the grant->consume latency is structurally present.
	if hb.cancel_tags.size() > 0:
		# P0: no cancel execution, so tags are recorded transiently via combo state.
		# (No serialized cancel-tag field until TKT-P0-08; a no-op store keeps P0 clean.)
		pass

	# --- Mark this id_group as connected for the attacker's current move -----
	# (single-hit across active frames — F-005). A rehit_interval hitbox would instead
	# schedule a re-hit after the interval (TKT-P0-09); at P0 the id simply stays marked.
	if not _has_active_hit_id(atk, hb.id_group):
		atk.active_hit_ids.append(hb.id_group)

	# --- Record last_hit (F-002; inspection surface) ------------------------
	var rec := HitRecord.new()
	rec.attacker = attacker
	rec.defender = defender
	rec.damage_dealt = applied_damage
	rec.was_block = blocking
	rec.scaling_applied_pct = scaling_pct
	rec.combo_count_after = def.combo_hits if not blocking else 0
	# The hit is observable on the frame this step PRODUCES. Phase 7 sets the final tick
	# to next.tick + 1, so record that value now — HitEvent.tick then equals the tick of
	# the state in which last_hit is first readable (deterministic, phase-order-stable).
	rec.tick = next.tick + 1
	next.last_hit = rec


## Whether the defender is blocking the incoming hit: holding BACK (raw resolved to
## back vs the attacker) in a blockable state. P0: a grounded, non-hitstun defender who
## holds back blocks; a defender already in hitstun cannot block. Reads the defender's
## CURRENT raw input frame (this tick) resolved by the defender's facing.
static func _defender_is_blocking(def: PlayerState, attacker: int, next: SimState) -> bool:
	# Cannot block while in hitstun (already being combo'd).
	if def.stun_kind == PlayerView.STUN_HIT and def.stun > 0:
		return false
	var raw: int = def.input_history.newest()
	var intent: Dictionary = resolve_intent(raw, def.facing)
	# "Back" relative to the defender's facing is the blocking direction. Because the
	# defender faces the attacker (P0 characters always face each other), holding back
	# = away from the attacker = the block direction.
	return bool(intent["back"])


# ---------------------------------------------------------------------------
# Phase 6: Advantage / neutral update (combat-resolution.md phase 6; AD-008).
# Recompute nothing STORED for advantage (it is derived live by Advantage.live from
# state each time it is read — single source), but flag NEUTRAL RESTORATION: set
# neutral_restored_this_tick TRUE exactly on the tick BOTH players transition to
# actionable (criterion 5: not before, not after).
#
# "Both actionable THIS tick" is computed against the post-phase-5 state but BEFORE
# phase 7 decrements counters, so the flag reflects the situation the inspection
# surface reads for this tick. The edge (transition) is detected by comparing to the
# PREVIOUS tick's both-actionable condition, carried via the flag's own history.
# ---------------------------------------------------------------------------

static func phase6_advantage_neutral(next: SimState, prev_both_actionable: bool) -> void:
	var both_now: bool = _both_actionable(next)
	# Neutral is "restored" on the tick both BECOME actionable: both actionable now AND
	# not both actionable on the previous tick (the rising edge).
	next.neutral_restored_this_tick = both_now and not prev_both_actionable


## Both players actionable in the CURRENT (post-phase-5, pre-phase-7) state.
static func _both_actionable(next: SimState) -> bool:
	return _actionable(next, 0) and _actionable(next, 1)


static func _actionable(next: SimState, i: int) -> bool:
	var p: PlayerState = next.players[i]
	var character: Character = MoveRegistry.character(p.character_id)
	var move: MoveState = character.get_state(p.state_id) if character != null else null
	return Actionability.is_actionable(p, move)


# ---------------------------------------------------------------------------
# Phase 7: Advance counters (combat-resolution.md phase 7; AD-010). Decrement
# hitstop and stun, then advance the tick. Counters under ACTIVE hitstop do NOT
# decrement the frozen quantities (frame_in_state/stun): while hitstop > 0 the action
# is frozen, and hitstop itself counts down; stun resumes counting only once hitstop
# reaches 0. This is what makes frame-step cross hitstop one tick at a time (AD-010).
#
# HITSTOP SET THIS TICK IS NOT DECREMENTED THIS TICK. `was_frozen` records each
# player's hitstop>0 state at the START of the tick (captured in step, before phase 5
# could set it). A player who FIRST receives hitstop in phase 5 this tick is not
# decremented in phase 7 — otherwise the freeze would last (hitstop - 1) ticks. So a
# hit setting hitstop = N freezes the character for exactly N following ticks (AD-010:
# "hold constant for exactly `hitstop` ticks").
# ---------------------------------------------------------------------------

static func phase7_advance_counters(next: SimState, was_frozen: Array) -> void:
	for i in range(2):
		var p: PlayerState = next.players[i]
		if p.hitstop > 0:
			# Only decrement hitstop that was already active at tick start; a hitstop
			# just set this tick begins its countdown next tick. While frozen, stun /
			# frame_in_state hold (AD-010; phases 2/3 already skipped the frozen player).
			if bool(was_frozen[i]):
				p.hitstop -= 1
		else:
			if p.stun > 0:
				p.stun -= 1
				if p.stun == 0:
					# Stun elapsed: the stun_kind clears here; the return-to-idle
					# transition happens in phase 2 of the NEXT tick (so the defender
					# becomes actionable and can act on the frame stun hits 0 + 1).
					p.stun_kind = PlayerView.STUN_NONE
	next.tick = next.tick + 1


# ---------------------------------------------------------------------------
# Shared helpers.
# ---------------------------------------------------------------------------

## Enter a state cleanly: set state_id and put the character ON FRAME 1 of the new
## state immediately (a fresh entry IS on frame 1 this tick; phase 2 skips its advance
## for a state entered this tick). Zeroes horizontal velocity on entry (a new move sets
## its own keyframe motion in phase 3). Clears active_hit_ids: a NEW move is a new
## "contact," so its hitboxes may connect again (single-hit is per-move — F-005).
static func _enter_state(p: PlayerState, character: Character, state_id: int) -> void:
	p.state_id = state_id
	p.frame_in_state = 1
	p.vel_x = 0
	p.active_hit_ids = PackedInt32Array()


## True iff the player has already connected `id_group` during its current move.
static func _has_active_hit_id(p: PlayerState, id_group: int) -> bool:
	for gid in p.active_hit_ids:
		if gid == id_group:
			return true
	return false


## True iff the move's category is a stun category (hitstun/blockstun).
static func _is_stun_category(move: MoveState) -> bool:
	return move.category == MoveState.CATEGORY_HITSTUN \
		or move.category == MoveState.CATEGORY_BLOCKSTUN
