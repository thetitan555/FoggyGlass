# Architecture Decisions

> Owned by the **Architect**. A running record of the load-bearing calls behind
> the spec: what was decided, why, and what was rejected. A Developer or QA
> should be able to learn *why* the architecture is the way it is without asking.
> Append-only in spirit; supersede an entry rather than silently rewriting it.

Status legend: **settled** (agreed, build against it) · **provisional** (in
effect but expect revision) · **superseded** (kept for history).

## Index (read this; pull full entries below on demand)

- **AD-001** State is data; the scene tree is a view — settled
- **AD-002** Dumb input layer: raw, frame-indexed bitfields — settled
- **AD-003** Buffering and SOCD resolve sim-side — settled
- **AD-004** Fixed 60 Hz tick; `step` is pure, non-mutating — settled (revised)
- **AD-005** Fixed-point sim math from the start — settled (revised)
- **AD-006** Move data as `.tres` Resources against a schema — settled
- **AD-007** One state-machine pattern for every character — settled
- **AD-008** One advantage formula; static + live values — settled (revised)
- **AD-009** Fixed intra-tick phase order — settled
- **AD-010** Hitstop is in-state, not a loop pause — settled
- **AD-011** Read-only inspection surface is the systems/content seam — settled
- **AD-012** Our own AABB overlap; engine physics owns nothing — settled
- **AD-013** Engine code lives under `/game` — settled
- **AD-014** Fixed-point convention: 64-bit, scale 2^16, no transcendentals; `FP` packaging, two extractors, `mul` magnitude budget — settled
- **AD-015** Cancels are typed `CancelRule` lists — settled
- **AD-016** Multi-hit and throw resolution models — settled
- **AD-017** Cancel timing across hitstop; T+1 grant→consume — settled
- **AD-018** Three attack buttons at input layer; labels above it — settled
- **AD-019** Inspection surface fixed-point only; px is render-only — settled
- **AD-020** Reset restores sim state + playback position — settled
- **AD-021** Projectiles are first-class serialized sim entities — settled
- **AD-022** Input buffer: 9f motion window, 6f command buffer — settled
- **AD-023** Canonical state hash: ordered FNV-1a over an integer value stream — settled
- **AD-024** Inspection-backing SimState fields + `MoveRegistry` authored-data model — settled
- **AD-025** `neutral_restored_this_tick` is a rising edge — settled
- **AD-026** Single-hit across active frames via per-attacker `active_hit_ids` — settled
- **AD-027** AABB overlap is strict (touching edges do not overlap) — settled

## Phase-pipeline latitude ratifications (JC-013..021)

These P0-06/07 judgment calls were ratified as *internal latitude* — correct
builds of what the spec already decided, folded here (or ruled test-only) rather
than adding contract surface. Full reasoning lives in `judgment-log.md`; this note
records the disposition so future work inherits it. **JC-013** phase pipeline as a
`StepPhases` all-static module, one named function per AD-009 phase (packaging;
`step`'s signature unchanged; the named-function order is what criterion 2's
reorder-to-fail test points at). **JC-014** a freshly-entered state sits on
`frame_in_state = 1` the entry tick and phase 2 skips the advance for a same-tick
entry (the unique 1-indexed reading where a move's first authored frame is neither
skipped nor doubled; ties to JC-011/JC-019). **JC-016** damage scaling is one
`DamageScaling` definition; the specific 10%-step/10%-floor numbers are
slice-provisional placeholder tuning (the *mechanism* is AD-008/combat-resolution
contract; the numbers are the Strategist's to set via the spec — the done-bar's
single hit is hit-count-1 ⇒ 100% ⇒ unscaled, insensitive to the table). **JC-017**
pushbox mutual separation splits the overlap in half with the odd remainder to P1
(deterministic exact-integer pushout; sub-pixel at FP scale; movement-only, no feel
value beyond "characters don't overlap"). **JC-019** a looping state wraps
`frame_in_state` modulo duration; a stun-category state *clamps* at duration (keeps
the resolved keyframe range valid through a stun that outlasts the reaction's
authored span — needed for the defender to stay a valid combo target, TKT-P0-09).
**JC-020 / JC-021** test-only fixes (hitstop countdown expectation 3→2 against the
sim's own post-step value; `Callable(StepPhases, name).is_valid()` for static-module
phase-presence checks) — no sim code touched, pure test latitude. **JC-015** and
**JC-018** were contract-adjacent and are ratified into owned rules — see AD-015
note / AD-025 respectively.

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

