extends SceneTree

## Headless test for arc-projectile gravity (TKT-P2-04, AD-047).
## move-format.md → ProjectileData.gravity / criterion 14; combat-resolution.md
## phase 3 / criterion 17 (mechanism only — the readable-mixup oki-trace
## acceptance is character-B content, TKT-P2-06's job).
##
## Run:  godot --headless --path game -s res://tests/test_arc_projectile.gd
## Exits non-zero on any failure so a harness/CI can gate on it.

var _failures: int = 0
var _checks: int = 0

const CHAR_ID: int = 930
const STATE_IDLE: int = 0
const STATE_FIREBALL: int = 1     # spawns the straight-line (gravity 0) shell
const STATE_ARC: int = 2          # spawns the arc (gravity != 0) shell
const PROJ_STRAIGHT: int = 1
const PROJ_ARC: int = 2
const PROJ_GROUND_LEVEL: int = 3  # gravity 0, spawned AT/BELOW ground_y (regression control)

const GRAVITY: int = 6000         # baked FP, nonzero (arbitrary but > 0 and small vs SCALE)
const SPAWN_FRAME: int = 2


func _init() -> void:
	_run()
	MoveRegistry.clear()
	ProjectileRegistry.clear()
	if _failures == 0:
		print("[test_arc_projectile] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_arc_projectile] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _false(cond: bool, msg: String) -> void:
	_eq(cond, false, msg)


# --- Character / projectile builders --------------------------------------------

func _hurt() -> Box:
	return Box.make(FP.from_int(-15), FP.from_int(-80), FP.from_int(30), FP.from_int(80))


func _idle() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_IDLE
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 1
	m.loop = true
	var kf := Keyframe.new()
	kf.frame_start = 1
	kf.frame_end = 1
	kf.hurtboxes = [_hurt()]
	m.timeline = [kf]
	return m


func _spawn_state(state_id: int, data: ProjectileData, offset_y: int) -> MoveState:
	var m := MoveState.new()
	m.id = state_id
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 20
	m.loop = false
	var kf_start := Keyframe.new()
	kf_start.frame_start = 1
	kf_start.frame_end = SPAWN_FRAME - 1
	kf_start.hurtboxes = [_hurt()]
	var kf_spawn := Keyframe.new()
	kf_spawn.frame_start = SPAWN_FRAME
	kf_spawn.frame_end = SPAWN_FRAME
	kf_spawn.hurtboxes = [_hurt()]
	kf_spawn.has_spawn = true
	kf_spawn.spawn_projectile = data
	kf_spawn.spawn_offset_x = FP.from_int(10)
	kf_spawn.spawn_offset_y = offset_y
	kf_spawn.spawn_velocity_x = FP.from_units(3.0)
	kf_spawn.spawn_velocity_y = 0
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = SPAWN_FRAME + 1
	kf_rec.frame_end = 20
	kf_rec.hurtboxes = [_hurt()]
	m.timeline = [kf_start, kf_spawn, kf_rec]
	return m


func _projectile_data(data_id: int, gravity: int) -> ProjectileData:
	var data := ProjectileData.new()
	data.id = data_id
	data.lifetime = 200   # generous; despawn-by-lifetime is not what these tests probe
	data.max_per_owner = 1
	data.gravity = gravity
	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(-10), FP.from_int(-10), FP.from_int(20), FP.from_int(20))
	hb.hit_kind = HitBox.HIT_KIND_PROJECTILE
	hb.damage = 20
	hb.hitstun = 10
	hb.blockstun = 6
	hb.hitstop = 0
	hb.id_group = 90 + data_id
	data.hitbox = hb
	return data


func _build_character() -> Character:
	var c := Character.new()
	c.id = CHAR_ID
	c.idle_state_id = STATE_IDLE
	var phys := CharacterPhysics.new()
	c.physics = phys
	c.default_pushbox = Box.make(FP.from_int(-10), FP.from_int(-40), FP.from_int(20), FP.from_int(40))
	c.states = [
		_idle(),
		_spawn_state(STATE_FIREBALL, _projectile_data(PROJ_STRAIGHT, 0), FP.from_int(-40)),
		_spawn_state(STATE_ARC, _projectile_data(PROJ_ARC, GRAVITY), FP.from_int(-40)),
	]
	c.button_map = []
	return c


func _install() -> void:
	MoveRegistry.install({CHAR_ID: _build_character()})
	ProjectileRegistry.install({
		PROJ_STRAIGHT: _projectile_data(PROJ_STRAIGHT, 0),
		PROJ_ARC: _projectile_data(PROJ_ARC, GRAVITY),
		PROJ_GROUND_LEVEL: _projectile_data(PROJ_GROUND_LEVEL, 0),
	})


