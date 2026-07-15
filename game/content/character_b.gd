class_name CharacterB
extends RefCounted

## Character B — the pressure/air-mobility character (character-b.md; TKT-P2-05).
## PART 1 (this file, so far): the six chainable normals + the strength-ladder
## gatling cancels (AD-044), the two dedicated command normals (5H/6H/2H), the
## throw (existing AD-016/029 model — no new throw rules), and ground movement
## (walk/dash/jump wiring over AD-043/046, already-built engine capabilities).
## Air toolkit + specials (divekicks, low slide, arc projectile) are TKT-P2-06's
## job and are NOT authored here. Authored PURELY as data (move-format.md
## criterion 1 / character-b.md criterion 1) — no character-specific engine
## code; B and A resolve frame data through the exact same code path.
##
## CONTENT SOURCE (mirrors character_a.gd's role): `tools/bake_character_b.gd`
## calls `build_character()` and ResourceSaver.save()s the result to
## `data/character-b.tres`; `game/tests/test_character_b.gd` builds the SAME
## character via this one function — one authored definition, two consumers.
##
## All spatial/physics values are BAKED FIXED-POINT integers (AD-014). Frame
## counts, damage, stun are plain ints. Every numeric value below not pinned by
## `character-b.md`'s own table (damage/stun/hitstop, hurtbox/hitbox geometry,
## gravity/jump/dash speeds) is Developer-provisional tuning (the spec's own
## header: "frame numbers, box geometry, and the exact tuning values here are
## slice-provisional") — recorded in docs/judgment-log.md, not re-litigated here.
##
## FLAGGED ENGINE GAP (docs/flags.md, raised with this ticket): AD-044's "lights
## self-chain, including exact repeat" (5L->5L, 2L->2L) does NOT currently fire.
## CancelEval.find_cancel rejects ANY cancel (concrete or group-resolved) whose
## destination equals the player's CURRENT state_id (`target == p.state_id` /
## `group_target == p.state_id` -> `continue`), and phase2_state_machine's own
## ordinary actionable/buffered-command branch carries an identical guard
## (`target_state != p.state_id`). This predates AD-044 (P0 code, before any
## character needed self-repeat) and was never exercised by a test until this
## ticket. Verified empirically (a scratch trace: a concrete on_contact,
## input-gateless cancel targeting the attacker's OWN state never fires — the
## state's frame_in_state keeps advancing instead of resetting to 1). B's
## 5L/2L are authored below EXACTLY as AD-044 specifies (their ladder group
## includes themselves), so no re-authoring is needed once the gap is fixed —
## only the CURRENTLY-BLOCKED transition (5L->5L, 2L->2L) is affected; every
## cross-state ladder transition (5L->2L, 2L->5M, 5M->2M, 2M->2H, 2H->5H, 5H->2H,
## …) is unaffected and verified working in test_character_b.gd. This is an
## engine-capability question ("no engine change" is this ticket's explicit
## scope), not a data-authoring gap — flagged to the Architect/Strategist rather
## than patched here.

const CHAR_ID: int = 3

# --- Movement states ---------------------------------------------------------
const STATE_IDLE: int = 300
const STATE_WALK_F: int = 301
const STATE_WALK_B: int = 302
const STATE_DASH_F: int = 303
const STATE_DASH_B: int = 304
const STATE_CROUCH: int = 305
const STATE_PREJUMP: int = 306
const STATE_JUMP_N: int = 307
const STATE_JUMP_F: int = 308
const STATE_JUMP_B: int = 309
# Directional prejump lead-ins (AD-039), mirrors character_a.gd exactly.
const STATE_PREJUMP_F: int = 360
const STATE_PREJUMP_B: int = 361

# --- Normals -------------------------------------------------------------------
const STATE_5L: int = 310
const STATE_2L: int = 311
const STATE_5M: int = 312
const STATE_2M: int = 313
const STATE_5H: int = 314
const STATE_2H: int = 315
const STATE_6H: int = 316   # command overhead (NOT part of the auto-ladder)

# --- Reaction states -------------------------------------------------------------
const STATE_HITSTUN: int = 320
const STATE_BLOCKSTUN: int = 321
const STATE_CROUCH_BLOCKSTUN: int = 322
const STATE_HITSTUN_LAUNCH: int = 323   # 2H's launch -> knockdown-eligible reaction
const STATE_THROWN: int = 324

# --- Throw (L+H) --------------------------------------------------------------
const STATE_THROW: int = 350

