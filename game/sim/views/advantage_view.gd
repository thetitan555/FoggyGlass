class_name AdvantageView
extends RefCounted

## Read-only live-advantage view (inspection-surface.md → AdvantageView; AD-008).
##
## The truthful "who is plus RIGHT NOW": the one advantage formula
## (defender_remaining_stun - attacker_remaining_recovery) evaluated on the real
## situation, so it reflects cancels, late (meaty) contact, and current remaining
## recovery. Read from the sim's ONE advantage function (Advantage.live); never
## re-derived here (inspection-surface.md criterion 3). All integer — no floats.

## `defender_remaining_stun - attacker_remaining_recovery`, cancel-aware.
var value: int = 0

## Which player is plus: 0, 1, or PLUS_NONE (neither / exactly even).
var plus_player: int = PLUS_NONE

## Frames until BOTH players are actionable (0 when both already are).
var frames_to_neutral: int = 0

## True only on the tick both players become actionable (the neutral-restored flag).
var neutral_restored: bool = false

const PLUS_NONE: int = -1


static func make(p_value: int, p_plus_player: int, p_frames_to_neutral: int,
		p_neutral_restored: bool) -> AdvantageView:
	var a := AdvantageView.new()
	a.value = p_value
	a.plus_player = p_plus_player
	a.frames_to_neutral = p_frames_to_neutral
	a.neutral_restored = p_neutral_restored
	return a
