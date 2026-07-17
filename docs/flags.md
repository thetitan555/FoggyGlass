# Flag Ledger

> Open flags only (plus resolved-awaiting-relay). Closed entries live in
> `flags-archive.md`. Mechanism, ownership, and relay: `protocol.md` → "How a
> flag works."

---

### [open] 2026-07-16 · raised-by: User (P2 human gate) · owner: Developer · re: input path → sim (`game/`)
Problem: **~1 second of input lag on both characters.** Play/pause (`P`/`N`) respond
immediately; character commands do not. Reported at the P2 human-inspection gate.
This is tax under `audit-criterion.md` ("dropped/eaten inputs" / clunky UX are tax,
always) and it makes the gate's whole legibility question unanswerable — you cannot
judge whether a mixup is readable *as it happens* through a second of lag.
Diagnosis lead (a hypothesis to test, not a finding — the Developer owns the call):
that `P`/`N` are unaffected suggests the defect is below the Godot input layer and in
the sim-driver path — e.g. the sim not advancing at the intended fixed rate, or
stepping only on input events rather than on the clock. Note this may be the common
root of the two flags below; diagnose before fixing all three separately.
Headless tests are structurally blind to this: the sim is stepped directly by the
harness, so the driver that feeds it in the real app is untested.
---
Resolution (owner fills): …

### [open] 2026-07-16 · raised-by: User (P2 human gate) · owner: Developer · re: sim state / geometry overlay
Problem: **when a character is hit, their collision and hurtbox disappear** and stay
gone until that character receives another input. Reported at the P2 human gate.
Two very different severities and the diagnosis decides which: if the boxes are
*absent from sim state*, this is a combat-resolution defect (a character with no
hurtbox during hitstun is unhittable — a correctness hole the golden net did not
catch); if the boxes are present in state but the **overlay stops drawing them**,
it's a render defect against the charter's centerpiece legibility surface. Either
way it fails `audit-criterion.md` half 1 (the player cannot find out what happened).
Possibly the same root cause as the input-lag flag above (a sim that only advances
on input would freeze geometry exactly like this) — diagnose the two together.
---
Resolution (owner fills): …

### [open] 2026-07-16 · raised-by: User (P2 human gate) · owner: Developer · re: `spec/character-b.md` (divekick) / input path
Problem: **the user could not perform a divekick at all** at the P2 gate. B's three
divekicks are the legibility-critical centerpiece of TKT-P2-06 and carry their own
gate item (B-3, the three must be visually distinguishable) — which cannot be judged
while the move cannot be executed. QA's headless pass proved the trajectory/timing
half, so the moves resolve correctly *in the sim*; the failure is in reaching them
from a human hand. Likely downstream of the input-lag flag (an air command has only
the jump's airborne window to land in, and a second of lag exceeds it) — **diagnose
after the lag is fixed and re-test before treating this as a separate defect.**
If it survives the lag fix and the cause is the spec's command/window definition
rather than the implementation, flag it up to the Architect — do not retune the
window on your own authority.
---
Resolution (owner fills): …

### [open] 2026-07-16 · raised-by: User (P2 human gate) · owner: Developer · re: `game/scenes/training_mode.tscn` (HUD layout)
Problem: **the on-screen text overlays overlap and are becoming hard to read.** The
match result (KO / TIMEOUT / DOUBLE_KO) is a P2 gate item that must be "legible on
its face"; timeout text does appear, but readability is degrading as readouts
accumulate (TKT-P2-08 added several). Opacity introduced by our own instrument is
tax, not polish deferred to P4 — the instrument is the surface we audit *through*.
Note for the owner: the user hand-edited `ControlsLegend`'s offsets at the gate to
read the screen (commit `7c88462`, "moving text overlays around so i can read them").
That edit is a **workaround, not intended layout** — treat it as evidence of the
defect and re-solve the layout properly; don't preserve it and don't silently revert
it without saying so.
---
Resolution (owner fills): …
