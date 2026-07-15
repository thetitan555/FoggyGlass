extends SceneTree

## Headless test for directional block enforcement (TKT-P2-03, AD-045).
## move-format.md → HitBox.guard_height / criterion 11; combat-resolution.md
## "Directional block enforcement" / criterion 14; inspection-surface.md →
## HitEvent.guard_height/block_valid / criterion 8. Also covers character A's
## now-enforced `2L`/`2M` lows (the ratified AD-045 scope call).
##
## Run:  godot --headless --path game -s res://tests/test_guard_height.gd
## Exits non-zero on any failure so a harness/CI can gate on it.

var _failures: int = 0
var _checks: int = 0

# --- Minimal test character: one HIGH, one LOW, one MID (default) attack -----
const CHAR_ID: int = 920
const STATE_IDLE: int = 0
const STATE_CROUCH: int = 1
const STATE_ATTACK_HIGH: int = 2
const STATE_ATTACK_LOW: int = 3
const STATE_ATTACK_MID: int = 4
const STATE_HITSTUN: int = 5
const STATE_BLOCKSTUN: int = 6
const IDG_HIGH: int = 1
const IDG_LOW: int = 2
const IDG_MID: int = 3


func _init() -> void:
	_run()
	MoveRegistry.clear()
	if _failures == 0:
		print("[test_guard_height] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_guard_height] FAIL — %d of %d checks failed" % [_failures, _checks])
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


# --- Minimal character builder --------------------------------------------------

func _hurt_stand() -> Box:
	return Box.make(FP.from_int(-15), FP.from_int(-80), FP.from_int(30), FP.from_int(80))


func _hurt_crouch() -> Box:
	return Box.make(FP.from_int(-15), FP.from_int(-55), FP.from_int(30), FP.from_int(55))


func _loop_state(state_id: int, crouch: bool) -> MoveState:
	var m := MoveState.new()
	m.id = state_id
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 1
	m.loop = true
	m.is_crouch = crouch
	var kf := Keyframe.new()
	kf.frame_start = 1
	kf.frame_end = 1
	kf.hurtboxes = [_hurt_crouch() if crouch else _hurt_stand()]
	m.timeline = [kf]
	return m


## A one-frame committed attack whose single active frame always connects
## against a defender at reach. `guard_height` differs per call.
func _attack_state(state_id: int, guard_height: int, id_group: int) -> MoveState:
	var m := MoveState.new()
	m.id = state_id
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 8
	m.loop = false
	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(30), FP.from_int(-60), FP.from_int(30), FP.from_int(20))
	hb.guard_height = guard_height
	hb.damage = 10
	hb.hitstun = 12
	hb.blockstun = 8
	hb.hitstop = 0
	hb.hit_reaction = STATE_HITSTUN
	hb.block_reaction = STATE_BLOCKSTUN
	hb.id_group = id_group
	var kf := Keyframe.new()
	kf.frame_start = 1
	kf.frame_end = 1
	kf.hurtboxes = [_hurt_stand()]
	kf.hitboxes = [hb]
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 2
	kf_rec.frame_end = 8
	kf_rec.hurtboxes = [_hurt_stand()]
	m.timeline = [kf, kf_rec]
	return m


func _reaction(state_id: int, category: int) -> MoveState:
	var m := MoveState.new()
	m.id = state_id
	m.category = category
	m.duration = 12
	m.loop = false
	var kf := Keyframe.new()
	kf.frame_start = 1
	kf.frame_end = 12
	kf.hurtboxes = [_hurt_stand()]
	m.timeline = [kf]
	return m


