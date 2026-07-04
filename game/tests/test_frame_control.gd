extends SceneTree

## Headless test for frame control (TKT-P1-02): set_paused / is_paused / step_once
## on TickHost. training-mode.md criteria 1 (frame-step) and 2 (pause/resume).
## AD-010 (frame-step crosses hitstop one tick per call).
##
## Run:  godot --headless --path game -s res://tests/test_frame_control.gd
## Exits non-zero on any failure so a harness/CI can gate on it.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	if _failures == 0:
		print("[test_frame_control] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_frame_control] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	_test_pause_halts_advancement()
	_test_resume_continues_deterministically()
	_test_step_once_advances_exactly_one_tick()
	_test_step_once_crosses_hitstop_one_tick_per_call()


## Builds a host with LocalDeviceSources, PRE-PRODUCING enough frames (input.md
## "produce-before-query" — a source must produce frame N before the sim requests
## it) so a caller can freely call step_once()/​_physics_process() up to
## `pre_produced` times without a future-read violation.
func _make_host(pre_produced: int = 32) -> TickHost:
	var host := TickHost.new()
	var state := SimState.new_initial()
	var src1 := LocalDeviceSource.new()
	var src2 := LocalDeviceSource.new()
	for _k in range(pre_produced):
		src1.sample_next()
		src2.sample_next()
	host.setup(state, src1, src2)
	return host


# --- criterion 2: pause/resume -----------------------------------------------

func _test_pause_halts_advancement() -> void:
	var host := _make_host()
	_true(not host.is_paused(), "a fresh host is not paused (running by default)")
	host.set_paused(true)
	_true(host.is_paused(), "is_paused reflects set_paused(true)")
	var before: int = host.current_tick()
	# _physics_process must not advance while paused, regardless of delta.
	host._physics_process(0.016)
	host._physics_process(1.0)
	_eq(host.current_tick(), before, "paused sim does not advance via _physics_process")
	host.free()


func _test_resume_continues_deterministically() -> void:
	# training-mode.md criterion 2: "resuming continues deterministically (resumed
	# run hashes match an uninterrupted run)." Compare a run interrupted by a pause
	# against an uninterrupted uninterrupted run over the same fixed input stream.
	var in_p1 := PackedInt32Array([InputFrame.RIGHT, InputFrame.RIGHT, InputFrame.NEUTRAL,
		InputFrame.LEFT, InputFrame.NEUTRAL, InputFrame.UP, InputFrame.NEUTRAL, InputFrame.NEUTRAL])
	var in_p2 := PackedInt32Array([InputFrame.LEFT, InputFrame.NEUTRAL, InputFrame.NEUTRAL,
		InputFrame.RIGHT, InputFrame.NEUTRAL, InputFrame.NEUTRAL, InputFrame.NEUTRAL, InputFrame.NEUTRAL])

	# Uninterrupted: run all 8 ticks straight through via SimHarness (the same pure
	# step the host uses).
	var uninterrupted: SimState = SimHarness.run_replay(SimState.new_initial(), in_p1, in_p2)
	var uninterrupted_hash: int = uninterrupted.hash_state()

	# Interrupted: a host running the SAME stream via ReplaySource, paused partway
	# through, then resumed to completion.
	var host := TickHost.new()
	var src1 := ReplaySource.new(in_p1)
	var src2 := ReplaySource.new(in_p2)
	host.setup(SimState.new_initial(), src1, src2)

	for _k in range(3):
		host.step_once()
	host.set_paused(true)
	# Paused: advancing physics_process must not progress the sim.
	host._physics_process(0.016)
	host._physics_process(0.5)
	host.set_paused(false)
	for _k in range(5):
		host.step_once()

	_eq(host.get_state().hash_state(), uninterrupted_hash,
		"a run interrupted by pause/resume hashes identically to an uninterrupted run")
	host.free()


# --- criterion 1: frame-step --------------------------------------------------

func _test_step_once_advances_exactly_one_tick() -> void:
	var host := _make_host()
	host.set_paused(true)
	var before: int = host.current_tick()
	host.step_once()
	_eq(host.current_tick(), before + 1, "step_once advances exactly one tick")
	host.step_once()
	_eq(host.current_tick(), before + 2, "a second step_once advances exactly one more tick")
	# State is inspectable at each step (through the read-only surface).
	var view := InspectionView.new(host.get_state())
	_eq(view.tick(), before + 2, "InspectionView reads the post-step tick")
	host.free()


func _test_step_once_crosses_hitstop_one_tick_per_call() -> void:
	# AD-010 / training-mode.md criterion 1: "stepping crosses hitstop one tick per
	# call" — hitstop is in-state countdown, not a loop pause; step_once must not
	# special-case it or get "stuck." Drive LIGHT to connect (hitstop=8 on both
	# parties per TestSupport), then single-step through the freeze and confirm the
	# tick advances by exactly one each call while hitstop counts down.
	MoveRegistry.install(TestSupport.build_roster())
	var host := TickHost.new()
	var state := SimState.new_initial()
	state.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	state.players[0].character_id = TestSupport.CHAR_ID
	state.players[0].state_id = TestSupport.STATE_LIGHT
	state.players[0].frame_in_state = 0
	state.players[0].pos_x = FP.from_int(0)
	state.players[0].facing = 1
	state.players[1].character_id = TestSupport.CHAR_ID
	state.players[1].state_id = TestSupport.STATE_IDLE
	state.players[1].pos_x = FP.from_int(40)
	state.players[1].facing = -1
	var src1 := LocalDeviceSource.new()
	var src2 := LocalDeviceSource.new()
	host.setup(state, src1, src2)
	host.set_paused(true)

	# Step until the hit connects (both enter hitstop).
	var connected: bool = false
	for _k in range(10):
		src1.sample_next()
		src2.sample_next()
		host.step_once()
		if host.get_state().players[0].hitstop > 0:
			connected = true
			break
	_true(connected, "LIGHT connected and both parties entered hitstop")

	var hitstop_at_connect: int = host.get_state().players[0].hitstop
	_true(hitstop_at_connect > 0, "attacker has nonzero hitstop after the connect")

	# Single-step through the freeze: each step_once advances the TICK by one, and
	# hitstop counts down by exactly one per call (crosses hitstop one tick per call
	# — it does not jump past the freeze or refuse to advance).
	var prev_tick: int = host.current_tick()
	var prev_hitstop: int = hitstop_at_connect
	for _k in range(hitstop_at_connect):
		src1.sample_next()
		src2.sample_next()
		host.step_once()
		_eq(host.current_tick(), prev_tick + 1, "step_once crosses a hitstop tick advancing exactly one tick")
		_eq(host.get_state().players[0].hitstop, prev_hitstop - 1,
			"hitstop counts down by exactly one per step_once call")
		prev_tick = host.current_tick()
		prev_hitstop = host.get_state().players[0].hitstop
	_eq(host.get_state().players[0].hitstop, 0, "hitstop fully elapsed after stepping through it")

	host.free()
	MoveRegistry.clear()