### AD-014 · Fixed-point convention — settled (2026-06-27; elaborated 2026-07-02, TKT-P0-01 ratifications)
**Decision.** One scalar fixed-point type: 64-bit signed integer, fractional
scale `2^16` (1 game unit = 65536 sub-units). Multiply = `(a*b) >> 16`, divide =
`(a << 16) / b`; a single documented rounding rule (round-to-nearest, ties away
from zero) governs anywhere a conversion rounds. A small `FP` helper owns these
ops. **No transcendental math in the sim** for the slice — velocities are authored
as vectors; no normalization / trig / sqrt. Move and physics data reach the
runtime as **baked fixed-point integers**: authoring may use friendly units, but
the float→fixed bake happens once, off the hot path, never inside `step`.

**Helper packaging (ratified from JC-001).** The `FP` helper is a named class of
all-static methods (`FP.mul(a,b)`, `FP.div(a,b)`, etc.) — no instance state, never
instantiated, no autoload/global. The `FP.op()` call convention is the intended
call site.

**Extractors and which ops round (ratified from JC-002).** Two distinct
extractors, both binding on all callers:
- `round_to_int` applies the one rounding rule above (round-to-nearest, ties away
  from zero). This is the rule for **conversions that round**.
- `to_int` **truncates toward zero** (drops the fraction; `-1.9 → -1`, symmetric
  with `1.9 → 1`). This is for callers that want plain fraction-drop, e.g.
  whole-cell indexing.

`mul`, `div`, and the float→fixed bakes all apply the rounding rule.
**Prohibited:** arithmetic-shift "truncation" (`>>` floors toward −∞ for
negatives) is *not* an allowed third behavior — no caller may reintroduce it.

**`mul` operand-magnitude budget (ratified from JC-003).** `FP.mul` computes the
64-bit product `a*b` before the `>> 16` shift with **no widening or guard**. This
is correct while the *game-unit* product stays inside the signed-64 headroom:
`|a_units * b_units| < 2^31` (each operand safely up to ~46340 game units when the
other is comparable). This is the guaranteed magnitude contract. The slice's sim
values (stage-bounded positions/velocities, box dimensions — all under ~10^3 game
units) sit orders of magnitude inside the budget, so no guard is warranted now.
**Escalation trigger:** if any sim value ever approaches this budget, widening the
intermediate (128-bit or split-multiply) is a **revision to this AD**, not a
silent code change — the magnitude guarantee lives in this owned contract so QA
can assert against it, not in a method comment.

