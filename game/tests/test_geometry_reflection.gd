extends SceneTree

## Headless test for AD-037 (TKT-P1.1R-02): the box-data Y-reflection. Asserts
## the SIM-TRUTH orientation (through InspectionView/PlayerView, AD-011 — the
## same read surface TraceHarness itself uses) now reads right-side-up:
## grounded boxes are feet-anchored at world y = pos_y (= 0 for a grounded
## player at ground_y = 0) and extend UPWARD (more negative y) toward the head;
## the pushbox occupies the body's LOWER (nearer-to-feet) portion of the
## standing hurtbox; the crouch hurtbox's extent shrinks TOWARD the feet
## (its top edge moves closer to 0, i.e. less negative, than standing's);
## grounded attack hitboxes stay above the floor (do not reach below y = 0).
##
## Pixel/render orientation is confirmed at the human-inspection re-gate (not
## headless-checkable, per training-mode.md criteria 5/14 and this ticket's own
## acceptance note) -- this test is the headless half only.
##
## JUDGMENT CALL (logged, docs/judgment-log.md): verifies via direct
## InspectionView/PlayerView reads (typed BoxView.rect ints) rather than
## parsing TraceHarness's formatted `boxes` string field, and drives CROUCH by
## direct state-injection (mirrors test_character_a.gd/test_geometry_overlay.gd's
## existing pattern) rather than through scripted input, since held-DOWN ->
## CROUCH recognition is AD-038/TKT-P1.1R-03's job, not yet wired.
##
## Run:  godot --headless --path game -s res://tests/test_geometry_reflection.gd

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	ProjectileRegistry.clear()
	if _failures == 0:
		print("[test_geometry_reflection] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_geometry_reflection] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	_test_character_a_standing_hurtbox_and_pushbox_orientation()
	_test_character_a_crouch_hurtbox_shrinks_toward_feet()
	_test_character_a_grounded_hitboxes_stay_above_the_floor()
	_test_test_support_standing_hurtbox_and_pushbox_orientation()


# --- helpers ------------------------------------------------------------------

func _install_character_a() -> void:
	MoveRegistry.install({CharacterA.CHAR_ID: CharacterA.build_character()})
	ProjectileRegistry.install(CharacterA.build_projectile_registry())


func _install_test_support() -> void:
	MoveRegistry.install(TestSupport.build_roster())
	ProjectileRegistry.install(TestSupport.build_projectile_registry())


func _cleanup() -> void:
	MoveRegistry.clear()
	ProjectileRegistry.clear()


## A grounded player-0-only SimState (player 1 parked far away so it never
## enters player 0's boxes): pos_y = ground_y = 0 (AD-037: a grounded
## character's feet sit at pos_y = ground_y).
func _grounded_state(character_id: int, state_id: int, frame_in_state: int = 1) -> SimState:
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = character_id
	s.players[0].state_id = state_id
	s.players[0].frame_in_state = frame_in_state
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].pos_y = s.stage.ground_y
	s.players[0].facing = 1
	s.players[1].pos_x = FP.from_int(1000)   # out of the way
	return s


func _boxes(state: SimState, roster: Dictionary) -> Array[BoxView]:
	return InspectionView.new(state, roster).player(0).boxes


func _find_kind(boxes: Array[BoxView], kind: int) -> BoxView:
	for b in boxes:
		if b.kind == kind:
			return b
	return null


# --- Character A ---------------------------------------------------------------

func _test_character_a_standing_hurtbox_and_pushbox_orientation() -> void:
	_install_character_a()
	var s := _grounded_state(CharacterA.CHAR_ID, CharacterA.STATE_IDLE)
	var roster := {CharacterA.CHAR_ID: CharacterA.build_character()}
	var boxes := _boxes(s, roster)

	var hurt := _find_kind(boxes, BoxView.KIND_HURT)
	_true(hurt != null, "standing IDLE resolves a hurtbox")
	var push := _find_kind(boxes, BoxView.KIND_PUSH)
	_true(push != null, "standing IDLE resolves the default pushbox")

	# Feet-anchored: bottom edge (y + h) sits exactly at pos_y (world y = 0, the
	# feet/ground line); the box extends UPWARD (negative y) toward the head.
	_eq(int(hurt.rect["y"]) + int(hurt.rect["h"]), 0, "standing hurtbox bottom edge sits at the feet (pos_y = 0)")
	_true(int(hurt.rect["y"]) < 0, "standing hurtbox top edge is ABOVE the feet line (negative y = up, AD-037)")
	_eq(int(push.rect["y"]) + int(push.rect["h"]), 0, "pushbox bottom edge also sits at the feet")
	_true(int(push.rect["y"]) < 0, "pushbox top edge is also above the feet line")

	# The pushbox occupies the body's LOWER (nearer-to-feet) portion of the
	# hurtbox: its top edge is closer to the feet line (less negative / greater)
	# than the hurtbox's own top edge, while both share the same feet-anchored
	# bottom.
	_true(int(push.rect["y"]) > int(hurt.rect["y"]),
		"pushbox top edge sits BELOW (closer to the feet than) the hurtbox's top edge — the lower portion of the body")
	_cleanup()


