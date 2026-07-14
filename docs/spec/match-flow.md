# Spec — 1v1 Match Flow (the match layer)

> Owned by the **Architect**. Turns `briefs/match-flow.md` into a buildable match
> layer against AD-048. The state machine, serialization shape, and legibility
> readout are contract; exact **health/timer values are slice-provisional** (health
> tuned after B's damage — brief). The determinism/serialization bar (Tenet 1, per
> *match*) is contract, not tuning.
>
> Read with: `simulation.md` (SimState, the hash, the harness), `inspection-surface.md`
> (`MatchView`), and **AD-048**.

## What this is (and is not)

The loop that turns the slice from "hit a dummy" into a game you win or lose. **No
new combat** (brief) — it wraps combat, adds nothing to it: no meter, no super, no
mechanic not already in a character brief. **No presentation polish** (round intros,
win poses, announcer) — a *functional, readable* state flow, not a produced one. **No
character select** — the matchup is fixed A vs B; side assignment is a wiring constant
(AD-048), not a feature.

## The layer (AD-048)

`MatchState` **wraps** `SimState` and is advanced by a pure
`match_step(match_state, in_p1, in_p2) -> MatchState` — **above** combat's `step`,
whose signature is unchanged. Everything the match needs is serialized game state on
the fixed timestep (Tenet 1); a whole match round-trips, restores, and re-runs
identically from the same input stream.

### `MatchState` shape (serialized, cloned, canonically hashed — AD-023 discipline)

| Field | Meaning |
|---|---|
| `sim` | The wrapped `SimState` (carries per-player `health` — combat truth). |
| `round_wins[2]` | Per-player round wins (the pips). |
| `round_timer` | Frames remaining in the round; counts down on the fixed tick. **Frame-counted, never wall-clock** (Tenet 1). |
| `round_index` | Which round (for best-of / sudden-death). |
| `match_phase` | `ROUND_START` / `ACTIVE` / `ROUND_END` / `MATCH_END`. |
| `sudden_death` | Bool — the tie-at-match-point final round is active. |
| `phase_timer` | Deterministic transition counter for the non-`ACTIVE` phases. |
| `last_round_end_reason` | `KO` / `TIMEOUT` / `DOUBLE_KO` — **serialized truth** (so *why* a round ended is legible on its face, not a render inference). |

RNG reuses `SimState.rng` (the slice match needs none; the seed lives in serialized
state per Tenet 1 regardless). The AD-034 format-version stamp extends to the wrapper.

## The round/match state machine

- **`ROUND_START`.** Reset `SimState` to fresh symmetric start positions + **full
  health**; reset `round_timer` to the round length. Run `phase_timer` (a short, fixed
  count — a plain "ready" beat, no produced intro), then → `ACTIVE`.
- **`ACTIVE`.** `match_step` calls `step` (combat advances), then: decrement
  `round_timer`; check KO and timeout; on a round-ending condition set
  `last_round_end_reason`, award round win(s), and → `ROUND_END`.
- **`ROUND_END`.** Run `phase_timer`; if a player (or both, via a tie) has reached the
  match-win threshold → `MATCH_END` (or → `ROUND_START` for a sudden-death round if the
  tie pushed *both* to threshold); else → `ROUND_START` for the next round.
- **`MATCH_END`.** Terminal; the result is readable (who won, and the deciding
  `last_round_end_reason`).

Combat is **not advanced** outside `ACTIVE` (the transition phases run only their
deterministic `phase_timer`).

## Rules (defaults — provisional, brief-adjustable)

- **Rounds:** best-of-3 — first to **2** round wins takes the match.
- **Timer:** ~**99 in-game seconds** = ~**5940 frames** at 60 Hz, counted down on the
  tick. **Timeout → higher current health wins the round**; equal health → tie.
- **Health:** one conventional total in `SimState.players[i].health`. **Value tuned by
  the Architect against B's damage** (default target: a couple of good touches decide a
  round — brief). Placeholder until B's damage lands; the *mechanism* is contract.
