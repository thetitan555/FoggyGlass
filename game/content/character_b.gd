class_name CharacterB
extends RefCounted

## Character B — the pressure/air-mobility character (character-b.md; TKT-P2-05 +
## TKT-P2-06). PART 1 (TKT-P2-05): the six chainable normals + the strength-ladder
## gatling cancels (AD-044), the two dedicated command normals (5H/6H/2H), the
## throw (existing AD-016/029 model — no new throw rules), and ground movement
## (walk/dash/jump wiring over AD-043/046, already-built engine capabilities).
## PART 2 (this pass, TKT-P2-06): the air toolkit + specials + oki — the three
## divekicks (aerial specials, H = the overhead), the air normals (j.L/M/H,
## carrying the fall per AD-043), the low slide (LOW, hard knockdown ->
## knockdown-into-ground oki), and the arc projectile (three parabolas, AD-047,
## one falling in front for setplay). The 2H-JC -> airdash pressure wiring needs
## NO new authoring here: B's physics already carries air_dash_speed (TKT-P2-05)
## and the air-action economy (AD-046) is a generic engine mechanism that applies
## to ANY physically-airborne player regardless of how they got there (2H's own
## jump-cancel-on-block already lands B in JUMP_N/F/B, TKT-P2-05) — it "just
## works" once B is airborne with air_dash_speed != 0; verified by test, not
## re-authored. Authored PURELY as data (move-format.md criterion 1 /
## character-b.md criterion 1) — no character-specific engine code; B and A
## resolve frame data through the exact same code path.
##
## KNOCKDOWN-STATE CATCH-UP (AD-043's elaboration, JC-070 overturned 2026-07-15,
## ratified AFTER TKT-P2-05 landed — see docs/judgment-log.md for the full
## reasoning). TKT-P2-05's throw predates the ratified `Character.
## knockdown_state_id` contract and routed its hard knockdown directly to its own
## `STATE_THROWN` (a standalone reaction, not the shared knockdown state AD-043's
## elaboration specifies). This pass closes that gap: `STATE_THROWN` is renamed
## to `STATE_KNOCKDOWN` (id UNCHANGED, mirrors character_a.gd's own identical
## rename), `Character.knockdown_state_id` is now set, the throw's hit_reaction
## points at it directly (a grounded hard-KD hit, no air trip), the new low
## slide's hard-knockdown hit_reaction ALSO points at it directly, and 2H's
## launch (STATE_HITSTUN_LAUNCH) now automatically lands into it via the
## already-built engine mechanism (StepPhases._land) the moment
## knockdown_state_id is set — no further authoring needed for that
## convergence. All three hard-knockdown sources (throw, slide, launch-landing)
## now share ONE learnable wakeup duration (28 ticks), exactly AD-043's point.
##
## AD-049 CATCH-UP (2026-07-16, TKT-P2-09+10): `Character.knockdown_state_id`
## is RETIRED and folds into `reaction_map[REACTION_KNOCKDOWN]` (the same
## concept under a second name — see this file's build_character()); every
## `hit_reaction`/`block_reaction` above is now a `ReactionKind`, not a raw
## state_id, and B additionally authors `STATE_AIR_RESET` (a kind it never
## inflicts but must be able to RECEIVE — character A's 2H). The paragraph
## above describes the TKT-P2-06 catch-up's OWN history and is left as-is;
## read "knockdown_state_id" there as "reaction_map[REACTION_KNOCKDOWN]" now.
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
## RESOLVED ENGINE GAP (docs/flags.md, raised with this ticket, resolved
## 2026-07-15): AD-044's "lights self-chain, including exact repeat" (5L->5L,
## 2L->2L) initially did not fire — CancelEval.find_cancel rejected ANY cancel
## (concrete or group-resolved) whose destination equalled the player's CURRENT
## state_id unconditionally. The Architect's fix (CancelEval only, game/sim/
## cancel_eval.gd): permit a same-state cancel EXCEPT a truly gateless
## self-target (condition ALWAYS + input 0), which stays rejected. B's 5L/2L
## needed NO re-authoring — they were already authored exactly per AD-044 (each
## names itself as a legal member of its own ladder group, GROUP_ALL_NORMALS)
## before the fix landed; only the engine guard changed.

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
const STATE_HITSTUN_LAUNCH: int = 323   # 2H's launch -> lands into STATE_KNOCKDOWN (AD-043)
const STATE_AIR_RESET: int = 325   # AD-049 catch-up: B authors every reaction kind it can
									 # RECEIVE, not just inflict -- B has no launcher of its
									 # own that air-resets, but character A's 2H DOES inflict
									 # REACTION_AIR_RESET, and B is the defender in that
									 # matchup (docs/briefs/character-b.md "What B looks like
									 # when it receives"). Mirrors character_a.gd's own
									 # STATE_AIR_RESET exactly (see _build_reactions below).
const STATE_KNOCKDOWN: int = 324   # shared grounded knockdown reaction (AD-043 elaboration,
									 # ratified from JC-070): the throw's DIRECT hit_reaction,
									 # the low slide's DIRECT hit_reaction, and the landing
									 # target 2H's launch (STATE_HITSTUN_LAUNCH) converges on
									 # via Character.reaction_map[REACTION_KNOCKDOWN]
									 # (AD-049; was Character.knockdown_state_id,
									 # retired). Was STATE_THROWN
									 # pre-catch-up (id unchanged; see header note) — renamed
									 # since it is no longer throw-specific, mirroring
									 # character_a.gd's identical rename exactly.

# --- Throw (L+H) --------------------------------------------------------------
const STATE_THROW: int = 350

