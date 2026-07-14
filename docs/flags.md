# Flag Ledger

> Open flags only (plus resolved-awaiting-relay). Closed entries live in
> `flags-archive.md`. Mechanism, ownership, and relay: `protocol.md` → "How a
> flag works."

---

### [open] 2026-07-14 · raised-by: Architect · owner: Strategist · re: /docs/spec/character-b.md + /docs/spec/character-a.md (AD-045)
Problem: Character B's briefed **overhead / high-low mixup** (`6H`, H-divekick, vs. the
lows) is only a *real, readable* mixup if blocking is **directional** — but the P1 slice
deliberately made blocking **stance-agnostic hold-back with no high/low enforcement**
(character-a reconciliation). P2 therefore needs **directional block enforcement**
(AD-045: `HitBox.guard_height` × defender stance; a wrong-stance block resolves as a hit),
which (a) adds a combat-resolution surface the match-flow brief's "no new combat" guard
could be read against, and (b) **changes character A's behavior** — A's `2L`/`2M` become
enforced lows. This is a **scope/direction call** that reverses a recorded slice
simplification and touches an existing character, so it is raised rather than routed
around. I have **specced against "enforcement added"** (recommended: it is required by B's
brief intent and is the charter's readable-mixup thesis made mechanical; the alternative
guts B's high/low classroom to strike/throw-only) so dispatch is not blocked — but the
Strategist owns whether P2 accepts the scope. If accepted, this note is a one-line
confirmation; if not, B's mixup layer narrows and `character-b.md` / AD-045 revise.
---
Resolution (owner fills): …
