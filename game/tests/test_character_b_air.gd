extends SceneTree

## Headless dev tests for character B's air toolkit + specials (TKT-P2-06):
## the three divekicks, the low slide (hard-knockdown oki), the arc projectile
## (three parabolas, one falls-in-front), the air normals, and the 2H-JC ->
## airdash pressure wiring. character-b.md criteria 4, B-1, B-2, B-3, B-5
## (headless-checkable parts); combat-resolution.md criterion 17.
##
## THE HARD LEGIBILITY CONSTRAINTS ARE THE BAR (this file's real job):
##   - B-1: the low slide's spacing-variable block advantage is instrument-
##     readable and formula-correct (Advantage.live).
##   - B-2: the falls-in-front arc-projectile oki has NO unblockable frame.
##   - B-3: the three divekick trajectories are genuinely, measurably distinct.
## B-4/B-5 and the exact trajectory/parabola numbers are provisional tuning
## (character-b.md's own staging note) — see docs/judgment-log.md.
##
## Run:  godot --headless --path game -s res://tests/test_character_b_air.gd
## Exits non-zero on any failure so a harness/CI can gate on it.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	ProjectileRegistry.clear()
	if _failures == 0:
		print("[test_character_b_air] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_character_b_air] FAIL — %d of %d checks failed" % [_failures, _checks])
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


func _gt(actual: int, floor_value: int, msg: String) -> void:
	_checks += 1
	if not (actual > floor_value):
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected > %s)" % [msg, str(actual), str(floor_value)])


func _run() -> void:
	_test_authored_as_data_air()

	# B-3: the three divekicks are distinguishable.
	_test_divekick_hang_durations_strictly_increase()
	_test_divekick_dive_vectors_differ_pairwise()
	_test_divekick_h_is_the_only_overhead()
	_test_divekick_reachable_in_air_and_lands_to_idle()
	_test_divekick_connects_on_hit()

	# B-1: low slide spacing-variable, instrument-readable, formula-correct advantage.
	_test_slide_is_a_low_hard_knockdown()
	_test_slide_spacing_variable_advantage_is_instrument_readable()

	# B-2: falls-in-front arc projectile oki — no unblockable frame.
	_test_arc_projectiles_are_guard_mid_by_construction()
	_test_arc_l_falls_closest_to_b_the_oki_version()
	_test_arc_and_strike_never_require_incompatible_defense()

	# Air normals carry the fall (criterion 4).
	_test_air_normals_carry_the_fall()

	# 2H-JC -> airdash pressure (needs no new authoring; verify it works).
	_test_2h_jump_cancel_into_airdash()

	# Knockdown-state catch-up (AD-043 elaboration; this pass's gap-close).
	_test_knockdown_state_wired_and_shared()

	# B-4 (provisional reaction-window floor; logged judgment call).
	_test_h_divekick_reaction_window_floor_placeholder()

	# Determinism / round-trip over the new content.
	_test_divekick_mid_flight_round_trip()
	_test_slide_mid_active_round_trip()

	_test_baked_tres_matches_builder_after_air_content()


# --- Scenario setup ----------------------------------------------------------

func _install() -> Character:
	var c: Character = CharacterB.build_character()
	MoveRegistry.install({CharacterB.CHAR_ID: c})
	return c


func _install_projectiles() -> void:
	ProjectileRegistry.install(CharacterB.build_projectile_registry())


func _two_char_state(gap_units: int = 40) -> SimState:
	_install()
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-800), FP.from_int(800), 0)
	s.players[0].character_id = CharacterB.CHAR_ID
	s.players[0].state_id = CharacterB.STATE_IDLE
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = CharacterB.CHAR_ID
	s.players[1].state_id = CharacterB.STATE_IDLE
	s.players[1].pos_x = FP.from_int(gap_units)
	s.players[1].facing = -1
	return s


func _roster() -> Dictionary:
	return {CharacterB.CHAR_ID: MoveRegistry.character(CharacterB.CHAR_ID)}


func _cleanup() -> void:
	MoveRegistry.clear()
	ProjectileRegistry.clear()


# --- Authored-as-data sanity (criterion 1) -----------------------------------

