class_name TestSupport
extends RefCounted

## Shared programmatic move-data builders for the headless tests (TKT-P0-05/07/10).
## Building characters in code (not .tres) keeps the unit tests self-contained; the
## AUTHORED .tres test character is TKT-P0-10's done-bar artifact. All values are
## baked fixed-point integers (AD-014) — no floats reach the sim.
##
## The built character is deliberately trivial and HAND-COMPUTABLE (move-format.md
## criterion 2): a light attack with startup 4 / active 3 / recovery 6, hitstun 16,
## blockstun 10, so frame data and advantage are checkable by hand.

# --- State ids for the built test character ---------------------------------
const CHAR_ID: int = 1
const STATE_IDLE: int = 0
const STATE_WALK: int = 1
const STATE_LIGHT: int = 10        # a normal attack
const STATE_HITSTUN: int = 20      # forced hit reaction
const STATE_BLOCKSTUN: int = 21    # forced block reaction

# --- TKT-P0-08/09 states (buffer/cancels, throws, multi-hit) -----------------
const STATE_SPECIAL: int = 11      # special-cancel target (tag-gated, TKT-P0-08)
const STATE_REVERSAL: int = 12     # 623 motion reversal (TKT-P0-08 buffered reversal)
const STATE_THROW: int = 13        # a throw (throwbox connect, TKT-P0-09)
const STATE_THROWN: int = 22       # forced throw reaction (defender)
const STATE_MULTI: int = 14        # sequential multi-hit (two id_groups) (TKT-P0-09)
const STATE_REHIT: int = 15        # cadenced rehit (one id_group, rehit_interval) (TKT-P0-09)
const STATE_FIREBALL: int = 16     # spawns a projectile (TKT-P1-0P)

# --- Cancel tag (special-cancel gate) ---------------------------------------
const TAG_SPECIAL: int = 100       # LIGHT's hitbox grants this; SPECIAL requires it

# --- Throw / multi-hit tuning -----------------------------------------------
const THROW_DAMAGE: int = 80
const THROW_HITSTUN: int = 20
const THROW_TECH_WINDOW: int = 8   # frames the defender may tech (authored via HitBox.tech_window, AD-029)
const THROW_ID_GROUP: int = 5
const THROW_PUSHBACK: float = 3.0  # tech/clash separation (units); nonzero so a clash's
                                    # pushback is independently observable (F-011 fix)
const MULTI_DAMAGE: int = 20
const REHIT_DAMAGE: int = 15
const REHIT_INTERVAL: int = 4      # frames between cadenced re-hits
const SPECIAL_DAMAGE: int = 60

# --- Fireball / projectile tuning (TKT-P1-0P) --------------------------------
const PROJECTILE_DATA_ID: int = 1
const FIREBALL_SPAWN_FRAME: int = 3     # the keyframe frame the projectile releases on
const FIREBALL_DAMAGE: int = 30
const FIREBALL_HITSTUN: int = 14
const FIREBALL_BLOCKSTUN: int = 8
const FIREBALL_HITSTOP: int = 6
const FIREBALL_ID_GROUP: int = 50
const FIREBALL_LIFETIME: int = 40
const FIREBALL_MAX_PER_OWNER: int = 1
const FIREBALL_SPEED: int = 4           # units/tick, forward-relative

# --- Hand-computed frame data for STATE_LIGHT -------------------------------
# timeline: frames 1..3 startup (hurt only), 4..6 active (hitbox), 7..12 recovery.
# duration 12. => startup 3? No: startup = first_active - 1. First active frame = 4,
# so startup = 3; active = 6-4+1 = 3; recovery = 12 - 6 = 6; total = 12.
const LIGHT_DURATION: int = 12
const LIGHT_FIRST_ACTIVE: int = 4
const LIGHT_LAST_ACTIVE: int = 6
const LIGHT_STARTUP: int = 3
const LIGHT_ACTIVE: int = 3
const LIGHT_RECOVERY: int = 6

const LIGHT_DAMAGE: int = 40
const LIGHT_HITSTUN: int = 16
const LIGHT_BLOCKSTUN: int = 10
const LIGHT_HITSTOP: int = 8
const LIGHT_ID_GROUP: int = 1

# Reaction-state durations (defender stays stunned this long).
const HITSTUN_DURATION: int = 16
const BLOCKSTUN_DURATION: int = 10


