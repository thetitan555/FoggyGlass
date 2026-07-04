# Spec — Simulation Loop & Serializable State (P0)

> Owned by the **Architect**. The contract for Tenet 1: the deterministic step,
> the shape of serializable state, and the read-only inspection surface that is
> the systems/content seam. See decisions AD-001, AD-004, AD-005, AD-011, AD-012.

## The tick model

- Gameplay advances on a **fixed 60 Hz tick** inside `physics_process`. One
  `physics_process` = one sim tick = one call to `step`.
- The authoritative clock is a **tick counter in state**, not Godot's frame
  count, `delta`, or wall-clock. Render may run at any rate; it reads state and
  never advances it.
- If the engine reports multiple/zero physics steps, the sim still advances
  exactly one tick per intended tick — never scaled by `delta`.

## The step function

```
step(state: SimState, in_p1: InputFrame, in_p2: InputFrame) -> SimState
```

Contract:

- **Pure in contract.** The next state is a function only of `(state, in_p1,
  in_p2)`. No reads of wall-clock, `delta`, unseeded RNG, engine input polling,
  or the scene tree.
- **Must not mutate its input** (AD-004). `step` writes the next state into a
  *distinct* state object and leaves `state` untouched, so purity is structurally
  verifiable (`hash(prev)` is unchanged after the call). Buffer reuse is allowed —
  a state no longer live may be recycled as the output buffer — so this is not
  per-tick allocation churn.
- The internal phase order `step` runs is fixed and specified in
  `combat-resolution.md` (AD-009).

**Authored move data is a fixed input, not a `step` parameter (AD-024).** The
phase pipeline resolves each player's `Character` (boxes, transitions, frame
data) through a process-wide **immutable roster** (`MoveRegistry`), installed
once at match/scenario/test wiring and never mutated mid-run — *not* threaded
through `step`'s signature, which stays exactly `(state, in_p1, in_p2)`. This is
the same reasoning that keeps input *sources* external and out of `SimState`
(AD-001): authored content is a fixed input to the whole simulation, carries no
per-tick state, and so a snapshot/restore/replay reproduces identically because
the same immutable roster is present. The `character_id` in each `players[i]` is
the key the pipeline resolves against. `step` therefore remains a pure function
of `(state, inputs)` *given the installed roster*; the roster is a determinism
precondition, and mutating it mid-run is a determinism hazard the wiring layer
must not commit (AD-024).

**Install-once / immutable-across-a-run is a checkable invariant (AD-024, F-009).**
Because the type system cannot prevent a mid-run `install()`/`clear()`, this
precondition is not left to wiring discipline alone: the `MoveRegistry` exposes an
**install-generation token** (a monotonic counter, or equivalent identity, bumped on
every `install`/`clear`) that a run can capture at its first `step` and re-check.
The invariant is: *the roster's install-generation token observed at the first `step`
of a run is identical at every subsequent `step` of that run.* A change in the token
mid-run is a determinism break, not a silent hazard — it is now assertable (acceptance
criterion 11), the same way produce-before-query ordering was made an owned, checkable
invariant (F-001 → input.md crit 7) rather than resting on tree-order accident.

## `SimState` — the serializable root

A single plain-data graph (Dictionaries / typed Resources / packed arrays — no
live node references). Top-level fields:

| Field | Notes |
|---|---|
| `tick` | Monotonic tick counter; the authoritative clock. |
| `rng` | Seed + current RNG state, **inside** the serialized state (Tenet 1). Any randomness draws from here. |
| `players[2]` | Per-player state (below). |
| `projectiles` | List of live projectile entities (AD-021, AD-030) — owner, fixed-point position/velocity, lifetime, and a `data_id` (int) resolving the authored `ProjectileData` (its `hitbox` re-attached from `ProjectileRegistry` on restore — authored geometry is not serialized, AD-024/AD-030). Capped at one per owner for the slice. Empty when none are out. |
| `stage` | Bounds / wall positions / any stage state affecting the sim. |
| `last_hit` | The most recently resolved hit as a plain serialized `HitRecord`, or null if none has resolved this run (AD-024). Backs `InspectionView.last_hit()`; distinct from the seam-side `HitEvent` view it projects to. Serialized (null ⇒ empty-dict marker), deep-cloned, hashed with a presence flag (AD-023, AD-024). |
| `neutral_restored_this_tick` | Bool. Set by phase 6 exactly on the tick both players *transition* to actionable (rising edge — AD-025), cleared every other tick. Backs `AdvantageView.neutral_restored`. Serialized (as 0/1), cloned, hashed. |

Per-player state (`players[i]`):

