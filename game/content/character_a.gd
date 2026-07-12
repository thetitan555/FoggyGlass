class_name CharacterA
extends RefCounted

## Character A — the baseline shoto (character-a.md; TKT-P1-10). Authored PURELY
## as data against move-format.md / AD-006/007/008/015/016/021/030 — no
## character-specific engine code. This builder is the CONTENT SOURCE (mirrors
## TestSupport's role for the P0 test character): `tools/bake_character_a.gd`
## calls this and ResourceSaver.save()s the result to `data/character-a.tres`, so
## the shipped `.tres` and this builder agree by construction (no hand-
## transcription of ~20 states). `game/tests/test_character_a.gd` builds the
## SAME character via this one function and asserts against it — one content
## source, two consumers (a baked resource + a dev-test twin), never two
## authored definitions to drift apart.
##
## All spatial/physics values are BAKED FIXED-POINT integers (AD-014). Frame
## counts, damage, stun are plain ints (whole frames / whole units).
##
## INVULN NOTE (AD-031, TKT-P1-11, landed 2026-07-04). `Keyframe.invuln_strike`
## / `invuln_throw` are authored below on the DP / 2H / back dash exactly as
## character-a.md specifies, and the engine now CONSUMES them: step_phases.gd
## phase 4 gates a covered contact out of the contact list (the box whiffs) —
## `invuln_strike` whiffs STRIKE and PROJECTILE contacts, `invuln_throw` whiffs
## THROW (against `HitBox.hit_kind`). The whiff is observable (attacker
## `move_contact` resolves to WHIFF; defender invuln surfaces as
## `PlayerView.invuln`). So criteria 4 and 6 (invuln correctness) now pass
## end-to-end — see `game/tests/test_invuln.gd`. This was previously a flagged
## engine/format gap (invuln authored-but-inert); AD-031 resolved it. Every
## structural criterion (frame data, cancels, the fireball, the throw,
## no-gatling/no-jump-cancel) is fully authored and enforced by the engine.
##
## JUMP ARC (movement table). The engine has no gravity constant / airborne
## transition system (nothing in SimState or step_phases.gd integrates gravity
## or flips a grounded<->airborne category) — but keyframe motion already lets
## any state author an explicit PER-FRAME velocity (Keyframe.motion_vel_x/y,
## integrated as plain fixed-point add, phase 3). So the ~45-frame jump arc is
## authored as a sequence of one-frame keyframes carrying a hand-baked
## rise/fall vel_y curve (a simple symmetric triangular profile: constant rise
## velocity for the first half, constant fall velocity for the second,
## sign-flipped at the apex) — no new engine mechanism needed, purely a bigger
## timeline. This is a judgment call (logged, docs/judgment-log.md): a
## parabolic arc would need a authored per-frame table too (the engine has no
## quadratic/gravity primitive to lean on either way), so the simpler
## triangular profile is the reasonable data-only reading of "no jump
## cancels... ~45f airborne" that needs no new engine primitive.

const CHAR_ID: int = 2

# --- Movement states ---------------------------------------------------------
const STATE_IDLE: int = 100
const STATE_WALK_F: int = 101
const STATE_WALK_B: int = 102
const STATE_DASH_F: int = 103
const STATE_DASH_B: int = 104
const STATE_PREJUMP: int = 105
const STATE_JUMP_N: int = 106
const STATE_JUMP_F: int = 107
const STATE_JUMP_B: int = 108
const STATE_CROUCH: int = 109
# Directional prejump lead-ins (AD-039, TKT-P1.1R-04) -- mirror STATE_PREJUMP
# (the neutral lead-in) but each ALWAYS-cancels into JUMP_F/JUMP_B instead of
# JUMP_N. Numbered outside the contiguous 100-109 movement block (already
# full) rather than renumbering existing ids.
const STATE_PREJUMP_F: int = 160
const STATE_PREJUMP_B: int = 161

# --- Normals ------------------------------------------------------------------
const STATE_5L: int = 110
const STATE_5M: int = 111
const STATE_5H: int = 112
const STATE_2L: int = 113
const STATE_2M: int = 114
const STATE_2H: int = 115
const STATE_JL: int = 116
const STATE_JM: int = 117
const STATE_JH: int = 118

# --- Reaction states ------------------------------------------------------------
const STATE_HITSTUN: int = 120
const STATE_BLOCKSTUN: int = 121
const STATE_AIR_RESET: int = 122   # 2H's airborne "no follow-up" knock-away
const STATE_THROWN: int = 123
const STATE_CROUCH_BLOCKSTUN: int = 124
const STATE_HITSTUN_LAUNCH: int = 125   # DP hit reaction -> hard knockdown

# --- Fireball (236 L/M/H; a Projectile, AD-021/030) --------------------------
const STATE_FIREBALL_L: int = 130
const STATE_FIREBALL_M: int = 131
const STATE_FIREBALL_H: int = 132

# --- Shoryuken (623 L/M/H) ----------------------------------------------------
const STATE_DP_L: int = 140
const STATE_DP_M: int = 141
const STATE_DP_H: int = 142

# --- Throw (L+H) --------------------------------------------------------------
const STATE_THROW: int = 150

# --- Cancel tag ----------------------------------------------------------------
const TAG_SP: int = 1   # granted by 5L/5M/2L/2M on contact; gates > 236/623

# --- id_group allocation (unique per attack; TestSupport's convention) -------
const IDG_5L: int = 1
const IDG_5M: int = 2
const IDG_5H: int = 3
const IDG_2L: int = 4
const IDG_2M: int = 5
const IDG_2H: int = 6
const IDG_JL: int = 7
const IDG_JM: int = 8
const IDG_JH: int = 9
const IDG_FIREBALL_L: int = 10
const IDG_FIREBALL_M: int = 11
const IDG_FIREBALL_H: int = 12
const IDG_DP_L_HIT1: int = 13
const IDG_DP_M_HIT1: int = 14
const IDG_DP_H_HIT1: int = 15
const IDG_DP_H_HIT2: int = 16
const IDG_THROW: int = 17

# --- ProjectileData registry ids ---------------------------------------------
const PROJ_FIREBALL_L: int = 201
const PROJ_FIREBALL_M: int = 202
const PROJ_FIREBALL_H: int = 203

# --- Standard hurtbox (character-local, shared across most grounded frames) --
# AD-037: reflected across the feet line (new_y = -(old_y+old_h), h unchanged).
# local (-15,-80,30,80) -> feet at y=0 (pos_y), head at y=-80 -> matches
# TestSupport's convention (also reflected, TKT-P1.1R-02).
static func _hurt_stand() -> Box:
	return Box.make(FP.from_int(-15), FP.from_int(-80), FP.from_int(30), FP.from_int(80))

## Crouching hurtbox: shorter (crouch lows/blocks present a smaller profile).
## AD-037: reflected; top edge -55 (was 0), still feet-anchored at y=0.
static func _hurt_crouch() -> Box:
	return Box.make(FP.from_int(-15), FP.from_int(-55), FP.from_int(30), FP.from_int(55))

## Airborne hurtbox (jump normals / jump arc): same width, full height, offset
## up isn't needed since pos_y itself carries height. AD-037: reflected.
static func _hurt_air() -> Box:
	return Box.make(FP.from_int(-15), FP.from_int(-75), FP.from_int(30), FP.from_int(75))


## Build character A (character-a.md). One entry point; the .tres baker and the
## dev-test twin both call this so there is exactly one authored definition.
static func build_character() -> Character:
	var c := Character.new()
	c.id = CHAR_ID
	c.idle_state_id = STATE_IDLE

	var phys := CharacterPhysics.new()
	phys.walk_speed = FP.from_units(2.2)   # movement table: forward walk speed (data only; back walk is authored per-state)
	phys.gravity = 0                        # no engine gravity primitive; jump arc is keyframe-authored (see header note)
	phys.jump_velocity = 0
	c.physics = phys

	c.default_pushbox = Box.make(   # AD-037: reflected -> lower/nearer-to-feet portion of the hurtbox
		FP.from_int(-10), FP.from_int(-40), FP.from_int(20), FP.from_int(40))

	c.states = []
	c.states.append_array(_build_movement())
	c.states.append_array(_build_normals())
	c.states.append_array(_build_reactions())
	c.states.append_array(_build_fireballs())
	c.states.append_array(_build_shoryukens())
	c.states.append_array(_build_throw())

	c.button_map = _build_button_map()
	return c


