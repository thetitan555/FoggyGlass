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

### [open] 2026-07-02 · raised-by: Consultant (via user) · owner: Strategist · re: /docs/protocol.md (judgment-call ratification + judgment-log format)
Problem: The QA-gatekeeps proposal would route [impl]-tagged calls away from the Architect, but the current judgment log shows Developers can confidently under-classify contract-touching calls as latitude — JC-007 was tagged by the Developer as "stays a latitude call" and the Architect overrode it into an owned contract (AD-023); JC-002/006/009 were similarly upgraded. Adopting QA-routing now would rest the safety of those calls on a QA gate that has no track record, with zero data on the mislabel rate. Proposed refinement (raise-only; owner decides): before changing any routing or ownership, add a Developer-only classification tag to each judgment-log entry — [impl]/[contract] with an "unsure defaults to [contract]" discipline — that is recorded but acted on by no one. QA and the Architect keep today's ratify-everything flow unchanged; the tag is inert instrumentation whose only job is to accumulate a labelled dataset, so a future QA-verify / Architect-subset process can be replayed against real calls and measured before it is adopted. No role-prompt behavior change beyond the Developer recording the tag.
Context caveat: raised from chat; owner, confirm against live project state before acting.
---
Resolution (owner fills): …

---

### [open] 2026-07-02 · raised-by: Consultant (via user) · owner: Strategist · re: /docs/protocol.md (Token economy — judgment-call review consolidation)
Problem: The proposal's ROI rests on the premise that pure-impl calls are "often the majority," but the only judgment log so far is the P0 backbone, which is contract-dense by nature — the Architect folded roughly 5 of 9 entries (JC-002/003/006/007/009) into spec. P0 lays the foundational primitives, so its impl:contract ratio is not representative of steady-state feature work, and adopting on that basis while paying the four-role-prompt rewrite could be net-negative. Proposed refinement (raise-only; owner decides): before adopting the QA-gatekeeps change, measure the [impl]:[contract] ratio on a non-foundational feature's judgment log (the vestigial tag in the companion flag supplies this data) and treat that ratio — not P0 — as the adoption signal.
Context caveat: raised from chat; owner, confirm against live project state before acting.
---
Resolution (owner fills): …