| Field | Notes |
|---|---|
| `position`, `velocity` | Fixed-point integers (AD-005, AD-014) — never floats. |
| `character_id` | Which `Character` this player is (`move-format.md` → `Character.id`); the sim and inspection surface resolve this player's move data / boxes / frame data against it. Plain int. Sim-side authored-data resolution goes through `MoveRegistry` (AD-024); `character_id` is the key. |
| `facing` | Which way the character faces; the raw→forward/back conversion uses this. |
| `health` | Current health. |
| `state_id`, `frame_in_state` | Current state-machine state and the frame within it (see `move-format.md`). |
| `hitstop` | Remaining hitstop frames (AD-010). |
| `stun` | Remaining hitstun/blockstun frames; `0` = actionable. |
| `stun_kind` | Which kind of stun: `0` none / `1` hit / `2` block (backs `PlayerView.stun_kind`). Set by hit resolution (phase 5), cleared when stun expires. Plain int (AD-024). |
| `combo` | Hit count + current damage-scaling state + cumulative combo damage. Carried as three plain ints: `combo_hits`, `combo_scaling` (FP-scaled multiplier, AD-014 — starts `FP.ONE`), `combo_damage` (whole units, backs `PlayerView.combo.damage_total`). (AD-024.) |
| `active_hit_ids` | Per-attacker single-hit memory: the hitbox `id_group`s that have already connected during this player's *current* move (`PackedInt32Array`). A hitbox whose `id_group` is present does not re-hit, so a multi-frame active window lands one hit — not one per active frame (AD-016, "one hit per group per contact"). Cleared on every state entry. Serialized as a variable-length run (count-then-ids, order-committing per AD-023), cloned, hashed. Cadenced re-hit (`rehit_interval` > 0) consults this same set with an interval (see `active_hit_frames`). (AD-026.) |
| `active_hit_frames` | **Parallel to `active_hit_ids`** (index `i` is the tick `active_hit_ids[i]` last connected). Backs cadenced re-hit (`HitBox.rehit_interval`, AD-016): a `rehit_interval` hitbox re-hits the same target only once `rehit_interval` frames have elapsed since that `id_group` last connected — no hit on the frames between. Kept length-synced with `active_hit_ids` (appended/cleared together). `PackedInt32Array`; serialized/cloned/hashed as a variable-length run (count-then-frames, order-committing per AD-023). (AD-028.) |
| `cancel_tags` | Cancel tags granted to this player *as attacker* by a connecting hitbox in phase 5 of tick T (`HitBox.cancel_tags`), consumable by the cancel phase (phase 2) starting T+1 — the AD-017 grant→consume latency, which falls out for free because phase 2 precedes phase 5. Cleared on every state entry (a new move's tags are its own). `PackedInt32Array`; serialized/cloned/hashed as a variable-length run (count-then-tags, order-committing per AD-023). (AD-028.) |
| `move_contact` | Outcome of this player's *current* move for `CancelRule.condition` evaluation (AD-015): `0` none / `1` hit / `2` block / `3` whiff-resolved. Set on the attacker in phase 5 on connect; set to whiff once the move's last active frame passes with no connect (so `on_whiff` cancels can fire). An `on_contact` cancel matches hit OR block. Cleared on state entry. Plain int. (AD-028.) |
| `throw_tech_window` | Frames remaining in which this player (as the thrown *defender*) may tech the throw — input a throw to escape to neutral, no damage (AD-016). Set on throw connect, decremented in phase 7 (a P0 throw connect sets no mutual hitstop, so the window is not frozen). `0` = not in a tech window. Plain int. (AD-028.) |
| `thrown_by` | The attacker index that threw this player (for tech resolution / combo attribution), or `-1` if not thrown. Set on throw connect, cleared when the tech window closes or the throw resolves. Plain int. (AD-028.) |
| `input_history` | Ring buffer of recent raw `InputFrame`s — the substrate buffering/motion recognition reads (AD-003). |

**Derived, not stored (AD-001 / AD-005).** Active hitbox/hurtbox geometry is
*computed each tick* from move data + `(state_id, frame_in_state, facing,
position)` — not persisted. State stays minimal and single-sourced.

**The SimState table is extensible-as-systems-land, not presumed-complete.**
This table enumerates the fields P0 batch 1 established; it is *not* frozen. As a
new system lands (buffer/cancels, throws, meter, later mechanics) it may require
new *mutable, per-tick* state, and the defined home for that state is this table
— added here with name/type/serialization/hash treatment, under an AD, at the
ratification pass for the ticket that introduces it. The bar for adding a field
is unchanged and strict: a value belongs in `SimState` only if it is **mutable
sim truth that must survive snapshot/restore and be covered by the canonical
hash** (AD-023). Anything derivable each tick stays derived (AD-001); anything
that is fixed authored content stays out of state (AD-024, `MoveRegistry`);
anything owned by an input *source* stays external (Tenet 2). A field that clears
this bar is a ratified table addition, not a flag — flag only when the *shape* or
hash treatment is genuinely in question.

## Serialization

- `SimState` round-trips: **serialize → restore → resume produces identical
  state**, bit-for-bit at the data level.
- Save/restore is a deep copy of the data graph. Nodes are rebuilt as a *view*
  of restored state; they carry no state of their own.
- This is the one mechanism behind frame-step, situation-reset, replay, and
  rollback — they are all "snapshot, advance, maybe restore."

### Canonical state hash

`SimState` exposes a **canonical hash** — the single primitive the determinism,
purity, and round-trip criteria below are verified through, and the one QA's
golden/determinism harness (TKT-P0-11) standardizes on. It is a deterministic
function of the state's *data* alone: fixed field order (never Dictionary
iteration order), integer stream only (the state is float-free — AD-005/AD-019),
order-committing (a count is folded before every variable-length run so regrouped
bytes cannot collide), and total (every serialized field is covered). The
algorithm and prohibitions are fixed in **AD-023**. Two states are "equal" for
every criterion below iff their canonical hashes match.