func _test_character_a_crouch_hurtbox_shrinks_toward_feet() -> void:
	_install_character_a()
	var s := _grounded_state(CharacterA.CHAR_ID, CharacterA.STATE_CROUCH)
	var roster := {CharacterA.CHAR_ID: CharacterA.build_character()}
	var crouch_boxes := _boxes(s, roster)
	var crouch_hurt := _find_kind(crouch_boxes, BoxView.KIND_HURT)
	_true(crouch_hurt != null, "CROUCH resolves a hurtbox")

	var s_stand := _grounded_state(CharacterA.CHAR_ID, CharacterA.STATE_IDLE)
	var stand_hurt := _find_kind(_boxes(s_stand, roster), BoxView.KIND_HURT)

	# Both feet-anchored at the same ground line...
	_eq(int(crouch_hurt.rect["y"]) + int(crouch_hurt.rect["h"]), 0, "crouch hurtbox bottom edge also sits at the feet")
	# ...but the crouch box's extent SHRINKS TOWARD THE FEET: its top edge (the
	# head) sits closer to the ground (less negative) than standing's, and its
	# total height is smaller.
	_true(int(crouch_hurt.rect["y"]) > int(stand_hurt.rect["y"]),
		"crouch hurtbox top edge is closer to the feet than standing's (the head lowers when crouching)")
	_true(int(crouch_hurt.rect["h"]) < int(stand_hurt.rect["h"]),
		"crouch hurtbox is shorter than the standing hurtbox")
	_cleanup()


func _test_character_a_grounded_hitboxes_stay_above_the_floor() -> void:
	_install_character_a()
	var character := CharacterA.build_character()
	var roster := {CharacterA.CHAR_ID: character}
	var grounded_normals := [
		CharacterA.STATE_5L, CharacterA.STATE_5M, CharacterA.STATE_5H,
		CharacterA.STATE_2L, CharacterA.STATE_2M, CharacterA.STATE_2H,
	]
	for state_id in grounded_normals:
		var move: MoveState = character.get_state(state_id)
		var fd: FrameData = MoveData.frame_data(move)
		var first_active: int = fd.startup + 1
		var s := _grounded_state(CharacterA.CHAR_ID, state_id, first_active)
		var hit := _find_kind(_boxes(s, roster), BoxView.KIND_HIT)
		_true(hit != null, "state %d has a resolved hitbox on its first active frame" % state_id)
		if hit != null:
			_true(int(hit.rect["y"]) + int(hit.rect["h"]) <= 0,
				"state %d's hitbox does not reach below the floor (honest grounded height, AD-037)" % state_id)
	_cleanup()


# --- P0 test character (TestSupport) — the one convention holds slice-wide ----

func _test_test_support_standing_hurtbox_and_pushbox_orientation() -> void:
	_install_test_support()
	var roster := TestSupport.build_roster()
	var s := _grounded_state(TestSupport.CHAR_ID, TestSupport.STATE_IDLE)
	var boxes := _boxes(s, roster)

	var hurt := _find_kind(boxes, BoxView.KIND_HURT)
	_true(hurt != null, "TestSupport IDLE resolves a hurtbox")
	var push := _find_kind(boxes, BoxView.KIND_PUSH)
	_true(push != null, "TestSupport IDLE resolves the default pushbox")

	_eq(int(hurt.rect["y"]) + int(hurt.rect["h"]), 0, "TestSupport standing hurtbox bottom edge sits at the feet")
	_true(int(hurt.rect["y"]) < 0, "TestSupport standing hurtbox top edge is above the feet line")
	_eq(int(push.rect["y"]) + int(push.rect["h"]), 0, "TestSupport pushbox bottom edge also sits at the feet")
	_true(int(push.rect["y"]) > int(hurt.rect["y"]),
		"TestSupport pushbox top edge sits closer to the feet than the hurtbox's top edge (same convention, AD-037)")
	_cleanup()
