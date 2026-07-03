# Audit — P0 Batch 2 (TKT-P0-08, 09) + P0 Milestone Drift Sweep

> QA audit report. Owner: QA. Routed findings live in `docs/flags.md`.
> Date: 2026-07-03. Auditor: QA (FoggyGlass).
>
> Two jobs, one session:
>   1. **Batch-2 per-feature audit** — TKT-P0-08 (input buffer + cancels),
>      TKT-P0-09 (throws + multi-hit/rehit), against their acceptance criteria,
>      the tenets, the audit criterion, and a JC-022..029 drift check.
>   2. **P0 milestone drift sweep** (TKT-P0-01..11) — the cumulative
>      behavior-vs-charter and spec-vs-implementation review per-feature audits
>      can't see, plus an elevated test-isolation / liveness spot-check.
>
> Audited against the *current, ratified* specs (AD-028/029 are new since batch 1):
> `simulation.md`, `move-format.md`, `combat-resolution.md`, `inspection-surface.md`,
> the named ADs, and the ratified/overturned JC-022..029.

---

## CRITICAL — execution state (read this before the verdicts)

The 12-file suite passed on Godot **before** the last migration. Since then two
changes landed that **have NOT been run on Godot**:

- **AD-029 migration** — dedicated `HitBox.tech_window`; `_resolve_throw` +
  `test_support.gd` migrated off `blockstun`.
- **F-009** — `MoveRegistry.install_generation()` token + a new crit-11 test in
  `test_sim_state.gd`.

QA cannot execute in-sandbox (Godot absent). So every verdict below is a
**static read-of-source** verdict, and I separate:

- **Settled statically** — criteria I can fully settle by static trace (schema
  shape, field presence, hash-walk coverage, migration correctness, code paths).
- **Execution-gated** — criteria whose *green* status depends on the pending
  Godot run of the post-migration code. I do **not** claim the post-migration code
  passes on Godot; I claim it is **statically correct** and name what the run must
  confirm.

There are now **13** test files (batch 1 had 9; `test_overlap_boundary.gd`
[F-008], `test_buffer_cancels.gd`, `test_throws_multihit.gd`, and the crit-11
addition landed since).

---

## Batch-2 per-ticket verdicts

| Ticket | Verdict |
|---|---|
| **TKT-P0-08** (input buffer + cancels) | **PASS (static)** — execution-gated for final green |
| **TKT-P0-09** (throws + multi-hit/rehit) | **PASS-WITH-FINDINGS** — one test-liveness gap (F-012); sim correct |

Neither finding is an objective sim failure. **P0 clears the milestone audit
subject to the final Godot run** (see bottom line).

---

## TKT-P0-08 — input buffer + cancels

**Serves:** combat-resolution.md crit 8 (cancel timing) + 11 (input buffer);
move-format.md crit 7 (typed CancelRule). AD-015/017/022.

- **crit 11 (input buffer) — PASS (static).** `InputBuffer` is all-static, a pure
  function of `(input_history, facing)` — no serialized recognizer state (AD-003).
  Motion recognition (`motion_recognized`) is the greedy oldest→newest cursor scan
  over `MOTION_WINDOW = 9` (JC-022), tokens facing-resolved via `socd_normalize`
  first. Command buffer (`button_buffered`) scans the last `COMMAND_BUFFER = 6`
  frames. Windows match AD-022 exactly. Determinism-across-sources is asserted via
  `_test_buffering_source_independent` (same stream → identical hash).
- **crit 8 (cancel timing) — PASS (static).** `CancelEval.find_cancel` gates on
  condition (`move_contact`), window, `requires_tag`, and buffered input, in
  authored order. The AD-017 T+1 grant→consume latency falls out of the phase
  order (phase 2 precedes phase 5; tags recorded on the attacker in phase 5 are
  first visible next tick). Hitstop freeze: `phase2_state_machine` returns early
  while `hitstop > 0`, so **no** cancel executes during freeze; the command
  buffers and fires on the first unfrozen tick. `_test_cancel_never_during_hitstop`
  asserts LIGHT stays committed for every frozen tick.
- **move-format crit 7 (typed cancels) — PASS (static).** `CancelRule` is a typed
  list (target / condition / window / input / requires_tag). Gatling (`on_contact`),
  special-cancel (`requires_tag` + `on_contact`), and whiff-cancel (`on_whiff`) are
  each authorable as data and resolved by the one evaluator. The test character's
  LIGHT→SPECIAL special-cancel exercises the tag-gated path.

