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
	_run()
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