func _test_authored_as_data_air() -> void:
	var c := CharacterB.build_character()
	_true(c.reaction_state(MoveState.REACTION_KNOCKDOWN) != 0, "character B declares a REACTION_KNOCKDOWN reaction (AD-043 catch-up, folded into AD-049's reaction_map)")
	var slide: MoveState = c.get_state(CharacterB.STATE_SLIDE)
	_true(slide != null, "the low slide is authored")
	var arc_l: MoveState = c.get_state(CharacterB.STATE_ARC_L)
	_true(arc_l != null, "the arc projectile (L) is authored")
	var dk_h: MoveState = c.get_state(CharacterB.STATE_DIVEKICK_H)
	_true(dk_h != null, "the H divekick is authored")
	var jl: MoveState = c.get_state(CharacterB.STATE_JL)
	_true(jl != null, "j.L is authored")
	for st in c.states:
		_true(st.has_valid_category(), "state %d declares a valid engine-level category" % st.id)


# --- Divekick helpers ---------------------------------------------------------

## Drive P0 into a neutral jump, let it gain REAL altitude (mirrors how a
## divekick is actually used in play -- jump up, then dive down, not dive at
## the instant of takeoff), then hold DOWN+`button_bit` until the divekick
## state is entered (or `max_ticks` elapses). Returns the resulting SimState;
## caller checks state_id to confirm the divekick was actually reached.
##
## ALTITUDE MATTERS (discovered during test authoring, logged docs/judgment-
## log.md): the divekick's hang keyframe sets vel_y to a small fixed value
## every tick, so a divekick triggered at the literal instant of takeoff (near-
## zero height) can run the continuous ground clamp INTO the floor partway
## through its own hang (especially H's 16-frame hang) — an authoring/test
## reality, not an engine bug: a divekick needs the jump's own apex height
## under it, exactly like a real player would use one.
func _jump_then_divekick(target_state: int, button_bit: int, max_ticks: int = 40,
		altitude_ticks: int = 20) -> SimState:
	var s := _two_char_state(300)   # far apart -- isolates the divekick's own physics
	for _k in range(altitude_ticks):
		s = SimState.step(s, InputFrame.UP, InputFrame.NEUTRAL)
	for _k in range(max_ticks):
		s = SimState.step(s, InputFrame.DOWN | button_bit, InputFrame.NEUTRAL)
		if s.players[0].state_id == target_state:
			break
	return s


## Step `ticks` more times (both neutral) and return the trace of
## (frame_in_state, vel_x, vel_y) tuples, one per tick.
func _trace_divekick(s: SimState, ticks: int) -> Array:
	var out: Array = []
	for _k in range(ticks):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		out.append([s.players[0].frame_in_state, s.players[0].vel_x, s.players[0].vel_y, s.players[0].state_id])
	return out


## The tick (1-indexed frame_in_state) at which vel_y first exceeds
## `threshold` while still in `target_state` — marks the dive impulse taking
## effect (comfortably above the hang's small gravity-drift velocity).
func _first_dive_frame(trace: Array, target_state: int, threshold: int) -> int:
	for row in trace:
		if row[3] != target_state:
			continue
		if row[2] > threshold:
			return row[0]
	return -1


func _test_divekick_hang_durations_strictly_increase() -> void:
	# Data-level: the authored constants themselves.
	_true(CharacterB.DIVEKICK_L_HANG < CharacterB.DIVEKICK_M_HANG, "L's hang < M's hang (authored)")
	_true(CharacterB.DIVEKICK_M_HANG < CharacterB.DIVEKICK_H_HANG, "M's hang < H's hang (authored) -- H's long hang is the overhead tell")

	# Dynamic: measured through the real engine (a small threshold comfortably
	# above the ~1-gravity-unit hang drift, comfortably below any dive impulse).
	var threshold: int = FP.from_units(3.0)
	var s_l := _jump_then_divekick(CharacterB.STATE_DIVEKICK_L, InputFrame.BUTTON_0)
	_eq(s_l.players[0].state_id, CharacterB.STATE_DIVEKICK_L, "reached the L divekick (setup)")
	var dive_l: int = _first_dive_frame(_trace_divekick(s_l, 20), CharacterB.STATE_DIVEKICK_L, threshold)

	var s_m := _jump_then_divekick(CharacterB.STATE_DIVEKICK_M, InputFrame.BUTTON_1)
	_eq(s_m.players[0].state_id, CharacterB.STATE_DIVEKICK_M, "reached the M divekick (setup)")
	var dive_m: int = _first_dive_frame(_trace_divekick(s_m, 20), CharacterB.STATE_DIVEKICK_M, threshold)

	var s_h := _jump_then_divekick(CharacterB.STATE_DIVEKICK_H, InputFrame.BUTTON_2)
	_eq(s_h.players[0].state_id, CharacterB.STATE_DIVEKICK_H, "reached the H divekick (setup)")
	var dive_h: int = _first_dive_frame(_trace_divekick(s_h, 25), CharacterB.STATE_DIVEKICK_H, threshold)

	_true(dive_l != -1 and dive_m != -1 and dive_h != -1, "all three divekicks measurably dive (setup)")
	_true(dive_l < dive_m, "the L divekick's dive fires measurably EARLIER than M's (through the real engine)")
	_true(dive_m < dive_h, "the M divekick's dive fires measurably EARLIER than H's (through the real engine) -- H's tell is the longest")
	_cleanup()


