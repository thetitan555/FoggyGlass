# Flag Ledger

> Open flags only (plus resolved-awaiting-relay). Closed entries live in
> `flags-archive.md`. Mechanism, ownership, and relay: `protocol.md` → "How a
> flag works."

---

### [open] 2026-07-17 · raised-by: User (P2 re-gate) · owner: Developer · re: knockdown / `character-b.md` B-1, B-2
Problem: **no knockdown occurs by any means.** B's slide is briefed as causing a
**hard knockdown** and being B's most desirable combo ender (→ oki); at the re-gate
the slide put A into **state 123 (hitstun) only**, and the user could not produce a
knockdown by *any* route. This blocks gate item 9 outright — **B-2 (no unblockable
off the projectile oki) is untestable without a knockdown to set up oki from.**
Severity: this is a briefed, load-bearing mechanic that does not exist in play, and
it passed QA's objective audit.
Diagnosis lead (hypothesis, Developer owns the call): AD-049 folded
`knockdown_state_id` into `REACTION_KNOCKDOWN` resolved through the defender's
`reaction_map`, and AD-049 deliberately includes a resolution **floor**
(`kind → HITSTUN → idle_state_id`) so a content hole cannot reproduce the boxless
wedge. A missing/mis-authored `REACTION_KNOCKDOWN` in **A's** `reaction_map`, or a
slide hitbox still naming a non-knockdown kind, would fall through that floor and
present *exactly* as "reads as plain hitstun." If that is the cause, the floor is
**masking** a content hole the static completeness check was supposed to catch first
— which is a finding about AD-049's check, not just this bug. Report that explicitly;
it routes to the Architect.
---
Resolution (owner fills): …

### [open] 2026-07-17 · raised-by: User (P2 re-gate) · owner: Developer · re: AD-043 air-move semantics (`combat-resolution.md` criterion 15)
Problem: **performing an aerial as either character snaps it to the ground** (divekicks
excepted). This is the **exact defect TKT-P2-01 was dispatched to fix** — the roadmap's
P2 opener names it verbatim: *"the P1.1 re-gate found an air normal stops the jump arc
and the character snaps to the floor; carrying fall momentum through an air normal and
easing the descent is exactly this deferred half."* `character-b.md` also requires B's
air normals to **carry the fall**. TKT-P2-01 was reported complete, QA passed criterion
15, and the behaviour is unchanged from the P1.1 re-gate that deferred it into P2.
Determine whether the fix never covered air *normals* (as opposed to jump arcs), or
regressed. This is a P2 acceptance criterion that does not hold.
---
Resolution (owner fills): …

### [open] 2026-07-17 · raised-by: User (P2 re-gate) · owner: Developer · re: AD-046 air-action economy / `briefs/character-a.md`
Problem: **character A can attempt an air dash and a double jump**, which instantly
halt its air momentum. Two defects in one: A should have **neither**, and the thing it
does get is broken.
Air mobility is **B's signature and A's deliberate absence** — `briefs/character-b.md`
is explicit that "A's brief explicitly *reserved* air-mobility complexity for the
contrast," and A's only briefed dash is the **grounded** `66`/`44` (TKT-P2-02, the
"wire existing states to the shared recognizer" call). A having air actions dilutes the
A/B contrast the entire P2 content-seam thesis rests on.
Note the shape: this is the **mirror of AD-049**. There, two characters were coupled
through an id namespace the format never declared; here, the **engine appears to impose
kit on a character its content never authored**. Both are content-seam violations. If
AD-046 genuinely specs the air-action commands as engine-generic rather than
data-gated, that is an **Architect** call — flag it up, don't re-scope it yourself.
---
Resolution (owner fills): …

### [open] 2026-07-17 · raised-by: User (P2 re-gate) · owner: Developer · re: `match-flow.md` (sudden death) criteria 1–8
Problem: **sudden death cannot end the match.** It grants a point to **both** players,
and further wins increment both counts indefinitely — `MATCH_END` is unreachable. The
tie-at-match-point rule is briefed in `briefs/match-flow.md` and specced under AD-048;
this is a state-machine defect against `match-flow.md` criteria 1–8, which QA passed.
Non-blocking observation from the same item, **not** a defect: after the final round the
game shows "match over" and stops until the window is closed. That is acceptable for the
slice (no restart flow is in scope) — see the separate instrument-ergonomics flag below.
---
Resolution (owner fills): …

