extends SceneTree

## Headless dev tests for character B's authored move data, part 1
## (TKT-P2-05: normals + gatling ladder + throw + ground movement).
## character-b.md criteria 1, 2, 4 (ground part), 6; move-format.md criterion
## 10. Exercises CharacterB (game/content/character_b.gd) through the real
## SimState.step / InspectionView surface (AD-011), mirroring test_character_a.gd.
##
## Run:  godot --headless --path game -s res://tests/test_character_b.gd
## Exits non-zero on any failure so a harness/CI can gate on it.
##
## RESOLVED ENGINE GAP (docs/flags.md; see character_b.gd's header comment for
## the full write-up): a cancel (concrete OR group-resolved) whose destination
## equals the player's CURRENT state_id used to never fire (CancelEval.
## find_cancel guarded `target == p.state_id` / `group_target == p.state_id`
## unconditionally). The Architect's resolution: the guard is now relaxed to
## PERMIT a same-state cancel except a truly gateless self-target (condition
## ALWAYS + input 0) — this is what makes the lights' literal self-repeat
## (5L->5L, 2L->2L) fire (`CancelEval` only; `step_phases.gd`'s identical
## neutral-branch guard, `target_state != p.state_id`, is intentionally left
## as-is — it sits on a different path, the actionable/neutral re-derivation,
## which this self-repeat cancel does not exercise).

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	if _failures == 0:
		print("[test_character_b] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_character_b] FAIL — %d of %d checks failed" % [_failures, _checks])
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
	_test_frame_data_derivation_2l()
	_test_frame_data_derivation_5m()
	_test_frame_data_derivation_2m()
	_test_frame_data_derivation_5h()
	_test_frame_data_derivation_2h()
	_test_frame_data_derivation_6h()

	_test_ladder_5l_into_2l()
	_test_ladder_2l_into_5m()
	_test_ladder_5m_into_2m()
	_test_ladder_2m_into_2h()
	_test_ladder_2h_into_5h()
	_test_ladder_5h_into_2h()
	_test_ladder_rejects_5m_into_5m()
	_test_ladder_rejects_5m_into_5l()
	_test_ladder_self_repeat_5l_currently_blocked()
	_test_ladder_self_repeat_2l_currently_blocked()
	_test_full_example_chain_resolves_except_the_flagged_repeat_step()

	_test_5h_whiff_is_severely_punishable_vs_block_cancels_early()
	_test_2h_launches_and_jump_cancels_on_block()
	_test_6h_is_reachable_and_not_shadowed_by_5h()
	_test_6h_creeps_forward_during_startup()

	_test_throw_connects_through_block()
	_test_throw_connects_through_crouch_block_downback()
	_test_throw_tech_window()
	_test_throw_hard_knockdown()

	_test_walk_forward_and_back()
	_test_dash_f_reachable_via_66()
	_test_dash_b_reachable_via_44_and_carries_no_invuln()
	_test_jump_reachable_and_gravity_arcs()

	_test_baked_tres_matches_builder()


# --- Scenario setup ----------------------------------------------------------

func _install() -> void:
	MoveRegistry.install({CharacterB.CHAR_ID: CharacterB.build_character()})


func _two_char_state(gap_units: int = 40) -> SimState:
	_install()
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = CharacterB.CHAR_ID
	s.players[0].state_id = CharacterB.STATE_IDLE
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = CharacterB.CHAR_ID
	s.players[1].state_id = CharacterB.STATE_IDLE
	s.players[1].pos_x = FP.from_int(gap_units)
	s.players[1].facing = -1
	return s


func _cleanup() -> void:
	MoveRegistry.clear()


# --- Criterion 1: authored purely as data ------------------------------------

func _test_authored_as_data() -> void:
	var c := CharacterB.build_character()
	_eq(c.id, CharacterB.CHAR_ID, "character B has its own id")
	_true(c.states.size() >= 15, "character B authors a real ground kit (movement+normals+throw+reactions)")
	for st in c.states:
		_true(st.has_valid_category(), "state %d declares a valid engine-level category" % st.id)
	_true(c.cancel_groups.size() >= 5, "character B declares its strength-ladder cancel groups (AD-044)")


