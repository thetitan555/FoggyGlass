# Brief — Character A (the baseline shoto)

> Owned by the **Strategist**. A brief states **intent and constraints, not
> implementation** — the Architect owns the spec (frame data, hitboxes, exact
> normal list, damage, properties). This says *what the character is for*, *what
> it must feel like*, and *within what bounds*. Raise anything faulty or
> under-specified rather than building around it.
>
> Roadmap phase: **P1**, alongside the debug/technical training mode. This brief
> closes the roadmap's open question on character A's archetype and resolves the
> Architect's flag re: the missing P1 character brief.

## The problem it solves — for the charter

The slice needs its first real character: the one that proves the move/frame-data
format works on something a person actually plays, and that serves as the
training mode's first *real* test subject (its acceptance criteria — geometry,
real frame data, advantage on real moves, combo accounting — are only meaningful
against a real moveset).

A grounded, simplified shoto is the right choice because it is the most **legible
possible first character**. Its tools — a fireball, an anti-air reversal, a
commitment poke — are universal fighting-game vocabulary, so a veteran reads the
whole gameplan on sight (the charter's "genre knowledge pays off immediately"),
and a learner meets the archetypal first lessons of the genre — neutral,
whiff-punishing, anti-airing, zoning — in their clearest form. It is also the
**baseline the matchup is built on**: character B (P2) will be chosen to contrast
against it, and you can't define a contrast without a clean reference point.

## Who it's for

- **The veteran**, who sits down and instantly knows what to do — and feels the
  system open up under a familiar archetype.
- **The learner**, for whom a shoto is the genre's natural first classroom: every
  core interaction shows up here in its most readable shape.
- **The team**, because this is the moveset the training mode and the
  golden-file/regression nets first prove themselves against.

## What success feels like

The shoto's archetypal moments, each doubling as a legibility lesson:

- You throw a fireball, they jump it, you anti-air with the shoryuken — and if you
  mistime it, the training mode shows you exactly when the anti-air window was.
- You whiff-punish a poke with crouching medium kick into a fireball — a real
  bread-and-butter that feels earned, not handed to you.
- Your reversal gets blocked and you eat a full punish — and you can read, frame
  for frame, how minus you were and what window opened on the opponent.
- A clean confirm into the reversal for the knockdown, then your oki.

The throughline: these are **honest, readable interactions whose outcomes you can
always find out** — the charter's promise, taught through the genre's most
legible character. The execution (DP timing, the link, fireball spacing) stays
real; only the *breadth* is reduced.

## The defining toolkit (identity, not spec)

Stated as identity. The Architect owns every property, number, and frame; this
fixes only *what tools exist and what role each plays*.

- **Buttons: Light, Medium, Heavy** — a three-attack-button character, **no
  punch/kick divide.** (See the cross-cutting note below: this layout is
  slice-wide, not character-A-specific.)
- **Crouching medium kick** — the signature commitment poke; the heart of its
  ground neutral and whiff-punish game.
- **Fireball** — its zoning / neutral-control tool.
- **Shoryuken** — its reversal and anti-air; the high-commitment "get off me"
  button with a real risk/reward.
- **Ground throw** — participating in the system's throw/tech model (the Architect
  already specced tech windows; A uses them, it doesn't define new throw rules).
- **The basics:** walking (forward/back), jumping (neutral/forward/back) with
  jump-in normals, standing and crouching blocking, and an L/M/H normal set on
  stand/crouch/air sufficient for grounded neutral, anti-air, jump-ins, and a
  basic bread-and-butter.

**Discretion calls I'm making (veto any):** I'd give A a simple grounded
forward/back dash for neutral mobility, and **no air dash** — keeping it
grounded and legible, with air-mobility complexity reserved for a later/contrast
character. I'd also keep its identity as a *clean archetypal shoto* with no
signature gimmick for the slice; the novelty budget is better spent on character
B's contrast than on twisting the baseline. Say if you'd rather it carry a hook.

## A charter call: simplified, not dumbed down (Strategist position)

"Simplified shoto" must mean **reduced breadth, never reduced depth, ceiling, or
legibility.** Few moves — but the moves that exist keep a real execution ceiling
(reversal timing, links, fireball/poke spacing, whiff-punish reads) and full
in-the-moment readability. This is the charter line: we cut *surface area*, not
*mastery*. I'm stating it so no one downstream reads "simplified" as license to
flatten the character into a Fantasy-Strike-style autopilot — that would violate
the charter, which this slice exists to honor. If you disagree with where I've
drawn this, it's mine to revisit — raise it.

Per your steer: **don't import UNI conventions reflexively** (e.g. reverse beat).
The character uses only what its identity needs; chain/cancel rules come from the
move format's `CancelRule` model, applied to this character on purpose, not by
genre default.

## What it trades against

- **Content front-loading:** A is the first real moveset, so it's the first
  animation/data/tuning cost in the slice. Mitigated by deliberate leanness — a
  handful of moves, not a full character.
- **It commits the slice to the L/M/H three-button layout** as the input baseline
  (see below) — a system-level consequence of a character-level choice.
- **The simplicity/depth tension** named above: getting "few but deep" right is
  real design work, not a shortcut.

## Open questions (route as noted)

- **The L/M/H three-button layout is slice-wide, not character-A's to own**
  (Architect): A surfaced it, but it belongs in the input contract
  (`input.md` / the generic-button bitfield, AD-002). Please reflect it at the
  system level and confirm the input representation carries exactly these three
  attack buttons for the slice. If that conflicts with anything in the input
  spec, flag it back to me.
- **Exact normal set, and the fireball/reversal/throw properties** (Architect):
  all yours to spec within the identity above. The brief fixes roles, not frames.
- **Does the baseline need any identity hook at all** (back to me if you think
  so): my position is no for the slice — but it's a Strategist call I'll revisit
  if the Architect or you see a reason.
