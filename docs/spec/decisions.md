# Architecture Decisions

> Owned by the **Architect**. A running record of the load-bearing calls behind
> the spec: what was decided, why, and what was rejected. A Developer or QA
> should be able to learn *why* the architecture is the way it is without asking.
> Append-only in spirit; supersede an entry rather than silently rewriting it.

Status legend: **settled** (agreed, build against it) · **provisional** (in
effect but expect revision) · **superseded** (kept for history).

---

### AD-001 · State is data; the scene tree is a view — settled
**Decision.** The simulation state is a single serializable plain-data graph.
Godot nodes/sprites render *from* that data and are never the source of truth.
**Why.** Determinism, save/restore, frame-step, situation-reset, rollback, and
the debug inspection surface all reduce to "copy/inspect a data blob." One
separation buys all of them, and it is the precondition for Tenet 1.
**Rejected.** State living on nodes (CharacterBody positions, AnimationPlayer as
clock). Cheap to start, but un-serializable, non-deterministic, and forecloses
rollback — exactly what the tenet forbids.

### AD-002 · The input layer is dumb: raw, frame-indexed bitfields — settled
**Decision.** One per-frame `InputFrame` (a bitfield of raw directions + generic
buttons). Sources answer "input for frame N," reproducibly. The layer knows
nothing about facing, move semantics, or buffering.
**Why.** Tenet 2's master key: replay, netcode, CPU, scripted tutorial, and the
record/playback dummy become new *sources*, not new *systems*, only if every
source emits the identical dumb stream. Frame-indexing is required for rollback
re-simulation to re-request past frames.
**Rejected.** Facing-relative (forward/back) or pre-buffered input at the source
— it couples the source to game state and makes replays/netcode diverge.

### AD-003 · Buffering and SOCD resolve sim-side — settled
**Decision.** Input buffering/leniency, motion/command recognition, and SOCD
(opposing-direction) cleaning all live inside the sim, reading the per-player
raw history buffer that is part of serialized state. One SOCD normalization
function, applied identically to every source.
**Why.** Buffering must be deterministic and reproducible; placing it in the sim
means a replay reproduces buffering for free, and netcode rollback re-derives it
from the same raw bits.
**Rejected.** Buffering in the input source (would have to be re-implemented and
kept in sync across every source).

### AD-004 · Fixed 60 Hz tick; `step(state, inP1, inP2)` is pure in contract — settled
**Decision.** All gameplay advances on a fixed 60 Hz tick inside
`physics_process`, off our own tick counter in state. The step's output depends
only on `(prev state, two inputs)`. Implemented as in-place mutation of an owned
state object for speed, but with no external/wall-clock/`delta` reads.
**Why.** Tenet 1. Purity is the contract; in-place mutation is an implementation
detail that does not break it as long as nothing outside the inputs is read.
**Rejected.** Advancing on render/`delta`; immutable copy-per-step (correct but
needless allocation pressure for a single-machine sim).

### AD-005 · Floats now; fixed-point deferred — settled
**Decision.** Positions/velocities are floats for the slice.
**Why.** Tenet 1 is explicit: single-machine rollback needs only purity, for
which floats are fine. Fixed-point is only required for cross-platform *lockstep*,
which is not a slice goal. Keeping floats keeps rollback open without paying the
fixed-point tax now.
**Rejected.** Fixed-point from day one — premature; a deterministic-math decision
to revisit only if lockstep becomes a real goal (the tenet's call, not mine).

### AD-006 · Move/frame data authored as `.tres` Resources against a documented schema — settled
**Decision.** Moves are Godot custom `Resource` (`.tres`) files conforming to a
schema the Architect owns. Timelines are **keyframed frame-ranges**, not
per-frame arrays.
**Why.** Engine-native, editor-authorable, serializable, and text-diffable for
QA golden files. Authoring move data never touches engine code. Frame-ranges are
compact and authorable while still resolving to exact per-frame truth.
**Rejected.** Pure JSON (more tool-agnostic but off the engine's native
authoring/serialization path); per-frame arrays (verbose, error-prone to author).

### AD-007 · One state-machine pattern for every character — settled
**Decision.** A small fixed set of engine-level state *categories*
(grounded/airborne/hitstun/blockstun/etc.) governs physics and legal
transitions; per-move specifics live in data. Every character uses this one
pattern.
**Why.** Consistency is the Architect's whole value — one pattern is what keeps
twenty features feeling like one game and lets the move format generalize to
character B without becoming "A-shaped."
**Rejected.** Per-character bespoke state machines (drift engine; defeats the
content seam).

### AD-008 · One canonical advantage formula, computed in one place — settled
**Decision.** Advantage = `defender_remaining_stun − attacker_remaining_recovery`,
computed each tick in a single function and surfaced through the inspection
surface. Neutral is "restored" when both players are actionable.
**Why.** The charter's legibility promise and the brief both demand that "what
hit, what whiffed, who's plus" is observable and *consistent*. One formula in one
place is the only way two characters can't disagree about what advantage means.
**Rejected.** Per-move or per-character advantage handling (the canonical drift
the Architect exists to prevent).

### AD-009 · Fixed intra-tick phase order — settled
**Decision.** Each tick runs a fixed phase order: inputs → state-machine /
buffering / cancels → movement integration → box overlap detection → hit
resolution → advantage/neutral update → advance counters.
**Why.** Determinism requires a defined resolution order; the debug mode narrates
exactly this order, so pinning it serves both correctness and legibility.
**Rejected.** Ad-hoc per-system update order (non-deterministic interaction
outcomes; nothing for the debug readout to anchor to).

### AD-010 · Hitstop is in-state, not a loop pause — settled
**Decision.** On hit/block, affected counters freeze for N frames *within* state;
the sim loop keeps ticking. Frame-step works across hitstop.
**Why.** A paused loop would break frame-stepping, rollback, and the
"everything advances purely from (state, inputs)" contract.
**Rejected.** Halting the tick loop during hitstop.

### AD-011 · The read-only inspection surface is the systems/content seam — settled
**Decision.** A read-only accessor layer over sim state is the single interface
the debug mode, QA harness, and player-facing UI all read through. None reach
into sim internals; nothing mutates state through it.
**Why.** The seam must be an interface, not a guess (role + roadmap). Making it
read-only and shared means the debug mode and the determinism/golden harness
can't disagree about sim truth, and a later systems/content split is painless.
**Rejected.** Letting UI/debug read sim internals directly (couples player-facing
code to sim layout; the seam stops being a real boundary).

### AD-012 · Our own AABB overlap; engine physics solver owns nothing — settled
**Decision.** Hit/hurt/push overlap is our own AABB test inside the fixed step.
No RigidBody/CharacterBody integration advances gameplay state.
**Why.** Tenet 1. 2D box overlap is trivial and fully controllable/serializable;
the engine solver is neither.
**Rejected.** Godot physics bodies for combat (non-deterministic, non-serializable
gameplay state).

### AD-013 · Engine code lives under `/game` at repo root — settled
**Decision.** The Godot project tree is `/game`; `/docs` stays purely
coordination artifacts.
**Why.** Clean separation of the build from its substrate. The protocol leaves
this path to the Architect; recorded here as the canonical call.
**Note.** The protocol table's engine-path slot should mirror this — raised to
the Strategist (see `flags.md`).