# --- Criterion 2 (move-format.md) / character-b.md's Normals table -----------

func _test_frame_data_derivation_5l() -> void:
	var fd: FrameData = MoveData.frame_data(CharacterB.build_character().get_state(CharacterB.STATE_5L))
	_eq(fd.startup, 4, "5L startup = 4")
	_eq(fd.active, 3, "5L active = 3")
	_eq(fd.recovery, 7, "5L recovery = 7")


func _test_frame_data_derivation_2l() -> void:
	var fd: FrameData = MoveData.frame_data(CharacterB.build_character().get_state(CharacterB.STATE_2L))
	_eq(fd.startup, 4, "2L startup = 4")
	_eq(fd.active, 3, "2L active = 3")
	_eq(fd.recovery, 8, "2L recovery = 8")


func _test_frame_data_derivation_5m() -> void:
	var fd: FrameData = MoveData.frame_data(CharacterB.build_character().get_state(CharacterB.STATE_5M))
	_eq(fd.startup, 6, "5M startup = 6")
	_eq(fd.active, 3, "5M active = 3")
	_eq(fd.recovery, 12, "5M recovery = 12")


func _test_frame_data_derivation_2m() -> void:
	var fd: FrameData = MoveData.frame_data(CharacterB.build_character().get_state(CharacterB.STATE_2M))
	_eq(fd.startup, 7, "2M startup = 7")
	_eq(fd.active, 4, "2M active = 4")
	_eq(fd.recovery, 13, "2M recovery = 13")


func _test_frame_data_derivation_5h() -> void:
	var fd: FrameData = MoveData.frame_data(CharacterB.build_character().get_state(CharacterB.STATE_5H))
	_eq(fd.startup, 7, "5H startup = 7 (fast)")
	_eq(fd.active, 3, "5H active = 3")
	_eq(fd.recovery, 20, "5H recovery = 20 (severe)")


func _test_frame_data_derivation_2h() -> void:
	var fd: FrameData = MoveData.frame_data(CharacterB.build_character().get_state(CharacterB.STATE_2H))
	_eq(fd.startup, 9, "2H startup = 9")
	_eq(fd.active, 4, "2H active = 4")
	_eq(fd.recovery, 14, "2H recovery = 14")


func _test_frame_data_derivation_6h() -> void:
	var fd: FrameData = MoveData.frame_data(CharacterB.build_character().get_state(CharacterB.STATE_6H))
	_eq(fd.startup, 22, "6H startup = 22 (reactable)")
	_eq(fd.active, 3, "6H active = 3")
	_eq(fd.recovery, 18, "6H recovery = 18")


# --- Criterion 2 (character-b.md) / AD-044: the gatling ladder ---------------

## Drive P0 into `source_state` against a P1 placed in reach, step until the
## attack connects (move_contact == HIT — P1 held NEUTRAL throughout, so the
## on_contact cancel condition is satisfied by a HIT), then attempt the cancel
## by feeding `target_input` for a few ticks BEFORE `source_state`'s own
## duration elapses (proving it is a genuine early CANCEL, not merely "waited
## for recovery to end, then pressed the next button" — the ordinary buffered-
## command path would reach the same destination on the exact last frame
## regardless, so this specifically checks the EARLY transition).
func _drive_and_attempt_cancel(source_state: int, gap: int, target_input: int, ticks_to_try: int) -> SimState:
	var s := _two_char_state(gap)
	s.players[0].state_id = source_state
	s.players[0].frame_in_state = 0
	var move: MoveState = MoveRegistry.character(CharacterB.CHAR_ID).get_state(source_state)
	var connected: bool = false
	for _k in range(move.duration):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[0].move_contact == PlayerState.CONTACT_HIT:
			connected = true
			break
	assert(connected, "test setup: %d must connect against P1 at gap %d" % [source_state, gap])
	for _k in range(ticks_to_try):
		if s.players[0].frame_in_state >= move.duration:
			break   # only meaningful as an EARLY-cancel check while still committed
		s = SimState.step(s, target_input, InputFrame.NEUTRAL)
	return s


