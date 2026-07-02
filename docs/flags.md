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

### [open] 2026-07-02 · raised-by: QA · owner: Developer · re: game/sim/tick_host.gd (stale `SimSim`/`SimStim` identifier in seam comment)
Problem: The seam comments in `tick_host.gd` (and the JC-004 log) name the future
call `SimSim.step(...)` / `SimStim.step(...)`; the class landing at TKT-P0-03 is
`SimState`/`step` (README and `main.gd` already say `SimState`). Cosmetic doc
drift, zero code impact — flagged so the 03 developer isn't misled by an invented
`SimSim` name.
---
Resolution (owner fills): …
---

### [open] 2026-07-02 · raised-by: QA · owner: Strategist · re: /docs/tickets/p0-backbone.md + roadmap "done-when" (TKT-P0-01 audit scope)
Problem: TKT-P0-01's "Acceptance" line names crit 5 and crit 9 as its bar, but the
majority of what makes this ticket's tenet-proof meaningful (purity, round-trip,
determinism) is correctly deferred to 03/11. This is fine and intended — raised
only so done-tracking is explicit that TKT-P0-01 "passing audit" means *its own
reachable bar passed*, not that the determinism tenet is yet proven. No action
needed unless the Strategist wants the roadmap "done-when" wording to reflect the
partial coverage. FYI flag; owner may close as intended.
---
Resolution (owner fills): …
---
 NOT that determinism is yet proven end-to-end. No change needed
unless you want the roadmap "done-when" to reflect the partial coverage. Owner may
resolve as intended.
---
Resolution (owner fills): …
---
