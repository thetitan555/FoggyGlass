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
- **`decisions.md`** — the architecture decision record.

**Sequencing.** At the systems/content seam the player-facing side is downstream
of the simulation-facing interface, so the inspection surface (`simulation.md`),
even as a stub, comes before any feature that reads it. The determinism +
serialization harness comes online *with* the sim loop, not after.

## Status

P0 backbone: **spec drafted, awaiting review.** P1 (debug/technical training
mode) spec + tickets: not yet started — next session.
