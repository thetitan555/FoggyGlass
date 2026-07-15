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
# Phase 2: State machine + buffering + cancels (combat-resolution.md phase 2;
# AD-015/017/022). Advance frame_in_state; run the input buffer / motion & command
# recognition over input_history (InputBuffer, a PURE function of history — AD-003);
# apply legal transitions and CancelRules (CancelEval) per condition/window/requires_tag.
#
# A character under hitstop is FROZEN here (AD-010/AD-017): frame_in_state does not
# advance and NO transition or cancel executes. Inputs are still recorded (phase 1
# always ran), so a command BUFFERS during hitstop and executes on the first unfrozen
# tick — the buffer window (InputBuffer.COMMAND_BUFFER = 6) carries it across the freeze.
#
# TRANSITION PRIORITY, each tick (all buffered, deterministic):
#   1. Frozen under hitstop -> nothing (buffered command waits).
#   2. Stun expiry -> return to idle (become actionable).
#   3. Advance frame; mark a whiffed attack (last active frame passed, no connect).
#   4. Once-through move ended -> return to idle.
#   5. If ACTIONABLE (idle/looping or just-recovered): execute the first BUFFERED
#      button_map command. This is the reversal-on-wakeup / after-blockstun / after-
#      hitstop path (a 623 held through blockstun comes out frame-1) AND the ordinary
#      "press a button in neutral" path — unified: an actionable character runs a
#      buffered command (AD-022). If the CURRENT state is a LOOPING state (idle/walk/
#      crouch — MoveState.loop), the branch is TWO-TIER (AD-038, corrected 2026-07-10):
#      (a) a DISCRETE command (recognized command whose TARGET state is not `loop`) that
#      is buffered-ready via the AD-022 command buffer takes priority — unchanged
#      reversal/cancel-entry leniency, and it leaves the loop state on entry so it never
#      lingers; (b) otherwise the STANCE target is RE-DERIVED from the CURRENT TICK's
#      input alone (no command-buffer carry-over) — a `loop`-target command if satisfied
#      THIS tick, else character.idle_state_id — so a released direction returns to idle
#      on the very next actionable tick (prompt release, no ~COMMAND_BUFFER-tick lag). A
#      non-loop actionable state keeps the plain "run a buffered command, else stay"
#      behavior.
#   6. Else (committed move, not frozen): evaluate CancelRules; a legal cancel whose
#      input is buffered and whose window is open executes (special-cancel / gatling /
#      whiff-cancel — AD-015). Cancels buffer during hitstop but execute only here,
#      unfrozen (AD-017).
# ---------------------------------------------------------------------------

static func phase2_state_machine(next: SimState) -> void:
	for i in range(2):
		var p: PlayerState = next.players[i]
		# Frozen under hitstop: no frame advance, no transition/cancel (AD-010/AD-017).
		# A command still buffers (phase 1 recorded it); it fires on the first unfrozen
		# tick because InputBuffer reads the last COMMAND_BUFFER frames of history.
		if p.hitstop > 0:
			continue
		var character: Character = MoveRegistry.character(p.character_id)
		if character == null:
			# No authored data: nothing to advance (empty-roster backbone case).
			continue
		var move: MoveState = character.get_state(p.state_id)

		# --- Throw tech (AD-016) ---------------------------------------------
		# A thrown defender with an open tech window who inputs a throw TECHS it: both
		# players return to neutral, no damage. Checked before the ordinary advance so
		# the tech pre-empts the throw reaction. Runs only while the window is open.
		if p.throw_tech_window > 0 and p.thrown_by >= 0:
			if _try_throw_tech(next, i, character):
				continue

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
			_enter_state(next, p, character, character.idle_state_id)
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

		# --- Mark a whiffed attack (for on_whiff cancels, AD-015) ------------
		# If an attacking move passes its last active frame with no connect recorded
		# (move_contact still NONE), it has whiffed — set the contact so an on_whiff
		# cancel can fire in the recovery window. Only meaningful for a move with
		# hitboxes that hasn't hit or been blocked.
		if move != null and p.move_contact == PlayerState.CONTACT_NONE:
			var last_active: int = _last_active_frame_local(move)
			if last_active > 0 and p.frame_in_state > last_active:
				p.move_contact = PlayerState.CONTACT_WHIFF

		# --- A once-through move that has run its course returns to idle ------
		# When a non-looping, non-stun move passes its duration, the character becomes
		# actionable and returns to the neutral state (idle) for THIS tick so it can
		# accept a new input below. Looping states (idle/walk) never expire.
		move = character.get_state(p.state_id)
		if move != null and not move.loop and not _is_stun_category(move) \
				and p.frame_in_state > move.duration and p.stun == 0:
			_enter_state(next, p, character, character.idle_state_id)
			move = character.get_state(p.state_id)
			entered_this_tick = true

		# --- Buffered command on the first actionable frame (AD-022) ---------
		# An ACTIONABLE character (idle/looping, or just recovered) executes the first
		# BUFFERED button_map command. This is BOTH the ordinary "press a button in
		# neutral" transition AND the reversal-on-wakeup: a command pressed up to
		# COMMAND_BUFFER frames early (e.g. a 623 held through blockstun) fires on this
		# first actionable frame as a frame-1 reversal (AD-022). A LOOPING current state
		# (idle/walk/crouch) is TWO-TIER instead (AD-038, corrected 2026-07-10): a
		# discrete buffered-ready command still takes full AD-022 priority; otherwise the
		# stance is re-derived from CURRENT-TICK input only (see _buffered_discrete_command
		# / _current_tick_loop_command below).
		if Actionability.is_actionable(p, move):
			if move != null and move.loop:
				var discrete_target: int = _buffered_discrete_command(character, p)
				if discrete_target != -1:
					if discrete_target != p.state_id:
						_enter_state(next, p, character, discrete_target)
					continue
				var stance_target: int = _current_tick_loop_command(character, p)
				if stance_target == -1:
					stance_target = character.idle_state_id
				if stance_target != p.state_id:
					_enter_state(next, p, character, stance_target)
				continue
			var target_state: int = _buffered_command(character, p)
			if target_state != -1 and target_state != p.state_id:
				_enter_state(next, p, character, target_state)
			continue

		# --- Cancels in a committed move (AD-015/017) ------------------------
		# A committed (not actionable) but UNFROZEN move may cancel: a legal CancelRule
		# whose input is buffered and window is open executes (special-cancel, gatling,
		# whiff-cancel). Cancels never execute during hitstop (handled by the freeze
		# guard at the top) — they buffer and fire here on the first unfrozen tick.
		var cancel_target: int = CancelEval.find_cancel(p, move, character)
		if cancel_target != -1:
			_enter_state(next, p, character, cancel_target)


