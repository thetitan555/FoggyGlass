# Tickets — P0: Architecture Backbone

> Owned by the **Architect**. Developer-sized units decomposed from the P0 specs
> (`input.md`, `simulation.md`, `move-format.md`, `combat-resolution.md`,
> `inspection-surface.md`), serving roadmap phase P0. Each ticket names the spec
> it serves, its dependencies, and the acceptance criteria it must satisfy (QA
> verifies against the spec's criteria, not the ticket's prose). **The Developer's
> first work is TKT-P0-01.**

## Sequencing (interfaces first, done-bar early)

Contracts land before the systems that feed them, per the seam ordering: the
input contract (02) and the inspection-surface stub (04) exist — as real
interfaces — before the pipeline that fills them. The **done-bar scenario (10)**
lands as soon as core resolution (07) does; throws/multi-hit (08–09) complete the
P0 spec *after* the tenet proof, not before it. The determinism/serialization
hooks (11) come online **with** the sim loop (roadmap: violations are cheapest to
catch as the sim is written) — land 11 right after 03/04, not at the end.

```
01 scaffold + FP
 ├─▶ 02 input contract ──────┐
 ├─▶ 05 move format ─────────┼─▶ 06 phases 1–4 ─▶ 07 hit/stun/advantage ─▶ 10 test char + done-bar
 └─▶ 03 SimState + step ─────┘                      ├─▶ 08 input buffer + cancels
        └─▶ 04 inspection stub                      └─▶ 09 throws + multi-hit
        └─▶ 11 determinism/serialization hooks (with 04; land early)
```

---

### TKT-P0-01 · Project scaffold + fixed-point core
**Serves:** AD-013, AD-014; `simulation.md` (tick model). **Depends:** nothing.
**Scope:** The Godot project at `/game` (AD-013). The `FP` helper: 64-bit signed,
scale `2^16`, mul/div as shifts, the one documented rounding rule, **no
transcendentals** (AD-014). The fixed 60 Hz tick host in `physics_process`,
advancing off a tick counter in state — never `delta`-scaled; render decoupled.
**Acceptance:** `move-format.md` criterion 9 (fixed-point data path);
`simulation.md` criterion 5 (tick authority) — fully verifiable once 03 lands.

### TKT-P0-02 · Input contract: `InputFrame`, `InputSource`, device + replay sources
**Serves:** `input.md` (all). **Depends:** 01.
**Scope:** The 16-bit `InputFrame` (raw directions, `BUTTON_0..7`, reserved bits
validated); the one `InputSource` interface (`get_input(frame)`, frame-indexed,
reproducible, no future reads); the **Local-device** source (samples + records so
past frames stay answerable) and the **Replay** source (reads a recorded buffer).
No SOCD here — that is sim-side (06, AD-003). Record/playback dummy is P1
(TKT-P1-04); scripted source is P3.
**Acceptance:** `input.md` criteria 1, 2, 3, 4, 6 (criterion 5 lands with 06).

### TKT-P0-03 · `SimState` + pure `step` + serialization
**Serves:** `simulation.md`. **Depends:** 01, 02 (`step` takes two `InputFrame`s).
**Scope:** The `SimState` plain-data graph per spec (tick, rng, `players[2]`,
`projectiles` list — empty is fine for P0, stage); `step(state, in1, in2) →
SimState`, **non-mutating** (AD-004), advancing tick and pushing `input_history`
(full phase content lands 06–07); serialize → restore → resume round-trip; a
canonical state hash. No floats anywhere in state (AD-005/014).
**Acceptance:** `simulation.md` criteria 1, 3, 4, 5, 8, 9 (criterion 2 is
exercised end-to-end via 11; 6–7 verified as 04/06 land).

### TKT-P0-04 · Inspection surface — interface + minimal reads (stub)
**Serves:** `inspection-surface.md`; AD-011, AD-019. **Depends:** 03.
**Scope:** `InspectionView` with the **full API shape** (so P1 compiles against
it), implemented minimally over the current `SimState`: `tick()`, `player()` core
fields (state, frame, position, stun, hitstop, health, inputs), with
`frame_data()`, `advantage()`, `last_hit()` wired up as 05/07 land. Read-only by
construction; fixed-point truth only, px projection render-only (AD-019). The
complete implementation (resolved `BoxView`s, `projectiles()`) is **TKT-P1-01**;
this ticket exists so the seam is an interface from day one and 10/11 read
through it.
**Acceptance:** `inspection-surface.md` criteria 2 and 4 for the implemented
reads (criteria 1, 3, 5 complete at TKT-P1-01).

### TKT-P0-05 · Move-format resources + character state machine
**Serves:** `move-format.md`. **Depends:** 01 (FP), 03 (`state_id` linkage).
**Scope:** The `.tres` schema types — `Character`, `MoveState`, `Keyframe`,
`Box`, `HitBox`, `CancelRule`, the `Projectile` resource shell (AD-021; runtime
behavior is TKT-P1-0P) — engine-level state categories, the one state-machine
pattern, per-frame box resolution from keyframe ranges (derived, not stored,
AD-001), derived frame data (startup/active/recovery), stable text serialization.
**Acceptance:** `move-format.md` criteria 1, 2, 3, 6, 9 (5, 7, 8 verified once
07–09 land).