func _test_divekick_dive_vectors_differ_pairwise() -> void:
	# The authored dive vectors (vx, vy) are pairwise distinct (B-3: "hang
	# duration + dive vector differ").
	var vx := [CharacterB.DIVEKICK_L_DIVE_VX, CharacterB.DIVEKICK_M_DIVE_VX, CharacterB.DIVEKICK_H_DIVE_VX]
	var vy := [CharacterB.DIVEKICK_L_DIVE_VY, CharacterB.DIVEKICK_M_DIVE_VY, CharacterB.DIVEKICK_H_DIVE_VY]
	for i in range(3):
		for j in range(3):
			if i == j:
				continue
			_true(vx[i] != vy[j] or vx[i] != vx[j], "trajectory %d and %d are not identical" % [i, j])
	_true(vx[0] != vx[1] and vx[1] != vx[2] and vx[0] != vx[2], "dive horizontal speeds are pairwise distinct across L/M/H")
	_true(vy[0] != vy[1] and vy[1] != vy[2] and vy[0] != vy[2], "dive vertical speeds are pairwise distinct across L/M/H")
	_true(vx[2] == 0.0, "H's dive is near-vertical (zero authored horizontal component) -- character-b.md's own phrase")


func _test_divekick_h_is_the_only_overhead() -> void:
	var c := CharacterB.build_character()
	for pair in [[CharacterB.STATE_DIVEKICK_L, HitBox.GUARD_MID], [CharacterB.STATE_DIVEKICK_M, HitBox.GUARD_MID],
			[CharacterB.STATE_DIVEKICK_H, HitBox.GUARD_HIGH]]:
		var m: MoveState = c.get_state(pair[0])
		var found: bool = false
		for kf in m.timeline:
			for hb in kf.hitboxes:
				if hb.guard_height == pair[1]:
					found = true
		_true(found, "divekick state %d is authored guard_height=%d" % [pair[0], pair[1]])


func _test_divekick_reachable_in_air_and_lands_to_idle() -> void:
	var s := _jump_then_divekick(CharacterB.STATE_DIVEKICK_L, InputFrame.BUTTON_0)
	_eq(s.players[0].state_id, CharacterB.STATE_DIVEKICK_L, "the L divekick is reachable from a neutral jump via DOWN+L (2+attack in air)")
	var landed: bool = false
	for _k in range(60):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[0].state_id == CharacterB.STATE_IDLE:
			landed = true
			break
	_true(landed, "the divekick lands flush back to idle under the continuous ground clamp (AD-043) -- no bespoke landing state")
	_cleanup()