**Why.** A power-of-two scale makes multiply/divide cheap shifts; baking keeps the
runtime pure-integer and lockstep-safe; banning transcendentals removes the only
common cross-platform float-divergence source a 2D box fighter would otherwise hit.
Naming truncation and rounding as separate extractors keeps "which rule applied"
explicit at every call site; stating the `mul` magnitude budget makes the
unguarded product a *known, asserted bound* rather than a latent overflow.
**Rejected.** Per-tick float→fixed conversion (reintroduces float risk on the hot
path); a third-party fixed-point library (a handful of ops doesn't justify it);
128-bit/split-multiply `mul` now (correct at any magnitude but slower and
unjustified inside the stated budget — deferred to the escalation trigger above);
a single extractor (loses the truncation callers need); saturating-clamp `mul`
(hides overflow rather than surfacing it).

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

### AD-019 · Inspection surface is fixed-point truth only; pixel projection is render-only — settled (2026-06-27, Consultant flag)
**Decision.** The snapshot-able inspection surface carries only fixed-point integer
truth — no float fields. Pixel coordinates are a deterministic render-only
projection (fixed→px) computed for drawing and **excluded from every
golden/determinism snapshot**.
**Why.** QA golden-files and the UI read the *same* surface (AD-011). If a snapshot
included `_px` floats, cross-platform float drift (Tenet 1) could break goldens —
defeating the very harness the surface exists to serve. Splitting truth (snapshot)
from projection (render) keeps one surface while keeping snapshots float-free.
**Rejected.** Keeping `position_px`/`rect_px` as surface fields (puts floats in the
golden set); a second parallel surface for QA (two sources of truth — the thing
AD-011 forbids).

### AD-020 · A training-mode reset restores sim state *and* input-source playback position — settled (2026-06-27, Consultant flag)
**Decision.** The reset point captures both the sim `StateBlob` and the playback
position of each `RecordPlaybackSource`; `do_reset()` restores both, so a recorded
sequence replays **in sync** with the rep (the default and only slice behavior).
Independent/"metronome" playback (reset sim but keep the dummy rolling) is
explicitly out of slice scope — add only if later wanted.
**Why.** The playback cursor lives outside `SimState` (sources are external,
Tenet 2), so restoring `SimState` alone desyncs the dummy and breaks the core
training-rep loop. The fix lives in the **training-mode harness**, which sits above
the sim and owns both the runner and the sources — so it coordinates "restore
snapshot + rewind cursor" as one operation. The sim still knows nothing about
sources, so **Tenet 2 holds** (no tenet change; considered and ruled clear). The
frame-indexed `InputSource` contract (`input.md`) makes the rewind natural:
restoring the tick re-queries the same frames.
**Rejected.** Resetting `SimState` only (desyncs the dummy); pushing the cursor
into `SimState` (would make the sim own source state — Tenet 2 violation).

### AD-021 · Projectiles are first-class serialized sim entities — settled (2026-06-27, surfaced by character A's fireball)
**Decision.** A projectile (e.g. character A's fireball) is a sim entity in
`SimState.projectiles[]`, not a hitbox attached to a character. It is spawned by a
**`spawn` keyframe action** in the move data, carries its own fixed-point position
/velocity and hit data, integrates and resolves in the fixed phase order like a
character's boxes, and is consumed on hit/block or when its lifetime ends. The
slice caps **one live projectile per owner** (classic shoto fireball). Projectiles
are exposed through the inspection surface like any other sim truth.
**Why.** A character's move boxes are attached to the character and live only
during active frames; a fireball is *detached* and *persists* independently —
travelling after the move recovers. That's a different lifetime and ownership, so
it needs to be its own serialized entity. Doing so keeps determinism and
serialization intact (it's just more state in `SimState`) and is `build-for-
extension` (Tenet 3): B's tools, supers, traps reuse the same entity.
**Scope.** Projectile-vs-projectile interaction is deferred (no slice character
needs it yet); the field set leaves it open. **Mine to add** — I own the move
format and the `SimState` shape, and this touches no tenet.
**Rejected.** Modeling the fireball as a long-lived character hitbox (can't
out-live recovery or move independently of the character); a bespoke fireball
system (a projectile entity generalizes; a one-off doesn't).

### AD-022 · Input buffer: motion leniency + command buffer — settled (2026-06-27)
**Decision.** Buffering is sim-side (AD-003), evaluated each tick over
`input_history`. Two slice-wide windows:
- **Motion window = 9 frames.** A motion's directional sequence (e.g. `236`,
  `623`) is recognized if its directions occur in order within the last 9 frames.
- **Command buffer = 6 frames.** A recognized command (special, throw, or a
  special-cancel) is held up to 6 frames and **executes on the first frame the
  character is actionable** (reversal on wakeup / after blockstun / after hitstop)
  **or the first frame a cancel window opens** (special-cancel leniency).

Same windows for every character and every input source.
**Why.** The brief's reversal-on-wakeup and the link/cancel game need fair,
consistent leniency; frame-perfect-only inputs would be unfair and off-genre. One
system buffer keeps it uniform and deterministic (a pure function of
`input_history`, so replays/netcode reproduce it for free — Tenet 2).
**Rejected.** Per-character buffers (drift — the thing the Architect prevents); no
buffer (frame-perfect reversals; punishingly inconsistent); buffering in the input
source (AD-003 — would diverge across sources).

### AD-023 · Canonical state hash: ordered FNV-1a over an integer value stream — settled (2026-07-02, ratified from JC-007)
**Decision.** `SimState`'s canonical hash — the primitive every determinism /
round-trip / purity acceptance criterion (simulation.md 1/2/3) is verified through,
and the primitive QA's golden/determinism harness (TKT-P0-11) standardizes on — is
defined as a **deterministic function of the state's data alone**, with these
binding properties:
- **Fixed field order.** Fields are folded in an explicit, source-fixed order —
  never Dictionary key-iteration order.
- **Integer stream only.** Only the state's integer values are folded (the state is
  float-free by AD-005/AD-019; no float ever enters the hash).
- **Order-committing.** A count/size separator is folded before every
  variable-length run (the players list, each `input_history`'s frames, the
  projectile list) so a regrouping of the same bytes cannot collide.
- **Total coverage.** Every field present in `to_dict` is covered by the hash (the
  hashed key set equals the serialized key set).
- **Chosen algorithm.** 64-bit **FNV-1a**, byte-at-a-time, low byte first, over that
  ordered integer stream. GDScript ints are 64-bit two's-complement and wrap on
  overflow, matching FNV's mod-2^64 arithmetic; the per-byte extraction (`>>` then
  `& 0xFF`) yields the true two's-complement byte for negative values.
- **Prohibited.** Godot's built-in `hash()`, `var_to_bytes(...).hash()`, or any hash
  that depends on Dictionary iteration order or Godot's internal serialization —
  none are documented as stable across engine versions/platforms, and instability
  there would break QA goldens for reasons unrelated to sim state (the exact failure
  AD-019 guards against for pixel floats).
**Why.** The purity/determinism/round-trip proofs lean *entirely* on the hash being
a function of the state's DATA, not of object identity or map ordering. Making the
canonicality properties an owned contract — not a code comment — lets QA assert
against them and lets any future re-derivation of the hash (a different language, a
rollback re-sim host) reproduce the *same* value. The specific algorithm is pinned
because the harness must agree byte-for-byte on one hash; a second implementation
that satisfies the properties above but produces different bytes is still a break.
**Rejected.** Leaving the algorithm a provisional dev latitude call (QA's harness
depends on it — it is a contract, not latitude); `var_to_bytes(to_dict()).hash()` /
Godot `hash()` (order/stability-dependent, per Prohibited above).
**Note.** If QA (TKT-P0-11) needs to revise the algorithm for harness reasons, that
is a revision to *this AD*, not a silent code change — the canonical hash is one
owned definition both sides read.

### AD-024 · Inspection-backing SimState fields + `MoveRegistry` authored-data model — settled (2026-07-03, ratified from F-002 + F-004)
**Decision.** Two related contract questions the P0 batch-1 build surfaced —
*what serialized state backs the inspection surface*, and *how the pure `step`
reaches authored move data* — are settled together because they share one
principle (mutable sim truth lives in `SimState`; fixed authored content does not).

- **Inspection-backing fields (F-002).** The reads the inspection surface requires
  are backed by serialized `SimState` fields, ratified into the tables in
  `simulation.md`: `players[i].character_id` (int), `players[i].stun_kind`
  (int 0/1/2), the combo triple `combo_hits` / `combo_scaling` (FP multiplier) /
  `combo_damage` (whole units, backs `PlayerView.combo.damage_total`),
  `SimState.last_hit` (a plain `HitRecord` or null — the sim-side truth the
  `HitEvent` view projects), and `SimState.neutral_restored_this_tick` (bool —
  see AD-025). All are serialized (`to_dict`/`from_dict`, `last_hit` null ⇒
  empty-dict marker), deep-cloned, and covered by the canonical hash: `last_hit`
  is folded behind a presence flag (0/1) so no-hit vs. hit states cannot collide,
  and its integer fields fold in a fixed `HASH_FIELDS` order — this is `last_hit`'s
  canonical-hash treatment under AD-023's total-coverage requirement.
- **Authored-data model (F-004).** `step` resolves authored move data through a
  **process-wide immutable roster** (`MoveRegistry`), installed once at
  match/scenario/test wiring and never mutated mid-run — model (a). `step`'s
  signature stays exactly `(state, in_p1, in_p2)`; the roster is *not* threaded
  through it. `players[i].character_id` is the resolution key.

**Why.** The inspection contract already *implied* these reads; naming their
serialized shape in the owned table (not leaving them an implementation accident)
is what lets QA golden them and future systems build against them. The registry
model keeps `step`'s signature the `simulation.md` contract, matches AD-001
("SimState is the minimal *mutable* graph — authored content is not sim state"),
and mirrors how input *sources* live outside `SimState` (Tenet 2): authored
content is a fixed input to the whole sim, carries no per-tick state, so
snapshot/restore/replay reproduces identically. Settling both together records the
shared bar — *mutable* truth in state, *fixed* content out of it — that governs
future table additions (see `simulation.md`, "extensible-as-systems-land").
**Rejected.** Threading the roster through `step` as a parameter (model (b) — makes
the data dependency visible in the signature, but changes the `simulation.md`
contract signature for no determinism gain; the immutable-roster invariant gives
the same guarantee). Re-deriving inspection reads on the fly without backing state
(the values — combo totals, last hit, stun kind, neutral edge — are genuine
mutable sim truth that must survive snapshot/restore and be hashed; deriving them
would either lose them across restore or duplicate logic).
**Risk (recorded).** A process-wide static roster is global state: a mis-wired or
mid-run-mutated roster is a determinism hazard the type system does not prevent.
Mitigated by contract — `install` is documented once-at-wiring, `clear` is
test-only isolation. QA should assert the roster is installed before the first
`step` and unchanged across a run.

### AD-025 · `neutral_restored_this_tick` is a rising edge — settled (2026-07-03, ratified from JC-018)
**Decision.** `SimState.neutral_restored_this_tick` is set true by phase 6 on
exactly the tick the pair *transitions* to both-actionable:
`both_actionable(post-phase-5 state) AND NOT both_actionable(step's input state)`.
The pre-step condition is read from `step`'s **input** state — which *is* last
tick's state — so the edge needs no extra serialized field. The flag is true on
exactly the transition tick and false every other tick, including match start
(both were already actionable the prior tick, so no rising edge fires).
**Why.** `combat-resolution.md` criterion 5 requires the flag "exactly on the tick
both players become actionable — not before, not after." "Become actionable" *is*
a rising edge; flagging whenever both are actionable would fire every tick after
neutral returns (violates "not after"). Using the input state as the prior
condition keeps `SimState` minimal (AD-001) — no stored "was-neutral-last-tick"
field — since the input state already carries last tick's actionability.
**Rejected.** Flagging on the level (both-actionable), not the edge (fires every
subsequent tick); storing a separate prior-condition field (redundant — the input
state already is last tick's state); comparing against post-phase-7 counters
(shifts the edge by one tick, off by the counter decrement).

### AD-026 · Single-hit across active frames via per-attacker `active_hit_ids` — settled (2026-07-03, ratified from F-005)
**Decision.** "One hit per `id_group` per contact" (AD-016) across a multi-frame
active window is enforced by per-attacker memory of the `id_group`s that have
already connected during the *current* move: `players[i].active_hit_ids`
(`PackedInt32Array`), serialized/cloned/hashed as a variable-length run
(count-then-ids, order-committing per AD-023). A hitbox whose `id_group` is present
does not re-hit. The set is **cleared on every state entry** — a new move is a new
contact. Cadenced re-hit (`rehit_interval` > 0, AD-016) consults this same memory
with an interval (TKT-P0-09); with `rehit_interval` unset it stays populated for
the move's life ⇒ one hit per contact.
**Why.** A hitbox is active for its whole active window (and every frozen hitstop
tick); without per-attacker memory the same hitbox re-connects every active frame,
registering 2–3 hits and inflating the combo — which would break the done-bar's
"one hit" assertion. The memory must be *serialized state* so the single-hit
decision survives snapshot/restore and is deterministic (hashed). Per-attacker and
cleared-on-state-entry is the minimal correct scope: the group identity is
per-attack, and a fresh move is definitionally a fresh contact.
**Rejected.** Keying single-hit on the `last_hit` record (couples per-target
tracking to one global last-hit; wrong for simultaneous/multiple groups); a
per-move-instance token not in serialized state (would not survive restore — a
determinism hole); no memory (re-hits every active frame — the defect above).

### AD-027 · AABB overlap is strict; touching edges do not overlap — settled (2026-07-03, ratified from F-003)
**Decision.** The AABB overlap test (AD-012, our own integer box test) is
**strict**: boxes that merely *touch* — share an edge, e.g. `a.x + a.w == b.x` —
do **not** overlap. `ResolvedBox.overlaps` uses strict `<` / `>` on all four
edges. A hitbox exactly adjacent to a hurtbox does not register a hit.
**Why.** This is the common fighting-game convention and a hit/no-hit resolution
rule multiple roles build against (content authoring, QA goldens on hitbox
geometry). Left unpinned it is determinism- and feel-relevant and could read
materially differently between implementations, so it is an owned rule, not an
implementation accident. Strict adjacency keeps exact-touch from counting as a
connect, matching how box geometry is authored (a hitbox reaching *to* a hurtbox's
edge has not yet reached *into* it).
**Rejected.** Inclusive overlap (touching counts as a hit) — a legitimate
alternative for feel, but off-convention and would make exact-adjacency author
into surprise connects; if feel ever wants it, it is a one-line change in
`ResolvedBox.overlaps` and a revision to this AD, not a silent code change.
