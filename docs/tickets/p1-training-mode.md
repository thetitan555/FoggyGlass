# Tickets — P1: Debug / Technical Training Mode

> Owned by the **Architect**. Developer-sized units decomposed from
> `/docs/spec/training-mode.md` + `/docs/spec/inspection-surface.md`, serving the
> brief `debug-training-mode`. Each ticket names the spec it serves, its
> dependencies, and the acceptance criteria it must satisfy (QA verifies against
> the spec's criteria, not the ticket's prose).

## Sequencing (the seam)

At the systems/content seam the player-facing side is **downstream** of the
simulation-facing interface, so the sim-facing tickets (01–04) land first — as
real interfaces, stubbed if needed — before the player-facing tickets (05–09)
build on them. One developer writes both halves; the order still holds, because
05–09 compile against 01–04's surfaces.

```
01 inspection ─┐
02 frame-ctrl  ├─▶ 05 shell ─▶ 06 geometry
03 save/reset  │              ─▶ 07 frame-data+advantage
04 rec/play    ┘              ─▶ 08 live-state
                              ─▶ 09 input-display
```

P0 dependency: all of 01–04 require the P0 backbone (sim loop, serializable state,
inspection surface stub, `InputSource`). They observe whatever character exists —
the P0 test character is enough to build and verify against; character A (separate
content) sharpens validation when it lands.

### Build batches

The Developer executes these as three sessions (never invents its own batching —
protocol § "Token economy"). Grouping amortizes shared spec-reads and lands each
batch on a real checkpoint. Batch boundaries also honor the seam: Batch 1 lands the
sim-facing interfaces (and the projectile) that Batch 3's overlays read downstream.

- **Batch 1 (done):** TKT-P1-01, 02, 03, 04, 0P — the sim-facing interfaces plus the
  projectile entity. (03 depends on 04, 0P on the P0 backbone; all within-batch.)
  *Checkpoint:* the interfaces are green and a projectile resolves a hit.
- **Batch 2:** TKT-P1-10 — character A authoring, against the move format (needs 0P's
  fireball from Batch 1). *Checkpoint:* A is playable vs a dummy (the record/playback
  dummy from Batch 1's TKT-P1-04) — the **P1 done-bar** (Strategist's flag resolution).
- **Batch 3:** TKT-P1-05, 06, 07, 08, 09 — the training-mode shell plus the four
  overlays (all downstream of Batch 1's interfaces; 06–09 depend on 05). *Checkpoint:*
  the mode shows, live, what the sim is doing.

Note the deliberate ordering: character A (Batch 2) lands *before* the player-facing
overlays (Batch 3) that display it, because "A playable vs a dummy" is the P1 done-bar
and the overlays are the readout layer on top of a working, testable character. This is
a Strategist steerability call (widen/narrow batching is the Strategist's per protocol
§ "Token economy"); the mechanical grouping and its dependency-graph soundness are the
Architect's, and are recorded here. Dependency check: every batch's tickets have their
cross-batch dependencies satisfied by an earlier batch (0P before 10; 01–04 before 05;
05 before 06–09) — the plan is sound as drawn.

---

## Sim-facing interfaces (first)

### TKT-P1-01 · Inspection surface (concrete read API)
**Serves:** `inspection-surface.md`. **Depends:** P0 sim loop + `SimState`.
**Scope:** Implement `InspectionView` and its return types (`PlayerView`,
`BoxView`, `FrameData`, `AdvantageView`, `HitEvent`) as read-only views over the
current state, sourcing advantage/frame-data from the sim's own functions (no
re-derivation). `PlayerView` includes the batch-2 legibility fields
(`move_contact`, `cancel_tags`, `throw_tech_window`, `thrown_by`) surfaced
read-only from the corresponding `SimState` truth (F-013 / AD-028) — no
re-derivation, just projection. Build the interface first; this is the seam
everything else reads. Snapshot-able views are fixed-point only (these four are
plain int / int-array, no floats); px is a render-only projection (AD-019).
**Acceptance:** `inspection-surface.md` criteria 1–6.

### TKT-P1-02 · Frame control (pause / resume / step-once)
**Serves:** `training-mode.md` → Control layer (frame control). **Depends:** P0 sim
loop. **Scope:** `set_paused`/`is_paused`/`step_once`; stepping advances exactly
one tick and crosses hitstop one tick per call (AD-010).
**Acceptance:** `training-mode.md` criteria 1–2.

### TKT-P1-03 · Situation save / restore + single reset slot
**Serves:** `training-mode.md` → Control layer (reset). **Depends:** P0
serializable state; **TKT-P1-04** (reset point includes source playback position).
**Scope:** `snapshot`/`restore`; one reset slot (`capture_reset`/`do_reset`). The
reset point bundles the sim `StateBlob` **and** each `RecordPlaybackSource`'s
playback position, and `do_reset()` restores both so the dummy re-syncs (AD-020).
No multi-slot. Coordination lives in the harness, not the sim (Tenet 2 intact).
**Acceptance:** `training-mode.md` criteria 3 and 12.

