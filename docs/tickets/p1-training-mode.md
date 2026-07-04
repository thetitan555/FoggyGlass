# Tickets — P1: Debug / Technical Training Mode

> Owned by the **Architect**. Developer-sized units decomposed from
> `/docs/spec/training-mode.md` + `/docs/spec/inspection-surface.md`, serving the
> brief `debug-training-mode`. Each ticket names the spec it serves, its
> dependencies, and the acceptance criteria it must satisfy (QA verifies against
> the spec's criteria, not the ticket's prose).

## Sequencing (the seam)

At the systems/content seam the player-facing side is **downstream** of the
simulation-facing interface, so the sim-facing tickets (01–04) land first — as
real interfaces, stubbed if needed — before the player-facing tickets (05–09)
build on them. One developer writes both halves; the order still holds, because
05–09 compile against 01–04's surfaces.

```
01 inspection ─┐
02 frame-ctrl  ├─▶ 05 shell ─▶ 06 geometry
03 save/reset  │              ─▶ 07 frame-data+advantage
04 rec/play    ┘              ─▶ 08 live-state
                              ─▶ 09 input-display
```

P0 dependency: all of 01–04 require the P0 backbone (sim loop, serializable state,
inspection surface stub, `InputSource`). They observe whatever character exists —
the P0 test character is enough to build and verify against; character A (separate
content) sharpens validation when it lands.

### Build batches

The Developer executes these as three sessions (never invents its own batching —
protocol § "Token economy"). Grouping amortizes shared spec-reads and lands each
batch on a real checkpoint. Batch boundaries also honor the seam: Batch 1 lands the
sim-facing interfaces (and the projectile) that Batch 3's overlays read downstream.

- **Batch 1 (done):** TKT-P1-01, 02, 03, 04, 0P — the sim-facing interfaces plus the
  projectile entity. (03 depends on 04, 0P on the P0 backbone; all within-batch.)
  *Checkpoint:* the interfaces are green and a projectile resolves a hit.
- **Batch 2:** TKT-P1-10 — character A authoring, against the move format (needs 0P's
  fireball from Batch 1). *Checkpoint:* A is playable vs a dummy (the record/playback
  dummy from Batch 1's TKT-P1-04) — the **P1 done-bar** (Strategist's flag resolution).
- **Batch 2E (engine, content-surfaced):** TKT-P1-11, 12 — the two engine builds
  character-A authoring surfaced as flags (invuln consumption + `hit_kind`; command-schema
  jump/chord), resolved by the Architect as AD-031/AD-032. They unblock the part of A's
  done-bar (criteria 4, 6, 8) that inert authored data cannot reach. Independent of each
  other; both depend on Batch 1 (0P for the projectile invuln gate) and the Batch-2
  authored data. *Checkpoint:* A's invuln beats a jump-in end-to-end and jump/throw are
  reachable by live input. (Sequenced after Batch 2 because they consume its authored data;
  the Strategist scopes this session — see the flag resolutions.)
