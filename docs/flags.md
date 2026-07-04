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

### [open] F-014 · 2026-07-04 · raised-by: Architect · owner: Strategist · re: roadmap scope — height-dependent air-normal advantage mechanism
Problem (a scope question I own the *technical* half of but not the *whether/when*):
ratifying JC-A-04 surfaced that `character-a.md` promises air normals' ground advantage is
**height-dependent** ("deep jump-in = very plus, enabling the grounded links … sim truth the
training mode reads out, not a fixed number"), and routes 2 (`j.H , 5M > 623M`) and the
"deep = very +" note lean on it. But **no engine mechanism computes height-dependent
hitstun/advantage** — air-normal hitstun is authored as one flat value (JC-A-04, correctly,
since the `HitBox` schema has no per-height field and the spec locates height-dependence in
*live sim behavior*, not authored data). So today a `j.H` gives a *flat* advantage regardless
of contact height: the grounded links off a jump-in are structurally authored but not yet
height-varying. This is not an authoring gap (JC-A-04 authored the right flat value) and not
a move-format gap I can close by adding a field (height-dependence is a *resolution*
behavior — advantage as a function of the defender's y at contact — not an authored
constant). It is a **P-scope question: is the height-dependent air-advantage mechanism in
P1's done-bar, or deferred?** If in P1, I will spec it (a phase-5 rule: air-normal hitstun/
advantage scales with contact height, surfaced live through the inspection seam — a real
combat-resolution design and its own engine ticket, sibling to TKT-P1-11's invuln work). If
deferred, `character-a.md`'s "height-dependent" language and route 2's "deep = very +" should
be marked provisional/deferred so QA does not audit A against a mechanism the slice doesn't
yet build (criterion 10's "deals damage in the stated ballpark" is unaffected; only the
*height-varying* clause is). Raising rather than deciding scope myself, per the session's
instruction (scope/whether-a-mechanic-is-in-P1 is the Strategist's). The invuln and
command-schema flags this session are unaffected — this is a separate, narrower question that
JC-A-04's ratification made visible.
---
Resolution (owner fills): …
---

_No other open flags._