func _test_divekick_connects_on_hit() -> void:
	# Place a defender directly under B and confirm the divekick's active
	# hitbox actually hits during its (brief-hang, fast) plummet. Uses L (a
	# modest jump-up altitude, matching an actual jump-in use, rather than
	# H's much longer hang, which would still be descending from a great
	# height when its own short active window ends — a modest altitude keeps
	# the active window's height in reach of a grounded opponent, exactly how
	# a divekick is used in play).
	var s := _jump_then_divekick(CharacterB.STATE_DIVEKICK_L, InputFrame.BUTTON_0, 40, 7)
	_eq(s.players[0].state_id, CharacterB.STATE_DIVEKICK_L, "reached the L divekick (setup)")
	s.players[1].pos_x = s.players[0].pos_x   # directly beneath B's jump-up point
	var connected: bool = false
	for _k in range(40):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[0].move_contact == PlayerState.CONTACT_HIT or s.players[0].move_contact == PlayerState.CONTACT_BLOCK:
			connected = true
			break
		if s.players[0].state_id == CharacterB.STATE_IDLE:
			break
	_true(connected, "the L divekick's active hitbox actually connects during its plummet")
	_cleanup()


# --- Low slide: B-1 -----------------------------------------------------------

func _test_slide_is_a_low_hard_knockdown() -> void:
	var c := CharacterB.build_character()
	var m: MoveState = c.get_state(CharacterB.STATE_SLIDE)
	var found_low: bool = false
	var hit_reaction: int = -1
	for kf in m.timeline:
		for hb in kf.hitboxes:
			if hb.guard_height == HitBox.GUARD_LOW:
				found_low = true
			hit_reaction = hb.hit_reaction
	_true(found_low, "the low slide is authored guard_height=LOW (must be crouch-blocked)")
	_eq(hit_reaction, MoveState.REACTION_KNOCKDOWN, "the slide's hit_reaction is the REACTION_KNOCKDOWN kind (AD-049), which B's own reaction_map routes DIRECTLY into the shared knockdown state (AD-043, no air trip)")
	_true(m.is_crouch, "the slide is authored crouched throughout (matches the LOW's animation, AD-045)")


## Drive the slide against a defender at `gap`, holding crouch-block
## throughout; returns {contact_frame, adv_value} once it connects (or
## contact_frame == -1 if it never does within the budget).
func _slide_block_at_gap(gap: int) -> Dictionary:
	var s := _two_char_state(gap)
	s.players[0].state_id = CharacterB.STATE_SLIDE
	s.players[0].frame_in_state = 0
	s.players[1].state_id = CharacterB.STATE_CROUCH
	var contact_frame: int = -1
	for _k in range(CharacterB.SLIDE_STARTUP + CharacterB.SLIDE_ACTIVE + CharacterB.SLIDE_RECOVERY):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.DOWN | InputFrame.RIGHT)   # P1 faces -1; back = RIGHT
		if s.players[0].move_contact == PlayerState.CONTACT_BLOCK:
			contact_frame = s.players[0].frame_in_state
			break
	var adv := Advantage.live(s, _roster())
	return {"contact_frame": contact_frame, "adv_value": adv.value, "plus_player": adv.plus_player}


func _test_slide_spacing_variable_advantage_is_instrument_readable() -> void:
	# Two spacings chosen so the slide's single moving hitbox connects on
	# genuinely DIFFERENT active frames (near = early active frame, far = late
	# active frame) -- character-b.md's own mechanism, verified through the
	# real engine (values discovered by a headless probe during development,
	# not hand-derived — see docs/judgment-log.md).
	var near := _slide_block_at_gap(40)
	var far := _slide_block_at_gap(95)
	_true(near["contact_frame"] != -1, "the near-spacing slide connects (block) within budget")
	_true(far["contact_frame"] != -1, "the far-spacing slide connects (block) within budget")
	_true(near["contact_frame"] != far["contact_frame"],
		"the two spacings cause contact on DIFFERENT active frames (%s vs %s) -- the spacing-dependence itself" % [near["contact_frame"], far["contact_frame"]])
	_true(near["adv_value"] != far["adv_value"],
		"the two spacings produce DIFFERENT live block advantage (%s vs %s) -- instrument-readable (B-1)" % [near["adv_value"], far["adv_value"]])
	_true(far["contact_frame"] > near["contact_frame"], "the far spacing connects on a LATER active frame (setup for the formula-direction check)")
	_true(far["adv_value"] > near["adv_value"],
		"a LATER active-frame contact leaves the attacker LESS remaining recovery -> a HIGHER (better) live advantage -- formula-correct per AD-008 (character-b.md's own stated mechanism)")
	_cleanup()


# --- Arc projectile: B-2 -------------------------------------------------------