# =============================================================================
# Button map (move-format.md -> Character.button_map; AD-018/022/032).
#
# Evaluated in authored order; first satisfied buffered command wins. Motion
# commands are listed BEFORE their prefix's plain-button fallbacks so e.g. a 236L
# motion is recognized before a bare 5L. The throw CHORD (L+H, AD-032) is listed
# before the plain L/M/H normals so a simultaneous L+H press resolves as the
# throw, not 5L/5H -- the chord does not shadow either bare button (a bare L or H
# alone does not satisfy a chord), so 5L/5M/5H all stay reachable.
# =============================================================================
static func _build_button_map() -> Array[ButtonMapEntry]:
	var map: Array[ButtonMapEntry] = []
	# Shoryuken (623 + L/M/H) -- listed before fireball/normals so the DP motion
	# takes priority (623 contains a forward+down that could otherwise satisfy a
	# lingering partial 236 scan; ordering is deterministic per InputBuffer).
	map.append(_map_motion(InputBuffer.MOTION_623, InputFrame.BUTTON_0, STATE_DP_L))
	map.append(_map_motion(InputBuffer.MOTION_623, InputFrame.BUTTON_1, STATE_DP_M))
	map.append(_map_motion(InputBuffer.MOTION_623, InputFrame.BUTTON_2, STATE_DP_H))
	# Fireball (236 + L/M/H).
	map.append(_map_motion(InputBuffer.MOTION_236, InputFrame.BUTTON_0, STATE_FIREBALL_L))
	map.append(_map_motion(InputBuffer.MOTION_236, InputFrame.BUTTON_1, STATE_FIREBALL_M))
	map.append(_map_motion(InputBuffer.MOTION_236, InputFrame.BUTTON_2, STATE_FIREBALL_H))
	# Throw (L+H chord, AD-032) -- listed BEFORE the bare standing normals below
	# so first-match-wins routes a same-frame L+H to the throw while a bare L or
	# H alone still falls through to 5L/5H (the chord requires BOTH bits on one
	# frame; a lone press never satisfies it).
	map.append(_map_chord(InputFrame.BUTTON_0, InputFrame.BUTTON_2, STATE_THROW))
	# Crouching normals (DOWN + button) before standing so a held DOWN routes low.
	map.append(_map(1, InputFrame.DOWN, 0, STATE_2M))   # 2M before 2L/2H so authored order picks the more specific gate first (all DOWN-gated -- direction alone does not disambigguate button index, so button_index is what actually selects the move; order is for readability)
	map.append(_map(0, InputFrame.DOWN, 0, STATE_2L))
	map.append(_map(2, InputFrame.DOWN, 0, STATE_2H))
	# Crouch stance (pure-direction command, AD-032/AD-038): held bare DOWN, no
	# button, routes to the already-authored STATE_CROUCH (a `loop` state -- AD-038
	# re-derives it every tick, so releasing DOWN falls through to no satisfied
	# command and phase 2 returns to idle). Listed AFTER the DOWN+button crouching
	# normals immediately above (so 2L/2M/2H still win when a button is held -- a
	# bare DOWN entry would otherwise never lose to them since first-match-wins
	# already favors the button entries by list order) and BEFORE the walk entries
	# below (so a down-forward hold, e.g. numpad 3, crouches rather than walks --
	# DOWN is checked first in authored order).
	map.append(_map(-1, InputFrame.DOWN, 0, STATE_CROUCH))
	# Diagonal jumps (composite pure-direction command, AD-032/AD-039): UP held
	# together with forward/back routes to PREJUMP_F/PREJUMP_B instead of the
	# neutral PREJUMP -- each carries its own ALWAYS cancel into JUMP_F/JUMP_B
	# (_build_movement). `_required_direction_held` ANDs every bit in
	# required_direction, so UP|RIGHT (forward) / UP|LEFT (back) both gate
	# correctly off one entry each -- no new recognizer mechanism. Listed
	# BEFORE the bare-UP neutral entry below (first-match-wins, AD-032) so a
	# diagonal hold resolves to the directional prejump, not the neutral one;
	# 9 (up+forward) = forward jump, 7 (up+back) = back jump (character-a.md).
	map.append(_map(-1, InputFrame.UP | InputFrame.RIGHT, 0, STATE_PREJUMP_F))
	map.append(_map(-1, InputFrame.UP | InputFrame.LEFT, 0, STATE_PREJUMP_B))
	# Jump (pure-direction command, AD-032): held UP, no button, routes to the
	# prejump lead-in (whose own ALWAYS cancel carries it into the neutral jump
	# arc -- see _build_movement's PREJUMP note). Listed before the bare standing
	# normals so it does not need to compete with a button press at all (jump has
	# no button to shadow).
	map.append(_map(-1, InputFrame.UP, 0, STATE_PREJUMP))
	# Standing normals.
	map.append(_map(0, 0, 0, STATE_5L))
	map.append(_map(1, 0, 0, STATE_5M))
	map.append(_map(2, 0, 0, STATE_5H))
	# Walk (pure-direction command, AD-032): held forward/back, no button, into
	# the already-authored STATE_WALK_F/STATE_WALK_B (movement table, below in
	# _build_movement) -- these states and their keyframe motion were authored
	# but never reachable from live input (2026-07-08 human-inspection-gate
	# flag: "arrow-key left/right movement does nothing"). Listed AFTER the
	# standing normals so a button press always wins over a bare directional
	# hold on the same buffered frame -- e.g. forward+L still performs 5L, not
	# a walk (5L/5M/5H match on ANY direction via their own required_direction
	# == 0 gate, so they already take priority by list order over anything
	# listed below them -- no new precedence mechanism needed). required_
	# direction uses RIGHT/LEFT to mean forward/back (facing-resolved, same
	# ButtonMapEntry/InputBuffer convention the jump entry above uses with UP).
	map.append(_map(-1, InputFrame.RIGHT, 0, STATE_WALK_F))
	map.append(_map(-1, InputFrame.LEFT, 0, STATE_WALK_B))
	return map


## One ButtonMapEntry for a plain (non-motion, non-chord) command.
static func _map(button_index: int, required_direction: int, motion: int,
		target_state_id: int) -> ButtonMapEntry:
	var e := ButtonMapEntry.new()
	e.button_index = button_index
	e.required_direction = required_direction
	e.motion = motion
	e.target_state_id = target_state_id
	return e


## A two-button CHORD entry (AD-032): both `button_bit_a` and `button_bit_b` must
## be held on the same buffered frame. Bits are InputFrame.BUTTON_* constants;
## ButtonMapEntry wants bit INDICES, so this converts (mirrors _map_motion).
static func _map_chord(button_bit_a: int, button_bit_b: int, target_state_id: int) -> ButtonMapEntry:
	var e := ButtonMapEntry.new()
	e.button_index = _bit_to_index(button_bit_a)
	e.chord_button_index = _bit_to_index(button_bit_b)
	e.required_direction = 0
	e.motion = 0
	e.target_state_id = target_state_id
	return e


## A motion command entry (e.g. 236 + BUTTON_1). `button_bit` is an
## InputFrame.BUTTON_* constant; ButtonMapEntry.button_index wants the bit
## INDEX, so this converts (mirrors TestSupport._map's motion_button handling).
static func _map_motion(motion: int, button_bit: int, target_state_id: int) -> ButtonMapEntry:
	var e := ButtonMapEntry.new()
	e.button_index = _bit_to_index(button_bit)
	e.required_direction = 0
	e.motion = motion
	e.target_state_id = target_state_id
	return e


static func _bit_to_index(bit: int) -> int:
	for i in range(8):
		if bit == (1 << (4 + i)):
			return i
	return -1


