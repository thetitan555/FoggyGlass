class_name TraceHarness
extends RefCounted

## Contracts 2 + 3 (trace-harness.md): the minimal scripted-input behavioral-
## trace harness (TKT-P1.1R-01). A thin HEADLESS DRIVER above the sim — reads
## sim truth only through `InspectionView` (AD-011) and drives the sim only
## through a real `RecordPlaybackSource` in `Mode.PLAYBACK` (Tenet 2) — never a
## bespoke sim caller, never a `SimState`-internal read. Mirrors `SimHarness`'s
## existing shape (sim/sim_harness.gd): an all-static namespace of hooks, no
## instance state, no `step` of its own — it composes `InputScript.compile`,
## `RecordPlaybackSource`, `MoveRegistry`/`ProjectileRegistry`, `SimState.step`,
## and `InspectionView`, exactly the pieces Contract 2 names.
##
## WHAT IT IS NOT (trace-harness.md header). Not a TAS framework: compile a
## string -> buffer, replay N ticks headless, dump/assert chosen fields.
## Nothing more. No P2 mirroring, no `.trace` golden-file tooling, no dummy AI,
## no non-RecordPlaybackSource replay path (all explicitly deferred by the
## ticket/spec's "Not now").
##
## BLIND TO RENDER, BY CONSTRUCTION (acceptance criterion 6). Nothing here ever
## calls `InspectionView.px()`/`px_rect()` — every trace field is fixed-point
## sim truth. A trace is green while a render bug is live; that is documented,
## not a defect (trace-harness.md).

## Fixed field order (Contract 3's default movement-reconciliation field-set),
## per player, AFTER the leading "tick" field. `p{i}.` is prefixed onto each of
## these in `_trace_row`/`format_row` (JC: exact row text/field order logged as
## a latitude call — see docs/judgment-log.md).
const DEFAULT_FIELDS: PackedStringArray = [
	"state", "frame", "cat", "px", "py", "vx", "vy", "act", "stun", "sk", "face",
]

## Optional field-set names a caller may opt into (Contract 3 "Optional
## field-sets"). Passed as a subset of this array to `run`/`format_row`.
const OPTIONAL_BOXES: String = "boxes"
const OPTIONAL_ADVANTAGE: String = "advantage"
const OPTIONAL_LAST_HIT: String = "last_hit"

const _BOX_KIND_NAMES: Dictionary = {
	BoxView.KIND_HURT: "HURT",
	BoxView.KIND_HIT: "HIT",
	BoxView.KIND_THROW: "THROW",
	BoxView.KIND_PUSH: "PUSH",
}


# ---------------------------------------------------------------------------
# Contract 2 — the replay seam (headless driver).
# ---------------------------------------------------------------------------