**Execution-gated for 08:** all three criteria are statically correct but their
green status on the current tree depends on the pending Godot run (the file was
green pre-migration; the migration touched the throw path, not the buffer/cancel
path, so 08 is low-risk — but I do not claim green without the run).

---

## TKT-P0-09 — throws + multi-hit / rehit

**Serves:** combat-resolution.md crit 9 (multi-hit) + 10 (throws); move-format.md
crit 8 (multi-hit forms). AD-016, AD-026, AD-028, **AD-029**.

- **crit 10 (throws) — PASS (static) with a test-liveness gap (F-012).**
  - **Throwbox bypasses block — correct.** `phase5_hit_resolution` routes an
    `is_throw` contact to `_resolve_throw`, which ignores block state and forces
    the throw reaction. `_test_throw_bypasses_block` is non-vacuous (asserts a real
    connect: reaches `STATE_THROWN`, `stun_kind == HIT`, `health < 1000`).
  - **Tech to neutral — correct and non-vacuous.** `_try_throw_tech` (phase 2)
    undoes damage, clears stun, returns both to idle, closes the window. The test
    isolates the mechanism: `THROW_HITSTUN = 20` but the tech loop runs only
    `THROW_TECH_WINDOW + 2 = 10` iterations, so reaching IDLE within the loop
    **cannot** be the hitstun simply expiring — it must be a genuine tech. Good
    isolation.
  - **Clash-to-tech — sim correct; test is VACUOUS-CAPABLE (F-012).** I traced the
    geometry (P0 at x=0, throwbox world [20,60]; P1 hurtbox world [25,55] — they
    strictly overlap) and `_both_throwboxes_connect` → `_resolve_throw_clash`
    (push apart, no damage, no state change). The **sim behavior is correct.** But
    `_test_simultaneous_throw_clash` asserts only the *absence* of a thrown state
    and *absence* of damage — both of which are equally satisfied by a correct
    clash **and** by the throws never connecting at all (a broken button map,
    drifted throwbox geometry, or an accidental early return). There is **no
    positive liveness assertion** that the throwboxes reached their active window
    or that a clash was actually detected. This is the F-011 lineage (a green test
    that could pass vacuously by asserting the wrong / absent mechanism). Routed as
    **F-012 → Developer** (test-tooling, non-blocking). The clash arm of crit 10 is
    therefore **not yet locked by a self-verifying test**, though the code is
    correct by static trace.
- **crit 9 (multi-hit / rehit) — PASS (static).**
  - **Sequential multi-hit — non-vacuous.** `_test_sequential_multi_hit` asserts
    `max_combo == 2` (a specific positive count) — a broken multi-hit reads 0 and
    fails. Two distinct `id_group`s (10, 11) across keyframes each land once via
    `active_hit_ids`.
  - **Rehit cadence — non-vacuous and mechanism-checking.** `_test_rehit_cadence`
    asserts `hit_ticks.size() >= 2` **and** consecutive-hit spacing
    `>= REHIT_INTERVAL`. `_rehit_ready` measures cadence off `active_hit_frames`
    using the **produced tick** (`next.tick + 1`), the freeze-correct reading
    (JC-025). Spacing assertion validates "no hit between intervals." Good.
- **move-format crit 8 — PASS (static)** — same sequential + cadenced forms above.

**Execution-gated for 09:** the throw path is exactly what the AD-029 migration
touched, and it has **not** run on Godot since. Static trace confirms the
migration is correct (below), but crit 10's green status is the highest-value
item the pending run must confirm.

---

## Architect's routed QA focus (from the ratification pass) — results

1. **crit 11 install-generation token stable across a run (F-009) — SETTLED
   STATICALLY, PASS.** `test_sim_state.gd::_test_roster_install_generation_stable`
   captures the token at the first step, asserts it unchanged across 6 steps, and
   has an explicit **anti-vacuity guard** (asserts the run actually advanced). It
   further asserts a token bump does **not** change the state hash, and that
   **both** `install` and `clear` bump it. Confirmed the token is a static
   `MoveRegistry._install_generation` — **NOT** in `SimState`, **NOT** in `to_dict`,
   **NOT** in the `hash_state` walk. A bump cannot move the hash. Correct per
   AD-024 / simulation.md crit 11. *(Green status execution-gated — the crit-11
   test has not run on Godot.)*