- **Batch 3:** TKT-P1-05, 06, 07, 08, 09 — the training-mode shell plus the four
  overlays (all downstream of Batch 1's interfaces; 06–09 depend on 05). *Checkpoint:*
  the mode shows, live, what the sim is doing. Note: `PlayerView.invuln` (a derived read,
  TKT-P1-11) is surfaceable in TKT-P1-01 independently, so the overlays can be built against
  it in parallel with Batch 2E; only the *end-to-end* whiff-by-invuln display verifies once
  TKT-P1-11's phase-4 gate lands.

Note the deliberate ordering: character A (Batch 2) lands *before* the player-facing
overlays (Batch 3) that display it, because "A playable vs a dummy" is the P1 done-bar
and the overlays are the readout layer on top of a working, testable character. This is
a Strategist steerability call (widen/narrow batching is the Strategist's per protocol
§ "Token economy"); the mechanical grouping and its dependency-graph soundness are the
Architect's, and are recorded here. Dependency check: every batch's tickets have their
cross-batch dependencies satisfied by an earlier batch (0P before 10; 01–04 before 05;
05 before 06–09) — the plan is sound as drawn.

---

## Sim-facing interfaces (first)

### TKT-P1-01 · Inspection surface (concrete read API)
**Serves:** `inspection-surface.md`. **Depends:** P0 sim loop + `SimState`.
**Scope:** Implement `InspectionView` and its return types (`PlayerView`,
`BoxView`, `FrameData`, `AdvantageView`, `HitEvent`) as read-only views over the
current state, sourcing advantage/frame-data from the sim's own functions (no
re-derivation). `PlayerView` includes the batch-2 legibility fields
(`move_contact`, `cancel_tags`, `throw_tech_window`, `thrown_by`) surfaced
read-only from the corresponding `SimState` truth (F-013 / AD-028) — no
re-derivation, just projection. Build the interface first; this is the seam
everything else reads. Snapshot-able views are fixed-point only (these four are
plain int / int-array, no floats); px is a render-only projection (AD-019).
**Acceptance:** `inspection-surface.md` criteria 1–6.

### TKT-P1-02 · Frame control (pause / resume / step-once)
**Serves:** `training-mode.md` → Control layer (frame control). **Depends:** P0 sim
loop. **Scope:** `set_paused`/`is_paused`/`step_once`; stepping advances exactly
one tick and crosses hitstop one tick per call (AD-010).
**Acceptance:** `training-mode.md` criteria 1–2.

### TKT-P1-03 · Situation save / restore + single reset slot
**Serves:** `training-mode.md` → Control layer (reset). **Depends:** P0
serializable state; **TKT-P1-04** (reset point includes source playback position).
**Scope:** `snapshot`/`restore`; one reset slot (`capture_reset`/`do_reset`). The
reset point bundles the sim `StateBlob` **and** each `RecordPlaybackSource`'s
playback position, and `do_reset()` restores both so the dummy re-syncs (AD-020).
No multi-slot. Coordination lives in the harness, not the sim (Tenet 2 intact).
**Acceptance:** `training-mode.md` criteria 3 and 12.

### TKT-P1-04 · Record/playback dummy (input source)
**Serves:** `training-mode.md` → Control layer (dummy); `input.md`. **Depends:** P0
`InputSource` interface. **Scope:** `RecordPlaybackSource` implementing
`InputSource` with `PASSTHROUGH` / `RECORDING` / `PLAYBACK` modes over a raw
`InputFrame` buffer, looping playback. No AI/behavior. Expose a readable/restorable
playback position so the reset point (TKT-P1-03) can re-sync it (AD-020); being
frame-indexed (`input.md`) makes this natural.
**Acceptance:** `training-mode.md` criteria 4 and 12.

---

### TKT-P1-0P · Projectile entity system
**Serves:** AD-021; `move-format.md` (spawn/`Projectile`), `simulation.md`
(`SimState.projectiles`), `combat-resolution.md` (Projectiles section),
`inspection-surface.md` (`projectiles()`). **Depends:** P0 sim loop + state.
**Scope:** Add `SimState.projectiles`; the `spawn` keyframe action with per-owner
cap; per-tick integration, overlap-vs-opponent-hurtbox, hit/block resolution, and
despawn (consumed / lifetime / off-stage); expose `ProjectileView`. Sim-facing —
character A's fireball needs it. No projectile-vs-projectile (deferred).
**Acceptance:** `character-a.md` criterion 5 (fireball is a projectile);
surfaced in the geometry overlay (training-mode criterion 5).

## Content (authored against the format)