# --- id_group allocation -------------------------------------------------------
const IDG_5L: int = 1
const IDG_2L: int = 2
const IDG_5M: int = 3
const IDG_2M: int = 4
const IDG_5H: int = 5
const IDG_2H: int = 6
const IDG_6H: int = 7
const IDG_THROW: int = 8

# --- Cancel groups (AD-044's strength ladder; character-b.md "Cancel model") --
# Tag each of 5L/2L/5M/2M/5H/2H with STRENGTH (L<M<H) and STANCE (stand/crouch).
# A cancel source -> target is legal iff: target.strength > source.strength, OR
# target.strength == source.strength && target.stance != source.stance, OR both
# are L (lights self-chain, including exact repeat — AD-044). Concretely, per
# source normal, the legal DESTINATION set is:
#   5L, 2L (L)         -> {5L, 2L, 5M, 2M, 5H, 2H}  (everything: lights rule + both highers)
#   5M (M, stand)       -> {2M, 5H, 2H}               (opposite-stance M, both H's)
#   2M (M, crouch)      -> {5M, 5H, 2H}               (opposite-stance M, both H's)
#   5H (H, stand)       -> {2H}                        (opposite-stance H only; H is the ceiling)
#   2H (H, crouch)      -> {5H}                        (opposite-stance H only)
# Expressed as authored CancelGroups, shared where sets coincide (5L/2L share
# one group — both lights have the identical legal-destination set).
const GROUP_ALL_NORMALS: int = 1
const GROUP_FROM_5M: int = 2
const GROUP_FROM_2M: int = 3
const GROUP_FROM_5H: int = 4
const GROUP_FROM_2H: int = 5


# --- Standard hurtboxes (character-local, fixed-point; AD-037 reflected: feet
# at local y=0, head at y=-H) --------------------------------------------------
static func _hurt_stand() -> Box:
	return Box.make(FP.from_int(-15), FP.from_int(-80), FP.from_int(30), FP.from_int(80))


static func _hurt_crouch() -> Box:
	return Box.make(FP.from_int(-15), FP.from_int(-55), FP.from_int(30), FP.from_int(55))


static func _hurt_air() -> Box:
	return Box.make(FP.from_int(-15), FP.from_int(-75), FP.from_int(30), FP.from_int(75))


## Build character B (character-b.md; TKT-P2-05 part 1: ground content). One
## entry point; the .tres baker and the dev-test twin both call this so there
## is exactly one authored definition (mirrors character_a.gd's convention).
static func build_character() -> Character:
	var c := Character.new()
	c.id = CHAR_ID
	c.idle_state_id = STATE_IDLE

	var phys := CharacterPhysics.new()
	# Movement table (character-b.md, provisional): walk ~2.0f / ~1.8b px/f.
	phys.walk_speed = FP.from_units(2.0)
	# Gravity/jump reuse character A's verified TKT-P2-01 constants (same
	# generic gravity model — no differentiation from A specified yet; a
	# reasonable provisional default, logged). air_dash_speed/double_jump_velocity
	# reuse the SAME values test_dash_air_action.gd already exercises the engine
	# mechanism against, for confidence they behave sanely (AD-046).
	phys.gravity = FP.from_units(1.0)
	phys.jump_velocity = FP.from_units(22.0)
	phys.air_dash_speed = FP.from_units(6.0)
	phys.double_jump_velocity = FP.from_units(18.0)
	c.physics = phys

	c.default_pushbox = Box.make(
		FP.from_int(-10), FP.from_int(-40), FP.from_int(20), FP.from_int(40))

	c.states = []
	c.states.append_array(_build_movement())
	c.states.append_array(_build_normals())
	c.states.append_array(_build_reactions())
	c.states.append_array(_build_throw())

	c.cancel_groups = _build_cancel_groups()
	c.button_map = _build_button_map()
	return c


