extends SceneTree

## Headless test for the inspection surface (TKT-P0-04). inspection-surface.md
## criteria 2 and 4 for the implemented reads (1/3/5 complete at TKT-P1-01; the
## frame_data/advantage/last_hit wiring is exercised by test_combat.gd at 07).
##
## Run:  godot --headless --path game -s res://tests/test_inspection_view.gd
##
## Criteria covered here:
##   2 Read-only    — no method mutates SimState; the state hash is unchanged after
##                    any sequence of inspection calls; no mutator is exposed.
##   4 Snapshot-stable, fixed-point only — PlayerView / HitEvent truth views contain
##                    NO float fields (a recursive scan of their exported data).
## Plus: the core PlayerView reads return the sim's own values (state+frame,
## position, stun, hitstop, health, inputs), and px projection is a helper, never a
## truth-view field (criterion 6 spot-check).

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	if _failures == 0:
		print("[test_inspection_view] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_inspection_view] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	_test_read_only()
	_test_core_reads()
	_test_no_floats_in_truth_views()
	_test_stubs_typed()


func _test_read_only() -> void:
	# Criterion 2: no inspection call mutates state; the hash is unchanged after a
	# sequence of reads.
	var s := SimState.new_initial(7)
	# Advance a few ticks so there is non-trivial state to read.
	for f in range(5):
		s = SimState.step(s, InputFrame.RIGHT, InputFrame.LEFT)
	var before: int = s.hash_state()

	var view := InspectionView.new(s)
	# Exercise every read the surface offers.
	var _t: int = view.tick()
	var pv0: PlayerView = view.player(0)
	var pv1: PlayerView = view.player(1)
	var _pr: Array = view.projectiles()
	var _fd: FrameData = view.frame_data(0, 0)
	var _adv: AdvantageView = view.advantage()
	var _lh: HitEvent = view.last_hit()
	# Touch the returned views' fields too.
	var _x: int = pv0.position["x"]
	var _y: int = pv1.stun_remaining

	_eq(s.hash_state(), before, "state hash unchanged after a sequence of inspection reads")


func _test_core_reads() -> void:
	# The core PlayerView reads must equal the sim's own values (single source).
	var s := SimState.new_initial(3)
	s.players[0].health = 777
	s.players[0].stun = 12
	s.players[0].hitstop = 3
	s.players[0].pos_x = FP.from_int(-50)
	s.players[0].state_id = 4
	s.players[0].frame_in_state = 6
	s.players[0].facing = 1
	s = SimState.step(s, InputFrame.DOWN | InputFrame.BUTTON_1, InputFrame.NEUTRAL)

	var view := InspectionView.new(s)
	_eq(view.tick(), 1, "tick() reads state.tick")
	var pv: PlayerView = view.player(0)
	_eq(pv.health, 777, "PlayerView.health reads state")
	_eq(pv.stun_remaining, 12, "PlayerView.stun_remaining reads state")
	_eq(pv.hitstop_remaining, 3, "PlayerView.hitstop_remaining reads state")
	_eq(pv.position["x"], FP.from_int(-50), "PlayerView.position.x reads state (fixed-point)")
	_eq(pv.state_id, 4, "PlayerView.state_id reads state")
	_eq(pv.frame_in_state, 6, "PlayerView.frame_in_state reads state")
	# input_current is the raw frame recorded this tick.
	_eq(pv.input_current, InputFrame.DOWN | InputFrame.BUTTON_1,
		"PlayerView.input_current reads the recorded raw frame")
	# input_history is oldest -> newest, one frame recorded.
	_eq(pv.input_history.size(), 1, "PlayerView.input_history has the one recorded frame")
	_eq(pv.input_history[0], InputFrame.DOWN | InputFrame.BUTTON_1,
		"PlayerView.input_history[0] is the recorded frame")
	# With no roster, actionability falls back to stun/hitstop (stun 12 -> not actionable).
	_eq(pv.actionable, false, "PlayerView.actionable false while stunned (no-roster fallback)")


func _test_no_floats_in_truth_views() -> void:
	# Criterion 4: truth views carry no floats. Scan every exported field.
	var s := SimState.new_initial(1)
	s = SimState.step(s, InputFrame.RIGHT, InputFrame.LEFT)
	var view := InspectionView.new(s)
	var pv: PlayerView = view.player(0)

	_true(not _object_has_float(pv), "PlayerView contains no float field")

	# HitEvent (built from a HitRecord) also carries no float.
	var rec := HitRecord.new()
	rec.attacker = 0
	rec.defender = 1
	rec.damage_dealt = 40
	rec.scaling_applied_pct = 80
	var he := HitEvent.from_record(rec)
	_true(not _object_has_float(he), "HitEvent contains no float field")

	# px projection IS a float — but it is a helper, not a truth-view field
	# (criterion 6). Confirm it is not a member of the PlayerView.
	_true(not ("position_px" in pv), "PlayerView has no px field (px is render-only)")
	# And the helper produces a float, as expected for rendering.
	var px_val: float = InspectionView.px(FP.from_int(2))
	_true(typeof(px_val) == TYPE_FLOAT, "InspectionView.px returns a float (render-only helper)")


func _test_stubs_typed() -> void:
	# The 05/07-wired reads return typed, well-formed results before their data lands.
	var s := SimState.new_initial(1)
	var view := InspectionView.new(s)   # no roster
	var fd: FrameData = view.frame_data(0, 0)
	_true(fd != null, "frame_data returns a typed FrameData (empty) with no roster")
	_eq(fd.startup, 0, "empty frame_data has zero startup")
	var adv: AdvantageView = view.advantage()
	_true(adv != null, "advantage returns a typed AdvantageView")
	_eq(view.last_hit(), null, "last_hit is null before any hit resolves")
	_eq(view.projectiles().size(), 0, "projectiles empty in P0")


# --- helpers ----------------------------------------------------------------

## True if the object has any float-valued exported/script property, recursively
## through Dictionaries / Arrays it holds.
func _object_has_float(obj: Object) -> bool:
	for prop in obj.get_property_list():
		# Only inspect script variables (not built-in RefCounted noise).
		if not (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var v = obj.get(prop["name"])
		if _has_float(v):
			return true
	return false


func _has_float(v) -> bool:
	var t := typeof(v)
	if t == TYPE_FLOAT:
		return true
	if t == TYPE_PACKED_FLOAT32_ARRAY or t == TYPE_PACKED_FLOAT64_ARRAY:
		return true
	if t == TYPE_DICTIONARY:
		for k in v:
			if _has_float(k) or _has_float(v[k]):
				return true
		return false
	if t == TYPE_ARRAY:
		for e in v:
			if _has_float(e):
				return true
		return false
	return false
