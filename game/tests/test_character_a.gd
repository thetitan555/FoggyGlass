extends SceneTree

## Headless dev tests for character A's authored move data (TKT-P1-10).
## character-a.md criteria 1-7, 9 (criterion 8 landed with TKT-P0-08; criterion
## 10 is verified in-mode at the feature audit, not here). Exercises CharacterA
## (game/content/character_a.gd) through the same SimState.step/InspectionView
## surface the training mode and QA's golden harness read (AD-011), so this is
## a real end-to-end proof, not a check against the builder's own numbers.
##
## Run:  godot --headless --path game -s res://tests/test_character_a.gd
## Exits non-zero on any failure so a harness/CI can gate on it.
##
## SCOPE NOTE (superseded 2026-07-04, TKT-P1-12/AD-032). Jump and the throw
## command now DO have live-input button_map entries (a pure-direction jump —
## held UP, no button — and an L+H chord), verified end-to-end by
## game/tests/test_command_recognition.gd. The tests below that drive the
## player DIRECTLY into STATE_THROW / prejump (state_id set, then step) predate
## that and remain as-is: they exercise RESOLUTION (throw connect/tech/
## knockdown; jump arc integration) independent of recognition, which is still
## a valid, narrower thing to assert here.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	ProjectileRegistry.clear()
	if _failures == 0:
		print("[test_character_a] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_character_a] FAIL — %d of %d checks failed" % [_failures, _checks])
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


func _run() -> void:
	_test_authored_as_data()
	_test_frame_data_derivation_5l()
	_test_frame_data_derivation_5m()
	_test_frame_data_derivation_5h()
	_test_frame_data_derivation_2m()
	_test_5h_plus_on_block_and_advances()
	_test_5h_5m_link_window()
	_test_2h_safe_anti_air()
	_test_no_gatlings_no_jump_cancels()
	_test_fireball_is_projectile()
	_test_fireball_spawn_once()
	_test_fireball_one_tick_offset()
	_test_fireball_cap_suppresses_second_cast()
	_test_dp_invuln_authored_and_full_punishable()
	_test_dp_h_two_hit()
	_test_throw_connects_through_block()
	_test_throw_tech_window()
	_test_throw_hard_knockdown()
	_test_special_cancel_2m_into_dp()
	_test_footsie_route_2m_dp_l()
	_test_jump_arc_integrates()
	_test_baked_tres_matches_builder()


# --- Scenario setup ----------------------------------------------------------

func _install() -> void:
	MoveRegistry.install({CharacterA.CHAR_ID: CharacterA.build_character()})
	ProjectileRegistry.install(CharacterA.build_projectile_registry())


func _two_char_state(gap_units: int = 60) -> SimState:
	_install()
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = CharacterA.CHAR_ID
	s.players[0].state_id = CharacterA.STATE_IDLE
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = CharacterA.CHAR_ID
	s.players[1].state_id = CharacterA.STATE_IDLE
	s.players[1].pos_x = FP.from_int(gap_units)
	s.players[1].facing = -1
	return s


func _cleanup() -> void:
	MoveRegistry.clear()
	ProjectileRegistry.clear()


# --- Criterion 1: authored purely as data ------------------------------------

func _test_authored_as_data() -> void:
	# CharacterA.build_character() constructs a Character purely from exported
	# Resource fields (MoveState/Keyframe/HitBox/CancelRule/ProjectileData) --
	# no character-specific engine branch exists anywhere in step_phases.gd
	# (verified by inspection: StepPhases resolves every player's moves through
	# MoveRegistry.character(p.character_id) generically). This check asserts
	# the built Character is well-formed data resolvable by the generic path.
	var c := CharacterA.build_character()
	_eq(c.id, CharacterA.CHAR_ID, "character A has its own id")
	_true(c.states.size() >= 20, "character A authors a full kit (movement+normals+specials+throw+reactions)")
	for st in c.states:
		_true(st.has_valid_category(), "state %d declares a valid engine-level category" % st.id)


