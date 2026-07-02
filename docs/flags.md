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

### [resolved] 2026-07-01 · raised-by: Strategist · owner: Architect · re: /docs/tickets/ (missing P0 decomposition)
Problem: The P0 backbone has spec but no ticket decomposition — `/docs/tickets/`
contains only P1. `spec/README.md` pointed the Developer at TKT-P1-01, but every
P1 ticket depends on P0 deliverables (sim loop, `SimState`, `InputSource`,
inspection-surface stub) that have no tickets to build them by. The Developer's
role prompt says "build per the tickets"; a memory-less Developer session either
stalls or invents its own decomposition. Ask: decompose P0 into tickets
(interfaces-first, per your own seam ordering) before the Developer's first
session — this is the current blocker for development starting at all.
---
Resolution (Architect, 2026-07-02): Done — `/docs/tickets/p0-backbone.md`
decomposes P0 into **TKT-P0-01…11**, interfaces-first: the input contract (02)
and the inspection-surface stub (04) land as real interfaces before the pipeline
that fills them; the done-bar scenario (10) lands as soon as core resolution (07)
does; throws/multi-hit (08–09) complete the spec after the tenet proof; the
determinism/serialization hooks (11) come online with the sim loop, not at the
end. `spec/README.md` now points the Developer at **TKT-P0-01** as the first work.
---

### [resolved] 2026-07-01 · raised-by: Strategist · owner: Architect · re: /docs/spec/character-a.md (BnB routes contradict the frame data)
Problem: Two internal contradictions, checkable by the spec's own link arithmetic
(the same arithmetic that correctly yields the 5H link: window = on-hit advantage
− startup + 1 → 7 − 5 + 1 = 3). (a) Route 3 (`2L , 2L , 2M > 236H`) is impossible
as written: `2L , 2L`, claimed as a 1-frame link, computes to a **0-frame window**
(+3 hit adv vs 4f startup), and `2L , 2M` computes to **−2** (+3 vs 6f). Either
the hitstun table or the route is wrong. (b) Route 5 (`5M (CH) , 2M > 623L`)
depends on counterhit bonus stun, but no counterhit system exists anywhere in
`combat-resolution.md` or `move-format.md`. Fix the data or the routes; if
whether CH belongs in the slice is a design/scope question rather than a spec
gap, kick that part back to me. Note QA impact: criterion 10 ("each required
link window is non-empty") fails this spec as written.
---
Resolution (Architect, 2026-07-02): (a) Data fixed: `2L` hitstun 12 → **15**
(on-hit +3 → +6), making route 3 arithmetic-valid — `2L , 2L` = 3f window,
`2L , 2M` = 1f (the kit's hardest link; the old "1f" claim was misattributed to
`2L , 2L`). (b) Ruled + kicked: correct, no counterhit system exists in the
slice's combat resolution, and I won't grow P0 scope on my own authority — route
5 is removed, replaced with a DP-punish route; whether CH *should* enter the
slice is yours and is raised as a new flag below (owner: Strategist). Criterion
10's link arithmetic now checks out for every route.
---

### [resolved] 2026-07-01 · raised-by: Strategist · owner: Architect · re: /docs/spec/character-a.md (tuning values baked into acceptance criteria)
Problem: Acceptance criteria pin tuning-grade numbers: criterion 3 requires the
5H→5M link window be "exactly 3 frames," and criterion 2 requires derived frame
data "equal the tables" while the DP on-block values are approximate ("≈ −34").
These numbers were authored with no playable sim to feel them in; once one
exists, every tuning pass becomes a criterion failure requiring a flag
round-trip. Ask: re-shape the criteria to pin **structure** (the link exists and
is displayed; advantage derives from the one formula; the DP is full-punishable)
and mark the numeric tables **provisional until playable**, so QA can pass a
tuning change that preserves structure. The exact criterion shape is yours; the
provisional-numbers stance is mine and the user's.
---
Resolution (Architect, 2026-07-02): Adopted. `character-a.md` gains a **Tuning
status** stance — all numeric tables provisional until playable; structure is
binding. Criteria 2, 3, 4, 6 re-shaped to pin structure: derivation-consistency
via the one formula (not exact table values); the `5H` link non-empty, tight, and
displayed (3f is an authored target, provisional); `2H` invuln covering its
active frames and at-worst-slightly-minus; the DP full-punishable **by
construction** (even 25f `5H` punishes) rather than "≈ −34". AD-022's 9f/6f
buffer windows stay pinned — those are system constants, not character tuning.
---

### [resolved] 2026-07-01 · raised-by: Strategist · owner: Architect · re: /docs/spec/character-a.md + /docs/spec/README.md (character B pre-committed in spec)
Problem: Both docs stated character B's identity (gatlings + jump cancels, "per
the peek ahead"), but B's archetype is a roadmap open question owned by the
Strategist and deferred to the P2 brief. Root cause: the user steered A's numbers
in chat "to match up to a B like that"; the direction never landed in an owned
artifact, so the Architect recorded its understanding in the only place it could
— its own spec.
---
Resolution (user directive; edits applied by Strategist on the user's
instruction): Direct B references removed from both docs — A's "no gatlings / no
jump cancels" stance is unchanged and now points at "a later contrast character";
the user's actual leaning is recorded where direction lives (`roadmap.md` → open
questions). The protocol gains a **"direction lives upstream"** working agreement
so chat steers get routed to the owning artifact instead of recorded downstream.
Bundled user-directed hygiene edits, also applied by the Strategist: "awaiting
review" removed from `spec/README.md` status (no such gate exists in the
protocol); a one-line AD index added atop `decisions.md`; resolved flags moved to
`flags-archive.md`. Architect: on your next session, sanity-check that nothing
else in the spec leans on B's specifics, and re-own the touched files.
*(Architect, 2026-07-02: sanity-check done — remaining "later contrast
character" mentions state only A's negative space, not B's identity; touched
files re-owned. Relay complete; ready for archive.)*
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
