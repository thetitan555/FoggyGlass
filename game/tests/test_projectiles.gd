extends SceneTree

## Headless test for the projectile entity system (TKT-P1-0P).
## combat-resolution.md "Projectiles"; move-format.md (spawn / Projectile);
## simulation.md (SimState.projectiles); inspection-surface.md (ProjectileView).
## AD-021 (projectiles are first-class serialized sim entities).
##
## Run:  godot --headless --path game -s res://tests/test_projectiles.gd
## Exits non-zero on any failure so a harness/CI can gate on it.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	ProjectileRegistry.clear()
	if _failures == 0:
		print("[test_projectiles] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_projectiles] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _false(cond: bool, msg: String) -> void:
	_eq(cond, false, msg)


func _run() -> void:
	_test_spawn_creates_projectile()
	_test_spawn_respects_per_owner_cap()
	_test_integration_moves_independently_of_owner()
	_test_projectile_hits_opponent()
	_test_projectile_blocked()
	_test_despawn_on_lifetime()
	_test_despawn_off_stage()
	_test_no_projectile_vs_projectile()
	_test_inspection_surface_reads_projectiles()
	_test_snapshot_restore_round_trips_projectiles()
	_test_no_floats_in_projectile_view()


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


# --- spawn --------------------------------------------------------------------

func _test_spawn_creates_projectile() -> void:
	var s := _two_char_state()
	s.players[0].state_id = TestSupport.STATE_FIREBALL
	s.players[0].frame_in_state = 0   # first step enters frame 1 cleanly
	var spawned: bool = false
	for _k in range(TestSupport.FIREBALL_SPAWN_FRAME + 1):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.projectiles.size() > 0:
			spawned = true
			break
	_true(spawned, "the spawn keyframe creates a live projectile")
	_eq(s.projectiles.size(), 1, "exactly one projectile spawned")
	var pr: Projectile = s.projectiles[0]
	_eq(pr.owner, 0, "the spawned projectile's owner is the spawning player")
	_eq(pr.data_id, TestSupport.PROJECTILE_DATA_ID, "the projectile's data_id matches the authored shell")
	_true(pr.hitbox != null, "the projectile's hitbox resolved from ProjectileRegistry")
	_eq(pr.lifetime_remaining, TestSupport.FIREBALL_LIFETIME, "lifetime starts at the authored value")
	_teardown()


func _test_spawn_respects_per_owner_cap() -> void:
	# AD-021 / move-format.md Keyframe.spawn: "if the cap is full the spawn is
	# suppressed." FIREBALL_MAX_PER_OWNER == 1: spawning FIREBALL twice in a row
	# (before the first projectile despawns) must NOT create a second projectile.
	# Keep P1 far away so the first fireball travels its whole lifetime without
	# connecting (isolates the cap mechanic from hit-consumption).
	var s := _two_char_state(390)
	s.players[0].state_id = TestSupport.STATE_FIREBALL
	s.players[0].frame_in_state = 0
	# Drive through the first spawn + full recovery, then fire again immediately.
	for _k in range(20):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(s.projectiles.size(), 1, "one projectile live after the first cast")
	# Re-enter FIREBALL and drive to its spawn frame again while the first
	# projectile is still alive (lifetime 40 easily outlives the move's recovery).
	s.players[0].state_id = TestSupport.STATE_FIREBALL
	s.players[0].frame_in_state = 0
	for _k in range(TestSupport.FIREBALL_SPAWN_FRAME + 1):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(s.projectiles.size(), 1, "cap suppresses a second spawn while one is still live (max_per_owner=1)")
	_teardown()


# --- integration ----------------------------------------------------------------

func _test_integration_moves_independently_of_owner() -> void:
	# AD-021: "integrates each tick independently of the owner" — a projectile
	# keeps traveling even after the owner's move ends and the owner stops moving.
	var s := _two_char_state(200)   # keep P1 far away so the fireball doesn't connect yet
	s.players[0].state_id = TestSupport.STATE_FIREBALL
	s.players[0].frame_in_state = 0
	for _k in range(TestSupport.FIREBALL_SPAWN_FRAME + 1):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(s.projectiles.size() > 0, "projectile spawned (pre-check)")
	var pos_after_spawn: int = s.projectiles[0].pos_x
	var owner_pos_before: int = s.players[0].pos_x

	# Let the owner's move fully end (return to idle) while the projectile travels.
	for _k in range(20):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(s.projectiles.size() > 0, "projectile still alive (lifetime not yet elapsed)")
	_true(s.projectiles[0].pos_x > pos_after_spawn,
		"projectile kept moving forward after the owner's move ended")
	_eq(s.players[0].state_id, TestSupport.STATE_IDLE, "the owner has returned to idle")
	_eq(s.players[0].pos_x, owner_pos_before,
		"the owner did not move (idle has no motion) while the projectile traveled independently")
	_teardown()


# --- hit / block resolution ------------------------------------------------------

func _test_projectile_hits_opponent() -> void:
	var s := _two_char_state(60)
	s.players[0].state_id = TestSupport.STATE_FIREBALL
	s.players[0].frame_in_state = 0
	var hit: bool = false
	for _k in range(40):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[1].stun_kind == PlayerView.STUN_HIT and s.players[1].stun > 0:
			hit = true
			break
	_true(hit, "the projectile connects and puts the defender in hitstun")
	_true(s.players[1].health < 1000, "the projectile dealt damage")
	_eq(s.players[1].health, 1000 - TestSupport.FIREBALL_DAMAGE, "damage matches the authored fireball damage")
	# Consumed on hit (AD-021): the projectile despawns the tick it connects.
	_eq(s.projectiles.size(), 0, "the projectile is consumed (despawned) on hit")
	# Attribution: the hit is credited to the projectile's owner via last_hit.
	_true(s.last_hit != null, "last_hit recorded")
	_eq(s.last_hit.attacker, 0, "last_hit attributes the projectile's hit to its owner")
	_eq(s.last_hit.defender, 1, "last_hit names the correct defender")
	_false(s.last_hit.was_block, "this contact was a hit, not a block")
	_teardown()


func _test_projectile_blocked() -> void:
	# P1 holds back the whole time (P1 faces -1, so "back" is raw RIGHT).
	var s := _two_char_state(60)
	s.players[0].state_id = TestSupport.STATE_FIREBALL
	s.players[0].frame_in_state = 0
	var blocked: bool = false
	for _k in range(40):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.RIGHT)
		if s.players[1].stun_kind == PlayerView.STUN_BLOCK and s.players[1].stun > 0:
			blocked = true
			break
	_true(blocked, "the projectile is blocked (defender enters blockstun)")
	_eq(s.players[1].health, 1000, "a blocked projectile deals no chip damage at P0 (no-chip slice rule)")
	_eq(s.projectiles.size(), 0, "the projectile is consumed (despawned) on block, same as on hit")
	_true(s.last_hit != null, "last_hit recorded for the block")
	_true(s.last_hit.was_block, "last_hit records was_block true")
	_teardown()