## The target state of the first BUFFERED button_map command, or -1 if none. Reads each
## button_map entry through the ONE buffering recognizer (InputBuffer.entry_satisfied),
## so a motion (recognized within the 9-frame window) or a button (within the 6-frame
## command buffer) both trigger — this is what makes buffered/reversal inputs work,
## replacing the TKT-P0-06 direct this-frame-only match. Entries are evaluated in
## authored order (deterministic); the first satisfied wins.
static func _buffered_command(character: Character, p: PlayerState) -> int:
	for entry in character.button_map:
		if InputBuffer.entry_satisfied(p.input_history, entry, p.facing):
			return entry.target_state_id
	return -1


## Tier 1 of the loop-state branch (AD-038, corrected 2026-07-10): the target state of
## the first BUFFERED button_map command whose TARGET is a DISCRETE (non-`loop`) state,
## or -1 if none. A discrete command keeps FULL AD-022 leniency (a special/normal/throw/
## prejump pressed slightly early still fires the moment it is legal) — this is what
## keeps reversal/cancel-entry behavior intact for a character currently standing in a
## looping state (idle/walk/crouch). Authored order, first satisfied wins (AD-032).
## `target.loop` defaults false for an unresolvable state, so it is treated as discrete
## (matches the prior, single-tier behavior for any state the roster can't resolve).
static func _buffered_discrete_command(character: Character, p: PlayerState) -> int:
	for entry in character.button_map:
		if not InputBuffer.entry_satisfied(p.input_history, entry, p.facing):
			continue
		var target: MoveState = character.get_state(entry.target_state_id)
		if target != null and target.loop:
			continue   # a loop-target command is tier 2's job, not this discrete tier.
		return entry.target_state_id
	return -1


## Tier 2 of the loop-state branch (AD-038, corrected 2026-07-10): the target state of
## the first button_map command whose TARGET is a LOOP state (walk/crouch/…) satisfied
## by the CURRENT TICK's input ALONE — no COMMAND_BUFFER carry-over (InputBuffer.
## entry_satisfied_now). Returns -1 if no loop-target command is satisfied this tick
## (the caller falls back to character.idle_state_id). This is the "released direction
## exits promptly" half of the correction: a stance is never held alive by the buffer
## window once its direction is no longer held. Authored order, first satisfied wins.
static func _current_tick_loop_command(character: Character, p: PlayerState) -> int:
	for entry in character.button_map:
		var target: MoveState = character.get_state(entry.target_state_id)
		if target == null or not target.loop:
			continue   # a discrete-target command is tier 1's job, not this stance tier.
		if InputBuffer.entry_satisfied_now(p.input_history, entry, p.facing):
			return entry.target_state_id
	return -1


## Last frame any hitbox is active in this move (1-indexed), or 0 if none. Local mirror
## of MoveData's derivation for the whiff-edge check (avoids a cross-call for one int).
static func _last_active_frame_local(move: MoveState) -> int:
	var last: int = 0
	for kf in move.timeline:
		if kf.hitboxes.is_empty():
			continue
		if kf.frame_end > last:
			last = kf.frame_end
	return last


# ---------------------------------------------------------------------------
# Phase 3: Movement integration (combat-resolution.md phase 3; AD-014/AD-043). Apply
# per-keyframe motion (velocity sets/impulses) to velocity, apply GRAVITY to a
# physically-airborne character, integrate velocity into position (integer add), then
# apply the CONTINUOUS ground clamp fused with landing, then resolve stage bounds and
# pushbox collisions. Fixed-point ints only. Projectiles integrate here too (AD-021,
# each applying its own optional gravity, AD-047 — not this ticket), and any `spawn`
# actions firing this tick are processed here (TKT-P1-0P), subject to the owner's
# live cap.
# ---------------------------------------------------------------------------

