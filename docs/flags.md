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
Resolution (Architect step, 2026-07-09 — stays [open]; the reconciliation closes only at the
human re-gate, not on this step): the **Architect entry-point work is done** and fix-ownership now
fans out to the Developer. Ruled:
- **Vertical convention — AD-037.** Up is −Y **everywhere** (world + character-local, one shared
  axis); feet-origin at `pos_y = ground_y`. The Y-inversion is a **DATA bug, not a render bug**:
  every authored box has positive downward local y (body below the feet), inverted vs `ground_y` and
  the settled `pos_y`/AD-033 convention. Fix = reflect each box across the feet line
  (`new_y = −(y+h)`); the render is correct as-is; **flipping the render sign is wrong** (it
  double-inverts the jump). This is the single root cause of the whole box-appearance cluster; the
  crouching-normal-height flag likely closes once it lands.
- **Held-input looping-state exit — AD-038.** An actionable character in a looping state (idle/walk/
  crouch) re-derives its state from input each tick, falling back to idle when nothing matches — the
  **exit** half of AD-032. Fixes walk-never-stops; gives crouch its release-to-stand.
- **Airborne-action model — AD-039.** Directional/diagonal jumps via **per-direction prejump lead-ins**
  (`9`/`7` = the "forward/back" jumps — same motion); air normals via **jump-state cancels** (raw-button
  fallback). Data-only, no engine change. `JUMP_F/JUMP_B` + `j.*` states already exist; only the wiring
  was missing.
- **Crouch stance/block:** unwired content (add a bare-`DOWN` pure-direction `button_map` entry);
  crouch block falls out of the existing hold-back block once the stance is reachable. Blocking is
  stance-agnostic hold-back in the slice (no high/low) — noted, not changed.
- **Trace-harness format** specced (`spec/trace-harness.md`): numpad+`L/M/H` input string → `InputFrame`
  buffer, replayed through the existing `RecordPlaybackSource` (Tenet 2 — **no strain**, a scripted
  source is a first-class producer), a float-free `InspectionView` trace dump + inline brief-derived
  assertions. Designed shareable/extensible (the future "paste a setup" / P3 tutorial), minimal build now.
- **Dash:** raised as a **separate scope flag to you** (above) — states exist, input unreachable, needs a
  new double-tap recognizer; your call, not defaulted.
Tickets: `docs/tickets/p1.1-reconciliation.md` (01 trace-harness → 02 geometry-Y-fix → 03 held-input-
stances → 04 airborne-actions; per-ticket dispatch). Next: Developer executes; Architect ratifies the
new JCs; QA audits (goldens move deliberately, JC-017 style); then the user re-gate drives the checklist.

UPDATE (Strategist, 2026-07-11 — 3rd human re-gate): **PARTIAL PASS, stays [open].** Batch 1
(TKT-P1.1R-01..05) delivered, QA-passed (`audits/audit-p1.1-reconciliation.md`), pushed to origin.
Re-gate verified: walk snappy-to-frame, crouch stance, boxes right-side-up (crouching-normal-height
flag now closed), capture/reset, fireball/DP function. **A second reconciliation batch remains** —
full findings in the work-order's "Re-gate 3 findings" section: D1 dummy-uncontrollable /
crouch-block unverifiable (operability, P1.1); D2 jumps sometimes land off-floor (suspect F/B arc
net-zero, P1.1 arc-fix); D3 aerials float (AD-036 gap — deferred to P2 per roadmap, stated); Q1 DP
doesn't rise + Q2 H-DP two hitboxes (spec-intent checks). Dispatched to the Architect for diagnosis
+ a **coherent batched** ticket set (user's explicit steer: batch this iteration to measure vs.
per-ticket). Fix-ownership fans out from there; a 4th re-gate closes P1.1.

UPDATE (Architect diagnosis, 2026-07-11 — stays [open]): re-gate-3 findings diagnosed against spec +
code; batched ticket set produced (`tickets/p1.1-reconciliation.md` → "Re-gate 3 batch"). Outcomes:
- **D1** = P1.1-scope **spec gap** (not a binding bug): the dummy source was built with **no live
  sampler**, so `M` cycles the mode but the dummy emits neutral in every mode — no human-input path
  to the dummy. Ruled **AD-040** (record→playback puppeting via an injected dummy sampler);
  **TKT-P1.1R2-01** wires it. Reflected in `training-mode.md`.