2. **AD-028 three arrays hash count-first; two ints fixed order — SETTLED
   STATICALLY, PASS.** In `sim_state.gd::hash_state`, `active_hit_ids`,
   `active_hit_frames`, and `cancel_tags` each fold `.size()` before their elements
   (order-committing, AD-023). `move_contact`, `throw_tech_window`, `thrown_by` fold
   as plain ints in fixed order. Total coverage holds: the `hash_state` field set
   equals the `PlayerState.to_dict` key set (22 keys; I diffed them). *(Note: the
   Architect's phrasing "two ints" is three plain ints in the current shape —
   move_contact / throw_tech_window / thrown_by — all folded in fixed order; the
   count discrepancy is cosmetic, the hashing is correct.)*
3. **JC-024→AD-029 migration: NO throwbox authors a tech window via `blockstun`
   — SETTLED STATICALLY, PASS.** `hit_box.gd` has the dedicated `tech_window`
   field (line 59), distinct from `blockstun`. `_resolve_throw` reads
   `hb.tech_window` (step_phases.gd:690) into `def.throw_tech_window` — **no**
   `blockstun` read on the throw path. `test_support.gd::_build_throw` authors
   `tb.tech_window = THROW_TECH_WINDOW` and does **not** set `tb.blockstun`
   (line 322). Legit `blockstun` on strikes stays (LIGHT hitbox line 201,
   `_fwd_hitbox` line 255). The `.tres` done-bar artifact carries no throwbox.
   Migration is complete and correct.
4. **JC-022: golden the in-order-within-9f behavior, not the token list — NOTED.**
   No golden locks the concrete `236`/`623` token sequences as a contract;
   `_test_motion_window_recognition` / `_too_slow` assert the *behavior* (recognized
   within 9f in order; not recognized when spread beyond). Correct treatment.
5. **JC-027: 6-frame-command-buffer / recovery-boundary interaction is intended
   AD-022, not a leak — CONFIRMED, not flagged.** `test_buffer_cancels.gd`'s
   rewritten `_test_cancel_requires_tag` proves the tag gate by a whiff-vs-hit
   contrast asserted only at committed, non-actionable frames (never reaching the
   actionable frame where the buffered *neutral* press would fire), plus a positive
   control and a `whiff_seen` liveness check. The held-button-fires-frame-1 behavior
   is intended and correctly left unsuppressed. Not a defect.
6. **Placeholder tuning NOT goldened — CONFIRMED.** No golden locks the
   damage-scaling curve (JC-016), the 8f tech-window length or throw push constant
   (JC-024/029), or motion token lists. These stay Strategist-tunable.

---

## P0 milestone drift sweep

### A. Behavior-vs-charter across all of P0 (TKT-P0-01..11)

**The assembled backbone serves the tenets — verified:**
- **Deterministic sim (Tenet 1):** `step` is pure/non-mutating (distinct clone),
  RNG in-state, no `delta`/wall-clock/unseeded reads on the hot path, fixed-point
  integers only. The batch-2 additions are all serialized/cloned/hashed integers —
  determinism is preserved. `active_hit_frames` cadence uses absolute produced-tick
  (freeze-correct). No float reaches `step` (re-scanned `input_buffer.gd`,
  `cancel_eval.gd`, `step_phases.gd` throw/multihit paths — clean; the single
  "float" token in `input_buffer.gd` is a header comment).
- **Single input-source abstraction (Tenet 2):** buffering is a pure function of
  `input_history`, identical for every source; `_test_buffering_source_independent`
  asserts it. The install-generation token is wiring state, correctly *outside*
  `SimState` (Tenet 2 / AD-001).
- **Build-for-extension (Tenet 3):** dedicated `tech_window` (AD-029) is the
  extensible home for later throw variants; group-cancel targets and rehit fields
  are present-but-deferred, not built unused.

