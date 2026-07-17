extends SceneTree

## Headless test for AD-049 (the character-namespace rule + defender-resolved
## reactions): `move-format.md` "The character-namespace rule" / "Reactions" /
## `Character.reaction_map` / `HitBox.hit_reaction`/`block_reaction` / criteria
## 15-18; `combat-resolution.md` phase 5 + the throw path. TKT-P2-09+10.
##
## THIS TEST IS THE REGRESSION NET FOR THE P2 HUMAN-GATE BOX-VANISH DEFECT
## (docs/flags.md 2026-07-16). The defect: a hit character's collision/hurtbox
## vanished and the character was permanently stuck, because the old
## `hit_reaction`/`block_reaction` was a raw `state_id` authored on the
## ATTACKER and resolved against the DEFENDER's roster — which only ever
## "worked" because every test before this one matched a character against
## itself (a mirror), where attacker and defender happen to share one id
## namespace. **A mirror matchup cannot prove this fix** — see criterion 16 —
## so EVERY scenario below is character A vs character B (disjoint state-id
## ranges: A's run 100s-160s, B's run 300s+), in BOTH directions.
##
## Verified FAILING on the pre-fix code (a one-off repro script, not committed
## — see the Developer session notes / commit log for TKT-P2-09+10): A's 5L
## hitting B left B's `PlayerView.boxes` empty and B permanently stuck (never
## returned to idle within 200 ticks). This file is the permanent, broader net.
##
## Run:  godot --headless --path game -s res://tests/test_reaction_map.gd
## Exits non-zero on any failure so a harness/CI can gate on it.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	ProjectileRegistry.clear()
	if _failures == 0:
		print("[test_reaction_map] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_reaction_map] FAIL — %d of %d checks failed" % [_failures, _checks])
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


func _install() -> void:
	MoveRegistry.install({
		CharacterA.CHAR_ID: CharacterA.build_character(),
		CharacterB.CHAR_ID: CharacterB.build_character(),
	})
	var ok: bool = ProjectileRegistry.install([
		CharacterA.build_projectile_registry(),
		CharacterB.build_projectile_registry(),
	])
	_true(ok, "A+B projectile registries install clean (disjoint ranges, setup)")


func _cleanup() -> void:
	MoveRegistry.clear()
	ProjectileRegistry.clear()


## An A-vs-B (or B-vs-A) SimState: P0 is `attacker_char` in `attacker_state` at
## x=0 facing +1; P1 is `defender_char` in `defender_state` at x=`gap` facing -1.
func _state(attacker_char: int, attacker_state: int, defender_char: int,
		defender_state: int, gap: int) -> SimState:
	_install()
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-800), FP.from_int(800), 0)
	s.players[0].character_id = attacker_char
	s.players[0].state_id = attacker_state
	s.players[0].frame_in_state = 0
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[1].character_id = defender_char
	s.players[1].state_id = defender_state
	s.players[1].pos_x = FP.from_int(gap)
	s.players[1].facing = -1
	return s


func _roster() -> Dictionary:
	return {
		CharacterA.CHAR_ID: MoveRegistry.character(CharacterA.CHAR_ID),
		CharacterB.CHAR_ID: MoveRegistry.character(CharacterB.CHAR_ID),
	}


func _run() -> void:
	_test_criterion_15_reaction_map_completeness()
	_test_criterion_17_no_raw_id_authored_across_characters()
	_test_criterion_18_duplicate_projectile_id_rejected()

	# Criterion 16 — asymmetric A-vs-B, BOTH directions, every inflicted kind.
	_test_a_hits_b_hitstun()
	_test_b_hits_a_hitstun()
	_test_a_hits_b_blockstun()
	_test_b_hits_a_blockstun()
	_test_a_hits_b_crouch_blockstun()
	_test_b_hits_a_crouch_blockstun()
	_test_a_hits_b_launch_lands_into_b_own_knockdown()
	_test_b_hits_a_launch_lands_into_a_own_knockdown()
	_test_a_hits_b_air_reset_explicit()   # criterion 16's named AIR_RESET case
	_test_a_throw_hits_b_knockdown()
	_test_b_throw_hits_a_knockdown()


# =============================================================================
# Criterion 15 — reaction-map completeness, checked statically over the roster.
# =============================================================================

