extends SceneTree

## Headless test for docs/flags.md 2026-07-17 "re: HUD (round 2)" -- verifies
## REAL RENDERED TEXT EXTENTS (not Control.rect boxes) never overlap between
## training_mode.tscn's readout panels, and never occlude the symmetric-start
## character boxes AD-035 protects (TrainingMode.HUD_LEFT_COLUMN_SAFE_MAX_Y).
##
## THE PROXY THIS REPLACES (JC-101's prior fix): loading the .tscn and
## asserting no two Control.rects overlap -- which measured BOXES as a
## stand-in for TEXT, and text overflows its box (docs/audit-criterion.md
## "Exercise the thing, not a proxy for it"). This test instead:
##   1. Loads the REAL training_mode.tscn (the actual production scene file,
##      not a hand-rebuilt node tree).
##   2. Drives each panel's REAL Label with the SAME static formatter
##      production's own _refresh() calls (FrameDataPanel._format,
##      LiveStatePanel._format, InputHistoryPanel._format,
##      ControlsLegend.build_legend_text, DummyModeIndicator.
##      build_indicator_text, MatchPanelModel.format), fed a realistic
##      WORST-CASE content model per panel (every field maxed to what real
##      play can actually produce simultaneously -- not artificially
##      inflated).
##   3. Measures the ACTUAL glyph extents via Font.get_multiline_string_size
##      -- the same measurement Godot's own TextServer uses to lay text out
##      -- against each Label's REAL autowrap_mode/width read from the .tscn.
##   4. Asserts none of the resulting RENDERED rects intersect one another,
##      stay within the viewport, and the left-column panels' real bottom
##      edge never crosses the AD-035 safety line.
## This test WOULD FAIL against the pre-fix .tscn: none of the three
## left-column Labels had autowrap, so a two-player Live-State row alone
## rendered ~1360px wide unwrapped from a 16px left margin -- deep into (and
## past) the right column's rendered text, at a fraction of the true text
## height the boxes assumed.
##
## Run:  godot --headless --path game -s res://tests/test_hud_layout.gd

var _failures: int = 0
var _checks: int = 0

const VIEWPORT_SIZE := Vector2(1152.0, 648.0)


func _init() -> void:
	await _run()
	MoveRegistry.clear()
	if _failures == 0:
		print("[test_hud_layout] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_hud_layout] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	await _test_worst_case_content_does_not_overlap_and_stays_clear_of_characters()


## Build the REAL production scene, feed every panel's REAL Label the SAME
## static formatter production uses with a worst-case-but-realistic content
## model, measure the ACTUAL rendered text extent with the real font/wrap
## settings, and check every pairwise combination for overlap plus the
## AD-035 character-occlusion boundary.
func _test_worst_case_content_does_not_overlap_and_stays_clear_of_characters() -> void:
	var packed: PackedScene = load("res://scenes/training_mode.tscn")
	var tm: TrainingMode = packed.instantiate()
	var root := Node.new()
	root.add_child(tm)
	get_root().add_child(root)
	await process_frame

	var panels: Dictionary = {
		"FrameDataPanel": tm.get_node("FrameDataPanel"),
		"LiveStatePanel": tm.get_node("LiveStatePanel"),
		"InputHistoryPanel": tm.get_node("InputHistoryPanel"),
		"ControlsLegend": tm.get_node("ControlsLegend"),
		"DummyModeIndicator": tm.get_node("DummyModeIndicator"),
		"MatchPanel": tm.get_node("MatchPanel"),
	}

	# Overwrite each panel's real Label with the REAL formatter's worst-case
	# output (the exact same static functions _refresh() calls in production).
	panels["FrameDataPanel"].get_node("Label").text = FrameDataPanel._format(_worst_case_frame_data_model())
	panels["LiveStatePanel"].get_node("Label").text = LiveStatePanel._format(_worst_case_live_state_rows())
	panels["InputHistoryPanel"].get_node("Label").text = InputHistoryPanel._format(_worst_case_input_history_rows())
	panels["ControlsLegend"].get_node("Label").text = ControlsLegend.build_legend_text()
	panels["DummyModeIndicator"].get_node("Label").text = DummyModeIndicator.build_indicator_text(RecordPlaybackSource.Mode.RECORDING)
	panels["MatchPanel"].get_node("Label").text = MatchPanelModel.format(_worst_case_match_model())

	var rendered: Dictionary = {}
	for panel_name in panels.keys():
		var control: Control = panels[panel_name]
		var label: Label = control.get_node("Label")
		rendered[panel_name] = _measure_rendered_rect(label)
		_true(rendered[panel_name].size.x > 0.0 and rendered[panel_name].size.y > 0.0,
			"%s's Label rendered a non-empty extent (sanity)" % panel_name)

	# Pairwise: no two panels' REAL RENDERED TEXT extents intersect.
	var names: Array = rendered.keys()
	for i in range(names.size()):
		for j in range(i + 1, names.size()):
			var a: Rect2 = rendered[names[i]]
			var b: Rect2 = rendered[names[j]]
			_true(not a.intersects(b),
				"%s's rendered text does not overlap %s's rendered text (a=%s b=%s)" % [names[i], names[j], a, b])

	# Every rendered extent stays within the viewport (a bonus, cheap check --
	# text drifting off-screen is exactly as invisible as text buried under
	# another panel).
	for panel_name in rendered.keys():
		var r: Rect2 = rendered[panel_name]
		_true(r.position.x >= -0.5 and r.end.x <= VIEWPORT_SIZE.x + 0.5,
			"%s's rendered text stays within the viewport horizontally" % panel_name)
		_true(r.position.y >= -0.5 and r.end.y <= VIEWPORT_SIZE.y + 0.5,
			"%s's rendered text stays within the viewport vertically" % panel_name)

	# The AD-035 boundary: the LEFT-COLUMN panels' real rendered bottom edge
	# must stay at/above TrainingMode.HUD_LEFT_COLUMN_SAFE_MAX_Y, so the
	# symmetric-start character boxes (test_geometry_overlay.gd) are never
	# occluded.
	for panel_name in ["FrameDataPanel", "LiveStatePanel", "InputHistoryPanel"]:
		var r: Rect2 = rendered[panel_name]
		_true(r.end.y <= TrainingMode.HUD_LEFT_COLUMN_SAFE_MAX_Y,
			"%s's real rendered text bottom edge (%s) stays at/above the AD-035 safety line (%s)" % [
				panel_name, r.end.y, TrainingMode.HUD_LEFT_COLUMN_SAFE_MAX_Y])

	root.queue_free()


## The real rendered Rect2 a Label's CURRENT `text` occupies on screen: real
## global position, sized via the SAME measurement Godot's own TextServer uses
## to lay out the label (Font.get_multiline_string_size), respecting the
## label's REAL autowrap_mode/width from the .tscn -- not the Label's own
## Control.rect (the exact proxy this test replaces).
static func _measure_rendered_rect(label: Label) -> Rect2:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var wrap_width: float = -1.0
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		wrap_width = label.size.x
	var measured: Vector2 = font.get_multiline_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, wrap_width, font_size)
	return Rect2(label.global_position, measured)