func _build_character() -> Character:
	var c := Character.new()
	c.id = CHAR_ID
	c.idle_state_id = STATE_IDLE
	var phys := CharacterPhysics.new()
	c.physics = phys
	c.default_pushbox = Box.make(FP.from_int(-10), FP.from_int(-40), FP.from_int(20), FP.from_int(40))
	c.states = [
		_loop_state(STATE_IDLE, false),
		_loop_state(STATE_CROUCH, true),
		_attack_state(STATE_ATTACK_HIGH, HitBox.GUARD_HIGH, IDG_HIGH),
		_attack_state(STATE_ATTACK_LOW, HitBox.GUARD_LOW, IDG_LOW),
		_attack_state(STATE_ATTACK_MID, HitBox.GUARD_MID, IDG_MID),
		_reaction(STATE_HITSTUN, MoveState.CATEGORY_HITSTUN),
		_reaction(STATE_BLOCKSTUN, MoveState.CATEGORY_BLOCKSTUN),
	]
	# A bare-DOWN loop-target command (mirrors character_a.gd's crouch entry,
	# AD-038): a LOOP state re-derives from CURRENT-tick input every tick, so
	# without this the defender's forced STATE_CROUCH would fall back to idle
	# on the very first step regardless of what raw input is fed. Holding
	# DOWN + a back-hold (e.g. DOWN|RIGHT) is exactly how a crouch-block is
	# held in play.
	var crouch_entry := ButtonMapEntry.new()
	crouch_entry.button_index = -1
	crouch_entry.required_direction = InputFrame.DOWN
	crouch_entry.motion = 0
	crouch_entry.target_state_id = STATE_CROUCH
	c.button_map = [crouch_entry]
	return c


func _install() -> void:
	MoveRegistry.install({CHAR_ID: _build_character()})


## Attacker (P0) in `attack_state`, defender (P1) in `defender_state`, defender
## fed `defender_raw` this tick (a back-hold or neutral). One step is enough:
## frame_in_state 0 -> 1 enters the attack's sole active frame, which connects.
func _step_once(attack_state: int, defender_state: int, defender_raw: int) -> SimState:
	_install()
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = CHAR_ID
	s.players[0].state_id = attack_state
	s.players[0].frame_in_state = 0
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = CHAR_ID
	s.players[1].state_id = defender_state
	s.players[1].pos_x = FP.from_int(60)
	s.players[1].facing = -1
	s = SimState.step(s, InputFrame.NEUTRAL, defender_raw)
	return s


func _teardown() -> void:
	MoveRegistry.clear()


func _run() -> void:
	_test_low_hits_standing_backhold()
	_test_low_blocked_crouching()
	_test_high_hits_crouching_backhold()
	_test_high_blocked_standing()
	_test_mid_blocked_either_stance()
	_test_no_attempt_block_valid_true()
	_test_wrong_stance_deals_damage_not_blockstun()
	_test_character_a_2l_is_enforced_low()
	_test_character_a_2m_is_enforced_low()
	_test_character_a_2l_blocked_when_crouching()


# --- LOW ------------------------------------------------------------------------

func _test_low_hits_standing_backhold() -> void:
	# criterion 11: LOW is blocked only crouching; hits a standing back-hold.
	# "Back" for P1 (facing -1) is raw RIGHT.
	var s := _step_once(STATE_ATTACK_LOW, STATE_IDLE, InputFrame.RIGHT)
	_eq(s.players[1].stun_kind, PlayerView.STUN_HIT, "a LOW beats a STANDING back-hold (resolves as a hit)")
	_true(s.last_hit != null, "last_hit recorded")
	_false(s.last_hit.was_block, "was_block is false (the wrong-stance block failed)")
	_eq(s.last_hit.guard_height, HitBox.GUARD_LOW, "HitEvent.guard_height reads LOW")
	_false(s.last_hit.block_valid, "HitEvent.block_valid is false (wrong stance while attempting to block)")
	_teardown()