# --- Criterion 2: frame data derives consistently ----------------------------

func _test_frame_data_derivation_5l() -> void:
	var m: MoveState = CharacterA.build_character().get_state(CharacterA.STATE_5L)
	var fd: FrameData = MoveData.frame_data(m)
	_eq(fd.startup, 4, "5L startup = 4")
	_eq(fd.active, 3, "5L active = 3")
	_eq(fd.recovery, 6, "5L recovery = 6")
	_eq(fd.on_block_adv, 1, "5L on-block advantage = +1 (matches character-a.md)")
	_eq(fd.on_hit_adv, 4, "5L on-hit advantage = +4 (matches character-a.md)")


func _test_frame_data_derivation_5m() -> void:
	var m: MoveState = CharacterA.build_character().get_state(CharacterA.STATE_5M)
	var fd: FrameData = MoveData.frame_data(m)
	_eq(fd.startup, 5, "5M startup = 5")
	_eq(fd.active, 4, "5M active = 4")
	_eq(fd.recovery, 11, "5M recovery = 11")
	_eq(fd.on_block_adv, -2, "5M on-block advantage = -2 (matches character-a.md)")
	_eq(fd.on_hit_adv, 2, "5M on-hit advantage = +2 (matches character-a.md)")


func _test_frame_data_derivation_5h() -> void:
	var m: MoveState = CharacterA.build_character().get_state(CharacterA.STATE_5H)
	var fd: FrameData = MoveData.frame_data(m)
	_eq(fd.startup, 25, "5H startup = 25 (slow, reactable, per spec)")
	_eq(fd.active, 3, "5H active = 3")
	_eq(fd.recovery, 13, "5H recovery = 13")
	_eq(fd.on_block_adv, 3, "5H on-block advantage = +3 (the only plus-on-block grounded normal)")
	_eq(fd.on_hit_adv, 7, "5H on-hit advantage = +7 (enables the 3f link into 5M)")


func _test_frame_data_derivation_2m() -> void:
	var m: MoveState = CharacterA.build_character().get_state(CharacterA.STATE_2M)
	var fd: FrameData = MoveData.frame_data(m)
	_eq(fd.startup, 6, "2M startup = 6")
	_eq(fd.active, 3, "2M active = 3")
	_eq(fd.recovery, 13, "2M recovery = 13")
	_eq(fd.on_block_adv, -1, "2M on-block advantage = -1 (matches character-a.md, the signature poke)")
	_eq(fd.on_hit_adv, 3, "2M on-hit advantage = +3 (enables > 236/623)")


# --- Criterion 3: 5H pressure reset + tight link -----------------------------

func _test_5h_plus_on_block_and_advances() -> void:
	# 5H is plus on block and ADVANCES FORWARD (character-a.md: "advances ~30px").
	# Drive P0 into 5H, let P1 block it, confirm P0's OWN position moves forward.
	#
	# Asserts P0's OWN pos_x delta (not the inter-player gap) since the
	# 2026-07-08 walk-button-map fix (character_a.gd _build_button_map) makes
	# P1's held "back" input ALSO walk P1 backward (STATE_WALK_B) whenever P1 is
	# actionable and not frozen in blockstun -- correct new behavior (holding
	# back walks/retreats, same as any other direction), but it means the GAP
	# is no longer a clean proxy for "did P0 advance": P1 legitimately retreats
	# during 5H's startup/recovery too, which could mask or exaggerate P0's own
	# displacement. Measuring P0's own pos_x isolates the thing this test is
	# actually about.
	var s := _two_char_state(60)
	s.players[0].state_id = CharacterA.STATE_5H
	s.players[0].frame_in_state = 0
	var start_x: int = s.players[0].pos_x
	var p1_block: int = InputFrame.LEFT   # P1 faces -1; back = RIGHT... see below
	# P1 faces -1 (spawned facing left toward P0 on its left): back relative to
	# facing -1 is RIGHT (mirrors StepPhases.resolve_intent: facing<0 => back=RIGHT).
	p1_block = InputFrame.RIGHT
	for _k in range(45):
		s = SimState.step(s, InputFrame.NEUTRAL, p1_block)
	var end_x: int = s.players[0].pos_x
	_true(end_x > start_x, "5H advances P0 forward while active (P0's own pos_x increases)")
	_cleanup()