## AD-037: every standing hurtbox literal below (`Box.make(-15, -80, 30, 80)`)
## is the reflected form (was `(-15, 0, 30, 80)`; new_y = -(old_y+old_h) =
## -(0+80) = -80) -- feet at local y=0 (pos_y), head at y=-80. Mirrors
## CharacterA._hurt_stand()'s convention (TKT-P1.1R-02) so the one box
## convention holds slice-wide.
## Build the trivial test character (move-format.md, hand-computable).
static func build_test_character() -> Character:
	var c := Character.new()
	c.id = CHAR_ID
	c.idle_state_id = STATE_IDLE

	var phys := CharacterPhysics.new()
	phys.walk_speed = FP.from_units(2.0)   # 2 units/tick, baked fixed-point
	phys.gravity = 0
	phys.jump_velocity = 0
	c.physics = phys

	c.default_pushbox = Box.make(   # AD-037: reflected -> lower/nearer-to-feet portion of the hurtbox
		FP.from_int(-10), FP.from_int(-40), FP.from_int(20), FP.from_int(40))

	c.states = [
		_build_idle(),
		_build_walk(),
		_build_light(),
		_build_hitstun(),
		_build_blockstun(),
		_build_special(),
		_build_reversal(),
		_build_throw(),
		_build_thrown(),
		_build_multi(),
		_build_rehit(),
		_build_fireball(),
	]

	# button_map (evaluated in authored order; first satisfied buffered command wins):
	#   - 623 + BUTTON_2  -> REVERSAL (motion; buffered reversal, TKT-P0-08). FIRST so a
	#     dragon-punch motion is recognized before a bare BUTTON_2 falls through.
	#   - BUTTON_1        -> SPECIAL (special-cancel target; also a raw press in neutral).
	#   - BUTTON_2 + DOWN -> THROW (a throw command; DOWN-gated to avoid clashing REVERSAL).
	#   - UP + BUTTON_0   -> FIREBALL (spawns a projectile, TKT-P1-0P; UP-gated so it does
	#     not clash the bare-BUTTON_0 LIGHT command).
	#   - BUTTON_0        -> LIGHT (the normal; special-cancellable into SPECIAL).
	c.button_map = [
		_map(-1, 0, InputBuffer.MOTION_623, STATE_REVERSAL, 2),   # 623 + B2
		_map(1, 0, 0, STATE_SPECIAL),                             # B1
		_map(2, InputFrame.DOWN, 0, STATE_THROW),                 # B2 + down
		_map(0, InputFrame.UP, 0, STATE_FIREBALL),                # B0 + up
		_map(0, 0, 0, STATE_LIGHT),                               # B0
	]
	return c


## Build one ButtonMapEntry. `motion_button` (default -1) sets a button that a MOTION
## entry additionally requires (e.g. 623 + BUTTON_2); pass -1 for a pure motion.
static func _map(button_index: int, required_direction: int, motion: int,
		target_state_id: int, motion_button: int = -1) -> ButtonMapEntry:
	var e := ButtonMapEntry.new()
	e.button_index = motion_button if motion != InputBuffer.MOTION_NONE else button_index
	e.required_direction = required_direction
	e.motion = motion
	e.target_state_id = target_state_id
	return e


static func _build_idle() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_IDLE
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 1
	m.loop = true
	var kf := Keyframe.new()
	kf.frame_start = 1
	kf.frame_end = 1
	kf.hurtboxes = [Box.make(FP.from_int(-15), FP.from_int(-80), FP.from_int(30), FP.from_int(80))]
	m.timeline = [kf]
	return m


static func _build_walk() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_WALK
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 1
	m.loop = true
	var kf := Keyframe.new()
	kf.frame_start = 1
	kf.frame_end = 1
	kf.hurtboxes = [Box.make(FP.from_int(-15), FP.from_int(-80), FP.from_int(30), FP.from_int(80))]
	kf.has_motion = true
	kf.motion_vel_x = FP.from_units(2.0)   # forward walk speed
	m.timeline = [kf]
	return m


