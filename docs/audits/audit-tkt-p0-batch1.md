# Audit — P0 Batch 1 (TKT-P0-04, 05, 06, 07, 10, 11)

> QA audit report. Owner: QA. Routed findings live in `docs/flags.md`.
> Date: 2026-07-03. Auditor: QA (FoggyGlass).
>
> Scope (this round): the six batch-1 tickets — TKT-P0-04 (inspection surface),
> 05 (move format / state machine), 06 (phase pipeline 1–4), 07 (hit/stun/
> advantage 5–7), 10 (test character + done-bar), 11 (determinism/serialization
> harness hooks). **NOT audited: TKT-P0-08 (buffer/cancels) and 09 (throws/
> multi-hit)** — batch 2, not built; the done-bar needs neither.
>
> Audited against the *current, ratified* specs (AD-024/025/026/027 are new this
> pass): `simulation.md`, `inspection-surface.md`, `move-format.md`,
> `combat-resolution.md`, the named ADs, and JC-013..021 (all ratified).
>
> **Execution evidence.** Unlike audits 01 and 02/03 (which were static-only
> because Godot was unavailable), this batch has been **run green on the user's
> Godot: all 9 test files pass**, including `test_harness.gd` (TKT-P0-11 hooks)
> and `test_done_bar.gd` (the tenet proof). QA still cannot execute in-sandbox, so
> every verdict is a static read-of-source verdict — but the green run on real
> Godot **closes the criteria that were previously "gated on engine"** (called out
> explicitly below).

---

## Verdicts

| Ticket | Verdict |
|---|---|
| **TKT-P0-04** (inspection surface) | **PASS** |
| **TKT-P0-05** (move format / state machine) | **PASS** |
| **TKT-P0-06** (phase pipeline 1–4) | **PASS** |
| **TKT-P0-07** (hit/stun/advantage 5–7) | **PASS** |
| **TKT-P0-10** (test character + done-bar) | **PASS** |
| **TKT-P0-11** (determinism/serialization hooks) | **PASS** |

**Batch 1 clears audit — DONE.** The roadmap P0 done-bar (10 green + 11's hooks
green under the harness) is satisfied and verified through the inspection seam.
Two non-blocking findings are routed (F-008 to Developer, F-009 to Architect);
neither gates "done" — both are hardening of things that are *correct in code
today* but under-pinned against future drift. One standing watch item is recorded
for QA's own harness (MoveRegistry immutability), not a finding.

No objective failure was found in any batch-1 ticket.

---

## Previously engine-gated criteria the Godot run now CLOSES

The 02/03 audit marked several criteria "gated on engine / TKT-P0-11" because no
sim could be executed. With the harness landed and the suite green on real Godot,
these are now **verified end-to-end**, not merely by construction:

- **simulation.md crit 2 (end-to-end replay determinism) — NOW CLOSED.** This was
  the explicit open item from 02/03. `test_harness.gd::_test_replay_determinism`
  runs `SimHarness.replay_final_hash` **twice** from a fresh `new_initial(4242)`
  with identical input streams and asserts `h1 == h2` — that *is* the
  replay-one-stream-twice → identical-final-hash proof, end-to-end, not just the
  building blocks. It additionally asserts the harness replay equals an inline
  `step` loop (no harness-introduced divergence). And `test_done_bar.gd::
  _test_replay_determinism` proves the *same* property on the **full authored-
  character** path (roster installed, real hits resolving), so crit 2 holds for
  both the empty-roster backbone case and the real-character case. **Closed.**
- **simulation.md crit 1 (purity) — end-to-end confirmed.** `test_sim_state.gd`
  (02/03) plus the harness inline-loop equality run green.
- **simulation.md crit 3 (round-trip) — NOW CLOSED end-to-end.** `test_harness.gd
  ::_test_snapshot_resume_matches` snapshots mid-replay (tick j=12), loads, resumes
  to the end, and asserts the final hash equals the uninterrupted replay's — the
  *real* crit-3 proof, plus a per-tick hash trace with verified length/endpoints.
  `test_done_bar.gd` repeats it mid-scenario with an authored character. **Closed.**