# =============================================================================
# Cancel groups (AD-044 — see the const block above for the precise rule).
# =============================================================================
static func _build_cancel_groups() -> Array[CancelGroup]:
	var groups: Array[CancelGroup] = []

	var g_all := CancelGroup.new()
	g_all.id = GROUP_ALL_NORMALS
	g_all.members = [STATE_5L, STATE_2L, STATE_5M, STATE_2M, STATE_5H, STATE_2H]
	groups.append(g_all)

	var g_from_5m := CancelGroup.new()
	g_from_5m.id = GROUP_FROM_5M
	g_from_5m.members = [STATE_2M, STATE_5H, STATE_2H]
	groups.append(g_from_5m)

	var g_from_2m := CancelGroup.new()
	g_from_2m.id = GROUP_FROM_2M
	g_from_2m.members = [STATE_5M, STATE_5H, STATE_2H]
	groups.append(g_from_2m)

	var g_from_5h := CancelGroup.new()
	g_from_5h.id = GROUP_FROM_5H
	g_from_5h.members = [STATE_2H]
	groups.append(g_from_5h)

	var g_from_2h := CancelGroup.new()
	g_from_2h.id = GROUP_FROM_2H
	g_from_2h.members = [STATE_5H]
	groups.append(g_from_2h)

	return groups


## One on_contact, group-target, input-gateless ladder cancel (AD-044: "group
## cancels are authored input-gateless" — the group scan itself finds whichever
## member command is buffered). Window defaults to first-active -> end.
static func _ladder_cancel(group_id: int) -> CancelRule:
	var r := CancelRule.new()
	r.target = group_id
	r.target_is_group = true
	r.condition = CancelRule.CONDITION_ON_CONTACT
	r.window_start = 0
	r.window_end = 0
	r.input = 0
	return r


# =============================================================================
# Button map (move-format.md -> Character.button_map; AD-018/022/032/046).
#
# ORDER (first-match-wins, AD-032): throw chord first; crouching (DOWN+button)
# normals before 6H's forward+H gate before standing normals -- a down-forward
# hold (numpad 3) + H resolves 2H (crouching wins, matching character_a.gd's
# established "more specific DOWN-gated entry first" convention), while a PURE
# forward hold (no DOWN) + H falls through past the crouching entries (which
# all require DOWN) to 6H. A bare forward+H with 6H listed before 5H means
# 6H -- not 5H -- executes; 5H (required_direction=0, matches ANY direction)
# would otherwise shadow it by list order.
# =============================================================================
static func _build_button_map() -> Array[ButtonMapEntry]:
	var map: Array[ButtonMapEntry] = []
	# Throw (L+H chord, AD-032) -- before every bare button so a simultaneous
	# L+H resolves to the throw, not 5L/5H (a lone L or H never satisfies a chord).
	map.append(_map_chord(InputFrame.BUTTON_0, InputFrame.BUTTON_2, STATE_THROW))
	# Crouching normals (DOWN + button) before 6H/standing.
	map.append(_map(1, InputFrame.DOWN, 0, STATE_2M))
	map.append(_map(0, InputFrame.DOWN, 0, STATE_2L))
	map.append(_map(2, InputFrame.DOWN, 0, STATE_2H))
	# Crouch stance (bare DOWN, pure-direction command, AD-032/AD-038).
	map.append(_map(-1, InputFrame.DOWN, 0, STATE_CROUCH))
	# Diagonal jumps (composite pure-direction command, AD-032/AD-039).
	map.append(_map(-1, InputFrame.UP | InputFrame.RIGHT, 0, STATE_PREJUMP_F))
	map.append(_map(-1, InputFrame.UP | InputFrame.LEFT, 0, STATE_PREJUMP_B))
	# Jump (pure-direction command, AD-032).
	map.append(_map(-1, InputFrame.UP, 0, STATE_PREJUMP))
	# 6H -- command overhead (forward + H) -- BEFORE the standing normals so a
	# bare-forward + H resolves here, not 5H (character-b.md: "6H... is NOT part
	# of the auto-ladder" — reached only by this direct command).
	map.append(_map(2, InputFrame.RIGHT, 0, STATE_6H))
	# Standing normals.
	map.append(_map(0, 0, 0, STATE_5L))
	map.append(_map(1, 0, 0, STATE_5M))
	map.append(_map(2, 0, 0, STATE_5H))
	# Dash (double-tap direction command, AD-046) -- B's own ground dash/back dash.
	map.append(_map_double_tap(InputFrame.RIGHT, STATE_DASH_F))
	map.append(_map_double_tap(InputFrame.LEFT, STATE_DASH_B))
	# Walk (pure-direction command, AD-032).
	map.append(_map(-1, InputFrame.RIGHT, 0, STATE_WALK_F))
	map.append(_map(-1, InputFrame.LEFT, 0, STATE_WALK_B))
	return map


static func _map(button_index: int, required_direction: int, motion: int,
		target_state_id: int) -> ButtonMapEntry:
	var e := ButtonMapEntry.new()
	e.button_index = button_index
	e.required_direction = required_direction
	e.motion = motion
	e.target_state_id = target_state_id
	return e


