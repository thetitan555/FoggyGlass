extends SceneTree

## Headless test for TKT-P1.1-02 (human control surface).
## training-mode.md → "Human control surface (operability — P1.1)" + criterion
## 13; AD-018 (three attack buttons at the input layer).
##
## Binds each control operation to a device/keyboard input-map action, routed
## through the TrainingMode shell's OWN control methods (never TickHost/
## TrainingHarness/RecordPlaybackSource directly — the same seam rule as
## criterion 10), and completes the P1 device sampler with the three attack
## buttons.
##
## OPERABILITY ITSELF (a human pressing real hardware controls) is confirmed
## at the human-inspection gate, not here — the ticket is explicit that this
## is not headless-confirmable. What IS headless-checkable, and what this test
## drives, is that the bound handler (`TrainingMode._unhandled_input`,
## exercised via a synthetic action-press event) calls the correct shell
## control method, and that the device sampler encodes the three attack-button
## bits.
##
## Run:  godot --headless --path game -s res://tests/test_control_surface.gd
## Exits non-zero on any failure so a harness/CI can gate on it.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	await _run()
	MoveRegistry.clear()
	if _failures == 0:
		print("[test_control_surface] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_control_surface] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	await _test_pause_action_toggles_through_shell()
	await _test_step_action_advances_one_tick_through_shell()
	await _test_reset_actions_through_shell()
	await _test_dummy_mode_cycle_action_through_shell()
	_test_device_sampler_encodes_attack_buttons()
	_test_device_sampler_encodes_left_and_right()
	_test_dummy_sampler_encodes_attack_buttons_on_its_own_key_set()
	_test_input_map_actions_are_registered()


## A synthetic action-press event. `InputEventAction.is_action_pressed()`
## compares directly against its OWN `action`/`pressed` fields (Godot special-
## cases InputEventAction in InputMap's action-status lookup specifically so
## it can be used to simulate an action without a registered physical binding)
## — so this reproduces exactly what a real hardware key bound to that action
## would deliver to `_unhandled_input`, without needing a live window/device.
func _press(action: String) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func _test_pause_action_toggles_through_shell() -> void:
	var tm := await _make_shell()
	_true(not tm.is_paused(), "fresh shell is not paused")
	tm._unhandled_input(_press("tm_pause"))
	_true(tm.is_paused(), "tm_pause action pauses through the shell's set_paused")
	tm._unhandled_input(_press("tm_pause"))
	_true(not tm.is_paused(), "a second tm_pause action resumes (toggle)")
	tm.get_parent().queue_free()


func _test_step_action_advances_one_tick_through_shell() -> void:
	var tm := await _make_shell()
	tm.set_paused(true)
	var t0: int = tm.inspection_view().tick()
	tm._unhandled_input(_press("tm_step"))
	_eq(tm.inspection_view().tick(), t0 + 1, "tm_step action advances exactly one tick through step_once()")
	tm.get_parent().queue_free()


func _test_reset_actions_through_shell() -> void:
	var tm := await _make_shell()
	for _k in range(3):
		tm.step_once()
	tm._unhandled_input(_press("tm_capture_reset"))
	_true(tm.has_reset_point(), "tm_capture_reset action calls capture_reset() through the shell")
	var tick_at_capture: int = tm.inspection_view().tick()
	for _k in range(5):
		tm.step_once()
	tm._unhandled_input(_press("tm_do_reset"))
	_eq(tm.inspection_view().tick(), tick_at_capture, "tm_do_reset action calls do_reset() through the shell")
	tm.get_parent().queue_free()


func _test_dummy_mode_cycle_action_through_shell() -> void:
	var tm := await _make_shell()
	_eq(tm.get_dummy_mode(1), RecordPlaybackSource.Mode.PASSTHROUGH, "P2 dummy starts PASSTHROUGH")
	tm._unhandled_input(_press("tm_dummy_mode_cycle"))
	_eq(tm.get_dummy_mode(1), RecordPlaybackSource.Mode.RECORDING,
		"first tm_dummy_mode_cycle action -> RECORDING, through the shell's set_dummy_mode")
	tm._unhandled_input(_press("tm_dummy_mode_cycle"))
	_eq(tm.get_dummy_mode(1), RecordPlaybackSource.Mode.PLAYBACK, "second cycle -> PLAYBACK")
	tm._unhandled_input(_press("tm_dummy_mode_cycle"))
	_eq(tm.get_dummy_mode(1), RecordPlaybackSource.Mode.PASSTHROUGH, "third cycle wraps back to PASSTHROUGH")
	tm.get_parent().queue_free()


## AD-018 / training-mode.md "Complete the P1 device sampler." Drives real
## Input singleton state (Input.action_press) against the tm_button_* actions
## registered in project.godot's [input] map and confirms the sampler encodes
## all three attack-button bits (plus a direction) into the ONE InputFrame —
## same shape, no per-button special casing (Tenet 2).
func _test_device_sampler_encodes_attack_buttons() -> void:
	var tm := TrainingMode.new()
	_eq(tm._sample_device_p1(), InputFrame.NEUTRAL, "no input pressed -> NEUTRAL")

	Input.action_press("tm_button_0")
	_eq(tm._sample_device_p1(), InputFrame.BUTTON_0, "tm_button_0 encodes BUTTON_0")
	Input.action_release("tm_button_0")

	Input.action_press("tm_button_1")
	_eq(tm._sample_device_p1(), InputFrame.BUTTON_1, "tm_button_1 encodes BUTTON_1")
	Input.action_release("tm_button_1")

	Input.action_press("tm_button_2")
	_eq(tm._sample_device_p1(), InputFrame.BUTTON_2, "tm_button_2 encodes BUTTON_2")
	Input.action_release("tm_button_2")

	# All three attack buttons plus a direction at once — still ONE raw
	# InputFrame composed by OR, exactly like the existing direction bits.
	Input.action_press("ui_left")
	Input.action_press("tm_button_0")
	Input.action_press("tm_button_1")
	Input.action_press("tm_button_2")
	var combined: int = tm._sample_device_p1()
	_eq(combined, InputFrame.LEFT | InputFrame.BUTTON_0 | InputFrame.BUTTON_1 | InputFrame.BUTTON_2,
		"directions + all three attack buttons compose into one InputFrame")
	Input.action_release("ui_left")
	Input.action_release("tm_button_0")
	Input.action_release("tm_button_1")
	Input.action_release("tm_button_2")
	_eq(tm._sample_device_p1(), InputFrame.NEUTRAL, "releasing all inputs returns to NEUTRAL (no stuck state)")
	tm.free()


## Regression for the 2026-07-08 human-inspection-gate flag ("arrow-key
## left/right movement does nothing"): confirms `_sample_device_p1` encodes
## BOTH the LEFT and RIGHT direction bits (mirrors
## `_test_device_sampler_encodes_attack_buttons` above). Drives the built-in
## `ui_left`/`ui_right` actions directly via `Input.action_press` -- these are
## Godot's own default actions (arrow keys), not entries this project's
## `project.godot` [input] section defines, so this also stands as a guard
## against a future `[input]` edit accidentally shadowing/disabling them.
func _test_device_sampler_encodes_left_and_right() -> void:
	var tm := TrainingMode.new()

	Input.action_press("ui_left")
	_eq(tm._sample_device_p1(), InputFrame.LEFT, "ui_left (arrow key) encodes LEFT")
	Input.action_release("ui_left")

	Input.action_press("ui_right")
	_eq(tm._sample_device_p1(), InputFrame.RIGHT, "ui_right (arrow key) encodes RIGHT")
	Input.action_release("ui_right")

	_eq(tm._sample_device_p1(), InputFrame.NEUTRAL, "releasing both returns to NEUTRAL (no stuck state)")
	tm.free()


## TKT-P1.1R2-01 (AD-040 dummy-control operability). Mirrors
## _test_device_sampler_encodes_attack_buttons exactly, but against
## `_sample_device_dummy` and its OWN distinct tm_dummy_* key set — confirming
## the dummy's live sampler (the missing piece D1 diagnosed) actually encodes
## input, on keys that don't collide with P1's.
func _test_dummy_sampler_encodes_attack_buttons_on_its_own_key_set() -> void:
	var tm := TrainingMode.new()
	_eq(tm._sample_device_dummy(), InputFrame.NEUTRAL, "no dummy input pressed -> NEUTRAL")

	Input.action_press("tm_dummy_button_0")
	_eq(tm._sample_device_dummy(), InputFrame.BUTTON_0, "tm_dummy_button_0 encodes BUTTON_0")
	Input.action_release("tm_dummy_button_0")

	Input.action_press("tm_dummy_button_1")
	_eq(tm._sample_device_dummy(), InputFrame.BUTTON_1, "tm_dummy_button_1 encodes BUTTON_1")
	Input.action_release("tm_dummy_button_1")

	Input.action_press("tm_dummy_button_2")
	_eq(tm._sample_device_dummy(), InputFrame.BUTTON_2, "tm_dummy_button_2 encodes BUTTON_2")
	Input.action_release("tm_dummy_button_2")

	Input.action_press("tm_dummy_left")
	_eq(tm._sample_device_dummy(), InputFrame.LEFT, "tm_dummy_left encodes LEFT")
	Input.action_release("tm_dummy_left")

	Input.action_press("tm_dummy_right")
	_eq(tm._sample_device_dummy(), InputFrame.RIGHT, "tm_dummy_right encodes RIGHT")
	Input.action_release("tm_dummy_right")

	Input.action_press("tm_dummy_up")
	_eq(tm._sample_device_dummy(), InputFrame.UP, "tm_dummy_up encodes UP")
	Input.action_release("tm_dummy_up")

	Input.action_press("tm_dummy_down")
	_eq(tm._sample_device_dummy(), InputFrame.DOWN, "tm_dummy_down encodes DOWN")
	Input.action_release("tm_dummy_down")

	# Pressing P1's keys must NOT show up on the dummy's sampler (distinct key
	# sets, the judgment-log latitude call) — the two samplers are independent.
	Input.action_press("ui_left")
	Input.action_press("tm_button_0")
	_eq(tm._sample_device_dummy(), InputFrame.NEUTRAL,
		"P1's keys (ui_left/tm_button_0) do not leak into the dummy's sampler")
	Input.action_release("ui_left")
	Input.action_release("tm_button_0")
	tm.free()


## Sanity that the placeholder key bindings this ticket adds actually exist in
## project.godot's input map (distinct from the _press()-driven tests above,
## which don't need InputMap registration to pass) — guards against a typo'd
## action name silently doing nothing for a real key press.
func _test_input_map_actions_are_registered() -> void:
	for action in ["tm_pause", "tm_step", "tm_capture_reset", "tm_do_reset",
			"tm_dummy_mode_cycle", "tm_button_0", "tm_button_1", "tm_button_2",
			"tm_dummy_up", "tm_dummy_down", "tm_dummy_left", "tm_dummy_right",
			"tm_dummy_button_0", "tm_dummy_button_1", "tm_dummy_button_2"]:
		_true(InputMap.has_action(action), "%s is registered in project.godot's input map" % action)


## Mirrors test_training_mode_shell.gd's _make_shell(): a bare TrainingMode
## with just the TickHost child it needs, rooted under the live scene tree so
## @onready resolves and _ready() runs. No overlays mounted — control-surface
## behavior doesn't depend on them.
func _make_shell() -> TrainingMode:
	var tm := TrainingMode.new()
	var host := TickHost.new()
	host.name = "TickHost"
	tm.add_child(host)
	var root := Node.new()
	root.add_child(tm)
	get_root().add_child(root)
	await process_frame
	return tm