# =============================================================================
# Movement (character-a.md -> Movement table).
# =============================================================================
static func _build_movement() -> Array[MoveState]:
	var out: Array[MoveState] = []

	# IDLE: looping, 1 frame, standing hurtbox only.
	var idle := MoveState.new()
	idle.id = STATE_IDLE
	idle.category = MoveState.CATEGORY_GROUNDED
	idle.duration = 1
	idle.loop = true
	var idle_kf := Keyframe.new()
	idle_kf.frame_start = 1
	idle_kf.frame_end = 1
	idle_kf.hurtboxes = [_hurt_stand()]
	idle.timeline = [idle_kf]
	out.append(idle)

	# WALK FORWARD: looping, 2.2 px/f (movement table).
	var walk_f := MoveState.new()
	walk_f.id = STATE_WALK_F
	walk_f.category = MoveState.CATEGORY_GROUNDED
	walk_f.duration = 1
	walk_f.loop = true
	var wf_kf := Keyframe.new()
	wf_kf.frame_start = 1
	wf_kf.frame_end = 1
	wf_kf.hurtboxes = [_hurt_stand()]
	wf_kf.has_motion = true
	wf_kf.motion_vel_x = FP.from_units(2.2)
	walk_f.timeline = [wf_kf]
	out.append(walk_f)

	# WALK BACK: looping, 1.8 px/f.
	var walk_b := MoveState.new()
	walk_b.id = STATE_WALK_B
	walk_b.category = MoveState.CATEGORY_GROUNDED
	walk_b.duration = 1
	walk_b.loop = true
	var wb_kf := Keyframe.new()
	wb_kf.frame_start = 1
	wb_kf.frame_end = 1
	wb_kf.hurtboxes = [_hurt_stand()]
	wb_kf.has_motion = true
	wb_kf.motion_vel_x = FP.from_units(-1.8)   # back is negative forward-relative
	walk_b.timeline = [wb_kf]
	out.append(walk_b)

	# CROUCH: looping, 1 frame, crouching hurtbox (2L/2M lows are authored off
	# their own states directly, per TestSupport's pattern; CROUCH itself is
	# the idle-equivalent holding-down state so `PlayerView` reads a distinct
	# category-consistent crouch pose).
	var crouch := MoveState.new()
	crouch.id = STATE_CROUCH
	crouch.category = MoveState.CATEGORY_GROUNDED
	crouch.duration = 1
	crouch.loop = true
	var cr_kf := Keyframe.new()
	cr_kf.frame_start = 1
	cr_kf.frame_end = 1
	cr_kf.hurtboxes = [_hurt_crouch()]
	crouch.timeline = [cr_kf]
	out.append(crouch)

	# FORWARD DASH: 20f, ~95px, fully committed (no cancel -- authoring omits
	# any CancelRule). Approximate a uniform-speed step dash: 95/20 ~= 4.75 px/f.
	var dash_f := MoveState.new()
	dash_f.id = STATE_DASH_F
	dash_f.category = MoveState.CATEGORY_GROUNDED
	dash_f.duration = 20
	dash_f.loop = false
	var df_kf := Keyframe.new()
	df_kf.frame_start = 1
	df_kf.frame_end = 20
	df_kf.hurtboxes = [_hurt_stand()]
	df_kf.has_motion = true
	df_kf.motion_vel_x = FP.from_units(4.75)
	dash_f.timeline = [df_kf]
	out.append(dash_f)

	# BACK DASH: 22f, ~80px, invuln 1-7 (strike+throw) -- enforced by the engine
	# (step_phases.gd phase 4 consumes invuln per AD-031/TKT-P1-11; see this
	# file's header note and game/tests/test_invuln.gd). ~80/22 ~= 3.64 px/f.
	var dash_b := MoveState.new()
	dash_b.id = STATE_DASH_B
	dash_b.category = MoveState.CATEGORY_GROUNDED
	dash_b.duration = 22
	dash_b.loop = false
	var db_invuln_kf := Keyframe.new()
	db_invuln_kf.frame_start = 1
	db_invuln_kf.frame_end = 7
	db_invuln_kf.hurtboxes = [_hurt_stand()]
	db_invuln_kf.has_motion = true
	db_invuln_kf.motion_vel_x = FP.from_units(-3.64)
	db_invuln_kf.invuln_strike = true
	db_invuln_kf.invuln_throw = true
	var db_tail_kf := Keyframe.new()
	db_tail_kf.frame_start = 8
	db_tail_kf.frame_end = 22
	db_tail_kf.hurtboxes = [_hurt_stand()]
	db_tail_kf.has_motion = true
	db_tail_kf.motion_vel_x = FP.from_units(-3.64)
	dash_b.timeline = [db_invuln_kf, db_tail_kf]
	out.append(dash_b)

	# PREJUMP (neutral): 4f, grounded, then airborne (transitions to STATE_JUMP_N
	# once duration elapses -- authored as a plain once-through move; the jump
	# target is what phase 2's "once-through move ended -> idle" would otherwise
	# route to, so PREJUMP instead ends INTO the jump arc via its own short
	# timeline; a state sequence like this is not expressible as a chain
	# without a cancel/transition target. Reasonable data-only reading (logged):
	# PREJUMP carries a single CancelRule (condition ALWAYS, window = its own
	# full duration) into JUMP_N, so a jump command always resolves prejump ->
	# neutral jump automatically.
	#
	# DIRECTIONAL/DIAGONAL JUMPS (AD-039, TKT-P1.1R-04): a jump's horizontal
	# direction is decided at TAKEOFF (the input frame), so button_map routes
	# UP|FORWARD / UP|BACK to their OWN prejump lead-ins -- PREJUMP_F / PREJUMP_B
	# below -- rather than branching one prejump's cancel by direction (a
	# CancelRule has no direction gate to express that on). Each is authored
	# identically to this neutral PREJUMP (same 4f duration, same window-3
	# ALWAYS cancel), differing only in its cancel target (JUMP_F / JUMP_B).
	# Window is the LAST frame BEFORE duration (3, not 4): Actionability.is_actionable
	# treats a committed once-through move as actionable once frame_in_state >= duration
	# (the reasonable "recovery has ended" reading elsewhere), which on frame 4 itself
	# would make phase 2 take the actionable/buffered-command branch INSTEAD of the
	# cancel branch (see phase2_state_machine's fixed priority order) -- the ALWAYS
	# cancel would then never be reached and PREJUMP would loop forever re-satisfying
	# the held-UP jump command back into itself. Firing one frame earlier, on 3 (still
	# unambiguously committed), reaches the jump arc before that race window opens,
	# while each prejump's own duration/timeline stay the spec's authored 4f
	# (TKT-P1-12 latitude, extended identically to PREJUMP_F/PREJUMP_B below;
	# logged, docs/judgment-log.md).
	out.append(_build_prejump(STATE_PREJUMP, STATE_JUMP_N))
	out.append(_build_prejump(STATE_PREJUMP_F, STATE_JUMP_F))
	out.append(_build_prejump(STATE_PREJUMP_B, STATE_JUMP_B))

	out.append_array(_build_jump_arcs())

	return out


## One prejump lead-in (AD-039): 4f grounded once-through move whose sole
## CancelRule (condition ALWAYS, input 0 -- no gate) fires on frame 3 (see the
## window-3 rationale above `_build_movement`'s prejump block) into `target`
## (JUMP_N/F/B). PREJUMP/PREJUMP_F/PREJUMP_B differ ONLY in id + target -- the
## shared shape is why this is factored into one builder rather than three
## hand-copies.
static func _build_prejump(state_id: int, target: int) -> MoveState:
	var prejump := MoveState.new()
	prejump.id = state_id
	prejump.category = MoveState.CATEGORY_GROUNDED
	prejump.duration = 4
	prejump.loop = false
	var pj_kf := Keyframe.new()
	pj_kf.frame_start = 1
	pj_kf.frame_end = 4
	pj_kf.hurtboxes = [_hurt_stand()]
	prejump.timeline = [pj_kf]
	var pj_cancel := CancelRule.new()
	pj_cancel.target = target
	pj_cancel.condition = CancelRule.CONDITION_ALWAYS
	pj_cancel.window_start = 3
	pj_cancel.window_end = 3
	pj_cancel.input = 0
	prejump.cancels = [pj_cancel]
	return prejump