# ---------------------------------------------------------------------------
# Worst-case-but-realistic content models, one per panel -- realistic digit
# counts (not artificially inflated), maxing every field this panel can
# actually display simultaneously in real play.
# ---------------------------------------------------------------------------

static func _worst_case_frame_data_model() -> Dictionary:
	return {
		"static": [
			{"player": 0, "state_id": 999, "startup": 40, "active": 20, "recovery": 40, "total": 100, "on_hit_adv": -40, "on_block_adv": -40},
			{"player": 1, "state_id": 999, "startup": 40, "active": 20, "recovery": 40, "total": 100, "on_hit_adv": -40, "on_block_adv": -40},
		],
		"live": {"value": -40, "plus_player": 0, "frames_to_neutral": 40, "neutral_restored": false},
		"last_hit_why": {"attacker": 0, "defender": 1, "contact_depth": 200, "air_height_hitstun_delta": -30},
		"last_hit_guard": {"attacker": 0, "defender": 1, "guard_height": HitBox.GUARD_HIGH, "was_block": false, "block_valid": false},
	}


static func _worst_case_live_state_row(player: int, facing: int) -> Dictionary:
	return {
		"player": player, "facing": facing, "state_id": 999, "state_category": MoveState.CATEGORY_BLOCKSTUN,
		"frame_in_state": 60, "state_duration": 60, "hitstop_remaining": 15,
		"stun_remaining": 40, "stun_kind": PlayerView.STUN_BLOCK, "actionable": false,
		"invuln_strike": true, "invuln_throw": true, "hit_count": 20, "scaling_pct": 100,
		"damage_total": 999, "air_action_used": true, "reaction_kind": MoveState.REACTION_CROUCH_BLOCKSTUN,
	}


static func _worst_case_live_state_rows() -> Array:
	return [_worst_case_live_state_row(0, -1), _worst_case_live_state_row(1, 1)]


static func _worst_case_input_history_row(player: int) -> Dictionary:
	var history: Array = []
	for i in range(8):   # matches InputHistoryPanel.max_rows
		history.append({"raw": 0, "direction": "UD", "buttons": PackedStringArray(["L", "M", "H"])})
	return {
		"player": player,
		"current": {"raw": 0, "direction": "UD", "buttons": PackedStringArray(["L", "M", "H"])},
		"history": history,
		"recognized": {"jump": true, "throw": true},
	}


static func _worst_case_input_history_rows() -> Array:
	return [_worst_case_input_history_row(0), _worst_case_input_history_row(1)]


static func _worst_case_match_model() -> Dictionary:
	return {
		"has_match": true, "health": [1000, 1000], "round_wins": [9, 9], "round_timer": 3600,
		"match_phase": MatchState.PHASE_ROUND_END, "sudden_death": true,
		"last_round_end_reason": MatchState.REASON_DOUBLE_KO, "round_index": 9,
	}
