# Technical Tenets

> Inviolable architectural givens, owned by the user — a sibling to the charter.
> The charter says what the game is and why; this says what the build must
> always stay true to, technically. Every role reads this alongside the
> charter, first. These are not the Architect's to invent or override: the
> Architect enforces and elaborates them and may *raise* a problem with one, but
> only the user *resolves* it.

**Engine:** Godot. A 2D fighting game in the lineage of *Under Night In-Birth*.

## 1. The simulation is deterministic

Gameplay is a pure function of `(previous state, inputs)`. The same start state
and the same input stream produce the same result, every time.

In practice:

- The full game state is serializable; the sim can be saved, restored, and
  re-run from any frame.
- No dependence on wall-clock time or frame `delta`. Gameplay advances on a
  fixed timestep — all of it in `physics_process`, never on render timing.
- No unseeded randomness. Any RNG is seeded and lives inside the serialized
  state.
- Godot's physics *solver* never owns gameplay state — no RigidBody/CharacterBody
  integration or built-in physics step advancing anything we can't fully control
  or serialize. (*How* we satisfy this is the Architect's call, not a tenet:
  almost certainly our own movement and our own AABB hitbox/hurtbox overlap,
  since 2D overlap is just box tests — but an engine node used purely as a
  deterministic geometry or overlap query inside the fixed step is not
  forbidden.)

**Why:** this is what keeps rollback netcode on the table later without a
rewrite. We are not committing to ship netcode in the slice — only to never
foreclose it. Mind the actual bar: single-machine rollback re-simulation needs
only the purity above, so floats are fine *for it*. But floats behave
differently across platforms and compilers, so leaning on them now keeps
*rollback* open while quietly leaning away from strict cross-platform
*lockstep*. Lockstep is a harder bar we're keeping in view, not clearing now; if
it ever becomes a real goal, that's a deterministic-math decision (fixed-point,
or tightly controlled float settings) to make then.

## 2. All input flows through one abstraction

There is a single per-frame input representation (directions plus buttons — e.g.
a bitfield) and a single interface that yields the input for a given frame. The
simulation consumes two of them — one per player — and advances. Nothing in the
sim knows or cares where the input came from.

Every input producer is just another implementation of that one interface:
local device, replay file, network peer, CPU, and scripted tutorial sequences
all emit the identical per-frame stream. The training mode's record/playback
dummy is an input source writing and replaying a buffer.

**Why:** this is the master key. Replays, netcode, CPU opponents, and scripted
tutorials become new *input sources*, not new *systems*. The slice already
exercises the abstraction the rest of the project leans on.

## 3. Build for extension

The slice exists to prove the architecture, not to be the whole game. When two
implementations both satisfy the slice, prefer the one that leaves more doors
open later. Structures should make the *next* things easy, not merely work once.