static func _build_light() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_LIGHT
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = LIGHT_DURATION
	m.loop = false

	# Startup: hurtbox only, frames 1..3.
	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = 3
	kf_start.hurtboxes = [Box.make(FP.from_int(-15), FP.from_int(-80), FP.from_int(30), FP.from_int(80))]

	# Active: hurtbox + hitbox, frames 4..6. Two OVERLAPPING hitboxes sharing one
	# id_group so the single-hit rule (criterion 5) is testable — both point forward.
	# AD-037: the y arg passed here is the already-REFLECTED box top edge
	# (_make_light_hitbox's fixed h=20, so new_y = -(40+20) = -60; was 40).
	var hb1 := _make_light_hitbox(FP.from_int(30), FP.from_int(-60))
	var hb2 := _make_light_hitbox(FP.from_int(40), FP.from_int(-60))   # overlaps hb1
	var kf_active := Keyframe.new()
	kf_active.frame_start = 4
	kf_active.frame_end = 6
	kf_active.hurtboxes = [Box.make(FP.from_int(-15), FP.from_int(-80), FP.from_int(30), FP.from_int(80))]
	kf_active.hitboxes = [hb1, hb2]

	# Recovery: hurtbox only, frames 7..12.
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 7
	kf_rec.frame_end = 12
	kf_rec.hurtboxes = [Box.make(FP.from_int(-15), FP.from_int(-80), FP.from_int(30), FP.from_int(80))]

	m.timeline = [kf_start, kf_active, kf_rec]

	# Special-cancel (TKT-P0-08, AD-015): on hit or block, within the active window
	# onward, BUTTON_1 cancels LIGHT into SPECIAL — gated by TAG_SPECIAL, which LIGHT's
	# hitbox grants on connect. The requires_tag makes this a special-cancel, not a
	# free gatling; on_contact makes it available on hit AND block.
	var cancel := CancelRule.new()
	cancel.target = STATE_SPECIAL
	cancel.condition = CancelRule.CONDITION_ON_CONTACT
	cancel.window_start = 0            # default: first-active -> end
	cancel.window_end = 0
	cancel.input = InputFrame.BUTTON_1
	cancel.requires_tag = TAG_SPECIAL
	m.cancels = [cancel]
	return m


static func _make_light_hitbox(x: int, y: int) -> HitBox:
	var hb := HitBox.new()
	hb.box = Box.make(x, y, FP.from_int(30), FP.from_int(20))
	hb.damage = LIGHT_DAMAGE
	hb.hitstun = LIGHT_HITSTUN
	hb.blockstun = LIGHT_BLOCKSTUN
	hb.hitstop = LIGHT_HITSTOP
	hb.pushback_hit = FP.from_units(3.0)
	hb.pushback_block = FP.from_units(2.0)
	hb.hit_reaction = STATE_HITSTUN
	hb.block_reaction = STATE_BLOCKSTUN
	hb.id_group = LIGHT_ID_GROUP
	hb.rehit_interval = 0
	# LIGHT grants the special-cancel tag on connect (usable T+1, AD-017).
	hb.cancel_tags = PackedInt32Array([TAG_SPECIAL])
	return hb


static func _build_hitstun() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_HITSTUN
	m.category = MoveState.CATEGORY_HITSTUN
	m.duration = HITSTUN_DURATION
	m.loop = false
	var kf := Keyframe.new()
	kf.frame_start = 1
	kf.frame_end = HITSTUN_DURATION
	kf.hurtboxes = [Box.make(FP.from_int(-15), FP.from_int(-80), FP.from_int(30), FP.from_int(80))]
	m.timeline = [kf]
	return m


static func _build_blockstun() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_BLOCKSTUN
	m.category = MoveState.CATEGORY_BLOCKSTUN
	m.duration = BLOCKSTUN_DURATION
	m.loop = false
	var kf := Keyframe.new()
	kf.frame_start = 1
	kf.frame_end = BLOCKSTUN_DURATION
	kf.hurtboxes = [Box.make(FP.from_int(-15), FP.from_int(-80), FP.from_int(30), FP.from_int(80))]
	m.timeline = [kf]
	return m


# --- TKT-P0-08/09 move builders ---------------------------------------------

## A standard hurtbox (the character-local shape shared by every non-attacking frame).
static func _hurt() -> Box:
	return Box.make(FP.from_int(-15), FP.from_int(-80), FP.from_int(30), FP.from_int(80))


## A forward hitbox reaching into where the opponent's hurtbox sits.
static func _fwd_hitbox(damage: int, id_group: int, rehit_interval: int = 0) -> HitBox:
	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(30), FP.from_int(-60), FP.from_int(30), FP.from_int(20))   # AD-037 reflected
	hb.damage = damage
	hb.hitstun = LIGHT_HITSTUN
	hb.blockstun = LIGHT_BLOCKSTUN
	hb.hitstop = 0                 # 0 so multi-hit/rehit cadence isn't frozen by hitstop
	hb.pushback_hit = 0
	hb.pushback_block = 0
	hb.hit_reaction = STATE_HITSTUN
	hb.block_reaction = STATE_BLOCKSTUN
	hb.id_group = id_group
	hb.rehit_interval = rehit_interval
	return hb


