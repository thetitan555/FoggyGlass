extends SceneTree

## Headless test for TKT-P1-06 (the geometry overlay).
## training-mode.md → Readout: geometry; criterion 5. This test drives the
## PURE view-model (`GeometryOverlayModel.build_draw_list`), not the
## `_draw()`-based Node2D (pixel-exact rendering is a QA in-mode visual
## check per the ticket's own note) — it verifies the resolved BoxViews are
## correctly turned into color-coded, kind-tagged draw instructions, matching
## the world-space geometry the sim actually tests for overlap.
##
## Run:  godot --headless --path game -s res://tests/test_geometry_overlay.gd

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	await _run()
	MoveRegistry.clear()
	ProjectileRegistry.clear()
	if _failures == 0:
		print("[test_geometry_overlay] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_geometry_overlay] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	_test_hurtbox_draws_hurt_color_thin_border()
	_test_active_hitbox_draws_hit_color_thick_border()
	_test_projectile_hitbox_draws_its_own_distinct_color()
	_test_rects_match_resolved_boxes_in_world_space()
	_test_world_framing_centers_stage_and_seats_ground_low()
	_test_world_framing_puts_symmetric_start_boxes_on_screen_and_clear_of_panels()
	await _test_world_framing_is_render_only_no_effect_on_draw_list_or_state_hash()


func _install() -> void:
	MoveRegistry.install(TestSupport.build_roster())
	ProjectileRegistry.install(TestSupport.build_projectile_registry())


func _two_char_state(p1_units: int = 60) -> SimState:
	_install()
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


func _teardown() -> void:
	MoveRegistry.clear()
	ProjectileRegistry.clear()


# --- kind -> color/border mapping --------------------------------------------

func _test_hurtbox_draws_hurt_color_thin_border() -> void:
	var s := _two_char_state()
	s.players[0].frame_in_state = 1
	s.players[1].frame_in_state = 1
	# Both players idle: a resting hurtbox and the default pushbox are active
	# this tick, no HIT/THROW boxes.
	var view := InspectionView.new(s, TestSupport.build_roster())
	var draws: Array = GeometryOverlayModel.build_draw_list(view)
	var hurt_draws: Array = draws.filter(func(d): return d["kind"] == BoxView.KIND_HURT)
	_true(hurt_draws.size() >= 2, "at least one hurtbox per idle player draws")
	for d in draws:
		_true(d["kind"] == BoxView.KIND_HURT or d["kind"] == BoxView.KIND_PUSH,
			"idle players only expose HURT/PUSH boxes (no HIT/THROW while idle)")
	for d in hurt_draws:
		_eq(d["color"], GeometryOverlayModel.COLOR_HURT, "HURT boxes use COLOR_HURT")
		_eq(d["filled"], false, "a resting hurtbox is drawn unfilled")
		_eq(d["border_width"], GeometryOverlayModel.BORDER_HURT, "HURT boxes use the thin border")
	_teardown()


func _test_active_hitbox_draws_hit_color_thick_border() -> void:
	var s := _two_char_state()
	s.players[0].state_id = TestSupport.STATE_LIGHT
	s.players[0].frame_in_state = TestSupport.LIGHT_FIRST_ACTIVE   # active frame
	var view := InspectionView.new(s, TestSupport.build_roster())
	var draws: Array = GeometryOverlayModel.build_draw_list(view)
	var hit_draws: Array = draws.filter(func(d): return d["kind"] == BoxView.KIND_HIT)
	_true(hit_draws.size() > 0, "an active hitbox produces a HIT draw entry on its active frame")
	for d in hit_draws:
		_eq(d["color"], GeometryOverlayModel.COLOR_HIT, "HIT boxes use COLOR_HIT")
		_eq(d["filled"], true, "an active hitbox is drawn filled")
		_eq(d["border_width"], GeometryOverlayModel.BORDER_ACTIVE,
			"an active hitbox uses the THICK border — visually distinct from a resting hurtbox (criterion 5)")
	_true(GeometryOverlayModel.BORDER_ACTIVE > GeometryOverlayModel.BORDER_HURT,
		"active-box border is strictly thicker than a resting hurtbox's border")
	_teardown()


func _test_projectile_hitbox_draws_its_own_distinct_color() -> void:
	var s := _two_char_state()
	s.players[0].state_id = TestSupport.STATE_FIREBALL
	s.players[0].frame_in_state = 0
	for _k in range(TestSupport.FIREBALL_SPAWN_FRAME + 1):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(s.projectiles.size() > 0, "sanity: the fireball spawned")

	var view := InspectionView.new(s, TestSupport.build_roster())
	var draws: Array = GeometryOverlayModel.build_draw_list(view)
	var proj_draws: Array = draws.filter(
		func(d): return d["color"] == GeometryOverlayModel.COLOR_PROJECTILE)
	_eq(proj_draws.size(), 1, "the live projectile's hitbox draws exactly once, in its own color")
	_eq(proj_draws[0]["kind"], BoxView.KIND_HIT,
		"a projectile's carried hitbox is still classified HIT (inspection-surface.md) even though its DRAW color is distinct")
	_true(GeometryOverlayModel.COLOR_PROJECTILE != GeometryOverlayModel.COLOR_HIT,
		"a projectile's hitbox reads distinctly from a character's own active hitbox")
	_teardown()


# --- world-space correctness --------------------------------------------------

func _test_rects_match_resolved_boxes_in_world_space() -> void:
	var s := _two_char_state()
	s.players[0].state_id = TestSupport.STATE_LIGHT
	s.players[0].frame_in_state = TestSupport.LIGHT_FIRST_ACTIVE
	var view := InspectionView.new(s, TestSupport.build_roster())
	var pv: PlayerView = view.player(0)
	_true(pv.boxes.size() > 0, "sanity: player 0 has resolved boxes this tick")

	var draws: Array = GeometryOverlayModel.build_draw_list(view)
	# Every resolved BoxView's px_rect must appear among the draw list's rects
	# (the overlay draws exactly the geometry the sim tests for overlap — no
	# re-derivation, single source of truth).
	for box in pv.boxes:
		var expected_rect: Rect2 = InspectionView.px_rect(box.rect)
		var found: bool = false
		for d in draws:
			if d["rect"] == expected_rect and d["kind"] == box.kind:
				found = true
				break
		_true(found, "resolved box (kind %d) world-space rect appears in the draw list unmodified" % box.kind)
	_teardown()


# --- AD-035 render framing (TKT-P1.1-01 Part B) ------------------------------
# training-mode.md criterion 14 / AD-035. Pixel visibility on an actual running
# window is the human-inspection gate (not headless-checkable); what IS
# headlessly verifiable is the FRAMING MATH itself (GeometryOverlay.
# compute_world_framing, a pure function) and that applying it is render-only
# -- never touches the draw-list view-model or the sim state hash.

func _test_world_framing_centers_stage_and_seats_ground_low() -> void:
	var viewport_size := Vector2(1152.0, 648.0)
	var framing: Dictionary = GeometryOverlay.compute_world_framing(viewport_size)
	var pos: Vector2 = framing["position"]
	var zoom: Vector2 = framing["scale"]
	_true(zoom.x > 0.0 and zoom.y > 0.0, "framing zoom is positive")
	_eq(zoom.x, zoom.y, "framing zoom is uniform (no stretch)")

	# World x=0 (stage center, wall_left/right are symmetric) lands at the
	# viewport's horizontal center.
	var screen_x_of_stage_center: float = pos.x
	_true(abs(screen_x_of_stage_center - viewport_size.x * 0.5) < 0.01,
		"stage center (world x=0) lands at the viewport's horizontal center")

	# World y=0 (ground_y) lands low in the viewport (AD-035: "seated in the
	# lower portion of the view"), not centered.
	var screen_y_of_ground: float = pos.y
	var expected_ground_screen_y: float = viewport_size.y * GeometryOverlay.GROUND_LINE_FRACTION
	_true(abs(screen_y_of_ground - expected_ground_screen_y) < 0.01,
		"ground line (world y=0) lands at the configured lower-portion fraction of the viewport")
	_true(screen_y_of_ground > viewport_size.y * 0.5,
		"ground line sits below the viewport's vertical midpoint (lower portion, not centered)")

	# Zoom fits the stage width with margin -- fills a majority of the
	# viewport width but does not overflow it.
	var framed_stage_width_px: float = (GeometryOverlay.STAGE_WALL_RIGHT - GeometryOverlay.STAGE_WALL_LEFT) * zoom.x
	_true(framed_stage_width_px <= viewport_size.x + 0.01,
		"the framed stage width fits within the viewport width")
	_true(framed_stage_width_px > viewport_size.x * 0.5,
		"the framed stage fills a meaningful majority of the viewport width (not tiny)")


func _test_world_framing_puts_symmetric_start_boxes_on_screen_and_clear_of_panels() -> void:
	# training_mode.tscn's screen-anchored LEFT-COLUMN HUD panels (FrameDataPanel/
	# LiveStatePanel/InputHistoryPanel) occupy screen y 16..442 (docs/flags.md
	# 2026-07-17 "re: HUD (round 2)" resized them to fit REAL rendered text —
	# see test_hud_layout.gd). AD-035's acceptance bar: both characters at
	# their SYMMETRIC START positions (pos_x = +-100, pos_y = ground_y) are
	# fully on-screen and not occluded by that panel region.
	# Reads the ONE shared constant (TrainingMode.HUD_LEFT_COLUMN_SAFE_MAX_Y)
	# test_hud_layout.gd's own panel-sizing is designed against, so this test
	# and the HUD layout can never silently drift apart again.
	var PANEL_MAX_Y: float = TrainingMode.HUD_LEFT_COLUMN_SAFE_MAX_Y
	var viewport_size := Vector2(1152.0, 648.0)
	var framing: Dictionary = GeometryOverlay.compute_world_framing(viewport_size)
	var pos: Vector2 = framing["position"]
	var zoom: Vector2 = framing["scale"]

	var s := _two_char_state()
	s.players[0].pos_x = FP.from_int(-100)
	s.players[0].pos_y = 0
	s.players[1].pos_x = FP.from_int(100)
	s.players[1].pos_y = 0
	var view := InspectionView.new(s, TestSupport.build_roster())
	var checked_any: bool = false
	for i in range(2):
		var pv: PlayerView = view.player(i)
		for box in pv.boxes:
			checked_any = true
			var world_rect: Rect2 = InspectionView.px_rect(box.rect)
			var screen_rect := Rect2(pos + world_rect.position * zoom, world_rect.size * zoom)
			_true(screen_rect.position.x >= -0.01 and screen_rect.end.x <= viewport_size.x + 0.01,
				"player %d box (kind %d) fully within the viewport horizontally" % [i, box.kind])
			_true(screen_rect.position.y >= -0.01 and screen_rect.end.y <= viewport_size.y + 0.01,
				"player %d box (kind %d) fully within the viewport vertically" % [i, box.kind])
			_true(screen_rect.position.y >= PANEL_MAX_Y,
				"player %d box (kind %d) sits clear of the HUD panel region (screen y >= %.0f)" % [i, box.kind, PANEL_MAX_Y])
	_true(checked_any, "sanity: at least one box was checked for both symmetric-start players")
	_teardown()


func _test_world_framing_is_render_only_no_effect_on_draw_list_or_state_hash() -> void:
	# AD-019 criterion 6 / AD-035: the framing never enters a snapshot or the
	# canonical hash, and never changes the pure draw-list view-model -- "a
	# golden taken with vs. without the camera is identical." Exercises the
	# ACTUAL node code path (_ready()/_apply_world_framing()), not just the
	# pure function, so this also proves the live node's transform never
	# reaches back into sim state.
	var s := _two_char_state()
	var hash_before: int = s.hash_state()
	var view := InspectionView.new(s, TestSupport.build_roster())
	var draws_before: Array = GeometryOverlayModel.build_draw_list(view)

	var overlay := GeometryOverlay.new()
	get_root().add_child(overlay)
	await process_frame   # let _ready() run and apply the framing transform

	_true(overlay.scale.x > 0.0, "the live overlay node picked up a non-degenerate framing scale")
	_eq(s.hash_state(), hash_before, "applying the render framing does not change the sim state hash")
	var draws_after: Array = GeometryOverlayModel.build_draw_list(view)
	_eq(draws_after, draws_before, "applying the render framing does not change the geometry draw list")

	overlay.queue_free()
	_teardown()
