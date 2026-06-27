# Brief — Debug / Technical Training Mode

> Owned by the **Strategist**. A brief states **intent and constraints, not
> implementation** — it is the Architect's raw material, not a spec. The
> Architect decides *how*; this says *what for*, *for whom*, and *within what
> bounds*. Raise anything here that's faulty or under-specified rather than
> building around it.
>
> Roadmap phase: **P1.** Depends on the P0 backbone (the read-only inspection
> surface into sim state, and at least one character to observe).

## The problem it solves — for the charter

The charter's promise is **legibility**: "you can find out what happened and why,
every time." This mode is that promise in its most literal, technical form. When
a player can't tell why a combo dropped, why a button was punishable, whether a
blockstring had a gap, or what state the opponent was in — this is where they go
to get the ground truth, frame-accurate and unambiguous, without leaving the game
for an external frame-data resource or a wiki.

It also doubles as the **team's instrumentation.** It is the shared window into
sim state that the Developer builds against, QA verifies through, and the
Architect specs around. That dual role is why it comes first among features: the
rest of the slice is easier to build and audit once we can *see* what the
simulation is doing. It reads the inspection surface the tenets already require —
it is largely a *reading* of capabilities the architecture must expose anyway,
not a new system bolted on.

## Who it's for

- **The technically-engaged player** — the veteran reading the system fast, and
  the learner moving from "I need to be good enough to play this" to "I'm
  exploring the play space." Both need the same thing: the truth about what just
  happened, on demand.
- **The team** — Developer, QA, Architect — as instrumentation into the sim.

These audiences want the same data; the mode serves both by telling the truth
about the simulation clearly.

## What success feels like

You do something you don't understand, you come here, and the mode *tells you*:

- You drop a link and don't know why → you step the match forward one frame at a
  time and see you were a frame early.
- A move felt unsafe → the advantage readout confirms it's minus on block and you
  can see the punish window that opens.
- You're not sure your blockstring is a true string → you can see the exact frame
  gap and whether a reversal window existed in it.
- You want to drill a punish → you record the opponent's sequence, play it back
  identically, and practice against the same look every time.
- You want to retry instantly → you reset to a known situation without replaying
  the whole sequence.

The throughline: **the friction of *not knowing what happened* is gone; the
friction of mastery stays.** The hard combo is still hard — landing it is still
on you. The mode never makes execution easier; it makes the *truth* accessible.

## Required outcomes (what it must surface — not how)

Stated as intent. The Architect owns the mechanism, the data format, and the UI.

- **Frame data of moves in play:** startup / active / recovery, and advantage on
  hit and on block.
- **Advantage state:** who is plus or minus after an interaction, by how many
  frames, and when neutral is restored.
- **Hitbox / hurtbox / collision geometry**, visualized against the action.
- **Each character's current state:** which state-machine state, and the frame
  within it.
- **Hitstop and stun**, made visible as they happen.
- **Input display / history:** what the input layer actually received per frame —
  the single input representation surfaced directly (Tenet 2), so input is never
  the hidden variable.
- **Damage and combo accounting:** hits, damage, and any scaling, as they apply.
- **Frame control of the match:** pause, advance one fixed step at a time, and
  inspect state at each step — leaning on the deterministic, serializable sim
  (Tenet 1), which makes frame-stepping and exact-state inspection clean rather
  than bolted-on.
- **Situation reset / restore:** return to a known state instantly for repeated
  reps — again leveraging serializable state (Tenet 1).
- **A record/playback dummy:** capture a sequence and replay it identically. This
  is an **input source writing and replaying a buffer** (Tenet 2), not a special
  case and not an AI — keep it that way.

## Constraints and boundaries

- **Stay within the tenets.** Frame-step, reset/restore, and record/playback are
  expressions of determinism + serializable state + the single input abstraction.
  If a desired capability seems to need anything outside those, that's a flag to
  raise, not a workaround.
- **Bound the scope to a legibility instrument, not a shipped training suite.**
  In scope for the slice: the readouts and controls above, against the two slice
  characters. Out of scope (flag if it creeps in): combo-trial/challenge systems,
  multi-slot recording libraries, dummy *behavior AI* (the dummy is scripted
  input, nothing more), and frame-data UI polish beyond legibility.
- **The dummy is not a CPU opponent.** No behavior system, no AI. Any "reaction"
  (block, reversal-on-wakeup, etc.) the slice needs is expressed as scripted /
  recorded input through the one input interface.

## A clarity-principle call I'm making (Strategist position, not deferred)

There is a real tension with the principle *clarity is craft, not data* — that
principle says information should live in the game's visual language, with the HUD
used only when it must. **This mode is the deliberate exception, and that's
intended.** It is the *technical truth layer*: dense, explicit, numeric readouts
are appropriate and expected here precisely because this is the diagnostic
instrument, not the shipped in-match experience. The debug mode existing does
**not** relax the obligation, elsewhere, to teach through the game's visual
language in normal play — if anything it sets the ground truth that the in-match
art is later judged against. I'm ruling this intended so no one downstream treats
the data-density here as a principle violation, and so no one uses "training mode
shows it" as an excuse to skip in-match legibility. If you disagree with this
call, it's mine to revisit — raise it.

## Open questions (for the Architect; some route back to me)

- **Core vs. deferred readouts:** the list above is my proposed core. If any item
  is materially harder than the rest and would stretch the slice, flag it and
  I'll make the cut — better to ship a smaller honest instrument than a late one.
- **Exactly what the training mode must expose** is the operational form of the
  charter's legibility promise, so getting the core set right matters more than
  breadth. If you find a readout the slice's *systems* can't yet support, that's a
  P0/seam question, not a reason to fake it.
- **Shared surface with QA:** the mode and the determinism / golden-file harness
  should read the *same* inspection surface so they can't disagree about sim
  truth. The interface is the Architect's to define; this brief just asserts they
  must not diverge.
- **Reset granularity:** how rich "restore to a situation" needs to be for the
  slice (single quick-reset vs. saved situations) — your call on cost; default to
  the minimum that makes reps fast.
