extends SceneTree

## Headless test for TKT-P1.1R-04 (airborne actions — directional/diagonal
## jumps + air normals, AD-039). Serves AD-039; AD-032 (composite pure-
## direction command); AD-015 (CancelRule); character-a.md → Movement
## ("jumping neutral/forward/back … jump-in normals").
##
## Driven entirely through TraceHarness/InputScript (TKT-P1.1R-01) — the
## instrument this ticket names — since every scenario here is pure scripted
## movement with no proximity/hit-resolution need (unlike TKT-P1.1R-03's
## crouch-block scenario).
##
## Exact tick numbers below were derived by actually replaying each script
## headless (not hand-derived): a jump command held only through PREJUMP_*'s
## own window-3 lead-in (see character_a.gd's _build_prejump) then released
## to neutral so the arc plays out uninterrupted (matching the existing
## neutral-jump reachability test's shape, test_command_recognition.gd).
##
## Run:  godot --headless --path game -s res://tests/test_airborne_actions.gd
## Exits non-zero on any failure so a harness/CI can gate on it.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	ProjectileRegistry.clear()
	if _failures == 0:
		print("[test_airborne_actions] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_airborne_actions] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	_test_forward_jump_reaches_prejump_f_then_jump_f_and_carries_forward()
	_test_back_jump_reaches_prejump_b_then_jump_b_and_carries_back()
	_test_neutral_jump_reaches_jump_n_and_lands_flush()
	_test_mid_jump_button_reaches_matching_air_normal()
	# TKT-P1.1R3-02 (AD-042, re-gate-4 E2) — widened coverage the isolated R2
	# per-direction test omits (it releases the jump direction after 3 ticks, so
	# it never reproduces a HELD/repeated jump's transition-frame-loss drift).
	_test_held_up_repeated_jumps_land_flush_no_cumulative_drift()
	_test_held_forward_repeated_jumps_land_flush_no_cumulative_drift()
	_test_held_back_repeated_jumps_land_flush_no_cumulative_drift()
	_test_air_normal_interrupted_jump_lands_flush()


func _roster() -> Dictionary:
	return {CharacterA.CHAR_ID: CharacterA.build_character()}


# ---------------------------------------------------------------------------
# Forward jump (numpad 9 = UP|FORWARD): PREJUMP_F -> JUMP_F, pos_x carries
# forward (AD-039).
# ---------------------------------------------------------------------------

func _test_forward_jump_reaches_prejump_f_then_jump_f_and_carries_forward() -> void:
	# Hold 9 for 3 ticks (through PREJUMP_F's own window-3 ALWAYS cancel, which
	# needs no continued input), then release to neutral so JUMP_F's gravity-
	# driven flight plays out uninterrupted rather than re-triggering another
	# prejump once it lands (a held direction would re-satisfy the same
	# button_map entry there — not this test's concern).
	var rows: Array[Dictionary] = TraceHarness.run("9*3 5*50", "", 48, _roster(), CharacterA.CHAR_ID)
	_true(TraceHarness.check(rows, 1, "p0.state", CharacterA.STATE_PREJUMP_F),
		"holding 9 (up+forward) enters STATE_PREJUMP_F")
	_true(TraceHarness.check(rows, 3, "p0.state", CharacterA.STATE_JUMP_F),
		"PREJUMP_F's ALWAYS cancel carries into STATE_JUMP_F")
	_true(TraceHarness.check(rows, 3, "p0.cat", MoveState.CATEGORY_AIRBORNE),
		"STATE_JUMP_F is category AIRBORNE")
	var pre_jump: Dictionary = TraceHarness.row_at(rows, 2)
	var mid_arc: Dictionary = TraceHarness.row_at(rows, 20)
	_true(int(mid_arc["p0.px"]) > int(pre_jump["p0.px"]),
		"pos_x carries FORWARD (increases) during the forward jump arc")
	# TKT-P2-01 (AD-043, re-baselined): the forward jump shares the SAME
	# takeoff-impulse + gravity vertical profile as the neutral jump — only
	# motion_vel_x differs by direction — so it lands via the SAME continuous
	# clamp, on the SAME tick (45; see the held-jump tests' cycle-arithmetic
	# note for how this tick was derived by actual headless replay).
	_true(TraceHarness.check(rows, 45, "p0.state", CharacterA.STATE_IDLE),
		"the forward jump's continuous clamp lands it into STATE_IDLE at tick 45")
	_true(TraceHarness.check(rows, 45, "p0.py", 0),
		"the forward jump lands flush at ground_y (tick 45)")
	_true(TraceHarness.check(rows, 48, "p0.state", CharacterA.STATE_IDLE),
		"still idle at tick 48 (no re-trigger — input was released to neutral)")
	MoveRegistry.clear()


# ---------------------------------------------------------------------------
# Back jump (numpad 7 = UP|BACK): PREJUMP_B -> JUMP_B, pos_x carries back
# (AD-039).
# ---------------------------------------------------------------------------

func _test_back_jump_reaches_prejump_b_then_jump_b_and_carries_back() -> void:
	var rows: Array[Dictionary] = TraceHarness.run("7*3 5*50", "", 48, _roster(), CharacterA.CHAR_ID)
	_true(TraceHarness.check(rows, 1, "p0.state", CharacterA.STATE_PREJUMP_B),
		"holding 7 (up+back) enters STATE_PREJUMP_B")
	_true(TraceHarness.check(rows, 3, "p0.state", CharacterA.STATE_JUMP_B),
		"PREJUMP_B's ALWAYS cancel carries into STATE_JUMP_B")
	_true(TraceHarness.check(rows, 3, "p0.cat", MoveState.CATEGORY_AIRBORNE),
		"STATE_JUMP_B is category AIRBORNE")
	var pre_jump: Dictionary = TraceHarness.row_at(rows, 2)
	var mid_arc: Dictionary = TraceHarness.row_at(rows, 20)
	_true(int(mid_arc["p0.px"]) < int(pre_jump["p0.px"]),
		"pos_x carries BACK (decreases) during the back jump arc")
	# TKT-P2-01 (AD-043, re-baselined): same takeoff-impulse + gravity vertical
	# profile as JUMP_N/JUMP_F — lands via the same continuous clamp at tick 45.
	_true(TraceHarness.check(rows, 45, "p0.state", CharacterA.STATE_IDLE),
		"the back jump's continuous clamp lands it into STATE_IDLE at tick 45")
	_true(TraceHarness.check(rows, 45, "p0.py", 0),
		"the back jump lands flush at ground_y (tick 45)")
	_true(TraceHarness.check(rows, 48, "p0.state", CharacterA.STATE_IDLE),
		"still idle at tick 48 (no re-trigger — input was released to neutral)")
	MoveRegistry.clear()


# ---------------------------------------------------------------------------
# Neutral jump (numpad 8 = UP): STATE_PREJUMP -> STATE_JUMP_N, no horizontal
# carry, and gravity + the continuous clamp land it flush at ground_y (AD-043,
# TKT-P2-01 -- supersedes the prior authored net-zero arc, JC-047).
# ---------------------------------------------------------------------------

func _test_neutral_jump_reaches_jump_n_and_lands_flush() -> void:
	var rows: Array[Dictionary] = TraceHarness.run("8*3 5*50", "", 48, _roster(), CharacterA.CHAR_ID)
	_true(TraceHarness.check(rows, 1, "p0.state", CharacterA.STATE_PREJUMP),
		"holding 8 (up, neutral) enters the neutral STATE_PREJUMP")
	_true(TraceHarness.check(rows, 3, "p0.state", CharacterA.STATE_JUMP_N),
		"the neutral prejump's ALWAYS cancel carries into STATE_JUMP_N")
	_true(TraceHarness.check(rows, 3, "p0.cat", MoveState.CATEGORY_AIRBORNE),
		"STATE_JUMP_N is category AIRBORNE")
	# Released to neutral after tick 3, so no re-triggered prejump. The takeoff
	# impulse (-22.0 units) + gravity (1.0/tick) nets the discrete integration
	# back to ground_y exactly 43 ticks after JUMP_N is entered (tick 3), so the
	# continuous clamp lands the character into STATE_IDLE at tick 45 — derived
	# by actual headless replay (see the held-jump tests' cycle-arithmetic note).
	_true(TraceHarness.check(rows, 45, "p0.state", CharacterA.STATE_IDLE),
		"the neutral jump's continuous clamp lands it into STATE_IDLE at tick 45")
	_true(TraceHarness.check(rows, 45, "p0.py", 0),
		"the neutral jump lands EXACTLY flush at ground_y (tick 45)")
	_true(TraceHarness.check(rows, 48, "p0.state", CharacterA.STATE_IDLE),
		"still idle at tick 48 (no re-trigger — input was released to neutral)")
	var pre_jump: Dictionary = TraceHarness.row_at(rows, 2)
	var landed: Dictionary = TraceHarness.row_at(rows, 45)
	_eq(int(landed["p0.px"]), int(pre_jump["p0.px"]),
		"the neutral jump carries NO horizontal displacement (nets zero, no forward/back drift)")
	MoveRegistry.clear()


# ---------------------------------------------------------------------------
# A button pressed mid-jump enters the matching air normal (category
# AIRBORNE, reachable) — AD-039's jump-state-cancel mechanism, for all three
# buttons.
# ---------------------------------------------------------------------------

func _test_mid_jump_button_reaches_matching_air_normal() -> void:
	var cases := [
		["L", CharacterA.STATE_JL],
		["M", CharacterA.STATE_JM],
		["H", CharacterA.STATE_JH],
	]
	for c in cases:
		var button: String = c[0]
		var target_state: int = c[1]
		# 9*3 (forward prejump->jump_f, tick3) 5*10 (mid-arc, well inside the
		# air-normal cancel window [1, JUMP_DURATION-1]) then one tick of the
		# button (tick 14) -- verified by direct replay this fires the cancel
		# on that exact tick (CancelEval evaluates same-tick).
		var rows: Array[Dictionary] = TraceHarness.run(
			"9*3 5*10 %s*1 5*20" % button, "", 24, _roster(), CharacterA.CHAR_ID)
		_true(TraceHarness.check(rows, 14, "p0.state", target_state),
			"pressing %s mid-jump cancels JUMP_F into STATE %d" % [button, target_state])
		_true(TraceHarness.check(rows, 14, "p0.cat", MoveState.CATEGORY_AIRBORNE),
			"the reached air normal (%s) is category AIRBORNE" % button)
		MoveRegistry.clear()


# ---------------------------------------------------------------------------
# TKT-P2-01 (AD-043) — RE-BASELINED for the gravity model (JC-017-style
# deliberate re-baseline; the ticket's checkpoint names this explicitly). Held/
# repeated jumps must not drift; the exact tick numbers below were derived by
# ACTUALLY REPLAYING headless against the new engine (a `TraceHarness` probe
# dumping state/py/vy every tick — the same methodology this file's other
# tests already use), not hand-computed.
#
# Cycle arithmetic under the gravity model. PREJUMP*'s ALWAYS cancel still
# fires on frame 3 (2 ticks after entry) into JUMP_*, but JUMP_*'s own
# `duration` (50) is now a generous SAFETY BOUND, not the flight time itself
# (AD-043 — the continuous `pos_y >= ground_y` clamp is what actually ends the
# jump, in phase 3, well before the state's own duration/actionability would).
# Given TAKEOFF_SPEED=22.0 / gravity=1.0 (character_a.gd, logged in
# judgment-log.md), the discrete integration nets exactly back to ground_y 43
# ticks after JUMP_* is entered — landing INTO IDLE for exactly one tick (the
# clamp transitions AIRBORNE -> GROUNDED to idle, AD-043), after which idle (a
# `loop` state, AD-038) re-derives from the still-held jump direction on the
# VERY NEXT tick and re-enters PREJUMP*. This is a genuine, deliberate
# behavioral change from the pre-P2 model (which, coincidentally, had
# `duration` tuned to exactly match the authored net-zero arc's length, so a
# held direction's actionable-buffered-command transition fired the SAME tick
# as the arc's last frame, skipping idle entirely — see JC-017-archived
# reasoning). Under gravity, "how long the jump lasts" is a physical outcome,
# not an authored constant, so it can no longer coincide with `duration` by
# construction — one settled IDLE tick between landing and re-jump is the
# correct, expected shape now, not a bug.
#
# So each full PREJUMP*-entry -> PREJUMP*-re-entry cycle is exactly 45 ticks
# (2 grounded prejump ticks + 43 airborne flight ticks): landing (IDLE) at
# ticks 45, 90, 135; PREJUMP* re-entry the tick immediately after, at ticks 46,
# 91, 136 (1 + 45*n). `p0.py` reads flush (0) at every one of these ticks —
# NO cumulative drift, matching the old test's intent under the new mechanism.
# ---------------------------------------------------------------------------

func _test_held_up_repeated_jumps_land_flush_no_cumulative_drift() -> void:
	var rows: Array[Dictionary] = TraceHarness.run("8*141", "", 141, _roster(), CharacterA.CHAR_ID)
	_true(TraceHarness.check(rows, 1, "p0.state", CharacterA.STATE_PREJUMP),
		"tick 1: holding 8 enters STATE_PREJUMP (first cycle)")
	_true(TraceHarness.check(rows, 45, "p0.state", CharacterA.STATE_IDLE),
		"tick 45: the FIRST held jump's continuous clamp lands it into STATE_IDLE (AD-043)")
	_true(TraceHarness.check(rows, 45, "p0.py", 0),
		"tick 45 lands FLUSH after 1 completed held jump")
	_true(TraceHarness.check(rows, 46, "p0.state", CharacterA.STATE_PREJUMP),
		"tick 46: idle re-derives the still-held jump direction and re-enters STATE_PREJUMP the very next tick (AD-038)")
	_true(TraceHarness.check(rows, 46, "p0.py", 0),
		"tick 46 still flush")
	_true(TraceHarness.check(rows, 90, "p0.state", CharacterA.STATE_IDLE),
		"tick 90: the SECOND held jump lands into STATE_IDLE")
	_true(TraceHarness.check(rows, 90, "p0.py", 0),
		"tick 90 lands FLUSH after 2 completed held jumps -- no cumulative drift")
	_true(TraceHarness.check(rows, 91, "p0.state", CharacterA.STATE_PREJUMP),
		"tick 91: re-enters STATE_PREJUMP for the third cycle")
	_true(TraceHarness.check(rows, 135, "p0.state", CharacterA.STATE_IDLE),
		"tick 135: the THIRD held jump lands into STATE_IDLE")
	_true(TraceHarness.check(rows, 135, "p0.py", 0),
		"tick 135 lands FLUSH after 3 completed held jumps -- NO cumulative drift")
	_true(TraceHarness.check(rows, 136, "p0.state", CharacterA.STATE_PREJUMP),
		"tick 136: re-enters STATE_PREJUMP for the fourth cycle")
	MoveRegistry.clear()


func _test_held_forward_repeated_jumps_land_flush_no_cumulative_drift() -> void:
	var rows: Array[Dictionary] = TraceHarness.run("9*141", "", 141, _roster(), CharacterA.CHAR_ID)
	_true(TraceHarness.check(rows, 1, "p0.state", CharacterA.STATE_PREJUMP_F),
		"tick 1: holding 9 (forward jump) enters STATE_PREJUMP_F")
	_true(TraceHarness.check(rows, 45, "p0.py", 0),
		"tick 45 (forward jump) lands FLUSH after 1 completed held jump")
	_true(TraceHarness.check(rows, 46, "p0.state", CharacterA.STATE_PREJUMP_F),
		"tick 46: re-enters STATE_PREJUMP_F the tick after landing")
	_true(TraceHarness.check(rows, 90, "p0.py", 0),
		"tick 90 (forward jump) lands FLUSH after 2 completed held jumps -- no cumulative vertical drift")
	_true(TraceHarness.check(rows, 135, "p0.py", 0),
		"tick 135 (forward jump) lands FLUSH after 3 completed held jumps -- no cumulative vertical drift")
	MoveRegistry.clear()


func _test_held_back_repeated_jumps_land_flush_no_cumulative_drift() -> void:
	var rows: Array[Dictionary] = TraceHarness.run("7*141", "", 141, _roster(), CharacterA.CHAR_ID)
	_true(TraceHarness.check(rows, 1, "p0.state", CharacterA.STATE_PREJUMP_B),
		"tick 1: holding 7 (back jump) enters STATE_PREJUMP_B")
	_true(TraceHarness.check(rows, 45, "p0.py", 0),
		"tick 45 (back jump) lands FLUSH after 1 completed held jump")
	_true(TraceHarness.check(rows, 46, "p0.state", CharacterA.STATE_PREJUMP_B),
		"tick 46: re-enters STATE_PREJUMP_B the tick after landing")
	_true(TraceHarness.check(rows, 90, "p0.py", 0),
		"tick 90 (back jump) lands FLUSH after 2 completed held jumps -- no cumulative vertical drift")
	_true(TraceHarness.check(rows, 135, "p0.py", 0),
		"tick 135 (back jump) lands FLUSH after 3 completed held jumps -- no cumulative vertical drift")
	MoveRegistry.clear()


# ---------------------------------------------------------------------------
# TKT-P1.1R3-02 (AD-042) — the D3 side effect: an air-normal-interrupted jump
# (JUMP_F cut short by a mid-air L, mirroring
# _test_mid_jump_button_reaches_matching_air_normal's script) lands FLUSH.
#
# SUPERSEDED 2026-07-17 (flags.md, "AD-043 air-move semantics", a false-green):
# the PRIOR version of this test asserted landing at tick 24 — the tick j.L's
# OLD short authored `duration` (startup+active alone) expired — via the AD-042
# grounded-entry snap. That snap-on-duration-expiry WAS the "air normal snaps
# to the floor" defect this ticket exists to fix (the character was still
# genuinely airborne at tick 24, per `p0.py` mid-flight the ticks just before
# it — the "flush landing" this test celebrated was a teleport, not physics).
# TKT-P2-01/AD-043's continuous ground clamp is now what actually lands j.L (a
# safety-tail duration keeps the once-through-ended path from racing it — see
# character_a.gd's `_build_air_normal`), and it does so LATER, at the REAL
# physical landing tick (45, discovered via headless replay against this exact
# script, matching this tree's established methodology) — still flush at
# ground_y, but via genuine integration, not a duration-based snap. The AD-042
# grounded-entry snap itself is UNCHANGED and stays live as a defensive
# backstop for other paths (see `StepPhases._enter_state`'s own doc comment);
# this test now demonstrates the CONTINUOUS CLAMP is what actually resolves
# this case, by showing j.L is STILL genuinely airborne at the tick that used
# to be the (wrong) landing tick.
# ---------------------------------------------------------------------------

func _test_air_normal_interrupted_jump_lands_flush() -> void:
	var rows: Array[Dictionary] = TraceHarness.run("9*3 5*10 L*1 5*20", "", 50, _roster(), CharacterA.CHAR_ID)
	_true(TraceHarness.check(rows, 14, "p0.state", CharacterA.STATE_JL),
		"L mid-jump cancels JUMP_F into STATE_JL (unchanged reachability)")
	_true(TraceHarness.check(rows, 24, "p0.state", CharacterA.STATE_JL),
		"tick 24 (j.L's OLD short authored duration) -- j.L is STILL genuinely airborne here, not " +
		"snapped to idle: the fix carries the fall past the move's own short active window")
	var py_at_24: int = TraceHarness.row_at(rows, 24)["p0.py"]
	_true(py_at_24 < 0, "j.L's height at tick 24 is genuinely negative (still above ground_y) -- a real mid-flight position, not a teleport")
	_true(TraceHarness.check(rows, 45, "p0.state", CharacterA.STATE_IDLE),
		"the air-normal-interrupted jump lands (returns to idle) at its REAL physical landing tick (45)")
	_true(TraceHarness.check(rows, 45, "p0.py", 0),
		"the landing is flush at ground_y -- via the AD-043 continuous ground clamp's genuine physics, not a duration-based snap")
	MoveRegistry.clear()