# --- Air toolkit + specials (TKT-P2-06) ---------------------------------------
# Low slide (236 L/M/H -- character-b.md's own text gives three input strengths,
# but describes exactly ONE move's behavior, no per-strength differentiation
# unlike the divekick/projectile which explicitly enumerate three distinct
# versions -- so all three inputs route to ONE canonical slide, logged latitude).
const STATE_SLIDE: int = 365

# Arc projectile (214 L/M/H; AD-047) -- three genuinely distinct parabolas.
const STATE_ARC_L: int = 366
const STATE_ARC_M: int = 367
const STATE_ARC_H: int = 368

# Divekick (aerial special, 2+attack in air; three versions, H = the overhead).
const STATE_DIVEKICK_L: int = 370
const STATE_DIVEKICK_M: int = 371
const STATE_DIVEKICK_H: int = 372

# Air normals (carry the fall, AD-043 -- do not stop the jump arc).
const STATE_JL: int = 375
const STATE_JM: int = 376
const STATE_JH: int = 377

# --- id_group allocation -------------------------------------------------------
const IDG_5L: int = 1
const IDG_2L: int = 2
const IDG_5M: int = 3
const IDG_2M: int = 4
const IDG_5H: int = 5
const IDG_2H: int = 6
const IDG_6H: int = 7
const IDG_THROW: int = 8
const IDG_SLIDE: int = 9
const IDG_JL: int = 10
const IDG_JM: int = 11
const IDG_JH: int = 12
const IDG_DIVEKICK_L: int = 13
const IDG_DIVEKICK_M: int = 14
const IDG_DIVEKICK_H: int = 15
const IDG_ARC_L: int = 16
const IDG_ARC_M: int = 17
const IDG_ARC_H: int = 18

# --- ProjectileData registry ids (distinct from character A's 201-203) -------
const PROJ_ARC_L: int = 220
const PROJ_ARC_M: int = 221
const PROJ_ARC_H: int = 222

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
	# reaction_map (AD-049, REQUIRED): every ReactionKind -> B's OWN state_id --
	# not just the kinds B inflicts, every kind B can RECEIVE (this is where
	# STATE_AIR_RESET is authored: B never inflicts an air-reset, but A's 2H
	# does, and B is the defender in that matchup). Folds in the old
	# knockdown_state_id field (retired) as reaction_map[REACTION_KNOCKDOWN] --
	# every launched HITSTUN state's landing (STATE_HITSTUN_LAUNCH) redirects
	# here via StepPhases._land, and the throw/slide's direct hit_reaction
	# reaches it with no air trip, exactly as before.
	c.reaction_map = [
		ReactionMapEntry.make(MoveState.REACTION_HITSTUN, STATE_HITSTUN),
		ReactionMapEntry.make(MoveState.REACTION_LAUNCH, STATE_HITSTUN_LAUNCH),
		ReactionMapEntry.make(MoveState.REACTION_AIR_RESET, STATE_AIR_RESET),
		ReactionMapEntry.make(MoveState.REACTION_KNOCKDOWN, STATE_KNOCKDOWN),
		ReactionMapEntry.make(MoveState.REACTION_BLOCKSTUN, STATE_BLOCKSTUN),
		ReactionMapEntry.make(MoveState.REACTION_CROUCH_BLOCKSTUN, STATE_CROUCH_BLOCKSTUN),
	]

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
	c.states.append_array(_build_slide())
	c.states.append_array(_build_arc_projectiles())
	c.states.append_array(_build_divekicks())
	c.states.append_array(_build_air_normals())

	c.cancel_groups = _build_cancel_groups()
	c.button_map = _build_button_map()
	return c


## A ProjectileRegistry roster (data_id -> ProjectileData) for B's three arc-
## projectile strengths (mirrors CharacterA.build_projectile_registry's role —
## a caller that spawns/restores B's projectiles must ProjectileRegistry.
## install() this).
static func build_projectile_registry() -> Dictionary:
	var l := _arc_projectile_data(PROJ_ARC_L, IDG_ARC_L, FP.from_units(0.5), 30, 14, 10, 6)
	var m := _arc_projectile_data(PROJ_ARC_M, IDG_ARC_M, FP.from_units(0.4), 38, 16, 11, 7)
	var h := _arc_projectile_data(PROJ_ARC_H, IDG_ARC_H, FP.from_units(0.3), 46, 18, 12, 8)
	return {l.id: l, m.id: m, h.id: h}


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
	# Low slide (236 + L/M/H; TKT-P2-06) and arc projectile (214 + L/M/H; AD-047)
	# -- listed FIRST, before the throw chord/crouching normals, mirroring
	# character_a.gd's own discipline ("motion commands before their prefix's
	# plain-button fallbacks") so a completed 236/214 motion is never shadowed by
	# a bare-button or DOWN+button entry recognizing a PARTIAL match against the
	# motion's own intermediate frames. All three buttons route the slide to the
	# SAME canonical STATE_SLIDE (character-b.md describes one move's behavior,
	# not three distinct ones -- logged latitude, docs/judgment-log.md); the
	# projectile routes to three genuinely distinct strengths (AD-047).
	map.append(_map_motion(InputBuffer.MOTION_236, InputFrame.BUTTON_0, STATE_SLIDE))
	map.append(_map_motion(InputBuffer.MOTION_236, InputFrame.BUTTON_1, STATE_SLIDE))
	map.append(_map_motion(InputBuffer.MOTION_236, InputFrame.BUTTON_2, STATE_SLIDE))
	map.append(_map_motion(InputBuffer.MOTION_214, InputFrame.BUTTON_0, STATE_ARC_L))
	map.append(_map_motion(InputBuffer.MOTION_214, InputFrame.BUTTON_1, STATE_ARC_M))
	map.append(_map_motion(InputBuffer.MOTION_214, InputFrame.BUTTON_2, STATE_ARC_H))
	# Throw (L+H chord, AD-032) -- before every bare button so a simultaneous
	# L+H resolves to the throw, not 5L/5H (a lone L or H never satisfies a chord).
	map.append(_map_chord(InputFrame.BUTTON_0, InputFrame.BUTTON_2, STATE_THROW))
	# Crouching normals (DOWN + button) before 6H/standing.
	map.append(_map(1, InputFrame.DOWN, 0, STATE_2M))
	map.append(_map(0, InputFrame.DOWN, 0, STATE_2L))
	map.append(_map(2, InputFrame.DOWN, 0, STATE_2H))
	# Divekick target-lookup entries (DOWN + L/M/H; TKT-P2-06). These are NEVER
	# reachable via ordinary grounded idle-dispatch (first-match-wins already
	# resolves the identical DOWN+button gate to 2L/2M/2H, listed above) -- they
	# exist SOLELY so JUMP_N/F/B's own airborne CancelRules (an aerial "2+attack"
	# command) can resolve their input via CancelEval._input_buffered's
	# find-entry-by-target lookup, exactly the mechanism 2H's on-block
	# jump-cancel already reuses (button_map entries as a shared recognition
	# table, not exclusively a ground-dispatch list).
	map.append(_map(0, InputFrame.DOWN, 0, STATE_DIVEKICK_L))
	map.append(_map(1, InputFrame.DOWN, 0, STATE_DIVEKICK_M))
	map.append(_map(2, InputFrame.DOWN, 0, STATE_DIVEKICK_H))
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