### TKT-P1-10 · Author character A move data
**Serves:** `character-a.md` (full kit). **Depends:** P0 move format; **TKT-P1-0P**
(fireball). **Scope:** Author all of A — movement, 9 normals, fireball/shoryuken
(L/M/H), throw — purely as `.tres` move data with the listed frame data, hitboxes,
properties, and `CancelRule`s (special-cancels + links only; no gatlings/jump
cancels). No engine changes. This is the training mode's first *real* test subject
and the P1 done-bar (per the Strategist's flag resolution).
**Acceptance:** `character-a.md` criteria 1–7 and 9 (criterion 8 lands with
TKT-P0-08; criterion 10 is verified at the feature audit, in-mode).

## Engine (content-surfaced P1 work — flag resolutions)

> These two tickets are P1 **engine** work that character-A authoring (TKT-P1-10)
> surfaced as flags the Architect resolved (AD-031, AD-032). They unblock the part of
> `character-a.md`'s done-bar that authored-but-inert data cannot reach on its own. No
> content authoring here beyond the small `character_a.gd` `button_map` additions TKT-P1-12
> names; the durable design is the ADs. Sequencing: both are independent of the Batch-3
> overlays' *interfaces* (they touch the sim, not the seam shape); `PlayerView.invuln`
> (TKT-P1-11's read) is a derived projection addable in TKT-P1-01 with no dependency on the
> phase-4 change landing.

### TKT-P1-11 · Consume invulnerability (phase 4) + `HitBox.hit_kind`
**Serves:** AD-031; `combat-resolution.md` (phase 4 + Invulnerability + criterion 12),
`move-format.md` (`HitBox.hit_kind`, `Keyframe.invuln`), `inspection-surface.md`
(`PlayerView.invuln`). **Depends:** P0 phase pipeline (`step_phases.gd`); TKT-P1-0P
(projectiles, for the PROJECTILE gate); the character-A invuln data authored inert at
TKT-P1-10. **Scope:**
- Add `HitBox.hit_kind` (`STRIKE`/`THROW`/`PROJECTILE`; default `STRIKE`) to `hit_box.gd`;
  reconcile the existing `is_throw` to `hit_kind == THROW` (same fact, two names — the
  throw path may keep reading `is_throw`). Mark a projectile's carried hitbox `PROJECTILE`.
- In `phase4_overlap`, gate each candidate contact — **character hitbox and projectile
  alike** — against the *defender's* covering-keyframe invuln before appending it: a
  `STRIKE`/`PROJECTILE` against a frame with `invuln_strike` is **not appended**; a `THROW`
  against `invuln_throw` is not appended. Resolve the defender's covering keyframe via the
  same `MoveData` keyframe lookup the box resolver uses (derived, no new state). A suppressed
  contact reaches phase 5 for nothing — no `id_group`/throw-clash/combo effect.
- A projectile suppressed by invuln is **not consumed** (no phase-5 connect ⇒ no despawn);
  it may connect on a later vulnerable frame.
- Add the derived `PlayerView.invuln` (`{ strike, throw }` bools) read in
  `inspection_view.gd`/`player_view.gd`, projecting the covering keyframe. No `SimState`
  field, no new hash coverage.
**Acceptance:** `combat-resolution.md` criterion 12; `character-a.md` criteria 4 (`2H`
strike-invuln beats a jump-in, gives no combo) and 6 (each DP strike-invuln frame 1→first
active; `623H` also throw-invuln; the back dash's invuln 1–7); `inspection-surface.md`
criterion 1 (invuln readable through `PlayerView`) + criterion 4 (no float in the view).
A test must show: a strike whiffing an `invuln_strike` frame (no damage/stun, `move_contact`
→ `WHIFF`); the same frame still thrown unless `invuln_throw`; a projectile passing through
an `invuln_strike` frame and connecting on a later vulnerable frame.

### TKT-P1-12 · Command schema: pure-direction command + two-button chord
**Serves:** AD-032; `move-format.md` (`ButtonMapEntry` schema / command-recognition
contract). **Depends:** P0 input buffer (`input_buffer.gd`, `button_map_entry.gd`); the
character-A jump/throw `MoveState`s authored at TKT-P1-10. **Scope:**
- Add `chord_button_index: int = -1` to `button_map_entry.gd`.
- In `input_buffer.gd` `entry_satisfied`: (a) a `button_index == -1 && motion == 0` branch
  recognizing the entry by `required_direction` held within `COMMAND_BUFFER` (reuse
  `_required_direction_held`); (b) a chord branch requiring `button_index` **and**
  `chord_button_index` bits on the **same** buffered frame.
- Author A's `button_map` entries (in `character_a.gd`): jump (`UP`, no button →
  `STATE_PREJUMP`) and throw (`BUTTON_0`+`BUTTON_2` chord → `STATE_THROW`), the throw
  listed **before** the bare `5L/5M/5H` entries so first-match-wins routes `L+H` to the
  throw while bare presses still reach the normals. Remove the flag scope-note comments now
  that the entries exist.
**Acceptance:** `character-a.md` criterion 8 (buffer/recognition) extended: jump is reachable
by holding up; `L+H` performs the throw; **`5L`/`5M`/`5H` each remain reachable** by a bare
press (the chord does not shadow them). The recognizer stays a pure function of
`input_history` (deterministic across sources, `input.md` criterion 2). A test must show a
bare `L` reaching `5L`, and a same-frame `L+H` reaching the throw, with the throw entry
ordered first.

## Player-facing (downstream of the interfaces)

### TKT-P1-05 · Training-mode shell / scene
**Serves:** `training-mode.md` (placement + integration). **Depends:** 01–04
(interfaces, stubs ok). **Scope:** The mode/scene that wires a match with two input
sources (P1 = device, P2 = record/playback dummy), mounts the frame-control,
reset, and record/playback controls, and provides the surface the overlays render
into. Reads only via `InspectionView` + the control contracts — no `SimState`
internals.
**Acceptance:** `training-mode.md` criterion 10 (seam discipline); integrates
02–04 so their criteria are exercisable in-mode.

### TKT-P1-06 · Geometry overlay
**Serves:** `training-mode.md` → Readout (geometry). **Depends:** 01, 05.
**Scope:** Draw resolved `BoxView`s per player in world space, color-coded by
kind, active hitboxes distinct.
**Acceptance:** `training-mode.md` criterion 5.

### TKT-P1-07 · Frame-data & advantage panel
**Serves:** `training-mode.md` → Readout (frame data + advantage). **Depends:** 01,
05. **Scope:** Static startup/active/recovery + on-hit/on-block advantage for moves
in play; live advantage (value, who-plus, frames-to-neutral, neutral flag).
**Acceptance:** `training-mode.md` criterion 6; relies on AD-008's static-vs-live
distinction.

### TKT-P1-08 · Live-state panel (state, hitstop, stun, damage/combo)
**Serves:** `training-mode.md` → Readout (live state). **Depends:** 01, 05.
**Scope:** Per player: state + category + frame/duration, hitstop, stun + kind,
actionable; damage/combo (hit_count, scaling, total).
**Acceptance:** `training-mode.md` criteria 7 and 9.

### TKT-P1-09 · Input display / history
**Serves:** `training-mode.md` → Readout (input). **Depends:** 01, 05. **Scope:**
Decode the current `InputFrame` (directions + buttons) per player and a scrolling
history of recent raw frames (Tenet 2).
**Acceptance:** `training-mode.md` criterion 8.

---

## Cross-cutting (verified at feature audit, not a separate ticket)

- **Same-surface-as-QA** (`training-mode.md` criterion 11): the determinism/golden
  harness and the overlays read the one inspection surface; QA confirms no
  divergent second source of truth.
- **Judgment-call log:** any latitude the Developer takes on these tickets is
  recorded for Architect ratification before this feature is audited (protocol
  cadence).