func _test_low_blocked_crouching() -> void:
	var s := _step_once(STATE_ATTACK_LOW, STATE_CROUCH, InputFrame.DOWN | InputFrame.RIGHT)
	_eq(s.players[1].stun_kind, PlayerView.STUN_BLOCK, "a LOW is blocked by a CROUCHING back-hold")
	_true(s.last_hit.was_block, "was_block true")
	_true(s.last_hit.block_valid, "block_valid true (correct stance)")
	_eq(s.last_hit.guard_height, HitBox.GUARD_LOW, "HitEvent.guard_height reads LOW")
	_teardown()


# --- HIGH -----------------------------------------------------------------------

func _test_high_hits_crouching_backhold() -> void:
	# criterion 11: HIGH is blocked only standing; hits a crouching back-hold.
	var s := _step_once(STATE_ATTACK_HIGH, STATE_CROUCH, InputFrame.DOWN | InputFrame.RIGHT)
	_eq(s.players[1].stun_kind, PlayerView.STUN_HIT, "a HIGH beats a CROUCHING back-hold (resolves as a hit)")
	_false(s.last_hit.was_block, "was_block false")
	_false(s.last_hit.block_valid, "block_valid false (wrong stance)")
	_eq(s.last_hit.guard_height, HitBox.GUARD_HIGH, "HitEvent.guard_height reads HIGH")
	_teardown()


func _test_high_blocked_standing() -> void:
	var s := _step_once(STATE_ATTACK_HIGH, STATE_IDLE, InputFrame.RIGHT)
	_eq(s.players[1].stun_kind, PlayerView.STUN_BLOCK, "a HIGH is blocked by a STANDING back-hold")
	_true(s.last_hit.was_block, "was_block true")
	_true(s.last_hit.block_valid, "block_valid true (correct stance)")
	_teardown()


# --- MID (default) — unchanged either-stance behavior ---------------------------

func _test_mid_blocked_either_stance() -> void:
	var s_stand := _step_once(STATE_ATTACK_MID, STATE_IDLE, InputFrame.RIGHT)
	_eq(s_stand.players[1].stun_kind, PlayerView.STUN_BLOCK, "MID is blocked standing")
	_true(s_stand.last_hit.block_valid, "MID block_valid true when standing")
	var s_crouch := _step_once(STATE_ATTACK_MID, STATE_CROUCH, InputFrame.DOWN | InputFrame.RIGHT)
	_eq(s_crouch.players[1].stun_kind, PlayerView.STUN_BLOCK, "MID is blocked crouching")
	_true(s_crouch.last_hit.block_valid, "MID block_valid true when crouching")
	_eq(s_crouch.last_hit.guard_height, HitBox.GUARD_MID, "HitEvent.guard_height reads MID (default)")
	_teardown()


# --- block_valid distinguishes "wrong stance" from "no attempt" -----------------

func _test_no_attempt_block_valid_true() -> void:
	# The defender does not hold back at all (NEUTRAL) — a clean hit, not a
	# stance violation. block_valid stays true here (inspection-surface.md
	# HitEvent.block_valid: false ONLY for an attempted-but-wrong-stance block).
	var s := _step_once(STATE_ATTACK_LOW, STATE_IDLE, InputFrame.NEUTRAL)
	_eq(s.players[1].stun_kind, PlayerView.STUN_HIT, "no back-hold at all resolves as a hit")
	_false(s.last_hit.was_block, "was_block false (no attempt)")
	_true(s.last_hit.block_valid, "block_valid true — distinguishes 'did not attempt' from 'wrong stance'")
	_teardown()


func _test_wrong_stance_deals_damage_not_blockstun() -> void:
	# combat-resolution.md criterion 14: "a wrong-stance block deals hitstun/
	# damage, not blockstun."
	var s := _step_once(STATE_ATTACK_LOW, STATE_IDLE, InputFrame.RIGHT)
	_true(s.players[1].health < 1000, "a wrong-stance 'block' deals damage")
	_eq(s.players[1].state_id, STATE_HITSTUN, "the defender enters the HIT reaction, not the block reaction")
	_teardown()


# --- character A's now-enforced lows (ratified AD-045 scope call) ---------------