static func phase3_movement(next: SimState) -> void:
	# Projectiles PRE-EXISTING at the start of this phase (before any spawn below
	# can append new ones) integrate this tick; a projectile spawned THIS tick
	# starts exactly at its authored spawn position and does not ALSO take an
	# integration step the same tick (mirrors the "a freshly spawned/frozen thing
	# does not immediately age/move again this tick" convention already used for
	# hitstop and lifetime — TKT-P1-0P).
	var pre_spawn_count: int = next.projectiles.size()
	var ground_y: int = next.stage.ground_y

	for i in range(2):
		var p: PlayerState = next.players[i]
		# Frozen under hitstop: no movement (AD-010).
		if p.hitstop > 0:
			continue
		var character: Character = MoveRegistry.character(p.character_id)
		var move: MoveState = character.get_state(p.state_id) if character != null else null

		# Per-keyframe motion sets velocity for this frame (authored fixed-point,
		# applied along facing for horizontal). A keyframe with has_motion SETS
		# velocity (an impulse — takeoff, air dash, double jump, a divekick's dive);
		# otherwise a GROUNDED state decays to 0 (no slide/vertical), while any other
		# category INHERITS the ongoing velocity (AD-043 — an air normal / a launched
		# reaction carries the fall instead of stopping it).
		if move != null:
			_apply_keyframe_motion(p, move)

		# --- Airborne physics (AD-043): gravity, gated by GENUINE physical airborne-
		# ness, not by category alone. A standing HITSTUN/BLOCKSTUN reaction (category
		# HITSTUN/BLOCKSTUN, vel_y == 0, pos_y == ground_y already) must NOT accrete
		# gravity every tick just because its category isn't GROUNDED — only a
		# character actually off the ground (pos_y < ground_y) or carrying nonzero
		# vertical velocity this tick (a freshly set takeoff/launch impulse, still at
		# ground_y before integration) is "airborne" here. This is exactly what
		# distinguishes a "launched (airborne HITSTUN)" reaction (AD-043) from an
		# ordinary standing one sharing the same engine-level category.
		var grounded_category: bool = move == null or move.category == MoveState.CATEGORY_GROUNDED
		var was_airborne: bool = not grounded_category and (p.pos_y < ground_y or p.vel_y != 0)

		# --- Air-action commands (AD-046, TKT-P2-02): air dash / double jump --------
		# Runs BEFORE gravity is added this tick so a fired air action's impulse takes
		# the SAME "gravity accrues the same tick as the impulse" contract the takeoff
		# keyframe already uses (character_a.gd's jump-arc note). Only considered for a
		# GENUINELY physically airborne player (was_airborne, the same gate gravity
		# uses just below) with its one air action unspent.
		if character != null and was_airborne:
			_apply_air_action(p, character)

		if character != null and was_airborne:
			p.vel_y += character.physics.gravity

		# Integrate velocity into position (integer add — AD-014).
		p.pos_x = p.pos_x + p.vel_x
		p.pos_y = p.pos_y + p.vel_y

		# --- Continuous ground clamp fused with landing (AD-043) --- After
		# integration, a character that WAS physically airborne this tick and has now
		# reached/passed the floor lands: clamped position, velocity zeroed, one
		# mechanism (never leaves a character nominally airborne at the floor).
		if character != null and was_airborne and p.pos_y >= ground_y:
			_land(next, p, character, move)

		# Process any spawn action firing this tick (AD-021; move-format.md
		# Keyframe.spawn), subject to the owner's live-projectile cap.
		if move != null:
			_process_spawn(next, i, p, move)

	# Resolve stage bounds and pushbox AFTER both players integrated, so mutual pushout
	# reads both post-move positions (order-independent for a single symmetric pushout).
	_resolve_stage_and_pushboxes(next)

	# Integrate every PRE-EXISTING live projectile's own position independently of
	# its owner (AD-021: "integrates each tick independently of the owner"). Order
	# is fixed (list order) so integration is deterministic. New spawns are always
	# APPENDED, so index < pre_spawn_count is exactly "existed before this tick."
	for idx in range(pre_spawn_count):
		var pr: Projectile = next.projectiles[idx]
		pr.pos_x += pr.vel_x
		pr.pos_y += pr.vel_y


## Air-action commands (AD-046, TKT-P2-02): consumes a player's ONE air action per
## jump (`players[i].air_action_used`) on either a DOUBLE JUMP (a FRESH up-press) or
## an AIR DASH (double-tap forward/back), whichever is recognized first. Both read
## the ONE recognizer (InputBuffer) over `input_history` — pure functions of history,
## no new input path (Tenet 2). No-op once `air_action_used` is already true (the
## suppression AD-046 requires until the landing transition resets it, `_land` above).
##
## DOUBLE JUMP uses `direction_pressed_edge`, not the leniently-buffered
## `direction_buffered`: a player holding UP continuously from the INITIAL jump
## takeoff must press UP AGAIN once airborne — a level check would instantly spend
## the air action the moment `was_airborne` becomes true, since UP is already (and
## typically still) held from the jump input itself. AIR DASH reuses the SAME
## double-tap recognizer AD-046 gives character A's ground dash (`InputBuffer.
## double_tap_recognized`) — a continuous forward/back hold never satisfies it.
##
## DIVEKICK IS NOT RECOGNIZED HERE AT ALL (AD-046: an aerial special must never
## spend this budget) — it is authored later as its own CancelRule/state, entirely
## outside this generic mechanism, so there is no coupling to un-author.
##
## `character.physics.air_dash_speed` / `double_jump_velocity` are per-character
## fixed-point constants (0 = the character has no such kit, mirroring `gravity`/
## `jump_velocity`'s own 0-disables convention) — this mechanism is engine-uniform,
## never character-branched (move-format.md criterion 4 in spirit).
static func _apply_air_action(p: PlayerState, character: Character) -> void:
	if p.air_action_used:
		return
	if InputBuffer.direction_pressed_edge(p.input_history, InputFrame.UP, p.facing):
		p.vel_y = -character.physics.double_jump_velocity
		p.air_action_used = true
		return
	if InputBuffer.double_tap_recognized(p.input_history, InputFrame.RIGHT, p.facing):
		# RIGHT in required_direction means FORWARD (facing-resolved, AD-002) — apply
		# along facing, mirroring the keyframe-motion convention (_apply_keyframe_motion).
		p.vel_x = character.physics.air_dash_speed * p.facing
		p.vel_y = 0
		p.air_action_used = true
		return
	if InputBuffer.double_tap_recognized(p.input_history, InputFrame.LEFT, p.facing):
		p.vel_x = -character.physics.air_dash_speed * p.facing
		p.vel_y = 0
		p.air_action_used = true
		return


## Land a physically-airborne character (AD-043's continuous clamp fused with
## landing): clamp to the floor, zero velocity, and reset the one-air-action
## economy (AD-046 — landing resets `air_action_used` regardless of how the
## character got airborne). The STATE transition differs by what was airborne:
##   - AIRBORNE category (a jump / air normal): transition to idle, exactly like
##     the prior grounded-entry snap's landing case (AD-042, now subsumed).
##   - Any other category reaching here (a launched HITSTUN reaction — hit-set
##     `vel_y` via `HitBox.launch`): NO state change. The character's current
##     reaction state is already a non-actionable, fixed-`duration` HITSTUN-
##     category state (e.g. character A's STATE_HITSTUN_LAUNCH / STATE_AIR_RESET);
##     landing simply stops it falling further and lets that SAME authored
##     duration/stun keep counting down to wakeup — this is AD-043's "knockdown
##     reaction," which explicitly introduces no new engine category or
##     destination state ("knockdown is a grounded reaction state").
static func _land(next: SimState, p: PlayerState, character: Character, move: MoveState) -> void:
	p.pos_y = next.stage.ground_y
	p.vel_x = 0
	p.vel_y = 0
	p.air_action_used = false
	if move != null and move.category == MoveState.CATEGORY_AIRBORNE:
		_enter_state(next, p, character, character.idle_state_id)


