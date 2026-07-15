class_name ButtonMapEntry
extends Resource

## One entry in a Character.button_map (move-format.md → Character.button_map;
## AD-018). Maps a generic button (+ optional direction/motion condition) to a
## destination state_id. This is the ONLY place buttons gain meaning — the input
## layer stays semantically blank (AD-002/AD-018).
##
## The runtime (phase 2, TKT-P0-06 direct transitions / TKT-P0-08 buffered) reads
## this to turn a raw InputFrame into a legal transition. Authored as `.tres` data.

## Which generic button triggers this (InputFrame.BUTTON_0..7 bit index 0..7).
## -1 = no button required (a pure motion command, OR — with motion == 0 too —
## a pure-direction command like jump, AD-032).
@export var button_index: int = 0

## Optional SECOND required button (AD-032), forming a two-button CHORD with
## `button_index`: both bits must be held on the SAME buffered frame (not merely
## both somewhere within the window — see InputBuffer.entry_satisfied). -1 = no
## chord (a plain single-button or pure-direction command). Lets a chord (throw,
## L+H) be authored without stealing either bare button — the chord entry must be
## listed BEFORE the bare-button entries it shares a button with so first-match-
## wins routes the simultaneous press to the chord (move-format.md).
@export var chord_button_index: int = -1

## Optional required direction (raw InputFrame direction bits, e.g. DOWN for a
## crouching normal). 0 = any/none. Directions are RAW here; the sim resolves
## forward/back by facing before matching (AD-002) via the command condition.
@export var required_direction: int = 0

## Optional motion command id (e.g. a 236 / 623). 0 = none. Motion recognition is
## sim-side over input_history (AD-022, TKT-P0-08); this names which command.
@export var motion: int = 0

## Destination state_id this input produces.
@export var target_state_id: int = 0

## Double-tap recognition (AD-046, TKT-P2-02). When true, the command is a
## DOUBLE-TAP of `required_direction`: pressed -> released -> pressed within the
## slice-wide double-tap window (InputBuffer.DOUBLE_TAP_WINDOW), recognized by the
## one recognizer over `input_history` (pure function of history, Tenet 2). Shares
## the pure-direction shape (`button_index == -1`, `motion == 0`,
## `chord_button_index == -1`; `required_direction` names the tapped direction) but
## is a DISTINCT recognition path from a plain held direction (AD-032) — a
## continuous hold never satisfies a double-tap, only a genuine press-release-
## press. Routes to a dash state (character B's ground dash; character A's
## `66`/`44` -> `STATE_DASH_F`/`STATE_DASH_B`).
@export var double_tap: bool = false