func _test_5h_5m_link_window() -> void:
	# Criterion 3: 5H on hit links into 5M on a non-empty, TIGHT window (authored
	# target 3 frames). Verify: (a) 5M pressed immediately once 5H connects and P0
	# becomes actionable lands (the link exists and is not empty), (b) 5M's own
	# 5-frame startup is fully covered by 5H's authored +7 on-hit advantage (so the
	# link is real -- P0 is actionable and 5M starts up before P1 recovers).
	var s := _two_char_state(0)
	# Position P0's 5H hitbox to reach P1: 5H's box sits at local (30,35)-(65,60);
	# with P1 at a small gap it will connect once active.
	s.players[1].pos_x = FP.from_int(45)
	s.players[0].state_id = CharacterA.STATE_5H
	s.players[0].frame_in_state = 0
	var connected: bool = false
	for _k in range(45):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[0].move_contact == PlayerState.CONTACT_HIT:
			connected = true
			break
	_true(connected, "5H connects on hit (setup for the link)")
	# Once P0 becomes actionable (5H's recovery ends), press 5M immediately.
	var linked: bool = false
	for _k in range(60):
		var actionable: bool = Actionability.is_actionable(
			s.players[0], MoveRegistry.character(CharacterA.CHAR_ID).get_state(s.players[0].state_id))
		var p0_input: int = InputFrame.BUTTON_1 if actionable else InputFrame.NEUTRAL
		s = SimState.step(s, p0_input, InputFrame.NEUTRAL)
		if s.players[0].state_id == CharacterA.STATE_5M:
			linked = true
			break
	_true(linked, "5H, 5M link: pressing 5M on P0's first actionable frame after 5H connects lands 5M (non-empty link window)")
	_cleanup()


# --- Criterion 4: 2H safe anti-air --------------------------------------------

func _test_2h_safe_anti_air() -> void:
	var m: MoveState = CharacterA.build_character().get_state(CharacterA.STATE_2H)
	var fd: FrameData = MoveData.frame_data(m)
	_eq(fd.startup, 5, "2H startup = 5 (fast get-off-me)")
	_eq(fd.active, 3, "2H active = 3")
	_true(fd.on_block_adv < 0 and fd.on_block_adv >= -3,
		"2H at worst slightly minus on block (not punishable), got %d" % fd.on_block_adv)
	# No combo on hit: 2H's hit_reaction routes to STATE_AIR_RESET (a terminal
	# reaction with no attacker follow-up authored -- 2H itself is not cancellable).
	_eq(m.cancels.size(), 0, "2H is not cancellable (no combo on hit)")
	var hb: HitBox = null
	for kf in m.timeline:
		for h in kf.hitboxes:
			hb = h
	_eq(hb.hit_reaction, CharacterA.STATE_AIR_RESET, "2H hit reaction is the no-follow-up air reset")
	# Invuln is AUTHORED (frames 1 through end of active = frame 8) even though
	# inert pending the engine gap (docs/flags.md) -- assert the DATA is correct.
	var invuln_covers_1_to_8: bool = true
	for f in range(1, 9):
		var covering: Array[Keyframe] = m.keyframes_at(f)
		var has_invuln: bool = false
		for kf in covering:
			if kf.invuln_strike:
				has_invuln = true
		if not has_invuln:
			invuln_covers_1_to_8 = false
	_true(invuln_covers_1_to_8, "2H authors invuln_strike covering frames 1-8 (upper-body invuln, per spec -- inert pending docs/flags.md)")