## A motion command entry (e.g. 236 + BUTTON_1; TKT-P2-06). `button_bit` is an
## InputFrame.BUTTON_* constant; ButtonMapEntry.button_index wants the bit INDEX,
## so this converts (mirrors character_a.gd's identical helper).
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
## takeoff/gravity constants (see build_character's physics note above).
## TKT-P2-06 adds the two families of airborne cancels every jump carries: the
## divekick (an aerial special, does NOT spend the air action, AD-046) and the
## air normals (j.L/M/H, carry the fall, AD-043). The generic air-action economy
## itself (air dash / double jump) needs NO cancel authored here at all -- it is
## an engine-level phase-3 check (StepPhases._apply_air_action) gated only by
## `was_airborne` + `air_action_used`, not by anything this MoveState declares.
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
		var cancels: Array[CancelRule] = _divekick_cancels(JUMP_DURATION)
		cancels.append_array(_air_normal_cancels(JUMP_DURATION))
		m.cancels = cancels
		out.append(m)
	return out


## The three divekick CancelRules (JUMP_N/F/B -> DIVEKICK_L/M/H; TKT-P2-06).
## Listed BEFORE the air-normal cancels below (_build_jump_arcs appends this
## array first) so a DOWN-held button resolves the (more specific) divekick
## gate rather than the direction-agnostic air normal -- the same "more
## specific gate wins by list order" convention 6H/2H already use. Each targets
## a CONCRETE divekick state whose OWN button_map entry (DOWN + button,
## _build_button_map) CancelEval._input_buffered resolves by target-match (the
## same reuse 2H's on_block jump-cancel already established) -- `input` just
## needs to be nonzero to select that path.
static func _divekick_cancels(jump_duration: int) -> Array[CancelRule]:
	var targets := [
		[STATE_DIVEKICK_L, InputFrame.DOWN | InputFrame.BUTTON_0],
		[STATE_DIVEKICK_M, InputFrame.DOWN | InputFrame.BUTTON_1],
		[STATE_DIVEKICK_H, InputFrame.DOWN | InputFrame.BUTTON_2],
	]
	var rules: Array[CancelRule] = []
	for t in targets:
		var r := CancelRule.new()
		r.target = t[0]
		r.target_is_group = false
		r.condition = CancelRule.CONDITION_ALWAYS
		r.window_start = 1
		r.window_end = jump_duration - 1
		r.input = t[1]
		rules.append(r)
	return rules


