extends SceneTree

## QA's golden-file regression net (roadmap P2 done-condition; TKT-P2 "Cross-
## cutting: Golden-file regression net seeding" — "QA owns building it"). This
## is QA test tooling, not production code: three checked-in fixtures under
## tests/goldens/, each byte-compared against a freshly generated dump so a
## silent frame-data/geometry/determinism drift (a move quietly shifting from
## 7f to 8f startup, a hitbox quietly resizing, a match hash quietly changing)
## is caught even though every OTHER headless test stays green (they assert
## individual facts; this asserts the whole resolved shape hasn't moved).
##
## Three targets (the ones the P2 ticket names):
##   1. Character A's re-baselined movement (post-AD-043 gravity model,
##      JC-072/JC-068-072) — a fixed TraceHarness script over walk/dash/jump/
##      crouch, dumped through the one canonical TraceHarness/InspectionView
##      path (with box geometry) — every character's frame data/geometry
##      resolves through this SAME path (cross-system consistency, verified
##      structurally: this file's dump function takes a character_id and is
##      called for both A and B with no branch).
##   2. Character B's per-move resolved frame data + hitbox/hurtbox geometry
##      — MoveData.frame_data / MoveData.resolve_boxes, the same canonical
##      derivation A's moves resolve through.
##   3. A full-match determinism golden — final MatchState hash + a per-tick
##      hash trace over a fixed >=2-round script (a KO, then a timeout),
##      mirroring test_match_state.gd's own full-match script.
##
## A MISMATCH IS NOT AUTOMATICALLY A REGRESSION: a deliberate tuning/behavior
## change (JC-017/JC-072-style) legitimately moves these numbers, and
## re-baselining is a deliberate QA act, never a silent one. On a mismatch this
## test FAILS LOUDLY, writes the fresh dump to a sibling `*.actual.txt` file
## (never overwriting the checked-in golden), and names the first differing
## line — a human/QA reviews and re-baselines on purpose, exactly like any
## snapshot-test workflow.
##
## Run:  godot --headless --path game -s res://tests/test_golden_regression.gd
## Exits non-zero on any failure (mismatch OR missing fixture) so CI can gate.

var _failures: int = 0
var _checks: int = 0

const GOLDEN_DIR: String = "res://tests/goldens/"
const GOLDEN_A_MOVEMENT: String = "character_a_movement.golden.txt"
const GOLDEN_B_FRAME_DATA: String = "character_b_frame_data.golden.txt"
const GOLDEN_MATCH_FULL: String = "match_full.golden.txt"