## Fire a keyframe's `spawn` action on the EXACT tick its range is entered
## (frame_in_state == kf.frame_start) — a one-shot per keyframe range, not once
## per covered frame (a keyframe may span several frames; the projectile spawns
## once at the start of that range, matching an author's "this attack releases a
## fireball on frame N" intent). Subject to the owner's live-projectile cap
## (move-format.md: "if the cap is full the spawn is suppressed").
static func _process_spawn(next: SimState, owner: int, p: PlayerState, move: MoveState) -> void:
	for kf in move.timeline:
		if not kf.has_spawn or kf.spawn_projectile == null:
			continue
		if p.frame_in_state != kf.frame_start:
			continue
		_try_spawn_projectile(next, owner, p, kf)


## Spawn one projectile from a firing keyframe, if the owner is under its cap
## (AD-021, "one live projectile per owner" for the slice fireball; the cap is
## authored per-ProjectileData via max_per_owner, not hardcoded to 1, so a future
## character/projectile can differ). Registers the projectile in ProjectileRegistry
## by data_id (AD-024) — the runtime entity carries only the id, never the HitBox
## itself (see projectile.gd).
static func _try_spawn_projectile(next: SimState, owner: int, p: PlayerState, kf: Keyframe) -> void:
	var data: ProjectileData = kf.spawn_projectile
	var data_id: int = data.id
	var live_count: int = 0
	for pr in next.projectiles:
		if pr.owner == owner and pr.data_id == data_id:
			live_count += 1
	if live_count >= data.max_per_owner:
		return   # cap full: spawn suppressed (move-format.md Keyframe.spawn)

	# Spawn position: the owner's world position plus the keyframe's character-local
	# offset, flipped by facing (the same local->world convention MoveData uses for
	# boxes) so a spawn offset authored "in front of" the character stays in front
	# regardless of which way they face.
	var spawn_x: int = MoveData.world_offset_x(kf.spawn_offset_x, p.facing, p.pos_x)
	var spawn_y: int = p.pos_y + kf.spawn_offset_y
	# Spawn velocity: authored forward-relative (like keyframe motion), applied
	# along facing for the horizontal component; vertical is facing-independent.
	var vel_x: int = kf.spawn_velocity_x * p.facing
	var vel_y: int = kf.spawn_velocity_y

	var pr := Projectile.spawn(owner, data_id, data, spawn_x, spawn_y, vel_x, vel_y, p.facing)
	next.projectiles.append(pr)


## Apply a keyframe's authored motion for the current frame to the player's velocity.
## has_motion SETS an explicit velocity this frame (fixed-point; an impulse — takeoff,
## air dash, double jump, a divekick's dive), applied along facing for the horizontal
## component (forward is +facing; vertical is facing-independent). Uses the FIRST
## covering keyframe with motion (deterministic order).
##
## A frame with NO authored motion (AD-043, move-format.md movement invariants):
##   - GROUNDED category: zero velocity (no slide, no vertical — grounded states are
##     unchanged, pos_y pinned at ground_y, no gravity).
##   - Any other category (AIRBORNE, or a launched HITSTUN/BLOCKSTUN reaction):
##     INHERIT the ongoing velocity (leave it untouched) — this is what lets an air
##     normal carry the jump arc's fall, and a launched reaction keep falling under
##     gravity, instead of the velocity being reset to zero every frame it isn't
##     explicitly re-authored.
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
	elif move.category == MoveState.CATEGORY_GROUNDED:
		p.vel_x = 0
		p.vel_y = 0
	# else: inherit (no-op) — see doc comment above.


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
##   { attacker, defender, hitbox: HitBox, projectile_index: int (-1 if none) } —
## one per (attacker id_group) that touches the defender's hurtbox. id_group
## single-hit is enforced in phase 5, not here (here we may report multiple boxes
## of one group; phase 5 collapses them). Also tests every LIVE PROJECTILE's
## hitbox against its non-owner's hurtbox (AD-021; combat-resolution.md
## "Projectiles" — "its hitbox is tested against the opponent's hurtbox"); a
## projectile contact carries `projectile_index` so phase 5 can consume it.
static func phase4_overlap(next: SimState) -> Array:
	var contacts: Array = []
	for attacker in range(2):
		var defender: int = 1 - attacker
		var atk: PlayerState = next.players[attacker]
		var def: PlayerState = next.players[defender]
		var atk_boxes: Array = _resolved_boxes_for(atk)
		var def_boxes: Array = _resolved_boxes_for(def)
		var def_invuln: Dictionary = _defender_invuln(def)
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
			if not connected:
				continue
			# Invuln gate (AD-031): a geometric overlap against a covering-keyframe
			# invuln that matches this box's hit_kind WHIFFS — not appended, so phase 5
			# never sees it (no id_group/throw-clash/combo effect from a suppressed
			# contact). The box's own HitBox.hit_kind carries STRIKE by default.
			if _invuln_gates(rb.hit, def_invuln):
				continue
			contacts.append({
				"attacker": attacker,
				"defender": defender,
				"hitbox": rb.hit,
				"projectile_index": -1,
			})

	# Projectile-vs-opponent-hurtbox (AD-021). Each live projectile is tested
	# against the NON-OWNER's hurtboxes only (a projectile never hits its own
	# owner — no projectile-vs-projectile either, deferred per AD-021). Fixed list
	# order (next.projectiles order) keeps this deterministic.
	for idx in range(next.projectiles.size()):
		var pr: Projectile = next.projectiles[idx]
		var rb: ResolvedBox = pr.resolve_hitbox()
		if rb == null:
			continue
		var defender: int = 1 - pr.owner
		var def_boxes: Array = _resolved_boxes_for(next.players[defender])
		var def_invuln: Dictionary = _defender_invuln(next.players[defender])
		for hb in def_boxes:
			if hb.kind != BoxView.KIND_HURT:
				continue
			if rb.overlaps(hb):
				# Gated (AD-031): the projectile is NOT consumed — it is simply not
				# appended as a contact, so phase 5's "consume on connect" path never
				# runs for it. It passes through and may connect on a later vulnerable
				# frame (the one operational difference from a character strike).
				if _invuln_gates(rb.hit, def_invuln):
					break
				contacts.append({
					"attacker": pr.owner,
					"defender": defender,
					"hitbox": rb.hit,
					"projectile_index": idx,
				})
				break   # one contact per projectile per tick is enough; phase 5 consumes it
	return contacts