static func _map_chord(button_bit_a: int, button_bit_b: int, target_state_id: int) -> ButtonMapEntry:
	var e := ButtonMapEntry.new()
	e.button_index = _bit_to_index(button_bit_a)
	e.chord_button_index = _bit_to_index(button_bit_b)
	e.required_direction = 0
	e.motion = 0
	e.target_state_id = target_state_id
	return e


static func _map_double_tap(required_direction: int, target_state_id: int) -> ButtonMapEntry:
	var e := ButtonMapEntry.new()
	e.button_index = -1
	e.required_direction = required_direction
	e.motion = 0
	e.double_tap = true
	e.target_state_id = target_state_id
	return e


static func _bit_to_index(bit: int) -> int:
	for i in range(8):
		if bit == (1 << (4 + i)):
			return i
	return -1


# =============================================================================
# Movement (character-b.md -> Movement table). Mirrors character_a.gd's
# gravity-model jump authoring exactly (TKT-P2-01/AD-043) -- no air-normal
# cancel rules are added to JUMP_N/F/B yet (TKT-P2-06 adds them once B's air
# normals exist; a jump with no air-normal target authored simply has none to
# reach, which is correct for THIS ticket's ground-only scope).
# =============================================================================
static func _build_movement() -> Array[MoveState]:
	var out: Array[MoveState] = []

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
	wf_kf.motion_vel_x = FP.from_units(2.0)
	walk_f.timeline = [wf_kf]
	out.append(walk_f)

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
	wb_kf.motion_vel_x = FP.from_units(-1.8)
	walk_b.timeline = [wb_kf]
	out.append(walk_b)

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
	crouch.is_crouch = true
	out.append(crouch)

	# FORWARD DASH (66): 18f, ~85px, fully committed (no cancel authored), no
	# invuln -- B's stagger-pressure/approach tool (character-b.md).
	var dash_f := MoveState.new()
	dash_f.id = STATE_DASH_F
	dash_f.category = MoveState.CATEGORY_GROUNDED
	dash_f.duration = 18
	dash_f.loop = false
	var df_kf := Keyframe.new()
	df_kf.frame_start = 1
	df_kf.frame_end = 18
	df_kf.hurtboxes = [_hurt_stand()]
	df_kf.has_motion = true
	df_kf.motion_vel_x = FP.from_units(4.7)   # ~85/18
	dash_f.timeline = [df_kf]
	out.append(dash_f)

	# BACK DASH (44): 16f, ~70px, NO INVULN (character-b.md: "Not invulnerable
	# (or minimal), so it is a read-beatable escape... no invincible reversal
	# (defense is movement)"). This is a DELIBERATE contrast with character A's
	# invuln back dash -- logged as a design-adjacent latitude call (the brief
	# leaves "or minimal" open; zero invuln is the reading most consistent with
	# B's "no invincible reversal" identity line).
	var dash_b := MoveState.new()
	dash_b.id = STATE_DASH_B
	dash_b.category = MoveState.CATEGORY_GROUNDED
	dash_b.duration = 16
	dash_b.loop = false
	var db_kf := Keyframe.new()
	db_kf.frame_start = 1
	db_kf.frame_end = 16
	db_kf.hurtboxes = [_hurt_stand()]
	db_kf.has_motion = true
	db_kf.motion_vel_x = FP.from_units(-4.4)   # ~70/16
	dash_b.timeline = [db_kf]
	out.append(dash_b)

	out.append(_build_prejump(STATE_PREJUMP, STATE_JUMP_N))
	out.append(_build_prejump(STATE_PREJUMP_F, STATE_JUMP_F))
	out.append(_build_prejump(STATE_PREJUMP_B, STATE_JUMP_B))

	out.append_array(_build_jump_arcs())

	return out


## One prejump lead-in (AD-039). Mirrors character_a.gd's _build_prejump exactly
## (4f duration, ALWAYS cancel firing on frame 3 -- one frame before duration,
## per the JC-038 authoring rule -- into `target`).
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