func _test_arc_projectiles_are_guard_mid_by_construction() -> void:
	# Logged judgment call (B-2/AD-047): ALL three strengths are authored
	# GUARD_MID (blockable from either stance, test_guard_height.gd's own
	# `_test_mid_blocked_either_stance`) so the projectile can NEVER be in an
	# "opposite guard_height" conflict with any simultaneous B strike -- the
	# no-unblockable invariant holds BY CONSTRUCTION, not by timing.
	var reg: Dictionary = CharacterB.build_projectile_registry()
	for proj_id in [CharacterB.PROJ_ARC_L, CharacterB.PROJ_ARC_M, CharacterB.PROJ_ARC_H]:
		var data: ProjectileData = reg[proj_id]
		_eq(data.hitbox.guard_height, HitBox.GUARD_MID, "arc projectile %d is authored guard_height=MID" % proj_id)
		_true(data.gravity != 0, "arc projectile %d has nonzero gravity (a genuine parabola, AD-047)" % proj_id)


func _test_arc_l_falls_closest_to_b_the_oki_version() -> void:
	# Logged judgment call: L is the designated "falls right in front" oki
	# version (the brief does not name which strength) -- verified by running
	# each strength to its own ground-contact despawn and comparing final
	# landing distance from B.
	_install()
	_install_projectiles()
	var landing_x: Dictionary = {}
	for cast_state in [CharacterB.STATE_ARC_L, CharacterB.STATE_ARC_M, CharacterB.STATE_ARC_H]:
		var s := SimState.new_initial()
		s.stage = StageState.new_initial(FP.from_int(-1000), FP.from_int(1000), 0)
		s.players[0].character_id = CharacterB.CHAR_ID
		s.players[0].state_id = cast_state
		s.players[0].pos_x = FP.from_int(0)
		s.players[0].facing = 1
		s.players[1].character_id = CharacterB.CHAR_ID
		s.players[1].state_id = CharacterB.STATE_IDLE
		s.players[1].pos_x = FP.from_int(900)   # far out of reach -- isolates the projectile's own arc
		s.players[1].facing = -1
		var last_x: int = 0
		for _k in range(300):
			s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
			if s.projectiles.size() > 0:
				last_x = s.projectiles[0].pos_x
			elif last_x != 0:
				break   # despawned -- last_x holds its final in-flight position
		landing_x[cast_state] = last_x
	_true(landing_x[CharacterB.STATE_ARC_L] < landing_x[CharacterB.STATE_ARC_M],
		"L's arc lands closer to B than M's (L is the falls-in-front oki version)")
	_true(landing_x[CharacterB.STATE_ARC_M] < landing_x[CharacterB.STATE_ARC_H],
		"M's arc lands closer to B than H's (H is the longest-reach air-space-control version)")
	_true(landing_x[CharacterB.STATE_ARC_L] < FP.from_int(150),
		"L's arc lands close enough to B to be a genuine 'falls right in front' setup (< 150 units)")
	_cleanup()


func _test_arc_and_strike_never_require_incompatible_defense() -> void:
	# B-2's dynamic proof: a live arc-projectile hit and a genuine LOW strike
	# (2L) both resolve as BLOCKED against the SAME held stance (crouch-block),
	# with no stance switch in between -- never an unblockable, never a forced
	# stance guess between the two threats.
	_install()
	var reg: Dictionary = CharacterB.build_projectile_registry()
	ProjectileRegistry.install(reg)
	var data: ProjectileData = reg[CharacterB.PROJ_ARC_L]

	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = CharacterB.CHAR_ID
	s.players[0].state_id = CharacterB.STATE_IDLE
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = CharacterB.CHAR_ID
	s.players[1].state_id = CharacterB.STATE_CROUCH
	s.players[1].pos_x = FP.from_int(35)
	s.players[1].facing = -1

	# A live projectile placed right at the defender (the falls-in-front oki
	# moment) -- defender crouch-blocking (DOWN + back; P1 faces -1, back=RIGHT).
	var pr := Projectile.spawn(0, CharacterB.PROJ_ARC_L, data, FP.from_int(35), FP.from_int(-30), 0, 0, 1)
	s.projectiles.append(pr)
	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.DOWN | InputFrame.RIGHT)
	_true(s.last_hit != null, "the projectile connected (setup)")
	_true(s.last_hit.was_block, "the projectile is BLOCKED by the crouching defender")
	_true(s.last_hit.block_valid, "the projectile's block was stance-valid")

	# The SAME defender, STILL crouch-blocking (no stance switch), now also
	# blocks a genuine LOW strike (2L) from B.
	s.players[0].state_id = CharacterB.STATE_2L
	s.players[0].frame_in_state = 0
	var connected: bool = false
	for _k in range(10):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.DOWN | InputFrame.RIGHT)
		if s.players[0].move_contact == PlayerState.CONTACT_BLOCK:
			connected = true
			break
	_true(connected, "2L connects (setup)")
	_true(s.last_hit.was_block, "2L is ALSO blocked by the SAME held stance -- no incompatible defense was ever required (B-2)")
	_cleanup()


