# Flag Ledger

> Any role appends; the **owner** of the flagged artifact resolves. This ledger
> holds **open flags** (plus recently-resolved ones awaiting relay); once a
> resolution has been relayed, the entry moves to `flags-archive.md` — the
> permanent record — so this file stays a cheap read. Mechanism: raiser appends +
> tells the user; user relays to the owner; owner writes the resolution line,
> flips `[open]` to `[resolved]`, saves (git checkpoints happen per the
> protocol); user relays back. See `protocol.md` → "How a flag
> works."

---

### [open] 2026-07-04 · raised-by: Developer · owner: Architect · re: move-format.md (Keyframe.invuln) / combat-resolution.md (phase 4/5)
Problem: `character-a.md` structurally requires invulnerability to be a real, enforced
mechanic — `2H` "upper-body strike invuln 1–8" beating a jump-in (criterion 4), each DP
"strike-invulnerable from frame 1 through at least its first active frame" and `623H`
"also throw-invulnerable" (criterion 6), and back dash "invuln 1–7 (strike+throw)"
(Movement table) — but the engine has no consumption path for invulnerability at all.
`Keyframe.invuln_strike` / `invuln_throw` (move-format.md → Keyframe) are authored fields
only: nothing in `step_phases.gd` reads them. Phase 4 (`phase4_overlap`) records a contact
whenever an attacker's hitbox/throwbox overlaps a defender's hurtbox, with no check against
the defender's own invuln state; phase 5 resolves every such contact as hit-or-block. There
is also no notion of a "throw" vs "strike" hit *category* on `HitBox` to gate throw-invuln
against (only the `is_throw` flag, which marks the attacking box, not what a defender is
immune to). This is a genuine format/engine gap, not a per-move authoring choice — I can
author the `invuln_strike`/`invuln_throw` flags on A's keyframes (DP, `2H`, back dash) so
the data is ready, but they will be **inert**: nothing in the sim will make those frames
actually whiff an incoming hit, so criteria 4 and 6 (and the back dash's invuln) cannot
pass end-to-end until this is resolved. Per the ticket ("no engine changes... if you find
yourself needing an engine change to author a move, that's a spec/format gap — flag it"),
raising rather than adding ad hoc consumption code myself, since this touches phase 4/5
(a contract multiple roles build against) and needs a real design (does invuln fully
prevent the contact from being recorded, or does it record-but-no-op; does a `HitBox` need
a `hit_kind` — strike/throw/projectile — to check the right invuln flag against; how does
this interact with projectile contacts, which bypass the character's active-hit-id memory
entirely).
---
Resolution (owner fills): …
---

### [open] 2026-07-04 · raised-by: Developer · owner: Architect · re: move-format.md (ButtonMapEntry) / input_buffer.gd (command recognition)
Problem: authoring character A's movement and throw surfaced two commands the current
command-recognition schema (`ButtonMapEntry` + `InputBuffer`) cannot express:
1. **A pure-direction command (jump, `7/8/9`).** `InputBuffer.button_buffered` returns
   `false` outright when `button_index < 0` ("no button"), so a directionless command has
   no recognition path at all. A jump could in principle be authored as a one-token
   "UP" `motion` (the schema already lets a motion-only entry trigger with no button, per
   `InputBuffer.entry_satisfied`'s `button_index < 0` branch for motions), but the token
   vocabulary (`InputBuffer._motion_tokens`) is a fixed `match` over `MOTION_236`/
   `MOTION_623` in `input_buffer.gd` — adding a jump motion id means editing engine code,
   which this ticket may not do.
2. **A two-button chord (throw, `L+H`).** `ButtonMapEntry` names exactly one button bit
   (`button_index`) plus a *direction* gate (`required_direction`, which only inspects
   direction bits, never button bits) — there is no way to require two buttons at once.
   Unlike jump, there is no safe single-button stand-in for A: all three buttons already
   have standing normals (`5L`/`5M`/`5H`), and `button_map` resolves first-match-wins, so
   aliasing the throw to any bare button would permanently shadow that normal (I checked —
   authoring it on `BUTTON_2` alone makes `5H`, load-bearing for the kit's 3-frame-link
   route, unreachable).
Both are authored as real `MoveState`s with full frame data (`STATE_PREJUMP`/`STATE_JUMP_*`
in `game/content/character_a.gd`'s jump arc; `STATE_THROW` with its throwbox/tech-window/
knockdown) — the content is ready — but neither has a `button_map` entry in this batch, so
neither is reachable by a live input stream. Dev tests exercise both by driving a player
directly into the state (so the throw's connect/tech/knockdown *resolution* and the jump
arc's *keyframe motion* are still verified), but "press up to jump" / "press L+H to throw"
are not yet playable end-to-end. Per the ticket, flagging rather than editing
`input_buffer.gd`/`ButtonMapEntry` myself, since both are contract surface
(`move-format.md`) other content and the training-mode input-display ticket (TKT-P1-09)
will read through.
---
Resolution (owner fills): …
---

_No other open flags._
