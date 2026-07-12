extends SceneTree

## Headless test for TKT-P1.1R3-01 (AD-041 "Dummy-mode observability", re-gate-4
## E1). Exercises DummyModeIndicator.build_indicator_text -- the pure, Node-free
## text builder -- directly (no Label/TrainingMode needed, mirroring
## test_control_surface.gd's device-sampler tests and ControlsLegend's static
## build_legend_text() convention).
##
## THE RENDERED INDICATOR ITSELF (a human seeing the label update live on
## screen while cycling `M`) is confirmed at the human-inspection gate (5th
## re-gate) -- not headless-checkable, per the ticket. What IS headless-
## checkable, and what this test drives, is that the text builder names each
## mode correctly and carries the distinct "* REC" recording tell ONLY on
## RECORDING.
##
## Run:  godot --headless --path game -s res://tests/test_dummy_mode_indicator.gd
## Exits non-zero on any failure so a harness/CI can gate on it.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	if _failures == 0:
		print("[test_dummy_mode_indicator] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_dummy_mode_indicator] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	_test_passthrough_text()
	_test_recording_text_carries_the_rec_tell()
	_test_playback_text()


func _test_passthrough_text() -> void:
	var text: String = DummyModeIndicator.build_indicator_text(RecordPlaybackSource.Mode.PASSTHROUGH)
	_true(text.contains("PASSTHROUGH"), "PASSTHROUGH mode names itself in the indicator text")
	_true(not text.contains("REC"), "PASSTHROUGH does NOT carry the recording tell")


func _test_recording_text_carries_the_rec_tell() -> void:
	var text: String = DummyModeIndicator.build_indicator_text(RecordPlaybackSource.Mode.RECORDING)
	_true(text.contains("RECORDING"), "RECORDING mode names itself in the indicator text")
	_true(text.contains("REC"), "RECORDING carries a DISTINCT recording tell (charter observability -- E1)")


func _test_playback_text() -> void:
	var text: String = DummyModeIndicator.build_indicator_text(RecordPlaybackSource.Mode.PLAYBACK)
	_true(text.contains("PLAYBACK"), "PLAYBACK mode names itself in the indicator text")
	_true(not text.contains("REC"), "PLAYBACK does NOT carry the recording tell")