- **simulation.md crit 5 (tick authority), "render-rate doesn't change outcomes"
  half — closed for the sim path.** The replay runner advances purely on the
  recorded stream with no `delta`/frame-count input; determinism across two runs
  confirms outcomes don't depend on render timing.
- **simulation.md crit 6 (read-only seam) & crit 4/6 of inspection-surface.md —
  NOW CLOSED.** TKT-P0-04's surface now exists and `test_inspection_view.gd`
  proves read-only (hash unchanged after a full sequence of reads; no mutator
  exposed) and float-free truth views; `test_harness.gd::_test_truth_dump_float_
  free` proves the golden truth dump is float-free and px-free (px excluded).
- **move-format.md crit 9 ("no float reaches step") — NOW CLOSED at runtime.**
  `step` and the whole pipeline now exist and run; the float scan below plus the
  green run confirm no float on the hot path.

Still correctly **deferred** (not this batch): simulation.md crit 7 has no engine-
physics body to violate it (our own AABB — verified); inspection-surface.md
criteria 1/3/5 complete at TKT-P1-01 (resolved `BoxView`s / `projectiles()`);
move-format.md criteria 5/7/8 partially — 5 (single-hit) is proven now, 7/8
(cancels, multi-hit/rehit) land with 08/09.

---

## Focus-area findings (the ratification-pass items, highest drift-cost)

### MoveRegistry (AD-024) — immutable roster, installed-once, unchanged across a run
**PASS, with a standing watch item (not a finding).**
- The sim resolves every player's `Character` through `MoveRegistry` (a process-
  wide static roster), never through `step`'s signature, which stays exactly
  `(state, in_p1, in_p2)` — verified in `sim_state.gd::step` and every `StepPhases`
  resolution site (`MoveRegistry.character(p.character_id)`).
- **Install-before-first-step is obeyed in every runnable path.** `test_combat`,
  `test_done_bar`, and `test_harness` each `install()` the roster *before* the
  first `step` and `clear()` after; no code path mutates `_roster` mid-run. The
  done-bar's replay-twice runs both replays against the same installed roster, so
  determinism holds *given the discipline* — and it is held.
- **The hazard the type system doesn't prevent is real but already contract-
  owned.** `install()`/`clear()` are public static mutators on a process-wide
  static; nothing structurally forbids a mid-run mutation. This is exactly what
  AD-024 / F-004 ratified: installed once at wiring, immutable during a run, a
  determinism precondition the wiring layer must not violate. The code obeys it;
  no sim path breaks it. **Recorded as a QA harness watch item** (below), not a
  finding — the contract owns the residual and the code is compliant.

### Canonical-hash coverage (AD-023/026) — variable-length / optional folding
**PASS — total coverage verified by key-set diff.**
- I diffed every `to_dict` key set against what `hash_state` folds:
  - **SimState:** tick, rng(seed/state), stage(wall_left/right/ground_y), players,
    projectiles (count + `Projectile.HASH_FIELDS`), last_hit, neutral flag — all
    folded.
  - **PlayerState (17 fields):** all 17 folded, including the two variable-length
    runs.
- **`last_hit` presence-flag folding (focus item) — CONFIRMED.** `hash_state`
  folds `0` when `last_hit == null`, else folds `1` then `HitRecord.HASH_FIELDS`
  (7 integer fields, `was_block` stored as `was_block_int` so the stream is pure-
  integer). A no-hit state and a hit state can never collide. Correct per AD-023
  total coverage + AD-024.
- **`active_hit_ids` count-then-ids run (focus item) — CONFIRMED.** Folds
  `ah.size()` before each id (order-committing, AD-023/026), so a regrouped id run
  cannot collide. `input_history` frames are folded the same count-then-elements
  way. Correct.