## SPECIAL (special-cancel target): startup 3, active 4..6, recovery to 12. id_group 2.
static func _build_special() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_SPECIAL
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 12
	m.loop = false
	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = 3
	kf_start.hurtboxes = [_hurt()]
	var kf_active := Keyframe.new()
	kf_active.frame_start = 4
	kf_active.frame_end = 6
	kf_active.hurtboxes = [_hurt()]
	kf_active.hitboxes = [_fwd_hitbox(SPECIAL_DAMAGE, 2)]
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 7
	kf_rec.frame_end = 12
	kf_rec.hurtboxes = [_hurt()]
	m.timeline = [kf_start, kf_active, kf_rec]
	return m


## REVERSAL (623 buffered reversal): active on frame 1 (a true frame-1 reversal). Short.
static func _build_reversal() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_REVERSAL
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 10
	m.loop = false
	var kf_active := Keyframe.new()
	kf_active.frame_start = 1
	kf_active.frame_end = 2
	kf_active.hurtboxes = [_hurt()]
	kf_active.hitboxes = [_fwd_hitbox(50, 3)]
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 3
	kf_rec.frame_end = 10
	kf_rec.hurtboxes = [_hurt()]
	m.timeline = [kf_active, kf_rec]
	return m


## THROW: throwbox active frames 1..3; connect enters STATE_THROWN on the defender and
## opens a tech window (authored via the dedicated HitBox.tech_window, AD-029). id_group THROW_ID_GROUP.
static func _build_throw() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_THROW
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 12
	m.loop = false
	var tb := HitBox.new()
	tb.box = Box.make(FP.from_int(20), FP.from_int(-60), FP.from_int(40), FP.from_int(60))   # AD-037 reflected
	tb.damage = THROW_DAMAGE
	tb.hitstun = THROW_HITSTUN
	tb.tech_window = THROW_TECH_WINDOW   # dedicated tech-window frame count (AD-029)
	tb.pushback_hit = FP.from_units(THROW_PUSHBACK)   # clash/tech separation (AD-016)
	tb.hitstop = 0
	tb.hit_reaction = STATE_THROWN
	tb.block_reaction = STATE_THROWN
	tb.id_group = THROW_ID_GROUP
	tb.is_throw = true
	var kf := Keyframe.new()
	kf.frame_start = 1
	kf.frame_end = 3
	kf.hurtboxes = [_hurt()]
	kf.hitboxes = [tb]
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 4
	kf_rec.frame_end = 12
	kf_rec.hurtboxes = [_hurt()]
	m.timeline = [kf, kf_rec]
	return m


## THROWN: the defender's forced throw reaction (a hitstun-category reaction state).
static func _build_thrown() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_THROWN
	m.category = MoveState.CATEGORY_HITSTUN
	m.duration = THROW_HITSTUN
	m.loop = false
	var kf := Keyframe.new()
	kf.frame_start = 1
	kf.frame_end = THROW_HITSTUN
	kf.hurtboxes = [_hurt()]
	m.timeline = [kf]
	return m


## MULTI (sequential multi-hit): two DISTINCT id_groups across two keyframes (frames
## 2..3 group 10, frames 6..7 group 11) — each lands once (AD-016 sequential form).
static func _build_multi() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_MULTI
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 16
	m.loop = false
	var kf_a := Keyframe.new()
	kf_a.frame_start = 2
	kf_a.frame_end = 3
	kf_a.hurtboxes = [_hurt()]
	kf_a.hitboxes = [_fwd_hitbox(MULTI_DAMAGE, 10)]
	var kf_gap := Keyframe.new()
	kf_gap.frame_start = 4
	kf_gap.frame_end = 5
	kf_gap.hurtboxes = [_hurt()]
	var kf_b := Keyframe.new()
	kf_b.frame_start = 6
	kf_b.frame_end = 7
	kf_b.hurtboxes = [_hurt()]
	kf_b.hitboxes = [_fwd_hitbox(MULTI_DAMAGE, 11)]
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 8
	kf_rec.frame_end = 16
	kf_rec.hurtboxes = [_hurt()]
	m.timeline = [kf_a, kf_gap, kf_b, kf_rec]
	return m