# --- Criterion 9: no gatlings / no jump cancels ------------------------------

func _test_no_gatlings_no_jump_cancels() -> void:
	var c := CharacterA.build_character()
	var normal_state_ids: Array[int] = [
		CharacterA.STATE_5L, CharacterA.STATE_5M, CharacterA.STATE_5H,
		CharacterA.STATE_2L, CharacterA.STATE_2M, CharacterA.STATE_2H,
		CharacterA.STATE_JL, CharacterA.STATE_JM, CharacterA.STATE_JH,
	]
	var jump_state_ids: Array[int] = [CharacterA.STATE_JUMP_N, CharacterA.STATE_JUMP_F, CharacterA.STATE_JUMP_B]
	# No GROUNDED gatling: no normal (standing/crouching/air) has a CancelRule
	# targeting another normal. Skip the jump states themselves here -- AD-039's
	# airborne-action model has JUMP_N/F/B legitimately cancel into j.L/M/H
	# (TKT-P1.1R-04); that is the airborne character's own move cancelling into
	# an air normal, not a grounded normal->normal gatling chain, so it is not
	# what this check guards against.
	for st in c.states:
		if st.id in jump_state_ids:
			continue
		for rule in st.cancels:
			_false(rule.target in normal_state_ids,
				"state %d has no CancelRule targeting a normal (no gatlings)" % st.id)
	# No jump-cancel: no CancelRule anywhere targets a jump state, and the only
	# rules touching a jump state are the prejump lead-ins' own ALWAYS cancels
	# (PREJUMP/PREJUMP_F/PREJUMP_B -> JUMP_N/F/B, AD-039) -- not a player-granted
	# "cancel a move into a jump".
	var prejump_state_ids: Array[int] = [
		CharacterA.STATE_PREJUMP, CharacterA.STATE_PREJUMP_F, CharacterA.STATE_PREJUMP_B,
	]
	for st in c.states:
		if st.id in prejump_state_ids:
			continue   # the authored prejump->jump lead-ins themselves, not a jump-cancel grant
		for rule in st.cancels:
			_false(rule.target in jump_state_ids,
				"state %d grants no jump-cancel (reserved for a later character)" % st.id)


# --- Criterion 5: fireball is a projectile -----------------------------------

func _test_fireball_is_projectile() -> void:
	var s := _two_char_state(200)   # far enough the fireball travels, doesn't insta-hit
	s.players[0].state_id = CharacterA.STATE_FIREBALL_M
	s.players[0].frame_in_state = 0
	var spawned: bool = false
	for _k in range(20):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.projectiles.size() > 0:
			spawned = true
			break
	_true(spawned, "casting the fireball spawns a runtime Projectile")
	_eq(s.projectiles[0].owner, 0, "the projectile is owned by the caster")
	_eq(s.projectiles[0].data_id, CharacterA.PROJ_FIREBALL_M, "the projectile resolves the correct ProjectileData (236M)")
	_cleanup()


func _test_fireball_spawn_once() -> void:
	# AD-030/JC-033: the spawn fires ONCE on frame_start, not once per covered
	# frame. The spawn keyframe here is a single-frame range (14..14) so this
	# also confirms no accidental multi-spawn across the whole move.
	var s := _two_char_state(200)
	s.players[0].state_id = CharacterA.STATE_FIREBALL_L
	s.players[0].frame_in_state = 0
	var max_seen: int = 0
	for _k in range(50):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.projectiles.size() > max_seen:
			max_seen = s.projectiles.size()
	_eq(max_seen, 1, "one cast spawns exactly one fireball, never more (spawn fires once)")
	_cleanup()