func _test_criterion_15_reaction_map_completeness() -> void:
	var roster: Dictionary = {
		CharacterA.CHAR_ID: CharacterA.build_character(),
		CharacterB.CHAR_ID: CharacterB.build_character(),
	}
	for char_id in roster:
		var c: Character = roster[char_id]
		var missing: Array[int] = c.missing_reactions()
		_eq(missing.size(), 0, "character %d maps EVERY ReactionKind (missing: %s) -- criterion 15" % [char_id, str(missing)])
		for kind in MoveState.VALID_REACTION_KINDS:
			var state_id: int = c.reaction_state(kind)
			var m: MoveState = c.get_state(state_id)
			_true(m != null, "character %d's reaction_state(%d) (%d) exists in its OWN states" % [char_id, kind, state_id])
			if m == null:
				continue
			var is_hitstun_family: bool = kind in [
				MoveState.REACTION_HITSTUN, MoveState.REACTION_LAUNCH,
				MoveState.REACTION_AIR_RESET, MoveState.REACTION_KNOCKDOWN,
			]
			var is_blockstun_family: bool = kind in [
				MoveState.REACTION_BLOCKSTUN, MoveState.REACTION_CROUCH_BLOCKSTUN,
			]
			if is_hitstun_family:
				_eq(m.category, MoveState.CATEGORY_HITSTUN,
					"character %d's kind %d state declares CATEGORY_HITSTUN" % [char_id, kind])
			if is_blockstun_family:
				_eq(m.category, MoveState.CATEGORY_BLOCKSTUN,
					"character %d's kind %d state declares CATEGORY_BLOCKSTUN" % [char_id, kind])


# =============================================================================
# Criterion 17 — no raw state_id crosses a character boundary: every authored
# hit_reaction/block_reaction is one of the six closed ReactionKind values, not
# a character-local state_id (which would be some other arbitrary int).
# =============================================================================

func _test_criterion_17_no_raw_id_authored_across_characters() -> void:
	var roster: Dictionary = {
		CharacterA.CHAR_ID: CharacterA.build_character(),
		CharacterB.CHAR_ID: CharacterB.build_character(),
	}
	for char_id in roster:
		var c: Character = roster[char_id]
		for m in c.states:
			for kf in m.timeline:
				for hb in kf.hitboxes:
					_true(MoveState.VALID_REACTION_KINDS.has(hb.hit_reaction),
						"character %d state %d: hit_reaction (%d) is a closed ReactionKind, not a raw state_id" % [char_id, m.id, hb.hit_reaction])
					_true(MoveState.VALID_REACTION_KINDS.has(hb.block_reaction),
						"character %d state %d: block_reaction (%d) is a closed ReactionKind, not a raw state_id" % [char_id, m.id, hb.block_reaction])


# =============================================================================
# Criterion 18 — projectile data_id global-namespace uniqueness.
# =============================================================================

func _test_criterion_18_duplicate_projectile_id_rejected() -> void:
	# A and B install clean (disjoint ranges) -- already asserted in _install()
	# via every _state() call above; re-assert explicitly here too.
	var ok_clean: bool = ProjectileRegistry.install([
		CharacterA.build_projectile_registry(),
		CharacterB.build_projectile_registry(),
	])
	_true(ok_clean, "A+B projectile registries install clean (disjoint ranges)")

	# A synthetic collision: two sources sharing one data_id must be REJECTED,
	# not silently overwritten (the exact training_mode.gd merge-loop bug).
	var dupe_id: int = CharacterA.PROJ_FIREBALL_L
	var data_a := ProjectileData.new()
	data_a.id = dupe_id
	var data_b := ProjectileData.new()
	data_b.id = dupe_id   # SAME id as data_a -- the collision
	var ok_dupe: bool = ProjectileRegistry.install([{dupe_id: data_a}, {dupe_id: data_b}])
	_false(ok_dupe, "a duplicate data_id across two sources is REJECTED (AD-049), not silently overwritten")

	# Re-install the clean roster so later tests in this file aren't left with
	# the rejected/empty registry from the negative case above.
	ProjectileRegistry.install([
		CharacterA.build_projectile_registry(),
		CharacterB.build_projectile_registry(),
	])


# =============================================================================
# Criterion 16 — asymmetric A-vs-B cross-character reactions. Shared assertion:
# the defender enters a state FROM ITS OWN ROSTER, `PlayerView.boxes` is
# NON-EMPTY on every tick of the reaction, and the defender becomes actionable
# again when stun expires with NO external/round reset.
# =============================================================================