**One behavior-vs-charter DRIFT finding — the observable-in-principle-but-not-
surfaced gap (F-013).** Batch 2 added mutable, legibility-relevant serialized
state — `throw_tech_window`, `thrown_by`, `move_contact`, `cancel_tags` — but
**none of it is surfaced through the inspection seam** (`PlayerView`). The
charter's north star is "you can find out what happened and why, every time," and
the audit criterion's backstop is that the debug/training mode is where "what just
happened?" always has an answer. A defender who was thrown and had N frames to
tech, or a player whose cancel window just opened, currently has **no** read for
that state through `InspectionView`/`PlayerView`. This is exactly the drift the
sweep targets: it's in serialized state (observable in principle) but not exposed
through the seam (not actually observable). It is **not** an implementation bug —
`PlayerView` faithfully implements the *current* `inspection-surface.md` table,
which does not list these fields — so it routes to the **Architect** as a
spec-observability question (parallel to F-002): should the surface expose the
batch-2 tech-window/cancel state, and is that P0 or P1? **Does not block P0** —
the full inspection-surface implementation is explicitly TKT-P1-01, and no P0
acceptance criterion requires these reads. Routed as **F-013 → Architect**
(non-blocking). This is subjective/legibility-adjacent, so I surface and route; I
do not adjudicate whether the training mode *needs* it now.

### B. Spec-vs-implementation divergence across all P0

Walked the named ADs against the code — **no divergence found:**
- **AD-023 hash total coverage** — `hash_state` covers every `to_dict` key
  (SimState root + all 22 PlayerState fields + projectiles + last_hit presence-flag
  + neutral flag); count-first before every variable-length run. Confirmed.
- **AD-024 / AD-028 SimState shape** — every AD-028 field is present in
  `player_state.gd` with the ratified type, serialized, cloned, and hashed exactly
  as the AD specifies. `character_id` is the resolution key; the roster is resolved
  via `MoveRegistry`, `step` signature stays `(state, in1, in2)`. Confirmed.
- **AD-026 single-hit** — `active_hit_ids` per-attacker, cleared on every state
  entry (`_enter_state`); a present `id_group` does not re-hit. Confirmed.
- **AD-027 overlap strict** — `ResolvedBox.overlaps` uses strict `<`/`>` on all
  four edges; `test_overlap_boundary.gd` now pins the boundary (F-008 addressed).
  Confirmed.
- **AD-029 tech_window** — dedicated field, read on the throw path, no `blockstun`
  reuse (see routed-focus item 3). Confirmed.

### C. Test-isolation / liveness spot-check (elevated priority)

Read every batch-2 test scenario for vacuous-pass, mis-isolation, and missing
liveness. **One weak test found:**

- **WEAK — `test_throws_multihit.gd::_test_simultaneous_throw_clash`** — asserts
  only the *absence* of a thrown state and *absence* of damage. A correct clash and
  a never-connected pair of throws satisfy the assertion identically; there is no
  positive check that both players reached `STATE_THROW`, that the throwboxes hit
  their active window, or that a clash was detected. **Vacuous-capable.** →
  **F-012 → Developer.** (F-011 lineage.)

**Checked and found SOUND (self-verifying):**
- `_test_throw_bypasses_block` — asserts a real connect (STATE_THROWN, damage).
- `_test_throw_tech_to_neutral` — loop bound (10) < throw hitstun (20), so reaching
  IDLE is provably a tech, not stun expiry. Well isolated.
- `_test_sequential_multi_hit` — asserts `max_combo == 2` (positive count).
- `_test_rehit_cadence` — asserts count `>= 2` **and** spacing `>= interval`.
- `_test_cancel_requires_tag` (JC-027 rewrite) — whiff-vs-hit contrast at
  non-actionable frames + `whiff_seen` liveness + positive control. Exemplary
  isolation; directly closes the F-011 recurrence.
- `_test_cancel_never_during_hitstop` — asserts committed for *every* frozen tick.
- `_test_roster_install_generation_stable` — explicit anti-vacuity guard.
- `_test_buffering_source_independent` — real hash equality over a motion+button
  stream.

---

## Judgment-log drift check (JC-022..029)

Each entry re-checked against the current code and the ratified/overturned
disposition. **All match; no drift.**

- **JC-022** (greedy 9f token scan; motion table) — matches `InputBuffer.
  motion_recognized` / `_motion_tokens`; behavior goldened, not the token list. No drift.
- **JC-023** (CancelRule.input via button_map entry, raw-button fallback, groups
  deferred) — matches `CancelEval._input_buffered`; `target_is_group` skipped. No drift.
- **JC-024** (blockstun reuse) — **OVERTURNED** into AD-029; the code migrated off
  `blockstun` to the dedicated `tech_window`. Migration complete and correct. No drift.
