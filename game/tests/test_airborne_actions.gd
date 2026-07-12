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
	# needs no continued input), then release to neutral so JUMP_F's 45-frame
	# arc plays out uninterrupted rather than re-triggering another prejump on
	# its own final actionable frame (a held direction would re-satisfy the
	# same button_map entry there — not this test's concern).
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
	# TKT-P1.1R2-02 (D2 regression guard): the forward arc shares the SAME
	# net-zero vel_y profile as the neutral jump (JC-047) — only motion_vel_x
	# differs by direction (re-gate-3 D2 refutation). Assert it lands flush
	# too, mirroring the neutral-jump test's shape, so a future edit that
	# de-syncs JUMP_F's vertical profile from JUMP_N's is caught.
	_true(TraceHarness.check(rows, 48, "p0.state", CharacterA.STATE_IDLE),
		"the forward jump arc completes and returns to STATE_IDLE")
	_true(TraceHarness.check(rows, 48, "p0.py", 0),
		"the forward jump arc nets EXACTLY zero vertical displacement -- lands flush at ground_y (D2 guard)")
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
	# TKT-P1.1R2-02 (D2 regression guard): same net-zero vel_y profile as
	# JUMP_N/JUMP_F (JC-047) — assert the back jump lands flush too.
	_true(TraceHarness.check(rows, 48, "p0.state", CharacterA.STATE_IDLE),
		"the back jump arc completes and returns to STATE_IDLE")
	_true(TraceHarness.check(rows, 48, "p0.py", 0),
		"the back jump arc nets EXACTLY zero vertical displacement -- lands flush at ground_y (D2 guard)")
	MoveRegistry.clear()


# ---------------------------------------------------------------------------
# Neutral jump (numpad 8 = UP): STATE_PREJUMP -> STATE_JUMP_N, no horizontal
# carry, and the arc still lands flush (pos_y returns to ground_y — JC-047).
# ---------------------------------------------------------------------------

func _test_neutral_jump_reaches_jump_n_and_lands_flush() -> void:
	var rows: Array[Dictionary] = TraceHarness.run("8*3 5*50", "", 48, _roster(), CharacterA.CHAR_ID)
	_true(TraceHarness.check(rows, 1, "p0.state", CharacterA.STATE_PREJUMP),
		"holding 8 (up, neutral) enters the neutral STATE_PREJUMP")
	_true(TraceHarness.check(rows, 3, "p0.state", CharacterA.STATE_JUMP_N),
		"the neutral prejump's ALWAYS cancel carries into STATE_JUMP_N")
	_true(TraceHarness.check(rows, 3, "p0.cat", MoveState.CATEGORY_AIRBORNE),
		"STATE_JUMP_N is category AIRBORNE")
	# The full 45-frame arc plays out (released to neutral after tick 3, so no
	# re-triggered prejump); the character returns to idle at ground_y (0, the
	# SimState.new_initial()/StageState default) — a flush landing, not the
	# pre-JC-047 floor-sink drift.
	_true(TraceHarness.check(rows, 48, "p0.state", CharacterA.STATE_IDLE),
		"the neutral jump arc completes and returns to STATE_IDLE")
	_true(TraceHarness.check(rows, 48, "p0.py", 0),
		"the neutral jump arc nets EXACTLY zero vertical displacement -- lands flush at ground_y (JC-047)")
	var pre_jump: Dictionary = TraceHarness.row_at(rows, 2)
	var landed: Dictionary = TraceHarness.row_at(rows, 48)
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
# TKT-P1.1R3-02 (AD-042, re-gate-4 E2) — held/repeated jumps must not drift.
#
# Root cause (E2 diagnosis): a HELD jump direction reaches the jump's `duration`
# frame and transitions straight back into a grounded state (once-through-move-
# ended -> idle -> SAME-TICK re-derive of the still-held direction -> prejump,
# AD-038) with no settled idle tick in between -- silently dropping the arc's
# final fall frame. Each held/back-to-back jump therefore nets -6 (upward, since
# rising is -Y) instead of 0. The isolated per-direction test (TKT-P1.1R2-02)
# releases the direction after 3 ticks, so it never reaches this transition and
# never reproduces the drift.
#
# Cycle arithmetic (derived by ACTUALLY REPLAYING headless, not hand-derived —
# see the judgment-log entry for the exact off-by-one this uncovered). Holding
# a jump direction continuously, each PREJUMP*/JUMP* cycle is exactly 46
# ticks: PREJUMP*'s ALWAYS cancel fires on frame 3 (2 ticks after entry) into
# the JUMP_*'s 45-frame arc; a HELD jump direction makes `JUMP_*` exit one tick
# BEFORE its own once-through-ended check would fire, because Actionability.
# is_actionable treats a committed move as actionable once `frame_in_state >=
# duration` (JC-011/038's documented off-by-one straddle: actionable at `==
# duration`, "ended" only at `> duration`) — so on the arc's OWN last frame
# (frame_in_state == duration == 45) the still-held direction's DISCRETE
# buffered command (PREJUMP*, a non-loop target) already fires via the plain
# actionable-buffered-command branch, transitioning JUMP_* -> PREJUMP*
# directly and skipping idle AND that final frame's own motion (phase 2 runs
# before phase 3, so the frame-45 fall keyframe is authored but never
# integrated) — the arc's dropped final frame the E2 diagnosis names. So
# consecutive PREJUMP*-reentry ticks are 1, 47, 93, 139, ... (1 + 46*(n-1));
# PREJUMP* then occupies TWO ticks (frames 1-2) before its own frame-3 cancel
# re-enters JUMP_*. Before the AD-042 fix, `p0.py` at the reentry ticks
# drifted 0, -6, -12, -18 (one FALL_SPEED unit lost per completed jump, never
# recovered -- the "+6 units upward per jump" the ticket names). After the
# fix, every GROUNDED-category entry (idle OR prejump) snaps pos_y back to
# ground_y (0), so these ticks read flush every time -- NO cumulative drift.
# ---------------------------------------------------------------------------