## Compile `p1_text` (and `p2_text`, default "" -> a source that plays back
## NEUTRAL forever, RecordPlaybackSource's own documented empty-buffer
## behavior — Contract 2: "The P2 source defaults to a neutral (idle) script
## when only P1 is driven") into buffers, install `roster` into MoveRegistry
## (and `projectile_roster` into ProjectileRegistry, if non-empty), build a
## fresh initial SimState with BOTH players as `character_id` in its own
## `idle_state_id`, then run `ticks` ticks: produce_next() each
## RecordPlaybackSource (produce-before-query), `SimState.step`, and record a
## trace row from `InspectionView` over the resulting state (Contract 2, steps
## 1-4). Returns the ordered trace rows (row["tick"] == the state's tick right
## after that tick's step — see the walk-and-stop worked example in
## trace-harness.md: holding a direction for N ticks reads back p0.state at
## tick=N, matching 1-indexed "ticks simulated so far").
##
## CALLER OWNS ROSTER LIFETIME (mirrors every other MoveRegistry-driven test in
## this tree, e.g. test_command_recognition.gd): this does not call
## `MoveRegistry.clear()` — a caller running several scripts back-to-back keeps
## paying one install, and a single-script caller clears when it is done.
static func run(p1_text: String, p2_text: String, ticks: int, roster: Dictionary,
		character_id: int, projectile_roster: Dictionary = {},
		optional_fields: PackedStringArray = PackedStringArray()) -> Array[Dictionary]:
	MoveRegistry.install(roster)
	if not projectile_roster.is_empty():
		ProjectileRegistry.install(projectile_roster)

	var buf_p1: PackedInt32Array = InputScript.compile(p1_text)
	var buf_p2: PackedInt32Array = InputScript.compile(p2_text)

	var src_p1 := RecordPlaybackSource.new()
	src_p1.set_recorded_buffer(buf_p1)
	src_p1.set_mode(RecordPlaybackSource.Mode.PLAYBACK)

	var src_p2 := RecordPlaybackSource.new()
	src_p2.set_recorded_buffer(buf_p2)
	src_p2.set_mode(RecordPlaybackSource.Mode.PLAYBACK)

	assert(roster.has(character_id),
		"TraceHarness.run: character_id %d not present in the supplied roster" % character_id)
	var character: Character = roster[character_id]

	var state: SimState = SimState.new_initial()
	state.players[0].character_id = character_id
	state.players[0].state_id = character.idle_state_id
	state.players[1].character_id = character_id
	state.players[1].state_id = character.idle_state_id

	var rows: Array[Dictionary] = []
	for _t in range(ticks):
		# Produce-before-query (input.md "owned invariant"; training-mode.md /
		# TrainingHarness.step_once mirrors this exact ordering).
		var in_p1: int = src_p1.produce_next()
		var in_p2: int = src_p2.produce_next()
		state = SimState.step(state, in_p1, in_p2)
		rows.append(_trace_row(state, roster, optional_fields))
	return rows


## Build one trace row from `InspectionView` over `state` (Contract 2 step 4 /
## Contract 3 field-set). Reads ONLY through InspectionView/PlayerView/
## AdvantageView/HitEvent — no SimState-internal field is named here
## (acceptance criterion 4).
static func _trace_row(state: SimState, roster: Dictionary,
		optional_fields: PackedStringArray) -> Dictionary:
	var view := InspectionView.new(state, roster)
	var row: Dictionary = {"tick": view.tick()}
	for i in range(2):
		var p: PlayerView = view.player(i)
		var prefix: String = "p%d." % i
		row[prefix + "state"] = p.state_id
		row[prefix + "frame"] = p.frame_in_state
		row[prefix + "cat"] = p.state_category
		row[prefix + "px"] = int(p.position["x"])
		row[prefix + "py"] = int(p.position["y"])
		row[prefix + "vx"] = int(p.velocity["x"])
		row[prefix + "vy"] = int(p.velocity["y"])
		row[prefix + "act"] = p.actionable
		row[prefix + "stun"] = p.stun_remaining
		row[prefix + "sk"] = p.stun_kind
		row[prefix + "face"] = p.facing
		if optional_fields.has(OPTIONAL_BOXES):
			row[prefix + "boxes"] = _format_boxes(p.boxes)
	if optional_fields.has(OPTIONAL_ADVANTAGE):
		var a: AdvantageView = view.advantage()
		row["adv.value"] = a.value
		row["adv.plus_player"] = a.plus_player
		row["adv.neutral_restored"] = a.neutral_restored
	if optional_fields.has(OPTIONAL_LAST_HIT):
		var h: HitEvent = view.last_hit()
		if h != null:
			row["hit.attacker"] = h.attacker
			row["hit.defender"] = h.defender
			row["hit.damage_dealt"] = h.damage_dealt
			row["hit.was_block"] = h.was_block
			row["hit.contact_depth"] = h.contact_depth
			row["hit.air_height_hitstun_delta"] = h.air_height_hitstun_delta
	return row


static func _format_boxes(boxes: Array[BoxView]) -> String:
	var parts := PackedStringArray()
	for b in boxes:
		var name: String = _BOX_KIND_NAMES.get(b.kind, "?")
		parts.append("%s:%d,%d,%d,%d" % [name, int(b.rect["x"]), int(b.rect["y"]),
			int(b.rect["w"]), int(b.rect["h"])])
	return ";".join(parts)