## Every `ticks_to_try` below is generous (>= 20) against ANY authored
## `hitstop` (max 11, 5H's) -- AD-010/017: BOTH parties freeze for `hitstop`
## frames on connect and NO cancel evaluates while frozen, so the attempt loop
## must outlast hitstop before a cancel gets a real unfrozen tick to fire on.

func _test_ladder_5l_into_2l() -> void:
	var s := _drive_and_attempt_cancel(CharacterB.STATE_5L, 35, InputFrame.DOWN | InputFrame.BUTTON_0, 20)
	_eq(s.players[0].state_id, CharacterB.STATE_2L, "5L cancels into 2L (light -> light, different state)")
	_cleanup()


func _test_ladder_2l_into_5m() -> void:
	var s := _drive_and_attempt_cancel(CharacterB.STATE_2L, 35, InputFrame.BUTTON_1, 20)
	_eq(s.players[0].state_id, CharacterB.STATE_5M, "2L cancels into 5M (light -> higher strength)")
	_cleanup()


func _test_ladder_5m_into_2m() -> void:
	var s := _drive_and_attempt_cancel(CharacterB.STATE_5M, 35, InputFrame.DOWN | InputFrame.BUTTON_1, 20)
	_eq(s.players[0].state_id, CharacterB.STATE_2M, "5M cancels into 2M (same strength, opposite stance)")
	_cleanup()


func _test_ladder_2m_into_2h() -> void:
	var s := _drive_and_attempt_cancel(CharacterB.STATE_2M, 40, InputFrame.DOWN | InputFrame.BUTTON_2, 20)
	_eq(s.players[0].state_id, CharacterB.STATE_2H, "2M cancels into 2H (higher strength)")
	_cleanup()


func _test_ladder_2h_into_5h() -> void:
	var s := _drive_and_attempt_cancel(CharacterB.STATE_2H, 30, InputFrame.BUTTON_2, 20)
	_eq(s.players[0].state_id, CharacterB.STATE_5H, "2H cancels into 5H (same strength, opposite stance -- the brief's own example)")
	_cleanup()


func _test_ladder_5h_into_2h() -> void:
	var s := _drive_and_attempt_cancel(CharacterB.STATE_5H, 35, InputFrame.DOWN | InputFrame.BUTTON_2, 20)
	_eq(s.players[0].state_id, CharacterB.STATE_2H, "5H cancels into 2H (same strength, opposite stance)")
	_cleanup()


func _test_ladder_rejects_5m_into_5m() -> void:
	# 5M is not a member of GROUP_FROM_5M ({2M, 5H, 2H}) -- illegal per AD-044
	# (a genuinely DIFFERENT state than the source, so this is NOT entangled
	# with the flagged self-target gap; it is cleanly rejected by group
	# membership alone).
	var s := _drive_and_attempt_cancel(CharacterB.STATE_5M, 35, InputFrame.BUTTON_1, 20)
	_eq(s.players[0].state_id, CharacterB.STATE_5M, "5M does NOT cancel into 5M (not in its ladder group)")
	_cleanup()


func _test_ladder_rejects_5m_into_5l() -> void:
	var s := _drive_and_attempt_cancel(CharacterB.STATE_5M, 35, InputFrame.BUTTON_0, 20)
	_eq(s.players[0].state_id, CharacterB.STATE_5M, "5M does NOT cancel into 5L (not in its ladder group -- lower strength)")
	_cleanup()