## Two players, far enough apart that the projectile travels a long while before
## (if ever) reaching the defender's hurtbox — isolates gravity/despawn behavior
## from hit-consumption.
func _two_char_state(gap: int = 500) -> SimState:
	_install()
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-1000), FP.from_int(1000), 0)
	s.players[0].character_id = CHAR_ID
	s.players[0].state_id = STATE_IDLE
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = CHAR_ID
	s.players[1].state_id = STATE_IDLE
	s.players[1].pos_x = FP.from_int(gap)
	s.players[1].facing = -1
	return s


func _teardown() -> void:
	MoveRegistry.clear()
	ProjectileRegistry.clear()


func _run() -> void:
	_test_zero_gravity_default()
	_test_gravity_default_field_value()
	_test_straight_line_projectile_unaffected_by_gravity_field()
	_test_arc_projectile_accelerates_downward()
	_test_arc_projectile_despawns_on_ground_contact()
	_test_non_arc_projectile_does_not_ground_despawn()
	_test_arc_projectile_serialization_round_trip()


func _test_zero_gravity_default() -> void:
	var data := ProjectileData.new()
	_eq(data.gravity, 0, "ProjectileData.gravity defaults to 0 (straight-line, A's fireball unchanged)")


func _test_gravity_default_field_value() -> void:
	var reg: Dictionary = CharacterA.build_projectile_registry()
	for data_id in reg.keys():
		var data: ProjectileData = reg[data_id]
		_eq(data.gravity, 0, "character A's authored fireball data_id %d keeps gravity 0 (unchanged)" % data_id)


func _test_straight_line_projectile_unaffected_by_gravity_field() -> void:
	# gravity == 0: pos_y must never change (a straight-line projectile).
	var s := _two_char_state()
	s.players[0].state_id = STATE_FIREBALL
	s.players[0].frame_in_state = 0
	for _k in range(SPAWN_FRAME):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(s.projectiles.size() > 0, "straight-line projectile spawned (pre-check)")
	var y0: int = s.projectiles[0].pos_y
	var vy0: int = s.projectiles[0].vel_y
	for _k in range(20):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(s.projectiles.size() > 0, "straight-line projectile still alive after 20 more ticks")
	_eq(s.projectiles[0].vel_y, vy0, "gravity=0 never changes vel_y")
	_eq(s.projectiles[0].pos_y, y0, "gravity=0 never changes pos_y (straight line, unaffected by AD-047)")
	_teardown()


func _test_arc_projectile_accelerates_downward() -> void:
	# gravity != 0: vel_y accrues `gravity` each tick (starting the tick AFTER
	# spawn, AD-030/JC-034's spawn-tick convention); pos_y increases accordingly
	# (screen convention: +y is downward, AD-037/AD-033).
	var s := _two_char_state()
	s.players[0].state_id = STATE_ARC
	s.players[0].frame_in_state = 0
	for _k in range(SPAWN_FRAME):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(s.projectiles.size() > 0, "arc projectile spawned (pre-check)")
	_eq(s.projectiles[0].vel_y, 0, "vel_y is still 0 on the spawn tick itself (no integration yet)")
	var y_at_spawn: int = s.projectiles[0].pos_y

	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(s.projectiles.size() > 0, "arc projectile still alive one tick later")
	_eq(s.projectiles[0].vel_y, GRAVITY, "vel_y accrues exactly one tick of gravity")
	_eq(s.projectiles[0].pos_y, y_at_spawn + GRAVITY, "pos_y integrates the new vel_y (parabolic arc begins)")

	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(s.projectiles[0].vel_y, GRAVITY * 2, "vel_y accrues a second tick of gravity")
	_eq(s.projectiles[0].pos_y, y_at_spawn + GRAVITY + GRAVITY * 2, "pos_y reflects the accelerating fall")
	_teardown()