- Hash is FNV-1a over an ordered pure-integer stream, low byte first, no Godot
  `hash()`/`var_to_bytes`, no Dictionary iteration order (JC-007 → AD-023,
  re-verified against current code). Crit 10 holds.

### JC-017 pushout half-split — feeds `position`, locked by determinism goldens
**PASS — deterministic, cannot drift silently.**
- `_resolve_stage_and_pushboxes`: `half = overlap / 2` (integer, toward zero for
  positive overlap), `rem = overlap - half` given to player index 1 (the "second
  push"). Matches JC-017's ratified odd-remainder-to-P1 rule exactly. It is an
  exact-integer, symmetric split that feeds `pos_x` and therefore the hash, so the
  determinism goldens lock it — any later different split is a golden change, not a
  quiet edit, per the JC-017 caveat. Confirmed the mechanism is single-sourced in
  one function.

### JC-016 damage scaling — golden the MECHANISM, not the placeholder curve
**PASS — mechanism single-sourced; done-bar insensitive to the numbers.**
- `DamageScaling.scaling_for_hit_count` is the ONE scaling definition; phase 5
  applies it **before** subtracting damage (`FP.mul(...)` then subtract) and
  surfaces the applied percent (`HitRecord.scaling_applied_pct`, `PlayerView.combo
  .scaling_pct`). Mechanism matches combat-resolution.md.
- Per the JC-016 ruling I treat the 10%-step / 10%-floor NUMBERS as placeholder,
  **not** a golden to lock. The done-bar's single hit is hit-count 1 → `FP.ONE` →
  100% → damage == base 40, hand-checkable and independent of the curve (verified
  in `test_done_bar` and `test_combat`). Golden target = single source + pre-
  subtract + surfaced; the curve is Strategist-tunable in that one place.

### AD-027 strict overlap — touching edges decide hit/no-hit at exact adjacency
**PASS in code; test-coverage gap routed as F-008.**
- `ResolvedBox.overlaps` uses strict `<` / `>` on all four edges, so boxes that
  share an edge (`a.x + a.w == b.x`) do **not** overlap — exactly AD-027's strict
  convention. Phase 4 and the inspection overlay share this one test (single
  source), so the debug overlay shows what the sim tested.
- **Gap:** no test pins the *boundary* — no golden/assertion at exact adjacency
  (touching → no hit) or at 1-subunit penetration (→ hit). The convention is now
  the load-bearing hit/no-hit decision at adjacency; nothing currently locks it
  against an accidental future flip to `<=`. Routed to Developer as **F-008**
  (test tooling), non-blocking.

---

## Per-ticket static verification

### TKT-P0-04 — inspection surface (inspection-surface.md crit 2, 4)
- **Read-only by construction (crit 2):** no mutator, no `step`; every read returns
  a plain-data `*View` (copy-out), so no path aliases live `SimState`. Test asserts
  the state hash is unchanged after exercising every read. **PASS.**
- **Single source (crit 3, spot-verified now though it completes at P1):**
  `advantage()` → `Advantage.live`, `frame_data()` → `MoveData.frame_data`,
  `last_hit()` → `_state.last_hit` projected to `HitEvent`. No re-implementation.
- **Snapshot-stable, fixed-point only (crit 4):** truth views are int/bool only;
  recursive float scan of `PlayerView`/`HitEvent` is clean; px is a static render-
  only helper, never a truth-view field (crit 6 spot-check). **PASS.**

### TKT-P0-05 — move format / state machine (move-format.md crit 1, 2, 3, 6, 9)
- **1 data-only authoring / 2 derivation / 3 golden-able / 6 one pattern / 9 fixed-
  point:** all covered by `test_move_format` and the `.tres` done-bar artifact.
  Frame-data derivation (startup 3 / active 3 / recovery 6 / total 12) matches
  hand values via the ONE `MoveData.frame_data`; box resolution is deterministic
  (JC-011/14/19 1-indexed model consistent); every state declares a valid engine-
  level category; resolved geometry is pure int. **PASS.** (crit 5 proven at 07;
  4 fully checkable at character A; 7/8 at 08/09.)

### TKT-P0-06 — phase pipeline 1–4 (combat-resolution.md crit 2; input.md crit 5)
- **Phase order load-bearing (crit 2):** `step` runs the seven named `StepPhases`
  functions in the fixed AD-009 order; the order is the literal call sequence
  (JC-013), and `test_combat` asserts each phase is a named callable (JC-021
  idiom). **PASS.**
- **SOCD determinism (input.md crit 5):** one sim-side `socd_normalize` (LR→neutral,
  UD→Up priority), raw stays raw in history, only derived intent cleaned (JC-015 →
  input.md). Deterministic, source-agnostic. **PASS.**

### TKT-P0-07 — hit/stun/advantage 5–7 (combat-resolution.md crit 3, 4, 5, 6;
move-format.md crit 5)
- **3 advantage = one formula, both values:** static (`Advantage.fill_static`,
  pinned first-active/uncancelled) and live (`Advantage.live`, cancel-aware) both
  computed in the ONE advantage file; done-bar reads +8 on hit / +2 on block for
  both static and live at contact (hitstop cancels). **PASS.**