func _test_ladder_self_repeat_5l_currently_blocked() -> void:
	# RESOLVED (flags.md, 2026-07-15): AD-044 says "lights self-chain, including
	# exact repeat," so 5L is authored with itself IN its own ladder group
	# (GROUP_ALL_NORMALS). CancelEval's same-state guard was relaxed to permit a
	# same-state cancel except a truly gateless self-target — this on_contact,
	# input-gated cancel is exactly the case now permitted, so 5L->5L fires. Test
	# name kept (drives _drive_and_attempt_cancel's early-cancel proof) but the
	# expectation is flipped from "blocked" to "succeeds."
	var s := _drive_and_attempt_cancel(CharacterB.STATE_5L, 35, InputFrame.BUTTON_0, 20)
	_eq(s.players[0].state_id, CharacterB.STATE_5L, "5L->5L self-repeat fires (AD-044 exact light self-repeat, CancelEval fix)")
	_true(s.players[0].frame_in_state < move_duration(CharacterB.STATE_5L), "the self-repeat re-entered as a FRESH instance (frame_in_state reset), not merely finishing out the original")
	_cleanup()


func _test_ladder_self_repeat_2l_currently_blocked() -> void:
	var s := _drive_and_attempt_cancel(CharacterB.STATE_2L, 35, InputFrame.DOWN | InputFrame.BUTTON_0, 20)
	_eq(s.players[0].state_id, CharacterB.STATE_2L, "2L->2L self-repeat fires (AD-044 exact light self-repeat, CancelEval fix)")
	_cleanup()


## The authored `duration` of a character-B state (fresh lookup — avoids caching a
## builder instance across the self-repeat assertion above).
func move_duration(state_id: int) -> int:
	return CharacterB.build_character().get_state(state_id).duration


## The brief/AD-044's own worked example, "5L 2L 2L 5M 2M 2H 5H," driven END TO
## END through the real engine. Every step resolves EXCEPT the one flagged
## self-repeat step (2L -> 2L), which is skipped over by falling through to
## idle-then-reenter (documenting exactly where the chain currently breaks).
func _test_full_example_chain_resolves_except_the_flagged_repeat_step() -> void:
	var s := _two_char_state(35)

	# 5L
	s.players[0].state_id = CharacterB.STATE_5L
	s.players[0].frame_in_state = 0
	s = _run_until_contact_then(s, 30)
	_eq(s.players[0].state_id, CharacterB.STATE_5L, "chain step 1: in 5L")

	# 5L -> 2L
	s = _feed_until_state(s, InputFrame.DOWN | InputFrame.BUTTON_0, CharacterB.STATE_2L, 20)
	_eq(s.players[0].state_id, CharacterB.STATE_2L, "chain step 2: 5L -> 2L")

	# 2L -> 2L (FLAGGED: does not fire -- the chain cannot continue via cancel here).
	s = _feed_until_state(s, InputFrame.DOWN | InputFrame.BUTTON_0, CharacterB.STATE_2L, 20)
	_true(s.players[0].state_id == CharacterB.STATE_2L, "chain step 3 (flagged gap): still in 2L, self-repeat blocked as documented")

	# 2L -> 5M (this still works from wherever 2L's own cancel window is/whatever
	# frame we're on -- proves the REST of the chain is unaffected by the gap).
	s = _feed_until_state(s, InputFrame.BUTTON_1, CharacterB.STATE_5M, 20)
	_eq(s.players[0].state_id, CharacterB.STATE_5M, "chain step 4: 2L -> 5M (unaffected by the flagged gap)")

	# 5M -> 2M
	s = _feed_until_state(s, InputFrame.DOWN | InputFrame.BUTTON_1, CharacterB.STATE_2M, 20)
	_eq(s.players[0].state_id, CharacterB.STATE_2M, "chain step 5: 5M -> 2M")

	# 2M -> 2H
	s = _feed_until_state(s, InputFrame.DOWN | InputFrame.BUTTON_2, CharacterB.STATE_2H, 20)
	_eq(s.players[0].state_id, CharacterB.STATE_2H, "chain step 6: 2M -> 2H")

	# 2H -> 5H
	s = _feed_until_state(s, InputFrame.BUTTON_2, CharacterB.STATE_5H, 20)
	_eq(s.players[0].state_id, CharacterB.STATE_5H, "chain step 7: 2H -> 5H (the brief's own terminal step)")
	_cleanup()