## The jump arc (movement table: "~45f airborne, no air dash, no double jump,
## no jump cancels"). Authored as a hand-baked triangular vel_y profile over
## one-frame keyframes (see this file's header note: the engine has no gravity
## primitive, so an arc is authored data, not computed). Rise for 22f, a single
## one-frame APEX HANG (vel_y = 0) at frame 23, then fall for the remaining
## 22f -- symmetric magnitude, sign-flipped either side of the hang. JUMP_N/F/B
## share the same vertical profile; only horizontal carry differs (0 / forward
## / back).
##
## FIX NOTE (2026-07-08 human-inspection-gate flag, "player sinks ~5px below
## the floor on landing"). The original split was 22 rise frames / 23 fall
## frames (JUMP_DURATION=45 is odd, so an even 22/22 split leaves one frame
## over) at EQUAL rise/fall speed -- so the arc's net vertical displacement was
## NOT zero: 22*(-6.0) + 23*(+6.0) = +6.0 units of permanent downward drift
## every single jump (confirmed by driving the arc headlessly: pos_y lands
## exactly 6 units below its start, not "close to" as the prior dev-test
## tolerated -- see test_character_a.gd's _test_jump_arc_integrates, updated
## alongside this fix). Nothing in step_phases.gd clamps pos_y to ground_y
## (P0 movement is pure keyframe integration, AD-014), so that drift was never
## corrected and the character landed standing 6 units into the floor. Rather
## than change either tuned speed value (RISE_SPEED/FALL_SPEED, ratified
## content, JC-A-01), the extra frame is spent as an explicit one-frame apex
## hang (vel_y = 0) -- a common, feel-plausible jump-arc convention -- so
## 22 rise + 1 hang + 22 fall = 45 (JUMP_DURATION unchanged) nets to exactly
## zero and the character always lands flush at ground_y. Determinism-affecting
## (frame-23 vel_y changes from a fall frame to a hang frame, and the whole
## back half of the arc's positions shift up by up to 6 units) -- a deliberate,
## conscious change; recorded per JC-017-style convention in judgment-log.md.
static func _build_jump_arcs() -> Array[MoveState]:
	const JUMP_DURATION: int = 45
	const RISE_FRAMES: int = 22
	const APEX_HANG_FRAME: int = RISE_FRAMES + 1   # frame 23: vel_y = 0
	const RISE_SPEED: float = 6.0    # px/f upward (negative y, screen-up convention: rising is -y)
	const FALL_SPEED: float = 6.0
	const JUMP_HORIZ_SPEED: float = 3.5   # forward/back carry during a directional jump

	var out: Array[MoveState] = []
	var horiz_by_state := {
		STATE_JUMP_N: 0.0,
		STATE_JUMP_F: JUMP_HORIZ_SPEED,
		STATE_JUMP_B: -JUMP_HORIZ_SPEED,
	}
	for state_id in horiz_by_state.keys():
		var m := MoveState.new()
		m.id = state_id
		m.category = MoveState.CATEGORY_AIRBORNE
		m.duration = JUMP_DURATION
		m.loop = false
		var timeline: Array[Keyframe] = []
		for f in range(1, JUMP_DURATION + 1):
			var kf := Keyframe.new()
			kf.frame_start = f
			kf.frame_end = f
			kf.hurtboxes = [_hurt_air()]
			kf.has_motion = true
			kf.motion_vel_x = FP.from_units(horiz_by_state[state_id])
			# Rising (screen -y) for RISE_FRAMES, a single zero-velocity apex-hang
			# frame, then falling (+y) for the symmetric remainder. Baked as
			# CONSTANT velocities (a triangular position curve with a flat apex tick),
			# authored data -- see header/fix note above.
			if f <= RISE_FRAMES:
				kf.motion_vel_y = FP.from_units(-RISE_SPEED)
			elif f == APEX_HANG_FRAME:
				kf.motion_vel_y = 0
			else:
				kf.motion_vel_y = FP.from_units(FALL_SPEED)
			timeline.append(kf)
		m.timeline = timeline
		m.cancels = _air_normal_cancels(JUMP_DURATION)
		out.append(m)
	return out


## Air-normal reachability (AD-039): each of JUMP_N/F/B carries three ALWAYS
## CancelRules -- one per button -- targeting j.L/j.M/j.H. `input` is the raw
## BUTTON_n bitmask (no button_map entry targets a j.* state, so CancelEval.
## _input_buffered's raw-button fallback resolves it directly, exactly as
## AD-039 specifies -- "no button_map entry is needed for the air normals").
## Window [1, duration-1]: open from the first airborne frame through the
## frame before the jump's own duration elapses (frame `duration` itself is
## the jump's "once-through move ended" tick, at which point phase 2's
## actionable-return-to-idle branch already runs ahead of the cancel branch --
## the same reasoning the prejump's own window-below-duration authoring uses
## above, so a button held through the true last frame still lands one frame
## earlier rather than racing the idle-return). This is NOT a "jump cancel" in
## the movement table's sense (a grounded normal cancelling INTO a jump, which
## stays unauthored) -- it is the airborne character's OWN move (the jump arc)
## cancelling into an air normal, the mechanism AD-039 names.
static func _air_normal_cancels(jump_duration: int) -> Array[CancelRule]:
	var targets := [
		[STATE_JL, InputFrame.BUTTON_0],
		[STATE_JM, InputFrame.BUTTON_1],
		[STATE_JH, InputFrame.BUTTON_2],
	]
	var rules: Array[CancelRule] = []
	for t in targets:
		var r := CancelRule.new()
		r.target = t[0]
		r.condition = CancelRule.CONDITION_ALWAYS
		r.window_start = 1
		r.window_end = jump_duration - 1
		r.input = t[1]
		rules.append(r)
	return rules


# =============================================================================
# Normals (character-a.md -> Normals table + Damage & stun table).
#
# Every cancellable normal (5L/5M/2L/2M) grants TAG_SP on connect and carries
# SIX CancelRules -- one per concrete special-state target (fireball L/M/H,
# DP L/M/H) -- because CancelRule.target_is_group is deferred (JC-023: no
# group-target resolution exists yet), so a single "> special" intent is
# authored as six concrete rules, all gated by the same requires_tag/condition/
# window and differing only in `target`/`input`. This is a mechanical
# consequence of the existing engine, not a design choice -- logged.
# =============================================================================
static func _build_normals() -> Array[MoveState]:
	var out: Array[MoveState] = []
	out.append(_build_5l())
	out.append(_build_5m())
	out.append(_build_5h())
	out.append(_build_2l())
	out.append(_build_2m())
	out.append(_build_2h())
	out.append(_build_jl())
	out.append(_build_jm())
	out.append(_build_jh())
	return out


## The six special-cancel CancelRules shared by every "> 236/623" cancellable
## normal (5L/5M/2L/2M). `window_end` is the move's own duration (cancel legal
## from first-active through the whole recovery, per character-a.md "on
## contact" blockstring pressure). Condition ON_CONTACT (hit OR block).
static func _special_cancels(move_duration: int) -> Array[CancelRule]:
	var targets := [
		[STATE_FIREBALL_L, InputFrame.BUTTON_0],
		[STATE_FIREBALL_M, InputFrame.BUTTON_1],
		[STATE_FIREBALL_H, InputFrame.BUTTON_2],
		[STATE_DP_L, InputFrame.BUTTON_0],
		[STATE_DP_M, InputFrame.BUTTON_1],
		[STATE_DP_H, InputFrame.BUTTON_2],
	]
	var rules: Array[CancelRule] = []
	for pair in targets:
		var r := CancelRule.new()
		r.target = pair[0]
		r.condition = CancelRule.CONDITION_ON_CONTACT
		r.window_start = 0   # default: first-active -> end
		r.window_end = 0
		r.input = pair[1]
		r.requires_tag = TAG_SP
		rules.append(r)
	return rules