- **KO:** `health <= 0` ends the round (`reason = KO`; loser is the KO'd player). Both
  KO'd on the same tick → `DOUBLE_KO`.
- **Ties (brief):** `DOUBLE_KO` and equal-health `TIMEOUT` **award the round to both**
  (`round_wins++` each). If that pushes **both** to the match threshold at once → a
  single **sudden-death** final round (`sudden_death = true`, one round, any win takes
  the match — brief-confirmed 2026-07-14).

## Legibility (the charter job — brief)

The match must be as legible as the combat: you always know health, round count, and
the clock, and when a round/match ends you can always read **why** (KO vs timeout vs
double-KO). This is served through the seam by **`MatchView`** (`inspection-surface.md`):
health, `round_wins`, `round_timer`, `match_phase`, `last_round_end_reason` — all
serialized truth, read-only, snapshot-able. Health bars, round pips, the clock, and a
clear end-of-round/end-of-match result render *from* `MatchView`, following the P1
view/view-model split (JC-040). The end reason being **serialized truth** (not a render
guess) is what makes the emotionally-loaded moment — a razor-close timeout, a clean
double-KO — legible on its face.

**Human-inspection gate.** The match layer is an experiential surface (health, pips,
clock, result a human must *see and read correctly*). QA's headless audit (transitions,
determinism, correct win resolution) is necessary but **not sufficient** — the user's
play/look gate clears last, specifically checking that match state and *why a
round/match ended* are legible on screen (brief; roadmap P2 gate).

## Tenet compliance

- **Tenet 1 (per match).** `MatchState` serializes/restores/re-runs identically; the
  existing determinism + serialization harness (`simulation.md`) **extends to match
  boundaries** — a full match (multiple rounds, a KO, a timeout, a reset) round-trips and
  re-simulates to the same hashes. No wall-clock, no `_process` timer, no unseeded RNG.
- **Tenet 2.** `match_step` consumes the same two `InputFrame` streams — input-source-
  agnostic (two humans, human vs. record/playback dummy, CPU later); no new source type.

## Acceptance criteria (QA-checkable)

1. **Deterministic per match.** A whole match (≥2 rounds, including a KO and a timeout)
   serialized mid-match, restored, and resumed yields the same final `MatchState` hash as
   the uninterrupted run; the same input stream reproduces the same match, KO, and
   timeout (the per-match determinism proof — brief). No wall-clock/`_process`/`delta`
   drives the timer or any transition.
2. **`step` untouched.** `match_step` wraps `step` without changing its
   `(state, in_p1, in_p2)` signature (AD-024/AD-048); combat determinism is unchanged.
3. **KO resolution.** `health <= 0` ends the round with `reason = KO`; a simultaneous
   both-to-zero yields `DOUBLE_KO` and awards the round to both.
4. **Timeout resolution.** `round_timer == 0` ends the round with `reason = TIMEOUT` and
   awards it to the higher-health player; equal health awards it to both (tie).
5. **Scoring + match end.** First to 2 round wins → `MATCH_END`; a tie pushing both to 2
   → one `sudden_death` round that resolves the match on any win.
6. **Legibility (seam).** `MatchView` exposes health, round wins, timer, phase, and the
   round-end reason; each end condition (KO, timeout, double-KO) produces the correct
   `last_round_end_reason` as serialized truth (`inspection-surface.md` criterion 7).
7. **Round reset.** `ROUND_START` restores fresh symmetric positions and full health, and
   resets the timer — verified by hash-comparing a round-start state to a canonical
   fresh-round state.
8. **No new combat / no float in match state.** `MatchState` adds no combat mechanic and
   no float field; all match values are integer/enum (Tenet 1 / AD-019 discipline).

## Open items

- **Health value** — tuned after B's damage numbers (a follow-up tuning ticket; the
  mechanism is done).
- **Exact round length / transition-beat lengths** — provisional feel, adjustable; the
  frame-counted mechanism is contract.
