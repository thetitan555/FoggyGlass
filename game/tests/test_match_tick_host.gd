extends SceneTree

## Headless test for MatchTickHost (TKT-P2-08 integration; mirrors
## test_tick_host.gd exactly, one level up over MatchState/match_step).
##
## Run:  godot --headless --path game -s res://tests/test_match_tick_host.gd
## Exits non-zero on any failure so a harness/CI can gate on it.
##
## SCOPE. Pins the same fixed-tick discipline TickHost's own test pins, over
## the match wrapper: (a) the clock reads from state (current_tick() ==
## match_state.sim.tick), (b) one _advance == exactly one tick, never scaled
## by delta, (c) a paused host advances 0 regardless of delta.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	if _failures == 0:
		print("[test_match_tick_host] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_match_tick_host] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _run() -> void:
	var host := MatchTickHost.new()

	var match_state := MatchState.new_match(TestSupport.CHAR_ID, TestSupport.CHAR_ID, 0)
	var src1 := LocalDeviceSource.new()   # null sampler -> samples NEUTRAL
	var src2 := LocalDeviceSource.new()
	host.setup(match_state, src1, src2)

	# (a) Clock reads from the wrapped sim's own tick, not any engine counter.
	_eq(host.current_tick(), 0, "current_tick reads match_state.sim.tick (0 at start)")
	_eq(host.get_match_state().sim.tick, 0, "get_match_state exposes the MatchState handle")

	# (b)/(c) One advance == exactly one tick, monotonic, delta-free. During
	# ROUND_START (this match's starting phase), match_step runs the phase_timer
	# beat WITHOUT advancing combat (match-flow.md) — but the wrapped sim's own
	# tick, which THIS host's clock reads, only moves once ACTIVE begins. Drive
	# past the whole ROUND_START beat first so the clock is observed actually
	# ticking (the same "one _advance == one host tick" claim, exercised where
	# it is visible).
	var prev: int = host.current_tick()
	for i in range(MatchState.ROUND_START_BEAT_TICKS):
		src1.sample_next()
		src2.sample_next()
		host._match_state = host._advance(host._match_state)
	_eq(host.get_match_state().match_phase, MatchState.PHASE_ACTIVE, "ROUND_START beat elapsed -> ACTIVE")
	_eq(host.current_tick(), 0, "sim.tick did not advance during the whole ROUND_START beat")

	prev = host.current_tick()
	for i in range(120):
		src1.sample_next()
		src2.sample_next()
		host._match_state = host._advance(host._match_state)
		var now: int = host.current_tick()
		_eq(now, prev + 1, "advance #%d yields exactly +1 tick" % (i + 1))
		prev = now
	_eq(host.current_tick(), 120, "120 ACTIVE advances from 0 -> tick 120 (no delta scaling)")

	# running=false halts advancement via _physics_process.
	host.running = false
	var frozen: int = host.current_tick()
	host._physics_process(0.016)
	host._physics_process(1.0)
	_eq(host.current_tick(), frozen, "paused host does not advance regardless of delta")

	# Resume: one physics_process == one tick.
	host.running = true
	src1.sample_next()
	src2.sample_next()
	host._physics_process(0.016)
	_eq(host.current_tick(), frozen + 1, "resumed host advances exactly one tick per physics_process")
	src1.sample_next()
	src2.sample_next()
	host._physics_process(9.999)
	_eq(host.current_tick(), frozen + 2, "huge delta still advances exactly one tick")

	# step_once mirrors TickHost's own (pause-driven manual advance).
	host.set_paused(true)
	_true_check(host.is_paused(), "set_paused(true) -> is_paused() true")
	var before_step: int = host.current_tick()
	src1.sample_next()
	src2.sample_next()
	host.step_once()
	_eq(host.current_tick(), before_step + 1, "step_once advances exactly one tick while paused")

	host.free()


func _true_check(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)
