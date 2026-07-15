extends SceneTree

## Headless test for invulnerability consumption (TKT-P1-11, AD-031).
## combat-resolution.md phase 4 + Invulnerability section + criterion 12;
## move-format.md (HitBox.hit_kind, Keyframe.invuln); inspection-surface.md
## (PlayerView.invuln, criteria 1 & 4); character-a.md criteria 4 & 6.
##
## Run:  godot --headless --path game -s res://tests/test_invuln.gd
## Exits non-zero on any failure so a harness/CI can gate on it.
##
## Drives CharacterA (game/content/character_a.gd) through the real
## SimState.step/InspectionView surface (AD-011), matching the same read path
## the training mode and QA's golden harness use.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	ProjectileRegistry.clear()
	if _failures == 0:
		print("[test_invuln] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_invuln] FAIL — %d of %d checks failed" % [_failures, _checks])
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
	_test_hit_kind_default_strike()
	_test_is_throw_is_hit_kind_throw()
	_test_projectile_hit_kind_is_projectile()
	_test_strike_whiffs_on_2h_invuln()
	_test_dp_h_throw_invuln_beats_a_throw()
	_test_dp_still_thrown_without_throw_invuln()
	_test_playerview_invuln_readable()
	_test_projectile_passes_through_invuln_and_connects_later()
	_test_gated_contact_no_combo_bookkeeping()


# --- Scenario setup ----------------------------------------------------------

func _install() -> void:
	MoveRegistry.install({CharacterA.CHAR_ID: CharacterA.build_character()})
	ProjectileRegistry.install(CharacterA.build_projectile_registry())


func _two_char_state(gap_units: int = 60) -> SimState:
	_install()
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = CharacterA.CHAR_ID
	s.players[0].state_id = CharacterA.STATE_IDLE
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = CharacterA.CHAR_ID
	s.players[1].state_id = CharacterA.STATE_IDLE
	s.players[1].pos_x = FP.from_int(gap_units)
	s.players[1].facing = -1
	return s


func _cleanup() -> void:
	MoveRegistry.clear()
	ProjectileRegistry.clear()


# --- HitBox.hit_kind / is_throw reconciliation -------------------------------

func _test_hit_kind_default_strike() -> void:
	var hb := HitBox.new()
	_eq(hb.hit_kind, HitBox.HIT_KIND_STRIKE, "HitBox.hit_kind defaults to STRIKE")
	_false(hb.is_throw, "a default HitBox is not a throw")


func _test_is_throw_is_hit_kind_throw() -> void:
	# Setting the legacy is_throw flag must flip hit_kind (and read back true) —
	# the same fact under two names (AD-031), not two drifting fields.
	var hb := HitBox.new()
	hb.is_throw = true
	_eq(hb.hit_kind, HitBox.HIT_KIND_THROW, "is_throw = true sets hit_kind to THROW")
	_true(hb.is_throw, "is_throw reads true after being set")
	# Setting hit_kind directly must also be reflected in is_throw.
	var hb2 := HitBox.new()
	hb2.hit_kind = HitBox.HIT_KIND_THROW
	_true(hb2.is_throw, "hit_kind = THROW makes is_throw read true")


func _test_projectile_hit_kind_is_projectile() -> void:
	var reg: Dictionary = CharacterA.build_projectile_registry()
	for data_id in reg.keys():
		var data: ProjectileData = reg[data_id]
		_eq(data.hitbox.hit_kind, HitBox.HIT_KIND_PROJECTILE,
			"character A's fireball data_id %d carries hit_kind PROJECTILE" % data_id)


# --- Character-hitbox invuln gate (phase 4) ----------------------------------

