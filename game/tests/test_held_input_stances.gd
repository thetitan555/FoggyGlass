extends SceneTree

## Headless test for TKT-P1.1R-03 (held-input stances — AD-038 loop-state
## re-derivation + the crouch pure-direction command). Serves AD-038, AD-032
## (the crouch entry half), combat-resolution.md phase 2, character-a.md
## Movement ("standing and crouching blocking").
##
## Movement scenarios (walk-forward/back enter+exit, crouch enter+exit) are
## driven through TraceHarness/InputScript (TKT-P1.1R-01) — the instrument the
## ticket names for exactly this shape of assertion. The crouch-BLOCK scenario
## is a hit-resolution check that needs precise attacker/defender proximity,
## which TraceHarness's fixed 200-unit two-idle-character spawn does not expose
## a hook for (trace-harness.md names no position-override contract) — that one
## scenario uses a direct SimState.step loop + InspectionView read, mirroring
## the rest of the combat suite's proximity-controlled hit tests (e.g.
## test_character_a.gd's `_two_char_state`). Recorded as a judgment call
## (docs/judgment-log.md).
##
## Run:  godot --headless --path game -s res://tests/test_held_input_stances.gd
## Exits non-zero on any failure so a harness/CI can gate on it.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	ProjectileRegistry.clear()
	if _failures == 0:
		print("[test_held_input_stances] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_held_input_stances] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	_test_walk_forward_enters_and_exits_on_release()
	_test_walk_back_enters_and_exits_on_release()
	_test_crouch_enters_and_exits_on_release()
	_test_crouch_hurtbox_resolves_while_crouching()
	_test_crouching_held_back_defender_blocks()


func _roster() -> Dictionary:
	return {CharacterA.CHAR_ID: CharacterA.build_character()}


# ---------------------------------------------------------------------------
# Walk forward: enters on held 6, returns to idle on release (AD-038).
# ---------------------------------------------------------------------------

func _test_walk_forward_enters_and_exits_on_release() -> void:
	# Hold RIGHT (forward for P1, who faces right) for 5 ticks, then release to
	# neutral for the rest. InputBuffer's COMMAND_BUFFER (6-frame) leniency means
	# the walk state keeps RE-SELECTING itself (a no-op transition, AD-038's own
	# "target == current, no-op" case) for as long as the released direction is
	# still within the last 6 raw frames — i.e. through tick (last_held + 6) = 11.
	# Tick 12 is the first tick whose 6-frame window contains no RIGHT frame.
	var rows: Array[Dictionary] = TraceHarness.run("6*5 5*10", "", 15, _roster(), CharacterA.CHAR_ID)
	_true(TraceHarness.check(rows, 5, "p0.state", CharacterA.STATE_WALK_F),
		"holding forward enters STATE_WALK_F while held")
	_true(TraceHarness.check(rows, 15, "p0.state", CharacterA.STATE_IDLE),
		"walk forward returns to STATE_IDLE once the release has cleared the command buffer")
	# Once idle, position stops changing tick over tick (no residual drift).
	var last: Dictionary = TraceHarness.row_at(rows, 15)
	var prev: Dictionary = TraceHarness.row_at(rows, 14)
	_eq(int(last["p0.px"]), int(prev["p0.px"]), "p0.px is stationary once walk has released to idle")
	MoveRegistry.clear()


# ---------------------------------------------------------------------------
# Walk back: enters on held 4, returns to idle on release (AD-038).
# ---------------------------------------------------------------------------

func _test_walk_back_enters_and_exits_on_release() -> void:
	var rows: Array[Dictionary] = TraceHarness.run("4*5 5*10", "", 15, _roster(), CharacterA.CHAR_ID)
	_true(TraceHarness.check(rows, 5, "p0.state", CharacterA.STATE_WALK_B),
		"holding back enters STATE_WALK_B while held")
	_true(TraceHarness.check(rows, 15, "p0.state", CharacterA.STATE_IDLE),
		"walk back returns to STATE_IDLE once the release has cleared the command buffer")
	MoveRegistry.clear()


# ---------------------------------------------------------------------------
# Crouch: enters on held 2, returns to stand (idle) on release (AD-038/AD-032).
# ---------------------------------------------------------------------------

func _test_crouch_enters_and_exits_on_release() -> void:
	var rows: Array[Dictionary] = TraceHarness.run("2*5 5*10", "", 15, _roster(), CharacterA.CHAR_ID)
	_true(TraceHarness.check(rows, 5, "p0.state", CharacterA.STATE_CROUCH),
		"holding down enters STATE_CROUCH while held")
	_true(TraceHarness.check(rows, 15, "p0.state", CharacterA.STATE_IDLE),
		"crouch returns to STATE_IDLE (stand) once the release has cleared the command buffer")
	MoveRegistry.clear()


## Crouch is not just a label — the crouching hurtbox (shorter than standing)
## actually resolves while the state is held (character-a.md Movement).
func _test_crouch_hurtbox_resolves_while_crouching() -> void:
	var rows: Array[Dictionary] = TraceHarness.run("2*5", "", 5, _roster(), CharacterA.CHAR_ID,
		{}, PackedStringArray(["boxes"]))
	var row: Dictionary = TraceHarness.row_at(rows, 5)
	var boxes: String = str(row.get("p0.boxes", ""))
	_true(boxes.find("HURT:") != -1, "a HURT box resolves while crouching")
	# The crouching hurtbox is authored shorter (h=55) than standing (h=80,
	# character_a.gd _hurt_crouch/_hurt_stand) — assert the shorter height shows
	# up in the resolved world-space box (fixed-point, FP.from_int(55)/(80)), not
	# the standing one.
	var crouch_h: String = str(FP.from_int(55))
	var stand_h: String = str(FP.from_int(80))
	_true(boxes.find("," + crouch_h) != -1,
		"the resolved crouch HURT box carries the shorter (h=55, fixed-point) crouching height")
	_true(boxes.find("," + stand_h) == -1,
		"the resolved crouch HURT box is NOT the standing (h=80, fixed-point) height")
	MoveRegistry.clear()


# ---------------------------------------------------------------------------
# Crouch block: a crouching, held-back defender blocks a hit (enters a
# blockstun category). Direct SimState.step + InspectionView (see header note
# on instrument choice) — mirrors test_character_a.gd's proximity pattern.
# ---------------------------------------------------------------------------

func _test_crouching_held_back_defender_blocks() -> void:
	MoveRegistry.install(_roster())
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = CharacterA.CHAR_ID
	s.players[0].state_id = CharacterA.STATE_IDLE
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = CharacterA.CHAR_ID
	s.players[1].state_id = CharacterA.STATE_CROUCH
	s.players[1].frame_in_state = 1
	s.players[1].pos_x = FP.from_int(45)   # in 5L's reach — mirrors the existing 5L-proximity gap
	s.players[1].facing = -1

	# P1 (defender) faces -1: "back" (the block direction) is RIGHT (mirrors
	# StepPhases.resolve_intent / the 5H-block test's own note). Combined with
	# DOWN so it is ALSO the crouch pure-direction command (AD-032/AD-038) — a
	# crouching defender who holds back the whole time.
	var p1_crouch_block: int = InputFrame.DOWN | InputFrame.RIGHT

	# Confirm the defender is actually in STATE_CROUCH going into the exchange
	# (not just labeled so — the state re-derivation (AD-038) keeps it there
	# every tick DOWN is held, including this first one).
	s = SimState.step(s, InputFrame.BUTTON_0, p1_crouch_block)   # P0: bare L -> STATE_5L
	_eq(s.players[0].state_id, CharacterA.STATE_5L, "P0's L input enters STATE_5L")
	_eq(s.players[1].state_id, CharacterA.STATE_CROUCH,
		"P1 stays in STATE_CROUCH the tick the attack starts (loop re-derivation, target==current)")

	var blocked: bool = false
	for _k in range(15):
		s = SimState.step(s, InputFrame.NEUTRAL, p1_crouch_block)
		if s.players[0].move_contact == PlayerState.CONTACT_BLOCK:
			blocked = true
			break
	_true(blocked, "5L connects as a BLOCK against the crouching held-back defender")

	var view := InspectionView.new(s, _roster())
	var p1_view: PlayerView = view.player(1)
	_eq(p1_view.stun_kind, PlayerView.STUN_BLOCK, "the defender's stun_kind reads BLOCK, not HIT")
	var character: Character = MoveRegistry.character(CharacterA.CHAR_ID)
	var reaction_move: MoveState = character.get_state(p1_view.state_id)
	_eq(reaction_move.category, MoveState.CATEGORY_BLOCKSTUN,
		"the defender's reaction state is a blockstun category (stance-agnostic hold-back block)")
	MoveRegistry.clear()