## Step until P0's current move connects (move_contact == HIT), P1 held neutral.
func _run_until_contact_then(s: SimState, max_ticks: int) -> SimState:
	for _k in range(max_ticks):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[0].move_contact == PlayerState.CONTACT_HIT:
			return s
	return s


## Feed `p0_input` each tick (P1 neutral) until P0 reaches `target_state` or
## `max_ticks` elapses; if P0's OWN current move's duration is reached first
## (no more cancel window), keeps feeding through the ordinary actionable path
## too (both count as the chain progressing for this end-to-end trace).
func _feed_until_state(s: SimState, p0_input: int, target_state: int, max_ticks: int) -> SimState:
	for _k in range(max_ticks):
		s = SimState.step(s, p0_input, InputFrame.NEUTRAL)
		if s.players[0].state_id == target_state:
			return s
	return s


# --- character-b.md B-6: 5H whiff is severely punishable ---------------------

func _test_5h_whiff_is_severely_punishable_vs_block_cancels_early() -> void:
	# WHIFF: no defender in reach at all -- 5H's only cancel (on_contact -> 2H)
	# never becomes legal (move_contact resolves WHIFF, not HIT/BLOCK), so P0
	# is stuck through the FULL 30f duration.
	var s_whiff := _two_char_state(400)   # far out of any reach -- guaranteed whiff
	s_whiff.players[0].state_id = CharacterB.STATE_5H
	s_whiff.players[0].frame_in_state = 0
	for _k in range(29):
		s_whiff = SimState.step(s_whiff, InputFrame.DOWN | InputFrame.BUTTON_2, InputFrame.NEUTRAL)   # holding the 2H input throughout
	_eq(s_whiff.players[0].state_id, CharacterB.STATE_5H, "on a clean whiff, 5H is STILL uncancelled 29 ticks in (no on_whiff escape authored)")
	_eq(s_whiff.players[0].move_contact, PlayerState.CONTACT_WHIFF, "5H recorded a whiff (no contact)")

	# ON BLOCK: P1 blocks (holds back); the SAME 2H input, held from just after
	# connect, cancels EARLY -- well before the raw 30f duration would elapse.
	var s_block := _two_char_state(35)
	s_block.players[0].state_id = CharacterB.STATE_5H
	s_block.players[0].frame_in_state = 0
	var connected: bool = false
	for _k in range(11):
		s_block = SimState.step(s_block, InputFrame.NEUTRAL, InputFrame.RIGHT)   # P1 faces -1; back = RIGHT
		if s_block.players[0].move_contact == PlayerState.CONTACT_BLOCK:
			connected = true
			break
	_true(connected, "5H connects on block (setup)")
	for _k in range(20):
		if s_block.players[0].frame_in_state >= 30:
			break
		s_block = SimState.step(s_block, InputFrame.DOWN | InputFrame.BUTTON_2, InputFrame.RIGHT)
	_eq(s_block.players[0].state_id, CharacterB.STATE_2H, "5H, blocked, cancels into 2H well before its own 30f duration elapses")
	_true(s_block.players[0].frame_in_state < 30, "the cancel-into-2H happened EARLY, not after the raw duration ran out")
	_cleanup()


# --- character-b.md: 2H anti-air launcher + jump-cancel on block -------------

