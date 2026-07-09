# Pipeline Analysis — how "done" character A shipped unplayable

> Authored by the **Strategist** (owns pipeline health). Written after the P1.1
> human-inspection gate, run twice by the user (2026-07-08), found that character
> A — audited "done" at P1 on 24 green headless tests — could not walk-and-stop,
> could not crouch, had no directional or diagonal jumps, and rendered its boxes
> with an inverted Y axis. This is a process retrospective, not a bug report; the
> bugs are catalogued in `briefs/character-a-movement-reconciliation.md`. The
> question here is *why the pipeline let a materially incomplete character pass as
> done*, and what structurally prevents a repeat.

## The failure, stated plainly

Character A cleared P1's audit and was called done. It was not a playable
character. Its walk had no exit (held direction never returned to idle), it had
no crouch stance, it had no forward/back/diagonal jumps, and the one surface the
whole slice exists to provide — legible geometry — was drawn upside-down. None of
this was caught by the pipeline's own machinery. All of it was caught the moment a
human first pressed a key.

That gap between "passed every check" and "obviously broken on first human
contact" is the thing worth understanding. It is not a QA mistake or a Developer
mistake — every role did its job as the pipeline defined the job. The defect is in
how the pipeline defined "done."

## The design elements that produced it

**1. Every verification is a presence-check, never an absence-check.** Headless
tests inject an input and assert a specific output; QA's objective audit confirms
that implemented behavior is *correct*. Nothing in the pipeline enumerates the
*intended* behaviors and checks each is present. A missing crouch produces no
failing test, because no one writes a test for a behavior no one built — absence
leaves no artifact and is invisible to presence-based verification. Coverage was
implicitly defined as "what someone thought to assert," and no one thought to
assert "hold 6, release, return to idle" or "hold 2, crouch." You cannot catch an
omission with a suite that only ever confirms the presence of what's there.

**2. "Done" was defined as mechanically checkable, which structurally excludes the
dimensions that failed.** Done = "clears audit against acceptance criteria," and
acceptance criteria are, by construction, checkable statements about implemented
behavior. Completeness-against-intent and experiential correctness aren't cleanly
mechanical — so they were never criteria, so they were never gated. The pipeline
optimized for what it could verify and was blind, by definition, to what it
couldn't. Rendering is the sharpest case: box geometry on screen is only
confirmable by human eyes (the tests check draw-list *numbers*, not pixels), so the
Y-inversion had **zero** verification of any kind in P1.

**3. Nothing drove the artifact as a whole, as a human, before it was done.** The
first human input ever to pass through character A was the P1.1 gate — the training
mode wasn't even operable by a human until P1.1 (its own separate finding). An
entire character was authored, tested, and audited without a single key-press
running through it. There was no step in the definition of done that required
*using* the thing.

**4. Memory-less, per-ticket decomposition fragments the whole and leaves the
seams unowned.** Character A was assembled across many isolated, memory-less
ticket-sessions, each locally complete and locally green. No session ever held the
question "is character A, whole, a playable character against its brief?"
Completeness lives at the seams between tickets, and no role owns the seam. This is
the shadow side of the per-ticket dispatch discipline the token economy (rightly)
adopted: it caps blast radius, but it also means no one holds the integration view
unless the pipeline explicitly assigns it. Even the drift-control artifact is blind
here — the judgment-log records *decisions made* (latitude), never *requirements
unmet* (omissions). Our one anti-drift ledger cannot see an absence.

## What this session already fixed, and how well

The **human-inspection gate** added this session (a definition-of-done change:
experiential features aren't done until the user operates them — `audit-criterion.md`,
`protocol.md`) directly addresses elements **2 and 3**: it puts a human-driven,
experiential check into the definition of done, and it gives rendering its first
real gate. And it *works* — it caught every one of these defects across two runs,
exactly the class of thing headless verification structurally cannot see. Adopting
it was the correct response to the first overlay review, and this episode is strong
evidence for it.

But note precisely *how* it caught them: **opportunistically.** The user happened
to try to walk, happened to try to crouch. A human gate catches what the human
thinks to try; it is not a guarantee of coverage. It does not, on its own, close
elements **1 and 4** — presence-vs-coverage and the unowned integration seam. If
the user hadn't thought to test crouch, crouch would still be broken and P1.1 would
still read "done." We got a systematic failure caught by an unsystematic gate. That
worked twice; it is not a guarantee.

## Candidate improvements (proposals — the user's call, not adopted here)

Aimed at elements 1 and 4, the ones still open. Offered for deliberate decision,
not applied unilaterally — a new gate is a real cost and shouldn't be bolted on in
passing.

- **Make the human-inspection gate's checklist derive from the brief, not from
  whatever the operator improvises.** The brief already enumerates the intended
  surface (character A's movement list is right there). If the gate's checklist is
  *generated from that list*, the human drives a coverage of intended behavior
  rather than a spot-check of remembered behavior. This is the cheapest fix and it
  upgrades the gate we already have from opportunistic to systematic — turning the
  brief into the coverage oracle.

- **Add a coverage/completeness checkpoint before "done."** One explicit step that
  walks the brief's named elements and asserts each is built *and reachable* —
  converting absence-checking from an accident into a required pass. Candidate
  owner: the Architect (who already reconciles spec against intent) or a dedicated
  QA coverage pass. This is the direct structural answer to element 1.

- **Assign the integration/"whole-artifact" view to one owner per feature.** A
  single pass that holds the assembled feature as a whole and drives it against its
  brief, distinct from per-ticket verification — so the seams between tickets have
  an owner. This is the structural answer to element 4, and it pairs naturally with
  the brief-derived gate checklist above.

## The one-sentence version

The pipeline rigorously verified that **what was built was correct**, and had no
mechanism to verify that **what was intended was built** or that **the result was
usable** — so a character missing half its movement, rendered upside-down, passed
every check it was ever given; the human-inspection gate we just added is the right
first fix but catches by luck what a brief-derived checklist would catch by design.
