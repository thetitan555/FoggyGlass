class_name InspectionView
extends RefCounted

## The read-only inspection surface — the systems/content seam (AD-011,
## inspection-surface.md, simulation.md "The inspection surface").
##
## A read-only accessor layer over ONE SimState. The debug training mode, the QA
## determinism/golden harness, and any player-facing UI all read sim truth THROUGH
## this one surface and never reach into sim internals. This is the single source
## of truth (inspection-surface.md "Single source"): advantage is read from the
## sim's ONE advantage function, frame data from the sim's ONE derivation — debug
## mode and QA cannot disagree because they read the same numbers.
##
## READ-ONLY BY CONSTRUCTION (inspection-surface.md criterion 2). This class holds
## a reference to a SimState and exposes only queries. It has no mutator and no
## `step` — driving the sim is the control layer's job (training-mode.md), never
## this surface's. After any sequence of inspection calls the state hash is
## unchanged (the surface never writes state). Every read that could otherwise
## alias sim internals returns a plain-data VIEW (see the *View classes), so a
## caller cannot reach a live sub-object and mutate it.
##
## FIXED-POINT TRUTH ONLY (AD-019, inspection-surface.md criterion 4/6). Every
## snapshot-able truth view carries ONLY fixed-point integer truth — no floats — so
## QA can golden-file it without cross-platform float drift defeating the harness
## (Tenet 1). Pixel projection (fixed->px) is a render-only helper (see px/px_rect)
## and is NEVER a field of a truth view — it is excluded from every
## golden/determinism snapshot.
##
## SCOPE (TKT-P0-04, since extended). TKT-P0-04 landed the FULL API SHAPE (so
## later tickets compile against it) implemented minimally over the current
## SimState. `tick()` and the core PlayerView fields were live from the start.
## `frame_data()`/`advantage()`/`last_hit()` were wired at TKT-P0-05/07 (move
## format / hit-stun-advantage) through the sim's one derivation/one function —
## never a re-implementation. Resolved `boxes` (BoxView) landed at TKT-P0-05/06;
## the projectile RUNTIME (spawn/integrate/resolve/despawn) that fills
## `projectiles()` with non-empty results is TKT-P1-0P (the read shape itself was
## already fixed here at P0-04). This surface existing early is what let
## TKT-P0-10 / TKT-P0-11 and the P1 tickets read through one seam from day one.
##
## CHARACTER-AGNOSTIC (inspection-surface.md criterion 5). No character-specific
## code lives here; the surface reads whatever character/state exists.

## The state this view reads. Assigned at construction and never mutated here.
var _state: SimState = null

## The character roster this view resolves frame data / boxes against (TKT-P0-05+).
## A Dictionary of character_id -> Character resource. Optional: the core reads
## (tick, position, stun, ...) need no roster; only frame_data()/boxes do. Kept as a
## plain reference the caller supplies (the sim's authored data), read-only here.
var _roster: Dictionary = {}


## Construct a view over a SimState (and, optionally, the character roster the sim
## resolves move data against). The view does not own or copy the state; it reads
## it live. Because the surface is read-only, sharing the live handle is safe — a
## caller can build one per frame or reuse one; either way it never writes.
func _init(state: SimState, roster: Dictionary = {}) -> void:
	_state = state
	_roster = roster


# ---------------------------------------------------------------------------
# The API (inspection-surface.md → "The API").
# ---------------------------------------------------------------------------

## The authoritative sim tick (simulation.md: the clock is state.tick).
func tick() -> int:
	return _state.tick


## A read-only view of player `i` (i in {0,1}).
func player(i: int) -> PlayerView:
	assert(i == 0 or i == 1, "InspectionView.player: index %d out of range 0..1" % i)
	return PlayerView.new(_state, i, _roster)


## Live projectiles (AD-021). Projects whatever SimState.projectiles currently
## holds (populated/drained by the TKT-P1-0P spawn/integrate/resolve/despawn
## runtime); empty when none are out. The shape was fixed at P0 so callers could
## compile against it before the runtime landed.
func projectiles() -> Array[ProjectileView]:
	var out: Array[ProjectileView] = []
	for idx in range(_state.projectiles.size()):
		out.append(ProjectileView.new(_state, idx))
	return out


## Static, pinned frame data for a character's move state (move-format.md derived
## frame data; AD-008 static advantage). Reads the sim's ONE derivation
## (MoveData.frame_data), never a re-implementation (inspection-surface.md
## criterion 3). Returns an empty FrameData if the character/state is unknown or the
## roster was not supplied — so a caller always gets a typed result.
##
## WIRED PROGRESSIVELY: the derivation (startup/active/recovery) lands at TKT-P0-05;
## the static on-hit/on-block advantage lands at TKT-P0-07 (the advantage formula).
func frame_data(character_id: int, state_id: int) -> FrameData:
	if not _roster.has(character_id):
		return FrameData.new()
	var character: Character = _roster[character_id]
	var move: MoveState = character.get_state(state_id)
	if move == null:
		return FrameData.new()
	return MoveData.frame_data(move)


## Live, cancel-aware advantage for the current interaction (AD-008 live value).
## Reads the sim's ONE advantage function (Advantage.live) so debug mode and QA
## agree (inspection-surface.md criterion 3). WIRED AT TKT-P0-07.
func advantage() -> AdvantageView:
	return Advantage.live(_state, _roster)


## The most recent resolved hit, or null if none has resolved. WIRED AT TKT-P0-07
## (hit resolution records the last hit into state; this reads it out). Reads the
## sim's own `last_hit` record (a serialized SimState field added at TKT-P0-07,
## flag F-002) and projects it to a plain HitEvent view.
func last_hit() -> HitEvent:
	if _state.last_hit == null:
		return null
	return HitEvent.from_record(_state.last_hit)


# ---------------------------------------------------------------------------
# Render projection (render-only, never snapshotted — AD-019,
# inspection-surface.md "Render projection"). These produce FLOAT pixel values
# for DRAWING ONLY. They are NOT fields of any truth view above and the
# golden/determinism harness never snapshots them. The single source of truth QA
# snapshots stays fixed-point (the *View classes carry only integers).
# ---------------------------------------------------------------------------

## Pixels per game unit for the render projection. A view-only constant; changing it
## rescales drawing and touches NO sim truth (no truth view carries px).
const PX_PER_UNIT: float = 1.0

## Project a fixed-point scalar to float pixels (render-only, AD-019). Never feed the
## result back into the sim; never store it in a truth view.
static func px(fixed_value: int) -> float:
	return FP.to_float(fixed_value) * PX_PER_UNIT

## Project a fixed-point AABB {x,y,w,h} to a float pixel Rect2 (render-only).
static func px_rect(rect: Dictionary) -> Rect2:
	return Rect2(
		px(int(rect["x"])), px(int(rect["y"])),
		px(int(rect["w"])), px(int(rect["h"])))