# --- despawn ----------------------------------------------------------------

func _test_despawn_on_lifetime() -> void:
	# Keep P1 far enough away that the projectile never connects; it must despawn
	# once its lifetime elapses.
	var s := _two_char_state(390)
	s.players[0].state_id = TestSupport.STATE_FIREBALL
	s.players[0].frame_in_state = 0
	for _k in range(TestSupport.FIREBALL_SPAWN_FRAME + 1):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(s.projectiles.size() > 0, "projectile spawned (pre-check)")
	var lifetime_at_spawn: int = s.projectiles[0].lifetime_remaining
	for _k in range(lifetime_at_spawn + 2):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(s.projectiles.size(), 0, "the projectile despawns once its lifetime elapses")
	_teardown()


func _test_despawn_off_stage() -> void:
	# A projectile that travels past the stage wall despawns (combat-resolution.md
	# "Projectiles": "despawns when lifetime elapses OR it leaves the stage").
	# P1 is kept FAR from the projectile's path (behind P0, off to the left) so
	# only the off-stage condition can end the projectile — never a hit/block
	# consumption — isolating this despawn cause from the hit-resolution one. P0
	# is placed with room between it and the wall so the spawned projectile is
	# observably ALIVE for a beat before it travels off-stage (rather than
	# spawning already at the boundary, which despawns on its very next
	# integration tick and makes the "still alive" pre-check timing-fragile).
	var s := _two_char_state()
	s.stage = StageState.new_initial(FP.from_int(-500), FP.from_int(100), 0)
	s.players[0].pos_x = FP.from_int(40)
	s.players[0].facing = 1
	s.players[1].pos_x = FP.from_int(-450)   # far to the left, well outside the fireball's path
	s.players[1].facing = 1
	s.players[0].state_id = TestSupport.STATE_FIREBALL
	s.players[0].frame_in_state = 0
	for _k in range(TestSupport.FIREBALL_SPAWN_FRAME + 1):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(s.projectiles.size() > 0, "projectile spawned with room before the wall (pre-check)")
	_eq(s.last_hit, null, "the projectile has not connected with anyone (pre-check, isolates off-stage)")
	var despawned_off_stage: bool = false
	for _k in range(TestSupport.FIREBALL_LIFETIME):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.projectiles.size() == 0:
			despawned_off_stage = true
			break
	_true(despawned_off_stage, "the projectile despawned before its lifetime elapsed (off-stage)")
	_eq(s.last_hit, null, "still no hit recorded — despawn was due to off-stage, not a connect")
	_teardown()