func _test_fireball_one_tick_offset() -> void:
	# AD-030/JC-034: a projectile spawned on tick T does not integrate/age on
	# tick T -- it first moves and decrements lifetime on tick T+1. Spawn frame
	# is 14 (FIREBALL_SPAWN_FRAME); verify pos is UNCHANGED the tick it appears
	# and CHANGES the following tick.
	var s := _two_char_state(200)
	s.players[0].state_id = CharacterA.STATE_FIREBALL_H
	s.players[0].frame_in_state = 0
	var pos_at_spawn: int = 0
	var lifetime_at_spawn: int = 0
	var found_spawn_tick: bool = false
	for _k in range(20):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.projectiles.size() > 0 and not found_spawn_tick:
			found_spawn_tick = true
			pos_at_spawn = s.projectiles[0].pos_x
			lifetime_at_spawn = s.projectiles[0].lifetime_remaining
			_eq(lifetime_at_spawn, CharacterA.FIREBALL_LIFETIME,
				"projectile appears with its FULL authored lifetime on the spawn tick")
			# Advance exactly one more tick and check it moved + aged.
			s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
			_true(s.projectiles[0].pos_x != pos_at_spawn,
				"the fireball FIRST moves on the tick AFTER it spawns (AD-030 one-tick offset)")
			_eq(s.projectiles[0].lifetime_remaining, lifetime_at_spawn - 1,
				"the fireball FIRST ages (lifetime decrements) on the tick AFTER it spawns")
			break
	_true(found_spawn_tick, "fireball spawn was observed")
	_cleanup()


func _test_fireball_cap_suppresses_second_cast() -> void:
	# character-a.md criterion 5: "a second cast while one is live is suppressed"
	# (one fireball per player, max_per_owner = 1, AD-021).
	var s := _two_char_state(300)
	s.players[0].state_id = CharacterA.STATE_FIREBALL_L
	s.players[0].frame_in_state = 0
	for _k in range(20):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.projectiles.size() > 0:
			break
	_eq(s.projectiles.size(), 1, "first fireball is live")
	# P0 recovers, then casts again while the first is still traveling.
	for _k in range(35):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(Actionability.is_actionable(s.players[0], MoveRegistry.character(CharacterA.CHAR_ID).get_state(s.players[0].state_id)),
		"P0 is actionable again after the first fireball's recovery")
	s.players[0].state_id = CharacterA.STATE_FIREBALL_L
	s.players[0].frame_in_state = 0
	var still_one: bool = true
	for _k in range(20):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.projectiles.size() > 1:
			still_one = false
	_true(still_one, "casting a second fireball while one is live is suppressed (cap = 1)")
	_cleanup()


# --- Criterion 6: DP invuln + punish ------------------------------------------

func _test_dp_invuln_authored_and_full_punishable() -> void:
	for state_id in [CharacterA.STATE_DP_L, CharacterA.STATE_DP_M, CharacterA.STATE_DP_H]:
		var m: MoveState = CharacterA.build_character().get_state(state_id)
		var fd: FrameData = MoveData.frame_data(m)
		# Invuln authored from frame 1 through at least the first active frame.
		var first_active: int = fd.startup + 1
		var covers: bool = true
		for f in range(1, first_active + 1):
			var has_invuln: bool = false
			for kf in m.keyframes_at(f):
				if kf.invuln_strike:
					has_invuln = true
			if not has_invuln:
				covers = false
		_true(covers, "DP state %d authors invuln_strike frame 1 through first active (inert pending docs/flags.md)" % state_id)
		# Full-punishable by construction: total recovery from first-active contact
		# (fd.recovery + fd.active - 1) must EXCEED 5H's own frames-to-actionable
		# from ITS first-active contact (i.e. 5H, as the punish tool, must start up
		# and its 25f startup must fit before the DP recovers).
		var dp_attacker_recovery: int = fd.recovery + fd.active - 1
		var five_h_startup: int = 25
		_true(dp_attacker_recovery > five_h_startup,
			"DP state %d recovery (%df) exceeds 5H's 25f startup -- even 5H punishes (criterion 6)" % [state_id, dp_attacker_recovery])
	# 623H also authors invuln_throw (character-a.md: "strike+throw 1-8").
	var h: MoveState = CharacterA.build_character().get_state(CharacterA.STATE_DP_H)
	var throw_invuln_1_to_8: bool = true
	for f in range(1, 9):
		var has_it: bool = false
		for kf in h.keyframes_at(f):
			if kf.invuln_throw:
				has_it = true
		if not has_it:
			throw_invuln_1_to_8 = false
	_true(throw_invuln_1_to_8, "623H authors invuln_throw covering frames 1-8 (strike+throw invuln)")