# ---------------------------------------------------------------------------
# Contract 3 — trace dump (plain text, fixed field order, float-free, AD-019).
# ---------------------------------------------------------------------------

## Render one trace row as the fixed `key=value`, space-separated line
## (Contract 3 "Row = one dumped tick"). Field order: tick, then p0's
## DEFAULT_FIELDS in order, then p1's, then any requested optional fields.
static func format_row(row: Dictionary, optional_fields: PackedStringArray = PackedStringArray()) -> String:
	var parts := PackedStringArray()
	parts.append("tick=%d" % int(row["tick"]))
	for i in range(2):
		var prefix: String = "p%d." % i
		for f in DEFAULT_FIELDS:
			var key: String = prefix + f
			parts.append("%s=%s" % [key, _format_value(row[key])])
		if optional_fields.has(OPTIONAL_BOXES):
			var bkey: String = prefix + "boxes"
			parts.append("%s=%s" % [bkey, _format_value(row.get(bkey, ""))])
	if optional_fields.has(OPTIONAL_ADVANTAGE):
		for f in ["adv.value", "adv.plus_player", "adv.neutral_restored"]:
			if row.has(f):
				parts.append("%s=%s" % [f, _format_value(row[f])])
	if optional_fields.has(OPTIONAL_LAST_HIT):
		for f in ["hit.attacker", "hit.defender", "hit.damage_dealt", "hit.was_block",
				"hit.contact_depth", "hit.air_height_hitstun_delta"]:
			if row.has(f):
				parts.append("%s=%s" % [f, _format_value(row[f])])
	return " ".join(parts)


## Dump every row (Contract 3 "Dump" mode) as one newline-joined block.
static func format_rows(rows: Array[Dictionary], optional_fields: PackedStringArray = PackedStringArray()) -> String:
	var lines := PackedStringArray()
	for row in rows:
		lines.append(format_row(row, optional_fields))
	return "\n".join(lines)


static func _format_value(v) -> String:
	if typeof(v) == TYPE_BOOL:
		return "1" if v else "0"
	return str(v)


# ---------------------------------------------------------------------------
# Contract 3 — the inline-assert runner ("Assert" mode, the primary near-term
# mode). Checks a (tick, field, expected) triple against the rows `run` built
# and fails LOUDLY, naming tick/field/expected/actual (acceptance criterion 5).
# ---------------------------------------------------------------------------

## The row for `tick` (row["tick"] == tick), or an empty Dictionary if no such
## tick was recorded.
static func row_at(rows: Array[Dictionary], tick: int) -> Dictionary:
	for row in rows:
		if int(row["tick"]) == tick:
			return row
	return {}


## Check one inline assertion. Returns true and is silent on a pass; on a
## mismatch (or an unknown tick/field), prints a loud failure naming tick,
## field, expected, and actual, and returns false — the caller tallies pass/
## fail exactly like every other headless test's `_eq`/`_true` helper in this
## tree (e.g. test_record_playback.gd), so a script asserting a brief behavior
## the sim does not yet satisfy FAILS the suite rather than passing silently
## (acceptance criterion 5 — "the harness catches the omission").
static func check(rows: Array[Dictionary], tick: int, field: String, expected) -> bool:
	var row: Dictionary = row_at(rows, tick)
	if row.is_empty():
		printerr("[TraceHarness] assert FAIL — tick=%d field=%s expected=%s actual=<no such tick recorded (ran %d ticks)>"
			% [tick, field, str(expected), rows.size()])
		return false
	if not row.has(field):
		printerr("[TraceHarness] assert FAIL — tick=%d field=%s expected=%s actual=<unknown field>"
			% [tick, field, str(expected)])
		return false
	var actual = row[field]
	if actual != expected:
		printerr("[TraceHarness] assert FAIL — tick=%d field=%s expected=%s actual=%s"
			% [tick, field, str(expected), str(actual)])
		return false
	return true