# --- no projectile-vs-projectile (deferred, AD-021) --------------------------

func _test_no_projectile_vs_projectile() -> void:
	# AD-021: "Projectile-vs-projectile interaction is out of slice scope." Spawn
	# one from each player heading toward each other, far enough apart that they
	# cross paths WELL BEFORE either reaches the opposing player, and confirm
	# BOTH survive that pass-through (neither is consumed by colliding with the
	# other — only a player-hurtbox connect consumes a projectile).
	# Gap chosen so the projectiles cross WELL before FIREBALL_LIFETIME elapses
	# (crossing distance / closing speed must leave headroom under the lifetime,
	# or the two events would be indistinguishable) and well before reaching
	# either player's hurtbox.
	var gap_units: int = 180
	var s := _two_char_state(gap_units)
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].state_id = TestSupport.STATE_FIREBALL
	s.players[0].frame_in_state = 0
	s.players[1].state_id = TestSupport.STATE_FIREBALL
	s.players[1].frame_in_state = 0
	for _k in range(TestSupport.FIREBALL_SPAWN_FRAME + 1):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(s.projectiles.size(), 2, "both players' projectiles spawned")
	_eq(s.last_hit, null, "neither projectile has connected with a player yet (pre-check)")

	var p0_pos_before_cross: int = s.projectiles[0].pos_x if s.projectiles[0].owner == 0 else s.projectiles[1].pos_x
	var p1_pos_before_cross: int = s.projectiles[1].pos_x if s.projectiles[0].owner == 0 else s.projectiles[0].pos_x
	_true(p0_pos_before_cross < p1_pos_before_cross, "P0's fireball starts left of P1's fireball (pre-check)")

	# Step forward enough ticks for the two projectiles to have crossed (they
	# start well inside the gap and close at FIREBALL_SPEED*2/tick), but well
	# under FIREBALL_LIFETIME and nowhere near reaching either player's hurtbox.
	# They start (gap_units - 2*spawn_offset) units apart, closing at
	# 2*FIREBALL_SPEED/tick.
	var starting_separation: int = gap_units - 2 * 20   # 20 = the authored spawn_offset_x
	var cross_ticks: int = int(starting_separation / (2 * TestSupport.FIREBALL_SPEED)) + 5
	_true(TestSupport.FIREBALL_SPAWN_FRAME + 1 + cross_ticks < TestSupport.FIREBALL_LIFETIME,
		"test sanity: crossing completes well before the fireball's lifetime elapses")
	for _k in range(cross_ticks):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(s.last_hit, null, "still no player-hit after crossing — this window is pure projectile-vs-projectile territory")
	_eq(s.projectiles.size(), 2, "BOTH projectiles survive passing through each other (no projectile-vs-projectile consumption)")

	# Confirm they actually crossed (swapped relative order), so this genuinely
	# exercised the pass-through case and isn't just "nothing happened yet."
	var final_owner0_x: int = -1
	var final_owner1_x: int = -1
	for pr in s.projectiles:
		if pr.owner == 0:
			final_owner0_x = pr.pos_x
		else:
			final_owner1_x = pr.pos_x
	_true(final_owner0_x > final_owner1_x,
		"the two projectiles have crossed paths (P0's fireball is now right of P1's)")
	_teardown()


# --- inspection surface -------------------------------------------------------