### TKT-P0-06 · Phase pipeline, phases 1–4: inputs, SOCD, movement, overlap
**Serves:** `combat-resolution.md` (phase order); `input.md` (SOCD); AD-009,
AD-012, AD-014. **Depends:** 02, 03, 05.
**Scope:** The fixed intra-tick phase order inside `step`; SOCD normalization as
**one** sim-side function applied identically to every source; raw→forward/back
via `facing`; fixed-point movement integration + pushbox/stage resolution; our
own AABB overlap of resolved boxes. Buffering/cancel execution stubbed until 08
(direct button→state transitions are enough for the test character).
**Acceptance:** `combat-resolution.md` criterion 2 (phase order); `input.md`
criterion 5 (SOCD determinism).

### TKT-P0-07 · Hit resolution, hitstop, stun, advantage (phases 5–7)
**Serves:** `combat-resolution.md` (hit vs block, hitstop, stun, advantage,
combo); AD-008, AD-010. **Depends:** 06.
**Scope:** Hit-vs-block determination; damage + scaling + combo accounting;
`hit_reaction`/`block_reaction`; hitstop semantics (counters frozen, loop ticks,
AD-010); stun/actionability; **the one advantage function** surfacing both the
static pinned value and the live cancel-aware value; the neutral-restored flag;
`id_group` single-hit. Wire `advantage()`/`frame_data()`/`last_hit()` into 04.
**Acceptance:** `combat-resolution.md` criteria 3, 4, 5, 6; `move-format.md`
criterion 5.

### TKT-P0-08 · Input buffer + cancel rules
**Serves:** `combat-resolution.md` (input buffer); `move-format.md`
(`CancelRule`); AD-015, AD-017, AD-022. **Depends:** 07.
**Scope:** The 9-frame motion window and 6-frame command buffer over
`input_history` (pure function of it — deterministic across sources); `CancelRule`
evaluation per `condition`/`window`/`input`/`requires_tag`; tag grant on tick T,
consumable T+1; buffered commands executing on first actionable frame (frame-1
reversal) or first open cancel window; cancels buffer but never execute during
hitstop.
**Acceptance:** `combat-resolution.md` criteria 8, 11; `move-format.md`
criterion 7.

### TKT-P0-09 · Throws + multi-hit / rehit
**Serves:** `combat-resolution.md` (throws, multi-hit); AD-016. **Depends:** 07.
**Scope:** Throwbox connect bypassing blockstun; the tech window; simultaneous-
throw clash-to-tech; sequential multi-hit (distinct `id_group`s per keyframe);
`rehit_interval` cadence. Air throws / formal throw priority stay deferred
(AD-016).
**Acceptance:** `combat-resolution.md` criteria 9, 10; `move-format.md`
criterion 8.

### TKT-P0-10 · P0 test character + done-bar scenario
**Serves:** `combat-resolution.md` criterion 1; roadmap P0 "done when".
**Depends:** 04, 05, 06, 07 (not 08/09 — the done-bar needs no throws or buffer).
**Scope:** A trivial test character authored **purely as `.tres` data** — idle,
walk, one or two normals with hand-computable frame data, hit/block reactions —
plus a runnable scenario: two instances, recorded/replayed inputs, one hit
resolves; startup/active/recovery and static + live advantage read back through
`InspectionView` and match hand-computed values. This is **not** character A
(TKT-P1-10); it is the tenet proof.
**Acceptance:** `combat-resolution.md` criterion 1; `move-format.md` criterion 4
becomes fully checkable when character A lands.

### TKT-P0-11 · Determinism / serialization harness hooks
**Serves:** `simulation.md` criteria 1–3; roadmap ("the harness comes online
*with* the sim loop"). **Depends:** 03, 04. **Land immediately after them — do
not defer to the end.**
**Scope:** The mechanical hooks the QA harness drives: the canonical state hash;
snapshot dump/load; a headless replay runner (start state + recorded input stream
→ final hash); a golden dump of `InspectionView` truth views (fixed-point only —
no px, AD-019). **QA owns the harness and its verdicts**; this ticket provides
only the hooks.
**Acceptance:** `simulation.md` criteria 1, 2, 3 runnable end-to-end;
`inspection-surface.md` criteria 4, 6.

---

## Cross-cutting

- **Judgment-call log:** any latitude taken on these tickets is recorded in
  `/docs/judgment-log.md` for Architect ratification before P0 is audited
  (protocol cadence).
- **P0 exit:** roadmap "done when" = 10 green + 11's hooks green under QA's
  harness. 08/09 complete the P0 spec's criteria set and gate the P0 *audit*,
  not the done-bar.