# --- Air normals carry the fall (criterion 4) ---------------------------------

## FIXED 2026-07-17 (flags.md, "AD-043 air-move semantics", a false-green):
## the PRIOR version of this test only checked ONE tick of vel_y right after
## the cancel, then looped until STATE_IDLE was reached and called that
## "landed" — a duration-based early snap to the floor (the exact "air normal
## snaps to the ground" defect) reaches STATE_IDLE too, just much sooner and
## via a teleport rather than physical descent, so that assertion could not
## fail against the real defect. This version compares against an
## UNINTERRUPTED reference jump's own physical landing tick: j.L authors no
## motion of its own (pure inherit, AD-043), so cancelling into it must not
## change WHEN B lands at all.
func _test_air_normals_carry_the_fall() -> void:
	# Reference: an uninterrupted jump's own physical landing tick.
	var s_ref := _two_char_state(300)
	for _k in range(8):
		s_ref = SimState.step(s_ref, InputFrame.UP, InputFrame.NEUTRAL)
		if s_ref.players[0].state_id == CharacterB.STATE_JUMP_N:
			break
	_eq(s_ref.players[0].state_id, CharacterB.STATE_JUMP_N, "airborne in the neutral jump arc (reference setup)")
	var reference_landed_tick: int = -1
	for k in range(80):
		s_ref = SimState.step(s_ref, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s_ref.players[0].state_id == CharacterB.STATE_IDLE:
			reference_landed_tick = k + 1
			break
	_true(reference_landed_tick != -1, "an uncancelled jump lands within 80 ticks (reference setup)")

	var s := _two_char_state(300)
	for _k in range(8):
		s = SimState.step(s, InputFrame.UP, InputFrame.NEUTRAL)
		if s.players[0].state_id == CharacterB.STATE_JUMP_N:
			break
	_eq(s.players[0].state_id, CharacterB.STATE_JUMP_N, "airborne in the neutral jump arc (setup)")
	var vy_before: int = s.players[0].vel_y
	s = SimState.step(s, InputFrame.BUTTON_0, InputFrame.NEUTRAL)   # j.L (raw button, no button_map entry needed)
	_eq(s.players[0].state_id, CharacterB.STATE_JL, "the jump arc cancels into j.L on a bare button press")
	# The arc's ongoing velocity carries through unbroken -- no motion authored
	# on j.L means it INHERITS (AD-043), so vel_y this tick is the prior
	# velocity plus one more tick of gravity (never reset/stopped).
	_eq(s.players[0].vel_y, vy_before + MoveRegistry.character(CharacterB.CHAR_ID).physics.gravity,
		"j.L inherits the ongoing vertical velocity (+gravity) -- does not stop the jump arc")

	# THE REAL DEFECT CHECK: drive it all the way to landing and confirm it
	# lands on the EXACT SAME physical tick the reference jump did. Counted
	# from the SAME basis as reference_landed_tick (the tick JUMP_N was first
	# observed) -- the cancel step just above already consumed one tick of that
	# count, so it is added back in here (+1) rather than re-zeroed.
	var landed_tick: int = -1
	for k in range(80):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[0].state_id == CharacterB.STATE_IDLE:
			landed_tick = 1 + k + 1   # +1 for the cancel-input tick already taken above
			break
	_true(landed_tick != -1, "after j.L, B's jump still lands (setup)")
	_eq(landed_tick, reference_landed_tick,
		"cancelling into j.L lands on the EXACT SAME physical tick as an uninterrupted jump -- the " +
		"fall is carried all the way to the real ground clamp, not clipped by j.L's own short " +
		"authored duration (the 'air normal snaps to the floor' defect, flags.md 2026-07-17)")
	_eq(s.players[0].pos_y, s.stage.ground_y, "landing lands EXACTLY at ground_y via the continuous clamp, not a mid-air snap")
	_cleanup()


# --- 2H-JC -> airdash (needs no new authoring; verify it works) --------------

func _test_2h_jump_cancel_into_airdash() -> void:
	var s := _two_char_state(40)
	s.players[0].state_id = CharacterB.STATE_2H
	s.players[0].frame_in_state = 0
	var block_connected: bool = false
	for _k in range(14):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.RIGHT)
		if s.players[0].move_contact == PlayerState.CONTACT_BLOCK:
			block_connected = true
			break
	_true(block_connected, "2H connects on block (setup)")
	for _k in range(30):
		s = SimState.step(s, InputFrame.UP, InputFrame.RIGHT)
		if s.players[0].state_id == CharacterB.STATE_JUMP_N:
			break
	_eq(s.players[0].state_id, CharacterB.STATE_JUMP_N, "2H's on-block jump-cancel carries B into the neutral jump arc (setup)")
	_false(s.players[0].air_action_used, "the air action is still unspent on takeoff (setup)")
	# Double-tap forward (press -> release -> press) while airborne: the
	# GENERIC air-action economy (AD-046) applies to ANY physically-airborne
	# player with air_dash_speed != 0 -- no B-specific authoring needed for
	# this to fire once airborne.
	s = SimState.step(s, InputFrame.RIGHT, InputFrame.RIGHT)
	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.RIGHT)
	s = SimState.step(s, InputFrame.RIGHT, InputFrame.RIGHT)
	_true(s.players[0].air_action_used, "the air dash spent B's one air action")
	var expected_vx: int = MoveRegistry.character(CharacterB.CHAR_ID).physics.air_dash_speed
	_eq(s.players[0].vel_x, expected_vx, "the air dash set B's horizontal velocity to physics.air_dash_speed -- 2H-JC -> airdash pressure works with NO new authoring")
	_cleanup()


