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

### AD-004 · Fixed 60 Hz tick; `step` is pure and does not mutate its input — settled (revised 2026-06-27, Consultant flag)
**Decision.** All gameplay advances on a fixed 60 Hz tick inside
`physics_process`, off our own tick counter in state. `step(state, inP1, inP2)`
is a pure function of `(prev state, two inputs)` and **must not mutate its input
state** — it writes the next state into a *distinct* state object. Buffer reuse
is allowed (a state no longer live may be recycled as the output buffer), so this
is not per-tick allocation churn.
**Why.** Tenet 1 + Tenet 3: the slice exists to *prove* determinism, so purity
must be structurally verifiable, not upheld by discipline. With non-mutation,
`prev` is provably untouched after `step` (`hash(prev)` unchanged), turning a
purity violation into a cheap standing assertion instead of a bug found only when
a golden/determinism test happens to hit the offending path. At slice scale the
cost is negligible.
**Rejected.** In-place mutation of the input (fast, but purity checkable only by
discipline — the earlier stance, now overturned). Fresh allocation every tick
(unnecessary once non-live buffers are recycled).

### AD-005 · Fixed-point sim math from the start — settled (revised 2026-06-27, user directive)
**Decision.** Positions, velocities, and all gameplay math in `SimState` use a
fixed-point integer representation (see AD-014), not floats. Floats appear only
in the *view* (fixed→float for rendering).
**Why.** The user elected not to defer this. Tenet 1 framed fixed-point as the
bar for cross-platform *lockstep* and optional for single-machine rollback; doing
it now *exceeds* the minimum bar rather than violating it, and clears lockstep's
hardest obstacle while the sim is still small and cheap to get right. For a
box-based 2D fighter it does not seriously raise scope: AABB overlap and movement
are integer add/compare, and the slice needs no transcendental math.
**Supersedes.** The prior "floats now, fixed-point deferred" stance.
**Rejected.** Floats now (keeps rollback open but leaves lockstep a later
rewrite-risk; the user judged the pull-forward cost low enough to take now).

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

### AD-008 · One advantage computation: a pinned static number and a live readout — settled (revised 2026-06-27, Consultant flag)
**Decision.** One function computes `defender_remaining_stun −
attacker_remaining_recovery`, but two clearly-distinct values are surfaced:
- **Static move frame-advantage** (frame data / UI): computed at a *pinned
  reference frame* — contact on the move's **first active frame**, attacker
  **uncancelled**. The conventional on-hit/on-block number; a property of the move.
- **Live advantage** (training-mode per-tick): the same formula where
  `attacker_remaining_recovery` is the attacker's *actual* frames-to-actionable
  in the current situation, **including any committed cancel**. The truthful
  "who is plus right now."

So `attacker_remaining_recovery` is defined as actual frames-to-actionable, not
raw move-state recovery — the live number stays correct in the pressure/combo
cases legibility depends on. Neutral is "restored" when both players are actionable.
**Why.** Per-tick-only left no canonical number for content to read; raw-recovery-
only lied once a cancel shortened recovery — exactly the legibility-critical
cases. A pinned static value plus a cancel-aware live value resolves both while
keeping one formula in one place.
**Rejected.** A single number serving both roles (it can't — one is a move
property, one is situational); per-move or per-character advantage handling (the
canonical drift the Architect exists to prevent).

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
the Strategist (see `flags.md`). *(Resolved: Strategist mirrored it.)*