## Physics / overlap ownership

- All hit/hurt/push overlap is **our own AABB test** inside `step` (AD-012),
  on fixed-point integer coordinates — overlap is integer compare, movement is
  integer add (AD-014).
- No Godot RigidBody/CharacterBody integration or built-in physics step advances
  anything in `SimState`. An engine node used purely as a stateless geometry
  query inside the fixed step is permitted (Tenet 1's carve-out), but never as a
  state owner.

## The inspection surface (the seam)

A **read-only** accessor layer over `SimState` — the single interface the debug
training mode, the QA determinism/golden harness, and player-facing UI all read
through (AD-011). It is the systems/content seam: simulation-facing code exposes
this surface; player-facing content is built against it and never reaches into
sim internals.

- **Read-only.** It exposes state (and cheap derived reads like resolved boxes,
  frame data, advantage) but provides no path to mutate `SimState`.
- **Single source of truth.** Debug mode and QA harness read the *same* surface
  so they cannot disagree about sim truth (brief requirement).
- Specific readouts (frame data, advantage, boxes, state+frame, hitstop/stun,
  input history, damage/combo) are enumerated in `combat-resolution.md`; this
  spec fixes that they are read **through this one surface**. The concrete
  read API is specified in `inspection-surface.md`.

## Acceptance criteria (QA-checkable)

1. **Purity.** `step(s, a, b)` called twice on equal `(s, a, b)` yields states
   with identical serialized hashes.
2. **Determinism harness.** Replaying one fixed input stream from one start state
   twice produces identical final state hashes.
3. **Round-trip.** For a run of K ticks, snapshotting at tick j, restoring, and
   resuming to tick K yields a state hash identical to the uninterrupted run.
4. **No forbidden reads.** Gameplay advancement reads no `delta`/wall-clock and
   no unseeded RNG (RNG state is present in the snapshot and advances with it).
5. **Tick authority.** Sim tick count derives from `state.tick`, not engine frame
   count; render rate changes do not change sim outcomes.
6. **Read-only seam.** The inspection surface exposes the required reads and
   offers no mutator; attempting to drive state through it is impossible by
   construction.
7. **No engine-physics state.** No gameplay value in `SimState` is owned/advanced
   by a Godot physics body.
8. **No floats in sim state.** `SimState` contains no float fields; positions,
   velocities, and gameplay math are fixed-point integers (AD-005, AD-014). The
   sim performs no transcendental (trig/sqrt) operations.
9. **Immutable input.** After `next = step(prev, a, b)`, `hash(prev)` is identical
   to before the call — `step` did not mutate its input (AD-004).
10. **Hash canonicality (AD-023).** The canonical hash is a function of state data
    only: it does not use Dictionary iteration order or Godot's built-in
    `hash()`/`var_to_bytes`; every serialized field is covered (hashed key set ==
    `to_dict` key set); a count separator precedes every variable-length run so two
    states with the same bytes regrouped differently hash differently; and the hash
    is float-free. Two states with identical data hash identically regardless of
    construction path.
11. **Roster install-generation stable across a run (AD-024, F-009).** The
    `MoveRegistry` install-generation token captured at a run's first `step` is
    identical at every subsequent `step` of that run; a mid-run `install`/`clear`
    (which bumps the token) is detectable as a determinism break, not a silent one.
    The token itself is wiring state, not `SimState` — it is not serialized or hashed
    (it is a determinism *precondition*, not sim truth), but it is observable so QA can
    assert it holds across a run.
