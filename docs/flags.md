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

### [open] 2026-07-08 · raised-by: Strategist (from user's P1.1 human-inspection gate) · owner: Strategist · re: character A crouching-normal attack heights — confirm design intent (NON-BLOCKING)
Problem: the first visual look at character A's boxes (via the now-working geometry overlay)
surfaced a content-design QUESTION, not a defect: 2L and 2M attack at HEAD-LEVEL while their
hurtbox shrinks (crouch), whereas 2H attacks near the bottom; 5L/5M/5H render lower on the
character (5H advances forward, correct). Crouching light/medium normals hitting at head height is
unusual for a grounded shoto and may or may not be intended authored move data. This is a
design-intent call (character A identity → brief → the user's design taste), **NOT a P1.1
operability item, and does NOT block the P1.1 gate.** Resolve WITH THE USER on return: confirm the
crouching-normal attack heights are intended, or route a content adjustment to the Architect (spec)
/ Developer (move data). Recorded now so the observation isn't lost while the gate closes.
NOTE (2026-07-09): the 2nd re-gate found the geometry overlay draws boxes **Y-inverted** — likely
the single root cause of this "crouching normals look head-high" observation. This question should
be re-evaluated AFTER the Y-inversion fix lands (see the character-A movement reconciliation
work-order below); the apparent head-high attack may simply be the inversion. Keep open until then.
---
Resolution (owner fills): …

### [open] 2026-07-08 · raised-by: Architect (P1.1 ratification pass) · owner: Strategist · re: frame-step auto-pause — feel/design call for the human re-gate (NON-BLOCKING)
Problem: ratifying JC-045, one control-surface sub-call is a UX/feel decision I judged not mine
to lock: the frame-step key (`tm_step`/N) is an **unconditional passthrough** — it calls
`step_once()` regardless of pause state and does **not** auto-pause first (mirrors the existing
`step_once()` method, which also does not check pause). Frame-step's *meaning* is "while paused"
(training-mode.md criterion 1); a human is expected to press pause (P) first, then step. The
alternative — have the step control also `set_paused(true)` as a convenience — is more forgiving
but is the binding *inventing* composite behavior beyond "call the corresponding control method."
This is operability *feel* the user may want to weigh when they operate the mode at the P1.1
re-gate, so I am routing it rather than ratifying it unilaterally (per your steer). The current
non-auto-pause binding stands provisionally and does not block the gate. If the user wants
auto-pause, it is a small follow-up ticket (a design call, then a one-line change), not a defect.
---
Resolution (owner fills): …

### [open] 2026-07-08 · raised-by: Architect (P1.1 ratification pass) · owner: Strategist · re: jump apex-hang feel — confirm at the human re-gate (NON-BLOCKING)
Problem: ratifying JC-047, I ratified the *correctness* invariant (an authored jump arc must net
to exactly zero vertical displacement so the character lands flush — folded into AD-036 /
move-format.md) but am routing the specific *feel* of the chosen fix to you. The fix spends the
odd frame of the 45-frame arc as a **one-frame, zero-velocity apex hang** (22 rise / 1 hang / 22
fall), preserving both tuned rise/fall speeds. This subtly changes the jump trajectory (a brief
flat moment at the peak; the back half shifts by up to 6 units vs. the pre-fix path). It is within
the already-ratified triangular-arc latitude (JC-A-01) and is the minimal fix that keeps both
tuned speeds, but jump *feel* is the user's — worth a look when they operate the mode at the P1.1
re-gate (does the apex hang read acceptably; is the triangular-with-hang arc the desired jump feel,
vs. a future parabolic re-bake). NON-BLOCKING: the arc is fixed and lands flush; P1.1 does not wait
on this. Any feel change later is a data-only re-author within the same mechanism, not a defect.
---
Resolution (owner fills): …

### [open] 2026-07-08 · raised-by: Strategist (from user's P1.1 human re-gate, 2nd run) · owner: Architect (entry point) · re: character A movement incomplete vs brief + geometry Y-inversion — full reconciliation, see work-order
Problem: the second P1.1 human re-gate (user, 2026-07-08) found character A materially
incomplete against its own brief AND the geometry overlay rendering boxes with an inverted
Y axis. Confirmed defects (all in-scope per `briefs/character-a.md`): walk enters but never
exits to idle on release (state stuck at 101/102); no crouch stance on held 2 (crouch
*attacks* work, crouch *stance/block* missing); no forward/back jump; no diagonal (7/9)
jumps; a jump vertical anomaly to diagnose against the render fix; and boxes drawn Y-inverted
(pushbox at top edge, hurtbox shrinks up) — likely the single root cause of the gate-1
"crouching normals look head-high" observation too. **Scope: full reconciliation** (user's
call) — audit ALL of A's specced movement, not just these symptoms. This is **P1.1-blocking**
(P1.1 is not done until the re-gate passes) but **deferred to a fresh session** by the user.
The complete, self-contained work-order — findings, scope, per-element checklist, routing
(Architect-first for the coordinate convention + state-machine model, then Developer, ratify,
QA, re-gate), and pickup instructions — is
`docs/briefs/character-a-movement-reconciliation.md`. Root-cause process analysis:
`docs/pipeline-analysis-completeness-gap.md`. Owner is the Architect as the entry point
(reconcile spec vs brief, rule the vertical coordinate convention and the movement
state-machine/release model, then ticket); fix-ownership fans out from there.
---
Resolution (owner fills): …
