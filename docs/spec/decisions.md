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
- **AD-028** Buffer/cancel + throw/rehit mutable SimState fields (TKT-P0-08/09) — settled
- **AD-029** Dedicated `HitBox.tech_window` field; throw tech-window is not `blockstun` reuse — settled
- **AD-030** Projectile authored format: `ProjectileData` + `ProjectileRegistry`; runtime `data_id`; spawn timing — settled
- **AD-031** Invulnerability consumed in phase 4; `HitBox.hit_kind` gates strike/throw/projectile; whiff is observable — settled
- **AD-032** Command schema extension: pure-direction command + two-button chord; first-match-wins shadowing rule — settled
- **AD-033** Air-normal height-dependent advantage: phase-5 `AirHeightScaling` on hitstun; contact-depth read — settled
- **AD-034** Serialization carries a top-level format-version field (`"v":1`, absent⇒1, unknown⇒fail; not hashed) — settled
- **AD-035** Render-framing contract: sim world projects into the viewport via a render-only camera transform (extends AD-019) — settled
- **AD-036** No runtime ground clamp yet; a `pos_y ≥ ground_y` clamp + ground-contact landing is deferred defense-in-depth; interim guard is the net-zero-arc authoring invariant — provisional (deferred)
- **AD-037** Vertical convention: up is −Y everywhere (world + character-local, one shared axis); feet-origin at `pos_y = ground_y`; the box-authoring Y-inversion is a DATA bug (reflect across the feet line), the render is correct — settled
- **AD-038** Held-input looping-state exit: an actionable character in a looping state re-derives its state from input each tick, falling back to idle when no command matches (walk/crouch return to idle on release); stance selection reads CURRENT-tick input (not the command buffer) so release exits promptly, while discrete commands keep AD-022 buffer leniency — settled (2026-07-10 exit-lag correction)
- **AD-039** Airborne-action model: directional/diagonal jumps via per-direction prejump lead-ins; air normals reached by jump-state cancels — data-only, no engine change — settled

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

## Buffer/cancel + throw/rehit latitude ratifications (JC-022..027)

The P0-08/09 judgment calls, disposed at the batch-2 ratification pass (2026-07-03).
Full reasoning is in `judgment-log.md`; this records the disposition. **JC-022**
motion recognition = greedy ordered-token scan over the 9-frame window (AD-022) with a
one-place motion-id→token-sequence table — ratified as *latitude*: implements AD-022's
stated in-order-within-window semantics, no serialized recognizer state (buffering is a
pure function of `input_history`, AD-003), no contract surface. The 9-frame *window* is
the owned feel value (AD-022); the scan and token table are implementation. **JC-023** a
`CancelRule.input` resolved via the `button_map` entry whose target == the rule target
(raw-button fallback), through the one `InputBuffer` recognizer; group targets deferred —
ratified as *latitude*: single-recognizer routing so a cancel and a neutral transition
into the same state agree, no new namespace or contract; deferring group targets matches
AD-016's "leave the field, don't build the unused path." **JC-025** rehit cadence via the
parallel `active_hit_frames` run + produced-tick comparison, clash on both-throwboxes-
connect-same-tick — ratified as *latitude*: implements AD-016's stated cadence/clash with
the minimal serialized shape; the `active_hit_frames` *field* is the owned contract
addition (AD-028), this call is the logic that consumes it. Produced-tick (not
`frame_in_state`) comparison is the freeze-correct reading across hitstop. **JC-026 /
JC-027** the cancel-gate test fix — JC-026 was insufficient (its committed-window
isolation still let the 6-frame command buffer carry a held BUTTON_1 across LIGHT's
recovery boundary into SPECIAL via the *neutral* path, misread as a leaked cancel) and is
**superseded** by JC-027, which proves the tag gate by a whiff-vs-hit *contrast* asserted
at a fixed non-actionable frame (never reaching the actionable frame, so the neutral-press
path is provably unreachable) plus a positive control — ratified as *test-only latitude*
(no sim code touched; the gate was spec-correct throughout). **JC-024** the throw
tech-window schema — **overturned** as the durable shape and folded into an owned format
decision: the `blockstun` reuse is replaced by a dedicated `HitBox.tech_window` field
(AD-029); the Developer migrates authoring + the read off `blockstun`.

## P1 latitude ratifications (JC-035..043)

The P1 judgment calls (character A + training mode), disposed at the pre-audit
ratification pass (2026-07-04). Full reasoning in `judgment-log.md`; this records
the disposition. All nine **ratified** (none overturned).

- **JC-035** `HitBox.is_throw` reconciled to `hit_kind` as a computed property —
  *latitude*: pure packaging of AD-031's owned "same fact under two names"; a
  computed property makes it structurally true (one storage location) rather than
  discipline-maintained. No contract surface moves.
- **JC-036** dev-test scenarios inject a no-hitbox invuln state to isolate the
  phase-4 suppression gate — *test-only latitude*: correct isolation of the AD-031
  gate mechanism; the `2H`-vs-jump-in interaction claim is character-a.md content,
  exercised separately.
- **JC-037** `CancelEval` honors `CancelRule.input == 0` = "no input gate" —
  ratified **into the spec**. The `0 = none` meaning was already documented (in the
  class doc comment) and matches the format's sentinel conventions, but lived only
  in code — now folded into **move-format.md → CancelRule `input`** and **AD-015**
  (see above). Verified a genuine no-op for every other authored cancel (PREJUMP is
  the sole `input == 0` cancel in the codebase).
- **JC-038** PREJUMP's ALWAYS-cancel window moved `[4,4]`→`[3,3]` — ratified **with
  a spec note; the off-by-one ruled INTENDED**. `is_actionable` (`>= duration`) and
  the move-ended check (`> duration`) straddle by one frame *by design*:
  `frames_to_actionable` returns `0` on the `== duration` frame, so the two agree
  and every advantage read (AD-008) stays consistent — flipping to `>` would desync
  them. Because phase 2's fixed priority runs the actionable/buffered-command branch
  before the cancel branch, an ALWAYS-cancel whose `window_end == duration` is
  unreachable on its own last frame — a general **authoring hazard** now documented
  in **combat-resolution.md → "Stun & actionability"** and **move-format.md** (rule:
  author an input-gateless ALWAYS chaining cancel to end at `duration − 1`). The
  `[3,3]` workaround is the correct authoring; PREJUMP's authored 4f `duration` is
  unchanged. This is Architect-owned contract, not a Developer bug.
- **JC-039** `AirHeightScaling`'s four provisional numbers — *latitude*: exactly the
  numbers AD-033 names as the Developer's to pick (mechanism-first, same bar as
  JC-016). QA goldens ordering/floor/observability, not the curve.
- **JC-040** view/(pure)view-model split adopted as a **project-wide UI
  convention**: player-facing overlays are a thin Node-based view (`_draw()`/
  `Label.text`, `set_source`, `@onready` paths) backed by a static, Node-free
  `*Model` that does all `InspectionView` reads and produces plain display data; the
  model is headlessly unit-tested, the view is a thin, visually-QA'd render layer.
  This is the seam discipline the Architect brief wants (player-facing UI built
  against the read-only inspection surface, never reaching into sim internals) made
  structural. **Future P2 UI follows this pattern.** (The batch-recovery finding —
  nothing to reconcile; `main.gd`/`main.tscn` are unmodified P0 scaffold — is
  verification latitude.)