## 5L: 4 startup / 3 active / 6 recovery. dmg 30, blockstun 9, hitstun 12,
## hitstop 8. On block +1, on hit +4 (hand-check: 12-(6+3-1)=4; 9-8=1).
static func _build_5l() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_5L
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 13   # 4 startup + 3 active + 6 recovery
	m.loop = false
	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = 4
	kf_start.hurtboxes = [_hurt_stand()]
	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(25), FP.from_int(-65), FP.from_int(25), FP.from_int(20))   # AD-037 reflected
	hb.damage = 30
	hb.hitstun = 12
	hb.blockstun = 9
	hb.hitstop = 8
	hb.pushback_hit = FP.from_units(2.0)
	hb.pushback_block = FP.from_units(2.0)
	hb.hit_reaction = STATE_HITSTUN
	hb.block_reaction = STATE_BLOCKSTUN
	hb.id_group = IDG_5L
	hb.cancel_tags = PackedInt32Array([TAG_SP])
	var kf_active := Keyframe.new()
	kf_active.frame_start = 5
	kf_active.frame_end = 7
	kf_active.hurtboxes = [_hurt_stand()]
	kf_active.hitboxes = [hb]
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 8
	kf_rec.frame_end = 13
	kf_rec.hurtboxes = [_hurt_stand()]
	m.timeline = [kf_start, kf_active, kf_rec]
	m.cancels = _special_cancels(m.duration)
	return m


## 5M: 5 startup / 4 active / 11 recovery. dmg 60, blockstun 12, hitstun 16,
## hitstop 9. On block -2, on hit +2 (hand-check: 16-(11+4-1)=2; 12-14=-2).
static func _build_5m() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_5M
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 20   # 5 + 4 + 11
	m.loop = false
	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = 5
	kf_start.hurtboxes = [_hurt_stand()]
	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(25), FP.from_int(-62), FP.from_int(30), FP.from_int(22))   # AD-037 reflected
	hb.damage = 60
	hb.hitstun = 16
	hb.blockstun = 12
	hb.hitstop = 9
	hb.pushback_hit = FP.from_units(3.0)
	hb.pushback_block = FP.from_units(3.0)
	hb.hit_reaction = STATE_HITSTUN
	hb.block_reaction = STATE_BLOCKSTUN
	hb.id_group = IDG_5M
	hb.cancel_tags = PackedInt32Array([TAG_SP])
	var kf_active := Keyframe.new()
	kf_active.frame_start = 6
	kf_active.frame_end = 9
	kf_active.hurtboxes = [_hurt_stand()]
	kf_active.hitboxes = [hb]
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 10
	kf_rec.frame_end = 20
	kf_rec.hurtboxes = [_hurt_stand()]
	m.timeline = [kf_start, kf_active, kf_rec]
	m.cancels = _special_cancels(m.duration)
	return m


## 5H: 25 startup / 3 active / 13 recovery, forward-advancing (~30px over
## startup+active). dmg 80, blockstun 18, hitstun 22, hitstop 11. On block +3,
## on hit +7 (hand-check: 22-(13+3-1)=7; 18-15=3). NOT cancellable (its reward
## is the 5H,5M link, character-a.md criterion 3) -- authored with NO
## CancelRules. Advances forward via keyframe motion during startup+active.
static func _build_5h() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_5H
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 41   # 25 + 3 + 13
	m.loop = false
	# Forward advance spread over the 28 frames up to and including active
	# (25 startup + 3 active): ~30px / 28f ~= 1.07 px/f.
	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = 25
	kf_start.hurtboxes = [_hurt_stand()]
	kf_start.has_motion = true
	kf_start.motion_vel_x = FP.from_units(1.07)
	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(30), FP.from_int(-60), FP.from_int(35), FP.from_int(25))   # AD-037 reflected
	hb.damage = 80
	hb.hitstun = 22
	hb.blockstun = 18
	hb.hitstop = 11
	hb.pushback_hit = FP.from_units(2.0)
	hb.pushback_block = FP.from_units(3.0)
	hb.hit_reaction = STATE_HITSTUN
	hb.block_reaction = STATE_BLOCKSTUN
	hb.id_group = IDG_5H
	# NO cancel_tags: 5H is not special-cancellable (its reward is the LINK,
	# not a cancel -- character-a.md criterion 3/9). The 5H,5M link itself is
	# not a CancelRule at all: it is the ordinary "press 5M once actionable"
	# path, made TIGHT by 5H's own +7 on-hit advantage vs 5M's 5-frame startup
	# (7 - 5 = a 2-frame-late window before 5M would otherwise whiff -- see
	# the judgment-log entry on how the "3-frame link" is authored/verified).
	var kf_active := Keyframe.new()
	kf_active.frame_start = 26
	kf_active.frame_end = 28
	kf_active.hurtboxes = [_hurt_stand()]
	kf_active.hitboxes = [hb]
	kf_active.has_motion = true
	kf_active.motion_vel_x = FP.from_units(1.07)
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 29
	kf_rec.frame_end = 41
	kf_rec.hurtboxes = [_hurt_stand()]
	m.timeline = [kf_start, kf_active, kf_rec]
	m.cancels = []
	return m


## 2L: 4 startup / 3 active / 7 recovery, low. dmg 20, blockstun 10, hitstun
## 15, hitstop 8. On-block reconciles exactly (10-(7+3-1)=1, matching the
## spec's stated +1); on-hit does NOT (15-9=6, not the spec's stated +3) --
## the spec's own Normals-table "+3" and Damage-table "hitstun 15" don't
## reconcile via the one canonical formula (move-format.md AD-008) given
## startup/active/recovery 4/3/7. Authored to the INTERNALLY CONSISTENT
## reading (hitstun 15, deriving to +6) rather than silently picking whichever
## side of the contradiction to force -- move-format.md criterion 2 / the
## tuning-status note explicitly say exact table numbers are provisional and
## QA verifies derivation-consistency, not an exact match to the table, so
## this is the correct data-only reading; logged (docs/judgment-log.md) since
## a future tuning pass may want to close the gap by adjusting recovery
## instead of hitstun.
static func _build_2l() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_2L
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 14   # 4 + 3 + 7
	m.loop = false
	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = 4
	kf_start.hurtboxes = [_hurt_crouch()]
	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(20), FP.from_int(-20), FP.from_int(25), FP.from_int(15))   # AD-037 reflected
	hb.damage = 20
	hb.hitstun = 15
	hb.blockstun = 10
	hb.hitstop = 8
	hb.pushback_hit = FP.from_units(1.5)
	hb.pushback_block = FP.from_units(1.5)
	hb.hit_reaction = STATE_HITSTUN
	hb.block_reaction = STATE_CROUCH_BLOCKSTUN
	hb.id_group = IDG_2L
	hb.cancel_tags = PackedInt32Array([TAG_SP])
	var kf_active := Keyframe.new()
	kf_active.frame_start = 5
	kf_active.frame_end = 7
	kf_active.hurtboxes = [_hurt_crouch()]
	kf_active.hitboxes = [hb]
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 8
	kf_rec.frame_end = 14
	kf_rec.hurtboxes = [_hurt_crouch()]
	m.timeline = [kf_start, kf_active, kf_rec]
	m.cancels = _special_cancels(m.duration)
	return m


## 2M: 6 startup / 3 active / 13 recovery -- "the signature poke," long range.
## dmg 70, blockstun 14, hitstun 18, hitstop 10. On block -1, on hit +3.
static func _build_2m() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_2M
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 22   # 6 + 3 + 13
	m.loop = false
	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = 6
	kf_start.hurtboxes = [_hurt_crouch()]
	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(30), FP.from_int(-28), FP.from_int(45), FP.from_int(18))   # long range; AD-037 reflected
	hb.damage = 70
	hb.hitstun = 18
	hb.blockstun = 14
	hb.hitstop = 10
	hb.pushback_hit = FP.from_units(1.0)   # low pushback (allows the cancel, per spec)
	hb.pushback_block = FP.from_units(1.0)
	hb.hit_reaction = STATE_HITSTUN
	hb.block_reaction = STATE_CROUCH_BLOCKSTUN
	hb.id_group = IDG_2M
	hb.cancel_tags = PackedInt32Array([TAG_SP])
	var kf_active := Keyframe.new()
	kf_active.frame_start = 7
	kf_active.frame_end = 9
	kf_active.hurtboxes = [_hurt_crouch()]
	kf_active.hitboxes = [hb]
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 10
	kf_rec.frame_end = 22
	kf_rec.hurtboxes = [_hurt_crouch()]
	m.timeline = [kf_start, kf_active, kf_rec]
	m.cancels = _special_cancels(m.duration)
	return m