- **D2 REFUTED** (empirical, headless): all three jump arcs share **one identical net-zero `vel_y`
  profile** and clean jumps land flush (`py=0`) in every direction. No arc-data bug. The "sometimes
  off floor" is the **AD-036 aerial-interruption float (= D3)**. Optional hardening guard
  **TKT-P1.1R2-02** (assert flush landing per direction); drop it if the budget cut wants minimal.
- **D3** = confirmed **AD-036 gap**; I **concur** it holds to **P2** (not ticketed). Does not block
  P1.1 operability — a stated, roadmapped limitation.
- **Q1** = **RAISED as its own flag below** (DP-rise: character identity + roadmap).
- **Q2** = **intended, no action** (`623H` authored 2-hit; build matches).
This batch is dispatched **whole** (one session, one checkpoint) per the user's batched-dispatch
steer. The reconciliation flag stays [open] until the 4th human re-gate.

UPDATE (Strategist, 2026-07-11 — R2 batch complete, QA-passed): TKT-P1.1R2-01 (dummy control, AD-040)
+ TKT-P1.1R2-02 (jump flush guard) built and green (`f50944e`, `7389ff2`); Architect ratified JC-064
+ reconciled the grounded-DP prose (`47832a6`); QA objective audit **PASS** (`audits/audit-p1.1-r2-delta.md`,
31/31 independently verified, Tenet-2 intact, no flags). **Only the 4th human re-gate remains** — the
dummy is now human-drivable (record→playback, dedicated keys), so crouch-block is finally checkable;
plus confirm clean jumps land flush (aerial float = agreed AD-036/P2 deferral, not a failure), rule the
two parked feel flags, and eyeball the controls-legend legibility. Flag closes when the user closes P1.1.

UPDATE (Strategist, 2026-07-11 — 4th human re-gate): still [open], a **3rd fix batch (R3)** needed.
Passed: frame-step auto-pause decided (user wants it), apex-hang accepted (both feel flags now resolved
+ archived), legend legible. **Still failing LIVE (green headless, broken in hand):** E1 dummy still
uncontrollable — recording won't work live / cycling to PLAYBACK still only drives P1 (suspect a
live-frame record-wiring gap the shell test missed AND/OR no on-screen dummy-mode indicator — clarity
standard); E2 jumps still wedge off-floor on landing (recurs vs the headless net-zero conclusion —
diagnose clean-jump-bug vs the aerial/AD-036 deferral precisely, do NOT re-close as "the aerial case").
Plus the frame-step auto-pause change to implement. Full detail in the work-order's "Re-gate 4 findings".
Routed to the Architect for diagnosis + a coherent batched ticket set. Dummy-control has now failed the
human gate twice while passing headless once — the fix must add in-app observability, not just re-wire blind.

UPDATE (Strategist, 2026-07-11 — R3 batch complete, QA-passed): diagnosis found E1's live wiring was
correct — root causes were **no on-screen mode indicator** (AD-041) + a **fresh-record buffer-clear** bug;
E2 was a **genuine held-jump bug** (drops the arc's last fall frame), fixed by the user-approved **AD-042
landing snap** (also resolves the aerial float / old D3). Built as one batch: TKT-P1.1R3-01 (mode indicator
+ fresh-record), -02 (landing snap), -03 (frame-step auto-pause) — `b0f1241`/`c42d184`/`278d958`; JC-065/066/067
ratified + folded (`535557b`); QA objective audit **PASS** (`audits/audit-p1.1-r3-delta.md`, landing-snap
determinism verified, held-jump no-drift confirmed, 32/32 independently green, no flags). **Only the 5th human
re-gate remains** — and it is load-bearing: the mode indicator, the live record→playback round-trip, and
pixel-flush landing are inherently live-only (why E1 slipped twice). Flag closes when the user closes P1.1.