- **JC-041** missing `.tscn` scenes built + overlays auto-wired by duck-typed
  `set_source` — *latitude*: required infrastructure to make the mode runnable
  (training-mode.md's point); auto-wire keeps the shell the one wiring place without
  a shared base type. Scene-wiring only, no contract surface.
- **JC-042** projectile hitbox given its own draw color instead of a
  `hit_kind`-based `BoxView` split — *latitude*, and it correctly respects the seam:
  `BoxView.kind` (inspection-surface.md) is HURT/HIT/THROW/PUSH with no `hit_kind`
  field, and AD-031 adds `hit_kind` to the sim, not to `BoxView` — so the finer
  coding happens at the overlay's own draw-list level, not by reaching past the seam
  type. No seam change.
- **JC-043** recognized-command projection reuses the sim's own recognizer
  (`InputBuffer.entry_satisfied` over an `InputHistory` reconstructed from
  `PlayerView.input_history`) — *latitude*: single-source-of-truth extended to the
  training-mode side (no second panel-local recognizer to drift), character-agnostic
  (encodes only AD-032's generic schema), no seam field added.

## P1.1 latitude ratifications (JC-044..048)

The P1.1 judgment calls (finish-the-instrument: geometry framing, control surface,
walk wiring, jump-arc fix, serialization version), disposed at the pre-audit
ratification pass (2026-07-08). Full reasoning in `judgment-log.md`; this records the
disposition. All five **ratified** — two (JC-045, JC-047) with a narrow feel/design
sub-item *carved out and routed to the Strategist* (flags.md) rather than locked here.

- **JC-044** AD-035 render framing as a node `position`/`scale` transform on
  `GeometryOverlay` (not a `Camera2D`); placeholder constants; stage bounds as fixed
  literals — **ratified**. AD-035 explicitly names the node-transform as an accepted
  mechanism and the exact zoom/anchor/ground-line as placeholder. Folded into AD-035
  (see its ratified elaboration): (a) the world→screen framing computation is the
  **single shared world-space mapping** — a second world-space overlay reuses it, never
  re-derives (the drift AD-035's "Why" guards against); (b) hardcoded stage-bounds
  literals are acceptable **only while the stage is the fixed default** — a
  non-default/variable stage (P2) requires reading bounds through a live
  inspection-surface accessor (a `StageView`), a seam addition to make then.
- **JC-045** control-surface bindings (P/N/C/R/M/J/K/L), dummy mode-switch as one
  cycling key, InputMap-reading legend — **ratified** (keys/cycle/legend are placeholder
  latitude the ticket names). The legend correctly sits **outside** the `InspectionView`
  seam — it reads Godot's `InputMap`, not sim truth, so it is not a readout overlay and
  criterion 10's seam grep does not apply (folded as a one-line note into
  `training-mode.md`). **Carve-out:** the frame-step "unconditional passthrough, no
  auto-pause" sub-call is a UX/feel decision, **not** folded — routed to the Strategist
  (flags.md) for the human re-gate; the current binding stands provisionally.
- **JC-046** walk wiring (two pure-direction `button_map` entries → `WALK_F`/`WALK_B`,
  AD-032 pattern, listed after the standing normals) — **ratified** as correct
  move-format wiring: it is AD-032's pure-direction command shape, identical to jump,
  with the correct first-match-wins ordering (a button held with a direction still
  performs the normal). Folded: (a) `move-format.md` now names walk (bare held
  forward/back) as a **canonical pure-direction command** alongside jump; (b)
  `character-a.md` states walk is triggered by holding forward/back. **Classification
  (recorded for future dispatch wording):** `button_map` recognition wiring that routes
  to an *already-authored* state is **recognition plumbing**, distinct from authored
  move *content* (geometry/damage/timing) — the Developer correctly surfaced the
  boundary crossing rather than doing it silently. (Dispatch-boundary *wording* on a
  flag-driven fix is the Strategist's; this records only the technical distinction.)
- **JC-047** jump-arc fix (22 rise / 1 zero-velocity apex hang / 22 fall = 45, nets
  zero, both tuned speeds preserved) — **ratified** for the *correctness invariant*:
  an authored vertical arc must net to **exactly zero** displacement so the character
  lands flush (there is no runtime clamp — AD-036). Folded: `move-format.md` now carries
  the net-zero-arc authoring invariant. **Carve-out:** the specific *apex-hang feel*
  (vs. a future parabolic re-bake or an uneven fall speed) is a jump-feel decision the
  user owns — routed to the Strategist (flags.md) for re-gate confirmation; not locked
  by this ratification.
- **JC-048** serialization fail-fast (`push_error` + `return null` on an unrecognized
  `"v"`; dedicated `test_serialization_version.gd`) — **ratified** as the correct
  GDScript-idiomatic implementation of AD-034's stated fail-loudly / do-not-proceed
  behavior (GDScript has no exceptions; `assert` is stripped in release, so
  `push_error` + a sentinel return is the reliable fail-fast). Folded into AD-034:
  **`null`-return is the standing fail-fast-loader convention** for a `from_dict`-style
  loader that must reject a dict; a richer ok/error result type is a revision to make
  then, if a future migration needs structured error reporting.

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

**Defender identification for the live value (ratified from JC-012).** The live
advantage reads the CURRENT situation from state, so the **defender is the player
with `stun > 0`** (`defender_remaining_stun` is definitionally the stunned party's
count) and the attacker is the other. When **neither** is stunned there is no
interaction to read: value `0`, no plus-player. On a **trade** (both stunned — not
reachable in the slice's single-hit content, but pinned for determinism) the
defender is the player with the **greater remaining stun** (a deterministic
tiebreak so the hash is stable). Advantage is expressed from the attacker's POV
(positive ⇒ attacker plus / actionable first), matching this AD. The live value
must **not** read roles from `last_hit` — that couples a per-tick continuing
situation to the last discrete hit event, wrong once stun ticks down with no new
hit. (If a future mechanic makes role identification feel-bearing beyond the
formula's plain meaning, that is a revision here.)

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
default first-active→end), `input` (required command; **`0` = no input gate** —
the cancel is satisfied unconditionally on input, still subject to
`condition`/`window`/`requires_tag`, ratified from JC-037), `requires_tag`
(optional cancel tag). Move classes fall out of this: gatling/chain = `on_contact` to
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
**Risk, now a checkable invariant (recorded; F-009 resolution 2026-07-03).** A
process-wide static roster is global state: a mis-wired or mid-run-mutated roster is
a determinism hazard the type system does not prevent. The earlier mitigation rested
on wiring discipline plus a QA watch-item — no criterion to *assert*. That gap is now
closed the way F-001 closed produce-before-query ordering: the `MoveRegistry` exposes
an **install-generation token** (a monotonic counter bumped on every `install`/`clear`).
The owned invariant is *the token observed at a run's first `step` is identical at every
subsequent `step` of that run*; a mid-run mutation bumps it and is detectable, not
silent. Surfaced as **simulation.md acceptance criterion 11** so QA asserts the
precondition rather than only watching for it. The token is wiring/precondition state,
**not** `SimState` — it is deliberately *not* serialized or hashed (it is not mutable sim
truth; it is the fixed-content precondition AD-024 keeps *out* of state, Tenet 2 / AD-001),
but it is observable so the invariant is verifiable. `install` remains
documented-once-at-wiring; `clear` remains test-only isolation (a test that installs a
fresh roster starts a fresh run, so the per-run token capture is re-taken — the invariant
is per-run, not per-process).
**Known cost — a deliberate, slice-scoped exception (recorded 2026-07-08, F-flag resolution).**
`MoveRegistry`'s `static var _roster` + `static var _install_generation` are the **one piece
of process-wide mutable state** in an otherwise pure, serializable, per-instance design. This
is a *named, bounded exception* to that purity, not an accident to "fix":
- **The exception.** Authored roster + its install-generation token live in process-global
  static storage, shared by whatever runs in the process — not threaded through `step` and not
  held per-`SimState`.
- **Why acceptable at slice scope.** The slice runs **one sim per process** (a single training
  session / match / test scenario at a time), so a single global roster is unambiguous. Tests
  isolate scenarios with `clear()`; the install-generation token (above) makes any mid-run
  mutation *detectable* rather than silent (simulation.md criterion 11). Threading the roster
  through `step` (model (b), rejected above) would buy nothing here — there is no second
  concurrent roster to disambiguate.
- **The invariant that contains it.** Install-once, immutable-during-a-run; the per-run
  generation token observed at the first `step` is identical at every later `step` of that run.
  As long as that holds, the global is indistinguishable from a threaded immutable input.
- **What would force revisiting.** Any **concurrent/parallel sims in one process** sharing the
  static roster — e.g. a rollback host running a second speculative sim, a background/preview sim
  beside a live match, or two matches in one process — breaks the single-global assumption. At
  that point the roster must move to per-`SimState`-scoped or `step`-threaded resolution (model
  (b)); that is a **revision to this AD**, not a silent code change. The slice foreclosing none
  of this (Tenet 3) is why the token is already observable.

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

### AD-028 · Buffer/cancel + throw/rehit mutable SimState fields (TKT-P0-08/09) — settled (2026-07-03, ratified from F-010)
**Decision.** Five new *mutable, per-tick* `players[i]` fields — the sim truth the
input-buffer/cancels (TKT-P0-08) and throws/multi-hit (TKT-P0-09) systems need to
survive snapshot/restore and be canonically hashed (AD-023) — are ratified into the
`simulation.md` per-player table, in the exact shape built and validated on Godot
(all 12 test files pass):
- `cancel_tags` (`PackedInt32Array`) — cancel tags granted to this player *as
  attacker* by a connecting hitbox in phase 5 of tick T (`HitBox.cancel_tags`),
  consumable by phase 2 starting T+1 (AD-017 grant→consume latency, free because
  phase 2 precedes phase 5). Cleared on state entry.
- `move_contact` (int) — this player's current-move outcome for `CancelRule.condition`
  (AD-015): 0 none / 1 hit / 2 block / 3 whiff. Set on the attacker in phase 5; set to
  whiff once the last active frame passes with no connect. `on_contact` matches hit OR
  block. Cleared on state entry.
- `active_hit_frames` (`PackedInt32Array`) — *parallel* to `active_hit_ids` (AD-026):
  index i is the tick `active_hit_ids[i]` last connected, so `rehit_interval` cadence is
  measurable per `id_group`. Length-synced with `active_hit_ids` (appended/cleared
  together).
- `throw_tech_window` (int) — frames the thrown *defender* may still tech (AD-016). Set
  on throw connect, decremented in phase 7; not frozen (a P0 throw sets no mutual
  hitstop). 0 = not teching.
- `thrown_by` (int) — attacker index that threw this player, or -1 if not thrown. Set on
  throw connect, cleared when the window closes / the throw resolves.

All five are serialized (`to_dict`/`from_dict`), deep-cloned (`clone`), and covered by
the canonical hash (AD-023): the three `PackedInt32Array`s each fold **count-first**
(order-committing variable-length runs, exactly like `active_hit_ids`); the two plain
ints fold in fixed field order. Verified against the implemented `player_state.gd` /
`sim_state.gd` hash walk.
**Why.** Each clears the strict `SimState` bar (simulation.md, "extensible-as-systems-
land"): it is *mutable* sim truth that must survive snapshot/restore and be hashed —
not derivable each tick (AD-001) and not fixed authored content (AD-024). The two
per-attacker choices mirror AD-026's reasoning that a single global `last_hit` cannot
express two attackers' independent outcomes: `move_contact` is per-attacker (not derived
from `last_hit`), and `active_hit_frames` is a per-`id_group` parallel run (not a single
last-hit tick), each so a move with two contact outcomes or several cadenced groups is
represented correctly. The parallel-array (vs. dict) shape keeps the hash a simple
order-committing run alongside `active_hit_ids`.
**Rejected.** Deriving `move_contact` from `last_hit` (a single global record — cannot
express two attackers' independent contact, mirroring AD-026); a per-attacker single
last-hit tick instead of the per-`id_group` `active_hit_frames` run (wrong for a move
with several cadenced groups); a nested throw-state record (a flat pair of plain ints is
simpler to serialize/hash and adds no nesting the hash walk must special-case).
**Note.** This is the F-002/F-005 precedent applied at the batch-2 ratification pass:
a SimState *shape* addition is a flag the Architect ratifies under an AD, never dev
latitude. The rehit *cadence logic* and the throw *clash detection* that consume these
fields are JC-025 (ratified latitude); this AD owns only the field shapes.
**Observability (F-013, 2026-07-04).** Four of these fields are legibility-relevant
sim truth (`move_contact`, `cancel_tags`, `throw_tech_window`, `thrown_by`) and are
surfaced read-only through the inspection seam's `PlayerView` (`inspection-surface.md`),
resolving F-013 — the same F-002 precedent (AD-024) that legibility-relevant serialized
`SimState` truth is exposed through the one read surface (AD-011), not left observable-in-
principle-only. This surfacing lands in TKT-P1-01 (P1); no new field shape and no new AD
(the shapes are this AD; the surface is AD-011) — it is a projection of existing truth.

### AD-029 · Dedicated `HitBox.tech_window` field; the throw tech window is not `blockstun` reuse — settled (2026-07-03, ruling JC-024)
**Decision.** A throw's tech-window length (AD-016) is authored in a **dedicated
`HitBox.tech_window` field**, *not* by overloading the throwbox's otherwise-unused
`blockstun`. The Developer's P0 stand-in (reading the window from `blockstun` on a
throwbox, JC-024) is **overturned** as the durable shape: field-overloading is exactly
the kind of implicit, undocumented reuse that makes the move format harder to author
against and harder for QA to golden (a `blockstun` value on a throwbox would mean two
unrelated things depending on the `is_throw` flag). `tech_window` is meaningful only on
a throwbox (a throw is never blocked); `0` on a non-throw box. The tech/clash *resolution*
(both-to-neutral, damage undone, simultaneous throws clash) is AD-016's stated outcome and
is unchanged — this AD settles only *where the window length is authored*.
**Why.** This is a move-format *contract* question the Architect owns (settled: the
Architect owns the move/frame-data format). The window length is a genuine per-throw feel
value and deserves a named home in the schema, both so authors read one clear field and so
QA can golden throw frame data without decoding an overloaded field's meaning from a sibling
flag. Adding the field is the build-for-extension choice (Tenet 3): later throw variants
(air throws, throw-vs-throw, deferred in AD-016) read the same explicit field.
**Rejected.** Reusing `blockstun` (the P0 stand-in — implicit, dual-meaning, a golden
hazard; overturned); a sim-wide tech-window constant (not stated to be character-invariant,
and un-authorable/testable per-throw); no field (leaves crit 10's tech window unbacked in
the format).
**Consequence (for the Developer, via the ticket).** `test_support.gd` currently authors
the window through `tb.blockstun = THROW_TECH_WINDOW`; the throw resolution reads it from
`blockstun`. Migrate both to the new `tech_window` field: add it to `hit_box.gd`, author it
on the test throwbox, and read it in the throw path — a localized, reversible change. The
specific window length (8f in the test char) stays placeholder tuning (Strategist's, like
JC-016's scaling numbers), not a golden to lock.

### AD-030 · Projectile authored format: `ProjectileData` + `ProjectileRegistry`; runtime entity carries a `data_id`; spawn timing — settled (2026-07-04, ratified from JC-032/033/034)
**Decision.** Three related projectile-format questions the P1 `TKT-P1-0P` build
surfaced — *what the authored projectile shell is called and how a live projectile
resolves its authored data across serialization*, and *when a spawn fires and when a
fresh projectile first moves/ages* — are settled together because they are all move-
format contract the fireball (`character-a.md` criterion 5, § Fireball) must be
authored and tuned against, and all follow AD-021/AD-024's already-settled principles
(a projectile is a first-class serialized entity; fixed authored content stays out of
serialized state, resolved through an installed roster).

- **Authored shell = `ProjectileData`, not `Projectile` (JC-032).** The authored
  projectile schema type is named **`ProjectileData`** (`game/sim/data/projectile_data.gd`,
  `Resource`). The identifier `Projectile` is already owned by the *runtime* SimState
  entity (`SimState.projectiles[]`, a `RefCounted`, shipped at TKT-P0-05 per JC-010) —
  so the authored shell takes the distinct name to avoid the collision, exactly as
  `MoveState`-authoring-vs-runtime naming is kept distinct elsewhere. move-format.md's
  table is renamed `ProjectileData` to match (a spec-consistency fix; the collision was
  a defect in the format text, since `Projectile` there named an authored shell that in
  fact must coexist with a runtime class of the same conceptual role).
- **Registry resolution mirrors `MoveRegistry` 1:1 (JC-032).** A **`ProjectileRegistry`**
  holds the authored `data_id -> ProjectileData` roster, installed once per run and never
  mutated mid-run — the identical install/clear/generation-token discipline AD-024 fixes
  for `MoveRegistry` (including the F-009 install-generation invariant: the token observed
  at a run's first `step` must be identical at every subsequent `step`). Authored
  projectile content is a *fixed input to the sim*, not serialized state (AD-024/Tenet 2).
- **Runtime entity carries a plain `data_id`, resolves `hitbox` on restore (JC-032).**
  The runtime `Projectile` serializes a plain int `data_id` (hashed like any int),
  **not** a live `HitBox` reference — a `HitBox` is fixed authored geometry and must not
  enter the snapshot (it is not mutable sim truth the canonical hash commits to, AD-024).
  `Projectile.from_dict` re-attaches its `hitbox` via `ProjectileRegistry.data(data_id).hitbox`
  on restore, exactly as `character_id` re-reaches move data through `MoveRegistry`. This
  closes the P0-era gap `projectile.gd` already flagged.
- **Authored field split (JC-032).** move-format.md's `Projectile` table lists
  `owner, position, velocity, hitbox, lifetime, max_per_owner`. Of these, `owner` and
  the initial `position`/`velocity` are **spawn-time** values, not part of the
  projectile's own fixed design: `owner` is the casting player (from `SimState` at spawn),
  and the initial position/velocity come from the **spawning `Keyframe`** (`spawn` =
  `{ projectile, offset, velocity }`, move-format.md). So `ProjectileData` authors only
  the projectile's own fixed design — `id` (registry key), `hitbox`, `lifetime`,
  `max_per_owner` — while `owner`/`position`/`velocity` remain runtime-entity fields set
  at spawn. The move-format.md table is split accordingly (authored-shell fields vs.
  runtime-entity fields) so an author knows what the `.tres` carries vs. what the spawn
  supplies.
- **Spawn fires once, at `frame_start` (JC-033).** A `spawn` keyframe fires **once**,
  on the tick `frame_in_state == frame_start` for that keyframe's range — a one-shot per
  range, *not* once per covered frame. A spawn action authored across frames 3..5 spawns
  exactly one projectile, on frame 3. This is the projectile analogue of how a hitbox
  authored across an active range is one hit (collapsed by `id_group`), and it is what the
  per-owner cap language ("if the cap is full the spawn is suppressed") already presumes —
  a single discrete spawn *event* per firing. The authored frame range around a spawn is
  authoring convenience (the keyframe block), not a per-frame repeat instruction.
- **A projectile does not integrate or age on its spawn tick (JC-034).** A projectile
  spawned on tick T appears at its exact authored spawn position with its full authored
  `lifetime`, and first integrates (moves) and ages (decrements `lifetime`) on tick T+1.
  This is the same convention AD-010 fixes for hitstop (a freshly-set N-frame countdown
  holds for N *following* ticks, not N-1 — the `was_frozen` gate): a newly-created
  countdown/position starts at its authored value and only changes starting the next tick.
  Implemented by capturing a pre-spawn projectile count in `step` and gating phase-3
  integration / phase-7 lifetime on it, mirroring `was_frozen`. **Authoring consequence:**
  an authored `lifetime` of N means N ticks of life *measured from the tick after spawn*,
  and a spawn keyframe on frame F means the projectile exists starting frame F — so
  character A's fireball "spawns frame 14" (character-a.md) and its lifetime is counted
  from frame 15 onward. Tune the fireball's reach with this in mind (release frame = the
  `frame_start` of its `spawn` keyframe; travel begins the following tick).

**Why.** All three are move-format contract the Architect owns, surfaced by the first
projectile build and load-bearing for authoring character A's fireball the first time
(so content lands off provisional ground — the point of this session). The naming split
and registry mirror are the cheapest-to-reason resolution: anyone who understands
`character_id -> MoveRegistry` understands `data_id -> ProjectileRegistry` with identical
discipline. The spawn-once and no-spawn-tick-aging rules are the unique readings
consistent with the already-settled cap mechanism (JC-033) and AD-010's countdown
convention (JC-034); leaving them unstated would let the fireball be mis-tuned (a burst
instead of one shot, or a lifetime silently one tick short).
**Rejected.** Renaming the runtime entity to free `Projectile` for the authored shell
(touches more shipped P0 surface — `SimState.projectiles`, `ProjectileView`, `SimHarness`
— than naming the new authored type distinctly; JC-032). Serializing the `HitBox` on the
runtime entity (authored geometry in the snapshot — the exact thing AD-024 keeps out of
state; JC-032). A single shared registry across moves and projectiles (conflates two
authored-content domains for no benefit; the 1:1 `MoveRegistry`/`ProjectileRegistry`
mirror is more legible; JC-032). Firing a spawn on every covered frame (a multi-frame
spawn range would burst-spawn and defeat the per-owner cap; JC-033). Integrating/aging a
projectile the same tick it spawns (double-advances one tick's data — the first build's
own tests caught a spawn landing at a wall and immediately reading off-stage; also
silently shortens authored lifetime by one; JC-034).
**Note.** Projectile-vs-projectile interaction stays deferred (AD-021 scope). The
`ProjectileRegistry` install-generation invariant is the same one AD-024/F-009 make a
checkable precondition; QA asserts it the same way. If a future feel need wants spawn-tick
integration to behave differently, that is a revision to this AD, not a silent code change.

### AD-031 · Invulnerability is consumed in phase 4; `HitBox.hit_kind` gates it; the whiff is observable — settled (2026-07-04, resolves the invuln flag)
**Decision.** Authored invulnerability (`Keyframe.invuln_strike` / `invuln_throw`,
move-format.md, present but inert since P0) becomes a real, enforced mechanic. Three
coupled parts, all move-format / combat-resolution contract the Architect owns,
surfaced by character A's structural need for it (`2H` anti-air invuln, DP strike-invuln,
`623H` throw-invuln, back-dash invuln — `character-a.md` criteria 4 and 6, Movement table):

- **`HitBox` gains a `hit_kind` (STRIKE / THROW / PROJECTILE).** A defender's
  `invuln_strike` must gate against strikes and `invuln_throw` against throws, so an
  incoming box must declare *which kind* it is. `hit_kind` is the canonical category:
  `invuln_strike` whiffs `STRIKE` **and** `PROJECTILE` (a projectile is a strike at
  range — one immunity beats both); `invuln_throw` whiffs `THROW`. The legacy
  `is_throw`/`throwbox` flag is exactly `hit_kind == THROW` — the same fact under two
  names for continuity with the shipped throw path (which keys on `is_throw`); authoring
  may set either but they must agree. Default `STRIKE`; a projectile's carried hitbox is
  `PROJECTILE`.
- **Consumed in phase 4 (suppress the contact), not phase 5 (record-then-no-op).** The
  geometric overlap still computes, but a gated overlap is **not appended to the
  phase-4 contact list**, so phase 5 never sees it. This keeps invuln out of every
  phase-5 mechanism (`id_group` single-hit memory, the throw-clash scan, combo/scaling,
  `last_hit`) — correct, because a whiffed box is not a hit and must touch none of them.
  A phase-5 veto would instead have to *un-do* bookkeeping a recorded contact triggers;
  suppress-at-record is the clean cut. The gate reads the **defender's covering keyframe**
  for its current `frame_in_state` (invuln is a property of the frame the defender is in).
- **Projectiles gate but are not consumed.** A projectile contact carries
  `hit_kind == PROJECTILE` and is gated by the defender's `invuln_strike` like any strike.
  Because the gate suppresses the *contact*, the phase-5 "consume the projectile on
  connect" path never runs — so a projectile whiffed by invuln **passes through** and may
  still connect on a later vulnerable frame. This is the one operational difference from a
  character strike (which simply misses that frame and may connect on a later active
  frame of its own), and it falls out of suppress-in-phase-4 with no special case; it is
  the correct behavior (invuln makes the defender immune this frame, it does not destroy
  the projectile — the character-A fireball vs. a DP's invuln reads as "the fireball
  passed through the invulnerable startup," not "the fireball vanished").
- **The whiff is observable (charter legibility, principles "no knowledge checks").** A
  suppressed contact is not dropped silently. The attacker's `move_contact` resolves to
  `WHIFF` on the existing whiff edge (last active frame passes with no recorded connect,
  AD-028) — invuln produces a whiff through the *same* path a spatial miss does, no new
  attacker state. The **defender's** current invuln is surfaced read-only as
  `PlayerView.invuln` (`{ strike, throw }` bools, AD-031), a derived projection of the
  covering keyframe (like box geometry, AD-001) — **not** a new serialized `SimState`
  field. Together they let the training mode show "this frame was invulnerable" and
  attribute a whiff to it. This is what makes A's core anti-air read (`623` vs `2H`) and
  the back-dash escape *legible as why the hit didn't land*, satisfying criteria 4/6's
  "the training mode shows" clause, not just their mechanical half.

**Why.** Invuln is genuine combat-resolution contract (multiple roles build against
phase 4/5) and legibility-relevant, so it is an owned AD, not a dev latitude call —
the same bar F-002/F-005/AD-028 set for combat-resolution shape. Gating in phase 4 is
the unique reading that keeps a whiff from polluting phase-5 single-hit/throw/combo
bookkeeping while staying deterministic. `hit_kind` as the canonical category (with
`is_throw` folded into it) avoids a second, drifting throw-vs-strike discriminator.
Adding **no serialized field** (deriving invuln from the keyframe, reusing `move_contact`
for the whiff) keeps `SimState` minimal (AD-001) and the hash unchanged — invuln is
authored content resolved each tick, exactly like the boxes it sits beside.
**Rejected.** Recording the contact in phase 4 and vetoing it in phase 5 (forces phase 5
to un-do `id_group`/combo bookkeeping a recorded contact implies — invuln bleeds into
every phase-5 mechanism; rejected for the clean phase-4 cut). Consuming a projectile that
whiffs on invuln (would make invuln *destroy* projectiles, contradicting "immune this
frame, not projectile-killing," and would silently shorten a fireball's threat against a
DP; rejected). A single `invuln` bool (loses the strike-vs-throw distinction `623H`'s
throw-invuln and `2H`'s strike-only invuln both need). A new serialized `invuln` SimState
field (redundant — the covering keyframe already carries it; adding state would grow the
hash for a derivable value, an AD-001 violation). Silent suppression with no observable
whiff (violates the charter's "find out what happened and why" and principles' "no
knowledge checks" — a jump-in eaten by an invuln anti-air must read as *why*, not as an
inexplicable non-hit).
**Consequence (Developer, via the engine ticket).** `hit_box.gd` gains a `hit_kind` field
(default STRIKE) with `is_throw` reconciled to `hit_kind == THROW`; a projectile's carried
hitbox is authored/marked `PROJECTILE`. `step_phases.gd` phase 4 (`phase4_overlap`) gates
each candidate contact — character hitbox and projectile alike — against the defender's
covering-keyframe invuln before appending it, using the same `MoveData` keyframe resolution
the box resolver uses. `inspection_view.gd`/`player_view.gd` gain the derived `invuln`
read. No `SimState` shape change, no new hash field.
**Note (deferred, Tenet 3).** Per-hitbox *armor* (absorb-a-hit-and-continue) and
directional/partial invuln (upper-body-only as a geometric rather than whole-character
property) are **not** in the slice — `2H`'s "upper-body invuln 1–8" is modeled as
whole-character `invuln_strike` over frames 1–8 (the spec's structural claim is "beats a
jump-in during startup," which whole-character strike-invuln satisfies; the "upper-body"
framing is flavor the geometry does not yet encode). If a later character needs true
partial/geometric invuln, that is a revision to this AD (a per-box or per-region invuln),
not a silent code change. The `hit_kind` enum and the `invuln_*` flags leave that door open.

### AD-032 · Command schema extension: pure-direction command + two-button chord; the shadowing rule — settled (2026-07-04, resolves the command-recognition flag)
**Decision.** The `ButtonMapEntry` command-recognition schema (move-format.md;
`input_buffer.gd` recognizer) is extended so two command shapes character A already
authors as real `MoveState`s — a **pure-direction command** (jump `7/8/9`) and a
**two-button chord** (throw `L+H`) — become reachable by a live input stream. Surfaced by
authoring A's movement and throw (the flag): all three buttons are taken by standing
normals, so neither shape had a recognition path.

- **Pure-direction command (jump).** A `ButtonMapEntry` with `button_index == -1` (no
  button) and `motion == 0` is recognized by its `required_direction` alone, held on any
  of the last `COMMAND_BUFFER` (6) frames — the directionless path the P0 recognizer
  lacked (`button_buffered` returned `false` outright for `button_index < 0`). Jump is
  `required_direction == UP`. A jump is a *held direction*, **not** a motion sequence, so
  it is a `required_direction` gate, not a new `_motion_tokens` entry — `_motion_tokens`
  stays reserved for genuine multi-direction sequences (`236`/`623`), avoiding the
  engine-code edit to that fixed `match` the flag correctly declined to make ad hoc.
- **Two-button chord (throw).** `ButtonMapEntry` gains a `chord_button_index` field
  (`-1` = none). When set, the command requires `button_index` **and** `chord_button_index`
  both held on the **same** frame within the command buffer. "Same frame" is load-bearing:
  a per-button "appears anywhere in the 6-frame window" test would falsely fire on a `L`
  then a separate `H` six frames apart. The chord is one entry, one recognizer call, both
  bits checked per frame.
- **First-match-wins shadowing (the reachability rule).** `button_map` resolves in authored
  order, first satisfied wins (already true, JC-023 routes cancels through the same
  ordering). The chord entry MUST be authored **before** the bare-button entries it shares
  a button with, so `L+H` resolves to the throw, not `5L`. A bare `L` alone does not satisfy
  the chord (both bits required on one frame), so `5L`/`5M`/`5H` stay reachable when pressed
  alone. This makes the throw authorable **without** stealing a bare button — the exact
  blocker the flag hit (aliasing throw to a bare button permanently shadowed a load-bearing
  normal, e.g. `5H`, central to A's 3-frame-link route). The ordering is an authoring rule
  the format guarantees is *expressible*; the recognizer needs no new ordering logic.

**Why.** Both are command-recognition *contract* the Architect owns (move-format.md
`ButtonMapEntry` + the recognizer other content and TKT-P1-09's input display read
through), surfaced by real authored content that could not be reached — a genuine
format/engine gap, not a per-move authoring choice, so it is an owned AD, not dev latitude.
The two additions are the minimal grammar that expresses jump and throw: a no-button
direction gate (reusing the existing facing-aware `_required_direction_held`) and one
extra button field with same-frame semantics. Keeping jump a `required_direction` (not a
motion token) and the chord a single per-frame check keeps the recognizer a pure function
of `input_history` (AD-003/Tenet 2) — replays/netcode reproduce both for free, and TKT-P1-09
decodes them from the same raw frames. The shadowing rule is stated as an owned authoring
invariant so QA can assert `5L/5M/5H` reachability, rather than leaving it a content
accident.
**Rejected.** A new `motion` token for "UP" (would edit `input_buffer.gd`'s fixed
`_motion_tokens` match for a single held direction — heavier than a direction gate, and
conflates a held direction with a multi-frame sequence; the flag correctly declined this
ad hoc, and the direction-gate reading is cleaner as the owned resolution). Aliasing the
throw to a bare button (permanently shadows a standing normal under first-match-wins — the
flag's blocker; rejected). A general N-button chord list (`PackedInt32Array` of required
buttons) — more than the slice needs (throw is exactly two buttons); the single
`chord_button_index` is the minimal expressible form and a third button is a later AD
revision if a command ever needs it (Tenet 3: leave the door, don't build the unused path,
matching AD-016's discipline). Requiring both chord buttons *anywhere* in the 6-frame window
rather than same-frame (would fire on sequential presses — wrong for a chord; rejected).
**Consequence (Developer, via the engine ticket).** `button_map_entry.gd` gains
`chord_button_index: int = -1`. `input_buffer.gd` `entry_satisfied` gains: (a) a
`button_index == -1 && motion == 0` branch recognizing the entry by `required_direction`
within `COMMAND_BUFFER` (via the existing `_required_direction_held`); (b) a chord branch
requiring both button bits on the same buffered frame. `character_a.gd` then authors the
jump `button_map` entry (`UP`, no button) and the throw entry (`L`+`H` chord, listed before
the bare `5L/5M/5H` normals) — that authoring lands with character A, driven by this ticket's
schema, not invented by the content session. No `SimState` shape change; the recognizer stays
a pure function of history.

### AD-033 · Air-normal height-dependent advantage: a phase-5 `AirHeightScaling` rule on hitstun — settled (2026-07-04, resolves F-014)
**Decision.** An **airborne attacker's** connecting on-hit strike scales the **hitstun it
inflicts** by the attacker's **contact height**, so a deep jump-in leaves the attacker more
plus than a high one. This is the mechanism `character-a.md` already promises ("deep
jump-in = very plus … sim truth the training mode reads out, not a fixed number") and that
route 2 (`j.H , 5M > 623M`) leans on; the Strategist ruled it in P1's done-bar (F-014). It is
a **bounded phase-5 resolution rule**, not authored data (JC-A-04 correctly authors one flat
base hitstun; height is a live-sim scaling on top of it).

- **Locus: phase 5, on `hitstun`, feeding the one AD-008 formula.** The rule scales the
  hitstun *input* to hit resolution, not advantage directly — advantage is derived from
  hitstun by the single AD-008 formula, so scaling the input keeps one advantage computation
  and one place the number comes from (the consistency guard AD-008 exists to hold). The
  scaled hitstun flows into the defender's `stun`; the live advantage then reflects it for
  free (it reads the defender's actual remaining stun).
- **Height reference: attacker depth above ground.** `depth = ground_y − attacker.pos_y`
  (fixed-point; screen convention up = `−y`, so an airborne attacker has `pos_y < ground_y`,
  `depth > 0`, `depth == 0` at the floor). The **attacker's** height (how deep the jumping
  attacker connects), stage-relative via `ground_y`, character-agnostic.
- **Scaling: one `AirHeightScaling` definition (mirrors `DamageScaling`).** A single sim-wide
  static definition maps `depth` → a signed hitstun **delta** (a pure function of `depth`
  alone): `+DEEP_BONUS` at `depth ≤ 0`, `−HIGH_PENALTY` at `depth ≥ HIGH_REF_DEPTH`, linear
  between. Applied hitstun = `max(base_hitstun + delta, MIN_HITSTUN)` (a floor so a high hit
  still yields real, brief hitstun — never zero/negative; no upper clamp needed since
  `delta ≤ +DEEP_BONUS` by construction). The four numbers are **slice-provisional
  placeholder tuning** (feel is the Strategist's via the spec, exactly like DamageScaling's
  step/floor, JC-016); the **mechanism** — single definition, depth→delta, applied pre-stun,
  clamped, surfaced — is the contract. Integer/fixed-point only (AD-014); no float.
- **Gate: attacker `category == AIRBORNE` and the contact is a hit.** The character-agnostic
  definition of "air normal" is an airborne strike, not a named move list. A grounded
  normal's hitstun is untouched. Block is unaffected (a blocked air normal uses authored
  `blockstun`; air-blocking is out of P1 scope anyway). Throws never take this path.
- **Observable (charter / F-014's whole point).** The live advantage already reflects the
  scaled hitstun (no extra plumbing). To answer *why*, two ints are surfaced on the hit
  record — `contact_depth` and `air_height_hitstun_delta` — through `HitEvent`
  (`inspection-surface.md`), so the training mode can show "connected deep (depth X) → +N
  hitstun → this much more plus." Jump-in-depth→advantage is one of the least-observable
  things in most fighters; making it answerable live is close to the platonic north-star case.

**Why.** Height-dependent air advantage is genuine combat-resolution contract (multiple
roles build against phase 5) and legibility-relevant, so an owned AD, not dev latitude —
same bar as AD-031/AD-028. Scaling *hitstun into the one formula* (not advantage) is the
unique reading that preserves AD-008's single advantage computation while making the number
vary; a second, parallel advantage adjustment would be exactly the canonical drift AD-008
prevents. A single `AirHeightScaling` definition mirrors the already-ratified `DamageScaling`
single-source packaging. Gating on `AIRBORNE` (not a move list) keeps it character-agnostic
(character B's air normals scale identically). The delta-is-depth-only shape makes the
`air_height_hitstun_delta` readout exactly height's contribution, so the "why" is legible
without back-computation. It is genuinely **bounded**: a small phase-5 computation
(resolve attacker category, compute depth, look up the delta, clamp), one static definition,
and two int readout fields — no new phase, no new per-player field, no new system.
**Serialized-shape note.** The two readouts are a `HitRecord` shape addition (two `int`
fields, `0`/`0` on a non-air-normal hit) — Architect-owned like every serialized-shape change
(AD-024/AD-028 precedent), added to `HASH_FIELDS`/`to_dict`/`from_dict`/`clone` and covered by
the canonical hash (AD-023). No `players[i]` field is added: depth is computed from the
already-serialized `pos_y`, and the scaled hitstun flows into the already-serialized `stun`.
**Rejected.** Scaling **advantage** directly instead of hitstun (a second advantage
adjustment beside AD-008's formula — the canonical drift AD-008 exists to prevent; the
live-advantage read would then need its own height term, duplicating the logic). A per-move
or per-`HitBox` authored height table (JC-A-04 already ruled height is *live sim behavior*,
not authored data; a per-move table also loses the single-source consistency guard and
re-opens the "format is character-A-shaped" risk). Using the **defender's** height as the
reference (wrong semantics — a jump-in is "deep" by where the *attacker* connects, not the
grounded defender's position). A new serialized `players[i]` "last contact height" field
(unnecessary — the value is a transient of one hit, correctly homed on `last_hit`, not
per-player state). Leaving the numbers as a locked golden (they are slice-provisional feel
like DamageScaling — QA goldens the *mechanism*: deep > high, ordered correctly, floored;
not the specific curve).
**Consequence (Developer, via TKT-P1-13).** Add `AirHeightScaling`
(`game/sim/air_height_scaling.gd`, all-static, mirroring `damage_scaling.gd`) with the four
provisional constants and a `hitstun_delta(depth: int) -> int`. In `step_phases.gd`
`_resolve_one_hit`, on the **hit** branch (not block), when the attacker's resolved move
`category == CATEGORY_AIRBORNE`, compute `depth = next.stage.ground_y − atk.pos_y`, get the
delta, and set `stun_frames = max(hb.hitstun + delta, MIN_HITSTUN)`; record `contact_depth`
and `air_height_hitstun_delta` on the `HitRecord` (both `0` otherwise). Add the two fields to
`hit_record.gd` (`HASH_FIELDS`, `to_dict`, `from_dict`, `clone`) and the two projected reads
to `hit_event.gd`/`inspection_view.gd`. `character-a.md` route 2 / "deep = very +" are then
backed by a real mechanism (no character-A engine code — the rule is character-agnostic).
**Note (deferred, Tenet 3).** Height-dependent *pushback*, *launch*, or juggle behavior for
air normals is **not** in this rule — only hitstun/advantage, which is what F-014 and route 2
need. A later character wanting height-scaled launch is a revision to this AD (extend
`AirHeightScaling` to return more than a hitstun delta), not a silent code change.

### AD-034 · Serialization carries a top-level format-version field — settled (2026-07-08, F-flag resolution)
**Decision.** `SimState.to_dict()` carries a single format-version marker, `"v": 1`, on the
**top-level** dict only. Sub-object dicts (`player`, `rng`, `stage`, `projectile`,
`hit_record`, `input_history`) do **not** each carry a version — one version governs the whole
serialized graph; a change to any sub-shape bumps the top-level number.
- **`from_dict` handling.** Read `d.get("v", 1)`. **Absent ⇒ 1** (a dict written before this
  field is legacy v1 — the current shape, so it parses unchanged). **Equal to the current
  version (1) ⇒ parse normally.** **Any other value ⇒ fail loudly** (`push_error` + a clear
  message; do not silently mis-parse a format this code does not understand). A future
  migration path — reading an *older* version by up-converting — is added as an explicit branch
  when a v2 exists; there is exactly one version now, so no migration code is written yet, only
  the version stamp and the fail-fast guard.
- **NOT covered by the canonical hash.** `"v"` is format metadata, **not** mutable sim truth,
  so it is **not** folded into `hash_state()` (AD-023) — exactly like the install-generation
  token (AD-024) and pixel projections (AD-019) are excluded. Consequence: adding the field
  does **not** change any existing state hash, and every determinism/round-trip golden keyed on
  `hash_state()` is unaffected. `to_dict`/`from_dict` round-trip stays exact (the field
  survives the trip); `hash_state()` is blind to it by design.
**Why.** Determinism/serialization is a Tenet-1 surface. A version stamp is one field to add
now and expensive to retrofit once saved states — replays, save-states, rollback snapshots —
exist in the wild and must be migrated blind. Stamping the format the moment it stabilizes is
the cheap insurance; the fail-fast guard turns "silently loaded a format I don't understand"
into a loud, locatable error. Homing it once at the top level (not per sub-dict) is the minimal
shape: the graph versions as a unit, so N per-object stamps would be N places to bump for one
format change. Excluding it from the hash keeps the golden/determinism net — the thing this
surface exists to serve — stable across the field's introduction.
**Rejected.** No version field (the retrofit-blind cost the flag names); a version on every
sub-dict (N bump-sites for one unit-versioned graph; no benefit at slice scope); folding `"v"`
into the canonical hash (would invalidate every existing state golden for a non-sim-truth
marker — the exact drift AD-019/AD-024 exclude their own metadata to avoid); silently ignoring
an unknown version (defeats the purpose — a format guard that never guards).
**Consequence (Developer, via TKT-P1.1-03).** Add `"v": 1` to `SimState.to_dict()`
(`game/sim/sim_state.gd`); read + guard it in `from_dict` per the handling above. No sub-object
change, no `hash_state()` change, no new AD when v2 lands (bump the constant + add the migration
branch — a revision to this AD). A single `const FORMAT_VERSION := 1` on `SimState` is the
natural home for the number.
**Fail-fast loader convention (ratified from JC-048, 2026-07-08).** The concrete refusal
mechanism for the unknown-version guard — `push_error` (non-fatal in GDScript, and fires in
*every* build, unlike `assert`, which is stripped in release/non-debug exports) **followed by
`return null`** before touching any other field of `d` — is ratified as the **standing
fail-fast-loader convention** for any `from_dict`-style loader that must reject a dict it cannot
parse. GDScript has no idiomatic exceptions; `push_error` + a `null` sentinel is the closest
equivalent, and a caller that ignores the `null` gets a loud null-deref rather than a silent
mis-parse limping through a run. If a future migration needs structured error reporting (an
ok/error result type), that is a revision to this AD, made then.

### AD-035 · Render-framing contract: the sim world projects into the viewport via a render-only camera transform — settled (2026-07-08, geometry-overlay finding)
**Decision.** Extends AD-019. AD-019 fixed the fixed→px *scale* (`px()`/`px_rect()`,
`PX_PER_UNIT`) but never said **where the sim's world-space play area lands in the visible
viewport**. This AD closes that gap: the training mode (and later match rendering) frame the
world into the viewport through a **render-only world→screen transform** — a `Camera2D` on the
world layer, or an equivalent offset/zoom applied to the world-drawing node — composed with the
AD-019 scale.
- **What it defines.** The play area (stage bounds `wall_left..wall_right`, the ground line
  `ground_y`) maps to a visible region of the viewport: horizontally centered, with the ground
  line seated in the lower portion of the view, at a zoom that fits the stage width with margin.
  Both characters at their symmetric start positions (`pos_x = ±100` game units, `pos_y =
  ground_y`) must be **fully on-screen** and **not occluded by the readout panels**.
- **Boxes are world-layer; panels are screen-layer (HUD).** The geometry overlay draws in
  **world space** and is moved by the camera transform; the four readout `Control` panels are
  **screen-anchored HUD** and are *not* moved by it. This keeps the panels stationary while the
  world frames correctly behind/around them, and is the clean separation that resolves the
  "boxes behind the x≈16–700 panel region" symptom — the world is framed into visible space the
  HUD does not fully cover (e.g. the play area sits below/around the panels, or the panels are
  positioned clear of it).
- **Render-only; Tenet 1 untouched.** The transform is float, render-side, and **never enters a
  snapshot or the canonical hash** — identical to AD-019's px projection. It reads sim truth
  (stage bounds, positions) to *frame* the view; it writes nothing back. Determinism and the
  golden net are unaffected (a golden taken with or without the camera is identical — AD-019
  criterion 6 extends to it).
- **Exact numbers are placeholder (Developer's, like AD-014/JC-016 tuning).** The specific
  zoom, screen anchor, and ground-line screen y are render feel, not contract — the contract is
  "both characters fully visible, unoccluded, world-layer separate from HUD-layer." QA verifies
  the *contract* (boxes visible on screen, in-mode human gate); the specific pixels are the
  Developer's to pick and the user's to sign off via the human-inspection gate.
**Why.** The geometry overlay is the charter's centerpiece surface ("see what hit and what
whiffed"); at P0 there was nothing to look at, so AD-019 correctly stopped at scale and left
framing unspecced. The first human run (2026-07-08) showed the cost: with `PX_PER_UNIT = 1` and
no camera, world origin sits at the viewport top-left, so characters at `x = ±100`, `y = 0`
render partly off-screen and behind the panels — invisible. Framing is a **shared render
concern** (every overlay that draws in world space, and P2's match rendering, need the same
world→screen mapping), so it is specified once as an owned contract, not re-invented per
overlay — the consistency the Architect exists to guard. Keeping it render-only preserves
Tenet 1 exactly as AD-019 does.
**Rejected.** Baking a screen offset into `px()`/`px_rect()` (couples the *scale* projection to
a *framing* decision; other callers of `px()` — e.g. a future minimap or a non-camera view —
would inherit an unwanted offset; keep scale and framing as separate render concerns);
per-overlay ad-hoc offsets (the drift this AD prevents — two overlays framing the world
differently would disagree about where a box is); moving the play area by shifting sim
`positions` (a Tenet-1 violation — framing must never touch sim truth); making the panels
world-layer so they scroll with the camera (they are HUD — they must stay screen-anchored and
legible regardless of camera state).
**Consequence (Developer, via TKT-P1.1-01).** Add a render-only world→screen framing (a
`Camera2D` on the world/`GeometryOverlay` layer is the natural mechanism) so both characters'
boxes are fully visible and unoccluded by the panels; keep the four `Control` panels
screen-anchored (unmoved by the camera). No sim-truth change, no hash change, no snapshot field.
This lands together with the player-init code defect (same ticket) because boxes must first
*resolve* before framing can be verified — see the ticket.
**Ratified elaboration (from JC-044, 2026-07-08).**
- **Mechanism.** A render-only `position`/`scale` transform on the world-drawing `Node2D` itself
  (`GeometryOverlay`) is an accepted mechanism for this framing — AD-035 names it as the
  alternative to a `Camera2D`, and it keeps the sibling HUD panels screen-anchored with no
  `CanvasLayer` restructuring. The world→screen framing computation
  (`GeometryOverlay.compute_world_framing`) is the **single shared world-space mapping**: a second
  world-space overlay, or P2's match rendering, must **reuse** it — never independently re-derive
  framing, the per-overlay drift this AD's "Why" guards against. When a second world-space consumer
  lands, lift the framing computation to a shared location rather than copying it.
- **Stage bounds.** Hardcoding the stage bounds (`wall_left/right`, `ground_y`) as literals
  mirroring `StageState.new_initial()` is acceptable **only while the stage is the fixed slice
  default**. A non-default or variable stage (P2) requires the framing to read stage bounds through
  a **live inspection-surface accessor** (a new `StageView` / `stage()` read on `InspectionView`) so
  the framing tracks sim stage truth rather than assuming the default — a **seam addition
  (Architect's)** to make then, not a Developer latitude call. Deferred here because the P1.1
  acceptance bar is the symmetric start positions, which sit well inside the default bounds
  regardless.

### AD-036 · No runtime ground clamp yet; a `pos_y ≥ ground_y` clamp + ground-contact landing is deferred defense-in-depth — provisional (deferred; 2026-07-08, from JC-047)
**Context.** Vertical position in the sim is **pure keyframe integration** (AD-014 / JC-A-01) with
**no landing clamp anywhere** in `step_phases.gd`. A character's height is correct only because its
authored jump arc's per-frame `motion_vel_y` sums to exactly zero net displacement over the state's
`duration`. JC-047 found character A's arc did *not* net zero (22 rise / 23 fall at equal magnitude
⇒ +6 units of permanent downward drift per jump — the character sank into the floor), fixed by
re-authoring the arc to net zero (an apex-hang frame).
**Decision (interim guard in effect + deferred shape).**
- **Interim guard (in effect now).** The correctness relied upon is stated as an **authoring
  invariant**: an authored vertical arc must net to exactly zero displacement (return to start
  height) over its duration. Recorded in `move-format.md` (movement authoring) so character B's jump
  in P2 cannot silently reintroduce the JC-047 class of bug. Same kind of authoring constraint as
  the JC-038 "don't end an ALWAYS-cancel at `duration`" rule.
- **Deferred defense-in-depth (NOT built yet — new scope).** A runtime `pos_y ≥ ground_y` clamp *is*
  warranted as defense-in-depth and *will* be load-bearing for P2 (air moves, variable-height
  landings, knockdown-into-ground). But a **bare position clamp is rejected**: clamping position
  without also defining **ground-contact landing semantics** (transition `AIRBORNE → GROUNDED` on
  ground contact, not only on the fixed state `duration`) would *hide* a mis-authored arc — the
  character would silently float at ground level instead of visibly sinking — the opposite of the
  charter's legibility promise (a bug should surface, not be masked). So the clamp must be designed
  **together with** ground-contact landing, as one small mechanism, when it lands.
**Why deferred, not now.** P1.1 does not wait on it (Strategist steer, 2026-07-08): character A's
arc is fixed and it lands flush, and P1's fixed-duration jump needs no ground-contact landing. The
mechanism becomes genuinely load-bearing at P2's air movement, so it is best placed as **pre-P2
hardening or the first unit of P2 air-movement work** — *not* a late P4 harden pass (P2 air moves
would otherwise build on the fragile no-clamp foundation). **Roadmap placement is the Strategist's**
— flagged to them (flags.md); this AD records only the technical shape and the recommendation.
**Rejected.** A bare `pos_y ≥ ground_y` clamp with no landing semantics (masks authoring bugs —
anti-legibility; also leaves the character nominally "airborne" at ground level for the remaining
state frames). Doing nothing beyond the authoring invariant permanently (leaves vertical correctness
resting entirely on perfect authored data — the exact fragility JC-047 exposed; tolerable for the
slice's one fixed-duration jump, not for P2's air game). Building it now (new scope, not P1.1; and it
needs P2's air-move requirements to design the landing semantics against).
**Status.** Provisional/deferred: the *interim authoring invariant* is in effect; the *clamp +
landing mechanism* is designed-in-intent but unbuilt, pending Strategist roadmap placement.

### AD-037 · Vertical convention: up is −Y everywhere; the box Y-inversion is a data bug, not a render bug — settled (2026-07-09, character-A movement reconciliation)
**Decision.** The sim's vertical axis is **up = −Y**, screen-convention, applied on **one shared
axis** to BOTH world position and character-local box geometry. This anchors, at the geometry
level, the `pos_y` convention AD-033 already fixed ("screen convention up = −y … an airborne
attacker has `pos_y < ground_y`, `depth > 0`"). Concretely:
- **Ground line** = `stage.ground_y`. A grounded character's `position` anchor is its **feet**,
  at `pos_y = ground_y`; airborne ⇒ `pos_y < ground_y` (rising is −y, per the jump arc and AD-033).
- **Character-local box space shares the world axis** (box resolution is a pure translate +
  facing-x-flip: `wy = pos_y + b.y`, `move_data.gd`). So a box's `y` is its **min corner (the
  top/head edge)** and the box spans `[y, y+h]` **downward toward the feet**. A grounded body
  therefore occupies local `y ∈ [−H, 0]` — head at `−H`, feet at `0` (= `pos_y` = `ground_y`).
- **The Y-inversion is a DATA bug, not a render bug.** Every box in `content/character_a.gd`
  (and the P0 `TestSupport` character it mirrors) was authored with **positive, downward** local
  `y` — the body *below* the feet-origin. That is internally consistent for *relative* overlap
  (attacker and defender boxes share the wrong sign, so hit/hurt overlap still resolves — which
  is exactly why all 27 headless tests pass), but it is geometrically inverted against `ground_y`
  and the settled up = −Y `pos_y` convention, so it renders **below the floor and upside-down**
  (the gate-2 findings: pushbox at the *top* edge of the hurtbox; the crouch box shrinks *up*;
  crouching normals *look* head-high). **Fix = reflect every authored box across the feet line:**
  `new_y = −(old_y + old_h)`, `h` unchanged. E.g. standing hurt `[0,80] → [−80,0]`; `5L` hit
  `(y=45,h=20) → (y=−65,h=20)`; crouch hurt `[0,55] → [−55,0]`; default pushbox `[0,40] → [−40,0]`.
  After the reflection the pushbox sits at the *lower* part of the body, the crouch box shrinks
  *downward* (head lowers), and grounded attacks land at honest heights.
- **The render is correct as-is; do NOT flip the render sign.** World y-down projects to Godot's
  screen y-down through a **positive** zoom with **no Y flip** (`geometry_overlay.gd` /
  `px_rect`), and AD-035 seats `ground_y` low in the viewport — so once the box data is
  reflected, a body at world `y ∈ [ground_y−H, ground_y]` draws upright *above* the ground line,
  and a jump (`pos_y` going negative) draws *higher*. This is the load-bearing distinction the
  Developer must not guess wrong: **flipping the render sign is rejected and wrong.** A render
  flip would fix a *static* standing box by accident but **double-invert vertical motion** — a
  jump moves `pos_y` negative (up in sim, per JC-047's net-zero arc and AD-033); under a render
  flip that draws the jumping character *below* the floor. The fix lives in the DATA (one shared
  up = −Y axis), never in a render sign.
**Why.** `move-format.md`'s `Box` said only "AABB in character-local space … offset by position"
and never fixed the Y direction — genuinely unspecced, so the box authors read local y as "up =
+y, growing up from the feet" while the engine's translate + the settled `pos_y`/jump/AD-033
convention are up = −y. One axis, stated once, removes the ambiguity. This is the single root
cause behind the whole gate-2 box-appearance cluster and the perceived jump anomaly (the jump
*sim* is already correct — JC-047 verified net-zero headlessly — so once the body sits above the
floor the vertical read becomes honest; re-evaluate the jump feel and the crouching-normal-height
flag at the re-gate against a correctly-oriented display).
**Rejected.** A render Y-flip / negative `scale.y` (fixes standing by accident, double-inverts
the jump — anti-consistent with up = −Y `pos_y`/AD-033/JC-047). Flipping the `pos_y`/jump
convention to up = +y instead (a multi-document reversal of AD-033, the jump arc, and
combat-resolution's depth rule, for no benefit). A separate "local box y is y-up, resolve
subtracts" convention (mixes two axes through one translate — `wy = pos_y − b.y` for boxes but
`+` for motion; two conventions is the drift this AD exists to prevent).
**Consequence (Developer).** Reflect every authored box in `content/character_a.gd` (and, for the
P0 test character, `tests/test_support.gd`) by `new_y = −(y+h)`. No engine/format code changes —
`resolve_box`, `overlaps`, and `px_rect` already assume the shared-axis translate. Box world-y
values in the geometry goldens change **deliberately** (JC-017 style: a conscious behavior/geometry
move, goldens re-baselined, not "tolerated drift"); the sim's hit/hurt *relationships* are
unchanged (the reflection is uniform), so combat outcomes/advantage goldens are unaffected. Verify
right-side-up rendering for every state — including that a jump apex clears the HUD panels (within
AD-035's placeholder framing latitude; adjust zoom/anchor there if it does not, or flag).
**Spawn-point reflection (ratified from JC-054).** An authored spawn *point* — a
`Keyframe.spawn_offset_y` (e.g. the fireball release height), which has **no `h`** — reflects as
`new_y = −old_y`, the degenerate `h = 0` case of the box formula `−(y+h)`. A future character
authoring a spawn point inherits this rule (a point is a zero-height box reflected about its own
single edge).

### AD-038 · Held-input looping-state exit: re-derive an actionable loop state from input each tick — settled (2026-07-09, character-A movement reconciliation)
**Decision.** When a character is **actionable** and its current state is a **looping** state
(`MoveState.loop` — the neutral held-input family: idle, walk, crouch), phase 2 **re-derives the
desired state from buffered input every tick**: the desired state is the first satisfied
`button_map` command (through the one recognizer), or the character's `idle_state_id` if **no**
command is satisfied. Transition iff the desired state differs from the current. A **committed
once-through move** is unaffected — its end is still handled by the once-through → idle transition;
this rule governs only `loop` states.
**Why.** The P1 phase-2 actionable branch transitioned **only on a new matching command** and
otherwise stayed put. That is correct for a move in recovery, but it left a held-direction looping
state (walk/crouch) with **no exit** when the direction is released — the gate finding "walk enters
on 4/6 but never returns to idle, state stuck at 101/102." Re-deriving loop states each tick makes
every held-input stance enter on hold and return to idle on release **uniformly**, with no
per-state exit wiring: idle re-derives to itself (no-op); walk with the direction still held
re-selects walk (`target == current`, no-op); release ⇒ no satisfied command ⇒ idle. It is the
**exit** half of AD-032, which gave only the pure-direction **entry** (walk, and — once its
bare-`DOWN` entry is wired — crouch).
**Rejected.** Per-state explicit exit transitions (drift — every held state re-inventing its own
release, the thing the one-pattern state machine exists to prevent). Making walk/crouch
once-through (they must persist while the input is held). A timed/auto exit (exit is input-driven,
not a timer; a timed exit would feel wrong and is unnecessary).
**Correction (2026-07-10 — the loop-state re-derivation reads CURRENT input, not the command
buffer; resolves the AD-038 exit-lag flag, ruled an OVERSIGHT).** The AD-022 command buffer
(`COMMAND_BUFFER = 6`) exists for **reversal/cancel entry leniency** — firing a *discrete,
once-through* command (a normal, a motion special, a throw, or the prejump/jump lead-in) on the
first actionable frame even when the press was slightly early. It must **not** govern **loop-state
stance selection**. Wiring the whole re-derivation through `_buffered_command` (the buffered
window) made a *released* direction linger for up to `COMMAND_BUFFER − 1` (~5) ticks, so a held
walk/crouch kept re-selecting itself and did **not** exit on the release frame (empirically: held
5 ticks, exited at tick 11 not tick 6). Applied to a held direction's exit the buffer's leniency
has **no upside** — only ~83 ms of walk-stop imprecision, against the charter's precise-neutral-
spacing play space (and the gate-1 "walk won't stop" defect this reconciliation exists to close).
**Corrected contract:** the loop-state re-derivation decides the desired **stance** — a `loop`-state
command (walk / crouch) or the `idle_state_id` fallback — from the character's **current-tick
resolved input** (the direction held *this* tick), with **no command-buffer carry-over**, so a
released direction returns to `idle_state_id` on the very next actionable tick (prompt release). A
**discrete/committed command** (a command whose target state is **not** `loop`) still fires through
the AD-022 buffer with full leniency and takes priority when one is buffered-ready — it leaves the
loop state on entry, so it never lingers. Net: the buffer governs *entering an action*, current
input governs *which held stance you are in*.
**Consequence (Developer).** In `step_phases.gd` `phase2_state_machine`, the actionable **and**
`move.loop` branch is two-tier: (1) if a **discrete** command (recognized command whose target
state is not `loop`) is buffered-ready via the AD-022 command buffer, transition to it (unchanged
leniency); (2) otherwise compute the stance `target` from the **current tick's** recognized
pure-direction/`loop` command — NOT the buffered window — and if none is satisfied this tick set
`target = character.idle_state_id`; transition if `target != p.state_id`. (The `loop`/non-`loop`
target split is the clean discriminator — `MoveRegistry` already knows each state's `loop` flag.)
Non-loop actionable states keep the existing "run a buffered command, else stay" behavior. Still
deterministic (a pure function of `input_history` + state); movement goldens change deliberately
(walk now terminates **on the release frame**, not ~5 ticks later). **Needs a small Developer
follow-up ticket** (Strategist dispatches before the re-gate): change the loop-state exit read from
buffered to current-tick input, re-baseline the walk/crouch release-timing goldens accordingly.

### AD-039 · Airborne-action model: per-direction prejump lead-ins + air-normal jump-state cancels — settled (2026-07-09, character-A movement reconciliation)
**Decision.** Two data-only wirings (no engine or format change) complete character A's air game;
both use mechanisms the engine already has.
- **Directional/diagonal jumps via per-direction prejump lead-ins.** A jump's **horizontal**
  direction is decided at **takeoff** (the input frame), so it is captured by routing the jump
  command to one of **three** prejump states — `PREJUMP_N` / `PREJUMP_F` / `PREJUMP_B` — each an
  **input-gateless ALWAYS cancel** (`input = 0`, window ending at `duration − 1` per JC-038) into
  its matching `JUMP_N` / `JUMP_F` / `JUMP_B` arc. `button_map` (AD-032 pure-direction commands;
  the recognizer's `_required_direction_held` **ANDs** each required bit, so a composite
  `required_direction` is expressible): `UP|FORWARD → PREJUMP_F`, `UP|BACK → PREJUMP_B`,
  `UP → PREJUMP_N`, with the two **diagonals listed before** bare `UP` (first-match-wins, AD-032).
  **Reconciliation:** "jump forward/back" and "diagonal (7/9) jump" are the **same** motion —
  numpad `9` = up+forward, `7` = up+back; there is no separate pure-horizontal jump. One composite
  mechanism satisfies both the brief's "jumping (neutral/forward/back)" and the checklist's
  "diagonal (7/9)".
- **Air normals via jump-state cancels.** An airborne character acts by **cancelling its jump
  state into an air normal**: `JUMP_N/F/B` each carry three `CancelRule`s (condition `ALWAYS`,
  `window` = the airborne frames `[1, JUMP_DURATION − 1]`, `input =` `BUTTON_0/1/2`) targeting
  `j.L`/`j.M`/`j.H`. The window ends at `duration − 1` (ratified JC-059, same off-by-one as the
  prejump lead-in per JC-038): on the `duration` frame itself the committed jump is already
  actionable and phase 2's fixed priority takes the actionable/buffered branch over the cancel
  branch, so a frame-`duration` window edge is silently unreachable. The
  cancel's raw-button `input` resolves through `CancelEval`'s **existing raw-button fallback**
  (`_input_buffered` matches `rule.input == BUTTON_n` as a bitmask when no `button_map` entry
  targets the air-normal state), so **no `button_map` entry is needed** for the air normals and no
  new "airborne" gate field is added to `ButtonMapEntry`.
**Why.** The gate found forward/back and diagonal jumps and jump-in normals all unreachable:
`button_map` routed only bare `UP → PREJUMP`, `PREJUMP`'s cancel target was hardcoded `JUMP_N`, and
there were no `button_map` or cancel paths to `JUMP_F/JUMP_B` or the `j.*` normals (which is why
pressing a button mid-air did nothing — a committed jump is not actionable, so the actionable
`button_map` branch never fires in flight; only a cancel can act during a committed move). The
states (`JUMP_F/JUMP_B`, `j.L/M/H`) already **exist** — only the wiring was missing. Both fixes
express what the engine already supports (composite direction gate; ALWAYS cancel; raw-button
cancel fallback), so this is **unwired content over a stated model**, not a format gap.
**Known limitation (AD-036 class, deferred).** An air normal, on ending, returns to idle at
whatever height the arc/normal left it — there is **no ground-contact landing** (AD-036 defers the
`pos_y ≥ ground_y` clamp + landing semantics). So a jump-in cancelled mid-arc does not cleanly
land; **reachability + correct rendering is the P1.1 bar**, and clean air-normal landing rides on
AD-036's deferred mechanism. Confirm the feel at the re-gate; if the float reads unacceptably, it
is an AD-036 roadmap-placement question (Strategist), **not** P1.1 scope to build now.
**Rejected.** A single prejump with direction-branched cancels (a `CancelRule` has no direction
gate — the horizontal choice cannot be expressed on one cancel; three prejumps is the clean data
expression *and* captures direction at takeoff, which is correct). Making the jump state
"actionable" so the neutral `button_map` fires mid-air (breaks the committed-move model and the
actionable/advantage semantics). Adding an "airborne" gate field to `ButtonMapEntry` (unnecessary —
air normals are reached *from* the jump via a cancel, not from neutral; the cancel already means
"act during this move").
**Consequence (Developer).** In `content/character_a.gd`: author `PREJUMP_F`/`PREJUMP_B` mirroring
`PREJUMP` (each ALWAYS-cancelling to its jump, window `[3,3]` like the existing neutral prejump);
add the three composite-direction `button_map` entries (diagonals before bare `UP`); add three
air-normal `CancelRule`s to each of `JUMP_N/F/B`. No engine/format change; movement goldens gain
the new reachable states (deliberate).