## Drive `s` forward until `attacker`'s move_contact resolves to `expect_contact`
## (HIT or BLOCK), asserting boxes stay non-empty on `defender` every tick along
## the way. Returns the resulting state (still mid-reaction, one tick after
## connect) or null if it never connected within `budget` ticks.
func _drive_to_contact(s: SimState, defender: int, expect_contact: int, budget: int) -> SimState:
	for _k in range(budget):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		var view := InspectionView.new(s, _roster())
		_true(view.player(defender).boxes.size() > 0,
			"defender %d's boxes are non-empty this tick (frame_in_state=%d, state=%d)" % [defender, s.players[defender].frame_in_state, s.players[defender].state_id])
		if s.players[0].move_contact == expect_contact:
			return s
	return null


## Continue driving `s` (both neutral) until `defender` becomes actionable
## again (or `budget` ticks elapse, returning false). Asserts boxes stay
## non-empty every tick along the way, and that recovery happens WITHOUT any
## external state rebuild (this loop never touches SimState except via `step`).
func _drive_to_recovery(s: SimState, defender: int, defender_char: int, budget: int) -> bool:
	var roster: Dictionary = _roster()
	var character: Character = roster[defender_char]
	for _k in range(budget):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		var view := InspectionView.new(s, roster)
		_true(view.player(defender).boxes.size() > 0,
			"defender %d's boxes stay non-empty while recovering (state=%d)" % [defender, s.players[defender].state_id])
		var move: MoveState = character.get_state(s.players[defender].state_id)
		if Actionability.is_actionable(s.players[defender], move):
			return true
	return false


func _test_a_hits_b_hitstun() -> void:
	var s := _state(CharacterA.CHAR_ID, CharacterA.STATE_5L, CharacterB.CHAR_ID, CharacterB.STATE_IDLE, 30)
	s = _drive_to_contact(s, 1, PlayerState.CONTACT_HIT, 20)
	_true(s != null, "A's 5L connects on hit against B (setup)")
	if s == null:
		return
	_eq(s.players[1].state_id, CharacterB.STATE_HITSTUN, "B enters B's OWN STATE_HITSTUN (not A's, criterion 16/17)")
	_true(MoveRegistry.character(CharacterB.CHAR_ID).get_state(s.players[1].state_id) != null, "resolved state exists in B's own roster")
	_true(_drive_to_recovery(s, 1, CharacterB.CHAR_ID, 60), "B becomes actionable again after HITSTUN, no round reset")
	_cleanup()


func _test_b_hits_a_hitstun() -> void:
	var s := _state(CharacterB.CHAR_ID, CharacterB.STATE_5L, CharacterA.CHAR_ID, CharacterA.STATE_IDLE, 35)
	s = _drive_to_contact(s, 1, PlayerState.CONTACT_HIT, 20)
	_true(s != null, "B's 5L connects on hit against A (setup)")
	if s == null:
		return
	_eq(s.players[1].state_id, CharacterA.STATE_HITSTUN, "A enters A's OWN STATE_HITSTUN (not B's, criterion 16/17)")
	_true(_drive_to_recovery(s, 1, CharacterA.CHAR_ID, 60), "A becomes actionable again after HITSTUN, no round reset")
	_cleanup()


func _test_a_hits_b_blockstun() -> void:
	var s := _state(CharacterA.CHAR_ID, CharacterA.STATE_5L, CharacterB.CHAR_ID, CharacterB.STATE_IDLE, 30)
	# B holds back (RIGHT, since B faces -1) throughout.
	for _k in range(20):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.RIGHT)
		var view := InspectionView.new(s, _roster())
		_true(view.player(1).boxes.size() > 0, "B's boxes non-empty while blocking (frame_in_state=%d)" % s.players[1].frame_in_state)
		if s.players[0].move_contact == PlayerState.CONTACT_BLOCK:
			break
	_eq(s.players[0].move_contact, PlayerState.CONTACT_BLOCK, "A's 5L is blocked by B (setup)")
	_eq(s.players[1].state_id, CharacterB.STATE_BLOCKSTUN, "B enters B's OWN STATE_BLOCKSTUN (not A's)")
	_true(_drive_to_recovery(s, 1, CharacterB.CHAR_ID, 40), "B becomes actionable again after BLOCKSTUN")
	_cleanup()


func _test_b_hits_a_blockstun() -> void:
	var s := _state(CharacterB.CHAR_ID, CharacterB.STATE_5L, CharacterA.CHAR_ID, CharacterA.STATE_IDLE, 35)
	for _k in range(20):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.RIGHT)
		var view := InspectionView.new(s, _roster())
		_true(view.player(1).boxes.size() > 0, "A's boxes non-empty while blocking (frame_in_state=%d)" % s.players[1].frame_in_state)
		if s.players[0].move_contact == PlayerState.CONTACT_BLOCK:
			break
	_eq(s.players[0].move_contact, PlayerState.CONTACT_BLOCK, "B's 5L is blocked by A (setup)")
	_eq(s.players[1].state_id, CharacterA.STATE_BLOCKSTUN, "A enters A's OWN STATE_BLOCKSTUN (not B's)")
	_true(_drive_to_recovery(s, 1, CharacterA.CHAR_ID, 40), "A becomes actionable again after BLOCKSTUN")
	_cleanup()


