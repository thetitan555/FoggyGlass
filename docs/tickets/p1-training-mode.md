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

---

## Sim-facing interfaces (first)

### TKT-P1-01 · Inspection surface (concrete read API)
**Serves:** `inspection-surface.md`. **Depends:** P0 sim loop + `SimState`.
**Scope:** Implement `InspectionView` and its return types (`PlayerView`,
`BoxView`, `FrameData`, `AdvantageView`, `HitEvent`) as read-only views over the
current state, sourcing advantage/frame-data from the sim's own functions (no
re-derivation). Build the interface first; this is the seam everything else reads.
**Acceptance:** `inspection-surface.md` criteria 1–5.

### TKT-P1-02 · Frame control (pause / resume / step-once)
**Serves:** `training-mode.md` → Control layer (frame control). **Depends:** P0 sim
loop. **Scope:** `set_paused`/`is_paused`/`step_once`; stepping advances exactly
one tick and crosses hitstop one tick per call (AD-010).
**Acceptance:** `training-mode.md` criteria 1–2.

### TKT-P1-03 · Situation save / restore + single reset slot
**Serves:** `training-mode.md` → Control layer (reset). **Depends:** P0
serializable state. **Scope:** `snapshot`/`restore`; one reset slot
(`capture_reset`/`do_reset`) over a `StateBlob`. No multi-slot.
**Acceptance:** `training-mode.md` criterion 3.

### TKT-P1-04 · Record/playback dummy (input source)
**Serves:** `training-mode.md` → Control layer (dummy); `input.md`. **Depends:** P0
`InputSource` interface. **Scope:** `RecordPlaybackSource` implementing
`InputSource` with `PASSTHROUGH` / `RECORDING` / `PLAYBACK` modes over a raw
`InputFrame` buffer, looping playback. No AI/behavior.
**Acceptance:** `training-mode.md` criterion 4.

---

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
