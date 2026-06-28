# Spec — Debug / Technical Training Mode (P1)

> Owned by the **Architect**. Brief: `/docs/briefs/debug-training-mode.md`
> (Strategist). The charter's legibility promise in its most literal form, and the
> team's instrumentation. Depends on the P0 backbone, the **inspection surface**
> (`inspection-surface.md`), and at least one character to observe (the P0 test
> character suffices to build against; full validation lands with character A).

## What it is, and the clarity exception

A mode that tells you the ground truth of the simulation, frame-accurate. It is
the **deliberate exception** to *clarity is craft, not data* — dense, explicit,
numeric readouts are correct here because this is the diagnostic instrument, not
the shipped in-match experience (the Strategist ruled this intended in the brief).
It does **not** relax in-match legibility obligations elsewhere.

## Architecture placement (the seam)

The training mode is the **player-facing side of the systems/content seam**. It
reads sim truth only through the read-only `InspectionView`
(`inspection-surface.md`) and drives the sim only through the control contract
below. It never touches `SimState` internals. (Even though one developer writes
both halves now, the sim-facing interfaces come first — see tickets.)

## Control layer (sim-facing contract the mode is built on)

These are control operations on the deterministic loop — distinct from the
read-only inspection surface. All lean directly on Tenets 1 & 2.

**Frame control.**
- `set_paused(bool)` / `is_paused()` — a paused sim does not advance.
- `step_once()` — while paused, advance **exactly one** sim tick. Frame-steps
  *through* hitstop (one tick per call), since hitstop is in-state, not a loop
  pause (AD-010).

**Situation save / restore (reset).**
- `snapshot() -> StateBlob` / `restore(StateBlob)` — full serializable state
  round-trip (Tenet 1, `simulation.md`).
- **Reset granularity — Architect's call (brief deferred to me):** a **single
  reset slot**. `capture_reset()` stores the current state as the reset point;
  `do_reset()` restores it. This is the minimum that makes reps fast; multiple
  saved situations are a later extension, explicitly out of slice scope. The slot
  is a `StateBlob`, so multi-slot is additive, not a redesign.

**Record / playback dummy (Tenet 2 — an input source, not an AI).**
- `RecordPlaybackSource` *implements `InputSource`* with three modes:
  - `PASSTHROUGH` — yields the live device frames for its player.
  - `RECORDING` — yields live frames **and** appends each to a buffer.
  - `PLAYBACK` — yields buffered frames in order, looping at the end.
- Mode switches are deterministic; the buffer is the recorded raw `InputFrame`
  stream. The dummy has **no behavior/AI** — any "reaction" is recorded or
  scripted input through the one interface.

## Readout layer (player-facing overlays, all from `InspectionView`)

Each overlay renders only from the inspection surface. Grouped into the units the
tickets build:

**Geometry overlay.** Draw each player's resolved `BoxView`s in world space,
color-coded by `kind` (hurt / hit / throw / push). Active hitboxes are visually
distinct. This is "see what hit and what whiffed."

**Frame-data & advantage panel.** For the move(s) in play: static
`startup / active / recovery` and `on_hit_adv / on_block_adv` (the pinned values).
Plus the **live** advantage: `value`, who is plus, `frames_to_neutral`, and the
`neutral_restored` flag — the truthful "who's plus right now," correct through
cancels.

**Live-state panel.** Per player: `state_id` + `state_category` +
`frame_in_state / state_duration`; `hitstop_remaining`; `stun_remaining` +
`stun_kind`; `actionable`; and damage/combo (`hit_count`, `scaling_pct`,
`damage_total`).

**Input display / history.** Per player: the current `InputFrame` decoded
(directions + buttons) and a scrolling history of recent raw frames — the single
input representation surfaced directly (Tenet 2), so input is never the hidden
variable.

## Scope boundaries (from the brief — flag if they creep)

In scope: the readouts and controls above, against the slice characters. **Out of
scope:** combo-trial/challenge systems; multi-slot recording libraries (beyond the
one reset slot + one record buffer); dummy *behavior AI*; frame-data UI polish
beyond legibility.

## Acceptance criteria (QA-checkable)

1. **Frame-step.** While paused, `step_once()` advances exactly one tick; state is
   inspectable at each step; stepping crosses hitstop one tick per call.
2. **Pause/resume.** A paused sim does not advance; resuming continues
   deterministically (resumed run hashes match an uninterrupted run).
3. **Reset.** After `capture_reset()`, playing forward and `do_reset()` returns to
   the exact captured state (state hash equal); reps are repeatable.
4. **Record/playback round-trip.** Recording a player's inputs over a sequence then
   playing back reproduces the **identical** `InputFrame` stream, and the resulting
   sim is identical on every loop (deterministic). A buffer round-trips.
5. **Geometry.** Active hit/hurt/throw/push boxes draw at correct world positions
   matching the resolved boxes; on a contact tick the attacker hitbox is shown
   overlapping the defender hurtbox.
6. **Frame data + advantage.** The panel shows correct static
   startup/active/recovery and on-hit/on-block advantage for moves in play; the
   live advantage matches the sim's value and flips sign correctly on a punishable
   move (and differs from the static number when a cancel is used).
7. **State / hitstop / stun.** The panel shows correct current state+frame, and
   hitstop/stun counting down to `actionable`.
8. **Input display.** Shows the exact per-frame `InputFrame` each player's source
   emitted — matching what the sim consumed (Tenet 2).
9. **Damage / combo.** Shows hits, damage, and scaling as they apply; resets at
   neutral.
10. **Seam discipline.** The mode reads only through `InspectionView` and the
    control/input contracts above; it references no `SimState`-internal types
    directly (verifiable by inspection of the player-facing code's dependencies).
11. **Same surface as QA.** The values displayed equal those the determinism /
    golden harness reads from the same inspection surface — no second source of
    truth.