- **4 hitstop semantics:** `was_frozen` capture in `step` ensures a hitstop set
  *this* tick is not decremented this tick, so a freeze of N lasts exactly N ticks;
  frozen frame_in_state/stun hold while the loop ticks. `test_combat` walks the
  full freeze. **PASS.**
- **5 neutral flag (AD-025 rising edge):** `neutral_restored_this_tick = both_now
  AND NOT prev_both_actionable`, `prev` captured from `step`'s input state (= last
  tick). Fires on exactly one tick; false at match start. **PASS.**
- **6 / move-format 5 single-hit:** `id_group` collapse within a tick (`seen`) and
  across active frames (`active_hit_ids`, cleared on state entry). Two overlapping
  same-group hitboxes over a 3-frame window → one hit, one increment, one damage.
  **PASS.**

### TKT-P0-10 — test character + done-bar (combat-resolution.md crit 1)
- Trivial character authored **purely as `.tres`** (`data/test_character.tres`),
  loaded, two instances, inputs recorded then replayed through the deterministic
  `step`, one hit resolves, and startup/active/recovery + static + live advantage
  read back **through `InspectionView`** matching hand-computed values (+8 / +2,
  40 damage unscaled). The `.tres` is asserted byte-equal in derived values to the
  programmatic twin, so an authoring slip can't silently diverge. **PASS — the P0
  done-bar / tenet proof is met.**

### TKT-P0-11 — determinism/serialization hooks (simulation.md crit 1–3;
inspection-surface.md crit 4, 6)
- `SimHarness` provides the hooks (snapshot dump/load, headless replay runner →
  final hash + per-tick trace, float-free/px-free truth dump) and does **not** re-
  implement the canonical hash (uses `SimState.hash_state`). `test_harness.gd`
  drives them green: crit 1/2/3 runnable end-to-end, crit 4/6 (float-free, px-free,
  stable). **PASS.** QA owns the harness verdicts; the hooks behave as specified.

---

## Independent float / forbidden-read scan (crit 4, 8)

I re-ran my own scan across `game/sim/`. The only `float`-typed tokens on any
runtime path are: (a) `fp.gd` authoring bakes `from_float`/`from_units`/`to_float`
(documented off-hot-path per AD-014, never called from `step`); (b)
`inspection_view.gd::px`/`px_rect` (static render-only, never in a truth view or
snapshot, AD-019); (c) `tick_host._physics_process(_delta: float)` — the engine
signature, `_delta` unused. No transcendentals (trig/sqrt/pow) anywhere. No
`Time.`/`OS.`/`Engine`-frame-count/unseeded-RNG read reachable from `step`. **No
float in `SimState`; crit 8 and the crit-4 forbidden-read half hold**, now backed
by the green run.

---

