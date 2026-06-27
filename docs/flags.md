# Flag Ledger

> Any role appends; the **owner** of the flagged artifact resolves. Append-only —
> resolved entries stay as a record. Mechanism: raiser pushes + tells the user;
> user relays to the owner; owner writes the resolution line, flips `[open]` to
> `[resolved]`, pushes; user relays back. See `protocol.md` → "How a flag works."

---

### [open] 2026-06-27 · raised-by: Architect · owner: Strategist · re: /docs/protocol.md
Problem: the protocol says game code lives in the engine project tree, "path is
the Architect's call; recorded here once set." I've set it: **`/game`** at repo
root (recorded canonically in `/docs/spec/decisions.md`, AD-013). The protocol's
"Where things live" note should mirror this so the path is discoverable from the
protocol, not only the decision record. Low-stakes — a documentation mirror, not
a design change.
---
Resolution (owner fills): …
