class_name FrameData
extends RefCounted

## Static, pinned frame-data view for one move state (inspection-surface.md →
## FrameData; move-format.md "Derived frame data"; AD-008 static advantage).
##
## A property of the move IN ISOLATION: startup/active/recovery derived from the
## move's timeline (one canonical derivation, MoveData.frame_data), and the static
## on-hit / on-block advantage computed at the PINNED reference (contact on the
## move's first active frame, attacker uncancelled — AD-008). All integer frame
## counts — no floats. This is what a frame-data display reads.
##
## A default (all-zero) FrameData is returned by the inspection surface for an
## unknown character/state, so a caller always gets a typed result.

## Derived per move-format.md. `total` is the whole move length to first actionable.
var startup: int = 0
var active: int = 0
var recovery: int = 0
var total: int = 0

## Static advantage (AD-008 pinned reference). Filled at TKT-P0-07 (the advantage
## formula); zero until then. Positive => attacker plus, negative => defender plus.
var on_hit_adv: int = 0
var on_block_adv: int = 0
