extends SceneTree

## Headless test for throws + multi-hit / rehit (TKT-P0-09).
## combat-resolution.md criteria 9 (multi-hit), 10 (throws); move-format.md criterion 8
## (multi-hit forms). AD-016 (throw connect bypasses block, tech window, clash-to-tech;
## sequential multi-hit + cadenced rehit), AD-026 (active_hit_ids single-hit memory).
##
## Run:  godot --headless --path game -s res://tests/test_throws_multihit.gd
## Exits non-zero on any failure so a harness/CI can gate on it.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	if _failures == 0:
		print("[test_throws_multihit] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_throws_multihit] FAIL — %d of %d checks failed" % [_failures, _checks])
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
	_test_throw_bypasses_block()
	_test_throw_tech_to_neutral()
	_test_simultaneous_throw_clash()
	_test_sequential_multi_hit()
	_test_rehit_cadence()


# --- Scenario setup ---------------------------------------------------------

func _two_char_state(p1_units: int = 40) -> SimState:
	MoveRegistry.install(TestSupport.build_roster())
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = TestSupport.CHAR_ID
	s.players[0].state_id = TestSupport.STATE_IDLE
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = TestSupport.CHAR_ID
	s.players[1].state_id = TestSupport.STATE_IDLE
	s.players[1].pos_x = FP.from_int(p1_units)
	s.players[1].facing = -1
	return s


# --- Throws (crit 10) -------------------------------------------------------

func _test_throw_bypasses_block() -> void:
	# combat-resolution.md crit 10: a throw connects THROUGH block (bypasses blockstun).
	# P1 holds back (would block a strike); P0 throws. The throw connects regardless.
	# P0 faces +1; P1 faces -1, so P1 "back" = RIGHT (raw).
	var s := _two_char_state(40)
	var throw_cmd: int = InputFrame.BUTTON_2 | InputFrame.DOWN
	var p1_block: int = InputFrame.RIGHT
	s = SimState.step(s, throw_cmd, p1_block)
	var connected: bool = false
	for _k in range(6):
		if s.players[1].state_id == TestSupport.STATE_THROWN:
			connected = true
			break
		s = SimState.step(s, InputFrame.NEUTRAL, p1_block)
	_true(connected, "throw connects through block (bypasses blockstun, AD-016)")
	_eq(s.players[1].stun_kind, PlayerView.STUN_HIT, "thrown defender is in the throw reaction")
	_true(s.players[1].health < 1000, "throw dealt damage on connect")
	MoveRegistry.clear()


func _test_throw_tech_to_neutral() -> void:
	# crit 10: a defender throw input within the tech window techs the throw to neutral,
	# no damage. P0 throws P1; P1 techs by inputting a throw within the window.
	var s := _two_char_state(40)
	var throw_cmd: int = InputFrame.BUTTON_2 | InputFrame.DOWN
	# Tick 0: P0 throws; P1 also inputs a throw (a tech attempt within the window).
	s = SimState.step(s, throw_cmd, InputFrame.NEUTRAL)
	# Drive to the throw connect.
	for _k in range(6):
		if s.players[1].state_id == TestSupport.STATE_THROWN:
			break
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(s.players[1].state_id, TestSupport.STATE_THROWN, "throw connected (pre-tech)")
	var health_before_tech: int = s.players[1].health
	# P1 now inputs a throw within the tech window (P1 faces -1: DOWN + BUTTON_2 is the
	# throw command; direction gate for P1's THROW requires DOWN which is absolute).
	var teched: bool = false
	for _k in range(TestSupport.THROW_TECH_WINDOW + 2):
		s = SimState.step(s, InputFrame.NEUTRAL, throw_cmd)
		# A tech returns P1 to actionable (out of THROWN) with damage undone.
		if s.players[1].state_id == TestSupport.STATE_IDLE and s.players[1].stun == 0:
			teched = true
			break
	_true(teched, "defender throw within the tech window techs to neutral")
	_eq(s.players[1].health, 1000, "teched throw deals no damage (health restored)")
	MoveRegistry.clear()


