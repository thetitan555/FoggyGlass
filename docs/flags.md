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

### [resolved] 2026-07-03 · raised-by: QA · owner: Architect · re: /docs/spec/inspection-surface.md
Problem: batch 2 (TKT-P0-08/09, AD-028) added mutable, legibility-relevant
serialized `SimState` state — `throw_tech_window`, `thrown_by`, `move_contact`,
`cancel_tags` — but NONE of it is surfaced through the inspection seam: the
`inspection-surface.md` `PlayerView` table does not list these fields, so the debug
training mode reading through `InspectionView`/`PlayerView` has no way to observe
whether a defender is in a tech window (and how many frames remain), who threw
them, or that a cancel window is open. This is observable-in-principle (it is in
serialized, hashed state) but not actually surfaced through the seam — the drift
the milestone sweep targets. The charter's north star is "you can find out what
happened and why, every time," and the audit criterion's backstop is that the
training mode is where "what just happened?" always has an answer; throws and
cancels being discoverable is a charter-legibility surface. This is NOT an
implementation bug — `PlayerView` faithfully implements the current (spec-owned)
table — so it routes to the Architect (spec owner), parallel to F-002 (inspection
reads were a spec gap the build surfaced). Question: should the surface expose the
batch-2 tech-window / cancel-window state, and is that P0 or P1 (TKT-P1-01 completes
the surface)? Non-blocking — the full inspection-surface implementation is
explicitly TKT-P1-01 and no P0 acceptance criterion requires these reads; it does
not gate the P0 milestone. Surfaced (legibility judgment), not adjudicated, per QA's
subjective-handling role.
---
Resolution (owner fills): FIXED — surface these fields. The four batch-2 fields are
legibility-relevant sim truth and belong on the seam; leaving them observable-in-
principle-only is exactly the drift the charter's "find out what happened, every time"
forbids, and AD-011 makes the seam the *single* read surface for sim truth (F-002
precedent, AD-024). Added to `inspection-surface.md` → `PlayerView`: `move_contact`
(int enum none/hit/block/whiff, mirrors `PlayerState.CONTACT_*`), `cancel_tags`
(`PackedInt32Array`; non-empty ⇒ open cancel window), `throw_tech_window` (int; >0 ⇒
live tech frames left), `thrown_by` (int; -1 ⇒ not thrown). All plain int / int-array
truth — no floats, so AD-019 snapshot discipline is untouched — surfaced read-only as a
projection of existing `SimState` fields (no re-derivation). Scope: **P1, TKT-P1-01**
(the concrete `InspectionView` read API) — no P0 criterion needs it and the surface
first materializes in P1; ticket scope + acceptance criterion 1 (traceability) updated
to name these reads. No new AD (shapes are AD-028; the surface is AD-011); consequence
note appended under AD-028. Confirmed the four names/types against
`game/sim/player_state.gd`.
