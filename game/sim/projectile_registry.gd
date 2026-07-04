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


## Install the authored projectile roster (data_id -> ProjectileData). Called once
## by whatever wires the match/scenario/test, before the first `step`.
static func install(roster: Dictionary) -> void:
	_roster = roster


## Clear the roster (test isolation between scenarios).
static func clear() -> void:
	_roster = {}


## The ProjectileData for an id, or null if unknown.
static func data(data_id: int) -> ProjectileData:
	if _roster.has(data_id):
		return _roster[data_id]
	return null