func _test_held_up_repeated_jumps_land_flush_no_cumulative_drift() -> void:
	var rows: Array[Dictionary] = TraceHarness.run("8*141", "", 141, _roster(), CharacterA.CHAR_ID)
	_true(TraceHarness.check(rows, 1, "p0.state", CharacterA.STATE_PREJUMP),
		"tick 1: holding 8 enters STATE_PREJUMP (first cycle)")
	_true(TraceHarness.check(rows, 47, "p0.state", CharacterA.STATE_PREJUMP),
		"tick 47: the FIRST held jump completes and re-enters STATE_PREJUMP the same tick (AD-038)")
	_true(TraceHarness.check(rows, 47, "p0.py", 0),
		"tick 47 lands FLUSH after 1 completed held jump (pre-fix: py=-6, E2 drift)")
	_true(TraceHarness.check(rows, 93, "p0.state", CharacterA.STATE_PREJUMP),
		"tick 93: the SECOND held jump completes and re-enters STATE_PREJUMP")
	_true(TraceHarness.check(rows, 93, "p0.py", 0),
		"tick 93 lands FLUSH after 2 completed held jumps (pre-fix: py=-12, cumulative E2 drift)")
	_true(TraceHarness.check(rows, 139, "p0.state", CharacterA.STATE_PREJUMP),
		"tick 139: the THIRD held jump completes and re-enters STATE_PREJUMP")
	_true(TraceHarness.check(rows, 139, "p0.py", 0),
		"tick 139 lands FLUSH after 3 completed held jumps (pre-fix: py=-18, cumulative E2 drift) -- NO cumulative drift")
	MoveRegistry.clear()


func _test_held_forward_repeated_jumps_land_flush_no_cumulative_drift() -> void:
	var rows: Array[Dictionary] = TraceHarness.run("9*141", "", 141, _roster(), CharacterA.CHAR_ID)
	_true(TraceHarness.check(rows, 1, "p0.state", CharacterA.STATE_PREJUMP_F),
		"tick 1: holding 9 (forward jump) enters STATE_PREJUMP_F")
	_true(TraceHarness.check(rows, 47, "p0.state", CharacterA.STATE_PREJUMP_F),
		"tick 47: the FIRST held forward jump completes and re-enters STATE_PREJUMP_F")
	_true(TraceHarness.check(rows, 47, "p0.py", 0),
		"tick 47 (forward jump) lands FLUSH after 1 completed held jump")
	_true(TraceHarness.check(rows, 93, "p0.py", 0),
		"tick 93 (forward jump) lands FLUSH after 2 completed held jumps -- no cumulative vertical drift")
	_true(TraceHarness.check(rows, 139, "p0.py", 0),
		"tick 139 (forward jump) lands FLUSH after 3 completed held jumps -- no cumulative vertical drift")
	MoveRegistry.clear()


func _test_held_back_repeated_jumps_land_flush_no_cumulative_drift() -> void:
	var rows: Array[Dictionary] = TraceHarness.run("7*141", "", 141, _roster(), CharacterA.CHAR_ID)
	_true(TraceHarness.check(rows, 1, "p0.state", CharacterA.STATE_PREJUMP_B),
		"tick 1: holding 7 (back jump) enters STATE_PREJUMP_B")
	_true(TraceHarness.check(rows, 47, "p0.state", CharacterA.STATE_PREJUMP_B),
		"tick 47: the FIRST held back jump completes and re-enters STATE_PREJUMP_B")
	_true(TraceHarness.check(rows, 47, "p0.py", 0),
		"tick 47 (back jump) lands FLUSH after 1 completed held jump")
	_true(TraceHarness.check(rows, 93, "p0.py", 0),
		"tick 93 (back jump) lands FLUSH after 2 completed held jumps -- no cumulative vertical drift")
	_true(TraceHarness.check(rows, 139, "p0.py", 0),
		"tick 139 (back jump) lands FLUSH after 3 completed held jumps -- no cumulative vertical drift")
	MoveRegistry.clear()


# ---------------------------------------------------------------------------
# TKT-P1.1R3-02 (AD-042) — the D3 side effect: an air-normal-interrupted jump
# (JUMP_F cut short by a mid-air L, mirroring
# _test_mid_jump_button_reaches_matching_air_normal's script) now lands FLUSH
# once the air normal's active window ends and the once-through-move-ended
# transition returns to idle. Before AD-042 this was the re-gate-3 D3 aerial
# float (the arc's frozen mid-air height was never reconciled to the floor);
# the grounded-entry snap resolves it as an intended side effect (AD-042
# "Rejected (a)" / the ticket's "resolves re-gate-3 D3").
# ---------------------------------------------------------------------------

func _test_air_normal_interrupted_jump_lands_flush() -> void:
	var rows: Array[Dictionary] = TraceHarness.run("9*3 5*10 L*1 5*20", "", 26, _roster(), CharacterA.CHAR_ID)
	_true(TraceHarness.check(rows, 14, "p0.state", CharacterA.STATE_JL),
		"L mid-jump cancels JUMP_F into STATE_JL (unchanged reachability)")
	_true(TraceHarness.check(rows, 24, "p0.state", CharacterA.STATE_IDLE),
		"JL's active window ends and the once-through move returns to STATE_IDLE")
	_true(TraceHarness.check(rows, 24, "p0.py", 0),
		"the air-normal-interrupted jump now lands FLUSH at ground_y -- the AD-042 grounded-entry snap resolves the D3 aerial float")
	MoveRegistry.clear()
