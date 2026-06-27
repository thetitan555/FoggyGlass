# Flag Ledger

> Any role appends; the **owner** of the flagged artifact resolves. Append-only —
> resolved entries stay as a record. Mechanism: raiser pushes + tells the user;
> user relays to the owner; owner writes the resolution line, flips `[open]` to
> `[resolved]`, pushes; user relays back. See `protocol.md` → "How a flag works."

---

### [resolved] 2026-06-27 · raised-by: Architect · owner: Strategist · re: /docs/protocol.md
Problem: the protocol says game code lives in the engine project tree, "path is
the Architect's call; recorded here once set." I've set it: **`/game`** at repo
root (recorded canonically in `/docs/spec/decisions.md`, AD-013). The protocol's
"Where things live" note should mirror this so the path is discoverable from the
protocol, not only the decision record. Low-stakes — a documentation mirror, not
a design change.
---
Resolution (Strategist): Agreed — fixed, not a design change. `/game` is the
Architect's call to make (the protocol explicitly leaves the engine path to
them). Mirrored `/game` into the protocol's "Where things live" prose and the
artifact table so the path is discoverable from the protocol, with AD-013 as the
canonical source. No further action.
---

### [open] 2026-06-27 · raised-by: Consultant (via user) · owner: Architect · re: combat-resolution.md (advantage, AD-008)
Problem: The canonical advantage (`defender_remaining_stun − attacker_remaining_recovery`) is computed per-tick but no reference frame is pinned, so there is no defined "the" on-hit/on-block number for content or UI to read; and `attacker_remaining_recovery` is taken from the current move-state's recovery, which is incorrect once cancels let the attacker become actionable early — making the surfaced advantage misleading in exactly the pressure/combo cases the legibility goal most depends on.
Context caveat: raised from chat; owner, confirm against live project state before acting.
---
Resolution (owner fills): …
---

### [open] 2026-06-27 · raised-by: Consultant (via user) · owner: Architect · re: combat-resolution.md (AD-009/AD-010) + move-format.md (cancels)
Problem: The phase order and hitstop rule don't state whether the state-machine/cancel phase (phase 2) processes cancels while a character is frozen in hitstop, nor whether the one-frame path from hit-confirm (cancel_tags granted in phase 5) to cancel-availability (consumed in phase 2 next tick) is intentional. Both are unstated, feel-defining decisions. Relatedly, `cancels` is a single field carrying gatling/special/whiff/rehit semantics with no model spelled out.
Context caveat: raised from chat; owner, confirm against live project state before acting.
---
Resolution (owner fills): …
---

### [open] 2026-06-27 · raised-by: Consultant (via user) · owner: Architect · re: decisions.md AD-004 (+ simulation.md)
Problem: AD-004 permits in-place mutation of SimState and rejects copy-per-step as "needless allocation pressure," but at slice scale (single machine, 60Hz, two characters) that pressure is likely negligible, while mutability makes the purity contract enforceable only by discipline and leaves purity bugs detectable only when a golden/determinism test happens to hit the offending path — trading away the verifiability the slice exists to prove. Worth re-justifying mutability against this scale and Tenet 3.
Context caveat: raised from chat; owner, confirm against live project state before acting.
---
Resolution (owner fills): …
---

### [open] 2026-06-27 · raised-by: Consultant (via user) · owner: Architect · re: move-format.md + combat-resolution.md (phase 5)
Problem: Hit resolution defines single-hit integrity via `id_group` but specifies no rehit model for intended multi-hit moves (cadenced or sequential hits) and no resolution path for throws (blockstun bypass, tech window, throw-vs-throw, air throw) beyond `throwboxes`/`invuln` existing — so the contract has no answer for two common move classes. Needs either a model or an explicit "deferred."
Context caveat: raised from chat; owner, confirm against live project state before acting.
---
Resolution (owner fills): …