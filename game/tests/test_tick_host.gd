extends SceneTree

## Headless test for the fixed-tick host (TKT-P0-01 clock discipline, carried
## through the TKT-P0-03 seam close). AD-004, simulation.md.
##
## Run:  godot --headless --path game -s res://tests/test_tick_host.gd
## Exits non-zero on any failure so a harness/CI can gate on it.
##
## SCOPE / HONESTY NOTE. simulation.md criterion 5 ("Tick authority: sim tick count
## derives from state.tick, not engine frame count; render rate changes do not
## change sim outcomes") is now fully wired: the host advances a real SimState via
## the pure step, and the clock is read from state.tick. What this test pins:
##   (a) The host's clock is read from state (`current_tick()` == `state.tick`) —
##       not from an engine counter. set_state / get_state prove the reads route
##       through the SimState handle.
##   (b) One `_advance` call == exactly one tick of progress, monotonic, never
##       scaled by anything (no delta enters the advance path at all).
##   (c) `_delta` is unused: advancing via _physics_process with wildly different
##       delta values yields exactly +1 tick each, and a paused host advances 0.
## The "render rate changes don't change outcomes" half is asserted by construction
## (the advance path takes no delta/frame-count input) and is an end-to-end check
## under QA's harness at TKT-P0-11.

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

	# Wire a real initial state and two neutral sources so _advance can source
	# input through the InputSource contract, just like the running game.
	var state := SimState.new_initial()
	var src1 := LocalDeviceSource.new()   # null sampler -> samples NEUTRAL
	var src2 := LocalDeviceSource.new()
	host.setup(state, src1, src2)

	# (a) Clock reads from state, not from any engine counter.
	_eq(host.current_tick(), 0, "current_tick reads state.tick (0 at start)")
	_eq(host.get_state().tick, 0, "get_state exposes the SimState handle")

	# (b)/(c) One advance == exactly one tick, monotonic, delta-free.
	# The Local sources must PRODUCE each frame before the host queries it (no
	# future reads): sample_next() ahead of each advance mirrors the running game,
	# where the device is sampled for the current frame each tick.
	var prev: int = host.current_tick()
	for i in range(120):
		src1.sample_next()
		src2.sample_next()
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

	# Resume: one physics_process == one tick. The host must have the current frame
	# available from its sources; produce it first.
	host.running = true
	src1.sample_next()
	src2.sample_next()
	host._physics_process(0.016)
	_eq(host.current_tick(), frozen + 1, "resumed host advances exactly one tick per physics_process")
	# And a wildly different delta on the next tick still yields exactly +1.
	src1.sample_next()
	src2.sample_next()
	host._physics_process(9.999)
	_eq(host.current_tick(), frozen + 2, "huge delta still advances exactly one tick")

	host.free()