## 2H: 5 startup / 3 active / 13 recovery -- fast get-off-me anti-air.
## Upper-body strike invuln 1-8 (authored on the keyframes per spec and enforced
## by the engine -- step_phases.gd phase 4 consumes invuln per AD-031/TKT-P1-11;
## see this file's header note and game/tests/test_invuln.gd). dmg 60, blockstun
## 13, hitstun N/A (air reset, no combo -- see STATE_AIR_RESET), hitstop 10.
## NOT cancellable (anti-air, character-a.md).
static func _build_2h() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_2H
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 21   # 5 + 3 + 13
	m.loop = false
	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = 5
	kf_start.hurtboxes = [_hurt_crouch()]
	kf_start.invuln_strike = true   # frames 1-8 per spec; consumed in phase 4 (AD-031)
	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(15), FP.from_int(-90), FP.from_int(35), FP.from_int(60))   # tall anti-air box; AD-037 reflected
	hb.damage = 60
	hb.hitstun = 20   # air reset stun (defender knocked away, no follow-up)
	hb.blockstun = 13
	hb.hitstop = 10
	hb.pushback_hit = FP.from_units(3.0)
	hb.pushback_block = FP.from_units(2.0)
	hb.launch = FP.from_units(-4.0)   # knocks the airborne foe away/up, no juggle follow-up authored
	hb.hit_reaction = STATE_AIR_RESET
	hb.block_reaction = STATE_CROUCH_BLOCKSTUN
	hb.id_group = IDG_2H
	# no cancel_tags: 2H grants no special-cancel (anti-air, no combo on hit).
	var kf_active := Keyframe.new()
	kf_active.frame_start = 6
	kf_active.frame_end = 8
	kf_active.hurtboxes = [_hurt_crouch()]
	kf_active.hitboxes = [hb]
	kf_active.invuln_strike = true   # invuln through frame 8 (end of active) per spec
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 9
	kf_rec.frame_end = 21
	kf_rec.hurtboxes = [_hurt_crouch()]
	m.timeline = [kf_start, kf_active, kf_rec]
	m.cancels = []
	return m


## j.L: 4 startup / 6 active, air-to-air. dmg 30, hitstop 9. No block/ground
## advantage authored here (height-dependent, sim truth per spec -- the
## training mode reads it out live, not a fixed table number). Uses the
## generic hit/block reaction states; height-dependent hitstun is a live-sim
## question the spec explicitly defers, so this authors the BASE hitstun the
## table gives ("scales w/ height") as the flat authored value the format
## supports -- there is no per-height hitstun field in move-format.md, so a
## single authored value is the correct data-only reading (the "scaling"
## language in the spec describes sim behavior -- pushback/juggle physics
## -- outside the move-format schema, not a missing field here).
static func _build_jl() -> MoveState:
	return _build_air_normal(STATE_JL, 4, 6, 30, 9, IDG_JL,
		Box.make(FP.from_int(15), FP.from_int(-40), FP.from_int(25), FP.from_int(20)))   # AD-037 reflected


## j.M: 6 startup / 5 active, air-to-air / jump-in. dmg 50, hitstop 10.
static func _build_jm() -> MoveState:
	return _build_air_normal(STATE_JM, 6, 5, 50, 10, IDG_JM,
		Box.make(FP.from_int(15), FP.from_int(-40), FP.from_int(30), FP.from_int(25)))   # AD-037 reflected


## j.H: 8 startup / 5 active -- the jump-in starter (deep hit links into
## 5M/2M -- a live-sim confirm the training mode surfaces, not authored here).
## dmg 80, hitstop 11.
static func _build_jh() -> MoveState:
	return _build_air_normal(STATE_JH, 8, 5, 80, 11, IDG_JH,
		Box.make(FP.from_int(15), FP.from_int(-40), FP.from_int(35), FP.from_int(30)))   # AD-037 reflected


## Shared air-normal builder: startup (airborne hurtbox only), active (+ hitbox),
## no authored recovery tail beyond active (air normals recover on landing --
## the format has no "land" event, so the state ends at the end of active;
## landing/actionability is a live-sim concern already handled by the
## once-through-move-ended -> idle transition once frame_in_state exceeds
## duration). category AIRBORNE (does not affect physics -- see header note --
## but is the correct engine-level category label per move-format.md).
static func _build_air_normal(state_id: int, startup: int, active: int, damage: int,
		hitstop: int, id_group: int, hitbox_box: Box) -> MoveState:
	var m := MoveState.new()
	m.id = state_id
	m.category = MoveState.CATEGORY_AIRBORNE
	m.duration = startup + active
	m.loop = false
	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = startup
	kf_start.hurtboxes = [_hurt_air()]
	var hb := HitBox.new()
	hb.box = hitbox_box
	hb.damage = damage
	hb.hitstun = 14        # baseline height-dependent hitstun (see header note)
	hb.blockstun = 8
	hb.hitstop = hitstop
	hb.pushback_hit = FP.from_units(1.0)
	hb.pushback_block = FP.from_units(1.0)
	hb.hit_reaction = STATE_HITSTUN
	hb.block_reaction = STATE_BLOCKSTUN
	hb.id_group = id_group
	# No cancel_tags: air normals are not special-cancellable (character-a.md:
	# "all air normals" listed under Not cancellable).
	var kf_active := Keyframe.new()
	kf_active.frame_start = startup + 1
	kf_active.frame_end = startup + active
	kf_active.hurtboxes = [_hurt_air()]
	kf_active.hitboxes = [hb]
	m.timeline = [kf_start, kf_active]
	m.cancels = []
	return m


# =============================================================================
# Reaction states (forced hit/block/throw/air-reset reactions).
# =============================================================================
static func _build_reactions() -> Array[MoveState]:
	var out: Array[MoveState] = []

	var hitstun := MoveState.new()
	hitstun.id = STATE_HITSTUN
	hitstun.category = MoveState.CATEGORY_HITSTUN
	hitstun.duration = 22   # covers the longest authored hitstun (5H, 22f); stun clamps frame_in_state (JC-019)
	hitstun.loop = false
	var hs_kf := Keyframe.new()
	hs_kf.frame_start = 1
	hs_kf.frame_end = hitstun.duration
	hs_kf.hurtboxes = [_hurt_stand()]
	hitstun.timeline = [hs_kf]
	out.append(hitstun)

	var blockstun := MoveState.new()
	blockstun.id = STATE_BLOCKSTUN
	blockstun.category = MoveState.CATEGORY_BLOCKSTUN
	blockstun.duration = 18   # covers the longest authored blockstun (5H, 18f)
	blockstun.loop = false
	var bs_kf := Keyframe.new()
	bs_kf.frame_start = 1
	bs_kf.frame_end = blockstun.duration
	bs_kf.hurtboxes = [_hurt_stand()]
	blockstun.timeline = [bs_kf]
	out.append(blockstun)

	var crouch_blockstun := MoveState.new()
	crouch_blockstun.id = STATE_CROUCH_BLOCKSTUN
	crouch_blockstun.category = MoveState.CATEGORY_BLOCKSTUN
	crouch_blockstun.duration = 14   # longest crouch-blocked hit (2M, 14f)
	crouch_blockstun.loop = false
	var cbs_kf := Keyframe.new()
	cbs_kf.frame_start = 1
	cbs_kf.frame_end = crouch_blockstun.duration
	cbs_kf.hurtboxes = [_hurt_crouch()]
	crouch_blockstun.timeline = [cbs_kf]
	out.append(crouch_blockstun)

	# AIR_RESET: 2H's "no follow-up" knock-away. A HITSTUN-category state (so
	# it is a real, actionable-after reaction) authored long enough that no
	# combo continuation is possible before the defender lands/recovers,
	# matching "no combo" (criterion 4). No hitbox of its own.
	var air_reset := MoveState.new()
	air_reset.id = STATE_AIR_RESET
	air_reset.category = MoveState.CATEGORY_HITSTUN
	air_reset.duration = 20
	air_reset.loop = false
	var ar_kf := Keyframe.new()
	ar_kf.frame_start = 1
	ar_kf.frame_end = air_reset.duration
	ar_kf.hurtboxes = [_hurt_air()]
	air_reset.timeline = [ar_kf]
	out.append(air_reset)

	# THROWN: forced throw reaction (defender). Duration matches THROW's
	# authored hitstun.
	var thrown := MoveState.new()
	thrown.id = STATE_THROWN
	thrown.category = MoveState.CATEGORY_HITSTUN
	thrown.duration = 30   # hard-knockdown tail (oki setup window)
	thrown.loop = false
	var th_kf := Keyframe.new()
	th_kf.frame_start = 1
	th_kf.frame_end = thrown.duration
	th_kf.hurtboxes = [_hurt_stand()]
	thrown.timeline = [th_kf]
	out.append(thrown)

	# HITSTUN_LAUNCH: DP's launch -> hard-knockdown reaction (distinct from the
	# plain HITSTUN so a launched defender's authored duration covers the
	# hard-knockdown oki window character-a.md describes for DP/throw).
	var launch := MoveState.new()
	launch.id = STATE_HITSTUN_LAUNCH
	launch.category = MoveState.CATEGORY_HITSTUN
	launch.duration = 40
	launch.loop = false
	var hl_kf := Keyframe.new()
	hl_kf.frame_start = 1
	hl_kf.frame_end = launch.duration
	hl_kf.hurtboxes = [_hurt_air()]
	launch.timeline = [hl_kf]
	out.append(launch)

	return out