func _test_a_hits_b_crouch_blockstun() -> void:
	# A's 2L is guard_height=LOW; B must crouch-block it (DOWN+back).
	var s := _state(CharacterA.CHAR_ID, CharacterA.STATE_2L, CharacterB.CHAR_ID, CharacterB.STATE_CROUCH, 45)
	var crouch_back: int = InputFrame.DOWN | InputFrame.RIGHT
	for _k in range(20):
		s = SimState.step(s, InputFrame.NEUTRAL, crouch_back)
		var view := InspectionView.new(s, _roster())
		_true(view.player(1).boxes.size() > 0, "B's boxes non-empty while crouch-blocking")
		if s.players[0].move_contact == PlayerState.CONTACT_BLOCK:
			break
	_eq(s.players[0].move_contact, PlayerState.CONTACT_BLOCK, "A's 2L is crouch-blocked by B (setup)")
	_eq(s.players[1].state_id, CharacterB.STATE_CROUCH_BLOCKSTUN, "B enters B's OWN STATE_CROUCH_BLOCKSTUN (not A's)")
	_true(_drive_to_recovery(s, 1, CharacterB.CHAR_ID, 40), "B becomes actionable again after CROUCH_BLOCKSTUN")
	_cleanup()


func _test_b_hits_a_crouch_blockstun() -> void:
	# B's 2L is guard_height=LOW; A must crouch-block it.
	var s := _state(CharacterB.CHAR_ID, CharacterB.STATE_2L, CharacterA.CHAR_ID, CharacterA.STATE_CROUCH, 35)
	var crouch_back: int = InputFrame.DOWN | InputFrame.RIGHT
	for _k in range(20):
		s = SimState.step(s, InputFrame.NEUTRAL, crouch_back)
		var view := InspectionView.new(s, _roster())
		_true(view.player(1).boxes.size() > 0, "A's boxes non-empty while crouch-blocking")
		if s.players[0].move_contact == PlayerState.CONTACT_BLOCK:
			break
	_eq(s.players[0].move_contact, PlayerState.CONTACT_BLOCK, "B's 2L is crouch-blocked by A (setup)")
	_eq(s.players[1].state_id, CharacterA.STATE_CROUCH_BLOCKSTUN, "A enters A's OWN STATE_CROUCH_BLOCKSTUN (not B's)")
	_true(_drive_to_recovery(s, 1, CharacterA.CHAR_ID, 40), "A becomes actionable again after CROUCH_BLOCKSTUN")
	_cleanup()


## AD-043 knockdown convergence via the KIND (criterion 4 of the ticket): a
## LAUNCH reaction lands into the SAME character's own KNOCKDOWN reaction.
func _test_a_hits_b_launch_lands_into_b_own_knockdown() -> void:
	var s := _state(CharacterA.CHAR_ID, CharacterA.STATE_DP_L, CharacterB.CHAR_ID, CharacterB.STATE_IDLE, 30)
	s = _drive_to_contact(s, 1, PlayerState.CONTACT_HIT, 20)
	_true(s != null, "A's DP_L connects on hit against B (setup)")
	if s == null:
		return
	_eq(s.players[1].state_id, CharacterB.STATE_HITSTUN_LAUNCH, "B enters B's OWN STATE_HITSTUN_LAUNCH (not A's)")
	var landed: bool = false
	for _k in range(80):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		var view := InspectionView.new(s, _roster())
		_true(view.player(1).boxes.size() > 0, "B's boxes non-empty throughout the launch/landing (state=%d)" % s.players[1].state_id)
		if s.players[1].state_id == CharacterB.STATE_KNOCKDOWN:
			landed = true
			break
	_true(landed, "B's launch lands into B's OWN STATE_KNOCKDOWN (AD-043, via B's reaction_map)")
	_true(_drive_to_recovery(s, 1, CharacterB.CHAR_ID, 60), "B becomes actionable again after landing into knockdown")
	_cleanup()