## A strike (5L) must WHIFF against the back dash's strike+throw invuln (frames
## 1-7): no damage/stun on the tick of overlap, and the attacker's move_contact
## resolves to WHIFF on the existing whiff edge once 5L's own active window
## elapses with no recorded connect (character-a.md criteria 4/6; combat-
## resolution.md criterion 12). Both players are state-injected directly onto
## their first active / invuln-covered frames (mirrors test_character_a.gd's
## direct-drive pattern) so the overlap tick is exact and hand-traceable. The
## back dash (no hitbox of its own) is used as the invuln taker rather than 2H
## so the defender cannot counter-hit the attacker mid-move and interrupt 5L's
## own whiff-edge accounting.
func _test_strike_whiffs_on_2h_invuln() -> void:
	var s := _two_char_state(35)
	s.players[0].state_id = CharacterA.STATE_5L
	s.players[0].frame_in_state = 4   # next tick -> 5, 5L's first active frame
	s.players[1].state_id = CharacterA.STATE_DASH_B
	s.players[1].frame_in_state = 0   # next tick -> 1, within invuln_strike (1-7)
	var defender_health_before: int = s.players[1].health
	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_false(s.players[1].stun_kind == PlayerView.STUN_HIT and s.players[1].stun > 0,
		"5L does not land hitstun on the back dash's invuln window (whiffed)")
	_eq(s.players[1].health, defender_health_before, "the back dash's invuln taker took no damage from the whiffed 5L")
	# Advance until the whiff edge fires (5L's last active frame, 7, passes with
	# no recorded connect) but BEFORE 5L's own duration (13) elapses and 5L
	# returns to idle — re-entering idle resets move_contact to NONE, so the
	# read must land while 5L is still the current move.
	for _k in range(7):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_eq(s.players[0].state_id, CharacterA.STATE_5L, "still in 5L when reading move_contact (sanity, before it returns to idle)")
	_eq(s.players[0].move_contact, PlayerState.CONTACT_WHIFF, "5L's move_contact resolves to WHIFF against invuln")


## The same 2H startup that has invuln_strike does NOT have invuln_throw, so a
## throw must still connect against it (kind-gated: strike-invuln alone does
## not stop a throw — combat-resolution.md criterion 12 "vice-versa").
func _test_dp_still_thrown_without_throw_invuln() -> void:
	var s := _two_char_state(30)
	s.players[0].state_id = CharacterA.STATE_THROW
	s.players[0].frame_in_state = 0
	s.players[1].state_id = CharacterA.STATE_2H
	s.players[1].frame_in_state = 0
	var connected: bool = false
	for _k in range(20):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[1].state_id == CharacterA.STATE_KNOCKDOWN:
			connected = true
			break
	_true(connected, "a throw connects against 2H's strike-only invuln (no invuln_throw authored on 2H)")


## 623H is BOTH strike- and throw-invulnerable frames 1-8 (character-a.md
## criterion 6). A throw attempted into that window must whiff (no THROWN
## reaction), proving the THROW hit_kind gates on invuln_throw specifically.
func _test_dp_h_throw_invuln_beats_a_throw() -> void:
	var s := _two_char_state(30)
	s.players[0].state_id = CharacterA.STATE_THROW
	s.players[0].frame_in_state = 0
	s.players[1].state_id = CharacterA.STATE_DP_H
	s.players[1].frame_in_state = 0
	var connected: bool = false
	for _k in range(10):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		if s.players[1].state_id == CharacterA.STATE_KNOCKDOWN:
			connected = true
			break
	_false(connected, "a throw whiffs against 623H's throw-invuln window (1-8)")


# --- PlayerView.invuln (derived, no float) -----------------------------------

func _test_playerview_invuln_readable() -> void:
	var s := _two_char_state(45)
	s.players[1].state_id = CharacterA.STATE_2H
	s.players[1].frame_in_state = 1
	var roster: Dictionary = {CharacterA.CHAR_ID: MoveRegistry.character(CharacterA.CHAR_ID)}
	var view := PlayerView.new(s, 1, roster)
	_true(bool(view.invuln.get("strike", false)), "PlayerView.invuln.strike true on 2H's invuln startup frame 1")
	_false(bool(view.invuln.get("throw", false)), "PlayerView.invuln.throw false on 2H (strike-only invuln)")
	# criterion 4: no float in the view — both entries are plain bools.
	_true(typeof(view.invuln["strike"]) == TYPE_BOOL, "invuln.strike is a plain bool (no float)")
	_true(typeof(view.invuln["throw"]) == TYPE_BOOL, "invuln.throw is a plain bool (no float)")

	# Off the invuln window (recovery, frame far past 8) both read false.
	s.players[1].frame_in_state = 15
	var view2 := PlayerView.new(s, 1, roster)
	_false(bool(view2.invuln.get("strike", false)), "PlayerView.invuln.strike false once 2H's invuln window elapses")
	_cleanup()


# --- Projectile gate: gated but not consumed --------------------------------

