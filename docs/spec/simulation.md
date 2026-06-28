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

## `SimState` — the serializable root

A single plain-data graph (Dictionaries / typed Resources / packed arrays — no
live node references). Top-level fields:

| Field | Notes |
|---|---|
| `tick` | Monotonic tick counter; the authoritative clock. |
| `rng` | Seed + current RNG state, **inside** the serialized state (Tenet 1). Any randomness draws from here. |
| `players[2]` | Per-player state (below). |
| `stage` | Bounds / wall positions / any stage state affecting the sim. |

Per-player state (`players[i]`):

| Field | Notes |
|---|---|
| `position`, `velocity` | Fixed-point integers (AD-005, AD-014) — never floats. |
| `facing` | Which way the character faces; the raw→forward/back conversion uses this. |
| `health` | Current health. |
| `state_id`, `frame_in_state` | Current state-machine state and the frame within it (see `move-format.md`). |
| `hitstop` | Remaining hitstop frames (AD-010). |
| `stun` | Remaining hitstun/blockstun frames; `0` = actionable. |
| `combo` | Hit count + current damage-scaling state. |
| `input_history` | Ring buffer of recent raw `InputFrame`s — the substrate buffering/motion recognition reads (AD-003). |

**Derived, not stored (AD-001 / AD-005).** Active hitbox/hurtbox geometry is
*computed each tick* from move data + `(state_id, frame_in_state, facing,
position)` — not persisted. State stays minimal and single-sourced.

## Serialization

- `SimState` round-trips: **serialize → restore → resume produces identical
  state**, bit-for-bit at the data level.
- Save/restore is a deep copy of the data graph. Nodes are rebuilt as a *view*
  of restored state; they carry no state of their own.
- This is the one mechanism behind frame-step, situation-reset, replay, and
  rollback — they are all "snapshot, advance, maybe restore."

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
  spec fixes that they are read **through this one surface**.

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
