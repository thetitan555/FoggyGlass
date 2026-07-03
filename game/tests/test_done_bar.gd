extends SceneTree

## THE P0 DONE-BAR (TKT-P0-10). combat-resolution.md criterion 1 + roadmap P0
## "done when": a trivial test character authored PURELY as .tres data resolves a
## hit with correct advantage, read back through the inspection surface, matching
## hand-computed values.
##
## Run:  godot --headless --path game -s res://tests/test_done_bar.gd
## Exits non-zero on any failure so a harness/CI can gate on it.
##
## This is the tenet proof, NOT character A. It exercises the full seam:
##   - the character is loaded from res://data/test_character.tres (authored data,
##     no engine code — move-format.md criterion 1);
##   - two instances face each other; inputs are RECORDED then REPLAYED through the
##     Replay source (input.md) and the deterministic step;
##   - one hit resolves; startup/active/recovery and static + live advantage are read
##     back THROUGH InspectionView and match the hand-computed numbers;
##   - the whole run is deterministic (replay twice -> identical final hash).
##
## Hand-computed truth (see test_character.tres header):
##   LIGHT: startup 3, active 3, recovery 6, total 12.
##   on_hit_adv = +8, on_block_adv = +2.
##   live advantage at contact = +8 (hitstop cancels; attacker plus).