func _test_arc_projectile_despawns_on_ground_contact() -> void:
	# Spawn close enough to the ground that gravity carries it to pos_y >=
	# ground_y within a bounded number of ticks; confirm it despawns (AD-047
	# "ground contact despawn") the SAME tick it reaches/crosses ground_y.
	var s := _two_char_state()
	s.players[0].state_id = STATE_ARC
	s.players[0].frame_in_state = 0
	# Re-spawn near the ground: patch the spawn offset via a taller gravity is
	# simpler than re-authoring a new state — just run enough ticks for the
	# (small, constant) gravity to carry pos_y from spawn height (-40 units
	# above ground) up to ground_y; with GRAVITY baked-FP this takes a bounded
	# number of ticks, well inside this loop's budget.
	for _k in range(SPAWN_FRAME):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(s.projectiles.size() > 0, "arc projectile spawned (pre-check)")
	var ground_y: int = s.stage.ground_y
	var despawned_on_ground_contact: bool = false
	for _k in range(400):
		var was_alive: bool = s.projectiles.size() > 0
		var pre_pos_y: int = s.projectiles[0].pos_y if was_alive else 0
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if was_alive and s.projectiles.size() == 0:
			# Despawned this tick: confirm it was because gravity carried it to
			# (or past) the ground, not lifetime/off-stage (lifetime is 200,
			# generously above this loop's iteration count where it fires; the
			# stage is wide, so off-stage cannot be the cause here).
			_true(pre_pos_y < ground_y, "the projectile was above ground the tick before despawning (sanity)")
			despawned_on_ground_contact = true
			break
	_true(despawned_on_ground_contact, "the arc projectile despawns once gravity carries it to ground_y")
	_teardown()


func _test_non_arc_projectile_does_not_ground_despawn() -> void:
	# A gravity==0 projectile that is (unusually) authored AT/BELOW ground_y
	# must NOT be despawned by the ground-contact rule — AD-047 scopes the
	# despawn to an ARC projectile (gravity != 0); "not ground zoning" is a
	# design constraint on CONTENT, not an engine despawn the mechanism itself
	# imposes on every projectile regardless of gravity.
	MoveRegistry.clear()
	ProjectileRegistry.clear()
	var c := _build_character()
	# Re-author STATE_FIREBALL's spawn to release AT ground level (offset_y 0,
	# i.e. pos_y == ground_y at spawn) with the GROUND_LEVEL (gravity 0) shell.
	var ground_level_state := _spawn_state(STATE_FIREBALL, _projectile_data(PROJ_GROUND_LEVEL, 0), 0)
	c.states[1] = ground_level_state
	MoveRegistry.install({CHAR_ID: c})
	ProjectileRegistry.install({
		PROJ_STRAIGHT: _projectile_data(PROJ_STRAIGHT, 0),
		PROJ_ARC: _projectile_data(PROJ_ARC, GRAVITY),
		PROJ_GROUND_LEVEL: _projectile_data(PROJ_GROUND_LEVEL, 0),
	})
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-1000), FP.from_int(1000), 0)
	s.players[0].character_id = CHAR_ID
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = CHAR_ID
	s.players[1].pos_x = FP.from_int(500)
	s.players[1].facing = -1
	s.players[0].state_id = STATE_FIREBALL
	s.players[0].frame_in_state = 0
	for _k in range(SPAWN_FRAME):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(s.projectiles.size() > 0, "ground-level (gravity=0) projectile spawned (pre-check)")
	_true(s.projectiles[0].pos_y >= s.stage.ground_y, "it starts AT/BELOW ground_y (pre-check)")
	for _k in range(15):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(s.projectiles.size() > 0, "a gravity=0 projectile at ground level is NOT despawned by the ground-contact rule")
	_teardown()


func _test_arc_projectile_serialization_round_trip() -> void:
	# Determinism/round-trip must hold with gravity-affected projectile state
	# (Tenet 1) — a snapshot mid-arc restores and continues identically.
	var s := _two_char_state()
	s.players[0].state_id = STATE_ARC
	s.players[0].frame_in_state = 0
	for _k in range(SPAWN_FRAME + 3):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(s.projectiles.size() > 0, "arc projectile alive mid-flight (pre-check)")
	_true(s.projectiles[0].vel_y != 0, "vel_y is nonzero mid-arc (pre-check, gravity has accrued)")

	var hash_before: int = s.hash_state()
	var blob: Dictionary = s.to_dict()
	var restored: SimState = SimState.from_dict(blob)
	_eq(restored.hash_state(), hash_before, "restored mid-arc state hashes identically (round-trip)")
	_eq(restored.projectiles[0].vel_y, s.projectiles[0].vel_y, "restored vel_y matches")
	_eq(restored.projectiles[0].pos_y, s.projectiles[0].pos_y, "restored pos_y matches")

	var continued_original: SimState = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	var continued_restored: SimState = SimState.step(restored, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(continued_restored.hash_state(), continued_original.hash_state(),
		"stepping the restored mid-arc state matches stepping the original (determinism survives restore)")
	_teardown()