func _test_b_hits_a_launch_lands_into_a_own_knockdown() -> void:
	var s := _state(CharacterB.CHAR_ID, CharacterB.STATE_2H, CharacterA.CHAR_ID, CharacterA.STATE_IDLE, 40)
	s = _drive_to_contact(s, 1, PlayerState.CONTACT_HIT, 20)
	_true(s != null, "B's 2H connects on hit against A (setup)")
	if s == null:
		return
	_eq(s.players[1].state_id, CharacterA.STATE_HITSTUN_LAUNCH, "A enters A's OWN STATE_HITSTUN_LAUNCH (not B's)")
	var landed: bool = false
	for _k in range(80):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		var view := InspectionView.new(s, _roster())
		_true(view.player(1).boxes.size() > 0, "A's boxes non-empty throughout the launch/landing (state=%d)" % s.players[1].state_id)
		if s.players[1].state_id == CharacterA.STATE_KNOCKDOWN:
			landed = true
			break
	_true(landed, "A's launch lands into A's OWN STATE_KNOCKDOWN (AD-043, via A's reaction_map)")
	_true(_drive_to_recovery(s, 1, CharacterA.CHAR_ID, 60), "A becomes actionable again after landing into knockdown")
	_cleanup()


## Criterion 16's explicitly-named case: A's 2H inflicts REACTION_AIR_RESET,
## which ONLY B receives (B never inflicts it) -- the concrete content hole
## AD-049 closed. B must enter B's OWN air-reset state, keep its boxes, and
## recover (character-b.md "What B looks like when it receives").
func _test_a_hits_b_air_reset_explicit() -> void:
	var s := _state(CharacterA.CHAR_ID, CharacterA.STATE_2H, CharacterB.CHAR_ID, CharacterB.STATE_IDLE, 30)
	s = _drive_to_contact(s, 1, PlayerState.CONTACT_HIT, 20)
	_true(s != null, "A's 2H connects on hit against B (setup)")
	if s == null:
		return
	_eq(s.players[1].state_id, CharacterB.STATE_AIR_RESET, "B enters B's OWN STATE_AIR_RESET (the content hole AD-049 closed)")
	_true(MoveRegistry.character(CharacterB.CHAR_ID).get_state(CharacterB.STATE_AIR_RESET).category == MoveState.CATEGORY_HITSTUN,
		"B's STATE_AIR_RESET is HITSTUN-category")
	var recovered_or_knockdown: bool = false
	for _k in range(80):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		var view := InspectionView.new(s, _roster())
		_true(view.player(1).boxes.size() > 0, "B's boxes non-empty throughout the air-reset (state=%d)" % s.players[1].state_id)
		if s.players[1].state_id == CharacterB.STATE_KNOCKDOWN or s.players[1].state_id == CharacterB.STATE_IDLE:
			recovered_or_knockdown = true
			break
	_true(recovered_or_knockdown, "B's air-reset resolves onward (lands into B's own knockdown or recovers) -- never stuck")
	_true(_drive_to_recovery(s, 1, CharacterB.CHAR_ID, 60), "B eventually becomes actionable again, no round reset")
	_cleanup()


func _test_a_throw_hits_b_knockdown() -> void:
	var s := _state(CharacterA.CHAR_ID, CharacterA.STATE_THROW, CharacterB.CHAR_ID, CharacterB.STATE_IDLE, 30)
	var connected: bool = false
	for _k in range(20):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		var view := InspectionView.new(s, _roster())
		_true(view.player(1).boxes.size() > 0, "B's boxes non-empty during the throw resolve")
		if s.players[1].state_id == CharacterB.STATE_KNOCKDOWN:
			connected = true
			break
	_true(connected, "A's throw enters B DIRECTLY into B's OWN STATE_KNOCKDOWN (no air trip)")
	_true(_drive_to_recovery(s, 1, CharacterB.CHAR_ID, 60), "B becomes actionable again after the throw's knockdown")
	_cleanup()


func _test_b_throw_hits_a_knockdown() -> void:
	var s := _state(CharacterB.CHAR_ID, CharacterB.STATE_THROW, CharacterA.CHAR_ID, CharacterA.STATE_IDLE, 30)
	var connected: bool = false
	for _k in range(20):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		var view := InspectionView.new(s, _roster())
		_true(view.player(1).boxes.size() > 0, "A's boxes non-empty during the throw resolve")
		if s.players[1].state_id == CharacterA.STATE_KNOCKDOWN:
			connected = true
			break
	_true(connected, "B's throw enters A DIRECTLY into A's OWN STATE_KNOCKDOWN (no air trip)")
	_true(_drive_to_recovery(s, 1, CharacterA.CHAR_ID, 60), "A becomes actionable again after the throw's knockdown")
	_cleanup()
