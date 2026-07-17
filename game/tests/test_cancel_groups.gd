extends SceneTree

## Headless test for CancelRule group-target resolution (TKT-P2-03, AD-044).
## move-format.md → CancelRule.target / Character.cancel_groups / criterion 10;
## combat-resolution.md phase 2. This is the DEFERRED-BUT-SPECCED capability
## character B's gatling ladder authors against (AD-015's group path, JC-023
## deferred it — no character needed it until B). This test proves the
## MECHANISM generically (a minimal character, not B's actual ladder — B's
## content is TKT-P2-05's job): a CancelRule.target_is_group cancel resolves to
## WHICHEVER group-member destination the currently buffered command names, and
## does NOT fire for a buffered command whose destination is outside the group.
##
## Run:  godot --headless --path game -s res://tests/test_cancel_groups.gd
## Exits non-zero on any failure so a harness/CI can gate on it.

var _failures: int = 0
var _checks: int = 0

# --- Minimal test character ---------------------------------------------------
const CHAR_ID: int = 910
const STATE_IDLE: int = 0
const STATE_A: int = 1          # the source move (on_contact group-target cancel)
const STATE_B1: int = 2         # a group MEMBER (reachable via BUTTON_0)
const STATE_B2: int = 3         # a group MEMBER (reachable via BUTTON_1)
const STATE_C: int = 4          # NOT a group member (reachable via BUTTON_2)
const STATE_HITSTUN: int = 5    # defender's forced reaction (so STATE_A connects)
const GROUP_ID: int = 100
const IDG_A: int = 1