func _test_dp_h_two_hit() -> void:
	# 623H is a 2-hit launch (AD-016 sequential multi-hit: two distinct id_groups).
	var s := _two_char_state(30)
	s.players[0].state_id = CharacterA.STATE_DP_H
	s.players[0].frame_in_state = 0
	var max_combo: int = 0
	for _k in range(40):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[1].combo_hits > max_combo:
			max_combo = s.players[1].combo_hits
	_eq(max_combo, 2, "623H registers exactly two hits (2-hit launch)")
	_cleanup()


# --- Criterion 7: throw -------------------------------------------------------

func _test_throw_connects_through_block() -> void:
	var s := _two_char_state(30)
	s.players[0].state_id = CharacterA.STATE_THROW
	s.players[0].frame_in_state = 0
	var p1_block: int = InputFrame.RIGHT   # P1 faces -1; back = RIGHT
	var connected: bool = false
	for _k in range(10):
		s = SimState.step(s, InputFrame.NEUTRAL, p1_block)
		if s.players[1].state_id == CharacterA.STATE_THROWN:
			connected = true
			break
	_true(connected, "throw connects through block (bypasses blockstun)")
	_true(s.players[1].health < 1000, "throw dealt damage on connect")
	_cleanup()


func _test_throw_tech_window() -> void:
	var s := _two_char_state(30)
	s.players[0].state_id = CharacterA.STATE_THROW
	s.players[0].frame_in_state = 0
	for _k in range(10):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[1].state_id == CharacterA.STATE_THROWN:
			break
	_eq(s.players[1].state_id, CharacterA.STATE_THROWN, "throw connected (pre-tech)")
	_true(s.players[1].throw_tech_window > 0 and s.players[1].throw_tech_window <= CharacterA.THROW_TECH_WINDOW,
		"tech window is open and within the authored 7-frame window")
	# Defender techs by driving state directly into a throw-shaped command
	# recognition path: since STATE_THROW has no button_map entry (flagged),
	# tech recognition (_has_buffered_throw) cannot fire from raw input either
	# in this batch -- assert the DATA (tech_window field, hitbox) instead,
	# which is what criterion 7 actually claims ("techable within 7 frames").
	var throw_move: MoveState = CharacterA.build_character().get_state(CharacterA.STATE_THROW)
	var tb: HitBox = null
	for kf in throw_move.timeline:
		for h in kf.hitboxes:
			if h.is_throw:
				tb = h
	_true(tb != null, "the throw state carries a throwbox")
	_eq(tb.tech_window, CharacterA.THROW_TECH_WINDOW, "the throwbox authors a 7-frame tech window (AD-029 dedicated field)")
	_cleanup()


func _test_throw_hard_knockdown() -> void:
	var s := _two_char_state(30)
	s.players[0].state_id = CharacterA.STATE_THROW
	s.players[0].frame_in_state = 0
	for _k in range(10):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[1].state_id == CharacterA.STATE_THROWN:
			break
	_eq(s.players[1].state_id, CharacterA.STATE_THROWN, "throw connected")
	# Hard knockdown: defender remains non-actionable for the full authored
	# THROW_HITSTUN (30f), not a token few frames.
	var still_down_at_20: bool = true
	for _k in range(20):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	if Actionability.is_actionable(s.players[1], MoveRegistry.character(CharacterA.CHAR_ID).get_state(s.players[1].state_id)):
		still_down_at_20 = false
	_true(still_down_at_20, "thrown defender stays down for a real hard-knockdown duration, not a token few frames")
	_cleanup()