## Judgment-log drift check (JC-013..021, all ratified)

Each ratified call was re-checked against the current code AND the ratified spec.
**All nine match; no drift.**

- **JC-013** (StepPhases named-function-per-phase module): matches `step_phases.gd`;
  the AD-009 order is the literal call sequence in `step`. No drift.
- **JC-014** (`_enter_state` puts a fresh entry on frame 1; phase 2 skips the same-
  tick advance via `entered_this_tick`): matches. Consistent 1-indexed model with
  JC-011/19. No drift.
- **JC-015** (one `resolve_intent` = SOCD + facing; raw stays raw): matches
  `phase1`/`resolve_intent`/`socd_normalize`; folded into input.md. No drift.
- **JC-016** (single `DamageScaling`; done-bar unscaled 100%): matches; mechanism
  single-sourced, numbers placeholder (goldened as mechanism, not curve — see
  above). No drift.
- **JC-017** (pushout half-split, odd remainder to P1): matches
  `_resolve_stage_and_pushboxes` exactly; deterministic, hash-feeding, golden-
  locked. No drift.
- **JC-018** (neutral = rising edge, no extra serialized field → AD-025): matches
  `phase6` + the `prev_both_actionable` capture in `step`. No drift.
- **JC-019** (loop wraps `frame_in_state` mod duration; stun clamps at duration):
  matches the phase-2 advance for both the loop and the stun-sibling clamp.
  1-indexed consistent. No drift.
- **JC-020** (test-only: `hitstop_remaining` reads sim's own post-step value,
  pinned 3→2): matches `test_inspection_view` (asserts both `== s.players[0].hitstop`
  and literal `2`). Test-only; sim was already correct. No drift.
- **JC-021** (test-only: `Callable(StepPhases, name).is_valid()` for static
  presence): matches `test_combat::_test_phase_order_is_load_bearing`. No drift.

Note: JC-020/021 are Developer-owned test *fixes* (F-006/F-007); the ratifications
covered only the JC latitude. Those flags' own resolution is Developer's, not
touched here.

---

## Standing watch item (QA's own harness — not a flag)

- **MoveRegistry immutability assertion.** AD-024 makes install-once/immutable-
  across-a-run a *determinism precondition* the type system can't enforce. The code
  obeys it and every runnable path installs before the first `step`. For QA's own
  harness: add a check that the roster identity/contents are unchanged between the
  first and last `step` of a replay (e.g. snapshot `MoveRegistry.roster()` hash at
  run start and assert it at run end), so an accidental mid-run `install()`/`clear()`
  surfaces as a *test failure* rather than a silent determinism break. Not
  actionable as a spec/code change (the contract already owns it); recorded so QA's
  future harness work picks it up. (Sibling to the AD-014 mul-budget watch item from
  audit 01.)

---

## Findings (routed to `docs/flags.md`)

- **F-008 → Developer (test-tooling, non-blocking).** No test pins the AD-027
  strict-overlap boundary at exact adjacency. `ResolvedBox.overlaps` is correct
  (strict `<`/`>`), but nothing locks the touching-edge = no-hit convention against
  a future accidental flip to `<=`. Add a boundary golden/assertion: two boxes at
  `a.x + a.w == b.x` do not overlap; a 1-subunit penetration does. This is now the
  load-bearing hit/no-hit decision at adjacency (AD-027).
- **F-009 → Architect (spec-observability nit, non-blocking).** AD-024 states the
  immutable-roster/install-once determinism precondition, but no acceptance
  criterion gives QA something to *assert* it against — it rests on wiring
  discipline plus the watch item above. Ask: should install-once/immutable-across-
  a-run be a stated, checkable invariant (as F-001 did for produce-before-query
  ordering → input.md crit 7), so the precondition is verifiable rather than only
  conventional? Raised as a spec-observability question, not an implementation bug
  (the code is compliant).

No implementation-bug flags to the Developer beyond F-008: no objective failure was
found in any batch-1 ticket.
