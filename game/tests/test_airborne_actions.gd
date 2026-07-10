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