## Air-normal reachability (AD-039, mirrors character_a.gd's _air_normal_cancels
## exactly): three ALWAYS CancelRules, one per button, targeting j.L/j.M/j.H. No
## button_map entry targets a j.* state, so CancelEval._input_buffered's
## raw-button fallback resolves it directly.
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
## AD-044 -- including the literal 5L->5L repeat step, per the CancelEval fix
## above).
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
	hb.hit_reaction = MoveState.REACTION_HITSTUN
	hb.block_reaction = MoveState.REACTION_BLOCKSTUN
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
	hb.hit_reaction = MoveState.REACTION_HITSTUN
	hb.block_reaction = MoveState.REACTION_CROUCH_BLOCKSTUN
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
	hb.hit_reaction = MoveState.REACTION_HITSTUN
	hb.block_reaction = MoveState.REACTION_BLOCKSTUN
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
	hb.hit_reaction = MoveState.REACTION_HITSTUN
	hb.block_reaction = MoveState.REACTION_CROUCH_BLOCKSTUN
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
	hb.hit_reaction = MoveState.REACTION_HITSTUN
	hb.block_reaction = MoveState.REACTION_BLOCKSTUN
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
	hb.hit_reaction = MoveState.REACTION_LAUNCH
	hb.block_reaction = MoveState.REACTION_CROUCH_BLOCKSTUN
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
	hb.hit_reaction = MoveState.REACTION_HITSTUN
	hb.block_reaction = MoveState.REACTION_BLOCKSTUN
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

	# AIR_RESET (AD-049 catch-up): B never inflicts this kind -- B has no
	# launcher that air-resets rather than launches -- but AD-049 requires every
	# character to author every kind it can RECEIVE, and character A's 2H is
	# exactly the concrete case (A hits B, B receives REACTION_AIR_RESET;
	# docs/briefs/character-b.md "What B looks like when it receives"). Mirrors
	# character_a.gd's own STATE_AIR_RESET exactly: HITSTUN-category, the
	# airborne hurtbox, and a duration (20) that covers the airborne arc before
	# the shared StepPhases._land mechanism lands it into B's own
	# reaction_map[REACTION_KNOCKDOWN] -- the SAME convergence character A's own
	# air-reset already exercises (a launched HITSTUN-family state's landing is
	# not distinguished by ReactionKind, only by physical category -- AD-043),
	# not a new mechanism. 20 ticks is not an arbitrary guess: B reuses A's own
	# verified gravity constant (TKT-P2-05's judgment call) and the inflicting
	# hitbox is character A's 2H (same launch magnitude), so the physical flight
	# time is the same order as A's own air_reset. Duration / hurtbox choice are
	# latitude (docs/judgment-log.md) -- the brief's one hard constraint is that
	# this state be tellable apart from LAUNCH/KNOCKDOWN ON SIGHT, which is a
	# pose/animation concern outside this headless builder's reach.
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

	# KNOCKDOWN: the shared grounded knockdown reaction (AD-043 elaboration,
	# ratified from JC-070; TKT-P2-06 catch-up -- see this file's header note).
	# Reached THREE ways: (1) directly, as the throw's own hit_reaction (a
	# grounded hard-knockdown hit never goes airborne); (2) directly, as the low
	# slide's hit_reaction (character-b.md: "hard knockdown ... via
	# hit_reaction"); (3) via StepPhases._land, which redirects 2H's launch
	# (STATE_HITSTUN_LAUNCH) here the moment it lands (Character.
	# reaction_state(REACTION_KNOCKDOWN), AD-049) -- all three converge on ONE
	# learnable wakeup, counted from entry (landing/connect), not from the original hit.
	var knockdown := MoveState.new()
	knockdown.id = STATE_KNOCKDOWN
	knockdown.category = MoveState.CATEGORY_HITSTUN
	knockdown.duration = 28   # hard-knockdown tail (oki setup window) -- matches
							   # THROW_HITSTUN below and the slide's own hb.hitstun
							   # (logged judgment call: same NUMBER, not just the
							   # same MECHANISM, so the wakeup is genuinely one
							   # learnable timing regardless of source).
	knockdown.loop = false
	var kd_kf := Keyframe.new()
	kd_kf.frame_start = 1
	kd_kf.frame_end = knockdown.duration
	kd_kf.hurtboxes = [_hurt_stand()]
	knockdown.timeline = [kd_kf]
	out.append(knockdown)

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
	# docs/flags.md 2026-07-17 "re: throw hitbox geometry": same retune as
	# character_a.gd's throw (see that file's comment for the full sizing
	# rationale) -- B's hurtbox dimensions are identical to A's, so the same
	# ~a-tenth-area box (15x25, x=10/y=-30) applies unchanged.
	tb.box = Box.make(FP.from_int(10), FP.from_int(-30), FP.from_int(15), FP.from_int(25))
	tb.damage = THROW_DAMAGE
	tb.hitstun = THROW_HITSTUN
	tb.tech_window = THROW_TECH_WINDOW
	tb.pushback_hit = FP.from_units(2.0)
	tb.hitstop = 0
	tb.hit_reaction = MoveState.REACTION_KNOCKDOWN   # AD-043 elaboration (TKT-P2-06 catch-up): a
													   # grounded hard-knockdown hit -- direct to the
													   # shared knockdown state, no air trip (see this
													   # file's header note). A ReactionKind (AD-049).
	tb.block_reaction = MoveState.REACTION_KNOCKDOWN   # unused (throws bypass block); authored for schema completeness
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


# =============================================================================
# Low slide (character-b.md -> Specials -> Low slide; TKT-P2-06). 236 + L/M/H
# all route to this ONE canonical move (logged latitude: the spec describes
# exactly one move's behavior under three input strengths, unlike the
# divekick/projectile which explicitly enumerate three distinct versions).
#
# B-1's hard legibility constraint ("spacing-variable, instrument-readable
# advantage") falls out of AD-008's LIVE advantage formula for free, with NO
# new mechanism: the slide is a single moving hitbox authored on ONE keyframe
# spanning the WHOLE active window (SLIDE_ACTIVE frames) with a constant
# forward `has_motion` velocity -- so the character's WORLD position (and
# therefore the hitbox's world rect) advances every active frame even though
# the keyframe's LOCAL box coordinates never change. A closer defender is
# reached (and connects) on an EARLIER active frame; a farther defender is
# reached on a LATER one -- different frame_in_state at the moment of
# contact, hence different attacker-remaining-recovery, hence different live
# block advantage (Advantage.live), exactly the mechanism character-b.md
# names. The CAUSING spacing is separately visible on screen (the geometry
# overlay already renders both players' positions/boxes every frame; no new
# field is needed for that half of B-1 -- only the training mode's existing
# live-advantage readout + the existing geometry overlay, both already built).
# =============================================================================
const SLIDE_STARTUP: int = 12
const SLIDE_ACTIVE: int = 8      # several active frames -- the spacing-variable window (B-1)
const SLIDE_RECOVERY: int = 10
const SLIDE_SPEED: float = 5.0   # forward px/f during the active window (constant, AD-043
								  # keyframe-motion convention -- re-set identically every
								  # covered tick, not an impulse-then-inherit arc)
