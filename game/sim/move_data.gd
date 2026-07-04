class_name MoveData
extends RefCounted

## The ONE canonical move-data derivation (move-format.md → "Derived frame data";
## AD-001, AD-006, AD-008). All static functions — no state, never instantiated
## (FP/InputFrame packaging pattern). Two responsibilities:
##
##   1. Per-frame BOX RESOLUTION (AD-001): resolve a MoveState's active
##      hurt/hit/throw/push boxes for a given (frame_in_state, facing, position) to
##      world-space ResolvedBoxes — DERIVED, not stored. The sim tests these for
##      overlap (phase 4) and the inspection surface projects them (BoxView), so
##      there is ONE source of geometry truth.
##   2. DERIVED FRAME DATA: startup / active / recovery / total from a move's
##      timeline, computed this ONE way so no two characters disagree about what
##      "startup" means (move-format.md criterion 2). Static advantage is filled by
##      the advantage formula (TKT-P0-07, Advantage), not re-derived here.
##
## No floats reach here (AD-014/019): every value consumed is a baked fixed-point
## integer. Character-local box geometry is flipped by facing and offset by position
## with integer add/negate only.


# ---------------------------------------------------------------------------
# Box resolution (AD-001). Character-local box -> world-space AABB.
#
# Flip by facing: for facing == +1 (right), local x is world x; for facing == -1
# (left), the box mirrors about the character origin, so a local box [x, x+w)
# becomes world [-(x+w), -x). Then offset by the character's world position.
# Integer ops only (AD-014). This is the single geometry projection every consumer
# (overlap test + inspection overlay) shares.
# ---------------------------------------------------------------------------

## World-space x of a character-local box given facing and the character's world x.
## For facing +1: world_x = pos_x + local_x. For facing -1: mirror, world_x =
## pos_x - (local_x + local_w).
static func _world_x(local_x: int, local_w: int, facing: int, pos_x: int) -> int:
	if facing >= 0:
		return pos_x + local_x
	return pos_x - (local_x + local_w)


## PUBLIC world-space x for a character-local, ZERO-WIDTH offset (a point, not a
## box) given facing and the character's world x — the same local->world
## convention resolve_box/resolve_hit_box use, exposed for callers that need to
## flip a bare offset (not a box) by facing, e.g. a projectile spawn point
## (TKT-P1-0P, StepPhases._try_spawn_projectile). A point has no width to account
## for in the mirror, so this is `_world_x(local_x, 0, facing, pos_x)` named for
## its call site's intent.
static func world_offset_x(local_x: int, facing: int, pos_x: int) -> int:
	return _world_x(local_x, 0, facing, pos_x)


## Resolve one authored Box (hurt / throw / push) to a world-space ResolvedBox of the
## given kind. y is not flipped (vertical is facing-independent).
static func resolve_box(b: Box, kind: int, facing: int, pos_x: int, pos_y: int) -> ResolvedBox:
	var wx: int = _world_x(b.x, b.w, facing, pos_x)
	var wy: int = pos_y + b.y
	return ResolvedBox.make(kind, wx, wy, b.w, b.h)


## Resolve one authored HitBox to a world-space HIT (or THROW) ResolvedBox, carrying
## the originating HitBox for hit data / single-hit grouping.
static func resolve_hit_box(hb: HitBox, facing: int, pos_x: int, pos_y: int) -> ResolvedBox:
	var b: Box = hb.box
	var wx: int = _world_x(b.x, b.w, facing, pos_x)
	var wy: int = pos_y + b.y
	var kind: int = BoxView.KIND_THROW if hb.is_throw else BoxView.KIND_HIT
	return ResolvedBox.make(kind, wx, wy, b.w, b.h, hb)


## Resolve ALL active boxes for a move at a frame (1-indexed frame_in_state) to
## world space: every hurtbox / hitbox / throwbox in every keyframe covering the
## frame, plus the move's pushbox if supplied. Derived each tick (AD-001). Order is
## fixed (pushbox, then keyframes in timeline order, hurt then hit then throw within
## each) so the resolved list — and any golden of it — is deterministic.
static func resolve_boxes(move: MoveState, frame: int, facing: int, pos_x: int, pos_y: int,
		pushbox: Box = null) -> Array[ResolvedBox]:
	var out: Array[ResolvedBox] = []
	if pushbox != null:
		out.append(resolve_box(pushbox, BoxView.KIND_PUSH, facing, pos_x, pos_y))
	for kf in move.timeline:
		if not kf.covers(frame):
			continue
		for hb in kf.hurtboxes:
			out.append(resolve_box(hb, BoxView.KIND_HURT, facing, pos_x, pos_y))
		for hitb in kf.hitboxes:
			out.append(resolve_hit_box(hitb, facing, pos_x, pos_y))
		for tb in kf.throwboxes:
			out.append(resolve_box(tb, BoxView.KIND_THROW, facing, pos_x, pos_y))
	return out


# ---------------------------------------------------------------------------
# Derived frame data (move-format.md "Derived frame data", one canonical
# definition — AD-008). Computed from the timeline; the SAME derivation for every
# character (criterion 2/4).
#
#   Startup  = frames before the FIRST frame any HitBox is active.
#   Active   = frames during which any HitBox is active (first active .. last active).
#   Recovery = frames from end of active to the first actionable frame.
#   Total    = duration (frames to first actionable).
#
# "First actionable frame" for a move that plays once is `duration + 1` (the frame
# after the state ends); recovery = total - (last_active). For a move with no
# hitboxes (idle/walk) startup/active/recovery are 0 and total = duration.
# ---------------------------------------------------------------------------

## First frame (1-indexed) any HitBox is active, or 0 if the move has no hitboxes.
static func _first_active_frame(move: MoveState) -> int:
	var first: int = 0
	for kf in move.timeline:
		if kf.hitboxes.is_empty():
			continue
		if first == 0 or kf.frame_start < first:
			first = kf.frame_start
	return first


## Last frame (1-indexed) any HitBox is active, or 0 if the move has no hitboxes.
static func _last_active_frame(move: MoveState) -> int:
	var last: int = 0
	for kf in move.timeline:
		if kf.hitboxes.is_empty():
			continue
		if kf.frame_end > last:
			last = kf.frame_end
	return last


## The canonical derived frame data for a move (static, pinned). Advantage fields are
## left 0 here; the advantage formula (TKT-P0-07, Advantage.static_for_move) fills
## on_hit_adv / on_block_adv so advantage stays a SINGLE formula in one place
## (move-format.md: "this format only supplies the inputs").
static func frame_data(move: MoveState) -> FrameData:
	var fd := FrameData.new()
	fd.total = move.duration
	var first: int = _first_active_frame(move)
	var last: int = _last_active_frame(move)
	if first == 0:
		# No hitboxes: a non-attacking state (idle/walk/reaction). No startup/active.
		fd.startup = 0
		fd.active = 0
		fd.recovery = 0
	else:
		fd.startup = first - 1              # frames before first active
		fd.active = last - first + 1        # inclusive active span
		fd.recovery = move.duration - last  # end of active -> first actionable
	# on_hit_adv / on_block_adv wired by Advantage (TKT-P0-07).
	Advantage.fill_static(fd, move)
	return fd
