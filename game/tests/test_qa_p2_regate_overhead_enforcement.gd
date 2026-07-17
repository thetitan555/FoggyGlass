extends SceneTree

## QA re-audit finding (2026-07-17, P2 re-gate): the proxy-test sweep
## (docs/flags.md "re: test_character_b_air.gd and the shape of our tests")
## found that character B's TWO named overheads — `6H`
## (`test_character_b.gd::_test_6h_is_reachable_and_not_shadowed_by_5h`) and
## the H-divekick (`test_character_b_air.gd::_test_divekick_h_is_the_only_
## overhead`) — each assert `guard_height == HitBox.GUARD_HIGH` by reading it
## straight off the unresolved authored `HitBox`, with NO test anywhere in the
## 46-file suite driving either through a real block-resolution against a
## defender. `test_guard_height.gd` (the file that owns AD-045 dynamic
## enforcement coverage) never references `CharacterB` at all.
##
## Driving this through the real engine surfaced a GENUINE defect (routed as
## a Developer flag, docs/flags.md "re: 6H hitbox never reaches a crouching
## hurtbox"): `6H`'s hitbox (`y=-85, h=20` -> world y -85..-65) never overlaps
## a crouching hurtbox (`y=-55, h=55` -> world y -55..0, a 10-unit vertical
## gap) at ANY horizontal spacing — confirmed with the defender held
## STATIONARY in `STATE_CROUCH` (not a movement/spacing artifact). The attack
## WHIFFS a crouching defender outright rather than connecting as a hit (which
## is what `combat-resolution.md`'s own text says should happen: "HIGH...
## must be blocked standing (hits a crouching back-hold)"). This makes
## permanent crouching a FREE, zero-risk dodge of B's dedicated command
## overhead — undermining the high/low mixup `character-b.md` B-4 centers on.
## **This file does not assert the currently-broken 6H-vs-crouch behavior**
## (this project's convention per flags.md: a red assertion is not committed
## to the suite; the fix commit adds the permanent green regression) — it
## documents the finding here and asserts only what currently holds.
##
## The H-divekick (the OTHER named overhead) does NOT share this defect: its
## hitbox tracks B's own falling position, so it geometrically reaches both a
## standing AND a crouching hurtbox depending on contact height — verified
## both ways below. (The standing case pins the defender against the stage
## wall so the divekick's long hang/dive window can't be dodged by simply
## walking backward out of range — a spacing artifact discovered while
## writing this probe, not a resolution defect: AD-038's "holding back walks
## away when not in blockable range" is itself correct and expected.)
##
## Self-vs-self (B vs B) is the right shape HERE and does not reopen AD-049's
## "no mirror matchup" rule: that rule is specifically about cross-character
## REACTION-STATE resolution (`test_reaction_map.gd` covers that, in both
## directions, per criterion 16). `guard_height`/`is_crouch` enforcement
## (AD-045) is orthogonal — a single character's own move against its own
## roster's stance flag (`combat-resolution.md`'s "Safe" table entry for this
## exact site, AD-049).
##
## Run:  godot --headless --path game -s res://tests/test_qa_p2_regate_overhead_enforcement.gd

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	if _failures == 0:
		print("[test_qa_p2_regate_overhead_enforcement] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_qa_p2_regate_overhead_enforcement] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _install() -> void:
	MoveRegistry.install({CharacterB.CHAR_ID: CharacterB.build_character()})


func _cleanup() -> void:
	MoveRegistry.clear()
	ProjectileRegistry.clear()


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


func _run() -> void:
	_test_6h_blocked_standing()
	# 6H-vs-crouching is a KNOWN, ROUTED defect (see file header) — not asserted here.
	_test_h_divekick_blocked_standing_pinned_at_wall()
	_test_h_divekick_hits_crouching_wrong_stance()
	_test_negative_control_5l_still_blocked_crouching()


# -----------------------------------------------------------------------------
# 6H (guard_height=HIGH): standing back-hold blocks (this half is correct and
# genuinely engine-driven, unlike the authored-data-only check it replaces).
# -----------------------------------------------------------------------------

func _test_6h_blocked_standing() -> void:
	var s := _two_char_state(40)
	s.players[0].state_id = CharacterB.STATE_6H
	s.players[0].frame_in_state = 0
	var resolved: int = PlayerState.CONTACT_NONE
	for _k in range(30):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.RIGHT)   # P1 faces -1; back = RIGHT, standing
		if s.players[0].move_contact != PlayerState.CONTACT_NONE:
			resolved = s.players[0].move_contact
			break
	_eq(resolved, PlayerState.CONTACT_BLOCK, "6H is BLOCKED by a STANDING back-hold (driven through the real engine, not authored-data readback)")
	_eq(s.last_hit.guard_height, HitBox.GUARD_HIGH, "the resolved HitEvent reports guard_height=HIGH")
	_true(s.last_hit.block_valid, "block_valid true (correct stance for a HIGH attack)")
	_cleanup()