const SLIDE_DAMAGE: int = 50
const SLIDE_HITSTUN: int = 28    # matches STATE_KNOCKDOWN's authored duration exactly (the
								  # "one learnable wakeup" convergence -- see this file's
								  # header note)
const SLIDE_BLOCKSTUN: int = 14
const SLIDE_HITSTOP: int = 8


static func _build_slide() -> Array[MoveState]:
	var m := MoveState.new()
	m.id = STATE_SLIDE
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = SLIDE_STARTUP + SLIDE_ACTIVE + SLIDE_RECOVERY
	m.loop = false
	m.is_crouch = true   # crouched throughout (a sliding pose; AD-045: the animation the
						   # LOW guard reads against)

	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = SLIDE_STARTUP
	kf_start.hurtboxes = [_hurt_crouch()]

	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(15), FP.from_int(-15), FP.from_int(35), FP.from_int(15))
	hb.guard_height = HitBox.GUARD_LOW   # must be crouch-blocked (character-b.md)
	hb.damage = SLIDE_DAMAGE
	hb.hitstun = SLIDE_HITSTUN
	hb.blockstun = SLIDE_BLOCKSTUN
	hb.hitstop = SLIDE_HITSTOP
	hb.pushback_hit = FP.from_units(2.0)
	hb.pushback_block = FP.from_units(2.0)
	hb.hit_reaction = MoveState.REACTION_KNOCKDOWN   # hard knockdown -> knockdown-into-ground oki
													   # (character-b.md: "via hit_reaction");
													   # a ReactionKind (AD-049).
	hb.block_reaction = MoveState.REACTION_CROUCH_BLOCKSTUN
	hb.id_group = IDG_SLIDE

	var first_active: int = SLIDE_STARTUP + 1
	var last_active: int = SLIDE_STARTUP + SLIDE_ACTIVE
	var kf_active := Keyframe.new()
	kf_active.frame_start = first_active
	kf_active.frame_end = last_active
	kf_active.hurtboxes = [_hurt_crouch()]
	kf_active.hitboxes = [hb]
	kf_active.has_motion = true
	kf_active.motion_vel_x = FP.from_units(SLIDE_SPEED)   # constant forward slide (B-1's
															# spacing-variable mechanism)

	var kf_rec := Keyframe.new()
	kf_rec.frame_start = last_active + 1
	kf_rec.frame_end = m.duration
	kf_rec.hurtboxes = [_hurt_crouch()]

	m.timeline = [kf_start, kf_active, kf_rec]
	m.cancels = []   # B's most desirable combo ENDER (character-b.md) -- no further cancel authored
	return [m]


# =============================================================================
# Arc projectile (character-b.md -> Specials -> Arc projectile; AD-047;
# TKT-P2-06). 214 + L/M/H spawn three genuinely distinct parabolas (different
# initial velocity AND gravity, character-b.md's own text). ALL THREE are
# authored `guard_height = GUARD_MID` (logged judgment call, B-2/AD-047): a MID
# hit is blockable from EITHER stance (test_guard_height.gd's own
# `_test_mid_blocked_either_stance`), so the projectile can NEVER be in an
# "opposite guard_height" conflict with any simultaneous B strike, regardless
# of what that strike's own guard_height is -- this satisfies AD-047's
# no-unblockable invariant BY CONSTRUCTION rather than by careful timing: the
# real high/low or strike/throw guess is carried entirely by B's own strike/
# throw layer (a single, readable axis), with the projectile acting purely as
# a stance-agnostic space-control/pressure tool that resolves identically no
# matter which way the defender guesses. L is authored as the "falls right in
# front" oki version (shortest travel of the three -- logged judgment call: the
# brief does not name which strength is the oki version).
# =============================================================================
const ARC_CHAR_STARTUP: int = 15
const ARC_SPAWN_FRAME: int = 16   # ARC_CHAR_STARTUP + 1 -- the release frame (AD-030)
const ARC_CHAR_RECOVERY: int = 26
const ARC_LIFETIME: int = 200     # generous safety bound; ground-contact despawn (AD-047)
								   # is what actually ends an arc projectile's life in practice
const ARC_MAX_PER_OWNER: int = 1


static func _build_arc_projectiles() -> Array[MoveState]:
	var out: Array[MoveState] = []
	# (state_id, proj_id, id_group, spawn_vel_x, spawn_vel_y (negative = up), gravity,
	#  damage, hitstun, blockstun, hitstop)
	out.append(_build_arc_projectile(STATE_ARC_L, PROJ_ARC_L, IDG_ARC_L,
		2.0, -6.0, FP.from_units(0.5), 30, 14, 10, 6))     # shortest travel -> "falls in front" (oki)
	out.append(_build_arc_projectile(STATE_ARC_M, PROJ_ARC_M, IDG_ARC_M,
		4.0, -9.0, FP.from_units(0.4), 38, 16, 11, 7))     # medium arc
	out.append(_build_arc_projectile(STATE_ARC_H, PROJ_ARC_H, IDG_ARC_H,
		6.0, -13.0, FP.from_units(0.3), 46, 18, 12, 8))    # longest hangtime/reach -- air-space control
	return out