# =============================================================================
# Fireball -- 236 L/M/H (character-a.md -> Specials -> Fireball; AD-021/030).
#
# Release timing (AD-030): the spawn keyframe's frame_start IS the release
# frame (14). It fires once per keyframe range. Travel/aging begins frame 15
# (one-tick offset, AD-030/JC-034) -- speeds below are tuned as the RAW
# authored velocity; the projectile's own reach is simply
# speed * (lifetime - 0) frames of travel starting tick 15, which is what
# "tune reach against the offset" means (the lifetime already only counts
# ticks 15+, so no extra adjustment is needed beyond authoring lifetime as
# "frames of travel from tick 15").
# =============================================================================
static func _build_fireballs() -> Array[MoveState]:
	var out: Array[MoveState] = []
	out.append(_build_fireball(STATE_FIREBALL_L, PROJ_FIREBALL_L, 5.0))
	out.append(_build_fireball(STATE_FIREBALL_M, PROJ_FIREBALL_M, 7.0))
	out.append(_build_fireball(STATE_FIREBALL_H, PROJ_FIREBALL_H, 9.0))
	return out


const FIREBALL_SPAWN_FRAME: int = 14
const FIREBALL_CHAR_STARTUP: int = 13   # frames 1-13, spawn fires on frame 14
const FIREBALL_CHAR_RECOVERY: int = 30
const FIREBALL_DAMAGE: int = 60
const FIREBALL_HITSTUN: int = 16
const FIREBALL_BLOCKSTUN: int = 12
const FIREBALL_HITSTOP: int = 8
const FIREBALL_LIFETIME: int = 60   # frames of travel from tick 15 onward (off-stage despawn also applies)
const FIREBALL_MAX_PER_OWNER: int = 1


static func _build_fireball(state_id: int, proj_id: int, speed: float) -> MoveState:
	var m := MoveState.new()
	m.id = state_id
	m.category = MoveState.CATEGORY_GROUNDED
	# duration = char startup (13) + 1 spawn frame (14) + char recovery (30) = 44.
	m.duration = FIREBALL_CHAR_STARTUP + 1 + FIREBALL_CHAR_RECOVERY
	m.loop = false

	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = FIREBALL_SPAWN_FRAME - 1   # 1..13
	kf_start.hurtboxes = [_hurt_stand()]

	var kf_spawn := Keyframe.new()
	kf_spawn.frame_start = FIREBALL_SPAWN_FRAME      # 14: the release frame (AD-030)
	kf_spawn.frame_end = FIREBALL_SPAWN_FRAME        # fires ONCE, this exact frame
	kf_spawn.hurtboxes = [_hurt_stand()]
	kf_spawn.has_spawn = true
	kf_spawn.spawn_projectile = _build_projectile_data(proj_id, speed)
	kf_spawn.spawn_offset_x = FP.from_int(25)        # released in front of the character
	kf_spawn.spawn_offset_y = FP.from_int(-45)       # AD-037: reflected (scalar point, spawn_y = pos_y + offset_y) -- chest/hand height, now above the feet-origin
	kf_spawn.spawn_velocity_x = FP.from_units(speed)
	kf_spawn.spawn_velocity_y = 0

	var kf_rec := Keyframe.new()
	kf_rec.frame_start = FIREBALL_SPAWN_FRAME + 1
	kf_rec.frame_end = m.duration
	kf_rec.hurtboxes = [_hurt_stand()]

	m.timeline = [kf_start, kf_spawn, kf_rec]
	m.cancels = []   # the fireball itself is not a cancel target FROM anywhere further
	return m


## The authored ProjectileData shell (AD-030): only id/hitbox/lifetime/
## max_per_owner. owner and initial position/velocity come from the cast +
## the spawn keyframe (authored above), NOT here.
static func _build_projectile_data(proj_id: int, speed: float) -> ProjectileData:
	var data := ProjectileData.new()
	data.id = proj_id
	data.lifetime = FIREBALL_LIFETIME
	data.max_per_owner = FIREBALL_MAX_PER_OWNER
	var hb := HitBox.new()
	# AD-037: NOT reflected -- this box is symmetric about the projectile's own
	# center ([-12,+12], not feet-anchored), so new_y = -(y+h) = -(-12+24) = -12,
	# unchanged by construction (a projectile has no "feet line" to reflect
	# against; its local origin IS its center).
	hb.box = Box.make(FP.from_int(-12), FP.from_int(-12), FP.from_int(24), FP.from_int(24))
	hb.hit_kind = HitBox.HIT_KIND_PROJECTILE   # AD-031: a projectile's carried hitbox is PROJECTILE
	hb.damage = FIREBALL_DAMAGE
	hb.hitstun = FIREBALL_HITSTUN
	hb.blockstun = FIREBALL_BLOCKSTUN
	hb.hitstop = FIREBALL_HITSTOP
	hb.pushback_hit = FP.from_units(2.0)
	hb.pushback_block = FP.from_units(1.0)
	hb.hit_reaction = STATE_HITSTUN
	hb.block_reaction = STATE_BLOCKSTUN
	hb.id_group = IDG_FIREBALL_L if proj_id == PROJ_FIREBALL_L \
		else (IDG_FIREBALL_M if proj_id == PROJ_FIREBALL_M else IDG_FIREBALL_H)
	hb.rehit_interval = 0
	data.hitbox = hb
	return data


## A ProjectileRegistry roster (data_id -> ProjectileData) for A's three
## fireball strengths. Callers that spawn/restore A's fireballs must
## ProjectileRegistry.install() this (mirrors TestSupport.build_projectile_registry).
static func build_projectile_registry() -> Dictionary:
	var l := _build_projectile_data(PROJ_FIREBALL_L, 5.0)
	var mm := _build_projectile_data(PROJ_FIREBALL_M, 7.0)
	var h := _build_projectile_data(PROJ_FIREBALL_H, 9.0)
	return {l.id: l, mm.id: mm, h.id: h}


# =============================================================================
# Shoryuken -- 623 L/M/H (character-a.md -> Specials -> Shoryuken).
# =============================================================================
static func _build_shoryukens() -> Array[MoveState]:
	var out: Array[MoveState] = []
	out.append(_build_dp_l())
	out.append(_build_dp_m())
	out.append(_build_dp_h())
	return out


## 623L: startup 3, invuln strike 1-5, active 8, recovery 28+12(land)=40.
## dmg 100, launch -> hard KD. On block ~-34: attacker recovery from
## first-active = (40 + 8 - 1) = 47; defender's blockstun would need to be
## 13 for -34 -- DP has no blockstun table entry (character-a.md gives only
## an approximate on-block number, "the risk"), so blockstun is authored as a
## small value consistent with "full-punishable" (criterion 6: even 25f 5H
## punishes) rather than back-solved to hit -34 exactly -- see judgment-log.
static func _build_dp_l() -> MoveState:
	return _build_dp(STATE_DP_L, 3, 5, 8, 28, 12, 100, IDG_DP_L_HIT1, -1)