func _install_char_a() -> void:
	MoveRegistry.install({CharacterA.CHAR_ID: CharacterA.build_character()})


func _char_a_state(attacker_state: int, defender_state: int, defender_raw: int, gap: int = 60) -> SimState:
	_install_char_a()
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = CharacterA.CHAR_ID
	s.players[0].state_id = attacker_state
	s.players[0].frame_in_state = 0
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = CharacterA.CHAR_ID
	s.players[1].state_id = defender_state
	s.players[1].pos_x = FP.from_int(gap)
	s.players[1].facing = -1
	return s


func _test_character_a_2l_is_enforced_low() -> void:
	var reg: Dictionary = {CharacterA.CHAR_ID: CharacterA.build_character()}
	var c: Character = reg[CharacterA.CHAR_ID]
	var m: MoveState = c.get_state(CharacterA.STATE_2L)
	var found_low: bool = false
	for kf in m.timeline:
		for hb in kf.hitboxes:
			if hb.guard_height == HitBox.GUARD_LOW:
				found_low = true
	_true(found_low, "character A's 2L hitbox is authored guard_height = LOW (ratified AD-045 scope call)")
	_true(m.is_crouch, "character A's 2L is authored is_crouch = true (matches its crouching animation)")


func _test_character_a_2m_is_enforced_low() -> void:
	var reg: Dictionary = {CharacterA.CHAR_ID: CharacterA.build_character()}
	var c: Character = reg[CharacterA.CHAR_ID]
	var m: MoveState = c.get_state(CharacterA.STATE_2M)
	var found_low: bool = false
	for kf in m.timeline:
		for hb in kf.hitboxes:
			if hb.guard_height == HitBox.GUARD_LOW:
				found_low = true
	_true(found_low, "character A's 2M hitbox is authored guard_height = LOW (ratified AD-045 scope call)")


func _test_character_a_2l_blocked_when_crouching() -> void:
	# A's 2L must actually connect as a HIT against a standing back-hold, and be
	# BLOCKED by a crouching one, driven through the real engine/content path
	# (not just the authored-data check above). Start ONE tick before 2L's own
	# active window (frame 5) opens — character A's STANDING back-hold (bare
	# back, no DOWN) satisfies its own WALK_B loop-target command (AD-038's
	# re-derive-every-tick rule), so a defender genuinely walks backward while
	# holding it; starting right at the active window keeps that real drift from
	# accumulating enough ticks to walk the defender out of 2L's (short) reach.
	var s_stand := _char_a_state(CharacterA.STATE_2L, CharacterA.STATE_IDLE, InputFrame.RIGHT, 45)
	s_stand.players[0].frame_in_state = 4
	for _k in range(4):
		s_stand = SimState.step(s_stand, InputFrame.NEUTRAL, InputFrame.RIGHT)
		if s_stand.players[1].stun > 0:
			break
	_eq(s_stand.players[1].stun_kind, PlayerView.STUN_HIT, "character A's 2L beats a standing back-hold")

	# Crouch-blocking in play is DOWN + back held together (character A's own
	# STATE_CROUCH is a loop state that re-derives from CURRENT-tick input every
	# tick, AD-038 — holding back alone, with no DOWN, falls back to idle, and
	# because DOWN is listed before the walk entries, holding DOWN+back stays
	# crouched rather than walking, so no drift concern here).
	var crouch_back: int = InputFrame.DOWN | InputFrame.RIGHT
	var s_crouch := _char_a_state(CharacterA.STATE_2L, CharacterA.STATE_CROUCH, crouch_back, 45)
	for _k in range(8):
		s_crouch = SimState.step(s_crouch, InputFrame.NEUTRAL, crouch_back)
		if s_crouch.players[1].stun > 0:
			break
	_eq(s_crouch.players[1].stun_kind, PlayerView.STUN_BLOCK, "character A's 2L is blocked by a crouching back-hold")
	MoveRegistry.clear()
