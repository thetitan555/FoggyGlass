extends SceneTree

## Headless test for the fixed-tick host (TKT-P0-01, AD-004, simulation.md).
##
## Run:  godot --headless --path game -s res://tests/test_tick_host.gd
##
## SCOPE / HONESTY NOTE. simulation.md criterion 5 ("Tick authority: sim tick
## count derives from state.tick, not engine frame count; render rate changes do
## not change sim outcomes") is only FULLY verifiable once TKT-P0-03 lands a real
## SimState + pure `step` and a render loop exists to vary. What this test CAN
## pin now, and does:
##   (a) The host's clock is read from its state handle, not an engine counter —
##       set_state / current_tick prove the reads route through state.
##   (b) One `_advance` call == exactly one tick of progress, monotonic, never
##       scaled by anything (no delta enters the advance path at all).
##   (c) `_delta` is unused: advancing N times from a known state yields exactly
##       start+N regardless of any wall-clock between calls.
## The "render rate changes don't change outcomes" half is asserted by
## construction (the advance path takes no delta/frame-count input) and becomes
## an end-to-end check under QA's harness at 03/11. Called out so QA knows the
## boundary rather than assuming full coverage here.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	if _failures == 0:
		print("[test_tick_host] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_tick_host] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _run() -> void:
	var host := TickHost.new()

	# (a) Clock reads from state, not from any engine counter.
	host.set_state(0)
	_eq(host.current_tick(), 0, "current_tick reads state (0 after set_state 0)")
	host.set_state(500)
	_eq(host.current_tick(), 500, "current_tick reads state (500 after set_state 500)")

	# (b)/(c) One advance == exactly one tick, monotonic, delta-free.
	host.set_state(0)
	var prev: int = host.current_tick()
	for i in range(120):
		# Drive the same advance path _physics_process uses, directly, so no
		# render/wall-clock timing is involved — proving the advance takes none.
		host._sim_state = host._advance(host._sim_state)
		var now: int = host.current_tick()
		_eq(now, prev + 1, "advance #%d yields exactly +1 tick" % (i + 1))
		prev = now
	_eq(host.current_tick(), 120, "120 advances from 0 -> tick 120 (no delta scaling)")

	# running=false must halt advancement via _physics_process (pause is a host
	# concern, not a determinism one). Exercise the guard directly.
	host.running = false
	var frozen: int = host.current_tick()
	host._physics_process(0.016)   # delta value is irrelevant and ignored
	host._physics_process(1.0)     # even a huge delta must not advance while paused
	_eq(host.current_tick(), frozen, "paused host does not advance regardless of delta")

	host.running = true
	host._physics_process(0.016)
	_eq(host.current_tick(), frozen + 1, "resumed host advances exactly one tick per physics_process")

	host.free()