## 623M: startup 4, invuln strike 1-6, active 8, recovery 30+12. dmg 130.
static func _build_dp_m() -> MoveState:
	return _build_dp(STATE_DP_M, 4, 6, 8, 30, 12, 130, IDG_DP_M_HIT1, -1)


## 623H: startup 5, invuln strike+throw 1-8, active 10 (2 hits), recovery
## 33+14. dmg 160 (2-hit launch). Second hit authored as a distinct id_group
## (IDG_DP_H_HIT2) on a later keyframe within the active window -- a
## sequential multi-hit per AD-016 (two distinct id_groups, each lands once).
static func _build_dp_h() -> MoveState:
	return _build_dp(STATE_DP_H, 5, 8, 10, 33, 14, 160, IDG_DP_H_HIT1, IDG_DP_H_HIT2)


const DP_BLOCKSTUN: int = 10   # small, deliberately not back-solved to an exact -34..-40 (see judgment-log)
const DP_HITSTOP: int = 12


## Shared DP builder. `startup`, `invuln_end` (invuln through this frame,
## inclusive), `active`, `recovery`, `land` (extra recovery tail), `damage`,
## `id_group1`, `id_group2` (-1 for a single-hit DP; a real id for 623H's
## second hit, placed on the LAST active frame so both hits land within the
## authored active window).
static func _build_dp(state_id: int, startup: int, invuln_end: int, active: int,
		recovery: int, land: int, damage: int, id_group1: int, id_group2: int) -> MoveState:
	var m := MoveState.new()
	m.id = state_id
	m.category = MoveState.CATEGORY_GROUNDED
	var total_recovery: int = recovery + land
	m.duration = startup + active + total_recovery
	m.loop = false

	var timeline: Array[Keyframe] = []

	# Startup carries invuln_strike throughout (1..startup); if invuln_end
	# extends past startup into the active window (e.g. 623H: startup 5,
	# invuln through 8), the active keyframe below ALSO carries invuln_strike
	# to cover the remainder.
	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = startup
	kf_start.hurtboxes = [_hurt_stand()]
	kf_start.invuln_strike = true
	if state_id == STATE_DP_H:
		kf_start.invuln_throw = true   # 623H also throw-invulnerable (character-a.md)
	timeline.append(kf_start)

	var first_active: int = startup + 1
	var last_active: int = startup + active

	var hb1 := HitBox.new()
	hb1.box = Box.make(FP.from_int(10), FP.from_int(-75), FP.from_int(35), FP.from_int(55))   # AD-037 reflected
	hb1.damage = damage if id_group2 == -1 else int(damage * 0.6)   # 2-hit DP splits damage across both hits
	hb1.hitstun = 30
	hb1.blockstun = DP_BLOCKSTUN
	hb1.hitstop = DP_HITSTOP
	hb1.pushback_hit = FP.from_units(1.0)
	hb1.pushback_block = FP.from_units(3.0)
	hb1.launch = FP.from_units(-6.0)
	hb1.hit_reaction = STATE_HITSTUN_LAUNCH
	hb1.block_reaction = STATE_BLOCKSTUN
	hb1.id_group = id_group1

	var kf_active := Keyframe.new()
	kf_active.frame_start = first_active
	kf_active.frame_end = last_active
	kf_active.hurtboxes = [_hurt_air()]   # DP leaves the ground; airborne-shaped hurtbox during active
	kf_active.hitboxes = [hb1]
	# Invuln coverage extending into the active window (e.g. 623H: through frame 8).
	if invuln_end > startup:
		kf_active.invuln_strike = true
		if state_id == STATE_DP_H:
			kf_active.invuln_throw = true
	timeline.append(kf_active)

	# Second hit for 623H: a distinct id_group on the LAST active frame only
	# (a genuine second keyframe so AD-016's sequential multi-hit applies --
	# two distinct id_groups, each lands once).
	if id_group2 != -1:
		var hb2 := HitBox.new()
		hb2.box = Box.make(FP.from_int(10), FP.from_int(-55), FP.from_int(35), FP.from_int(45))   # AD-037 reflected
		hb2.damage = damage - hb1.damage
		hb2.hitstun = 30
		hb2.blockstun = DP_BLOCKSTUN
		hb2.hitstop = DP_HITSTOP
		hb2.pushback_hit = FP.from_units(1.0)
		hb2.pushback_block = FP.from_units(3.0)
		hb2.launch = FP.from_units(-8.0)
		hb2.hit_reaction = STATE_HITSTUN_LAUNCH
		hb2.block_reaction = STATE_BLOCKSTUN
		hb2.id_group = id_group2
		var kf_hit2 := Keyframe.new()
		kf_hit2.frame_start = last_active
		kf_hit2.frame_end = last_active
		kf_hit2.hurtboxes = [_hurt_air()]
		kf_hit2.hitboxes = [hb1, hb2]   # both hitboxes active this one frame; distinct id_groups
		if invuln_end >= last_active:
			kf_hit2.invuln_strike = true
			kf_hit2.invuln_throw = true
		# Replace the tail of kf_active with kf_hit2 covering just the last frame:
		# shrink kf_active's range so ranges don't overlap-duplicate the hitbox.
		kf_active.frame_end = last_active - 1
		timeline.append(kf_hit2)

	var kf_rec := Keyframe.new()
	kf_rec.frame_start = last_active + 1
	kf_rec.frame_end = m.duration
	kf_rec.hurtboxes = [_hurt_stand()]
	timeline.append(kf_rec)

	m.timeline = timeline
	m.cancels = []   # DP is not itself cancellable into anything (terminal, whiff or connect)
	return m


# =============================================================================
# Throw -- L+H (character-a.md -> Specials -> Throw; AD-016/029).
# =============================================================================
const THROW_STARTUP: int = 5
const THROW_RANGE_PX: float = 60.0
const THROW_TECH_WINDOW: int = 7
const THROW_WHIFF_RECOVERY: int = 20
const THROW_DAMAGE: int = 120
const THROW_HITSTUN: int = 30   # hard-knockdown duration -- StepPhases._resolve_throw sets
								  # def.stun = hb.hitstun directly, so THIS is what actually
								  # keeps the thrown defender down; must match (or exceed)
								  # STATE_THROWN's authored duration below, not a placeholder.


static func _build_throw() -> Array[MoveState]:
	var m := MoveState.new()
	m.id = STATE_THROW
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = THROW_STARTUP + THROW_WHIFF_RECOVERY   # whiff recovery timing; a connect exits early via the reaction path
	m.loop = false

	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = THROW_STARTUP - 1
	kf_start.hurtboxes = [_hurt_stand()]

	var tb := HitBox.new()
	tb.box = Box.make(FP.from_int(10), FP.from_int(-60), FP.from_int(60), FP.from_int(60))   # ~60px range; AD-037 reflected
	tb.damage = THROW_DAMAGE
	tb.hitstun = THROW_HITSTUN   # the hard-knockdown length (see const note above)
	tb.tech_window = THROW_TECH_WINDOW
	tb.pushback_hit = FP.from_units(2.0)
	tb.hitstop = 0
	tb.hit_reaction = STATE_THROWN
	tb.block_reaction = STATE_THROWN   # unused (throws bypass block) but authored for schema completeness
	tb.id_group = IDG_THROW
	tb.is_throw = true

	var kf_active := Keyframe.new()
	kf_active.frame_start = THROW_STARTUP
	kf_active.frame_end = THROW_STARTUP
	kf_active.hurtboxes = [_hurt_stand()]
	kf_active.throwboxes = []
	kf_active.hitboxes = [tb]   # throwbox authored as a HitBox with is_throw (matches TestSupport's pattern)

	var kf_rec := Keyframe.new()
	kf_rec.frame_start = THROW_STARTUP + 1
	kf_rec.frame_end = m.duration
	kf_rec.hurtboxes = [_hurt_stand()]

	m.timeline = [kf_start, kf_active, kf_rec]
	m.cancels = []
	return [m]