## The jump arc (gravity model, AD-043) -- reuses character A's verified
## takeoff/gravity constants (see build_character's physics note above). No
## air-normal cancel rules yet (TKT-P2-06 adds j.L/M/H and extends these three
## states' `cancels`; ground-only scope here).
static func _build_jump_arcs() -> Array[MoveState]:
	const JUMP_DURATION: int = 50
	const TAKEOFF_SPEED: float = 22.0
	const JUMP_HORIZ_SPEED: float = 3.5

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

		var kf_takeoff := Keyframe.new()
		kf_takeoff.frame_start = 1
		kf_takeoff.frame_end = 1
		kf_takeoff.hurtboxes = [_hurt_air()]
		kf_takeoff.has_motion = true
		kf_takeoff.motion_vel_x = FP.from_units(horiz_by_state[state_id])
		kf_takeoff.motion_vel_y = FP.from_units(-TAKEOFF_SPEED)

		var kf_flight := Keyframe.new()
		kf_flight.frame_start = 2
		kf_flight.frame_end = JUMP_DURATION
		kf_flight.hurtboxes = [_hurt_air()]

		m.timeline = [kf_takeoff, kf_flight]
		m.cancels = []   # TKT-P2-06 adds air-normal cancels here.
		out.append(m)
	return out


# =============================================================================
# Normals (character-b.md -> Normals table). Provisional frame numbers/damage/
# stun per the spec's own table (startup/active/recovery are given; damage/
# hitstun/blockstun/hitstop are NOT given by the spec table and are Developer
# tuning, logged).
# =============================================================================
static func _build_normals() -> Array[MoveState]:
	var out: Array[MoveState] = []
	out.append(_build_5l())
	out.append(_build_2l())
	out.append(_build_5m())
	out.append(_build_2m())
	out.append(_build_5h())
	out.append(_build_2h())
	out.append(_build_6h())
	return out


## 5L: 4 startup / 3 active / 7 recovery (duration 14). MID. Fast pressure
## starter; self-chains (ladder group = ALL_NORMALS, includes 5L itself --
## AD-044 -- but see the FLAGGED ENGINE GAP header note: the literal 5L->5L
## repeat step does not currently fire; every OTHER transition in the group
## does).
static func _build_5l() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_5L
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 14   # 4 + 3 + 7
	m.loop = false
	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = 4
	kf_start.hurtboxes = [_hurt_stand()]
	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(25), FP.from_int(-65), FP.from_int(22), FP.from_int(18))
	hb.guard_height = HitBox.GUARD_MID
	hb.damage = 20
	hb.hitstun = 14
	hb.blockstun = 10
	hb.hitstop = 7
	hb.pushback_hit = FP.from_units(2.0)
	hb.pushback_block = FP.from_units(2.0)
	hb.hit_reaction = STATE_HITSTUN
	hb.block_reaction = STATE_BLOCKSTUN
	hb.id_group = IDG_5L
	var kf_active := Keyframe.new()
	kf_active.frame_start = 5
	kf_active.frame_end = 7
	kf_active.hurtboxes = [_hurt_stand()]
	kf_active.hitboxes = [hb]
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 8
	kf_rec.frame_end = 14
	kf_rec.hurtboxes = [_hurt_stand()]
	m.timeline = [kf_start, kf_active, kf_rec]
	m.cancels = [_ladder_cancel(GROUP_ALL_NORMALS)]
	return m


## 2L: 4 startup / 3 active / 8 recovery (duration 15). LOW. Low pressure
## starter; self-chains (same GROUP_ALL_NORMALS as 5L).
static func _build_2l() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_2L
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 15   # 4 + 3 + 8
	m.loop = false
	m.is_crouch = true
	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = 4
	kf_start.hurtboxes = [_hurt_crouch()]
	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(20), FP.from_int(-20), FP.from_int(22), FP.from_int(15))
	hb.guard_height = HitBox.GUARD_LOW
	hb.damage = 18
	hb.hitstun = 15
	hb.blockstun = 11
	hb.hitstop = 7
	hb.pushback_hit = FP.from_units(1.5)
	hb.pushback_block = FP.from_units(1.5)
	hb.hit_reaction = STATE_HITSTUN
	hb.block_reaction = STATE_CROUCH_BLOCKSTUN
	hb.id_group = IDG_2L
	var kf_active := Keyframe.new()
	kf_active.frame_start = 5
	kf_active.frame_end = 7
	kf_active.hurtboxes = [_hurt_crouch()]
	kf_active.hitboxes = [hb]
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 8
	kf_rec.frame_end = 15
	kf_rec.hurtboxes = [_hurt_crouch()]
	m.timeline = [kf_start, kf_active, kf_rec]
	m.cancels = [_ladder_cancel(GROUP_ALL_NORMALS)]
	return m


