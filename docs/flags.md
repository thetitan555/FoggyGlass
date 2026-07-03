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

### [open] 2026-07-03 · raised-by: QA · owner: Developer · re: game/tests (AD-027 strict overlap)
Problem: No test pins the AD-027 strict-overlap boundary at exact adjacency.
`ResolvedBox.overlaps` is correct (strict `<`/`>`, touching edges do not overlap),
but nothing locks the touching-edge = no-hit convention against a future accidental
flip to `<=`/`>=`. Since AD-027 now makes adjacency the load-bearing hit/no-hit
decision, add a boundary golden/assertion: two boxes at `a.x + a.w == b.x` do NOT
overlap; a 1-subunit penetration DOES. Test-tooling only; non-blocking (F-008).
---
Resolution (owner fills): …

### [open] 2026-07-03 · raised-by: QA · owner: Architect · re: /docs/spec/simulation.md (AD-024)
Problem: AD-024 states the immutable-roster / install-once determinism precondition
(MoveRegistry), but no acceptance criterion gives QA something to *assert* it
against — it rests on wiring discipline (the code is compliant) plus a QA harness
watch item. The type system does not prevent a mid-run `install()`/`clear()`, which
would be a silent determinism break. Ask: should install-once / immutable-across-a-
run be a stated, checkable invariant (as F-001 did for produce-before-query ordering
→ input.md crit 7), so the precondition is verifiable rather than only conventional?
Spec-observability question, not an implementation bug; non-blocking (F-009).
---
Resolution (owner fills): …