## REHIT (cadenced): ONE id_group active frames 1..12 with rehit_interval 4 — hits on
## the first active frame, then again only once 4 frames have elapsed, and so on.
static func _build_rehit() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_REHIT
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 16
	m.loop = false
	var kf := Keyframe.new()
	kf.frame_start = 1
	kf.frame_end = 12
	kf.hurtboxes = [_hurt()]
	kf.hitboxes = [_fwd_hitbox(REHIT_DAMAGE, 20, REHIT_INTERVAL)]
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 13
	kf_rec.frame_end = 16
	kf_rec.hurtboxes = [_hurt()]
	m.timeline = [kf, kf_rec]
	return m


## FIREBALL (spawns a projectile, TKT-P1-0P): startup 1..2, releases the
## projectile on frame FIREBALL_SPAWN_FRAME (a keyframe covering that one frame
## carries the spawn action), then recovers. The move itself carries NO hitbox of
## its own — all damage comes from the spawned projectile — so a connect can only
## be attributed to the projectile, not the move's own (nonexistent) hitbox.
static func _build_fireball() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_FIREBALL
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 14
	m.loop = false

	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = FIREBALL_SPAWN_FRAME - 1
	kf_start.hurtboxes = [_hurt()]

	var kf_spawn := Keyframe.new()
	kf_spawn.frame_start = FIREBALL_SPAWN_FRAME
	kf_spawn.frame_end = FIREBALL_SPAWN_FRAME
	kf_spawn.hurtboxes = [_hurt()]
	kf_spawn.has_spawn = true
	kf_spawn.spawn_projectile = build_projectile_data()
	kf_spawn.spawn_offset_x = FP.from_int(20)   # released in front of the character
	kf_spawn.spawn_offset_y = FP.from_int(-40)   # AD-037: reflected (scalar point, spawn_y = pos_y + offset_y)
	kf_spawn.spawn_velocity_x = FP.from_units(float(FIREBALL_SPEED))
	kf_spawn.spawn_velocity_y = 0

	var kf_rec := Keyframe.new()
	kf_rec.frame_start = FIREBALL_SPAWN_FRAME + 1
	kf_rec.frame_end = 14
	kf_rec.hurtboxes = [_hurt()]

	m.timeline = [kf_start, kf_spawn, kf_rec]
	return m


## The authored ProjectileData shell for the test fireball (TKT-P1-0P). A forward
## hitbox, hand-computable damage/hitstun/blockstun, capped at
## FIREBALL_MAX_PER_OWNER live per owner.
static func build_projectile_data() -> ProjectileData:
	var data := ProjectileData.new()
	data.id = PROJECTILE_DATA_ID
	data.lifetime = FIREBALL_LIFETIME
	data.max_per_owner = FIREBALL_MAX_PER_OWNER
	var hb := HitBox.new()
	# AD-037: NOT reflected -- symmetric about the projectile's own center
	# ([-10,+10], not feet-anchored); new_y = -(y+h) = -(-10+20) = -10, unchanged.
	hb.box = Box.make(FP.from_int(-10), FP.from_int(-10), FP.from_int(20), FP.from_int(20))
	hb.hit_kind = HitBox.HIT_KIND_PROJECTILE   # AD-031: a projectile's carried hitbox is PROJECTILE
	hb.damage = FIREBALL_DAMAGE
	hb.hitstun = FIREBALL_HITSTUN
	hb.blockstun = FIREBALL_BLOCKSTUN
	hb.hitstop = FIREBALL_HITSTOP
	hb.pushback_hit = FP.from_units(2.0)
	hb.pushback_block = FP.from_units(1.0)
	hb.hit_reaction = STATE_HITSTUN
	hb.block_reaction = STATE_BLOCKSTUN
	hb.id_group = FIREBALL_ID_GROUP
	hb.rehit_interval = 0
	data.hitbox = hb
	return data


## A roster dict mapping character_id -> Character for the inspection surface / sim.
static func build_roster() -> Dictionary:
	var c := build_test_character()
	return {c.id: c}


## A ProjectileRegistry roster (data_id -> ProjectileData) matching the fireball
## authored above. Tests that spawn projectiles must ProjectileRegistry.install()
## this (mirroring MoveRegistry.install(build_roster())) so a restored/hashed
## projectile's hitbox re-attaches correctly (AD-024).
static func build_projectile_registry() -> Dictionary:
	var data := build_projectile_data()
	return {data.id: data}
