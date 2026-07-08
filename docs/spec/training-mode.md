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
  reset slot**. `capture_reset()` stores the reset point; `do_reset()` restores it.
  This is the minimum that makes reps fast; multiple saved situations are a later
  extension, explicitly out of slice scope. The slot is additive to multi-slot,
  not a redesign.
- **Reset restores sim *and* playback position (AD-020).** The reset point is
  **both** the sim `StateBlob` **and** the playback position of each
  `RecordPlaybackSource` — because the playback cursor lives outside `SimState`
  (sources are external, Tenet 2), so restoring state alone would desync the dummy
  and break the rep. `do_reset()` restores both, so a recorded sequence replays in
  sync every rep. This coordination lives **in this training-mode harness** (which
  owns both the runner and the sources), not in the sim — the sim still knows
  nothing about input sources, so Tenet 2 holds. Independent/"metronome" playback
  (reset sim, keep the dummy rolling) is out of slice scope.

**Record / playback dummy (Tenet 2 — an input source, not an AI).**
- `RecordPlaybackSource` *implements `InputSource`* with three modes:
  - `PASSTHROUGH` — yields the live device frames for its player.
  - `RECORDING` — yields live frames **and** appends each to a buffer.
  - `PLAYBACK` — yields buffered frames in order, looping at the end.
- Mode switches are deterministic; the buffer is the recorded raw `InputFrame`
  stream. The dummy has **no behavior/AI** — any "reaction" is recorded or
  scripted input through the one interface.

## Human control surface (operability — P1.1)

The control layer above is the sim-facing *contract*; this section is the
**human-facing binding** onto it, added in P1.1 (roadmap). P1 landed the control
methods but bound nothing to them, so the mode was observable but not operable
(`flags.md`, 2026-07-08). The brief's required outcomes describe a human *pressing*
frame control, reset, and record/playback — so binding them is completing P1, not
new scope.

- **Bound controls.** Pause/resume, frame-step (`step_once`), capture-reset,
  do-reset, and dummy record/playback mode-switch are each invokable from an actual
  **device/keyboard control** routed through the `TrainingMode` shell's control
  methods (never bypassing the shell into `TickHost`/`TrainingHarness`/
  `RecordPlaybackSource` directly — the shell stays the one place the sim is driven
  from, mirroring the read-only rule on the inspection side).
- **Complete the P1 device sampler.** The P1 device source samples directions only;
  it must also sample the **three attack buttons** (`BUTTON_0/1/2`, AD-018) so a
  human can actually perform character A's moves and read their frame data — the
  mode's whole purpose. Still the one `InputSource` interface (Tenet 2); the sampler
  emits the identical raw `InputFrame`.
- **Discoverable.** The bound controls are **surfaced on screen** (a minimal
  controls legend) so a human can find them without reading code — the operability
  the human-inspection gate confirms. This is legibility of the instrument, not
  UI polish; keep it minimal.
- **Players start as the installed character.** A code-level requirement completing
  the shell wiring: both players must begin as the **installed character in its idle
  state**, not the generic default player `SimState.new_initial()` builds — otherwise
  the roster lookup resolves nothing and every readout (and the geometry overlay)
  reads empty/zero (the 2026-07-08 finding: panels showed "state 0 … startup 0").
- **Key choice is placeholder.** The specific keys are the Developer's to pick
  (placeholder, like tuning numbers); the contract is "each control operation is
  reachable from a bound control, and the controls are discoverable." The default
  input map lives in `project.godot`.

## Geometry framing (P1.1)

The geometry overlay draws in **world space**; for boxes to be visible it needs a
world→viewport framing, specified in **AD-035** (a render-only camera transform
extending AD-019's fixed→px scale). The four readout panels stay **screen-anchored
HUD** (unmoved by the framing). Both characters at their symmetric start positions
must be fully on-screen and unoccluded by the panels. Render-only; never enters a
snapshot or the canonical hash (Tenet 1 intact, exactly as AD-019).

## Readout layer (player-facing overlays, all from `InspectionView`)

Each overlay renders only from the inspection surface. Grouped into the units the
tickets build:

**Geometry overlay.** Draw each player's resolved `BoxView`s in world space,
color-coded by `kind` (hurt / hit / throw / push), converting each box's
fixed-point `rect` to pixels via the render projection (`inspection-surface.md`,
AD-019). Active hitboxes are visually distinct. This is "see what hit and what
whiffed."

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
   overlapping the defender hurtbox. **The boxes are actually visible on screen**
   — both characters' resolved boxes render fully within the viewport and are not
   occluded by the readout panels (AD-035 framing; verified in-mode / at the human
   gate, since pixel visibility is not headless-checkable — the P1 gap this closes).
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
12. **Reset re-syncs the dummy (AD-020).** Record a dummy sequence,
    `capture_reset()`, play forward, `do_reset()` → the dummy replays the identical
    inputs from the reset point and the whole rep is bit-identical on repeat. (This
    covers the reset+playback *interaction*, which criteria 3 and 4 test only
    independently.)
13. **Human-operable (P1.1).** Each control operation — pause/resume, frame-step,
    capture-reset, do-reset, dummy record/playback mode-switch — is invokable by a
    human from a bound device/keyboard control (routed through the shell), and the
    device source samples directions **and** the three attack buttons so a human can
    perform character A's moves. The bound controls are surfaced on screen. Verified
    at the human-inspection gate (operability is not headless-confirmable).
14. **Framed on screen (P1.1).** With both players started as the installed
    character in idle, the geometry overlay's boxes are fully visible within the
    viewport and unoccluded by the panels (AD-035); the readout panels stay
    screen-anchored. Render-only — a golden taken with or without the camera is
    identical (AD-019 criterion 6 extends to the framing). Pixel visibility verified
    at the human-inspection gate.