func _test_inspection_surface_reads_projectiles() -> void:
	var s := _two_char_state(60)
	s.players[0].state_id = TestSupport.STATE_FIREBALL
	s.players[0].frame_in_state = 0
	for _k in range(TestSupport.FIREBALL_SPAWN_FRAME + 1):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(s.projectiles.size() > 0, "projectile spawned (pre-check)")

	var view := InspectionView.new(s, TestSupport.build_roster())
	var views: Array[ProjectileView] = view.projectiles()
	_eq(views.size(), s.projectiles.size(), "InspectionView.projectiles() count matches sim truth")
	var pv: ProjectileView = views[0]
	var pr: Projectile = s.projectiles[0]
	_eq(pv.owner, pr.owner, "ProjectileView.owner equals sim truth")
	_eq(int(pv.position["x"]), pr.pos_x, "ProjectileView.position.x equals sim truth (fixed-point)")
	_eq(int(pv.position["y"]), pr.pos_y, "ProjectileView.position.y equals sim truth (fixed-point)")
	_eq(pv.lifetime_remaining, pr.lifetime_remaining, "ProjectileView.lifetime_remaining equals sim truth")
	_true(pv.box != null, "ProjectileView.box resolves a BoxView for the geometry overlay")
	_eq(pv.box.kind, BoxView.KIND_HIT, "the projectile's box is a HIT box")
	_true(not pv.box.hit.is_empty(), "the projectile's BoxView carries hit data")
	_eq(int(pv.box.hit["damage"]), TestSupport.FIREBALL_DAMAGE, "hit data damage matches the authored fireball")
	_teardown()


# --- serialization round-trip -------------------------------------------------

func _test_snapshot_restore_round_trips_projectiles() -> void:
	var s := _two_char_state(60)
	s.players[0].state_id = TestSupport.STATE_FIREBALL
	s.players[0].frame_in_state = 0
	for _k in range(TestSupport.FIREBALL_SPAWN_FRAME + 1):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(s.projectiles.size() > 0, "projectile spawned (pre-check)")

	var hash_before: int = s.hash_state()
	var blob: Dictionary = s.to_dict()
	var restored: SimState = SimState.from_dict(blob)
	_eq(restored.hash_state(), hash_before, "restored state hashes identically (round-trip)")
	_eq(restored.projectiles.size(), s.projectiles.size(), "restored projectile count matches")
	var rp: Projectile = restored.projectiles[0]
	var op: Projectile = s.projectiles[0]
	_eq(rp.owner, op.owner, "restored projectile owner matches")
	_eq(rp.data_id, op.data_id, "restored projectile data_id matches")
	_eq(rp.pos_x, op.pos_x, "restored projectile pos_x matches")
	_eq(rp.pos_y, op.pos_y, "restored projectile pos_y matches")
	_eq(rp.lifetime_remaining, op.lifetime_remaining, "restored projectile lifetime matches")
	_true(rp.hitbox != null, "restored projectile's hitbox RE-ATTACHED via ProjectileRegistry (AD-024)")
	_eq(rp.hitbox.damage, op.hitbox.damage, "re-attached hitbox carries the correct authored damage")

	# The restored state must continue identically to the original (Tenet 1's
	# "snapshot, advance, maybe restore" primitive applied to a state WITH a live
	# projectile).
	var continued_original: SimState = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	var continued_restored: SimState = SimState.step(restored, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(continued_restored.hash_state(), continued_original.hash_state(),
		"stepping the restored state matches stepping the original (determinism survives restore)")
	_teardown()


func _test_no_floats_in_projectile_view() -> void:
	var s := _two_char_state(60)
	s.players[0].state_id = TestSupport.STATE_FIREBALL
	s.players[0].frame_in_state = 0
	for _k in range(TestSupport.FIREBALL_SPAWN_FRAME + 1):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_true(s.projectiles.size() > 0, "projectile spawned (pre-check)")
	var view := InspectionView.new(s, TestSupport.build_roster())
	var pv: ProjectileView = view.projectiles()[0]
	_true(not _object_has_float(pv), "ProjectileView contains no float field (AD-019)")
	_teardown()


# --- helpers ------------------------------------------------------------------

func _object_has_float(obj: Object) -> bool:
	for prop in obj.get_property_list():
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
	if t == TYPE_OBJECT and v != null:
		return _object_has_float(v)
	return false
