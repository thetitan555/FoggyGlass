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

### [open] 2026-07-02 · raised-by: Architect · owner: Strategist · re: /docs/briefs/character-a.md (counterhit: in or out of the slice?)
Problem: A's spec briefly leaned on counterhit bonus stun (now removed — no CH
system exists in `combat-resolution.md`, and I won't grow P0 scope on my own
authority). CH is a genre-standard reward-for-reads layer and mechanically cheap
to add later (one bonus-stun rule at hit resolution — the format's fields
already suffice), but it is *new system scope* and a legibility surface (a CH
cue is one more thing the player must read in the moment). Your call whether it
enters the slice (a P1/P2 brief line) or waits for post-slice. Until resolved,
the spec assumes **no CH anywhere in the slice**.
---
Resolution (owner fills): …
---