# --- Knockdown-state catch-up (AD-043 elaboration) ---------------------------

func _test_knockdown_state_wired_and_shared() -> void:
	var c := CharacterB.build_character()
	_eq(c.reaction_state(MoveState.REACTION_KNOCKDOWN), CharacterB.STATE_KNOCKDOWN, "Character.reaction_map[REACTION_KNOCKDOWN] is set (AD-049 fold-in of the old knockdown_state_id)")

	# 2H's launch lands into the SAME shared knockdown state (via StepPhases._land).
	var s := _two_char_state(40)
	s.players[0].state_id = CharacterB.STATE_2H
	s.players[0].frame_in_state = 0
	var hit_connected: bool = false
	for _k in range(14):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[0].move_contact == PlayerState.CONTACT_HIT:
			hit_connected = true
			break
	_true(hit_connected, "2H connects on hit (setup)")
	_eq(s.players[1].state_id, CharacterB.STATE_HITSTUN_LAUNCH, "victim launches (setup)")
	var landed_into_knockdown: bool = false
	for _k in range(80):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[1].state_id == CharacterB.STATE_KNOCKDOWN:
			landed_into_knockdown = true
			break
	_true(landed_into_knockdown, "2H's launch lands into the SAME shared knockdown state as the throw and the slide (AD-043 elaboration)")
	_cleanup()


# --- B-4 (provisional; reaction-window floor placeholder) --------------------

const REACTION_WINDOW_FLOOR_TICKS: int = 12   # Strategist feel value placeholder
											   # (provisional, like AirHeightScaling
											   # -- logged docs/judgment-log.md);
											   # the MECHANISM below is the contract.