## A fireball (PROJECTILE) whiffed by a DP's strike-invuln startup must pass
## through (not despawn) and connect once the DP's invuln window elapses.
## State-injected for precision (mirrors the 5L/2H test above): P1 sits in
## DP_L's invuln window (frames 1-11) directly overlapping a hand-placed live
## projectile, so the whiff tick is exact; P1 then advances into DP_L's
## vulnerable tail (frame 12+) while the SAME projectile (never despawned)
## keeps traveling, and must connect there.
func _test_projectile_passes_through_invuln_and_connects_later() -> void:
	# P0 placed far away (pos_x 0, per _two_char_state) so DP_L's OWN hitbox (P1
	# is the attacker of that move) cannot reach and confound the read with an
	# unrelated self-inflicted hit/hitstop; this test isolates the projectile-
	# vs-P1 interaction only. P1 (the projectile's target, at gap_units = 200 —
	# within the stage's [-400,400] wall bounds, else the projectile despawns
	# off-stage before the invuln read) is left there; the projectile below is
	# spawned AT that same position so it lands exactly on P1, not at world x=0.
	var s := _two_char_state(200)
	s.players[1].state_id = CharacterA.STATE_DP_L
	s.players[1].frame_in_state = 4   # next tick -> 5, within invuln_strike (1-11)
	s.players[1].facing = -1

	var reg: Dictionary = CharacterA.build_projectile_registry()
	var data: ProjectileData = reg[CharacterA.PROJ_FIREBALL_L]
	# Placed exactly overlapping P1's standing hurtbox (P1's own pos_x, 500),
	# stationary (vel 0) so it cannot drift out of overlap between ticks —
	# isolates the invuln gate from any travel/positioning concern.
	var pr := Projectile.spawn(0, CharacterA.PROJ_FIREBALL_L, data, s.players[1].pos_x, FP.from_int(0), 0, 0, 1)
	s.projectiles = [pr]
	var defender_health_before: int = s.players[1].health

	# Tick 1: P1 is on frame 5 (invuln_strike true) — the projectile must whiff
	# and NOT be consumed (still live afterward).
	s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	_false(s.players[1].stun_kind == PlayerView.STUN_HIT and s.players[1].stun > 0,
		"the projectile whiffs against DP_L's invuln_strike window")
	_eq(s.players[1].health, defender_health_before, "no damage from the whiffed projectile")
	_true(s.projectiles.size() > 0, "the whiffed projectile is NOT consumed (still live)")

	# Advance P1 to frame_in_state 12 (vulnerable — invuln ends at 11) while the
	# same still-live projectile remains in place; it must now connect.
	for _k in range(7):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	# The connect itself moves P1 out of DP_L into a hitstun reaction (frame_in_
	# state resets there), so "advanced past the invuln window" is verified by
	# the connect having happened at all, not by a raw frame count post-hit.
	_true(s.players[1].stun_kind == PlayerView.STUN_HIT and s.players[1].stun > 0,
		"the same projectile connects once DP_L's invuln window elapses (passed through, not destroyed)")
	_false(s.players[1].state_id == CharacterA.STATE_DP_L,
		"P1 left DP_L (the invuln-bearing state) once the projectile connected past invuln")
	_cleanup()


# --- Gated contact touches nothing in phase 5 --------------------------------

## A strike suppressed by invuln must not register as a combo hit / id_group
## connect / cancel-tag grant for the attacker — the "gated overlaps reach
## phase 5 for nothing" guarantee (AD-031).
func _test_gated_contact_no_combo_bookkeeping() -> void:
	var s := _two_char_state(45)
	s.players[0].state_id = CharacterA.STATE_5L   # grants TAG_SP on connect
	s.players[0].frame_in_state = 0
	s.players[1].state_id = CharacterA.STATE_2H
	s.players[1].frame_in_state = 0
	for _k in range(15):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
	# 5L's active window has passed (5L is 13f total); no combo hit was counted,
	# and no cancel tag was granted (the connect never reached phase 5).
	_eq(s.players[1].combo_hits, 0, "no combo hit registered for a contact gated by invuln")
	var has_sp_tag: bool = false
	for t in s.players[0].cancel_tags:
		if t == CharacterA.TAG_SP:
			has_sp_tag = true
	_false(has_sp_tag, "no cancel tag granted from a contact gated by invuln (never reached phase 5)")