static func _build_arc_projectile(state_id: int, proj_id: int, id_group: int,
		spawn_vel_x: float, spawn_vel_y: float, gravity: int,
		damage: int, hitstun: int, blockstun: int, hitstop: int) -> MoveState:
	var m := MoveState.new()
	m.id = state_id
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = ARC_CHAR_STARTUP + 1 + ARC_CHAR_RECOVERY
	m.loop = false

	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = ARC_SPAWN_FRAME - 1
	kf_start.hurtboxes = [_hurt_stand()]

	var kf_spawn := Keyframe.new()
	kf_spawn.frame_start = ARC_SPAWN_FRAME
	kf_spawn.frame_end = ARC_SPAWN_FRAME
	kf_spawn.hurtboxes = [_hurt_stand()]
	kf_spawn.has_spawn = true
	kf_spawn.spawn_projectile = _arc_projectile_data(proj_id, id_group, gravity,
		damage, hitstun, blockstun, hitstop)
	kf_spawn.spawn_offset_x = FP.from_int(20)     # released in front of the character
	kf_spawn.spawn_offset_y = FP.from_int(-55)    # AD-037: reflected -- chest height, above the feet-origin
	kf_spawn.spawn_velocity_x = FP.from_units(spawn_vel_x)
	kf_spawn.spawn_velocity_y = FP.from_units(spawn_vel_y)   # negative = up (AD-037), then
															   # ProjectileData.gravity pulls it
															   # back down into the arc (AD-047)

	var kf_rec := Keyframe.new()
	kf_rec.frame_start = ARC_SPAWN_FRAME + 1
	kf_rec.frame_end = m.duration
	kf_rec.hurtboxes = [_hurt_stand()]

	m.timeline = [kf_start, kf_spawn, kf_rec]
	m.cancels = []
	return m


## The authored ProjectileData shell (AD-021/030/047): id/hitbox/lifetime/
## max_per_owner/gravity. Owner and initial position/velocity come from the
## cast + the spawn keyframe (authored above), NOT here.
static func _arc_projectile_data(proj_id: int, id_group: int, gravity: int,
		damage: int, hitstun: int, blockstun: int, hitstop: int) -> ProjectileData:
	var data := ProjectileData.new()
	data.id = proj_id
	data.lifetime = ARC_LIFETIME
	data.max_per_owner = ARC_MAX_PER_OWNER
	data.gravity = gravity   # AD-047: nonzero -> parabolic arc + ground-contact despawn
	var hb := HitBox.new()
	# NOT reflected (AD-037): symmetric about the projectile's own center, no feet
	# line to reflect against (mirrors character_a.gd's fireball hitbox note).
	hb.box = Box.make(FP.from_int(-14), FP.from_int(-14), FP.from_int(28), FP.from_int(28))
	hb.hit_kind = HitBox.HIT_KIND_PROJECTILE
	hb.guard_height = HitBox.GUARD_MID   # logged judgment call (B-2/AD-047) -- see file header block above
	hb.damage = damage
	hb.hitstun = hitstun
	hb.blockstun = blockstun
	hb.hitstop = hitstop
	hb.pushback_hit = FP.from_units(2.0)
	hb.pushback_block = FP.from_units(1.0)
	hb.hit_reaction = MoveState.REACTION_HITSTUN
	hb.block_reaction = MoveState.REACTION_BLOCKSTUN
	hb.id_group = id_group
	hb.rehit_interval = 0
	data.hitbox = hb
	return data


# =============================================================================
# Divekick (character-b.md -> Specials -> Divekick; TKT-P2-06). An aerial
# special ("2+attack in air") reached via JUMP_N/F/B's own CancelRules
# (_divekick_cancels) resolving each version's DOWN+button button_map entry.
# Does NOT spend the air action (AD-046) -- it never runs through
# StepPhases._apply_air_action at all, so there is nothing to un-couple.
#
# TRAJECTORY MODEL (AD-043 velocity-sets): a HANG keyframe authors has_motion
# on EVERY covered frame with the SAME literal (small/zero) vel_y -- since
# StepPhases._apply_keyframe_motion re-evaluates every tick and gravity is
# added AFTER the keyframe's set, a fixed authored vel_y is re-imposed each
# hang tick BEFORE gravity's per-tick addition, giving a near-flat hang (drifts
## by exactly `gravity` per tick, never accelerating) instead of a free fall --
# "zero/low vertical velocity for N frames," per the brief. The DIVE is then a
# SINGLE-FRAME impulse (mirrors the jump takeoff / character_a.gd's own
# convention) that SETS a strong vel_y (+ vel_x per version); every frame after
# that authors NO motion, so gravity + the inherited velocity carry an
# accelerating plummet, exactly like the ordinary jump arc.
#
# B-3 (headless-checkable): hang duration STRICTLY increases L < M < H, and
# each version's dive vel_x/vel_y are pairwise distinct -- the three
# trajectories are measurably different, and H's hang is the LONGEST (the
# readable "overhead is coming" tell, character-b.md).
# =============================================================================
const DIVEKICK_L_HANG: int = 4
const DIVEKICK_M_HANG: int = 9
const DIVEKICK_H_HANG: int = 16   # longest -- the readable overhead tell (character-b.md)

const DIVEKICK_L_DIVE_VX: float = 1.0
const DIVEKICK_L_DIVE_VY: float = 9.0    # brief hang, FAST dive (mostly vertical)
const DIVEKICK_M_DIVE_VX: float = 4.5    # more horizontal travel
const DIVEKICK_M_DIVE_VY: float = 6.0
const DIVEKICK_H_DIVE_VX: float = 0.0    # near-vertical plummet (character-b.md)
const DIVEKICK_H_DIVE_VY: float = 10.0

# Blockstun (JC-095 tuning). Named constants, not inline literals, because
# AD-050 pins an EQUALITY between each divekick's own blockstun and its
# landing-recovery `duration` -- referencing the SAME constant from both
# `_build_divekicks()` and `_build_divekick_landing_states()` below makes the
# invariant hold BY CONSTRUCTION rather than by two call sites happening to
# agree on a literal.
const DIVEKICK_L_BLOCKSTUN: int = 9
const DIVEKICK_M_BLOCKSTUN: int = 11
const DIVEKICK_H_BLOCKSTUN: int = 13

