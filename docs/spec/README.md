# Spec — Index

> Owned by the **Architect**. The buildable contracts the Developer builds
> against and QA verifies through. Each doc carries **acceptance criteria**
> (checkable "done and correct" statements). Read `decisions.md` for *why* the
> architecture is the way it is.

## P0 — Architecture backbone

The proof surface everything else hangs on. No content; just the contracts.

- **`input.md`** — the input-source contract: the per-frame `InputFrame`
  representation and the one `InputSource` interface every producer implements
  (Tenet 2).
- **`simulation.md`** — the deterministic sim loop, the serializable `SimState`
  shape, and the read-only inspection surface that is the systems/content seam
  (Tenet 1).
- **`move-format.md`** — the data-driven `.tres` move/frame-data format and the
  single state-machine pattern every character uses.
- **`combat-resolution.md`** — how a tick resolves combat (phase order, overlap,
  hitstop, stun, the single advantage formula, combo) and how each result maps to
  the inspection surface.
- **`inspection-surface.md`** — the concrete read-only `InspectionView` API: the
  systems/content seam that debug mode, QA, and UI all read sim truth through.
- **`decisions.md`** — the architecture decision record.

## P1 — Debug / technical training mode

The first feature, built on the backbone. The charter's legibility promise made
literal, and the team's instrumentation.

- **`training-mode.md`** — the feature spec: control layer (frame control,
  save/restore reset, record/playback dummy) + readout layer (geometry, frame-data
  & advantage, live state, input history), with acceptance criteria.
- **`/docs/tickets/p1-training-mode.md`** — the seam-ordered ticket decomposition
  (TKT-P1-01…09).

**Sequencing.** At the systems/content seam the player-facing side is downstream
of the simulation-facing interface, so the inspection surface (`simulation.md`),
even as a stub, comes before any feature that reads it. The determinism +
serialization harness comes online *with* the sim loop, not after.

## Status

P0 backbone: **spec drafted; revised once** to adopt fixed-point sim math
(AD-005/AD-014) and to resolve four Consultant flags — advantage static-vs-live
(AD-008), the `CancelRule` model + cancel/hitstop timing (AD-015/AD-017),
non-mutating `step` (AD-004), and multi-hit/throw models (AD-016). See `flags.md`
for the resolutions. P1 (debug/technical training mode): **spec + tickets drafted**
(`training-mode.md`, `inspection-surface.md`, `tickets/p1-training-mode.md`) —
awaiting review, then the Developer can pick up TKT-P1-01.