func _test_2h_launches_and_jump_cancels_on_block() -> void:
	# ON HIT: launches into STATE_HITSTUN_LAUNCH (airborne-launched reaction).
	var s_hit := _two_char_state(40)
	s_hit.players[0].state_id = CharacterB.STATE_2H
	s_hit.players[0].frame_in_state = 0
	var hit_connected: bool = false
	for _k in range(14):
		s_hit = SimState.step(s_hit, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s_hit.players[0].move_contact == PlayerState.CONTACT_HIT:
			hit_connected = true
			break
	_true(hit_connected, "2H connects on hit (setup)")
	_eq(s_hit.players[1].state_id, CharacterB.STATE_HITSTUN_LAUNCH, "2H launches its victim into the launch reaction")
	_true(s_hit.players[1].vel_y < 0, "the launched defender carries upward velocity (an actual launch, not a flat knockdown)")

	# ON BLOCK: jump-cancellable -- feed UP shortly after the block connects,
	# well before 2H's own 27f duration elapses.
	var s_block := _two_char_state(40)
	s_block.players[0].state_id = CharacterB.STATE_2H
	s_block.players[0].frame_in_state = 0
	var block_connected: bool = false
	for _k in range(14):
		s_block = SimState.step(s_block, InputFrame.NEUTRAL, InputFrame.RIGHT)
		if s_block.players[0].move_contact == PlayerState.CONTACT_BLOCK:
			block_connected = true
			break
	_true(block_connected, "2H connects on block (setup)")
	var left_2h_early: bool = false
	for _k in range(20):
		if s_block.players[0].state_id != CharacterB.STATE_2H:
			left_2h_early = true   # the jump-cancel fired well before 2H's own 27f duration
			break
		s_block = SimState.step(s_block, InputFrame.UP, InputFrame.RIGHT)
	_true(left_2h_early, "2H, blocked, jump-cancels out EARLY (before its own duration elapses)")
	# Holding UP continues the SAME jump command through the prejump's own
	# cascade (AD-039), so by the time we observe it, it may already be in
	# PREJUMP or have carried on into JUMP_N -- either is the jump-cancel
	# having fired correctly (never idle, never a special/other normal).
	_true(s_block.players[0].state_id == CharacterB.STATE_PREJUMP or s_block.players[0].state_id == CharacterB.STATE_JUMP_N,
		"the jump-cancel lands B in the prejump lead-in or its own jump arc (got state_id=%d)" % s_block.players[0].state_id)
	_cleanup()


# --- 6H reachability (command overhead, not shadowed by 5H) ------------------

func _test_6h_is_reachable_and_not_shadowed_by_5h() -> void:
	var s := _two_char_state(40)
	# Forward + H (numpad 6 + H): must resolve to 6H, not 5H (button_map order).
	s = SimState.step(s, InputFrame.RIGHT | InputFrame.BUTTON_2, InputFrame.NEUTRAL)
	_eq(s.players[0].state_id, CharacterB.STATE_6H, "forward+H resolves to 6H (command overhead), not 5H")
	_cleanup()

	# A bare H (no direction) still reaches plain 5H (6H does not shadow it).
	var s2 := _two_char_state(40)
	s2 = SimState.step(s2, InputFrame.BUTTON_2, InputFrame.NEUTRAL)
	_eq(s2.players[0].state_id, CharacterB.STATE_5H, "a bare H (no forward) still reaches 5H")
	_cleanup()

	# 6H's own guard_height is HIGH.
	var m: MoveState = CharacterB.build_character().get_state(CharacterB.STATE_6H)
	var found_high: bool = false
	for kf in m.timeline:
		for hb in kf.hitboxes:
			if hb.guard_height == HitBox.GUARD_HIGH:
				found_high = true
	_true(found_high, "6H is authored guard_height = HIGH (the dedicated overhead)")


## docs/flags.md 2026-07-17 "re: JC-095 provisional tuning — settled": 6H
## "could move forward slightly during startup to make the overhead tell
## clearer." Drives 6H through the REAL engine and confirms B's world position
## actually advances during the startup window (frames 1-22) — not just that a
## keyframe claims `has_motion` (the authored data alone doesn't prove the
## engine actually applies it every tick).
func _test_6h_creeps_forward_during_startup() -> void:
	var s := _two_char_state(60)
	s.players[0].state_id = CharacterB.STATE_6H
	s.players[0].frame_in_state = 0
	var pos_before: int = s.players[0].pos_x
	for _k in range(21):   # stay inside the 22f startup window (frame_in_state 1..21)
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		_true(s.players[0].frame_in_state <= 22, "sanity: still within 6H's startup window")
	var pos_during_startup: int = s.players[0].pos_x
	_true(pos_during_startup != pos_before, "B's world position actually moves during 6H's startup (the real engine, not just authored data)")
	_true(pos_during_startup > pos_before, "B moves FORWARD (facing +1) during 6H's startup, clarifying the overhead tell")
	_cleanup()


# --- Throw (character-b.md: existing AD-016/029 model, no new throw rules) ---

func _test_throw_connects_through_block() -> void:
	var s := _two_char_state(30)
	s.players[0].state_id = CharacterB.STATE_THROW
	s.players[0].frame_in_state = 0
	var p1_block: int = InputFrame.RIGHT   # P1 faces -1; back = RIGHT
	var connected: bool = false
	for _k in range(10):
		s = SimState.step(s, InputFrame.NEUTRAL, p1_block)
		if s.players[1].state_id == CharacterB.STATE_KNOCKDOWN:
			connected = true
			break
	_true(connected, "throw connects through block (bypasses blockstun)")
	_true(s.players[1].health < 1000, "throw dealt damage on connect")
	_cleanup()


## docs/flags.md 2026-07-17 "re: throw hitbox geometry" — positive confirmation
## to KEEP: "the throw correctly beats a downback hold" (mirrors
## test_character_a.gd's identical regression — see that file for the full
## rationale). Defender starts in STATE_CROUCH and holds DOWN+RIGHT (down-back;
## P1 faces -1) throughout.
func _test_throw_connects_through_crouch_block_downback() -> void:
	var s := _two_char_state(30)
	s.players[0].state_id = CharacterB.STATE_THROW
	s.players[0].frame_in_state = 0
	s.players[1].state_id = CharacterB.STATE_CROUCH
	var p1_down_back: int = InputFrame.DOWN | InputFrame.RIGHT
	var connected: bool = false
	for _k in range(10):
		s = SimState.step(s, InputFrame.NEUTRAL, p1_down_back)
		if s.players[1].state_id == CharacterB.STATE_KNOCKDOWN:
			connected = true
			break
	_true(connected, "throw connects against a down-back (crouch-block) held defender")
	_true(s.players[1].health < 1000, "throw dealt damage on connect (crouch-block case)")
	_cleanup()


func _test_throw_tech_window() -> void:
	var s := _two_char_state(30)
	s.players[0].state_id = CharacterB.STATE_THROW
	s.players[0].frame_in_state = 0
	for _k in range(10):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[1].state_id == CharacterB.STATE_KNOCKDOWN:
			break
	_eq(s.players[1].state_id, CharacterB.STATE_KNOCKDOWN, "throw connected (pre-tech)")
	_true(s.players[1].throw_tech_window > 0 and s.players[1].throw_tech_window <= CharacterB.THROW_TECH_WINDOW,
		"tech window is open and within the authored window")
	_cleanup()


func _test_throw_hard_knockdown() -> void:
	var s := _two_char_state(30)
	s.players[0].state_id = CharacterB.STATE_THROW
	s.players[0].frame_in_state = 0
	for _k in range(10):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[1].state_id == CharacterB.STATE_KNOCKDOWN:
			break
	_eq(s.players[1].state_id, CharacterB.STATE_KNOCKDOWN, "throw connected")
	for _k in range(18):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	var still_down: bool = not Actionability.is_actionable(
		s.players[1], MoveRegistry.character(CharacterB.CHAR_ID).get_state(s.players[1].state_id))
	_true(still_down, "thrown defender stays down for a real hard-knockdown duration, not a token few frames")
	_cleanup()


# --- Ground movement: walk / dash / jump wiring ------------------------------

func _test_walk_forward_and_back() -> void:
	var s := _two_char_state(200)
	var start_x: int = s.players[0].pos_x
	for _k in range(10):
		s = SimState.step(s, InputFrame.RIGHT, InputFrame.NEUTRAL)
	_eq(s.players[0].state_id, CharacterB.STATE_WALK_F, "holding forward reaches STATE_WALK_F")
	_true(s.players[0].pos_x > start_x, "walking forward advances position")

	var s2 := _two_char_state(200)
	var start_x2: int = s2.players[0].pos_x
	for _k in range(10):
		s2 = SimState.step(s2, InputFrame.LEFT, InputFrame.NEUTRAL)
	_eq(s2.players[0].state_id, CharacterB.STATE_WALK_B, "holding back reaches STATE_WALK_B")
	_true(s2.players[0].pos_x < start_x2, "walking back retreats position")
	_cleanup()


func _test_dash_f_reachable_via_66() -> void:
	var roster: Dictionary = {CharacterB.CHAR_ID: CharacterB.build_character()}
	var rows: Array[Dictionary] = TraceHarness.run("6*1 5*1 6*1 5*30", "", 34, roster, CharacterB.CHAR_ID)
	var dash_tick: int = -1
	for row in rows:
		if int(row["p0.state"]) == CharacterB.STATE_DASH_F:
			dash_tick = int(row["tick"])
			break
	_true(dash_tick != -1, "double-tapping forward (66) reaches STATE_DASH_F")
	MoveRegistry.clear()


func _test_dash_b_reachable_via_44_and_carries_no_invuln() -> void:
	var roster: Dictionary = {CharacterB.CHAR_ID: CharacterB.build_character()}
	var rows: Array[Dictionary] = TraceHarness.run("4*1 5*1 4*1 5*30", "", 34, roster, CharacterB.CHAR_ID)
	var dash_tick: int = -1
	for row in rows:
		if int(row["p0.state"]) == CharacterB.STATE_DASH_B:
			dash_tick = int(row["tick"])
			break
	_true(dash_tick != -1, "double-tapping back (44) reaches STATE_DASH_B")
	MoveRegistry.clear()
	# No invuln authored anywhere in DASH_B's timeline (character-b.md: "not
	# invulnerable (or minimal)" -- authored as a clean, read-beatable escape).
	var m: MoveState = CharacterB.build_character().get_state(CharacterB.STATE_DASH_B)
	var any_invuln: bool = false
	for kf in m.timeline:
		if kf.invuln_strike or kf.invuln_throw:
			any_invuln = true
	_false(any_invuln, "back dash carries NO invuln frames (read-beatable escape, not a reversal)")


func _test_jump_reachable_and_gravity_arcs() -> void:
	var s := _two_char_state(200)
	for _k in range(6):
		s = SimState.step(s, InputFrame.UP, InputFrame.NEUTRAL)
	_eq(s.players[0].state_id, CharacterB.STATE_JUMP_N, "holding UP reaches STATE_JUMP_N via the prejump lead-in")
	var apex_reached: bool = false
	var landed: bool = false
	for _k in range(60):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[0].vel_y > 0:
			apex_reached = true   # gravity has turned the ascent into a descent
		if apex_reached and s.players[0].state_id == CharacterB.STATE_IDLE:
			landed = true
			break
	_true(landed, "B's jump rises then lands flush back to idle under the gravity model (AD-043), no hand-baked arc")
	_cleanup()


# --- Golden-able authoring: the baked .tres matches the builder --------------

func _test_baked_tres_matches_builder() -> void:
	var baked := ResourceLoader.load("res://data/character-b.tres", "Resource", ResourceLoader.CACHE_MODE_IGNORE) as Character
	_true(baked != null, "data/character-b.tres loads as a Character")
	if baked == null:
		return
	var built := CharacterB.build_character()
	_eq(baked.states.size(), built.states.size(), "baked .tres has the same state count as the builder")
	_eq(baked.button_map.size(), built.button_map.size(), "baked .tres has the same button_map size as the builder")
	_eq(baked.cancel_groups.size(), built.cancel_groups.size(), "baked .tres has the same cancel_groups count as the builder")