const DIVEKICK_SAFETY_TAIL: int = 30   # safety bound above physical fall time (mirrors the
										 # jump arc's own JUMP_DURATION convention) -- the
										 # continuous ground clamp, not this duration, is what
										 # actually ends the move (AD-043). AD-050 (TKT-P2-11):
										 # the active hitbox now runs ALL THE WAY to `duration`
										 # (through the whole descent) instead of stopping after
										 # a fixed DIVEKICK_ACTIVE window -- `active_hit_ids`
										 # still guarantees one hit per contact (AD-026), so the
										 # long window is one hit available anywhere in the fall,
										 # never a machine-gun.

# Landing-recovery state ids (AD-050, TKT-P2-11) -- one per divekick strength,
# since L/M/H each author a DIFFERENT blockstun (the AD-050 equality invariant
# is per-move: recovery `duration` == THAT divekick's own `HitBox.blockstun`).
const STATE_DIVEKICK_L_LANDING: int = 378
const STATE_DIVEKICK_M_LANDING: int = 379
const STATE_DIVEKICK_H_LANDING: int = 380


static func _build_divekicks() -> Array[MoveState]:
	var out: Array[MoveState] = []
	out.append(_build_divekick(STATE_DIVEKICK_L, STATE_DIVEKICK_L_LANDING, IDG_DIVEKICK_L,
		DIVEKICK_L_HANG, DIVEKICK_L_DIVE_VX, DIVEKICK_L_DIVE_VY, HitBox.GUARD_MID, 35, 14, DIVEKICK_L_BLOCKSTUN, 7))
	out.append(_build_divekick(STATE_DIVEKICK_M, STATE_DIVEKICK_M_LANDING, IDG_DIVEKICK_M,
		DIVEKICK_M_HANG, DIVEKICK_M_DIVE_VX, DIVEKICK_M_DIVE_VY, HitBox.GUARD_MID, 45, 16, DIVEKICK_M_BLOCKSTUN, 8))
	out.append(_build_divekick(STATE_DIVEKICK_H, STATE_DIVEKICK_H_LANDING, IDG_DIVEKICK_H,
		DIVEKICK_H_HANG, DIVEKICK_H_DIVE_VX, DIVEKICK_H_DIVE_VY, HitBox.GUARD_HIGH, 55, 18, DIVEKICK_H_BLOCKSTUN, 9))   # the ONLY overhead
	out.append_array(_build_divekick_landing_states())
	return out


static func _build_divekick(state_id: int, landing_state_id: int, id_group: int, hang_frames: int,
		dive_vx: float, dive_vy: float, guard_height: int,
		damage: int, hitstun: int, blockstun: int, hitstop: int) -> MoveState:
	var m := MoveState.new()
	m.id = state_id
	m.category = MoveState.CATEGORY_AIRBORNE
	# AD-050 (TKT-P2-11): landing redirects into a grounded, non-actionable,
	# once-through recovery state (authored below, `_build_divekick_landing_states`)
	# instead of idle -- `StepPhases._land`'s pinned precedence. This is the
	# format call JC-094's deferral named ("an Architect format call... routed
	# as a flag -- never a content workaround"), now resolved.
	m.landing_state_id = landing_state_id
	m.duration = hang_frames + 1 + DIVEKICK_SAFETY_TAIL

	var kf_hang := Keyframe.new()
	kf_hang.frame_start = 1
	kf_hang.frame_end = hang_frames
	kf_hang.hurtboxes = [_hurt_air()]
	kf_hang.has_motion = true
	kf_hang.motion_vel_x = 0
	kf_hang.motion_vel_y = 0   # re-imposed every hang tick -- see file header note above

	var dive_frame: int = hang_frames + 1
	var kf_dive := Keyframe.new()
	kf_dive.frame_start = dive_frame
	kf_dive.frame_end = dive_frame   # a SINGLE-frame impulse (mirrors the jump takeoff)
	kf_dive.hurtboxes = [_hurt_air()]
	kf_dive.has_motion = true
	kf_dive.motion_vel_x = FP.from_units(dive_vx)
	kf_dive.motion_vel_y = FP.from_units(dive_vy)   # positive = down (AD-037)

	# --- Active-until-ground (AD-050) -----------------------------------------
	# The active hitbox is authored to persist through the WHOLE descent -- from
	# the frame right after the dive impulse all the way to `duration` (the
	# safety-tail upper bound) -- so the state's own end (the AD-043 continuous
	# ground clamp landing it) is what stops the hitbox, not a fixed active
	# window. `active_hit_ids` (AD-026, cleared on state entry) still enforces
	# ONE hit per `id_group` per contact, so this long window is one hit
	# available anywhere in the fall, never repeated damage.
	var active_start: int = dive_frame + 1
	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(10), FP.from_int(-30), FP.from_int(30), FP.from_int(30))
	hb.guard_height = guard_height
	hb.damage = damage
	hb.hitstun = hitstun
	hb.blockstun = blockstun
	hb.hitstop = hitstop
	hb.pushback_hit = FP.from_units(2.0)
	hb.pushback_block = FP.from_units(2.0)
	hb.hit_reaction = MoveState.REACTION_HITSTUN
	hb.block_reaction = MoveState.REACTION_BLOCKSTUN
	hb.id_group = id_group
	var kf_active := Keyframe.new()
	kf_active.frame_start = active_start
	kf_active.frame_end = m.duration
	kf_active.hurtboxes = [_hurt_air()]
	kf_active.hitboxes = [hb]
	# NO motion authored on/after the dive impulse -- gravity + the dive's
	# inherited velocity carry the accelerating plummet (AD-043), exactly like
	# the ordinary jump arc's post-takeoff flight keyframe.

	m.timeline = [kf_hang, kf_dive, kf_active]
	m.cancels = []
	return m