## The defender's CURRENT-frame invulnerability, read from its covering keyframe(s)
## for `frame_in_state` (AD-031; derived, no new SimState field — mirrors how box
## geometry is resolved). Multiple covering keyframes union (any covering keyframe
## setting a flag grants it, matching how MoveData unions box lists). Returns
## `{ "strike": bool, "throw": bool }`; both false if the character/state/keyframe
## is unknown (a safe, always-vulnerable default).
static func _defender_invuln(def: PlayerState) -> Dictionary:
	var out: Dictionary = {"strike": false, "throw": false}
	var character: Character = MoveRegistry.character(def.character_id)
	if character == null:
		return out
	var move: MoveState = character.get_state(def.state_id)
	if move == null:
		return out
	for kf in move.timeline:
		if not kf.covers(def.frame_in_state):
			continue
		if kf.invuln_strike:
			out["strike"] = true
		if kf.invuln_throw:
			out["throw"] = true
	return out


## True iff the incoming box's `hit_kind` is whiffed by the defender's current
## invuln (AD-031): STRIKE/PROJECTILE gate on invuln_strike; THROW gates on
## invuln_throw. `hb` may be null defensively (never gates a null box).
static func _invuln_gates(hb: HitBox, def_invuln: Dictionary) -> bool:
	if hb == null:
		return false
	if hb.hit_kind == HitBox.HIT_KIND_THROW:
		return bool(def_invuln.get("throw", false))
	# STRIKE and PROJECTILE both gate on invuln_strike (AD-031: "a projectile is a
	# strike delivered at range — one immunity beats both").
	return bool(def_invuln.get("strike", false))


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
# confirmed contact (respecting id_group single-hit + rehit cadence), determine hit vs
# block, apply damage after scaling, set the defender's reaction state + stun, set
# hitstop on BOTH parties, apply pushback, grant cancel_tags, update combo, record
# last_hit. THROWBOX connects take the throw path (_resolve_throw): bypass blockstun,
# open a tech window (TKT-P0-09).
# ---------------------------------------------------------------------------

static func phase5_hit_resolution(next: SimState, contacts: Array) -> void:
	if contacts.is_empty():
		return
	# Throw clash-to-tech (AD-016): if BOTH players' throwboxes connect this tick
	# (simultaneous ground throws within the window), resolve as a tech (clash) — no
	# throw, both pushed to neutral — instead of one throwing the other. Only a
	# character throwbox can set is_throw (a projectile is never a throw), so this
	# scan is unaffected by projectile contacts mixed into the same list.
	if _both_throwboxes_connect(contacts):
		_resolve_throw_clash(next, contacts)
		return

	# Single-hit integrity (AD-016, move-format.md criterion 5). Collapse to ONE hit per
	# (attacker, id_group):
	#   - WITHIN this tick: overlapping boxes sharing an id_group register one hit
	#     (`seen`; first occurrence wins — deterministic, phase 4 emits in fixed order).
	#   - ACROSS active frames: an id_group already connected during THIS move
	#     (active_hit_ids) does not re-hit — a multi-frame active window lands ONE hit,
	#     not one per active frame. A rehit_interval hitbox re-hits only once the interval
	#     has elapsed since its last connect (active_hit_frames); no hit between (AD-016).
	#
	# PROJECTILE CONTACTS (AD-021) bypass the character's per-move active_hit_ids/
	# rehit memory entirely: a projectile's "move" is its own lifecycle, not the
	# owner's current character state (the owner may have long since recovered
	# and be in an unrelated state by the time the projectile connects). Single-
	# hit-per-contact is enforced instead by CONSUMING the projectile on connect
	# (despawn_pending, applied after this pass) — a despawned projectile cannot
	# contact again, which is the projectile-equivalent of "one hit per contact."
	var seen: Dictionary = {}   # key "attacker:id_group" -> true (this tick)
	var consumed_projectiles: Dictionary = {}   # projectile_index -> true (this tick)
	for c in contacts:
		var hb: HitBox = c["hitbox"]
		if hb == null:
			continue
		var attacker: int = int(c["attacker"])
		var defender: int = int(c["defender"])
		var projectile_index: int = int(c["projectile_index"])

		if projectile_index >= 0:
			# A projectile contact: single-hit-per-contact via consumption, not
			# active_hit_ids (that memory belongs to the OWNER's current move, which
			# a traveling projectile has already outlived). Skip if this projectile
			# already resolved a contact this same tick (defensive; phase 4 emits at
			# most one contact per projectile per tick already).
			if consumed_projectiles.has(projectile_index):
				continue
			consumed_projectiles[projectile_index] = true
			_resolve_one_hit(next, attacker, defender, hb)
			next.projectiles[projectile_index].lifetime_remaining = 0   # consumed on hit/block (AD-021)
			continue

		# THROWBOX connect (AD-016): take the throw path (bypasses block; opens a tech
		# window). A throw is single-per-contact by id_group like any hit.
		if hb.is_throw:
			var tkey: String = "%d:%d" % [attacker, hb.id_group]
			if seen.has(tkey):
				continue
			if _has_active_hit_id(next.players[attacker], hb.id_group):
				continue
			seen[tkey] = true
			_resolve_throw(next, attacker, defender, hb)
			continue
		var key: String = "%d:%d" % [attacker, hb.id_group]
		if seen.has(key):
			continue
		# Already connected this id_group during the current move? For a plain hitbox
		# (rehit_interval == 0) never re-hit. For a cadenced hitbox, re-hit only if the
		# interval has elapsed since the last connect (else skip — no hit between).
		if not _rehit_ready(next.players[attacker], hb, next.tick + 1):
			continue
		seen[key] = true
		_resolve_one_hit(next, attacker, int(c["defender"]), hb)