## 5M: 6 startup / 3 active / 12 recovery (duration 21). MID. Ground poke,
## weak absolute (character-b.md). Ladder: {2M, 5H, 2H}.
static func _build_5m() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_5M
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 21   # 6 + 3 + 12
	m.loop = false
	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = 6
	kf_start.hurtboxes = [_hurt_stand()]
	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(28), FP.from_int(-60), FP.from_int(30), FP.from_int(20))
	hb.guard_height = HitBox.GUARD_MID
	hb.damage = 45
	hb.hitstun = 17
	hb.blockstun = 12
	hb.hitstop = 9
	hb.pushback_hit = FP.from_units(3.0)
	hb.pushback_block = FP.from_units(3.0)
	hb.hit_reaction = STATE_HITSTUN
	hb.block_reaction = STATE_BLOCKSTUN
	hb.id_group = IDG_5M
	var kf_active := Keyframe.new()
	kf_active.frame_start = 7
	kf_active.frame_end = 9
	kf_active.hurtboxes = [_hurt_stand()]
	kf_active.hitboxes = [hb]
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 10
	kf_rec.frame_end = 21
	kf_rec.hurtboxes = [_hurt_stand()]
	m.timeline = [kf_start, kf_active, kf_rec]
	m.cancels = [_ladder_cancel(GROUP_FROM_5M)]
	return m


## 2M: 7 startup / 4 active / 13 recovery (duration 24). LOW. String filler.
## Ladder: {5M, 5H, 2H}.
static func _build_2m() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_2M
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 24   # 7 + 4 + 13
	m.loop = false
	m.is_crouch = true
	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = 7
	kf_start.hurtboxes = [_hurt_crouch()]
	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(28), FP.from_int(-25), FP.from_int(38), FP.from_int(18))
	hb.guard_height = HitBox.GUARD_LOW
	hb.damage = 40
	hb.hitstun = 19
	hb.blockstun = 15
	hb.hitstop = 9
	hb.pushback_hit = FP.from_units(1.0)
	hb.pushback_block = FP.from_units(1.0)
	hb.hit_reaction = STATE_HITSTUN
	hb.block_reaction = STATE_CROUCH_BLOCKSTUN
	hb.id_group = IDG_2M
	var kf_active := Keyframe.new()
	kf_active.frame_start = 8
	kf_active.frame_end = 11
	kf_active.hurtboxes = [_hurt_crouch()]
	kf_active.hitboxes = [hb]
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 12
	kf_rec.frame_end = 24
	kf_rec.hurtboxes = [_hurt_crouch()]
	m.timeline = [kf_start, kf_active, kf_rec]
	m.cancels = [_ladder_cancel(GROUP_FROM_2M)]
	return m


## 5H: 7 startup / 3 active / 20 recovery (duration 30). MID. Whiff punisher --
## lightning startup, SEVERE recovery. The whiff-punish emerges structurally
## (character-b.md B-6; no new mechanism): 5H's only cancel is the ladder's
## on_contact rule (target {2H}), so it is available ONLY on hit/block -- on a
## clean whiff (move_contact resolves WHIFF, never HIT/BLOCK) no cancel
## condition ever holds and B is stuck through the FULL 30f duration, whereas on
## hit/block the ladder cancel into 2H can fire almost immediately after
## connect, cutting the EFFECTIVE recovery far short of the raw 30f. See
## docs/judgment-log.md for the reasoning and test_character_b.gd's
## `_test_5h_whiff_is_severely_punishable_vs_block_cancels_early` for the
## end-to-end proof.
static func _build_5h() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_5H
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 30   # 7 + 3 + 20
	m.loop = false
	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = 7
	kf_start.hurtboxes = [_hurt_stand()]
	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(28), FP.from_int(-58), FP.from_int(32), FP.from_int(22))
	hb.guard_height = HitBox.GUARD_MID
	hb.damage = 65
	hb.hitstun = 27
	hb.blockstun = 20
	hb.hitstop = 11
	hb.pushback_hit = FP.from_units(2.0)
	hb.pushback_block = FP.from_units(3.0)
	hb.hit_reaction = STATE_HITSTUN
	hb.block_reaction = STATE_BLOCKSTUN
	hb.id_group = IDG_5H
	var kf_active := Keyframe.new()
	kf_active.frame_start = 8
	kf_active.frame_end = 10
	kf_active.hurtboxes = [_hurt_stand()]
	kf_active.hitboxes = [hb]
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 11
	kf_rec.frame_end = 30
	kf_rec.hurtboxes = [_hurt_stand()]
	m.timeline = [kf_start, kf_active, kf_rec]
	m.cancels = [_ladder_cancel(GROUP_FROM_5H)]
	return m