### [open] 2026-07-17 · raised-by: User (P2 re-gate) · owner: Developer · re: reaction legibility on the instrument
Problem: **the airborne reaction kinds are not tellable apart on the instrument.** B's
`2H` puts A into state 125 then 123; A's `2H` puts B into 325 then 324 — AD-049 is
resolving correctly (that is the fix working), but **every one of them reads as
"hitstun" in the overlay**, because the readout surfaces the *category*
(`CATEGORY_HITSTUN`) rather than the `ReactionKind`. The user could only distinguish
them by reading raw state ids off the screen.
This fails the constraint I set on `briefs/character-b.md` ("What B looks like when it
*receives*"): **`AIR_RESET` / `LAUNCH` / `KNOCKDOWN` must be tellable apart on sight**,
because they demand different responses — juggle incoming, wakeup mixup incoming, or
nothing — in the same airborne moment. With no art or audio, **the instrument is
currently the only channel that can carry this**, so the readout must name the kind.
Distinguishing them by memorising integer state ids is a knowledge check on our own
instrument (`audit-criterion.md`).
Requirement (mine, stated so it isn't re-litigated): surface the **`ReactionKind`** in
the readout. Do **not** add a "you got crossed up"-style answer key — legibility is
bought by transparency, never by answering the question for the player.
---
Resolution (owner fills): …

### [open] 2026-07-17 · raised-by: User (P2 re-gate) · owner: Developer · re: `game/scenes/training_mode.tscn` (HUD, round 2)
Problem: **text still overlaps.** Specifically: the **Live State** lines extend right
past their box and collide with the controls legend; the **dummy-passthrough** and
**match** overlay text collide with the bottom of the controls text. The match result
itself is now legible (that half of the prior fix worked).
Note for the owner, and it is the point of this flag: the previous fix was verified by
loading the `.tscn` and asserting that no two `Control.rect`s overlap. **That measured
boxes as a proxy for text**, and text overflows its box — which is precisely the failure
`audit-criterion.md` → "Exercise the thing, not a proxy for it" now names. Verify
**rendered text extents**, not rects, or say plainly that you cannot and route it to the
gate.
---
Resolution (owner fills): …

### [open] 2026-07-17 · raised-by: User (P2 re-gate) · owner: Developer · re: throw hitbox geometry
Problem: **the grab hitbox is comically large** — the user's estimate is that it should
be roughly **a tenth** of its current size. Positive confirmation from the same item, to
keep: **the throw correctly beats a downback hold** (AD-016/029 model working as
intended).
---
Resolution (owner fills): …

### [open] 2026-07-17 · raised-by: Strategist (from user re-gate) · owner: Architect · re: divekick active/recovery semantics (`character-b.md`, JC-095)
Problem: the user's re-gate settles the JC-095 divekick tuning with a call that is
**mechanical, not numeric**, so it needs speccing rather than a Developer tuning pass:
**the divekicks should remain active until they reach the ground, and their ground
recovery should equal their blockstun.**
Why I'm routing this as a contract change and endorsing it rather than passing it
through as a number: the two clauses together generate **height-dependent block
advantage as an emergent property** — hit low and you land almost immediately, so
recovery ≈ blockstun ≈ neutral; hit high and you must still fall the remaining distance
while their blockstun ticks out, so you land deeply negative. That is the *same* shape
as B-1's spacing-dependent slide advantage, which the brief already calls cherished
friction **on the condition that it is observable** — and here the causal variable
(how high you hit) is the most visible thing on screen. It is a better mechanic than a
flat number, and it is not a Developer latitude call.
Constraint carried from the brief: whatever you spec must keep the three divekicks'
**trajectories legibly distinct** (B-3) and keep **H the sole overhead** (B-4).
---
Resolution (owner fills): …

### [open] 2026-07-17 · raised-by: Strategist (from user re-gate) · owner: Developer · re: JC-095 provisional tuning — settled
Problem: the user's re-gate settles the remaining JC-095 numbers. These are **direction,
now recorded** (protocol: a steer in chat is provisional until the owning artifact
records it) — apply them as tuning, and flag back only if one conflicts with a
legibility invariant rather than quietly splitting the difference:
- **B's `H` projectile** — travel distance a little **lower**.
- **B's `L` projectile** — should travel **much higher** before coming down.
- **The slides** — their distances should vary **much more** between strengths.
- **The `L` and `M` divekicks** — should travel **more horizontally**, to read as
  distinct from `H`'s near-vertical plummet (B-3). `H` and the hang profiles are fine.
- **`6H`** — 23f startup and a high hit both read correctly; the user's improvement:
  it **could move forward slightly during startup** to make the overhead tell clearer.
Judged and passing, recorded so they aren't re-opened: the three divekicks' guard
heights (`j.2H` HIGH, `j.2L`/`j.2M` MID) are **fine**; the slide's spacing-dependent
advantage is **still good** (B-1 holding, second confirmation); `2L`/`2M` **enforce
LOW** (AD-045 working).
See the separate Architect flag above for the divekick active/recovery **mechanic** —
do not implement that half from this entry.
---
Resolution (owner fills): …

### [open] 2026-07-17 · raised-by: Strategist (from user re-gate) · owner: Developer · re: B-5 facing readout
Problem: the user asks whether it is intended that an airdash crossup shows **nothing
special in the overlay**. **Answered on `briefs/character-b.md`** (new section, "What
B-5 actually requires") — read it; the short version is that no crossup *indicator* is
intended or wanted (it would answer the read the option exists to pose), but B-5 still
requires the **side be discoverable after the fact**.
The concrete question for you: **is facing / blocking-side exposed in `PlayerView` and
shown in the training-mode readouts?** If yes, B-5 is met and this closes as "intended,
already satisfied." If no, expose it as ordinary state alongside advantage and stun —
not as a crossup callout.
---
Resolution (owner fills): …

### [open] 2026-07-17 · raised-by: Strategist · owner: Developer · re: instrument ergonomics — match reset
Problem: at match end the game stops until the window is closed, and `R` (`do_reset`) is
a **no-op in match mode** (JC-098). Correct as specced, but it means **every re-gate
costs the user a full app relaunch per match** — and the user has now gated this project
six-plus times.
This is tax on our own process, not on the player: the instrument is the surface we
audit *through* (`roadmap.md` P1.1), and the charter's legibility promise is not served
by a gate that is expensive to run. Bind `R` to restart the match in match mode (or say
why that is more than it looks and I'll drop it). **Low priority — do not let this
displace the correctness flags above.**
---
Resolution (owner fills): …