## Landing-recovery states (AD-050, TKT-P2-11): a grounded, non-actionable,
## once-through recovery entered on landing INSTEAD of idle (via
## `MoveState.landing_state_id`, resolved by `StepPhases._land`). `duration` is
## the AD-050 pinned equality -- EXACTLY the corresponding divekick's own
## `HitBox.blockstun` (the JC-095 tuning flag owns the blockstun VALUES; this
## ticket owns the equality). No hitboxes, no cancels: a real commitment
## whether the divekick hit, was blocked, or whiffed entirely (AD-050 -- "a
## single authored value applied on landing regardless of outcome"). One state
## per strength since L/M/H author different blockstun.
static func _build_divekick_landing_states() -> Array[MoveState]:
	var out: Array[MoveState] = []
	out.append(_build_divekick_landing(STATE_DIVEKICK_L_LANDING, DIVEKICK_L_BLOCKSTUN))
	out.append(_build_divekick_landing(STATE_DIVEKICK_M_LANDING, DIVEKICK_M_BLOCKSTUN))
	out.append(_build_divekick_landing(STATE_DIVEKICK_H_LANDING, DIVEKICK_H_BLOCKSTUN))
	return out


static func _build_divekick_landing(state_id: int, blockstun: int) -> MoveState:
	var m := MoveState.new()
	m.id = state_id
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = blockstun   # the AD-050 pinned equality: recovery == this divekick's blockstun
	m.loop = false
	var kf := Keyframe.new()
	kf.frame_start = 1
	kf.frame_end = m.duration
	kf.hurtboxes = [_hurt_stand()]
	m.timeline = [kf]
	m.cancels = []   # a real commitment on every landing -- hit, block, or whiff (AD-050)
	return m


# =============================================================================
# Air normals (character-b.md -> Normals table, j.L/M/H; TKT-P2-06). Carry the
# fall (AD-043) -- author NO motion at all, mirroring character_a.gd's
# _build_air_normal exactly, so the ongoing jump-arc velocity + gravity pass
# through untouched (criterion 4: "does not stop the arc").
# =============================================================================
static func _build_air_normals() -> Array[MoveState]:
	var out: Array[MoveState] = []
	out.append(_build_air_normal(STATE_JL, 4, 6, 30, 9, IDG_JL,
		Box.make(FP.from_int(15), FP.from_int(-40), FP.from_int(25), FP.from_int(20))))
	out.append(_build_air_normal(STATE_JM, 6, 5, 45, 10, IDG_JM,
		Box.make(FP.from_int(15), FP.from_int(-40), FP.from_int(30), FP.from_int(25))))
	out.append(_build_air_normal(STATE_JH, 8, 5, 60, 11, IDG_JH,
		Box.make(FP.from_int(15), FP.from_int(-40), FP.from_int(35), FP.from_int(30))))
	return out


## SAFETY-TAIL FIX (2026-07-17, flags.md "AD-043 air-move semantics"): mirrors
## character_a.gd's IDENTICAL `_build_air_normal` fix exactly -- this builder was
## copied from A's (then-also-buggy) version at TKT-P2-06 time, so B inherited
## the same defect. `duration` now extends `AIR_NORMAL_SAFETY_TAIL` frames past
## startup+active (matching B's own jump `JUMP_DURATION`/divekick
## `DIVEKICK_SAFETY_TAIL` conventions) so the AD-043 continuous ground clamp --
## not the move's own short authored duration -- is what actually ends the
## fall. See character_a.gd's `_build_air_normal` doc comment for the full root-
## cause account (never a TKT-P2-01 regression: the physical clamp itself was
## always correct; this content was simply never revisited when it superseded
## the old duration-based pseudo-landing).
static func _build_air_normal(state_id: int, startup: int, active: int, damage: int,
		hitstop: int, id_group: int, hitbox_box: Box) -> MoveState:
	const AIR_NORMAL_SAFETY_TAIL: int = 50   # mirrors character_a.gd's own margin
	var m := MoveState.new()
	m.id = state_id
	m.category = MoveState.CATEGORY_AIRBORNE
	m.duration = startup + active + AIR_NORMAL_SAFETY_TAIL
	m.loop = false
	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = startup
	kf_start.hurtboxes = [_hurt_air()]
	var hb := HitBox.new()
	hb.box = hitbox_box
	hb.damage = damage
	hb.hitstun = 14
	hb.blockstun = 8
	hb.hitstop = hitstop
	hb.pushback_hit = FP.from_units(1.0)
	hb.pushback_block = FP.from_units(1.0)
	hb.hit_reaction = MoveState.REACTION_HITSTUN
	hb.block_reaction = MoveState.REACTION_BLOCKSTUN
	hb.id_group = id_group
	var kf_active := Keyframe.new()
	kf_active.frame_start = startup + 1
	kf_active.frame_end = startup + active
	kf_active.hurtboxes = [_hurt_air()]
	kf_active.hitboxes = [hb]
	# Safety-tail keyframe: no authored motion -- inherits the ongoing fall
	# (StepPhases._apply_keyframe_motion), supplies only the airborne hurtbox.
	var kf_tail := Keyframe.new()
	kf_tail.frame_start = startup + active + 1
	kf_tail.frame_end = m.duration
	kf_tail.hurtboxes = [_hurt_air()]
	m.timeline = [kf_start, kf_active, kf_tail]
	m.cancels = []   # air normals are not special-cancellable (mirrors character A)
	return m
