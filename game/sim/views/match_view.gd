class_name MatchView
extends RefCounted

## Read-only projection of MatchState (inspection-surface.md → MatchView, AD-048).
##
## Sibling to InspectionView (which reads a SimState), not a method on it — the
## match layer wraps SimState in a DIFFERENT serialized root (MatchState), so it
## gets its own read-only view over that root, following the same "single
## source of truth, plain snapshot-able returns, no mutator" discipline
## (inspection-surface.md "Principles"). A caller holding a MatchState builds
## `InspectionView.new(match_state.sim, roster)` for player-level truth and
## `MatchView.new(match_state)` for match-level truth — the two seams compose,
## neither reaches into the other's internals.
##
## Every field is copied out at construction (read-only by construction, same
## discipline as PlayerView) — plain int / bool / PackedInt32Array, no floats
## (AD-019), so this is golden-file-able exactly like every other truth view.

## Per-player current health ([h0, h1]) — also readable via PlayerView.health;
## surfaced here too so a health-bar UI can read the whole match picture off
## ONE view without also constructing an InspectionView.
var health: PackedInt32Array = PackedInt32Array([0, 0])

## Per-player round wins ([w0, w1]) — the round pips.
var round_wins: PackedInt32Array = PackedInt32Array([0, 0])

## Frames remaining in the round (the clock; frame-counted, never wall-clock —
## AD-048/Tenet 1).
var round_timer: int = 0

## ROUND_START / ACTIVE / ROUND_END / MATCH_END (mirrors MatchState.PHASE_*).
var match_phase: int = MatchState.PHASE_ROUND_START

## True while the tie-at-match-point single sudden-death round is live.
var sudden_death: bool = false

## KO / TIMEOUT / DOUBLE_KO / NONE (mirrors MatchState.REASON_*) — serialized
## truth, so *why* a round/match ended is legible on its face, not a render
## inference (charter; match-flow.md "Legibility").
var last_round_end_reason: int = MatchState.REASON_NONE

## Which round this is (best-of / sudden-death numbering).
var round_index: int = 0


func _init(match_state: MatchState) -> void:
	health = PackedInt32Array([
		match_state.sim.players[0].health,
		match_state.sim.players[1].health,
	])
	round_wins = match_state.round_wins.duplicate()
	round_timer = match_state.round_timer
	match_phase = match_state.match_phase
	sudden_death = match_state.sudden_death
	last_round_end_reason = match_state.last_round_end_reason
	round_index = match_state.round_index
