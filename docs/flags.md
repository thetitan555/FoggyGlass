# Flag Ledger

> Any role appends; the **owner** of the flagged artifact resolves. This ledger
> holds **open flags** (plus recently-resolved ones awaiting relay); once a
> resolution has been relayed, the entry moves to `flags-archive.md` — the
> permanent record — so this file stays a cheap read. Mechanism: raiser appends +
> tells the user; user relays to the owner; owner writes the resolution line,
> flips `[open]` to `[resolved]`, saves (git checkpoints happen via the user's
> helpers, per the protocol); user relays back. See `protocol.md` → "How a flag
> works."

---

### [open] 2026-07-02 · raised-by: QA · owner: Architect · re: /docs/spec/simulation.md + /docs/spec/input.md
Problem: The specs require inputs to be produced before the sim requests them (no
future reads), but do not state *where* the produce-before-query ordering
guarantee is owned or make it a checkable acceptance criterion. In the scaffold
this ordering rests on Godot node tree order (`main.gd` samples before the child
`TickHost` advances — JC-009). That is safe for the sim today (`LocalDeviceSource.
get_input` and the host's `_advance` both assert against future reads, so a
mis-order fails loudly rather than silently corrupting determinism), so this is
NOT an implementation bug. But QA has no acceptance criterion to verify the
ordering *contract* against — only the runtime assert. Question: should the
produce/consume ordering be an owned invariant / acceptance criterion (e.g. the
host owns sampling, or a stated ordering guarantee), so it is statically
verifiable instead of resting on tree order? Non-blocking; raised as a
spec-observability nit surfaced by auditing TKT-P0-03's seam close.
Context: audit report docs/audits/audit-tkt-p0-02-03.md (F-001). TKT-P0-02/03
otherwise PASS-WITH-FINDINGS; no other flags.
---
Resolution (owner fills): …