func _init() -> void:
	_run()
	MoveRegistry.clear()
	ProjectileRegistry.clear()
	if _failures == 0:
		print("[test_golden_regression] OK — %d checks passed" % _checks)
		quit(0)
	else:
		printerr("[test_golden_regression] FAIL — %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _run() -> void:
	_check_golden(GOLDEN_A_MOVEMENT, _character_a_movement_dump())
	_check_golden(GOLDEN_B_FRAME_DATA, _character_frame_data_dump(CharacterB.CHAR_ID, CharacterB.build_character()))
	_check_golden(GOLDEN_MATCH_FULL, _full_match_golden_dump())


# ---------------------------------------------------------------------------
# Golden compare/report plumbing
# ---------------------------------------------------------------------------

func _check_golden(filename: String, actual: String) -> void:
	_checks += 1
	var path: String = GOLDEN_DIR + filename
	if not FileAccess.file_exists(path):
		_failures += 1
		printerr("  FAIL: golden fixture missing: %s (writing the fresh dump to %s.actual.txt for review — this is the FIRST baseline, seed it deliberately, don't blind-copy)" % [path, path])
		_write_actual(path, actual)
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var expected: String = f.get_as_text()
	f.close()
	if actual == expected:
		return
	_failures += 1
	_write_actual(path, actual)
	var exp_lines: PackedStringArray = expected.split("\n")
	var act_lines: PackedStringArray = actual.split("\n")
	var first_diff: int = -1
	for i in range(max(exp_lines.size(), act_lines.size())):
		var e: String = exp_lines[i] if i < exp_lines.size() else "<no line>"
		var a: String = act_lines[i] if i < act_lines.size() else "<no line>"
		if e != a:
			first_diff = i
			printerr("  FAIL: golden mismatch: %s" % path)
			printerr("    first differing line %d:" % i)
			printerr("      golden: %s" % e)
			printerr("      actual: %s" % a)
			break
	printerr("    (%d golden lines, %d actual lines; fresh dump written to %s.actual.txt — review and re-baseline deliberately if this is an intended change)"
		% [exp_lines.size(), act_lines.size(), path])


func _write_actual(path: String, actual: String) -> void:
	var f := FileAccess.open(path + ".actual.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(actual)
		f.close()


# ---------------------------------------------------------------------------
# 1. Character A's re-baselined movement golden (post-AD-043 gravity model).
# Walk fwd/back, ground dash fwd/back (66/44), jump neutral/back/forward,
# crouch hold — through TraceHarness (the one canonical scripted-input path,
# AD-011/Tenet 2), WITH resolved box geometry (the hitbox/hurtbox regression
# half of the net), so a silent movement-arc OR geometry drift both show up as
# a byte diff. Script length is exact (no playback looping past the end).
# ---------------------------------------------------------------------------

const _A_MOVEMENT_SCRIPT: String = "
5*3
6*30
5*10
4*30
5*10
6*1 5*1 6*1
5*40
4*1 5*1 4*1
5*40
8*60
5*10
7*60
5*10
9*60
5*10
2*30
5*10
"
const _A_MOVEMENT_TICKS: int = 419   # exact sum of the script's token counts above


func _character_a_movement_dump() -> String:
	var roster: Dictionary = {CharacterA.CHAR_ID: CharacterA.build_character()}
	var rows: Array[Dictionary] = TraceHarness.run(
		_A_MOVEMENT_SCRIPT, "", _A_MOVEMENT_TICKS, roster, CharacterA.CHAR_ID,
		{}, PackedStringArray([TraceHarness.OPTIONAL_BOXES]))
	MoveRegistry.clear()
	return TraceHarness.format_rows(rows, PackedStringArray([TraceHarness.OPTIONAL_BOXES])) + "\n"


# ---------------------------------------------------------------------------
# 2. Per-character resolved frame data + hitbox/hurtbox geometry golden. Data-
# level (no sim stepping): for every authored state, dump the canonical
# derived FrameData (MoveData.frame_data — the SAME derivation every
# character uses, move-format.md criterion 2/4) plus, per keyframe, the
# resolved world-space box set at that keyframe's first frame (facing=1,
# position=(0,0)) via MoveData.resolve_boxes — the SAME box-resolution path
# phase 4 tests for overlap and the inspection surface projects (AD-001). One
# dumper, called for either character with no branch (the cross-system-
# consistency proof made structural: this function does not know it is being
# asked about A or B).
# ---------------------------------------------------------------------------

func _character_frame_data_dump(char_id: int, c: Character) -> String:
	var lines := PackedStringArray()
	var states: Array[MoveState] = c.states.duplicate()
	states.sort_custom(func(a, b): return a.id < b.id)
	for st in states:
		var fd: FrameData = MoveData.frame_data(st)
		lines.append("STATE id=%d category=%d duration=%d loop=%d is_crouch=%d | startup=%d active=%d recovery=%d total=%d on_hit_adv=%d on_block_adv=%d" % [
			st.id, st.category, st.duration, int(st.loop), int(st.is_crouch),
			fd.startup, fd.active, fd.recovery, fd.total, fd.on_hit_adv, fd.on_block_adv,
		])
		var pushbox: Box = st.effective_pushbox(c) if st.has_method("effective_pushbox") else _fallback_pushbox(st, c)
		var kfs: Array[Keyframe] = st.timeline.duplicate()
		kfs.sort_custom(func(a, b): return a.frame_start < b.frame_start)
		for kf in kfs:
			var boxes: Array[ResolvedBox] = MoveData.resolve_boxes(st, kf.frame_start, 1, 0, 0, pushbox)
			var box_strs := PackedStringArray()
			for b in boxes:
				var gh: int = b.hit.guard_height if b.hit != null else -1
				box_strs.append("%s(x=%d,y=%d,w=%d,h=%d,gh=%d)" % [_kind_name(b.kind), b.x, b.y, b.w, b.h, gh])
			lines.append("  kf[%d..%d] invuln_strike=%d invuln_throw=%d motion=%d,%d spawn=%d : %s" % [
				kf.frame_start, kf.frame_end, int(kf.invuln_strike), int(kf.invuln_throw),
				kf.motion_vel_x if kf.has_motion else 0, kf.motion_vel_y if kf.has_motion else 0,
				int(kf.has_spawn), "; ".join(box_strs),
			])
	return "\n".join(lines) + "\n"


func _fallback_pushbox(st: MoveState, c: Character) -> Box:
	return st.pushbox if st.pushbox != null else c.default_pushbox


func _kind_name(kind: int) -> String:
	match kind:
		BoxView.KIND_HURT: return "HURT"
		BoxView.KIND_HIT: return "HIT"
		BoxView.KIND_THROW: return "THROW"
		BoxView.KIND_PUSH: return "PUSH"
		_: return "?"


# ---------------------------------------------------------------------------
# 3. Full-match determinism golden. The SAME fixed >=2-round script shape
# test_match_state.gd's own _test_full_match_determinism_round_trip exercises
# (a ROUND_START beat, real ACTIVE ticks, an injected KO ending round 1, a
# ROUND_END beat, round 2's ROUND_START beat, real ACTIVE ticks, an injected
# near-timeout ending round 2, MATCH_END) — golden-filed here as the
# per-tick hash trace + final result summary, so a silent determinism/
# match-flow drift (a phase reordering, a hash-composition change) shows up as
# a byte diff even if every existing pass/fail assertion still passes.
# ---------------------------------------------------------------------------

func _full_match_script() -> Array:
	var script: Array = []
	for i in range(MatchState.ROUND_START_BEAT_TICKS):
		script.append(["step"])
	for i in range(5):
		script.append(["step"])
	script.append(["inject_health", 1, 0])
	script.append(["step"])
	for i in range(MatchState.ROUND_END_BEAT_TICKS):
		script.append(["step"])
	for i in range(MatchState.ROUND_START_BEAT_TICKS):
		script.append(["step"])
	for i in range(5):
		script.append(["step"])
	script.append(["inject_health", 1, 200])
	script.append(["inject_timer", 1])
	script.append(["step"])
	for i in range(MatchState.ROUND_END_BEAT_TICKS):
		script.append(["step"])
	for i in range(3):
		script.append(["step"])
	return script


func _apply_action(ms: MatchState, action: Array) -> MatchState:
	match action[0]:
		"step":
			return MatchState.match_step(ms, InputFrame.NEUTRAL, InputFrame.NEUTRAL)
		"inject_health":
			var m2 := ms.clone()
			m2.sim.players[action[1]].health = action[2]
			return m2
		"inject_timer":
			var m2 := ms.clone()
			m2.round_timer = action[1]
			return m2
		_:
			return ms


func _full_match_golden_dump() -> String:
	MoveRegistry.install(TestSupport.build_roster())
	var script := _full_match_script()
	var ms := MatchState.new_match(TestSupport.CHAR_ID, TestSupport.CHAR_ID, 777)
	var lines := PackedStringArray()
	for i in range(script.size()):
		ms = _apply_action(ms, script[i])
		lines.append("%d hash=%d phase=%d wins=%d,%d reason=%d" % [
			i, ms.hash_state(), ms.match_phase, ms.round_wins[0], ms.round_wins[1], ms.last_round_end_reason,
		])
	lines.append("FINAL hash=%d phase=%d wins=%d,%d reason=%d sudden_death=%d" % [
		ms.hash_state(), ms.match_phase, ms.round_wins[0], ms.round_wins[1], ms.last_round_end_reason, int(ms.sudden_death),
	])
	MoveRegistry.clear()
	return "\n".join(lines) + "\n"