## Whether a hitbox may connect given the attacker's per-move single-hit / rehit memory.
## A NEW id_group (never connected this move) may always hit. An already-connected group:
##   - rehit_interval == 0: never again (single hit per contact — AD-016).
##   - rehit_interval  > 0: only once `rehit_interval` frames have elapsed since its last
##     connect (candidate_tick - last_connect >= rehit_interval), and no hit in between.
static func _rehit_ready(atk: PlayerState, hb: HitBox, candidate_tick: int) -> bool:
	var idx: int = _active_hit_index(atk, hb.id_group)
	if idx == -1:
		return true
	if hb.rehit_interval <= 0:
		return false
	var last_connect: int = atk.active_hit_frames[idx]
	return candidate_tick - last_connect >= hb.rehit_interval


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
	var contact_depth: int = 0
	var air_height_hitstun_delta: int = 0
	if blocking:
		reaction_state = hb.block_reaction
		stun_frames = hb.blockstun
		stun_kind = PlayerView.STUN_BLOCK
	else:
		reaction_state = hb.hit_reaction
		stun_frames = hb.hitstun
		stun_kind = PlayerView.STUN_HIT
		# --- Air-normal height-dependent advantage (AD-033), hit branch only ---
		# When the ATTACKER's current move category is AIRBORNE, scale the hitstun
		# it inflicts by contact depth through the ONE AirHeightScaling definition,
		# feeding the single AD-008 advantage formula (never a second, parallel
		# advantage adjustment). Grounded normals and blocked/thrown contacts are
		# untouched. depth = ground_y - attacker.pos_y (fixed-point; deeper = smaller
		# depth, more plus).
		var atk_character: Character = MoveRegistry.character(atk.character_id)
		var atk_move: MoveState = atk_character.get_state(atk.state_id) if atk_character != null else null
		if atk_move != null and atk_move.category == MoveState.CATEGORY_AIRBORNE:
			contact_depth = next.stage.ground_y - atk.pos_y
			air_height_hitstun_delta = AirHeightScaling.hitstun_delta(contact_depth)
			stun_frames = max(hb.hitstun + air_height_hitstun_delta, AirHeightScaling.MIN_HITSTUN)

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
		_enter_state(next, def, character_def, reaction_state)
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

	# --- Attacker's move-contact outcome (for CancelRule.condition, AD-015) --
	# The attacker's current move now HAS connected: hit or block. An on_hit / on_block
	# / on_contact cancel becomes legal from here (in its window). This is set on the
	# ATTACKER (per-attacker, not the global last_hit — AD-026's reasoning: two attackers
	# have independent contact outcomes).
	atk.move_contact = PlayerState.CONTACT_BLOCK if blocking else PlayerState.CONTACT_HIT

	# --- Cancel-tag grant (AD-017: granted phase 5 tick T, usable T+1) -------
	# The attacker records the granted tags in serialized state. Because phase 2 (the
	# cancel phase) precedes phase 5, a tag granted here on tick T is first visible to
	# the cancel evaluation on tick T+1 — the uniform one-tick grant->consume latency
	# (AD-017) falls out of the fixed phase order, no explicit delay needed.
	for tag in hb.cancel_tags:
		if not _has_cancel_tag(atk, tag):
			atk.cancel_tags.append(tag)

	# --- Mark this id_group as connected for the attacker's current move -----
	# (single-hit across active frames — F-005/AD-026). Record BOTH the id_group and the
	# tick it connected (active_hit_frames, parallel), so a rehit_interval hitbox can
	# cadence off the last connect (TKT-P0-09). next.tick is still this tick's pre-phase-7
	# value; +1 makes the recorded connect tick the tick this step PRODUCES, matching how
	# last_hit.tick and the rehit-interval comparison are expressed.
	var connect_tick: int = next.tick + 1
	var existing: int = _active_hit_index(atk, hb.id_group)
	if existing == -1:
		atk.active_hit_ids.append(hb.id_group)
		atk.active_hit_frames.append(connect_tick)
	else:
		# Re-hit (rehit_interval elapsed): refresh the last-connect tick in place.
		atk.active_hit_frames[existing] = connect_tick

	# --- Record last_hit (F-002; inspection surface) ------------------------
	var rec := HitRecord.new()
	rec.attacker = attacker
	rec.defender = defender
	rec.damage_dealt = applied_damage
	rec.was_block = blocking
	rec.scaling_applied_pct = scaling_pct
	rec.combo_count_after = def.combo_hits if not blocking else 0
	# Air-normal height-dependent advantage readout (AD-033): 0/0 on any
	# non-air-normal hit (blocked, thrown, or a grounded attacker) — set above only
	# on the airborne-attacker hit branch, otherwise left at their zero defaults.
	rec.contact_depth = contact_depth
	rec.air_height_hitstun_delta = air_height_hitstun_delta
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
# Throws (combat-resolution.md "Throws"; AD-016). A throwbox overlapping a throwable
# hurtbox CONNECTS and BYPASSES BLOCKSTUN — throws are not blocked (block state is
# ignored). On connect the defender enters the throw's reaction state and a TECH WINDOW
# opens: if the defender inputs a throw within the window, the throw is teched (both
# pushed to neutral, no damage). Simultaneous ground throws within the window resolve
# as a tech (clash). Air throws / formal throw-vs-throw priority stay deferred (AD-016).
# ---------------------------------------------------------------------------

## True iff BOTH players have a throwbox contact this tick (simultaneous throws) — the
## clash-to-tech case (AD-016). Reads the phase-4 contact list for a throw contact from
## each attacker.
static func _both_throwboxes_connect(contacts: Array) -> bool:
	var atk0_throws: bool = false
	var atk1_throws: bool = false
	for c in contacts:
		var hb: HitBox = c["hitbox"]
		if hb == null or not hb.is_throw:
			continue
		if int(c["attacker"]) == 0:
			atk0_throws = true
		else:
			atk1_throws = true
	return atk0_throws and atk1_throws


## Resolve a simultaneous-throw CLASH as a tech (AD-016): neither throw lands, both
## players are pushed apart to neutral, no damage, no stun. Deterministic (symmetric
## separation; the pushout constant is the throw's own tech pushback).
static func _resolve_throw_clash(next: SimState, contacts: Array) -> void:
	# Use the first throw hitbox's tech pushback for a symmetric separation (both are
	# grounded throws in the slice; either's constant is fine — deterministic first).
	var push: int = 0
	for c in contacts:
		var hb: HitBox = c["hitbox"]
		if hb != null and hb.is_throw:
			push = hb.pushback_hit
			break
	var p0: PlayerState = next.players[0]
	var p1: PlayerState = next.players[1]
	# Push each away from the other along x (P0 left of P1 by convention; if equal,
	# P0 goes left — deterministic tiebreak).
	var p0_left: bool = p0.pos_x <= p1.pos_x
	p0.pos_x += (-push if p0_left else push)
	p1.pos_x += (push if p0_left else -push)
	# No damage, no stun, no throw reaction — both stay actionable (a clean tech/clash).