## 2H: 9 startup / 4 active / 14 recovery (duration 27). MID. Anti-air
## launcher, JUMP-CANCELLABLE ON BLOCK (character-b.md). On hit: launches into
## STATE_HITSTUN_LAUNCH (airborne HITSTUN reaction -- lands into knockdown per
## AD-043, same mechanism as character A's DP). Carries TWO cancel families:
## the ladder's on_contact rule (-> 5H, the ladder's stated "2H 5H" legal step)
## and three ON_BLOCK-only rules into the prejump lead-ins (jump-cancel), keyed
## off the SAME jump commands already in button_map (UP / UP+RIGHT / UP+LEFT) --
## no new recognizer, no tag, exactly "an in-format cancel to a concrete state."
static func _build_2h() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_2H
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 27   # 9 + 4 + 14
	m.loop = false
	m.is_crouch = true
	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = 9
	kf_start.hurtboxes = [_hurt_crouch()]
	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(15), FP.from_int(-90), FP.from_int(35), FP.from_int(60))
	hb.guard_height = HitBox.GUARD_MID
	hb.damage = 55
	hb.hitstun = 30   # launch stun -- matches character A's DP-tier launch convention
	hb.blockstun = 16
	hb.hitstop = 10
	hb.pushback_hit = FP.from_units(3.0)
	hb.pushback_block = FP.from_units(2.0)
	hb.launch = FP.from_units(-6.0)
	hb.hit_reaction = STATE_HITSTUN_LAUNCH
	hb.block_reaction = STATE_CROUCH_BLOCKSTUN
	hb.id_group = IDG_2H
	var kf_active := Keyframe.new()
	kf_active.frame_start = 10
	kf_active.frame_end = 13
	kf_active.hurtboxes = [_hurt_crouch()]
	kf_active.hitboxes = [hb]
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 14
	kf_rec.frame_end = 27
	kf_rec.hurtboxes = [_hurt_crouch()]
	m.timeline = [kf_start, kf_active, kf_rec]
	var cancels: Array[CancelRule] = [_ladder_cancel(GROUP_FROM_2H)]
	cancels.append_array(_jump_cancel_on_block())
	m.cancels = cancels
	return m


## The three on_block, jump-cancel CancelRules (2H -> PREJUMP_N/F/B). Each
## targets a CONCRETE state (not a group) already reachable via an existing
## button_map entry (the bare-UP / UP+RIGHT / UP+LEFT jump commands), so
## CancelEval._input_buffered's "find the button_map entry whose target ==
## rule.target" path resolves it directly -- `input` just needs to be nonzero to
## select that path; the semantic direction bits are used here for readability.
static func _jump_cancel_on_block() -> Array[CancelRule]:
	var targets := [
		[STATE_PREJUMP, InputFrame.UP],
		[STATE_PREJUMP_F, InputFrame.UP | InputFrame.RIGHT],
		[STATE_PREJUMP_B, InputFrame.UP | InputFrame.LEFT],
	]
	var rules: Array[CancelRule] = []
	for t in targets:
		var r := CancelRule.new()
		r.target = t[0]
		r.target_is_group = false
		r.condition = CancelRule.CONDITION_ON_BLOCK
		r.window_start = 0
		r.window_end = 0
		r.input = t[1]
		rules.append(r)
	return rules


## 6H: 22 startup (reactable) / 3 active / 18 recovery (duration 43). HIGH --
## the dedicated command overhead in B's mixup (character-b.md). NOT part of
## the auto-ladder (no group cancel authored); reached only via its own
## forward+H command (button_map).
static func _build_6h() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_6H
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 43   # 22 + 3 + 18
	m.loop = false
	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = 22
	kf_start.hurtboxes = [_hurt_stand()]
	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(20), FP.from_int(-85), FP.from_int(30), FP.from_int(20))
	hb.guard_height = HitBox.GUARD_HIGH
	hb.damage = 55
	hb.hitstun = 24
	hb.blockstun = 16
	hb.hitstop = 10
	hb.pushback_hit = FP.from_units(2.0)
	hb.pushback_block = FP.from_units(2.0)
	hb.hit_reaction = STATE_HITSTUN
	hb.block_reaction = STATE_BLOCKSTUN
	hb.id_group = IDG_6H
	var kf_active := Keyframe.new()
	kf_active.frame_start = 23
	kf_active.frame_end = 25
	kf_active.hurtboxes = [_hurt_stand()]
	kf_active.hitboxes = [hb]
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 26
	kf_rec.frame_end = 43
	kf_rec.hurtboxes = [_hurt_stand()]
	m.timeline = [kf_start, kf_active, kf_rec]
	m.cancels = []   # not a ladder member (character-b.md: special-cancel target only, and no specials exist yet)
	return m


