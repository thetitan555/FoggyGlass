# Brief — 1v1 Match Flow (the match layer)

> Owned by the **Strategist**. A brief states **intent and constraints, not
> implementation**. This says *what the match layer is for* and *within what
> bounds*; the Architect owns the state machine, the serialization shape, exact
> health/timer numbers, and how it wraps the sim. Raise anything faulty rather
> than building around it.
>
> Roadmap phase: **P2**, alongside character B. This is the smaller of P2's two
> features — the game loop, not new combat. It closes the roadmap's open question
> on match rules.

## The problem it solves — for the charter

Everything so far hits a dummy. The match layer is what turns the slice from a
tech demo into a **game you can win or lose** — the loop that gives every read
stakes. It's also half of P2's done-condition: *"A vs B is playable start to
finish under the deterministic sim."* Without it there's no "start to finish."

Its charter job is small but real: **the match must be as legible as the combat.**
You always know your health, the round count, the clock — and, when a round or the
match ends, you can always read *why* it ended (KO vs timeout vs double-KO). "Find
out what happened and why" doesn't stop at the frame data; it covers the whole
result.

## Who it's for

- **The player**, who now plays *for* something — a best-of match against a real
  opponent, where the neutral, the reads, and the combos finally carry
  consequence.
- **The team**, because a full match wrapping the sim is the proof that the
  determinism tenet holds not just per-frame but **per-match**: the same input
  stream reproduces the same match, KO, and timeout — which is what keeps replays
  and netcode open for whole matches, not just rounds.

## What success feels like

- You win a razor-close round on a **timeout** with a sliver of health, and it's
  immediately, unambiguously readable that *that's* why you won.
- A clean **double-KO** resolves in a way nobody has to look up — the result is
  legible on its face.
- A best-of-3 goes to a **final round**, and the round pips make the stakes
  glanceable without a thought.
- At no point do you wonder what the match state is or why the last round went the
  way it did.

## What's in scope — and what is pointedly not

**In scope (the match layer):**

- Per-player **health** and KO detection (health → 0 ends the round).
- The **round/match state machine**: round start (both characters reset to
  starting positions and full health), active play, round-end resolution, match-end
  resolution.
- A **round timer** and its timeout resolution.
- **Win conditions** and round/match scoring (below).
- The **legible readout** of all of the above (health bars, round pips, clock, and
  a clear end-of-round/end-of-match result state).

**Explicitly not in scope** (flag it if it creeps in):

- **No new combat.** No meter, super, or any mechanic not already in a character
  brief. The match layer wraps combat; it doesn't add to it.
- **No presentation polish.** Round intros, win poses, announcer, transitions —
  the roadmap defers presentation. The match layer needs a *functional, readable*
  state flow, not a produced one. A plain, honest readout clears the bar.
- **No character select.** The slice's matchup is fixed A vs B; a select screen is
  post-slice. (If a trivial side-assignment is needed, that's the Architect's
  call — not a feature here.)

## The match rules (defaults — adjust any)

Conventional best-of, so nothing here is a surprise to a veteran:

- **Rounds:** best-of-3 — first to **2 round wins** takes the match.
- **Timer:** ~**99 in-game seconds**, frame-counted (see the tenet note — *not*
  wall-clock). Timeout resolves to **higher current health wins the round**.
- **Health:** a single conventional total, **tuned by the Architect against the
  characters' damage numbers** (health lives with the match layer, but its *value*
  is a balance call that belongs where damage is set). Default target: combos and
  reads matter — a couple of good touches decide a round, not thirty pokes.
- **Ties:** double-KO and equal-health timeout **award the round to both players**
  (conventional). *The one genuinely arbitrary call:* if that pushes both to the
  match-win threshold at once, default is a single **sudden-death final round**.
  Confirm, or say if you'd rather a tie round simply **replay with no score** (no
  draws) — cleaner, slightly less conventional.

These are direction, not spec; the Architect owns the numbers and may flag any back
if they fight the characters.

## The constraint this brief exists to protect (Tenet 1)

**The match state is game state.** Health, round wins, the timer, and any RNG are
part of the serialized simulation and advance on the fixed timestep — *exactly* the
same determinism and serialization bar as a single frame of combat. This is
load-bearing and easy to get wrong: a match timer is a classic place someone
reaches for wall-clock or `_process`. Don't. A whole match must **serialize,
restore, and re-run identically** from the same input stream, or the tenet's
per-match promise (replays/rollback of full matches) is quietly broken. The
Architect owns *how*; QA verifies it with the existing determinism/serialization
harness, extended to match boundaries. If satisfying this looks impossible within
the match layer as scoped, that's a flag, not a workaround.

Corollary (Tenet 2): the match layer is **input-source-agnostic.** It wraps two
per-frame input streams and neither knows nor cares whether they come from two
humans, a human vs the record/playback dummy, or a CPU later. It consumes the same
one abstraction everything else does.

## Legibility & the human-inspection gate

P2 carries the human-inspection gate (roadmap), and the match layer is squarely an
**experiential surface**: health, pips, clock, and result are things a human must
*see and read correctly* to confirm. QA's headless audit (state transitions,
determinism, correct win resolution) is necessary but **not sufficient** — the
user's play/look gate clears last, specifically checking that match state and
*why a round/match ended* are legible on screen. Audit criterion mechanics as
usual.

## What it trades against

- **It's cheap engineering but real legibility work.** The state machine is small;
  making the result *always readable* (especially timeout and double-KO) is where
  the actual care goes. Underinvest there and the charter promise breaks at the
  most emotionally loaded moment — the one where you just lost.
- **The determinism bar adds a serialization surface.** Wrapping the sim in match
  state is one more thing that must round-trip. That's cost paid on purpose — it's
  the per-match proof P2 is *for*.

## Open questions (route as noted)

- **Tie-at-match-point rule** (mine — sudden-death vs no-score replay) — I've
  defaulted to sudden-death; say which you want. The only rule here without an
  obvious conventional answer.
- **Exact health/timer values and the round/match state machine shape**
  (Architect) — yours to spec and tune. The brief fixes the loop and the tenet
  bar, not the numbers.
- **Health tuning depends on B's damage**, which depends on B's spec — so match
  tuning naturally lands *after* B's moveset is specced, even though the match
  layer's structure can be built alongside it. Sequencing is the Architect's call.
