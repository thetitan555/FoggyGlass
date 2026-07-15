extends SceneTree

## Headless test for TKT-P2-02 (double-tap dash + one-air-action economy — AD-046).
## Serves `move-format.md` criterion 12 (`ButtonMapEntry.double_tap`),
## `combat-resolution.md` criterion 16 (one air action), `character-b.md`
## criterion 3, and `inspection-surface.md` (`PlayerView.air_action_used`).
##
## Three layers, mirroring this tree's established shape:
##   1. PURE recognizer unit tests (InputBuffer.double_tap_recognized /
##      direction_pressed_edge / entry_satisfied) — no SimState at all, exercising
##      the recognition functions directly over a hand-built InputHistory.
##   2. Character A's `66`/`44` reaching STATE_DASH_F/STATE_DASH_B through the
##      REAL button_map, driven via TraceHarness (mirrors test_airborne_actions.gd).
##   3. The air-action economy (air dash / double jump / suppression / the
##      PlayerView readout), driven directly through SimState.step (mirrors
##      test_airborne_physics.gd's convention of hand-setting state_id/
##      frame_in_state to isolate the engine mechanism from command recognition).
##      Character A's `physics.air_dash_speed`/`double_jump_velocity` are TEST-ONLY
##      mutations of a builder-produced Character (character_a.gd's authored kit is
##      untouched — A does not carry these values in its shipped content; the
##      engine mechanism itself is universal/character-value-gated, same convention
##      as `gravity`/`jump_velocity`).
##
## Run:  godot --headless --path game -s res://tests/test_dash_air_action.gd
## Exits non-zero on any failure so a harness/CI can gate on it.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	if _failures == 0:
		print("[test_dash_air_action] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_dash_air_action] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	_test_double_tap_recognizes_press_release_press()
	_test_double_tap_rejects_continuous_hold()
	_test_double_tap_rejects_single_press_no_repress()
	_test_double_tap_window_boundary_recognized_at_edge()
	_test_double_tap_window_boundary_fails_one_frame_too_late()
	_test_direction_pressed_edge_true_only_on_fresh_press()
	_test_direction_pressed_edge_false_on_continuous_hold()
	_test_entry_satisfied_double_tap_entry()

	_test_character_a_66_reaches_dash_f()
	_test_character_a_44_reaches_dash_b()

	_test_air_dash_spends_air_action_and_sets_velocity()
	_test_double_jump_spends_air_action_and_reimpulses()
	_test_second_air_action_suppressed_until_spent_flag_cleared()
	_test_held_up_from_takeoff_does_not_spend_double_jump()
	_test_plain_air_normal_does_not_spend_air_action()

	_test_player_view_surfaces_air_action_used()


# =============================================================================
# Layer 1: pure recognizer unit tests (no SimState).
# =============================================================================

## Push `frame` onto `hist` for `count` ticks (a plain hold/release helper for
## building history sequences by hand).
func _push_n(hist: InputHistory, frame: int, count: int) -> void:
	for _k in range(count):
		hist.push(frame)


func _test_double_tap_recognizes_press_release_press() -> void:
	var hist := InputHistory.new()
	_push_n(hist, InputFrame.NEUTRAL, 3)
	_push_n(hist, InputFrame.RIGHT, 1)     # first press
	_push_n(hist, InputFrame.NEUTRAL, 1)   # release
	_push_n(hist, InputFrame.RIGHT, 1)     # second press
	_true(InputBuffer.double_tap_recognized(hist, InputFrame.RIGHT, 1),
		"press -> release -> press of RIGHT within the window is recognized as a double-tap (facing +1)")
	# Facing-relative: the SAME raw sequence with facing -1 means "forward" is
	# actually raw LEFT, so RIGHT (raw) does NOT satisfy a required_direction of
	# RIGHT under facing -1 (AD-002) — never recognized.
	_eq(InputBuffer.double_tap_recognized(hist, InputFrame.RIGHT, -1), false,
		"the same raw RIGHT double-tap does not satisfy a RIGHT(forward) requirement under facing -1")


func _test_double_tap_rejects_continuous_hold() -> void:
	var hist := InputHistory.new()
	_push_n(hist, InputFrame.NEUTRAL, 2)
	_push_n(hist, InputFrame.RIGHT, 6)   # held continuously, never released
	_eq(InputBuffer.double_tap_recognized(hist, InputFrame.RIGHT, 1), false,
		"a continuous hold (no release) never satisfies a double-tap — this is what keeps an ordinary walk from spuriously dashing")


func _test_double_tap_rejects_single_press_no_repress() -> void:
	var hist := InputHistory.new()
	_push_n(hist, InputFrame.NEUTRAL, 4)
	_push_n(hist, InputFrame.RIGHT, 1)
	_push_n(hist, InputFrame.NEUTRAL, 4)
	_eq(InputBuffer.double_tap_recognized(hist, InputFrame.RIGHT, 1), false,
		"a single press with no second press never satisfies a double-tap")


## Window-boundary tests (AD-046 placeholder DOUBLE_TAP_WINDOW = 12, logged
## judgment-log.md). `double_tap_recognized` scans the last DOUBLE_TAP_WINDOW
## frames of history (ages 0..DOUBLE_TAP_WINDOW-1). Placing the second press
## EXACTLY at the oldest in-window age (age = DOUBLE_TAP_WINDOW - 1, i.e. the
## sequence completes on the LAST frame the scan still covers) must recognize;
## pushing one MORE neutral frame first (shoving the whole sequence one frame
## further into the past) must not.

func _test_double_tap_window_boundary_recognized_at_edge() -> void:
	var hist := InputHistory.new()
	# Build so the SECOND press lands exactly DOUBLE_TAP_WINDOW-1 frames before
	# the newest pushed frame: press(1) -> release(1) -> press(1) -> pad with
	# NEUTRAL up to (DOUBLE_TAP_WINDOW - 3) more frames so the newest frame is
	# exactly the boundary.
	var pad: int = InputBuffer.DOUBLE_TAP_WINDOW - 3
	_push_n(hist, InputFrame.RIGHT, 1)     # first press
	_push_n(hist, InputFrame.NEUTRAL, 1)   # release
	_push_n(hist, InputFrame.RIGHT, 1)     # second press (this is the ONLY press ever seen again)
	_push_n(hist, InputFrame.NEUTRAL, pad) # push the sequence to the oldest edge of the window
	_true(InputBuffer.double_tap_recognized(hist, InputFrame.RIGHT, 1),
		"a press-release-press completing exactly at the oldest in-window age is still recognized")


func _test_double_tap_window_boundary_fails_one_frame_too_late() -> void:
	var hist := InputHistory.new()
	var pad: int = InputBuffer.DOUBLE_TAP_WINDOW - 3 + 1   # one MORE than the recognized case
	_push_n(hist, InputFrame.RIGHT, 1)
	_push_n(hist, InputFrame.NEUTRAL, 1)
	_push_n(hist, InputFrame.RIGHT, 1)
	_push_n(hist, InputFrame.NEUTRAL, pad)
	_eq(InputBuffer.double_tap_recognized(hist, InputFrame.RIGHT, 1), false,
		"the identical press-release-press one frame further outside the window is NOT recognized")


func _test_direction_pressed_edge_true_only_on_fresh_press() -> void:
	var hist := InputHistory.new()
	_push_n(hist, InputFrame.NEUTRAL, 5)
	_push_n(hist, InputFrame.UP, 1)   # a fresh press THIS tick
	_true(InputBuffer.direction_pressed_edge(hist, InputFrame.UP, 1),
		"UP held this tick, not held the tick before, IS a rising edge")


func _test_direction_pressed_edge_false_on_continuous_hold() -> void:
	var hist := InputHistory.new()
	_push_n(hist, InputFrame.UP, 8)   # held for many ticks, including "now" and "the tick before"
	_eq(InputBuffer.direction_pressed_edge(hist, InputFrame.UP, 1), false,
		"UP held continuously (held both this tick AND the tick before) is NOT a rising edge — " +
		"this is exactly what stops a jump's own initiating UP-press from instantly spending the double jump")
	# Aged one tick further (still continuous): also false, and NOT rescued by any
	# lookback window (direction_pressed_edge is a strict this-tick-vs-prev check,
	# unlike direction_buffered's leniency) — the original 1-frame edge at the very
	# start of the push sequence is long gone by the time this check runs.
	_push_n(hist, InputFrame.UP, 1)
	_eq(InputBuffer.direction_pressed_edge(hist, InputFrame.UP, 1), false,
		"still no edge one tick later, still mid-hold")


func _test_entry_satisfied_double_tap_entry() -> void:
	var hist := InputHistory.new()
	_push_n(hist, InputFrame.NEUTRAL, 2)
	_push_n(hist, InputFrame.RIGHT, 1)
	_push_n(hist, InputFrame.NEUTRAL, 1)
	_push_n(hist, InputFrame.RIGHT, 1)
	var e := ButtonMapEntry.new()
	e.button_index = -1
	e.required_direction = InputFrame.RIGHT
	e.double_tap = true
	e.target_state_id = 999
	_true(InputBuffer.entry_satisfied(hist, e, 1),
		"a double_tap ButtonMapEntry is satisfied through the ONE recognizer (entry_satisfied)")
	# A held (non-double-tap) RIGHT never satisfies the double_tap entry, even
	# though it WOULD satisfy an ordinary pure-direction entry (AD-032) — the two
	# shapes are genuinely distinct recognition paths.
	var hist2 := InputHistory.new()
	_push_n(hist2, InputFrame.RIGHT, 6)
	_eq(InputBuffer.entry_satisfied(hist2, e, 1), false,
		"a continuous RIGHT hold does not satisfy a double_tap entry, even though it would satisfy a plain pure-direction entry")


# =============================================================================
# Layer 2: character A's 66/44 reach STATE_DASH_F/STATE_DASH_B (real engine).
# =============================================================================

func _roster() -> Dictionary:
	return {CharacterA.CHAR_ID: CharacterA.build_character()}


func _first_tick_in_state(rows: Array[Dictionary], state_id: int) -> int:
	for row in rows:
		if int(row["p0.state"]) == state_id:
			return int(row["tick"])
	return -1


func _test_character_a_66_reaches_dash_f() -> void:
	# 6 (forward), release to neutral for a tick, 6 again (forward) -- a genuine
	# double-tap gesture through the real InputScript grammar.
	var rows: Array[Dictionary] = TraceHarness.run("6*1 5*1 6*1 5*30", "", 34, _roster(), CharacterA.CHAR_ID)
	var dash_tick: int = _first_tick_in_state(rows, CharacterA.STATE_DASH_F)
	_true(dash_tick != -1, "double-tapping forward (66) reaches STATE_DASH_F")
	if dash_tick != -1:
		_true(TraceHarness.check(rows, dash_tick, "p0.cat", MoveState.CATEGORY_GROUNDED),
			"STATE_DASH_F is category GROUNDED")
	MoveRegistry.clear()


func _test_character_a_44_reaches_dash_b() -> void:
	var rows: Array[Dictionary] = TraceHarness.run("4*1 5*1 4*1 5*30", "", 34, _roster(), CharacterA.CHAR_ID)
	var dash_tick: int = _first_tick_in_state(rows, CharacterA.STATE_DASH_B)
	_true(dash_tick != -1, "double-tapping back (44) reaches STATE_DASH_B")
	MoveRegistry.clear()


# =============================================================================
# Layer 3: the one-air-action economy (direct SimState.step driving, mirroring
# test_airborne_physics.gd's convention of hand-setting state/frame to isolate
# the engine mechanism from command recognition).
# =============================================================================

## Character A's builder, with TEST-ONLY nonzero air_dash_speed/double_jump_velocity
## (A's own authored kit does not use these — this test exercises the GENERIC
## engine mechanism, universal across characters, per-character-value-gated
## exactly like gravity/jump_velocity).
const AIR_DASH_SPEED: float = 6.0
const DOUBLE_JUMP_VELOCITY: float = 18.0

func _air_action_roster() -> Dictionary:
	var c: Character = CharacterA.build_character()
	c.physics.air_dash_speed = FP.from_units(AIR_DASH_SPEED)
	c.physics.double_jump_velocity = FP.from_units(DOUBLE_JUMP_VELOCITY)
	return {CharacterA.CHAR_ID: c}


func _install(roster: Dictionary) -> void:
	MoveRegistry.install(roster)


func _cleanup() -> void:
	MoveRegistry.clear()


func _two_char_state() -> SimState:
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = CharacterA.CHAR_ID
	s.players[0].state_id = CharacterA.STATE_IDLE
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = CharacterA.CHAR_ID
	s.players[1].state_id = CharacterA.STATE_IDLE
	s.players[1].pos_x = FP.from_int(300)
	s.players[1].facing = -1
	return s


## Drive `s` mid-flight in STATE_JUMP_N (well past the frame-1 takeoff impulse,
## so `was_airborne` is unambiguously true and any transient takeoff-frame
## quirk is well behind us), holding NEUTRAL throughout.
func _mid_flight_state(roster: Dictionary) -> SimState:
	_install(roster)
	var s := _two_char_state()
	s.players[0].state_id = CharacterA.STATE_JUMP_N
	s.players[0].frame_in_state = 0
	for _k in range(10):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	return s


func _test_air_dash_spends_air_action_and_sets_velocity() -> void:
	var roster := _air_action_roster()
	var s := _mid_flight_state(roster)
	_eq(s.players[0].air_action_used, false, "air_action_used is unspent 10 ticks into an ordinary jump")
	_true(s.players[0].state_id == CharacterA.STATE_JUMP_N, "still mid-flight in STATE_JUMP_N")

	# Double-tap forward: press, release, press.
	s = SimState.step(s, InputFrame.RIGHT, InputFrame.NEUTRAL)
	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	s = SimState.step(s, InputFrame.RIGHT, InputFrame.NEUTRAL)   # the tap completes THIS tick

	var gravity: int = CharacterA.build_character().physics.gravity
	_eq(s.players[0].vel_x, FP.from_units(AIR_DASH_SPEED),
		"air dash sets vel_x to physics.air_dash_speed (facing +1, forward)")
	_eq(s.players[0].vel_y, gravity,
		"air dash zeroes vel_y this tick, then the SAME tick's gravity accrual applies on top " +
		"(mirrors the takeoff impulse's own same-tick-gravity contract)")
	_eq(s.players[0].air_action_used, true, "air dash spends the one air action")
	_cleanup()


func _test_double_jump_spends_air_action_and_reimpulses() -> void:
	var roster := _air_action_roster()
	var s := _mid_flight_state(roster)
	var vy_before: int = s.players[0].vel_y

	# A FRESH up-press (not a continuation of any prior hold — history has been
	# all-NEUTRAL for the last 10 ticks).
	s = SimState.step(s, InputFrame.UP, InputFrame.NEUTRAL)

	var gravity: int = CharacterA.build_character().physics.gravity
	_eq(s.players[0].vel_y, -FP.from_units(DOUBLE_JUMP_VELOCITY) + gravity,
		"double jump re-impulses vel_y to -physics.double_jump_velocity, then gravity accrues the same tick")
	_true(s.players[0].vel_y != vy_before, "vel_y visibly changed from its natural gravity-only trajectory")
	_eq(s.players[0].air_action_used, true, "double jump spends the one air action")
	_eq(s.players[0].vel_x, 0, "double jump does not touch vel_x")
	_cleanup()


func _test_second_air_action_suppressed_until_spent_flag_cleared() -> void:
	var roster := _air_action_roster()
	var s := _mid_flight_state(roster)

	# Spend the air action via double jump.
	s = SimState.step(s, InputFrame.UP, InputFrame.NEUTRAL)
	_eq(s.players[0].air_action_used, true, "the air action is spent")
	var vy_after_double_jump: int = s.players[0].vel_y
	var gravity: int = CharacterA.build_character().physics.gravity

	# Continue holding neutral a few ticks (natural gravity accrual only).
	for _k in range(3):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		vy_after_double_jump += gravity
	_eq(s.players[0].vel_y, vy_after_double_jump,
		"vel_y follows ordinary gravity accrual with no further air-action interference")

	# Attempt a SECOND air action (a full double-tap forward gesture) while
	# air_action_used is still true -- must be suppressed: neither vel_x (air
	# dash) nor a vel_y re-impulse (double jump) should fire.
	var vx_before_attempt: int = s.players[0].vel_x
	s = SimState.step(s, InputFrame.RIGHT, InputFrame.NEUTRAL)
	vy_after_double_jump += gravity
	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	vy_after_double_jump += gravity
	s = SimState.step(s, InputFrame.RIGHT, InputFrame.NEUTRAL)   # would complete a double-tap, if unspent
	vy_after_double_jump += gravity
	_eq(s.players[0].vel_x, vx_before_attempt,
		"a SECOND double-tap forward is suppressed -- vel_x is untouched (air_action_used already true)")
	_eq(s.players[0].vel_y, vy_after_double_jump,
		"vel_y still follows plain gravity accrual -- the second air action never fired")
	_true(s.players[0].air_action_used, "air_action_used stays true (not re-derived, not cleared by the failed attempt)")

	# Simulate a landing reset directly (the reset mechanism itself is TKT-P2-01's
	# scope, already covered by test_airborne_physics.gd) and confirm the SAME
	# gesture spends the (now-fresh) air action again -- the suppression is keyed
	# purely on the per-jump flag, not a one-time-ever budget.
	s.players[0].air_action_used = false
	var vx_before_second_dash: int = s.players[0].vel_x
	s = SimState.step(s, InputFrame.RIGHT, InputFrame.NEUTRAL)
	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	s = SimState.step(s, InputFrame.RIGHT, InputFrame.NEUTRAL)
	_eq(s.players[0].vel_x, FP.from_units(AIR_DASH_SPEED),
		"once air_action_used is fresh again (landing-reset proxy), the same gesture spends it again")
	_true(s.players[0].vel_x != vx_before_second_dash, "vel_x visibly changed on the fresh attempt")
	_cleanup()


func _test_held_up_from_takeoff_does_not_spend_double_jump() -> void:
	# The regression this ticket's fix (direction_pressed_edge, strict this-tick-
	# vs-previous-tick) guards against: a jump command HELD continuously through
	# takeoff must never itself register as a fresh double-jump press the moment
	# the character becomes airborne. Drives a REAL neutral-jump input (held UP
	# from before takeoff, continuing through flight) and confirms the takeoff
	# impulse's vel_y is never clobbered to a near-zero double-jump re-impulse.
	var roster := _air_action_roster()
	_install(roster)
	var s := _two_char_state()
	for _k in range(6):
		s = SimState.step(s, InputFrame.UP, InputFrame.NEUTRAL)   # held UP throughout: idle -> PREJUMP -> JUMP_N
	_eq(s.players[0].state_id, CharacterA.STATE_JUMP_N, "held UP reaches STATE_JUMP_N (unchanged reachability)")
	_eq(s.players[0].air_action_used, false,
		"holding UP continuously from before takeoff through the early airborne ticks never spends the air action")
	_cleanup()


func _test_plain_air_normal_does_not_spend_air_action() -> void:
	# A stand-in for "divekick does not spend the air action" (AD-046): the
	# mechanism is not authored via any CancelRule/state at all (unlike a future
	# divekick would be), so ANY other airborne action -- here, an ordinary air
	# normal reached via JUMP_F's existing air-normal cancel (AD-039) -- is
	# structurally incapable of touching air_action_used. Mirrors
	# test_airborne_actions.gd's mid-jump-button-reaches-air-normal scenario
	# (9*3 5*10 L*1), driven directly through SimState.step (rather than
	# TraceHarness) so `air_action_used` -- not part of TraceHarness's fixed row
	# schema -- is directly observable every tick.
	var roster := _air_action_roster()
	_install(roster)
	var s := _two_char_state()
	var up_forward: int = InputFrame.UP | InputFrame.RIGHT
	for _k in range(3):
		s = SimState.step(s, up_forward, InputFrame.NEUTRAL)
	for _k in range(10):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	s = SimState.step(s, InputFrame.BUTTON_0, InputFrame.NEUTRAL)   # L mid-jump
	_eq(s.players[0].state_id, CharacterA.STATE_JL,
		"pressing L mid-jump still reaches STATE_JL (air-normal reachability unchanged)")
	_eq(s.players[0].air_action_used, false,
		"reaching an ordinary air normal (the divekick stand-in) never spends the air action")
	_cleanup()


func _test_player_view_surfaces_air_action_used() -> void:
	var roster := _air_action_roster()
	_install(roster)
	var s := _two_char_state()
	s.players[0].air_action_used = true
	var view := PlayerView.new(s, 0, roster)
	_true(view.air_action_used, "PlayerView.air_action_used projects the true PlayerState value")

	var s2 := _two_char_state()
	s2.players[0].air_action_used = false
	var view2 := PlayerView.new(s2, 0, roster)
	_eq(view2.air_action_used, false, "PlayerView.air_action_used projects the false PlayerState value")
	_cleanup()