## Resolve a single throw connect (AD-016). Bypasses blockstun (block state ignored):
## the defender ALWAYS enters the throw's reaction (hit_reaction) and takes the throw's
## hitstun. A TECH WINDOW opens on the defender: `throw_tech_window` frames in which a
## defender throw input techs the throw to neutral (handled in phase 2). Damage is
## applied on the throw connect (a throw is a hit that can't be blocked); the tech, if
## it fires next tick(s), reverses to neutral before the reaction commits meaningfully.
static func _resolve_throw(next: SimState, attacker: int, defender: int, hb: HitBox) -> void:
	var atk: PlayerState = next.players[attacker]
	var def: PlayerState = next.players[defender]
	var character_def: Character = MoveRegistry.character(def.character_id)

	# Throw bypasses block: the defender enters the throw reaction (hit_reaction) and
	# takes throw hitstun regardless of holding back.
	if character_def != null and hb.hit_reaction != 0:
		_enter_state(next, def, character_def, hb.hit_reaction)
	def.stun = hb.hitstun
	def.stun_kind = PlayerView.STUN_HIT

	# Open the defender's tech window (AD-016). The window length is authored on the
	# throw hitbox via its dedicated `tech_window` field (AD-029; no longer a reuse of
	# `blockstun` — a throw is never blocked). Record who threw.
	def.throw_tech_window = hb.tech_window
	def.thrown_by = attacker

	# Damage (throws deal damage on connect; single-sourced scaling like any hit — a
	# throw normally starts a combo so hit-count 1 => unscaled at P0).
	def.combo_hits = 1
	def.combo_damage = 0
	def.combo_scaling = DamageScaling.scaling_for_hit_count(def.combo_hits)
	var applied_damage: int = FP.round_to_int(FP.mul(FP.from_int(hb.damage), def.combo_scaling))
	def.health -= applied_damage
	def.combo_damage += applied_damage

	# Attacker's move contact (throws register as a hit for cancels/combo attribution).
	atk.move_contact = PlayerState.CONTACT_HIT

	# Single-hit memory (a throw connects once per contact, like any id_group).
	var connect_tick: int = next.tick + 1
	if _active_hit_index(atk, hb.id_group) == -1:
		atk.active_hit_ids.append(hb.id_group)
		atk.active_hit_frames.append(connect_tick)

	# Record last_hit (inspection surface). A throw is a hit that bypassed block.
	var rec := HitRecord.new()
	rec.attacker = attacker
	rec.defender = defender
	rec.damage_dealt = applied_damage
	rec.was_block = false
	rec.scaling_applied_pct = FP.round_to_int(FP.mul(def.combo_scaling, FP.from_int(100)))
	rec.combo_count_after = def.combo_hits
	rec.tick = connect_tick
	next.last_hit = rec


## Apply a defender's throw TECH (AD-016): if the thrown defender inputs a throw within
## the tech window, the throw is teched — both players pushed to neutral, damage undone,
## stun cleared, tech state closed. Called from phase 2 for a defender with an open
## tech window who has a buffered throw command. Returns true iff a tech fired.
static func _try_throw_tech(next: SimState, defender: int, character: Character) -> bool:
	var def: PlayerState = next.players[defender]
	if def.throw_tech_window <= 0 or def.thrown_by < 0:
		return false
	# Did the defender input a throw command within the buffer? A throw is a button_map
	# entry whose target is a throw move; recognize any such buffered command.
	if not _has_buffered_throw(character, def):
		return false
	var attacker: int = def.thrown_by
	var atk: PlayerState = next.players[attacker]
	# Undo the throw damage taken this exchange (tech = no damage), reset combo.
	def.health += def.combo_damage
	def.combo_hits = 0
	def.combo_damage = 0
	def.combo_scaling = FP.ONE
	# Clear stun / reaction: both return to neutral (idle).
	def.stun = 0
	def.stun_kind = PlayerView.STUN_NONE
	if character != null:
		_enter_state(next, def, character, character.idle_state_id)
	var atk_char: Character = MoveRegistry.character(atk.character_id)
	if atk_char != null:
		_enter_state(next, atk, atk_char, atk_char.idle_state_id)
	# Push apart to neutral (symmetric); use the throw's authored tech pushback if any.
	var push: int = FP.from_int(20)
	var def_left: bool = def.pos_x <= atk.pos_x
	def.pos_x += (-push if def_left else push)
	atk.pos_x += (push if def_left else -push)
	# Close the tech window.
	def.throw_tech_window = 0
	def.thrown_by = -1
	return true


## Whether the defender has a buffered throw command (a button_map entry whose target is
## a MoveState carrying a throwbox). Recognized through the same buffering (InputBuffer).
static func _has_buffered_throw(character: Character, p: PlayerState) -> bool:
	if character == null:
		return false
	for entry in character.button_map:
		var target: MoveState = character.get_state(entry.target_state_id)
		if target == null or not _move_has_throwbox(target):
			continue
		if InputBuffer.entry_satisfied(p.input_history, entry, p.facing):
			return true
	return false


## True iff any keyframe of the move carries a throw hitbox (a throwbox in hitboxes) or
## a throwbox entry. Used to identify a "throw command" for teching.
static func _move_has_throwbox(move: MoveState) -> bool:
	for kf in move.timeline:
		if not kf.throwboxes.is_empty():
			return true
		for hb in kf.hitboxes:
			if hb.is_throw:
				return true
	return false


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

static func phase7_advance_counters(next: SimState, was_frozen: Array,
		existing_projectile_count: int = -1) -> void:
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
		# Throw tech window counts down independently of stun/hitstop (AD-016). A throw
		# connect applies no mutual hitstop at P0, so the window is not frozen. When it
		# closes, clear who threw (the tech is no longer possible).
		if p.throw_tech_window > 0:
			p.throw_tech_window -= 1
			if p.throw_tech_window == 0:
				p.thrown_by = -1
	_advance_and_despawn_projectiles(next, existing_projectile_count)
	next.tick = next.tick + 1