### TKT-P1-04 · Record/playback dummy (input source)
**Serves:** `training-mode.md` → Control layer (dummy); `input.md`. **Depends:** P0
`InputSource` interface. **Scope:** `RecordPlaybackSource` implementing
`InputSource` with `PASSTHROUGH` / `RECORDING` / `PLAYBACK` modes over a raw
`InputFrame` buffer, looping playback. No AI/behavior. Expose a readable/restorable
playback position so the reset point (TKT-P1-03) can re-sync it (AD-020); being
frame-indexed (`input.md`) makes this natural.
**Acceptance:** `training-mode.md` criteria 4 and 12.

---

### TKT-P1-0P · Projectile entity system
**Serves:** AD-021; `move-format.md` (spawn/`Projectile`), `simulation.md`
(`SimState.projectiles`), `combat-resolution.md` (Projectiles section),
`inspection-surface.md` (`projectiles()`). **Depends:** P0 sim loop + state.
**Scope:** Add `SimState.projectiles`; the `spawn` keyframe action with per-owner
cap; per-tick integration, overlap-vs-opponent-hurtbox, hit/block resolution, and
despawn (consumed / lifetime / off-stage); expose `ProjectileView`. Sim-facing —
character A's fireball needs it. No projectile-vs-projectile (deferred).
**Acceptance:** `character-a.md` criterion 5 (fireball is a projectile);
surfaced in the geometry overlay (training-mode criterion 5).

## Content (authored against the format)

### TKT-P1-10 · Author character A move data
**Serves:** `character-a.md` (full kit). **Depends:** P0 move format; **TKT-P1-0P**
(fireball). **Scope:** Author all of A — movement, 9 normals, fireball/shoryuken
(L/M/H), throw — purely as `.tres` move data with the listed frame data, hitboxes,
properties, and `CancelRule`s (special-cancels + links only; no gatlings/jump
cancels). No engine changes. This is the training mode's first *real* test subject
and the P1 done-bar (per the Strategist's flag resolution).
**Acceptance:** `character-a.md` criteria 1–7 and 9 (criterion 8 lands with
TKT-P0-08; criterion 10 is verified at the feature audit, in-mode).

## Player-facing (downstream of the interfaces)

### TKT-P1-05 · Training-mode shell / scene
**Serves:** `training-mode.md` (placement + integration). **Depends:** 01–04
(interfaces, stubs ok). **Scope:** The mode/scene that wires a match with two input
sources (P1 = device, P2 = record/playback dummy), mounts the frame-control,
reset, and record/playback controls, and provides the surface the overlays render
into. Reads only via `InspectionView` + the control contracts — no `SimState`
internals.
**Acceptance:** `training-mode.md` criterion 10 (seam discipline); integrates
02–04 so their criteria are exercisable in-mode.

### TKT-P1-06 · Geometry overlay
**Serves:** `training-mode.md` → Readout (geometry). **Depends:** 01, 05.
**Scope:** Draw resolved `BoxView`s per player in world space, color-coded by
kind, active hitboxes distinct.
**Acceptance:** `training-mode.md` criterion 5.

### TKT-P1-07 · Frame-data & advantage panel
**Serves:** `training-mode.md` → Readout (frame data + advantage). **Depends:** 01,
05. **Scope:** Static startup/active/recovery + on-hit/on-block advantage for moves
in play; live advantage (value, who-plus, frames-to-neutral, neutral flag).
**Acceptance:** `training-mode.md` criterion 6; relies on AD-008's static-vs-live
distinction.

### TKT-P1-08 · Live-state panel (state, hitstop, stun, damage/combo)
**Serves:** `training-mode.md` → Readout (live state). **Depends:** 01, 05.
**Scope:** Per player: state + category + frame/duration, hitstop, stun + kind,
actionable; damage/combo (hit_count, scaling, total).
**Acceptance:** `training-mode.md` criteria 7 and 9.

### TKT-P1-09 · Input display / history
**Serves:** `training-mode.md` → Readout (input). **Depends:** 01, 05. **Scope:**
Decode the current `InputFrame` (directions + buttons) per player and a scrolling
history of recent raw frames (Tenet 2).
**Acceptance:** `training-mode.md` criterion 8.

---

## Cross-cutting (verified at feature audit, not a separate ticket)

- **Same-surface-as-QA** (`training-mode.md` criterion 11): the determinism/golden
  harness and the overlays read the one inspection surface; QA confirms no
  divergent second source of truth.
- **Judgment-call log:** any latitude the Developer takes on these tickets is
  recorded for Architect ratification before this feature is audited (protocol
  cadence).
