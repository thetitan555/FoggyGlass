class_name SimHarness
extends RefCounted

## Determinism / serialization harness HOOKS (TKT-P0-11). All static — no state.
##
## QA OWNS THE HARNESS AND ITS VERDICTS (AD-020, ticket note); this class provides
## only the mechanical hooks QA's harness drives:
##   - snapshot dump/load  (SimState.to_dict / from_dict, wrapped for convenience)
##   - a headless REPLAY RUNNER: start state + a recorded input stream -> final
##     canonical hash (and, optionally, a per-tick hash trace).
##   - a golden TRUTH DUMP of InspectionView (fixed-point only — NO px, AD-019),
##     stable/serializable so QA can golden-file it.
## The canonical hash itself is SimState.hash_state (AD-023); this class does not
## re-implement it.
##
## Everything here reads the sim through the same pure step / read-only surface the
## game uses, so a harness run is bit-identical to a real run (Tenet 1).


# ---------------------------------------------------------------------------
# Snapshot dump / load. Thin wrappers so a harness has one entry point and the
# round-trip contract (dump -> load -> identical hash) is exercised in one place.
# ---------------------------------------------------------------------------

## Dump a SimState to a plain-data snapshot Dictionary (deep, float-free).
static func dump_state(state: SimState) -> Dictionary:
	return state.to_dict()


## Load a SimState from a snapshot produced by dump_state. Exact inverse.
static func load_state(snapshot: Dictionary) -> SimState:
	return SimState.from_dict(snapshot)


# ---------------------------------------------------------------------------
# Headless replay runner (simulation.md criteria 1-3). Given a start state and two
# recorded input streams (one per player, frame-indexed), advance to the end and
# return the final canonical hash. This is the primitive QA's determinism harness
# drives: replay one fixed input stream twice -> identical final hash (criterion 2).
#
# The streams are plain PackedInt32Array recordings — exactly what a LocalDevice
# source records / a Replay source reads (input.md), fed here without any engine.
# ---------------------------------------------------------------------------

## Advance `start` by min(len(in_p1), len(in_p2)) ticks, feeding recorded frames.
## Returns the final SimState. Non-mutating: `start` is untouched (step is pure).
static func run_replay(start: SimState, in_p1: PackedInt32Array, in_p2: PackedInt32Array) -> SimState:
	var n: int = min(in_p1.size(), in_p2.size())
	var s: SimState = start
	for f in range(n):
		s = SimState.step(s, in_p1[f], in_p2[f])
	return s


## Convenience: the final canonical hash after a replay (criterion 2's primitive).
static func replay_final_hash(start: SimState, in_p1: PackedInt32Array, in_p2: PackedInt32Array) -> int:
	return run_replay(start, in_p1, in_p2).hash_state()


## A per-tick hash trace of a replay: hash BEFORE each tick, then the final hash.
## Length = ticks + 1. Lets QA localize the exact tick a determinism/round-trip
## divergence first appears rather than only seeing the final mismatch.
static func replay_hash_trace(start: SimState, in_p1: PackedInt32Array, in_p2: PackedInt32Array) -> PackedInt64Array:
	var n: int = min(in_p1.size(), in_p2.size())
	var trace: PackedInt64Array = PackedInt64Array()
	var s: SimState = start
	trace.append(s.hash_state())
	for f in range(n):
		s = SimState.step(s, in_p1[f], in_p2[f])
		trace.append(s.hash_state())
	return trace


# ---------------------------------------------------------------------------
# Golden truth dump of the inspection surface (inspection-surface.md criteria 4/6).
# Produces a stable, plain-data, FIXED-POINT-ONLY dictionary of the sim's inspection
# truth for a state — NO px projection (AD-019), so a golden taken with or without a
# UI active is identical. QA golden-files this. Field order is fixed so the dump is
# byte-diffable.
# ---------------------------------------------------------------------------

## Dump the full inspection truth for `state` (resolved against `roster`) as a plain
## Dictionary. Every value is int / bool / int-array — float-free by construction
## (the *View classes carry only fixed-point truth). Suitable for golden files.
static func dump_inspection_truth(state: SimState, roster: Dictionary = {}) -> Dictionary:
	var view := InspectionView.new(state, roster)
	var out: Dictionary = {
		"tick": view.tick(),
		"players": [],
		"projectiles": [],
		"advantage": _dump_advantage(view.advantage()),
		"last_hit": _dump_last_hit(view.last_hit()),
	}
	for i in range(2):
		out["players"].append(_dump_player(view.player(i)))
	for pv in view.projectiles():
		out["projectiles"].append(_dump_projectile(pv))
	return out


static func _dump_player(pv: PlayerView) -> Dictionary:
	var boxes: Array = []
	for b in pv.boxes:
		boxes.append(_dump_box(b))
	return {
		"character_id": pv.character_id,
		"state_id": pv.state_id,
		"state_category": pv.state_category,
		"frame_in_state": pv.frame_in_state,
		"state_duration": pv.state_duration,
		"actionable": pv.actionable,
		"pos_x": int(pv.position["x"]),
		"pos_y": int(pv.position["y"]),
		"vel_x": int(pv.velocity["x"]),
		"vel_y": int(pv.velocity["y"]),
		"facing": pv.facing,
		"health": pv.health,
		"hitstop_remaining": pv.hitstop_remaining,
		"stun_remaining": pv.stun_remaining,
		"stun_kind": pv.stun_kind,
		"combo_hit_count": int(pv.combo["hit_count"]),
		"combo_scaling_pct": int(pv.combo["scaling_pct"]),
		"combo_damage_total": int(pv.combo["damage_total"]),
		"input_current": pv.input_current,
		"input_history": pv.input_history,
		"boxes": boxes,
	}


static func _dump_box(b: BoxView) -> Dictionary:
	var d: Dictionary = {
		"kind": b.kind,
		"x": int(b.rect["x"]),
		"y": int(b.rect["y"]),
		"w": int(b.rect["w"]),
		"h": int(b.rect["h"]),
	}
	if not b.hit.is_empty():
		d["hit"] = {
			"damage": int(b.hit["damage"]),
			"hitstun": int(b.hit["hitstun"]),
			"blockstun": int(b.hit["blockstun"]),
			"hitstop": int(b.hit["hitstop"]),
			"id_group": int(b.hit["id_group"]),
			"rehit_interval": int(b.hit["rehit_interval"]),
		}
	return d


static func _dump_projectile(pv: ProjectileView) -> Dictionary:
	var box_dump = null
	if pv.box != null:
		box_dump = _dump_box(pv.box)
	return {
		"owner": pv.owner,
		"pos_x": int(pv.position["x"]),
		"pos_y": int(pv.position["y"]),
		"lifetime_remaining": pv.lifetime_remaining,
		"box": box_dump,
	}


static func _dump_advantage(a: AdvantageView) -> Dictionary:
	return {
		"value": a.value,
		"plus_player": a.plus_player,
		"frames_to_neutral": a.frames_to_neutral,
		"neutral_restored": a.neutral_restored,
	}


static func _dump_last_hit(h: HitEvent) -> Dictionary:
	if h == null:
		return {}
	return {
		"attacker": h.attacker,
		"defender": h.defender,
		"damage_dealt": h.damage_dealt,
		"was_block": h.was_block,
		"scaling_applied": h.scaling_applied,
		"combo_count_after": h.combo_count_after,
		"tick": h.tick,
	}