## Decrement every PRE-EXISTING live projectile's lifetime and remove any that are
## due to despawn this tick (AD-021, combat-resolution.md "Projectiles" --
## "despawns when lifetime elapses or it leaves the stage"). Three despawn causes:
##   - CONSUMED: phase 5 already set lifetime_remaining to 0 on a hit/block connect.
##   - LIFETIME: the countdown reaches 0 this tick.
##   - OFF-STAGE: the projectile's position has left [wall_left, wall_right].
## Filtering (not decrementing-in-place-then-filtering-elsewhere) keeps this the
## ONE place a projectile leaves SimState.projectiles, deterministic list order
## preserved for the survivors (stable filter, no reordering).
##
## `existing_count`: how many projectiles were already live BEFORE this tick's
## phase 3 could spawn new ones (SimState.step captures this; -1 means "treat
## every projectile as pre-existing," the safe default for any caller that does
## not track spawns). New spawns are always APPENDED (phase 3), so index
## `>= existing_count` is a same-tick spawn and is NOT decremented this tick —
## mirrors `was_frozen`'s "a freeze/lifetime of N frames lasts N FOLLOWING ticks"
## rule (AD-010's reasoning applied to projectile lifetime).
static func _advance_and_despawn_projectiles(next: SimState, existing_count: int = -1) -> void:
	var survivors: Array[Projectile] = []
	for idx in range(next.projectiles.size()):
		var pr: Projectile = next.projectiles[idx]
		var newly_spawned: bool = existing_count >= 0 and idx >= existing_count
		# A projectile consumed by phase 5 already has lifetime_remaining == 0; a
		# pre-existing projectile that hasn't connected counts down normally. A
		# projectile spawned THIS tick is not aged the same tick it appears.
		if pr.lifetime_remaining > 0 and not newly_spawned:
			pr.lifetime_remaining -= 1
		var off_stage: bool = pr.pos_x < next.stage.wall_left or pr.pos_x > next.stage.wall_right
		if pr.lifetime_remaining <= 0 or off_stage:
			continue   # despawned: not added to survivors
		survivors.append(pr)
	next.projectiles = survivors


# ---------------------------------------------------------------------------
# Shared helpers.
# ---------------------------------------------------------------------------

## Enter a state cleanly: set state_id and put the character ON FRAME 1 of the new
## state immediately (a fresh entry IS on frame 1 this tick; phase 2 skips its advance
## for a state entered this tick). Zeroes horizontal velocity on entry (a new move sets
## its own keyframe motion in phase 3). Clears active_hit_ids: a NEW move is a new
## "contact," so its hitboxes may connect again (single-hit is per-move — F-005).
##
## GROUNDED-ENTRY LANDING SNAP (TKT-P1.1R3-02, AD-042, re-gate-4 E2). On entry to any
## CATEGORY_GROUNDED state, reconcile pos_y to the stage floor if it isn't already
## there. This is the landing-semantics half of AD-036, pulled into P1.1: a HELD jump
## direction exits its arc ONE TICK EARLY, at the is_actionable(>= duration) vs.
## move-ended (> duration) boundary (JC-011/JC-038) — the state becomes actionable ON
## its `duration` frame, one tick before the move is considered ended, so the still-
## held direction's buffered command re-derives a grounded transition (-> prejump,
## AD-038) there and the arc's final fall tick never applies, silently dropping it (a
## genuine +6-unit-per-jump upward drift, confirmed via trace-harness replay). The
## snap corrects that ENGINE transition-frame loss, not the arc data (already
## net-zero) — it is paired with the net-zero authoring invariant + TKT-P1.1R2-02's
## per-direction assertions, which still catch a mis-authored arc, so this does not
## mask one (AD-042 "not a bare clamp"). As an intended side effect, an air normal
## ending mid-arc also snaps to floor on its own once-through-ended -> idle
## transition, resolving the re-gate-3 D3 aerial float. Character-agnostic (reads the
## TARGET state's category + the stage's ground_y; no character-A branch).
## Deterministic — a pure function of state.
##
## SUBSUMED BY AD-043 (TKT-P2-01). The continuous `pos_y >= ground_y` clamp fused
## with landing (phase 3, StepPhases._land) now handles the ordinary jump-landing
## case directly (and does so BEFORE any once-through-ended/actionable race can
## even arise, since it runs on physical ground contact, not on the state's
## authored `duration`). This snap remains as a defensive backstop for any OTHER
## path that enters a GROUNDED state while marginally off `ground_y` (e.g. a
## direct-to-GROUNDED transition that never went through the airborne clamp) —
## harmless and cheap to keep, not required for the jump/knockdown cases AD-043
## itself now covers.
static func _enter_state(next: SimState, p: PlayerState, character: Character, state_id: int) -> void:
	p.state_id = state_id
	p.frame_in_state = 1
	p.vel_x = 0
	p.active_hit_ids = PackedInt32Array()
	# A new move is a new contact: reset its single-hit / rehit memory, its contact
	# outcome (for on_hit/on_block/on_whiff cancels), and its granted cancel tags — a
	# new move's tags are its own (AD-015/017/026).
	p.active_hit_frames = PackedInt32Array()
	p.move_contact = PlayerState.CONTACT_NONE
	p.cancel_tags = PackedInt32Array()

	var target: MoveState = character.get_state(state_id) if character != null else null
	if target != null and target.category == MoveState.CATEGORY_GROUNDED and p.pos_y != next.stage.ground_y:
		p.pos_y = next.stage.ground_y


## True iff the player has already connected `id_group` during its current move.
static func _has_active_hit_id(p: PlayerState, id_group: int) -> bool:
	for gid in p.active_hit_ids:
		if gid == id_group:
			return true
	return false


## Index of `id_group` in the attacker's active_hit_ids (parallel to active_hit_frames),
## or -1 if it has not connected this move. Used for rehit cadence (last-connect tick).
static func _active_hit_index(p: PlayerState, id_group: int) -> int:
	for i in range(p.active_hit_ids.size()):
		if p.active_hit_ids[i] == id_group:
			return i
	return -1


## True iff the granted cancel tag is present in the attacker's cancel_tags (AD-017).
static func _has_cancel_tag(p: PlayerState, tag: int) -> bool:
	for t in p.cancel_tags:
		if t == tag:
			return true
	return false


## True iff the move's category is a stun category (hitstun/blockstun).
static func _is_stun_category(move: MoveState) -> bool:
	return move.category == MoveState.CATEGORY_HITSTUN \
		or move.category == MoveState.CATEGORY_BLOCKSTUN
