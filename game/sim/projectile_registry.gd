class_name ProjectileRegistry
extends RefCounted

## The immutable authored ProjectileData registry (AD-021, AD-024's "authored
## content is a fixed input, not sim state" reasoning applied to projectiles —
## mirrors MoveRegistry exactly, same rationale, same install-once discipline).
##
## WHY THIS EXISTS. A live `Projectile` (the runtime SimState entity) carries a
## `hitbox` reference, but the hitbox is authored `.tres` data (AD-024 keeps
## authored content OUT of SimState/serialization — only mutable sim truth is
## serialized). So a live projectile's serialized form (Projectile.to_dict) cannot
## carry the HitBox object itself; it carries a stable integer `data_id` instead,
## and THIS registry is what a restore path resolves that id back to its
## `ProjectileData` (and therefore its `hitbox`) — exactly how `character_id`
## resolves through `MoveRegistry` for a player's move data.
##
## DETERMINISM (Tenet 1). Installed ONCE at scenario/match wiring, immutable
## during a run, so `step` stays a pure function of (state, inputs) given the
## fixed content — identical reasoning and identical shape to `MoveRegistry`.
##
## All static — a namespace over one static roster, like MoveRegistry.

## data_id -> ProjectileData. Immutable during a run; replaced wholesale at wiring.
static var _roster: Dictionary = {}


## Install the authored projectile roster, replacing it wholesale (mirrors
## MoveRegistry.install's convention: called once by whatever wires the match/
## scenario/test, before the first `step`).
##
## AD-049: `ProjectileData.id` (`data_id`) is a GLOBAL namespace across the
## WHOLE roster, not per-character -- so a caller wiring more than one
## character's projectiles must MERGE their registries, and that merge is
## exactly where a same-id collision would previously overwrite silently
## (`training_mode.gd`'s A+B merge, resolved by this fix). Accepts either:
##   - a single `data_id -> ProjectileData` Dictionary (the common single-
##     source case; every existing call site), installed as-is; or
##   - an `Array` of such Dictionaries, MERGED here with duplicate-id
##     rejection -- a `data_id` repeated across two sources FAILS LOUDLY
##     (`push_error`, install is NOT applied, the prior roster is left
##     untouched) instead of a caller's own dict-merge loop silently
##     overwriting one character's projectile with another's.
## Returns true on a clean install, false (with a push_error) on a rejected
## duplicate.
static func install(roster) -> bool:
	var sources: Array = roster if roster is Array else [roster]
	var merged: Dictionary = {}
	for source in sources:
		for data_id in source:
			if merged.has(data_id):
				push_error("ProjectileRegistry.install: duplicate data_id %s across sources -- install REJECTED (AD-049 global-namespace uniqueness)." % str(data_id))
				return false
			merged[data_id] = source[data_id]
	_roster = merged
	return true


## Clear the roster (test isolation between scenarios).
static func clear() -> void:
	_roster = {}


## The ProjectileData for an id, or null if unknown.
static func data(data_id: int) -> ProjectileData:
	if _roster.has(data_id):
		return _roster[data_id]
	return null
