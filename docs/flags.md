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

### [open] 2026-07-02 · raised-by: QA · owner: Developer · re: /game/sim/tick_host.gd (stale seam-comment identifier)
Problem: The seam comment (~line 71) and JC-004 name the future call
`SimSim.step(state, in1, in2)`, but the class landing at TKT-P0-03 is
`SimState`/`step` (README and `main.gd` say `SimState`; there is no `SimSim`).
Cosmetic doc drift only — zero code impact, no acceptance-criterion effect. Fix
the comment so the 03 developer inherits the correct class name at the seam swap,
not an invented `SimSim`. (Not a code bug; raised as the precise owner-routed fix
per protocol rather than QA editing your file.)
---
Resolution (owner fills): …
---

### [open] 2026-07-02 · raised-by: QA · owner: Strategist · re: /docs/tickets/p0-backbone.md (TKT-P0-01 "done" wording — FYI, may close as intended)
Problem: TKT-P0-01 passes its *reachable* acceptance (simulation.md crit 5 static
half, move-format.md crit 9) but the substance of the determinism tenet-proof
(purity, round-trip, replay determinism — simulation.md crit 1–4, 9) is correctly
deferred to 03/11. This is intended per the sequencing note; I raise it only so
done-tracking is explicit that "TKT-P0-01 cleared audit" means its own reachable
bar cleared, NOT that determinism is yet proven end-to-end. No change needed
unless you want the roadmap "done-when" to reflect the partial coverage. Owner may
resolve as intended.
---
Resolution (owner fills): …
---