func _test_h_divekick_reaction_window_floor_placeholder() -> void:
	# The delay from H-divekick's OWN state entry (the earliest on-screen frame
	# that distinguishes it -- entering a different state than L/M) to its
	# first active frame is a FIXED property of the state's own authored
	# timeline (hang + one dive-impulse frame), independent of how the
	# sequence reached it (a direct jump, an airdash first, a 2H-JC first,
	# etc. all enter the SAME state and inherit the SAME interval) -- so one
	# measurement bounds every route (character-b.md B-4's mechanism).
	var active_start: int = CharacterB.DIVEKICK_H_HANG + 1 + 1   # hang frames + the 1-frame
																   # dive impulse + 1 (active starts
																   # the frame AFTER the dive impulse)
	_gt(active_start, REACTION_WINDOW_FLOOR_TICKS,
		"H-divekick's entry-to-active-hitbox delay (%d ticks) exceeds the provisional reaction-window floor (%d) -- settles at the human gate" % [active_start, REACTION_WINDOW_FLOOR_TICKS])

	# Confirm dynamically through the real engine too (not just the arithmetic).
	var s := _jump_then_divekick(CharacterB.STATE_DIVEKICK_H, InputFrame.BUTTON_2)
	_eq(s.players[0].state_id, CharacterB.STATE_DIVEKICK_H, "reached H divekick (setup)")
	var entered_tick: int = s.tick
	var active_tick: int = -1
	for _k in range(30):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[0].move_contact != PlayerState.CONTACT_NONE or s.players[0].frame_in_state == active_start:
			active_tick = s.tick
			break
	_true(active_tick != -1, "H divekick reaches its own active frame within budget (setup)")
	_gt(active_tick - entered_tick, REACTION_WINDOW_FLOOR_TICKS - 1,
		"the measured entry-to-active delay through the real engine also clears the provisional floor")
	_cleanup()


# --- Determinism / round-trip over the new content ---------------------------

func _test_divekick_mid_flight_round_trip() -> void:
	var s := _jump_then_divekick(CharacterB.STATE_DIVEKICK_M, InputFrame.BUTTON_1)
	_eq(s.players[0].state_id, CharacterB.STATE_DIVEKICK_M, "reached M divekick (setup)")
	for _k in range(3):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	var hash_before: int = s.hash_state()
	var blob: Dictionary = s.to_dict()
	var restored: SimState = SimState.from_dict(blob)
	_eq(restored.hash_state(), hash_before, "a mid-divekick snapshot restores to an identical canonical hash")
	var cont_orig: SimState = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	var cont_restored: SimState = SimState.step(restored, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(cont_restored.hash_state(), cont_orig.hash_state(), "stepping the restored mid-divekick state matches stepping the original")
	_cleanup()


func _test_slide_mid_active_round_trip() -> void:
	var s := _two_char_state(95)
	s.players[0].state_id = CharacterB.STATE_SLIDE
	s.players[0].frame_in_state = CharacterB.SLIDE_STARTUP   # entering the active window next tick
	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.DOWN | InputFrame.RIGHT)
	var hash_before: int = s.hash_state()
	var blob: Dictionary = s.to_dict()
	var restored: SimState = SimState.from_dict(blob)
	_eq(restored.hash_state(), hash_before, "a mid-slide-active snapshot restores to an identical canonical hash")
	var cont_orig: SimState = SimState.step(s, InputFrame.NEUTRAL, InputFrame.DOWN | InputFrame.RIGHT)
	var cont_restored: SimState = SimState.step(restored, InputFrame.NEUTRAL, InputFrame.DOWN | InputFrame.RIGHT)
	_eq(cont_restored.hash_state(), cont_orig.hash_state(), "stepping the restored mid-slide state matches stepping the original")
	_cleanup()


# --- Golden-able authoring: the baked .tres matches the builder --------------

func _test_baked_tres_matches_builder_after_air_content() -> void:
	var baked := ResourceLoader.load("res://data/character-b.tres", "Resource", ResourceLoader.CACHE_MODE_IGNORE) as Character
	_true(baked != null, "data/character-b.tres loads as a Character")
	if baked == null:
		return
	var built := CharacterB.build_character()
	_eq(baked.states.size(), built.states.size(), "baked .tres has the same state count as the builder (post air-content)")
	_eq(baked.button_map.size(), built.button_map.size(), "baked .tres has the same button_map size as the builder")
	_eq(baked.reaction_state(MoveState.REACTION_KNOCKDOWN), built.reaction_state(MoveState.REACTION_KNOCKDOWN), "baked .tres carries the same REACTION_KNOCKDOWN mapping as the builder")