### AD-014 · Fixed-point convention — settled (2026-06-27)
**Decision.** One scalar fixed-point type: 64-bit signed integer, fractional
scale `2^16` (1 game unit = 65536 sub-units). Multiply = `(a*b) >> 16`, divide =
`(a << 16) / b`; a single documented rounding rule (round-to-nearest, ties away
from zero) governs anywhere a conversion rounds. A small `FP` helper owns these
ops. **No transcendental math in the sim** for the slice — velocities are authored
as vectors; no normalization / trig / sqrt. Move and physics data reach the
runtime as **baked fixed-point integers**: authoring may use friendly units, but
the float→fixed bake happens once, off the hot path, never inside `step`.
**Why.** A power-of-two scale makes multiply/divide cheap shifts; baking keeps the
runtime pure-integer and lockstep-safe; banning transcendentals removes the only
common cross-platform float-divergence source a 2D box fighter would otherwise hit.
**Rejected.** Per-tick float→fixed conversion (reintroduces float risk on the hot
path); a third-party fixed-point library (a handful of ops doesn't justify it).

### AD-015 · Cancels are a list of typed rules, not one opaque field — settled (2026-06-27, Consultant flag)
**Decision.** `MoveState.cancels` is a list of `CancelRule`s, each:
`target` (state id or tag/group), `condition` (`on_hit` | `on_block` |
`on_contact` | `on_whiff` | `always`), `window` (frame range within the move;
default first-active→end), `input` (required command), `requires_tag` (optional
cancel tag). Move classes fall out of this: gatling/chain = `on_contact` to
another normal within a window; special-cancel = `requires_tag` granted by the
connecting hitbox; whiff-cancel = `on_whiff`. Rehit/multi-hit is **not** a cancel
(AD-016).
**Why.** A single field carrying gatling/special/whiff semantics had no model;
it was neither authorable nor auditable consistently. A typed rule list makes each
cancel class explicit and the format generalizable.
**Rejected.** Keeping the opaque field.

### AD-016 · Multi-hit and throw resolution models — settled (2026-06-27, Consultant flag)
**Decision.**
- **Multi-hit.** Two authorable forms: (a) *sequential* — distinct hitboxes in
  distinct `id_group`s across timeline keyframes, each landing once; (b)
  *cadenced rehit* — a hitbox with `rehit_interval` (frames) lets the same
  `id_group` hit the same target again after the interval. `id_group` still
  guarantees one hit per group per contact.
- **Throws.** A throwbox overlapping a throwable hurtbox connects and **bypasses
  blockstun** (throws are not blocked). A defender input within a **tech window**
  (defined frames after the throw connects) techs it (both pushed to neutral).
  Simultaneous ground throw attempts within the tech window resolve as a tech
  (clash). **Deferred, explicitly:** air throws and formal throw-vs-throw priority
  — not in the slice's two grounded movesets; the throwbox / `invuln` /
  air-eligibility fields leave the door open (Tenet 3).
**Why.** The format had no answer for two common move classes; this gives
multi-hit a model and throws a real connect/tech path without overbuilding what
the slice won't use.
**Rejected.** Leaving both unstated (a contract gap a developer would invent at
the keyboard).

### AD-017 · Cancel timing across hitstop, and the grant→consume latency — settled (2026-06-27, Consultant flag)
**Decision.** During hitstop a character is frozen: `frame_in_state` / `stun` do
not advance (AD-010) and **no cancel transition executes**. Inputs are still
recorded each tick (phase 1 always runs), so a cancel may be *buffered* during
hitstop and **executes on the first unfrozen tick**. `cancel_tags` granted in
phase 5 of tick T become available to the cancel phase (phase 2) starting tick
**T+1**; this one-tick grant→consume latency is intentional and uniform (a hit's
cancel window opens the frame after contact).
**Why.** These were unstated, feel-defining decisions. Freezing cancels during
hitstop keeps hitstop a true freeze while preserving buffering; the one-tick
latency is an inherent, consistent consequence of the fixed phase order (AD-009),
not an accident.
**Rejected.** Executing cancels mid-hitstop (breaks freeze semantics); same-tick
grant→consume (impossible under the phase order without a second pass).

### AD-018 · Slice uses three attack buttons (count at input layer, labels above it) — settled (2026-06-27, routed by Strategist via character-A brief)
**Decision.** The slice's input representation carries **three attack buttons**
(`BUTTON_0/1/2`), used by every character and every input source. The *count* is
fixed at the input-contract level; the **L/M/H labels and button→move mapping live
above the input layer** (character `button_map`), keeping the input layer
semantically blank (AD-002). `BUTTON_3+` reserved for post-slice.
**Why.** Character A surfaced "Light/Medium/Heavy, no punch/kick divide," but a
button *layout* is a system-level fact (replays, netcode, the dummy, and both
characters must agree on how many buttons exist), not a character-local one.
Pinning the count while keeping meaning in the mapping layer reflects it
system-wide without violating AD-002's dumb-input-layer rule.
**Rejected.** Naming L/M/H inside the input bitfield (couples the input layer to
move semantics — AD-002 violation); leaving the count to each character (sources
couldn't agree on the input shape).
