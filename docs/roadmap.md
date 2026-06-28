# Roadmap — to the Vertical Slice

> Owned by the **Strategist**. The sequence of what gets built and why, anchored
> to the vertical slice. Later (post-slice) work is gestured at, not specified.
> This is direction, not a spec — the Architect turns each phase into briefs →
> spec → tickets. Revise it when reality demands; it's a plan, not a contract.

## What the slice is for

The slice exists to **prove the architecture, not to be the game.** It is "done"
when it demonstrates — runnably — that the three tenets hold and that the systems
they enable (replays, netcode, CPU, scripted tutorials) are *new input sources,
not new systems*. Everything below is sequenced to reach that proof on the
shortest honest path.

Fixed scope (from the constraints, not negotiable here): a playable 1v1 match, a
debug/technical training mode, a two-player tutorial, and — settled this session
— **two lean characters**. Two because one can't prove the data-driven move
format or exercise the systems/content seam, and a real matchup is the only place
"every option is readable as it happens" becomes testable.

Explicitly **not** in the slice: online/netcode (kept *possible* by determinism,
not built), roster breadth beyond two, and presentation polish. Building any of
these now is scope the slice doesn't need — flag it if it creeps in.

## The spine (why the order is the order)

Each phase depends on the one before it through a real interface, so the order
isn't preference — it's the dependency graph:

```
P0 backbone ─▶ P1 char A + debug training ─▶ P2 char B + 1v1 match ─▶ P3 2P tutorial ─▶ P4 harden
```

The load-bearing sequencing fact: the debug training mode and the 2P tutorial
both straddle the **systems/content seam** (systems exposes an inspection API and
a scripted-input mechanism; the player-facing side builds on it). At the seam,
the player-facing half is downstream of the simulation-facing interface — so
those interfaces, even as stubs, come first. The determinism harness comes online
*with* the sim loop, not after, because determinism violations are far cheaper to
catch as the sim is written than to chase later.

## P0 — Architecture backbone

The spine everything hangs on. No content, no feature — just the proof surface.

Built here: the input-source interface and per-frame input type (Tenet 2); the
deterministic sim loop on a fixed timestep with fully serializable state
(Tenet 1); the move/state-machine pattern and the **data-driven, serializable
move/frame-data format**; and core frame resolution — hit/hurtbox overlap,
hitstop, hit/block-stun, advantage — exposed through a **read-only inspection
surface** into sim state, so the debug mode can read it out. QA stands up the
determinism + serialization harness against the loop as it lands.

**Done when:** the sim advances purely from `(state, inputs)`; state round-trips
(serialize → restore → resume identically); the determinism harness is green; and
a trivial test "character" defined entirely in move data resolves a hit with
correct advantage, read back through the inspection surface. *This is the tenet
proof — the rest is building on proven ground.*

## P1 — First character + debug/technical training mode

The first real content and the first feature, together — because the debug mode
is the team's **instrumentation**, and it needs something to observe. This is the
first feature brief (drafted next).

Built here: character A — a thin but combo-capable moveset (movement, a small set
of normals, one or two specials, a throw — enough for neutral, a real combo, and
oki), authored as move data against the P0 format. And the debug/technical
training mode reading the inspection surface: frame data, hitbox/hurtbox display,
advantage on block/hit, hitstop, state — the charter's "find out what happened
and why" made literal. Record/playback dummy is an input source writing and
replaying a buffer (Tenet 2), not a special case.

**Done when:** character A is playable against a dummy; the training mode shows,
live and correctly, what the sim is doing each frame; the record/playback dummy
round-trips a buffer. *The instrumentation the whole team uses now exists.*

## P2 — Second character + playable 1v1 match

Proves the format generalizes and gives us a real matchup and a real game loop.

Built here: character B, a second lean moveset deliberately distinct from A,
authored purely in move data — the test that the format wasn't secretly
A-shaped. And the 1v1 match flow wrapping the sim: health, KO, round/match
state, win condition — the match layer, not new combat.

**Done when:** A vs B is playable start to finish under the deterministic sim;
both characters obey one move format and one advantage computation (QA verifies
cross-system consistency); the golden-file frame-data/hitbox regression net is
seeded now that there are stable characters to snapshot. *The content seam is
proven: a second character was content, not engineering.*

## P3 — Two-player tutorial

The second seam-straddling feature: a scripted-input source plus authored
content.

Built here: a scripted-input source (another implementation of the one input
interface — Tenet 2 again) and the authored tutorial sequence on top of it. Keeps
the charter's "no knowledge checks" honest by teaching in-the-moment legibility
rather than memorized answers.

**Done when:** the tutorial plays a scripted sequence deterministically through
the normal input path, with two players, teaching the systems the slice has.
*Scripted tutorials are proven to be input sources, not bespoke systems.*

## P4 — Harden and audit the slice

Not new features — the proof, made durable.

QA runs the first full **drift sweep** (cumulative behavior vs charter,
spec vs implementation) and the charter audit against the audit criterion; the
golden-file and determinism nets are confirmed as the standing safety net;
recorded judgment calls are ratified into the spec.

**Done when:** the slice passes the audit criterion, the regression/determinism
nets are green and trusted, and no judgment call sits unresolved. *The slice is
not just runnable but defensible — and the architecture is proven extensible.*

## Open questions (resolve before the phase that needs them)

- **Character A archetype** — *resolved:* a grounded, simplified shoto, briefed
  in `/docs/briefs/character-a.md`. **Character B archetype** — open, deferred to
  the P2 brief; it will be chosen to *contrast* A (the split is what tests the
  format and matchup legibility). Exact movesets are the Architect's to spec.
- **Match rules** — rounds, timer, health values: a P2-brief detail, defaulted
  to a conventional best-of for now unless you want otherwise.
- **What the training mode must expose, exactly** — the P1 brief pins this; it's
  the operational form of the charter's legibility promise, so it's worth getting
  right there.

## After the slice (sketch only — not committed)

Beyond the slice, in rough order and explicitly not planned in detail yet: more
characters (now cheap, if the format held), netcode built on the determinism the
slice preserved, CPU opponents as another input source, and presentation polish.
The slice's whole job is to make these *additions* rather than *rewrites*.