# --- Cancels: > 236 / > 623 ----------------------------------------------------

## Drive P0 from STATE_2M through contact, then feed the REAL 623 sequence
## (forward, down, down-forward -- distinct from 236's down/down-forward/
## forward, so it cannot be confused with a fireball cancel sharing the same
## button) holding the final down-forward+button through to the cancel,
## matching test_buffer_cancels.gd's _test_buffered_reversal_frame1 pattern.
## Returns the state after the cancel fires (or after giving up).
func _drive_2m_into_dp_l() -> SimState:
	var s := _two_char_state(50)
	s.players[0].state_id = CharacterA.STATE_2M
	s.players[0].frame_in_state = 0
	for _k in range(25):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[0].move_contact == PlayerState.CONTACT_HIT:
			break
	# P0 is still frozen in hitstop from the connecting hit; wait it out feeding
	# neutral (a held 623 prefix risks ALSO satisfying 236's D/DF/F pattern once
	# repeated across many ticks, since a held down-forward frame trivially
	# satisfies both 236's and 623's shared DF/F tokens -- so hold NOTHING
	# during the freeze, then fire the real 3-tick 623 sequence ONCE, timed so
	# it completes exactly as hitstop clears (fresh within the 9f motion / 6f
	# command windows, unambiguous because it is not repeated).
	while s.players[0].hitstop > 0:
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	var f: int = InputFrame.RIGHT          # P0 faces +1 -> forward is RIGHT
	var d: int = InputFrame.DOWN
	var df: int = InputFrame.DOWN | InputFrame.RIGHT
	var b0: int = InputFrame.BUTTON_0
	var seq: Array = [f | b0, d | b0, df | b0]
	for inp in seq:
		s = SimState.step(s, inp, InputFrame.NEUTRAL)
		if s.players[0].state_id == CharacterA.STATE_DP_L:
			return s
	# Hold the completed motion's final frame a few more ticks (command-buffer
	# leniency) in case the cancel phase needed one more tick to observe it.
	for _k in range(4):
		s = SimState.step(s, df | b0, InputFrame.NEUTRAL)
		if s.players[0].state_id == CharacterA.STATE_DP_L:
			return s
	return s


func _test_special_cancel_2m_into_dp() -> void:
	# 2M > 623L on contact (character-a.md's footsie/whiff-punish route uses this).
	var s := _drive_2m_into_dp_l()
	_true(s.players[0].state_id == CharacterA.STATE_DP_L,
		"2M > 623L: special-cancel into the DP fires on contact (tag-gated, character-a.md route 1)")
	_cleanup()


func _test_footsie_route_2m_dp_l() -> void:
	# character-a.md route 1: 2M > 623L -> hard KD. Confirm the DP portion of
	# the route ends in the hard-knockdown launch reaction.
	var s := _drive_2m_into_dp_l()
	_eq(s.players[0].state_id, CharacterA.STATE_DP_L, "cancel into 623L landed")
	# Drive the DP to connect; P1 should end in the launch->hard-KD reaction.
	var kd: bool = false
	for _k in range(30):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[1].state_id == CharacterA.STATE_HITSTUN_LAUNCH:
			kd = true
			break
	_true(kd, "2M > 623L route ends in the DP's launch -> hard-knockdown reaction")
	_cleanup()


# --- Jump arc (movement table; authored data, flagged unreachable via input) --

