# Flag Ledger

> Open flags only (plus resolved-awaiting-relay). Closed entries live in
> `flags-archive.md`. Mechanism, ownership, and relay: `protocol.md` → "How a
> flag works."

---

### [open] 2026-07-17 · raised-by: User (P2 3rd gate) · owner: Architect · re: facing never flips — a foundational sim gap
Problem: **a character's `facing` never changes after match init.** The user jumped one
character over the other and facing stayed default; it never flips in play. Diagnosed by
the Strategist before routing (`game/sim/*.gd` grep): `facing` is assigned **only** at
init (`sim_state.gd:95/101`, `match_state.gd:159/167`) and in serialization round-trip
(`player_state.gd`, `projectile.gd`) — **nothing in the sim updates it based on relative
position.** So P1 permanently faces right and P2 permanently faces left, whoever is on
which side. My B-5 facing readout (just shipped) is faithfully reporting a value that
genuinely never moves — the readout is correct; the sim is the gap.
Why this routes to the Architect, not straight to the Developer: this is load-bearing far
beyond a readout — `facing` resolves motion inputs to forward/back (`input_buffer.gd`),
decides crossup block direction, and mirrors box geometry. A character whose facing is
wrong after a crossup blocks the wrong way and reads motions backwards. And **when** facing
should flip is a genuine design decision with legibility stakes (only while grounded? only
while actionable? never mid-move? at the apex of a jump-over?) — an ambiguous auto-facing
rule creates exactly the unreadable crossup states the charter's no-knowledge-checks line
warns against. That's a spec/contract call (combat-resolution), not implementation
latitude. **Same class as AD-049:** a foundational behaviour never exercised because no
test or prior gate ever crossed two characters over. Spec the auto-facing rule (an AD),
then it decomposes to a Developer ticket. This is not a quick tuning fix.
---
Resolution (owner fills): …

### [open] 2026-07-17 · raised-by: User (P2 3rd gate) · owner: Strategist · re: air-reset semantics contradict the brief (air tech / air-to-air)
Problem: **air-to-air hit makes the victim snap to the ground, and no air tech is
possible.** The user tried to air-recover from an air-to-air hit and couldn't; the victim
snaps down instead of a recoverable neutral fall.
This is a **brief-vs-spec conflict that is mine to resolve first**, which is why I own it
rather than the Developer. `briefs/character-b.md` ("What B looks like when it *receives*")
says `AIR_RESET` is a **"neutral fall, B recovers, nothing follows."** But JC-102
(Developer-authored, **Architect-ratified** 2026-07-17) built B's air-reset as
`CATEGORY_HITSTUN` that **converges into knockdown on landing**, same as a launch. "Lands
into a knockdown" is not "recovers, nothing follows" — the implementation contradicts the
brief's own words, and the ratification missed it for the AD-049 reason: air-reset was
never inflicted in a real match until this gate, so the conflict never surfaced.
What I owe before this can move: **clarify the brief** — what does "B recovers, nothing
follows" mean mechanically? Does the victim become actionable *in the air* (a true air
tech/recovery the player performs), or land neutral-and-actionable rather than knocked
down? Is air-teching a mechanic this slice has at all, or is the intended reading simply
"a soft, non-knockdown landing"? Once I pin that, it flags to the **Architect** (JC-102 /
the air-reset landing precedence in AD-043/`combat-resolution.md` likely need revising —
an *upstream correction of a ratified call*, correctly the Architect's to make, not a
patch), then to the Developer. **Deferred to a fresh session** — this is a design decision
that deserves a clear head, not the tail of a long one.
---
Resolution (owner fills): …

### [open] 2026-07-17 · raised-by: User (P2 3rd gate) · owner: Developer · re: B's double jump snaps to ground at the apex (airborne physics)
Problem: **B's double jump causes a ground snap at the apex of the jump** instead of a
second upward impulse. (A correctly has neither air action now; this is B's authored
double jump misbehaving.) Confirmed by the Strategist that the code path *exists* and looks
plausible — `_apply_air_action` (`step_phases.gd:459-463`) recognizes the UP-edge and sets
`vel_y = -double_jump_velocity` for a `was_airborne` player with `air_action_used` false —
so this is a **behavioural bug needing empirical reproduction**, not an obvious static
error. Suspects worth checking: the up-edge recognition vs. a still-held jump input; the
`was_airborne`/ground-clamp interaction at apex (`vel_y ≈ 0`); interaction with the
air-normal safety-tail duration fix from this cycle.
**Sequencing note (Strategist):** do NOT dispatch this alone. It shares the airborne-physics
subsystem with the air-reset-snap defect above (which is deferred pending my brief
clarification), so both should be diagnosed in **one** airborne-physics Developer session in
the fresh cycle — paying that subsystem's cold-start read once, not twice. Held for the
fresh session with the air-reset design decision, not this pass.
---
Resolution (owner fills): …