func _init() -> void:
	_run()
	MoveRegistry.clear()
	if _failures == 0:
		print("[test_cancel_groups] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_cancel_groups] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


# --- Character builder ---------------------------------------------------------

func _hurt() -> Box:
	return Box.make(FP.from_int(-15), FP.from_int(-80), FP.from_int(30), FP.from_int(80))


## STATE_A: a one-frame committed move whose single active frame's hitbox always
## connects (against a defender placed in its reach). Carries ONE CancelRule: an
## on_contact, group-target cancel into GROUP_ID (members STATE_B1/STATE_B2).
## `input = 0` (AD-044: a group-target rule is authored input-gateless — the
## group scan itself finds whichever member command is buffered).
func _build_state_a() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_A
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = 8
	m.loop = false
	var hb := HitBox.new()
	hb.box = Box.make(FP.from_int(30), FP.from_int(-60), FP.from_int(30), FP.from_int(20))
	hb.damage = 10
	hb.hitstun = 12
	hb.blockstun = 8
	hb.hitstop = 0
	hb.hit_reaction = MoveState.REACTION_HITSTUN
	hb.block_reaction = MoveState.REACTION_HITSTUN
	hb.id_group = IDG_A
	var kf := Keyframe.new()
	kf.frame_start = 1
	kf.frame_end = 1
	kf.hurtboxes = [_hurt()]
	kf.hitboxes = [hb]
	var kf_rec := Keyframe.new()
	kf_rec.frame_start = 2
	kf_rec.frame_end = 8
	kf_rec.hurtboxes = [_hurt()]
	m.timeline = [kf, kf_rec]

	var cancel := CancelRule.new()
	cancel.target = GROUP_ID
	cancel.target_is_group = true
	cancel.condition = CancelRule.CONDITION_ON_CONTACT
	cancel.window_start = 0   # default: first-active -> end (frame 1 -> 8)
	cancel.window_end = 0
	cancel.input = 0          # AD-044: group cancels are authored input-gateless
	m.cancels = [cancel]
	return m


## A rule with a GROUP TARGET NAMING AN UNKNOWN GROUP ID (no matching
## Character.cancel_groups entry) — a defensive case: resolution must return -1
## (no crash, no transition), never mistakenly match anything.
func _build_state_a_unknown_group() -> MoveState:
	var m := _build_state_a()
	m.cancels[0].target = 999999   # no such group declared
	return m


func _simple_state(state_id: int, loop: bool = false, duration: int = 6) -> MoveState:
	var m := MoveState.new()
	m.id = state_id
	m.category = MoveState.CATEGORY_GROUNDED
	m.duration = duration
	m.loop = loop
	var kf := Keyframe.new()
	kf.frame_start = 1
	kf.frame_end = duration
	kf.hurtboxes = [_hurt()]
	m.timeline = [kf]
	return m


func _build_hitstun() -> MoveState:
	var m := MoveState.new()
	m.id = STATE_HITSTUN
	m.category = MoveState.CATEGORY_HITSTUN
	m.duration = 12
	m.loop = false
	var kf := Keyframe.new()
	kf.frame_start = 1
	kf.frame_end = 12
	kf.hurtboxes = [_hurt()]
	m.timeline = [kf]
	return m


func _map(button_index: int, target_state_id: int) -> ButtonMapEntry:
	var e := ButtonMapEntry.new()
	e.button_index = button_index
	e.required_direction = 0
	e.motion = 0
	e.target_state_id = target_state_id
	return e


func _build_character(state_a: MoveState) -> Character:
	var c := Character.new()
	c.id = CHAR_ID
	c.idle_state_id = STATE_IDLE
	var phys := CharacterPhysics.new()
	c.physics = phys
	c.default_pushbox = Box.make(FP.from_int(-10), FP.from_int(-40), FP.from_int(20), FP.from_int(40))

	c.states = [
		_simple_state(STATE_IDLE, true, 1),
		state_a,
		_simple_state(STATE_B1),
		_simple_state(STATE_B2),
		_simple_state(STATE_C),
		_build_hitstun(),
	]
	c.reaction_map = _reaction_map()

	var group := CancelGroup.new()
	group.id = GROUP_ID
	group.members = [STATE_B1, STATE_B2]
	c.cancel_groups = [group]

	# BUTTON_0 -> a group MEMBER; BUTTON_1 -> the OTHER group member;
	# BUTTON_2 -> a state NOT in the group (the negative case).
	c.button_map = [
		_map(0, STATE_B1),
		_map(1, STATE_B2),
		_map(2, STATE_C),
	]
	return c


## Every ReactionKind mapped to THIS character's own STATE_HITSTUN (AD-049,
## REQUIRED) — the only reaction either the attacker or the (separate-CHAR_ID)
## defender character in this test ever inflicts/receives is HITSTUN (both
## hb.hit_reaction and hb.block_reaction on STATE_A's hitbox are authored
## REACTION_HITSTUN). This is now resolved through EACH character's own map —
## the two characters no longer need to coincidentally SHARE a raw state_id
## (the exact bug class AD-049 fixes), they just both author this kind.
func _reaction_map() -> Array[ReactionMapEntry]:
	return [
		ReactionMapEntry.make(MoveState.REACTION_HITSTUN, STATE_HITSTUN),
		ReactionMapEntry.make(MoveState.REACTION_BLOCKSTUN, STATE_HITSTUN),
		ReactionMapEntry.make(MoveState.REACTION_CROUCH_BLOCKSTUN, STATE_HITSTUN),
		ReactionMapEntry.make(MoveState.REACTION_LAUNCH, STATE_HITSTUN),
		ReactionMapEntry.make(MoveState.REACTION_AIR_RESET, STATE_HITSTUN),
		ReactionMapEntry.make(MoveState.REACTION_KNOCKDOWN, STATE_HITSTUN),
	]


func _defender_character() -> Character:
	# A trivial defender (no attacks needed) — just idle + a plain hurtbox, on a
	# DIFFERENT CHAR_ID (CHAR_ID + 1) with its OWN reaction_map (AD-049) — the
	# attacker's hit_reaction/block_reaction now resolve through the DEFENDER's
	# own map, not a raw id coincidentally shared across the two characters.
	var c := Character.new()
	c.id = CHAR_ID + 1
	c.idle_state_id = STATE_IDLE
	var phys := CharacterPhysics.new()
	c.physics = phys
	c.default_pushbox = Box.make(FP.from_int(-10), FP.from_int(-40), FP.from_int(20), FP.from_int(40))
	c.states = [
		_simple_state(STATE_IDLE, true, 1),
		_build_hitstun(),
	]
	c.reaction_map = _reaction_map()
	c.button_map = []
	return c


func _install(state_a: MoveState) -> void:
	var attacker := _build_character(state_a)
	var defender := _defender_character()
	MoveRegistry.install({attacker.id: attacker, defender.id: defender})


func _two_char_state(state_a: MoveState) -> SimState:
	_install(state_a)
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = CHAR_ID
	s.players[0].state_id = STATE_A
	s.players[0].frame_in_state = 0   # first step enters frame 1 cleanly
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = CHAR_ID + 1
	s.players[1].state_id = STATE_IDLE
	s.players[1].pos_x = FP.from_int(60)
	s.players[1].facing = -1
	return s


func _teardown() -> void:
	MoveRegistry.clear()


func _run() -> void:
	_test_group_resolves_to_first_member_command()
	_test_group_resolves_to_other_member_command()
	_test_non_member_command_does_not_cancel()
	_test_unknown_group_resolves_to_nothing()


## Step STATE_A once (its own hitbox connects, setting move_contact = HIT so the
## ON_CONTACT cancel condition holds from the NEXT tick onward).
func _connect_state_a(state_a: MoveState) -> SimState:
	var s := _two_char_state(state_a)
	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(s.players[0].move_contact, PlayerState.CONTACT_HIT, "STATE_A's hitbox connected (pre-check)")
	return s


func _test_group_resolves_to_first_member_command() -> void:
	var s := _connect_state_a(_build_state_a())
	# BUTTON_0 -> STATE_B1, a group member: the group-target cancel must resolve
	# to STATE_B1 specifically (not the group id, not STATE_B2).
	s = SimState.step(s, InputFrame.BUTTON_0, InputFrame.NEUTRAL)
	_eq(s.players[0].state_id, STATE_B1, "a buffered command to a group MEMBER (B1) satisfies the group cancel")
	_teardown()


func _test_group_resolves_to_other_member_command() -> void:
	var s := _connect_state_a(_build_state_a())
	# BUTTON_1 -> STATE_B2, the OTHER group member.
	s = SimState.step(s, InputFrame.BUTTON_1, InputFrame.NEUTRAL)
	_eq(s.players[0].state_id, STATE_B2, "a buffered command to the OTHER group member (B2) also satisfies the group cancel")
	_teardown()


func _test_non_member_command_does_not_cancel() -> void:
	var s := _connect_state_a(_build_state_a())
	# BUTTON_2 -> STATE_C, NOT a member of GROUP_ID: the group-target cancel must
	# NOT fire — this is move-format.md criterion 10's negative case ("no format
	# extension" means only DECLARED members satisfy it).
	s = SimState.step(s, InputFrame.BUTTON_2, InputFrame.NEUTRAL)
	_eq(s.players[0].state_id, STATE_A, "a buffered command OUTSIDE the group does not satisfy the group-target cancel")
	_teardown()


func _test_unknown_group_resolves_to_nothing() -> void:
	# Defensive case: a CancelRule.target_is_group naming a group the character
	# never declared must resolve to no transition at all (no crash, no match) —
	# never partially match or fall back to a raw state_id read of the (bogus)
	# group id.
	var s := _connect_state_a(_build_state_a_unknown_group())
	s = SimState.step(s, InputFrame.BUTTON_0, InputFrame.NEUTRAL)
	_eq(s.players[0].state_id, STATE_A, "an unresolvable group id never satisfies the cancel (defensive)")
	_teardown()