func _test_simultaneous_throw_clash() -> void:
	# crit 10: simultaneous ground throws within the window clash to a tech — neither
	# lands, both stay actionable, no damage. Both input a throw on the same tick.
	#
	# F-011 lineage: asserting only "neither is THROWN / neither took damage" is also
	# true of throws that never connect at all (a broken button map, drifted throwbox
	# geometry, an accidental early return). This test therefore ALSO asserts positive
	# liveness: (a) both players actually entered STATE_THROW with their throwbox on its
	# authored active window (frames 1..3, TestSupport._build_throw) on the tick the
	# clash is checked, and (b) the clash path actually ran — `_resolve_throw_clash`
	# applies a deterministic symmetric pushback (step_phases.gd), so the players'
	# separation strictly increases from its pre-clash value. Without both of these, a
	# "neither thrown / no damage" reading would be indistinguishable from throws that
	# simply whiffed.
	var s := _two_char_state(40)
	var pre_clash_separation: int = absi(s.players[1].pos_x - s.players[0].pos_x)
	var throw_cmd0: int = InputFrame.BUTTON_2 | InputFrame.DOWN
	var throw_cmd1: int = InputFrame.BUTTON_2 | InputFrame.DOWN
	s = SimState.step(s, throw_cmd0, throw_cmd1)
	# Liveness: both players actually entered their THROW move (STATE_THROW) and their
	# throwbox is on its active window (frames 1..3) — i.e. the throws are live, not
	# whiffed or blocked by a button-map/geometry regression.
	_eq(s.players[0].state_id, TestSupport.STATE_THROW, "P0 entered STATE_THROW (live throw attempt)")
	_eq(s.players[1].state_id, TestSupport.STATE_THROW, "P1 entered STATE_THROW (live throw attempt)")
	_true(s.players[0].frame_in_state >= 1 and s.players[0].frame_in_state <= 3,
		"P0's throwbox is on its authored active window (frame 1..3)")
	_true(s.players[1].frame_in_state >= 1 and s.players[1].frame_in_state <= 3,
		"P1's throwbox is on its authored active window (frame 1..3)")
	# On the tick both throwboxes connect, the clash resolves: neither enters THROWN.
	var clashed: bool = false
	for _k in range(6):
		var p0_thrown: bool = s.players[0].state_id == TestSupport.STATE_THROWN
		var p1_thrown: bool = s.players[1].state_id == TestSupport.STATE_THROWN
		# A clash: NEITHER is thrown and NEITHER took damage.
		if not p0_thrown and not p1_thrown:
			clashed = true
		else:
			clashed = false
			break
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(clashed, "simultaneous throws clash to a tech (neither is thrown)")
	_eq(s.players[0].health, 1000, "no damage to P0 on a throw clash")
	_eq(s.players[1].health, 1000, "no damage to P1 on a throw clash")
	# Positive proof the clash path RAN (not just "throws never connected"):
	# `_resolve_throw_clash` (step_phases.gd) applies a deterministic symmetric pushback
	# once both throwboxes connect, so separation must have strictly increased.
	var post_clash_separation: int = absi(s.players[1].pos_x - s.players[0].pos_x)
	_true(post_clash_separation > pre_clash_separation,
		"clash applied symmetric pushback (proof _resolve_throw_clash executed, not a whiff)")
	MoveRegistry.clear()


# --- Multi-hit / rehit (crit 9; move-format crit 8) -------------------------

func _test_sequential_multi_hit() -> void:
	# crit 9: a sequential multi-hit (two DISTINCT id_groups across keyframes) lands each
	# hit once. P0's MULTI has group 10 (frames 2..3) and group 11 (frames 6..7). Over
	# the move, exactly TWO hits register (combo reaches 2), each dealing its damage once.
	var s := _two_char_state(40)
	s.players[0].state_id = TestSupport.STATE_MULTI
	# frame_in_state 0 so the first step's phase-2 advance puts it on frame 1 (the
	# character enters MULTI cleanly; see phase-2 advance: 0 -> 1).
	s.players[0].frame_in_state = 0
	var max_combo: int = 0
	for _k in range(20):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[1].combo_hits > max_combo:
			max_combo = s.players[1].combo_hits
	_eq(max_combo, 2, "sequential multi-hit (two id_groups) registers exactly TWO hits")
	MoveRegistry.clear()


func _test_rehit_cadence() -> void:
	# crit 9: a rehit_interval hitbox re-hits on its cadence and NOT between intervals.
	# REHIT is one id_group active frames 1..12 with rehit_interval 4. It hits on the
	# first active frame, then again only once 4 frames have elapsed. Count the distinct
	# hit ticks; they must be spaced by >= rehit_interval, and there must be MORE than one.
	var s := _two_char_state(40)
	s.players[0].state_id = TestSupport.STATE_REHIT
	s.players[0].frame_in_state = 0   # first step advances to frame 1 (clean enter)
	var hit_ticks: Array = []
	var last_combo: int = 0
	for _k in range(24):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[1].combo_hits > last_combo:
			hit_ticks.append(s.tick)
			last_combo = s.players[1].combo_hits
	_true(hit_ticks.size() >= 2, "rehit lands more than once (cadenced re-hit)")
	# Consecutive hits are spaced by at least rehit_interval (no hit between).
	var ok_spacing: bool = true
	for i in range(1, hit_ticks.size()):
		if hit_ticks[i] - hit_ticks[i - 1] < TestSupport.REHIT_INTERVAL:
			ok_spacing = false
	_true(ok_spacing, "consecutive rehits are spaced by >= rehit_interval (no hit between)")
	MoveRegistry.clear()
