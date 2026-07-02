# Audit — TKT-P0-02 (input contract) & TKT-P0-03 (SimState + pure step + serialization)

> QA audit report. Owner: QA. Routed findings live in `docs/flags.md`.
> Date: 2026-07-02. Auditor: QA (FoggyGlass).
>
> Scope: `game/sim/{input_frame,input_source,local_device_source,replay_source,
> input_history,sim_state,player_state,stage_state,rng_state,tick_host}.gd`,
> `game/scenes/main.gd`, and `game/tests/{test_input,test_sim_state,
> test_tick_host,test_fp}.gd`, against `docs/spec/input.md` (crit 1,2,3,4,6),
> `docs/spec/simulation.md` (crit 1,3,4,5,8,9), the named ADs, and JC-006..009.
>
> Engine reality: Godot is not installed in this environment. No test script was
> executed and no end-to-end determinism proof was run. Every verdict below is
> split into **verified statically** (by reading + hand-tracing) vs. **gated on
> the engine / QA harness TKT-P0-11**.

---

## Verdicts

- **TKT-P0-02 (input contract): PASS-WITH-FINDINGS.** All statically-checkable
  acceptance criteria hold (1,2,4,6 fully; 3 by construction). One non-blocking
  finding routed (F-001, doc/observability nit to Architect). SOCD/crit 5 is
  correctly deferred to TKT-P0-06 (not audited, not a finding).
- **TKT-P0-03 (SimState + step + serialization): PASS-WITH-FINDINGS.** Purity,
  immutability, round-trip, hash canonicality, and no-floats-in-state all hold on
  static trace and are structurally sound. Criteria whose *proof* requires a
  running engine (crit 2 end-to-end determinism) or a later ticket (crit 6/7 seam,
  TKT-P0-04) are gated, not failed. One non-blocking finding routed (F-001).

No objective failure found. Nothing here blocks the backbone; the tenet is being
served (see closing read).

---

## TKT-P0-02 — input contract, per input.md acceptance criteria

| Crit | Statement | Verdict | Basis |
|---|---|---|---|
| 1 | InputFrame serialize/restore is bit-identical | **PASS (static)** | Frame value IS a masked `int` (JC-006); `InputHistory.to_dict/from_dict` duplicate a `PackedInt32Array` with no transform. Test `_test_round_trip` asserts age-by-age identity through the real sim serialization path. |
| 2 | Reproducible `get_input(N)` for a produced frame | **PASS (static)** | `LocalDeviceSource` records into `_buffer`; `get_input` is a pure indexed read. `ReplaySource` fixes its buffer at construction. Both assert on future reads. Test queries each frame twice. |
| 3 | Local recording replayed == identical stream | **PASS by construction (static)** | `ReplaySource._init` duplicates the exact `get_recorded_buffer()` bytes and re-validates; `get_input` is the same indexed read. Test `_test_source_equivalence` compares 25 frames plus replay self-reproducibility. Runtime engine run not required — the buffer is the sole state. |
| 4 | Dumb layer: no facing/character/sim reads | **PASS (static)** | Confirmed by reading: `LocalDeviceSource` depends only on its injected `Callable` sampler + `_buffer`; `ReplaySource` only on `_buffer`. No `Input.*`/`Time`/sim references in code (grep, comments stripped: none). The device poll lives in `main.gd` (view), outside the source and outside `step`. |
| 5 | SOCD determinism | **DEFERRED** | Sim-side, TKT-P0-06. Raw opposing directions correctly stay raw end-to-end (verified: `_test_round_trip` keeps Left+Right). Not a finding. |
| 6 | Reserved-bit (12..15) rejection | **PASS (static)** | `InputFrame.is_valid` checks `RESERVED_MASK` **and** 16-bit width. `InputSource.validate` routes every produced value through it (asserts debug, strips in release). Both concrete sources validate at their boundary (`sample_next`, `ReplaySource._init` loop). Test exercises bits 12, 15, and 16. |

**Gated on engine:** none for 02 beyond ordinary "the assertions fire under a real
run" — the logic is fully hand-traceable and buffer-only.

## TKT-P0-03 — SimState / step / serialization, per simulation.md

| Crit | Statement | Verdict | Basis |
|---|---|---|---|
| 1 | Purity: step twice on equal (s,a,b) → equal hashes | **PASS (static)** | `step` clones then mutates only the clone; deterministic (no external reads). Test `_test_immutable_input_and_purity` asserts `next1.hash == next2.hash`. |
| 3 | Snapshot at j, restore, resume to K == uninterrupted | **PASS (static)** | `to_dict`/`from_dict` are exact inverses over plain-data; deep-copy detach confirmed. Test `_test_snapshot_restore_resume` (K=20, j=8) reconstructs from the dict and matches the gold hash; `_test_full_round_trip` covers the base + double round-trip. |
| 4 | No forbidden reads; RNG in snapshot & advances with it | **PASS (static)** | `step`'s only inputs are `(state, in_p1, in_p2)`. No `Time`/`OS`/`Engine`/`randi`/`Input` in any code path reachable from `step` (grep, comments stripped: none). `RngState` (SplitMix64) lives in `SimState.rng`, is in `to_dict` and in `hash_state`; different seeds hash differently (tested). |
| 5 | Tick authority from `state.tick`, not engine frame count | **PASS (static)** | `TickHost.current_tick()` returns `_sim_state.tick`; `_advance` reads `state.tick` as the frame, one advance per `_physics_process`, `_delta` unused. Test drives 120 advances + paused/huge-delta cases → exactly +1 each. The "render-rate doesn't change outcomes" half is true by construction (advance path takes no delta/frame input); full end-to-end is a TKT-P0-11 harness check. |
| 8 | No floats in sim state; no transcendentals | **PASS (static, my own recursive scan)** | Recursive `_has_float` test walks the serialized dict. Independently confirmed: I grepped every sim file — the only `float` tokens are (a) `fp.gd` authoring bakes (`from_float`/`from_units`) and view projection (`to_float`), all documented off-hot-path per AD-014 and never called from `step`; (b) comments; (c) `tick_host._delta` (unused). **No float-typed field exists in any state object.** `combo_scaling` is an FP int (65536), not a float. No trig/sqrt/pow anywhere. |
| 9 | Immutable input: hash(prev) unchanged after step | **PASS (static)** | Non-mutation is structural: `step` writes to `state.clone()`. Deep-copy discipline verified per member — `PlayerState.clone` deep-copies `input_history` (reference type), `RngState.clone`/`StageState.clone` copy values; no aliasing back into `prev`. Test asserts `s.hash == before_hash` after step **and** `prev p1 history size == 0` (the alias trap). |