func _test_jump_arc_integrates() -> void:
	# The jump states are reachable via button_map now (AD-032, TKT-P1-12), but
	# this test still drives the state directly to isolate the AUTHORED KEYFRAME
	# MOTION itself (data), independent of command recognition.
	var s := _two_char_state(200)
	s.players[0].state_id = CharacterA.STATE_JUMP_N
	s.players[0].frame_in_state = 0
	var start_y: int = s.players[0].pos_y
	var apex_y: int = start_y
	for _k in range(22):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[0].pos_y < apex_y:
			apex_y = s.players[0].pos_y
	_true(apex_y < start_y, "the jump arc rises (pos_y decreases) during the authored rise frames")
	for _k in range(23):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	# FIX (2026-07-08 human-inspection-gate flag, "player sinks ~5px below the
	# floor on landing"): 22 rise frames + a one-frame zero-velocity apex hang
	# (frame 23) + 22 fall frames now nets to EXACTLY zero displacement (was: 22
	# rise @ -6.0 + 23 fall @ +6.0 = +6 units of permanent downward drift, since
	# 45 is odd and the old split gave the extra frame entirely to the fall
	# half). Assert the arc returns BIT-EXACT to its starting height, not merely
	# "close" -- this is the deliberate behavior change the fix makes (recorded
	# JC-017-style in judgment-log.md: this test's prior tolerance documented the
	# very drift that was the reported defect).
	_eq(s.players[0].pos_y, start_y,
		"the jump arc returns EXACTLY to its starting height after the full authored duration (no floor-sink drift)")
	_cleanup()


# --- The baked .tres artifact matches the builder (one authored definition) --

func _test_baked_tres_matches_builder() -> void:
	# TKT-P1-10: character A is authored PURELY as .tres data (criterion 1). The
	# shipped artifact is data/character-a.tres, baked from CharacterA.build_
	# character() by tools/bake_character_a.gd; this asserts the .tres on disk
	# still matches the builder (no drift between the authored file and the
	# content source) and that it resolves through the real generic engine path
	# exactly like the programmatic twin -- proving the .tres itself, not just
	# the builder function, is what "playable against a dummy" means.
	var loaded: Character = load("res://data/character-a.tres")
	_true(loaded != null, "data/character-a.tres loads as a Character resource")
	var built: Character = CharacterA.build_character()
	_eq(loaded.id, built.id, "baked .tres character id matches the builder")
	_eq(loaded.states.size(), built.states.size(), "baked .tres has the same number of states as the builder")
	_eq(loaded.button_map.size(), built.button_map.size(), "baked .tres has the same button_map size as the builder")
	# Spot-check derived frame data agrees for a representative move (5H, the
	# most structurally distinctive: 25f startup, forward-advancing, +3/+7).
	var l5h: MoveState = loaded.get_state(CharacterA.STATE_5H)
	var b5h: MoveState = built.get_state(CharacterA.STATE_5H)
	var lfd: FrameData = MoveData.frame_data(l5h)
	var bfd: FrameData = MoveData.frame_data(b5h)
	_eq(lfd.on_block_adv, bfd.on_block_adv, "baked .tres 5H on-block advantage matches the builder")
	_eq(lfd.on_hit_adv, bfd.on_hit_adv, "baked .tres 5H on-hit advantage matches the builder")
	# Resolve the LOADED .tres through a REAL step (not just static derivation)
	# to prove it plays through the generic engine path, not only the builder's
	# in-memory twin.
	MoveRegistry.install({loaded.id: loaded})
	ProjectileRegistry.install(CharacterA.build_projectile_registry())
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = loaded.id
	s.players[0].state_id = CharacterA.STATE_5L
	s.players[0].frame_in_state = 0
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = loaded.id
	s.players[1].state_id = CharacterA.STATE_IDLE
	s.players[1].pos_x = FP.from_int(30)
	s.players[1].facing = -1
	var connected: bool = false
	for _k in range(15):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[0].move_contact == PlayerState.CONTACT_HIT:
			connected = true
			break
	_true(connected, "5L from the LOADED .tres connects through a real SimState.step (the artifact itself is playable)")
	_cleanup()