const CHAR_ID: int = 1
const STATE_IDLE: int = 0
const STATE_LIGHT: int = 10
const STATE_HITSTUN: int = 20

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_run()
	MoveRegistry.clear()
	if _failures == 0:
		print("[test_done_bar] OK — %d checks passed (P0 DONE-BAR)" % _checks)
		quit(0)
	else:
		printerr("[test_done_bar] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("  FAIL: %s  (got %s, expected %s)" % [msg, str(actual), str(expected)])


func _true(cond: bool, msg: String) -> void:
	_eq(cond, true, msg)


func _run() -> void:
	var character := _load_character()
	if character == null:
		_failures += 1
		printerr("  FAIL: could not load res://data/test_character.tres")
		return
	_test_authored_data_matches_hand_values(character)
	_test_authored_matches_programmatic_twin(character)
	_test_done_bar_hit_and_advantage_via_inspection(character)
	_test_done_bar_block_advantage(character)
	_test_replay_determinism(character)


func _load_character() -> Character:
	var res = load("res://data/test_character.tres")
	if res is Character:
		return res
	return null


func _roster(character: Character) -> Dictionary:
	return {character.id: character}


## Build the done-bar start state: two instances facing each other, P0 at 0 (facing
## +1), P1 at 50 units (facing -1), both idle. Roster installed for the sim (F-004).
func _start_state(character: Character) -> SimState:
	MoveRegistry.install(_roster(character))
	var s := SimState.new_initial()
	s.stage = StageState.new_initial(FP.from_int(-400), FP.from_int(400), 0)
	s.players[0].character_id = character.id
	s.players[0].state_id = STATE_IDLE
	s.players[0].pos_x = FP.from_int(0)
	s.players[0].facing = 1
	s.players[0].health = 1000
	s.players[1].character_id = character.id
	s.players[1].state_id = STATE_IDLE
	s.players[1].pos_x = FP.from_int(50)
	s.players[1].facing = -1
	s.players[1].health = 1000
	return s


# --- Criterion: authored .tres data derives the hand-computed frame data ----

func _test_authored_data_matches_hand_values(character: Character) -> void:
	# move-format.md criterion 2, through the ONE derivation, on AUTHORED data.
	var light: MoveState = character.get_state(STATE_LIGHT)
	_true(light != null, ".tres character has the LIGHT state")
	var fd: FrameData = MoveData.frame_data(light)
	_eq(fd.startup, 3, "authored LIGHT startup = 3")
	_eq(fd.active, 3, "authored LIGHT active = 3")
	_eq(fd.recovery, 6, "authored LIGHT recovery = 6")
	_eq(fd.total, 12, "authored LIGHT total = 12")
	_eq(fd.on_hit_adv, 8, "authored LIGHT on-hit advantage = +8")
	_eq(fd.on_block_adv, 2, "authored LIGHT on-block advantage = +2")


func _test_authored_matches_programmatic_twin(character: Character) -> void:
	# The authored .tres must agree with the programmatic TestSupport twin the unit
	# tests use (so a .tres authoring slip cannot silently diverge from the hand math).
	var authored: FrameData = MoveData.frame_data(character.get_state(STATE_LIGHT))
	var twin_char := TestSupport.build_test_character()
	var twin: FrameData = MoveData.frame_data(twin_char.get_state(TestSupport.STATE_LIGHT))
	_eq(authored.startup, twin.startup, ".tres startup matches programmatic twin")
	_eq(authored.active, twin.active, ".tres active matches twin")
	_eq(authored.recovery, twin.recovery, ".tres recovery matches twin")
	_eq(authored.on_hit_adv, twin.on_hit_adv, ".tres on-hit adv matches twin")
	_eq(authored.on_block_adv, twin.on_block_adv, ".tres on-block adv matches twin")


# --- Criterion 1: a hit resolves; advantage reads back through InspectionView --

func _test_done_bar_hit_and_advantage_via_inspection(character: Character) -> void:
	var roster := _roster(character)
	# Record P0's inputs: BUTTON_0 on frame 0, neutral after. P1 neutral throughout.
	var stream_p1 := PackedInt32Array()
	var stream_p2 := PackedInt32Array()
	var n := 30
	for f in range(n):
		stream_p1.append(InputFrame.BUTTON_0 if f == 0 else InputFrame.NEUTRAL)
		stream_p2.append(InputFrame.NEUTRAL)

	# REPLAY the recorded streams through the deterministic step, stopping at contact.
	MoveRegistry.install(roster)
	var s := _start_state(character)
	var contact: SimState = null
	for f in range(n):
		s = SimState.step(s, stream_p1[f], stream_p2[f])
		if s.last_hit != null and contact == null:
			contact = s
			break
	_true(contact != null, "a hit resolves during the replayed scenario")
	if contact == null:
		return

	# READ BACK THROUGH THE INSPECTION SURFACE (the seam) — never sim internals.
	var view := InspectionView.new(contact, roster)

	# last_hit reads out the resolved hit.
	var hit: HitEvent = view.last_hit()
	_true(hit != null, "InspectionView.last_hit() returns the resolved hit")
	_eq(hit.attacker, 0, "last_hit attacker is P0")
	_eq(hit.defender, 1, "last_hit defender is P1")
	_eq(hit.was_block, false, "the hit was not blocked")
	_eq(hit.damage_dealt, 40, "damage dealt = base 40 (unscaled first hit), read through surface")

	# Defender state read through the surface: HITSTUN.
	var def_view: PlayerView = view.player(1)
	_eq(def_view.state_id, STATE_HITSTUN, "defender in HITSTUN via PlayerView")
	_eq(def_view.stun_kind, PlayerView.STUN_HIT, "defender stun_kind = hit via PlayerView")
	_true(not def_view.actionable, "defender not actionable during hitstun via PlayerView")

	# STATIC frame data through the surface: +8 on hit, +2 on block.
	var fd: FrameData = view.frame_data(CHAR_ID, STATE_LIGHT)
	_eq(fd.startup, 3, "surface frame_data startup = 3")
	_eq(fd.active, 3, "surface frame_data active = 3")
	_eq(fd.recovery, 6, "surface frame_data recovery = 6")
	_eq(fd.on_hit_adv, 8, "surface static on-hit advantage = +8")
	_eq(fd.on_block_adv, 2, "surface static on-block advantage = +2")

	# LIVE advantage through the surface at contact: +8, attacker (P0) plus.
	var adv: AdvantageView = view.advantage()
	_eq(adv.value, 8, "surface LIVE advantage at contact = +8 (matches static; hitstop cancels)")
	_eq(adv.plus_player, 0, "surface advantage: attacker (P0) is plus")

	MoveRegistry.clear()


# --- On-block variant: live advantage +2 through the surface ----------------

func _test_done_bar_block_advantage(character: Character) -> void:
	var roster := _roster(character)
	MoveRegistry.install(roster)
	var s := _start_state(character)
	# P1 holds BACK (raw RIGHT under facing -1 = away from P0) every tick -> blocks.
	var contact: SimState = null
	for f in range(30):
		var p1_in: int = InputFrame.BUTTON_0 if f == 0 else InputFrame.NEUTRAL
		s = SimState.step(s, p1_in, InputFrame.RIGHT)
		if s.last_hit != null:
			contact = s
			break
	_true(contact != null, "a blocked hit resolves in the block scenario")
	if contact == null:
		return
	var view := InspectionView.new(contact, roster)
	var hit: HitEvent = view.last_hit()
	_eq(hit.was_block, true, "the hit was blocked (read through surface)")
	_eq(hit.damage_dealt, 0, "no chip damage on block at P0 (read through surface)")
	var adv: AdvantageView = view.advantage()
	_eq(adv.value, 2, "surface LIVE advantage on block = +2")
	MoveRegistry.clear()


# --- Determinism of the whole done-bar scenario -----------------------------

func _test_replay_determinism(character: Character) -> void:
	var roster := _roster(character)
	var stream_p1 := PackedInt32Array()
	var stream_p2 := PackedInt32Array()
	for f in range(30):
		stream_p1.append(InputFrame.BUTTON_0 if f == 0 else InputFrame.NEUTRAL)
		stream_p2.append(InputFrame.NEUTRAL)

	MoveRegistry.install(roster)
	var h1: int = SimHarness.replay_final_hash(_start_state(character), stream_p1, stream_p2)
	var h2: int = SimHarness.replay_final_hash(_start_state(character), stream_p1, stream_p2)
	_eq(h1, h2, "done-bar scenario replays to an identical final hash (determinism)")

	# Snapshot mid-scenario, restore, resume -> identical final hash.
	var s := _start_state(character)
	for f in range(10):
		s = SimState.step(s, stream_p1[f], stream_p2[f])
	var snap: Dictionary = SimHarness.dump_state(s)
	var restored: SimState = SimHarness.load_state(snap)
	for f in range(10, 30):
		restored = SimState.step(restored, stream_p1[f], stream_p2[f])
	_eq(restored.hash_state(), h1, "snapshot/restore/resume mid-done-bar matches uninterrupted")
	MoveRegistry.clear()
