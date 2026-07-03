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

	c.default_pushbox = Box.make(
		FP.from_int(-10), FP.from_int(0), FP.from_int(20), FP.from_int(40))

	c.states = [
		_build_idle(),
		_build_walk(),
		_build_light(),
		_build_hitstun(),
		_build_blockstun(),
	]

	# button_map: BUTTON_0 -> light attack (L). Direction-agnostic.
	var entry := ButtonMapEntry.new()
	entry.button_index = 0            # BUTTON_0
	entry.required_direction = 0
	entry.motion = 0
	entry.target_state_id = STATE_LIGHT
	c.button_map = [entry]
	return c


static func _build_idle() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_IDLE
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 1
	m.loop = true
	var kf := Keyframe.new()
	kf.frame_start = 1
	kf.frame_end = 1
	kf.hurtboxes = [Box.make(FP.from_int(-15), FP.from_int(0), FP.from_int(30), FP.from_int(80))]
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
	kf.hurtboxes = [Box.make(FP.from_int(-15), FP.from_int(0), FP.from_int(30), FP.from_int(80))]
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
	kf_start.hurtboxes = [Box.make(FP.from_int(-15), FP.from_int(0), FP.from_int(30), FP.from_int(80))]

	# Active: hurtbox + hitbox, frames 4..6. Two OVERLAPPING hitboxes sharing one
	# id_group so the single-hit rule (criterion 5) is testable — both point forward.
	var hb1 := _make_light_hitbox(FP.from_int(30), FP.from_int(40))
	var hb2 := _make_light_hitbox(FP.from_int(40), FP.from_int(40))   # overlaps hb1
	var kf_active := Keyframe.new()
	kf_active.frame_start = 4
	kf_active.frame_end = 6
	kf_active.hurtboxes = [Box.make(FP.from_int(-15), FP.from_int(0), FP.from_int(30), FP.from_int(80))]
	kf_active.hitboxes = [hb1, hb2]

	# Recovery: hurtbox only, frames 7..12.
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 7
	kf_rec.frame_end = 12
	kf_rec.hurtboxes = [Box.make(FP.from_int(-15), FP.from_int(0), FP.from_int(30), FP.from_int(80))]

	m.timeline = [kf_start, kf_active, kf_rec]
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
	kf.hurtboxes = [Box.make(FP.from_int(-15), FP.from_int(0), FP.from_int(30), FP.from_int(80))]
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
	kf.hurtboxes = [Box.make(FP.from_int(-15), FP.from_int(0), FP.from_int(30), FP.from_int(80))]
	m.timeline = [kf]
	return m


## A roster dict mapping character_id -> Character for the inspection surface / sim.
static func build_roster() -> Dictionary:
	var c := build_test_character()
	return {c.id: c}
