# Audit Criterion

> Owned by the **Strategist**: the charter made operational — the standard QA
> checks every change against. **I own *what* this tests for; QA owns *how* it's
> performed.** If the criterion itself is unworkable or a boundary is wrong,
> that's a flag to me — QA doesn't quietly reinterpret it. Read alongside
> `charter.md` and `principles.md`; this is their enforcement edge.

## The one test

For any change, ask both halves and require both:

1. **Does it keep the game legible?** Can the player find out what happened and
   why — during the moment or after it — every time?
2. **Did it dumb anything down to get there?** Legibility is bought by making the
   game *transparent*, never by making it *easier*, shallower, or lower-ceiling.

A change passes only if legibility held **and** nothing was flattened to buy it.
A clear-but-shallower change fails half 2. A deep-but-opaque change fails half 1.
The charter wants both axes high at once; so does this test.

## The dividing line: cherished friction vs. tax

Friction is not the enemy — *the wrong* friction is. The charter is explicit
about which is which.

- **Cherished friction — keep it. It *is* the play space:** a hard combo, a
  one-frame link, a lost read, a tight punish window, a long grind toward
  mastery. Difficulty of *execution* and difficulty of *reading the situation
  live* are the game. Removing them dumbs the game down (fails half 2).
- **Tax — remove it. It stands *between* the player and the play space:**
  opacity (you can't tell what happened), feedback that doesn't tell you what
  happened, clunky UX, dropped/eaten inputs, and **knowledge checks** — losing
  because you didn't *already know*, rather than because you didn't *read or
  execute* in the moment.

The test that separates them: **is the player paying this friction to engage the
game, or to reach it?** Cost paid playing the game is cherished. Cost paid
getting to the game is tax.

## The knowledge-check line (from `principles.md`)

The single sharpest distinction, because it's the easiest to get wrong:

- **Cherished:** *"I can see what to do and have to read or execute it live."*
  A character may carry a whole library of strong, distinct options — that's good
  design — **as long as the correct response is readable as it happens.**
- **Tax:** *"I lost because I didn't already know."* The answer was gated behind
  prior metagame knowledge, not discoverable in the moment.

Note the scope limit the principle sets: high-level *matchup strategy* is
emergent and metagame-dependent — we neither design nor test against it. The
audit tests the **in-the-moment legibility of each option**, not whether a
player has theory-crafted the matchup.

## The legibility backstop

Some things are correctly unreactable live — a true 50/50, a fast mixup, a
frame-perfect punish. That is allowed; the read/guess is part of the play space.
The charter's promise is not "always reactable," it's **"always discoverable."**
So the backstop test:

**Even when a player can't respond in time, can they find out — during or after —
what hit them, what their options were, and why it worked?** If yes, the friction
is cherished (a lost read). If they can't even discover what happened, it's tax
(opacity). The debug/technical training mode and replays are this backstop made
real: they are where "what just happened?" always has an answer.

## The human-inspection gate (experiential surfaces)

Some of what this criterion tests is not confirmable by a headless check. Whether
boxes actually *render*, whether a control is *operable* by a human hand, whether
a readout is legible *on screen* — these are the charter's legibility promise at
the pixel and the input, and no passing test suite proves them. P1 is the
standing lesson: all 24 headless tests were green while the geometry overlay drew
nothing and nothing in the mode was human-operable (`flags.md`, 2026-07-08).
Green tests are necessary and not sufficient.

So: **any change with an experiential surface — anything whose correctness
includes rendering, input-operability, or on-screen legibility a headless check
cannot confirm — carries a human-inspection gate.** QA's objective verdict does
not close it; only the user, having seen and operated the thing, does (the
"play/overlay-look gate" the user already owns — `protocol.md`). Until that gate
clears, the change is *audit-passed, pending human inspection* — never "done."
Ownership stays clean: the Strategist **declares** the gate on the owning brief
or roadmap milestone (it's a direction call), QA **enforces** it (a declared-open
gate blocks a done verdict), and the done-mechanics are `protocol.md`'s. This is
the same automate-the-objective / human-holds-the-experiential shape as the push
gate.

**The gate runs off a brief-derived checklist, not improvisation.** A human gate
otherwise catches only what the human thinks to try. P1.1 is the lesson: character
A's missing walk-stop, crouch, and directional jumps were all *enumerable from its
brief*, yet took two opportunistic re-gates to surface because nothing drove the
brief's named surface as a coverage list (`pipeline-analysis-completeness-gap.md`).
So when the Strategist declares a gate, it **attaches a checklist derived from the
owning brief's enumerated surface** — its movement list, required controls,
legibility readouts — one line per intended behavior. The user drives that list;
QA records each item as a gate open-item and cannot issue *done* while any stands
unchecked. This converts the gate from opportunistic spot-check to systematic
coverage of *intended* behavior — the absence-check the presence-based test suite
structurally can't perform. Free exploration on top is still welcome; the checklist
just guarantees the floor.

## Exercise the thing, not a proxy for it

A check that is **true but doesn't test the claim** is worse than no check, because
it retires the question. This is now the project's most-repeated failure, four times
in three phases, and always the same shape — *we confirmed what we thought to look
at, and the thing itself was never exercised*:

- **P1:** 24/24 headless green while the geometry overlay drew nothing and no
  control was operable. The tests exercised the sim; the claim was about the screen.
- **P1.1:** character A's missing walk-stop, crouch, and directional jumps — all
  enumerable from its brief, none exercised (`pipeline-analysis-completeness-gap.md`).
- **P2:** every cross-character hit was broken while 43/43 passed and QA's grep
  correctly found zero character-specific branches. The suite only ever matched a
  character **against itself**; the grep saw explicit coupling and was structurally
  blind to implicit coupling (AD-049).
- **P2:** ~1s of input lag reached the user, because the harness steps the sim
  directly and **nothing tests the driver that feeds it in the real app.**

So, when a check is claimed to satisfy a criterion, both must hold:

1. **It exercises the real thing along the real path** — not a stand-in, not the
   layer beneath it. A sim test does not prove a driver. A structural grep does not
   prove a behaviour. A mirror matchup does not prove two characters interoperate.
2. **It could fail.** If no realistic defect in the thing under test would turn this
   check red, it is measuring something else. *State what would have failed it.*

QA owns *how* verification is performed and this does not take that back — it's the
bar the how must clear, and it's **mine to state because it's the charter's
discoverability promise turned on our own instruments**: a green check we can't trust
is opacity aimed at the team instead of the player. The human-gate checklist rule
below is this same rule applied to the experiential half; this is its objective twin.
Where a check genuinely cannot exercise the real thing (a Godot layer, a human eye),
the honest move is to **say so and route it to the gate** — never to write the proxy
and let it read as proof.

## Objective vs. subjective (QA's handling, per its role)

- **Objective — QA verifies, pass/fail, owns the call:** Is the information
  actually exposed? Does the inspection surface report what hit, what whiffed,
  advantage, state, inputs, frame data — correctly and consistently? Determinism
  and serialization hold? Every character obeys the one advantage formula and one
  move format? These have right answers; the criterion is satisfied or it isn't.
- **Subjective — QA *surfaces*, does not adjudicate:** Is a thing *clear enough*?
  Is this friction play-space or tax? Is a character's option *readable in the
  moment* or a knowledge check? These are judgments of feel. QA flags candidates
  — changes that *look* like they cross the line — and routes them to the
  Strategist (and through me, the user). QA ruling something "unfun" or "a
  knowledge check" on its own authority is overreach; surfacing it is the job.

## Boundary cases (the part worth sharpening — examples, not an exhaustive list)

- **A 1-frame link that players drop constantly** → *cherished.* Execution
  difficulty is the play space. The fix if any is *legibility* (the training mode
  shows you were a frame early), never making the link easier.
- **A move that's plus on block with no readable sign it's the attacker's turn**
  → *tax.* The advantage is real depth; the *opacity* about it is the defect.
  Resolve by making the turn legible (visual/audio/HUD), not by changing the
  frame data.
- **A character gimmick you can only answer if you've read the wiki** → *tax
  (knowledge check)* — unless the tell is readable in the moment, in which case
  the *same option* is cherished depth. The dividing question is always: could a
  paying-attention player who's never seen it read the answer live?
- **An unreactable 50/50 on knockdown** → *cherished*, provided the situation is
  legible (you can tell you're in a mix and what the options are) and discoverable
  after (training mode shows what hit). An unreactable mix where you can't even
  tell what happened → *tax*.
- **A long, grindy path to mastering a character** → *cherished.* "The work of
  understanding is itself part of the reward" (charter). Length is not a defect;
  opacity along the way is.
- **A menu/netcode-stub/UX papercut, an input that didn't register** → *tax,*
  always. None of it is the play space.

When a case sits genuinely on the line, that's a *surface-to-Strategist*, not a
QA call — and sharpening the boundary afterward is mine.

## How it's applied (cadence, per the protocol)

- **Per change:** every change is checked against this criterion before it's
  "done." Objective failures route to their owner as flags (implementation →
  Developer; spec gap → Architect; intent/criterion → Strategist; charter → user).
- **Cumulative (per milestone):** individual changes can each pass and still add
  up to a game that's drifted opaque or quietly dumbed-down. The drift sweep
  applies this test to the *aggregate*, not just the diff — the failure mode
  per-change checks can't see.

## What this criterion is NOT

- **Not a fun-arbiter.** It does not rule on whether a mechanic is enjoyable;
  that's the user's call, surfaced, never QA's verdict.
- **Not a balance or difficulty standard.** It never argues something is too hard
  or too strong. Hard and strong are fine; *opaque* and *dumbed-down* are not.
- **Not a license to simplify.** "Make it clearer" is the mandate; "make it
  easier" is the thing this test exists to catch and reject.