- **JC-025** (rehit cadence via `active_hit_frames` + produced-tick; clash on both-
  throwboxes-connect) — matches `_rehit_ready` (produced-tick `next.tick+1`) and
  `_both_throwboxes_connect`. No drift.
- **JC-026** (cancel-gate test fix) — **SUPERSEDED** by JC-027; the current
  `_test_cancel_requires_tag` is the JC-027 shape (contrast + non-actionable frames
  + positive control). Correctly superseded, not present in its old form. No drift.
- **JC-027** (cancel-gate contrast rewrite) — matches the current test. No drift.
- **JC-028** (install-generation as static int + accessor) — matches
  `MoveRegistry` (static counter, `install_generation()`, not serialized/hashed).
  No drift.
- **JC-029** (crit-11 assertion in `test_sim_state.gd`) — matches
  `_test_roster_install_generation_stable`, with `clear()` teardown for isolation.
  No drift.

Note: JC-026/027 are Developer-owned test *fixes* (F-011 recurrence); the
ratifications covered only the JC latitude, not the flag's own resolution
(Developer's, already archived).

---

## Settled statically vs execution-gated (summary)

**Settled statically (QA-owned pass/fail, no run needed):**
- AD-029 migration correctness (no throwbox uses `blockstun`; read is `tech_window`).
- crit-11 token: NOT in SimState / not hashed; bump can't move the hash; install &
  clear both bump; anti-vacuity guard present.
- AD-028 hash: three arrays count-first, plain ints fixed order, total coverage.
- Spec-vs-impl (AD-023/024/026/027/028/029): no divergence.
- Sim clash / tech / rehit / cancel-gate *code paths*: correct by trace.
- Float-free batch-2 code paths.
- Test-isolation spot-check (F-012 the only weak test).

**Execution-gated on the pending Godot run (green status not claimable by QA):**
- Whole 13-file suite green on the post-migration tree — **especially**:
  - the **throw path** (AD-029 migration has not run on Godot),
  - the **crit-11 test** (`test_sim_state.gd`, F-009 addition has not run),
  - `test_buffer_cancels.gd` / `test_throws_multihit.gd` end-to-end.
- I do **not** assert the post-migration code passes on Godot; I assert it is
  statically correct and that the run is the remaining gate.

---

## Findings (routed to `docs/flags.md`)

- **F-012 → Developer (test-tooling, non-blocking).**
  `test_throws_multihit.gd::_test_simultaneous_throw_clash` can pass vacuously: it
  asserts only that neither player is thrown and neither took damage — true both
  for a correct clash and for throws that never connect. Add a positive liveness
  check that both players actually reached `STATE_THROW` and that the clash path
  ran (e.g. assert both throwboxes reached their active window / a detectable clash
  signal), so the clash arm of crit 10 is locked by a self-verifying test. (F-011
  lineage.) The sim clash behavior is correct; only the test is weak.
- **F-013 → Architect (spec-observability, non-blocking).** Batch-2 added mutable,
  legibility-relevant serialized state (`throw_tech_window`, `thrown_by`,
  `move_contact`, `cancel_tags`) that is not surfaced through the inspection seam
  (`PlayerView` / `inspection-surface.md`). Should the surface expose the throw
  tech-window / cancel-window state so the debug training mode makes throws and
  cancels *discoverable* (charter legibility; the "what just happened?" backstop),
  and is that P0 or P1 (TKT-P1-01) scope? Raised as a spec question (the code is
  faithful to the current spec table), parallel to F-002. Does not gate P0.

No objective sim failure was found in either batch-2 ticket.

---

## Bottom line

**P0 clears the milestone audit — subject to the final Godot run.** Every P0
acceptance criterion I can settle statically holds; spec-vs-impl shows no
divergence across AD-023/024/026/027/028/029; the JC-022..029 drift check is
clean; the AD-029 migration and the F-009 crit-11 addition are statically correct.

**What blocks a fully-closed "done":**
1. **The pending Godot run** of the post-migration tree (execution-gated criteria
   above) — the one hard gate QA cannot clear from the sandbox. The throw path and
   the crit-11 test are the highest-value items to watch, since they are exactly
   what changed since the last green run.
2. **F-012** and **F-013** are **non-blocking** hardening findings (a weak clash
   test; a legibility-surface spec gap) — they do not gate the milestone but should
   be resolved before the clash arm of crit 10 is considered self-verifying and
   before the batch-2 legibility surface is considered complete.