**Gated (not failed):**
- **Crit 2 (determinism harness, end-to-end):** replay one input stream twice →
  identical final hash. Requires a running engine and the QA harness (TKT-P0-11).
  The building blocks are all present and the in-test analog
  (`_test_snapshot_restore_resume`, same-seed equality) passes on trace; the true
  end-to-end proof is mine to land at TKT-P0-11.
- **Crit 6 (read-only seam) & Crit 7 (no engine-physics state):** the inspection
  surface lands at TKT-P0-04 and there is no physics body in `SimState` today
  (AABB is TKT-P0-06). Nothing to verify yet; not in these tickets' scope.

---

## Judgment-call log — drift check (JC-006..009)

Each provisional call was checked against both the spec and the code. All four
**match the code and do not drift from the spec**; all remain provisional pending
Architect ratification (that is the Architect's cadence duty, not a QA finding).

- **JC-006** (InputFrame = masked `int`, class as namespace): matches `input_frame.gd`.
  Round-trips as itself; consistent with input.md "plain value, byte-identical".
  No drift.
- **JC-007** (canonical hash = ordered FNV-1a over an integer stream): matches
  `sim_state.hash_state`. **Hand-verified the canonicality claims:** walks named
  keys in fixed source order (not Dictionary iteration), folds a count separator
  before the players list, before each history's frames, and the projectile count;
  `_fold` processes 8 bytes low-first with `& 0xFF` (correct for negative 64-bit
  values — arithmetic `>>` then mask still yields the true two's-complement byte).
  Float-free. Every serialized field is covered by the hash (I diffed `to_dict`
  keys vs. hashed keys for player + stage: exact match). No drift; this is the
  load-bearing determinism primitive and it is sound.
- **JC-008** (InputHistory CAP=32): matches `input_history.gd`; covers AD-022's
  9/6 windows with headroom; stored flat oldest→newest so serialization is
  cursor-independent (canonical). No drift.
- **JC-009** (sources sampled parent-before-child via tree order in `main.gd`):
  matches `main.gd` + `tick_host.gd`. The Developer already flagged this as
  scaffold wiring to harden if a later ticket needs a hard ordering guarantee.
  **QA concurrence (non-blocking):** the *sim* is unaffected — `step` consumes only
  the already-recorded frame, and both `LocalDeviceSource.get_input` and the host's
  `_advance` assert against future reads, so a mis-order would fail loudly, not
  silently corrupt determinism. Fine for this audit. Noted in F-001 as the one
  thing worth an Architect eye for the *observability* of that guarantee, not a
  defect.

---

## Placeholder P0 geometry — reviewed, NOT a finding

The Developer disclosed placeholder P0 data: spawns at ±100, `health = 1000`,
walls ±400, ground 0 (`SimState.new_initial`, `StageState.new_initial`). Judged
against the audit criterion and the acceptance criteria:

- input.md and simulation.md acceptance criteria require the state to be **valid,
  symmetric, float-free, serializable, and deterministic** — not tuned. All hold.
- The audit criterion tests legibility and no-dumbing-down; placeholder starting
  numbers are neither an opacity nor a flattening. There is no player-facing
  behavior to be opaque yet.
- Authored data is already ticketed (TKT-P0-10). The values are round, clearly
  labelled "data, not feel," and overridable via `new_initial` arguments.

**Cleared.** Not routed. (If tuned values were silently presented *as* final, that
would be drift — they were not.)

---

## Findings (routed to `docs/flags.md`)

- **F-001 → Architect (observability/spec nit, non-blocking).** simulation.md and
  input.md fix that inputs must be produced before the sim requests them (no future
  reads) but do not state *where* the produce-before-query ordering guarantee is
  owned. JC-009 leans on Godot node tree order in the scaffold; that is fine for
  the sim (asserts guard it), but the acceptance criteria give QA nothing to assert
  the ordering *contract* against — only the runtime assert. Ask: should the
  produce/consume ordering be an owned acceptance criterion (e.g. host owns
  sampling, or a stated invariant) so it is verifiable rather than resting on tree
  order? Raised as a spec-observability question, not an implementation bug.

No implementation-bug flags to the Developer: no objective failure was found.
```

## Static vs. engine-gated — summary for the record

**Verified statically (pass/fail owned by QA):** input.md 1,2,3,4,6;
simulation.md 1,3,4,5,8,9; hash canonicality; deep-copy/non-mutation discipline;
no-floats recursive scan; JC-006..009 code-vs-spec match.

**Gated on the engine / TKT-P0-11 (cannot claim pass here):** simulation.md crit 2
(end-to-end replay-twice determinism), and the runtime firing of debug `assert`s.
**Gated on a later ticket:** simulation.md crit 6 (seam, TKT-P0-04) and crit 7
(engine-physics state, TKT-P0-06) — out of these tickets' scope.