# -----------------------------------------------------------------------------
# H-divekick (guard_height=HIGH, B's OTHER named overhead, B-3/B-4's central
# case): reached via a real jump+divekick input sequence (mirrors
# test_character_b_air.gd's own `_jump_then_divekick`).
# -----------------------------------------------------------------------------

func _jump_then_h_divekick(s: SimState, p1_input_during_setup: int, altitude_ticks: int = 20, reach_ticks: int = 40) -> SimState:
	for _k in range(altitude_ticks):
		s = SimState.step(s, InputFrame.UP, p1_input_during_setup)
	for _k in range(reach_ticks):
		s = SimState.step(s, InputFrame.DOWN | InputFrame.BUTTON_2, p1_input_during_setup)
		if s.players[0].state_id == CharacterB.STATE_DIVEKICK_H:
			break
	return s


## Pinned near the stage's positive wall (P1 facing -1, so "back" = toward the
## wall) so the divekick's long hang/dive window can't be dodged by walking
## backward out of range indefinitely (AD-038's "holding back walks away when
## not in a blockable state" is itself correct — this is a real spacing
## interaction, not a resolution bug, and pinning it out isolates the
## guard_height/block-validity claim this test is actually about).
func _test_h_divekick_blocked_standing_pinned_at_wall() -> void:
	var s := _two_char_state(0)
	s.players[0].pos_x = FP.from_int(770)
	s.players[1].pos_x = FP.from_int(795)
	s = _jump_then_h_divekick(s, InputFrame.RIGHT)
	_eq(s.players[0].state_id, CharacterB.STATE_DIVEKICK_H, "reached the H divekick (setup)")
	var resolved: int = PlayerState.CONTACT_NONE
	for _k in range(50):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.RIGHT)
		if s.players[0].move_contact != PlayerState.CONTACT_NONE:
			resolved = s.players[0].move_contact
			break
	_eq(resolved, PlayerState.CONTACT_BLOCK, "the H divekick is BLOCKED by a STANDING back-hold (driven through the real engine, defender pinned at the wall)")
	if resolved == PlayerState.CONTACT_BLOCK:
		_eq(s.last_hit.guard_height, HitBox.GUARD_HIGH, "the resolved HitEvent reports guard_height=HIGH")
		_true(s.last_hit.block_valid, "block_valid true (correct stance)")
	_cleanup()


func _test_h_divekick_hits_crouching_wrong_stance() -> void:
	var s := _two_char_state(30)
	s = _jump_then_h_divekick(s, InputFrame.NEUTRAL)
	_eq(s.players[0].state_id, CharacterB.STATE_DIVEKICK_H, "reached the H divekick (setup)")
	var resolved: int = PlayerState.CONTACT_NONE
	for _k in range(50):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.DOWN | InputFrame.RIGHT)   # crouching back-hold
		if s.players[0].move_contact != PlayerState.CONTACT_NONE:
			resolved = s.players[0].move_contact
			break
	_eq(resolved, PlayerState.CONTACT_HIT, "the H divekick beats a CROUCHING back-hold -- resolves as a HIT, not a block (AD-045: HIGH must be blocked standing)")
	if resolved == PlayerState.CONTACT_HIT:
		_eq(s.last_hit.guard_height, HitBox.GUARD_HIGH, "the resolved HitEvent reports guard_height=HIGH")
		_true(not s.last_hit.block_valid, "block_valid false (wrong stance)")
	_cleanup()


# -----------------------------------------------------------------------------
# Negative control: the SAME crouching back-hold correctly BLOCKS a MID move
# (5L) at a comparable setup shape -- proving a crouching defender's block
# machinery works in general (the 6H whiff above is 6H's own geometry, not a
# broken crouch-block).
# -----------------------------------------------------------------------------

func _test_negative_control_5l_still_blocked_crouching() -> void:
	var s := _two_char_state(40)
	s.players[0].state_id = CharacterB.STATE_5L
	s.players[0].frame_in_state = 0
	var resolved: int = PlayerState.CONTACT_NONE
	for _k in range(15):
		s = SimState.step(s, InputFrame.NEUTRAL, InputFrame.DOWN | InputFrame.RIGHT)
		if s.players[0].move_contact != PlayerState.CONTACT_NONE:
			resolved = s.players[0].move_contact
			break
	_eq(resolved, PlayerState.CONTACT_BLOCK, "negative control: a crouching back-hold correctly blocks 5L (MID)")
	_cleanup()