# =============================================================================
# Reaction states.
# =============================================================================
static func _build_reactions() -> Array[MoveState]:
	var out: Array[MoveState] = []

	var hitstun := MoveState.new()
	hitstun.id = STATE_HITSTUN
	hitstun.category = MoveState.CATEGORY_HITSTUN
	hitstun.duration = 27   # covers the longest authored standing hitstun (5H, 27f)
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
	blockstun.duration = 20   # covers the longest authored standing blockstun (5H, 20f)
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
	crouch_blockstun.duration = 16   # covers the longest crouch-blocked hit (2H, 16f)
	crouch_blockstun.loop = false
	crouch_blockstun.is_crouch = true
	var cbs_kf := Keyframe.new()
	cbs_kf.frame_start = 1
	cbs_kf.frame_end = crouch_blockstun.duration
	cbs_kf.hurtboxes = [_hurt_crouch()]
	crouch_blockstun.timeline = [cbs_kf]
	out.append(crouch_blockstun)

	# HITSTUN_LAUNCH: 2H's launch -> knockdown-eligible reaction (AD-043: a
	# launched airborne-HITSTUN character lands into knockdown automatically --
	# no new engine category/state needed, same mechanism as character A's DP).
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

	# THROWN: forced throw reaction (defender).
	var thrown := MoveState.new()
	thrown.id = STATE_THROWN
	thrown.category = MoveState.CATEGORY_HITSTUN
	thrown.duration = 28   # hard-knockdown tail (oki setup window)
	thrown.loop = false
	var th_kf := Keyframe.new()
	th_kf.frame_start = 1
	th_kf.frame_end = thrown.duration
	th_kf.hurtboxes = [_hurt_stand()]
	thrown.timeline = [th_kf]
	out.append(thrown)

	return out


# =============================================================================
# Throw -- L+H (character-b.md: "the shared throw ... AD-016/029 ... defines
# NO new throw rules"). Mirrors character_a.gd's throw exactly in SHAPE; only
# the numeric values differ (B's own provisional tuning, logged).
# =============================================================================
const THROW_STARTUP: int = 5
const THROW_TECH_WINDOW: int = 7
const THROW_WHIFF_RECOVERY: int = 18
const THROW_DAMAGE: int = 90
const THROW_HITSTUN: int = 28   # hard-knockdown duration -- must match/exceed STATE_THROWN's duration


static func _build_throw() -> Array[MoveState]:
	var m := MoveState.new()
	m.id = STATE_THROW
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = THROW_STARTUP + THROW_WHIFF_RECOVERY
	m.loop = false

	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = THROW_STARTUP - 1
	kf_start.hurtboxes = [_hurt_stand()]

	var tb := HitBox.new()
	tb.box = Box.make(FP.from_int(10), FP.from_int(-60), FP.from_int(55), FP.from_int(60))
	tb.damage = THROW_DAMAGE
	tb.hitstun = THROW_HITSTUN
	tb.tech_window = THROW_TECH_WINDOW
	tb.pushback_hit = FP.from_units(2.0)
	tb.hitstop = 0
	tb.hit_reaction = STATE_THROWN
	tb.block_reaction = STATE_THROWN   # unused (throws bypass block); authored for schema completeness
	tb.id_group = IDG_THROW
	tb.is_throw = true

	var kf_active := Keyframe.new()
	kf_active.frame_start = THROW_STARTUP
	kf_active.frame_end = THROW_STARTUP
	kf_active.hurtboxes = [_hurt_stand()]
	kf_active.hitboxes = [tb]

	var kf_rec := Keyframe.new()
	kf_rec.frame_start = THROW_STARTUP + 1
	kf_rec.frame_end = m.duration
	kf_rec.hurtboxes = [_hurt_stand()]

	m.timeline = [kf_start, kf_active, kf_rec]
	m.cancels = []
	return [m]
