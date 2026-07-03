# Judgment-Call Log

> Owned by the **Developer** (appends entries); the **Architect** ratifies or
> overturns each at least once per feature, before audit (protocol cadence).
> Written for other roles to pick up: QA reads it for drift, the Architect to
> fold ratified calls into the spec, future work to inherit decisions instead of
> re-deriving them. Every entry is a *latitude* call — how to build something the
> spec already decided *what* it is. Anything touching a contract, feel, or tenet
> is a flag (`flags.md`), not an entry here.
>
> Status: **provisional** (recorded, awaiting ratification) · **ratified** ·
> **overturned**. Entries are append-only; supersede rather than rewrite.

---

### JC-001 · 2026-07-02 · TKT-P0-01 · `FP` as a static-function class — ratified
**Decided.** `FP` is a `class_name FP extends RefCounted` with all-static
methods (`FP.mul(a, b)` etc.), carrying no instance state and never
instantiated.
**Serves.** TKT-P0-01 / AD-014 ("A small `FP` helper owns these ops"). AD-014
fixes the ops and convention; how the helper is *packaged* is left open.
**Alternatives passed over.** A global autoload singleton (adds a global for
pure math with no state — unnecessary coupling); free functions in a plain
script (GDScript has no module-level free functions callable as `FP.mul`).
**Why.** Static methods on a named class give the `FP.op()` call site the ops
want, with zero state, zero globals, and no instancing on the hot path. Purely
internal; invisible across the seam; trivially reversible.
**Ratified** (Architect, 2026-07-02). Pure packaging of the AD-014 helper, which
left "how the helper is packaged" open. No contract surface, no state, no seam
exposure — nothing to fold beyond noting the `FP.op()` call convention, which
AD-014 already implies. Folded into AD-014 (packaging + API line).

### JC-002 · 2026-07-02 · TKT-P0-01 · `to_int` truncates toward zero; `round_to_int` is the AD-014 rounding rule — ratified
**Decided.** Two distinct extractors: `to_int` truncates toward zero (drops the
fraction), `round_to_int` applies AD-014's rounding (round-to-nearest, ties away
from zero). Applied the *same* documented rounding rule to `mul` and `div`
results and the float bakes.
**Serves.** AD-014 ("a single documented rounding rule ... governs anywhere a
conversion rounds").
**Alternatives passed over.** A single extractor applying the rounding rule
(loses plain truncation, which callers sometimes want — e.g. whole-cell
indexing); arithmetic-shift truncation only (`>>` floors toward -inf for
negatives, which is neither truncation nor the AD-014 rule — a silent
inconsistency).
**Why.** AD-014 names the rounding rule for *conversions that round*; truncation
(fraction-drop) and rounding are different operations and callers need both
named distinctly. `mul`/`div`/bakes all round; `to_int` deliberately truncates,
symmetric about zero (`-1.9 -> -1`, matching `1.9 -> 1`), and is documented as
such. No values here that reach `step` are floats.
**Ratified** (Architect, 2026-07-02). This is a real contract elaboration, not
just latitude: AD-014 named one rounding rule for *conversions that round* but
was silent on plain truncation, which integer-cell callers (whole-cell indexing)
need. The two-extractor split is the correct resolution and is now binding on all
callers. Folded into AD-014 (extractors + which ops round). Note the ban on
arithmetic-shift truncation (`>>` floors toward -inf for negatives) is also now
part of the contract, so no caller silently reintroduces a third rounding
behavior.

### JC-003 · 2026-07-02 · TKT-P0-01 · 64-bit product overflow left unguarded, documented — ratified (behavior) + contract fixed in AD-014
**Decided.** `FP.mul` computes `a * b` at 64 bits before the `>> 16` shift and
does **not** guard/widen against intermediate overflow. Documented in the method
and here as a known bound.
**Serves.** AD-014 (`mul = (a*b) >> 16`). AD-014 specifies the op, not overflow
handling.
**Alternatives passed over.** 128-bit intermediate / split-multiply (correct at
any magnitude but slower and unjustified at slice magnitudes); saturating clamp
(hides a bug rather than surfacing it).
**Why.** At the slice's magnitudes (stage-bounded positions/velocities, box
dims) the product is far inside 64 bits, so the plain op is correct and cheapest.
Widening is out of TKT-P0-01 scope and, if the sim ever approaches the limit,
becomes an Architect contract question (what magnitudes must `FP` guarantee?) —
raise then, don't pre-solve now. Flagged as a bound so QA/Architect see it
consciously rather than discovering it.
**Ratified with a contract addition** (Architect, 2026-07-02). The Developer was
right to flag this: the *behavior* (plain 64-bit `(a*b)>>16`, no widening) is
ratified, but "what magnitude must `FP.mul` guarantee" is a contract I own, not a
dev latitude call, so it must not live only as a code comment. Folded into AD-014
as an explicit **operand-magnitude budget**: `FP.mul(a,b)` is correct while
`|a_units * b_units| < 2^31` (game-unit product), i.e. each operand safely up to
~46340 game units when the other is comparable. The slice's magnitudes
(stage-bounded positions/velocities/box dims, all far under ~10^3 units) sit
orders of magnitude inside this, so no guard is needed now. AD-014 now also
states the escalation trigger: if any sim value approaches the budget, widening
(128-bit / split-multiply) is an AD-014 revision, not a silent code change. This
keeps the bound in the owned contract where QA can assert against it, not buried
in a method doc.

### JC-004 · 2026-07-02 · TKT-P0-01 · Tick host advances against a minimal seam, not real `SimState`/`step` — ratified (01→03 ordering ruled intended)
**Decided.** `tick_host.gd` owns the fixed-tick clock discipline now (one tick
per `physics_process`, state-owned counter, `delta` never used to scale), but
advances an integer tick-only *stand-in* state through a single `_advance` seam,
because `SimState` and pure `step` are TKT-P0-03 and the input contract is 02.
**Serves.** TKT-P0-01 scope ("the fixed 60 Hz tick host ... advancing off a tick
counter in state") + the sequencing note that 01 lands before 02/03. The host's
job — pin the clock discipline — is landable before the state it will drive
exists.
**Alternatives passed over.** Deferring the whole host to 03 (would leave the
clock discipline unpinned while gameplay is written — exactly what the
sequencing note wants avoided: "violations are cheapest to catch as the sim is
written"); stubbing a fake `SimState` shape now (would pre-empt the 03 contract I
don't own — a contract invention, which is a flag, not latitude).
**Why.** The seam (`_sim_state` handle + single `_advance`) lets the
tick-authority logic be written and tested now and swapped to
`SimSim.step(state, in1, in2)` at 03 without changing the discipline. The
stand-in is deliberately a bare `int` (tick only) so it *cannot* accidentally
prefigure the real state shape. If 03's `step` signature or state handle differs
from what this seam assumes, that surfaces as a one-line swap here, not a
contract I baked in.
**Ratified; the 01→03 ordering is intended, not a decomposition defect**
(Architect, 2026-07-02). The seam call is exactly right and exactly what
build-for-extension (Tenet 3) wants. The sequencing the Developer surfaced is
deliberate: TKT-P0-01's job is to *pin the fixed-tick clock discipline* (one tick
per `physics_process`, state-owned counter, `delta` never scales), and that
discipline is landable and testable before the `SimState`/`step` contract it will
eventually drive exists. The roadmap principle "violations are cheapest to catch
as the sim is written" wants the clock authority pinned first, not last, so 01
correctly precedes 03. Advancing a bare `int` tick-only stand-in through a single
`_advance` seam — rather than stubbing a fake `SimState` shape — was the right
call; the fake-shape alternative would have pre-empted the 03 contract (correctly
identified as a flag, not latitude). At TKT-P0-03 the swap to
`step(state, in1, in2)` is a one-line change at `_advance` and must not touch the
clock discipline. Recorded as an explicit ticket note in p0-backbone.md so the 03
developer inherits the seam-swap expectation. **No defect to correct.**

### JC-005 · 2026-07-02 · TKT-P0-01 · Headless `SceneTree` test runners with exit-code gating — ratified
**Decided.** Tests are standalone `extends SceneTree` scripts run via
`godot --headless -s`, each printing an OK/FAIL summary and `quit(0/1)` so a
harness/CI gates on the exit code. No third-party test framework.
**Serves.** The Developer duty to write tests as I build (protocol), and QA's
need for deterministic, scriptable checks — kept framework-free so QA owns the
harness (TKT-P0-11) without inheriting a dependency.
**Alternatives passed over.** GUT/other GDScript test frameworks (a dependency
QA hasn't chosen and 11 may supersede); in-editor-only tests (not headless/CI-
gateable).
**Why.** `SceneTree` + exit code is the lightest thing that runs headless and
gates cleanly, and it leaves QA free to adopt or replace the harness at 11
without unpicking a framework. If QA standardizes on something at 11, these
convert trivially.
**Ratified** (Architect, 2026-07-02). Test-tooling latitude, not a contract:
framework-free, headless, exit-code-gateable, and deliberately leaves the harness
choice to QA at TKT-P0-11. Nothing to fold into a spec — the one consequence
worth flagging for QA is that these runners are provisional scaffolding QA may
supersede at 11, which the entry already states. QA owns the harness verdicts
(TKT-P0-11 scope), so this constrains nothing they inherit.

### JC-006 · 2026-07-02 · TKT-P0-02 · `InputFrame` value is a plain masked `int`, class is a namespace — ratified
**Decided.** An `InputFrame` *value* is carried as a plain GDScript `int` masked to
the low 16 bits; `input_frame.gd` is a never-instantiated `class_name InputFrame
extends RefCounted` holding only bit constants + pure static helpers over that int
(mirrors the FP packaging, JC-001). No boxed per-frame object on the data path.
**Serves.** TKT-P0-02 / input.md ("a single fixed-width unsigned bitfield (16
bits)"; "`InputFrame` is a plain value: it serializes/restores byte-identically").
The spec fixes the *representation* (16-bit bitfield) and the requirement (plain,
byte-identical round-trip); how that value is *carried in GDScript* is left open.
**Alternatives passed over.** A wrapper `Resource`/object per frame (boxes a 16-bit
value — heavier to store in `input_history`, allocates per tick, and would need its
own serialization to stay byte-identical; a plain int already round-trips as
itself); a `PackedByteArray` per frame (over-engineered for 16 bits).
**Why.** GDScript has no native `u16`. A masked `int` IS the value, so it drops
straight into `input_history` (a `PackedInt32Array`) and any recorded buffer,
round-trips byte-identically for free (input.md criterion 1), and keeps the input
layer allocation-free on the hot path. The class-as-namespace gives
`InputFrame.CONST` / `InputFrame.helper()` call sites with zero state.
**Reversal cost.** Low and seam-invisible: the value is only ever produced/consumed
through `InputSource.get_input(frame) -> int` and the frame constants; wrapping it
later would touch those call sites but not the contract shape.
**Ratified** (Architect, 2026-07-02). GDScript packaging of a representation the
spec already fixed (16-bit bitfield, plain byte-identical value), mirroring the
`FP` packaging (JC-001/AD-014). Not pure latitude to leave un-folded, though:
the "masked `int` IS the value; `InputFrame` is a namespace, not a wrapper" fact is
shared vocabulary the Developer and QA both reason against, so I folded it into
input.md (the `InputFrame` plain-value bullet) rather than leaving it only here. The
call is correct and now owned. No wrapper-type is to be reintroduced without a spec
change.

### JC-007 · 2026-07-02 · TKT-P0-03 · Canonical state hash is FNV-1a over an ordered integer value stream — ratified into spec (AD-023)
**Decided.** `SimState.hash_state()` folds the state's integer values, walked in a
FIXED field order, with 64-bit FNV-1a (byte-at-a-time, low byte first). It does not
use Godot's `hash()`, `var_to_bytes`, or Dictionary iteration order.
**Serves.** TKT-P0-03 ("a canonical state hash") + simulation.md criteria 1/2/3,
which are all verified by "do two states hash the same?". The spec requires a
*canonical* hash; the algorithm is left to the Developer.
**Alternatives passed over.** `var_to_bytes(to_dict()).hash()` — depends on
Dictionary key-iteration order and Godot's internal serialization, neither
guaranteed stable across engine versions/platforms, so it would risk breaking QA
goldens for reasons unrelated to sim state (the exact failure AD-019 guards against
for a different case); Godot's built-in `hash()` on the dict — same order/stability
concern, and not documented as platform-stable.
**Why.** Purity/determinism/round-trip proofs lean entirely on the hash being a
deterministic function of the state's DATA, not of object identity or map ordering.
FNV-1a over an explicitly-ordered pure-integer stream is platform-independent
(GDScript ints are 64-bit two's-complement and wrap on overflow, giving FNV's mod-
2^64 arithmetic), float-free (AD-019), and order-committing (folding sizes/counts
before elements prevents regrouping collisions). It is a *tool* for QA's harness,
not a sim contract, so it stays a latitude call — but flagged provisional because if
QA (TKT-P0-11) wants a specific hash the harness standardizes on, this converts
trivially and should defer to that.
**Ratified INTO the spec, not as latitude** (Architect, 2026-07-02). The Developer
flagged the right thing: this is *not* a latitude call, it is a contract I own. The
canonical hash is the primitive simulation.md's determinism/purity/round-trip
criteria (1/2/3) are all verified through, and QA's TKT-P0-11 golden/determinism
harness standardizes on it byte-for-byte — a second implementation that satisfies
the properties but produces different bytes is still a break. So the canonicality
requirements are now owned in **AD-023** and surfaced in simulation.md (a "Canonical
state hash" subsection under Serialization, plus new acceptance criterion 10 so QA
can assert the *properties*, not just "two states hash the same"). Folded: fixed
field order (not Dictionary iteration), integer-only/float-free, order-committing
count separators, total coverage, and the pinned algorithm (64-bit FNV-1a, low byte
first) with the ban on Godot `hash()`/`var_to_bytes`. The Developer's instinct to
defer to QA at TKT-P0-11 is honored, but as an **AD-023 revision** if needed, not a
silent code change — both sides now read one owned hash definition. The
implementation as written matches AD-023; no code change required.

### JC-008 · 2026-07-02 · TKT-P0-03 · `InputHistory` capacity CAP = 32 frames — ratified
**Decided.** The per-player raw-input ring buffer (`input_history.gd`) holds up to
CAP = 32 frames, oldest→newest, stored as a flat `PackedInt32Array` so its
serialized form is canonical regardless of the ring's write cursor.
**Serves.** TKT-P0-03 / simulation.md (`players[i].input_history` — "ring buffer of
recent raw InputFrames"); AD-003/AD-022 fix the *buffering windows* (9-frame motion,
6-frame command). The spec fixes the windows (feel, sim-side); the *storage depth*
of the history is an internal capacity detail left open.
**Alternatives passed over.** CAP = exactly the largest window (9) — no headroom, so
any later rule needing more lookback silently truncates; unbounded history — grows
the serialized state without bound and bloats every snapshot/hash for no gameplay
need.
**Why.** 32 covers the AD-022 windows (9/6) several times over with headroom for a
future rule, while keeping the serialized state and the hashed frame-stream small.
The WINDOWS are the feel values and live in AD-022 (sim-side, the Architect's); CAP
is just how deep the substrate buffer is, so it is latitude. If a future buffering
rule needs more lookback than CAP, that is a one-line bump here, not a contract
change.
**Ratified as recorded** (Architect, 2026-07-02). Correct split: the buffering
*windows* that determine feel (9f motion / 6f command) are owned in AD-022; CAP is
internal storage depth, pure latitude, with the right analysis (covers the windows
with headroom, keeps snapshot/hash small, cursor-independent flat storage keeps
serialization canonical — which also serves AD-023). No spec change: CAP must stay
`>=` the largest AD-022 window, which the "one-line bump if a rule needs more
lookback" note already guarantees. Nothing to fold.

### JC-009 · 2026-07-02 · TKT-P0-03 · Input sources sampled parent-before-child via tree order in the scaffold — ratified (ordering now an owned invariant via F-001)
**Decided.** In the running scaffold (`main.gd`), the `LocalDeviceSource`s are
`sample_next()`-produced in `Main._physics_process` (the parent), which Godot runs
before the child `TickHost._physics_process` that advances the sim — so the current
frame exists in each source before the host queries `get_input(state.tick)` (no
future read, input.md).
**Serves.** TKT-P0-03 seam close / input.md (sources "produce" a frame before the
sim requests it) — view-side wiring only; the sim (`step`) consumes only the
already-recorded frame.
**Alternatives passed over.** Making `TickHost` own device sampling — but the host
holds the abstract `InputSource` (which has no `sample_next`; only concrete device
sources do), and sampling inside the host would couple it to a concrete source type,
violating "nothing in the sim knows which concrete source it holds" (input.md); a
`Callable`-based sample hook on the host — extra indirection for no P0 benefit.
**Why.** Tree-order (parent-before-children) is Godot's documented `_physics_process`
ordering, and separating "produce the device frame" (view/wiring) from "advance the
sim" (host) keeps the host source-type-agnostic. This is scaffold wiring outside the
sim, fully reversible, and invisible across the seam. Flagged as a spot to harden if
a later ticket needs a hard ordering guarantee rather than relying on tree order.
**Ratified — and the ordering IS now an owned invariant** (Architect, 2026-07-02).
The Developer's two calls here are both ratified: (1) sampling stays in the
wiring/view layer, NOT in the tick host — moving it into the host would couple the
host to concrete device sources and violate "nothing in the sim knows which concrete
source it holds"; the abstract `InputSource` has no sampling method, correctly. (2)
producing-the-frame is separated from advancing-the-sim. What the Developer rightly
flagged as "a spot to harden if a later ticket needs a hard ordering guarantee" is
exactly what QA raised as F-001, and I have now hardened it: input.md carries a
"Produce-before-query ordering (owned invariant)" clause (owned by the driver, not
the sim, not the sources — same ownership AD-020 gives the harness) plus acceptance
criterion 7. So tree-order in `main.gd` is ratified as *one valid way to satisfy*
the invariant, no longer a contract resting on an accident. See flags.md F-001
(resolved). No code change required; the scaffold already satisfies the invariant.

### JC-010 · 2026-07-02 · TKT-P0-04/05 · Inspection views + serialized-state backing fields packaged as plain-data classes — provisional
**Decided.** The inspection-surface returns are small `RefCounted` plain-data view
classes (`PlayerView`, `BoxView`, `ProjectileView`, `FrameData`, `AdvantageView`,
`HitEvent`) that COPY sim values out at construction, under `game/sim/views/`. The
sim-side truth backing `last_hit` is a separate plain `HitRecord` in state (the view
`HitEvent` projects it). The move-format schema types (`Character`, `MoveState`,
`Keyframe`, `Box`, `HitBox`, `CancelRule`, `ButtonMapEntry`, `CharacterPhysics`) are
`Resource` subclasses under `game/sim/data/` (AD-006 `.tres`), and the runtime
`Projectile` entity is a `RefCounted` plain-data object (not the authored resource).
**Serves.** TKT-P0-04 (full API shape, read-only, snapshot-able plain returns) +
TKT-P0-05 (`.tres` schema types). inspection-surface.md fixes the API shape and
"plain serializable data (no live node refs)"; move-format.md fixes the schema.
*How* each is packaged (RefCounted view vs. Resource, file layout, copy-out
construction) is left open.
**Alternatives passed over.** Returning raw `PlayerState`/dicts from the surface
(leaks live sim internals — violates read-only-by-construction and lets a caller
mutate state through a returned handle); making the views `Resource`s (heavier, and
they are transient per-tick projections, not authored assets); one giant view file
(worse for the seam's file-level clarity).
**Why.** Copy-out view objects make the surface read-only structurally: a caller
holds a snapshot, never a path back into `SimState` (inspection-surface.md criterion
2). Fixed-point-only fields keep them golden-able (criterion 4). Schema types as
`Resource`s get engine-native `.tres` authoring/serialization for free (AD-006).
Purely internal packaging; the API shapes themselves are the Architect's (built to
spec, not invented). **The serialized-state fields these views require
(`character_id`, `stun_kind`, `combo_damage`, `last_hit`, `neutral_restored_this_tick`)
are NOT latitude — they change the owned SimState shape and are raised as flag
F-002.** This entry covers only the packaging of the views/schema classes.

### JC-011 · 2026-07-02 · TKT-P0-05 · "First actionable frame" for derived recovery = duration+1 (recovery = total − last_active) — provisional
**Decided.** In the one canonical frame-data derivation (MoveData.frame_data),
recovery = `move.duration − last_active_frame`, i.e. the first actionable frame of a
once-through move is `duration + 1` (the frame after the state ends). Startup =
`first_active − 1`, active = `last_active − first_active + 1`, total = `duration`.
**Serves.** move-format.md "Derived frame data": Startup = frames before first
active; Active = first→last active; Recovery = end-of-active → first actionable;
these are named but the exact arithmetic (whether "first actionable" is `duration`
or `duration+1`) is not spelled out. I filled it the way that makes
startup+active+recovery == total for the hand-computed test move (3+3+6 == 12).
**Alternatives passed over.** Recovery = `duration − last_active − 1` (treats the
last state frame as already actionable — makes the three parts sum to total−1, an
off-by-one that breaks the "everything after active is recovery" reading);
first-actionable = last_active+1 with active counted exclusively (inconsistent with
"first to last active" being inclusive).
**Why.** With inclusive active [first,last] and duration = frames-to-first-
actionable, recovery is exactly the frames strictly after last_active up to and
including the last state frame, = duration − last_active, and the three parts sum to
total. This is the only reading under which the spec's own definitions are mutually
consistent and hand-verifiable. If the Architect intends a different actionable-
edge convention it is a one-line change here — flagging-adjacent, but recorded as
latitude because it is the unique internally-consistent reading of the stated
definitions, not a new choice.

### JC-012 · 2026-07-02 · TKT-P0-07(pre-wired at 05) · Live-advantage party identification reads defender = the player in stun — provisional
**Decided.** The live advantage (Advantage.live) identifies the defender as the
player with `stun > 0` and the attacker as the other; when neither is stunned there
is no interaction, so value = 0 / plus_player = none. If BOTH are stunned (a trade),
the player with the greater remaining stun is taken as the advantage-read defender
(deterministic tiebreak). Advantage is expressed from the attacker's POV (positive =
attacker plus), matching AD-008 (positive ⇒ attacker actionable first).
**Serves.** AD-008 / combat-resolution.md "Advantage": one formula
`defender_remaining_stun − attacker_remaining_recovery`, live value cancel-aware.
The formula and the two surfaced values are the contract; *how the live value
identifies which player is the defender from state* is not spelled out.
**Alternatives passed over.** Tracking attacker/defender explicitly on `last_hit`
and reading roles from there (couples the live per-tick advantage to the last
discrete hit event — wrong for a continuing situation where stun ticks down every
frame with no new hit; the live value must read the CURRENT situation, AD-008);
picking defender arbitrarily on a trade (non-deterministic).
**Why.** AD-008 defines advantage in terms of "defender_remaining_stun" — the
defender is definitionally the stunned party, so reading it from `stun > 0` is the
formula's own meaning, not an added rule. The both-stunned tiebreak is a rare P0
case (no true trades in the slice's single-hit done-bar) made deterministic so the
hash is stable. If the Architect wants explicit role tracking, it is a localized
change in Advantage.live. Recorded as latitude; escalate to a flag if role
identification turns out to be feel-bearing beyond the formula's plain meaning.

### JC-013 · 2026-07-02 · TKT-P0-06 · Phase pipeline packaged as a `StepPhases` static module; each AD-009 phase a named function — ratified
**Decided.** The intra-tick phase order (AD-009) is implemented as `StepPhases`
(all-static, `game/sim/step_phases.gd`), one named function per phase
(`phase1_read_inputs`, `phase2_state_machine`, `phase3_movement`, `phase4_overlap`,
`phase5_hit_resolution`, `phase6_advantage_neutral`, `phase7_advance_counters`).
`SimState.step` orchestrates them in the fixed order and holds no phase logic itself.
**Serves.** TKT-P0-06/07 (the fixed intra-tick phase order inside `step`);
combat-resolution.md phase order (AD-009). The spec fixes the ORDER and each phase's
content; how the phases are *packaged in GDScript* (one module vs. inline in `step`
vs. per-phase files) is left open.
**Alternatives passed over.** All phases inline in `SimState.step` (one long
function — worse legibility, and the order becomes implicit control flow rather than
an explicit, reorderable-to-fail call list QA can point criterion 2 at); a phase per
file (over-fragmented for seven short cohesive functions that share helpers).
**Why.** A named-function-per-phase module makes the AD-009 order the literal,
readable call sequence in `step` (so "reordering changes results" — criterion 2 — is
a one-line reorder in a test), keeps each phase independently testable, and mirrors
the FP/MoveData static-namespace packaging already ratified (JC-001). Purely internal
factoring; the `step(state,in1,in2)` contract signature is unchanged. Reversible.
**Ratified as latitude** (Architect, 2026-07-03). Pure GDScript packaging of the
AD-009 phase order (which fixes the ORDER and each phase's content, not the
factoring), mirroring the already-ratified FP/MoveData/`StepPhases` static-namespace
pattern (JC-001). The `step` signature is unchanged, so no contract surface moves.
The one consequence worth pinning — that the named-function call sequence in `step`
IS the load-bearing order criterion 2's reorder-to-fail test points at — is inherent
to the packaging and already stated in the entry. Disposition noted in decisions.md
(JC-013..021 ratifications block). No spec change, no code change.

### JC-014 · 2026-07-02 · TKT-P0-06 · `_enter_state` puts a freshly-entered state ON frame 1 this tick; phase 2 skips the advance for a same-tick entry — ratified
**Decided.** Entering a state (`_enter_state`) sets `frame_in_state = 1` directly (a
fresh entry IS on frame 1 the tick it is entered), and phase 2's frame-advance is
skipped for any state entered THIS tick (`entered_this_tick` guard). A state that was
already active last tick advances by one.
**Serves.** move-format.md (`frame_in_state` is 1-indexed; keyframes are 1-indexed
inclusive ranges); combat-resolution.md phase 2 ("advance `frame_in_state`"). The spec
fixes 1-indexing and "advance the frame"; the exact edge behavior on the ENTRY tick
(is a just-entered move on frame 0-then-advanced, or on frame 1 immediately?) is not
spelled out.
**Alternatives passed over.** Enter at frame 0, always advance to 1 (breaks when a
transition happens AFTER the advance in the same phase 2 pass — the new move would
sit at frame 0, uncovered by any keyframe, silently delaying every move by one tick);
entering at frame 1 but still advancing (double-counts the entry tick, putting a
fresh move on frame 2 immediately and skipping frame-1 boxes).
**Why.** Frame 1 must be a real, box-resolving frame the tick a move starts (its
startup begins immediately), so a move pressed on tick T has its frame-1 geometry
active on T. Entering at frame 1 + skipping the same-tick advance is the only reading
where a move's first authored frame is neither skipped nor doubled, and it makes
startup/active/recovery hand-math (JC-011) line up with the resolved boxes. Localized
to `_enter_state` + the phase-2 guard.
**Ratified as latitude** (Architect, 2026-07-03). This is the unique reading under
which a move's first authored frame (frame 1) is neither skipped nor doubled the tick
it starts, and it makes the JC-011 startup/active/recovery hand-math and the JC-019
loop/clamp indexing mutually consistent (all 1-indexed inclusive). move-format.md
already fixes 1-indexed inclusive keyframes and phase 2 "advance the frame"; the
entry-tick edge is filling a spelled-out mechanism, not choosing new behavior. The
three (JC-011 / JC-014 / JC-019) form one coherent 1-indexed frame model — verified
against the executed done-bar (frame-1 geometry active the tick a move starts).
Localized; reversible. No new contract surface. Disposition noted in decisions.md.

### JC-015 · 2026-07-02 · TKT-P0-06 · SOCD default (LR→neutral, UD→up) + facing resolution as one `resolve_intent`; raw stays raw in history — ratified into spec
**Decided.** SOCD normalization is one function (`socd_normalize`): Left+Right → drop
both (neutral horizontal), Up+Down → drop Down (Up priority), buttons/reserved
untouched. `resolve_intent` runs SOCD then maps raw L/R to forward/back by `facing`,
returning a plain intent dict the state machine reads by MEANING. The RAW frame is
pushed to `input_history` unchanged (phase 1); only the derived intent is cleaned.
**Serves.** input.md "SOCD normalization" (the default rule is stated there: LR→
neutral, UD→Up priority) and AD-002/AD-003 (raw stays raw; forward/back is sim-side).
The RULE and its being one sim-side source-agnostic function are the contract; where
the single point lives and the intent-record shape are open.
**Alternatives passed over.** Cleaning SOCD into `input_history` (destroys raw
fidelity for replay — AD-003 forbids); resolving forward/back at the input source
(AD-002 forbids — sources are dumb); separate SOCD and facing functions called at
scattered call sites (two normalization points — the thing "one function" prevents).
**Why.** input.md states the default rule explicitly, so implementing it is filling a
spelled-out mechanism, not choosing feel (the rule is "tunable in that one place" —
so the one place is `socd_normalize`, exactly here). One `resolve_intent` keeps SOCD
and facing as a single derivation the whole state machine shares, so no consumer
re-normalizes. NOTE: the SOCD default itself is a "gameplay-flavored choice the
Strategist may revisit" (input.md) — if it changes, it changes in `socd_normalize`
only; recorded as latitude because I implemented the spec's STATED default verbatim,
not a new choice.
**Ratified INTO the spec, not as bare latitude** (Architect, 2026-07-03). The
Developer flagged the right seam: this touches a rule multiple roles build against
(the scrutiny note called it out). But the SOCD default rule and its "one sim-side
source-agnostic function" mechanism were ALREADY owned in input.md + AD-003, and the
raw-L/R → forward/back facing conversion is ALREADY owned sim-side (AD-002/AD-003).
The Developer implemented those verbatim. The one thing not yet named — that SOCD and
facing are the SAME single `resolve_intent` derivation, with raw staying raw in
history and only the derived intent cleaned — I folded into input.md ("One derivation
for SOCD + facing"), so the single-normalization-point is an owned name, not an
implementation accident. No NEW decision was made (no AD needed); the default itself
stays the Strategist's to revisit in that one place. Code as written matches.

### JC-016 · 2026-07-02 · TKT-P0-07 · Damage scaling as a single `DamageScaling` definition (hit-count table); the done-bar's single hit is unscaled 100% — ratified
**Decided.** Damage scaling lives in ONE place (`DamageScaling.scaling_for_hit_count`,
`game/sim/damage_scaling.gd`): hit 1 = 100% (FP.ONE), each further hit −10%, floored
at 10%, returned as a fixed-point multiplier. Phase 5 applies it BEFORE subtracting
damage and surfaces the applied percent (HitRecord/PlayerView).
**Serves.** combat-resolution.md "Combo & damage accounting" ("Damage scaling applies
from a single scaling definition ... before damage is subtracted — deterministic and
surfaced"). The spec fixes the MECHANISM (single definition, applied pre-subtract,
surfaced); the step/floor NUMBERS are not specified.
**Alternatives passed over.** Inlining scaling in phase 5 (no single source — a second
scaling site could drift); a per-move scaling field (per-move variant — the drift the
consistency guard prevents); no scaling at P0 (leaves the "surfaced scaling" criterion
unbacked).
**Why.** combat-resolution.md demands a SINGLE scaling definition; a static namespace
is the one-source packaging (mirrors Advantage/Actionability). The specific
10%/10%-floor step is placeholder tuning (feel is the Strategist's, via the spec) and
is flagged in-file as slice-provisional; it does NOT affect the done-bar, whose single
hit is hit-count 1 → 100% → damage == base exactly (hand-checkable, independent of the
table). If the Strategist wants specific scaling values that is a spec/data change, a
one-place edit here — recorded as latitude because the MECHANISM (the contract) is
built to spec and only unspecified numbers are chosen, with the done-bar deliberately
insensitive to them.
**Ratified as latitude, with the number/mechanism split named** (Architect,
2026-07-03). combat-resolution.md demands a SINGLE scaling definition applied
pre-subtract and surfaced — that MECHANISM is the contract and is built to spec. The
specific 10%-step / 10%-floor NUMBERS are unspecified placeholder tuning: they are
feel, the Strategist's to set via the spec, and are correctly flagged slice-provisional
in-file. The done-bar is deliberately insensitive (hit-count 1 ⇒ 100% ⇒ unscaled), so
no P0 verdict rests on the numbers. **For QA:** treat the 10%/10%-floor values as
placeholder, not a golden to lock — golden the mechanism (single source, pre-subtract,
surfaced), not the specific curve. Disposition + the number/mechanism split noted in
decisions.md. No new AD (mechanism already AD-008/combat-resolution); no code change.

### JC-017 · 2026-07-02 · TKT-P0-06 · Pushbox mutual separation splits the overlap in half, odd remainder to player 1 (deterministic) — ratified
**Decided.** When two pushboxes overlap horizontally (phase 3), each is pushed out by
half the overlap along x; an odd remainder goes to player 1 (`rem = overlap - half`),
so the split is exact-integer and deterministic. Stage walls are then clamped so each
pushbox stays inside `[wall_left, wall_right]`.
**Serves.** combat-resolution.md phase 3 ("resolve pushbox collisions and stage
bounds"); AD-012 (our own AABB, integer). The spec fixes THAT pushbox/stage resolution
happens in phase 3 with our own integer overlap; the exact separation split is not
specified.
**Alternatives passed over.** Pushing only one player (asymmetric — one character walks
through the other); floating-point half (violates AD-014 integer math); dropping the
odd remainder (leaves a 1-subunit residual overlap that could linger, a determinism
smell). 
**Why.** Symmetric half-split is the conventional mutual-pushout and keeps neither
character privileged; the fixed odd-remainder-to-P1 rule makes the integer split total
and deterministic (the hash stays stable). Pure movement resolution, no feel value
beyond "characters don't overlap," localized to `_resolve_stage_and_pushboxes`. At the
FP scale (2^16 sub-units) a 1-subunit remainder is sub-pixel and invisible; the rule
exists only to keep the math exact.
**Ratified as latitude — with one caveat for QA** (Architect, 2026-07-03). Scrutinized
as a possible owned rule: the split touches `position`, which is hashed, so any
re-implementation that splits differently changes the hash. But there is no feel value
beyond "characters don't overlap," and the odd-remainder-to-P1 is a 1-sub-unit
(sub-pixel) tiebreak that exists only to keep the integer split exact and deterministic.
That is genuine movement-resolution latitude, not a contract multiple roles design
against. The one consequence: **QA determinism goldens will lock this specific
deterministic split** (it feeds the hash), so it must not drift silently — a later
different pushout is a conscious change with a golden update, not a quiet edit.
Recorded in decisions.md (JC-013..021 block). No new AD, no code change.

### JC-018 · 2026-07-02 · TKT-P0-07 · `neutral_restored_this_tick` is a RISING EDGE: both-actionable now AND not both-actionable at the start of this tick — ratified into spec (AD-025)
**Decided.** Phase 6 sets `neutral_restored_this_tick = both_actionable(post-phase-5
state) AND NOT both_actionable(input state)`. The pre-step both-actionable condition is
captured from `step`'s INPUT state before any mutation; the post condition after hit
resolution. So the flag is true on exactly the tick the pair TRANSITIONS from
not-both-actionable to both-actionable, and false every other tick (including a tick
where both were already actionable last tick, e.g. match start).
**Serves.** combat-resolution.md criterion 5 ("flags neutral restored exactly on the
tick both players become actionable — not before, not after") and AdvantageView.
neutral_restored. Criterion 5 pins the SEMANTICS (the exact transition tick); the
mechanism (rising-edge vs. a stored last-condition) is left to implementation.
**Alternatives passed over.** Flagging whenever both are actionable (fires every tick
after neutral returns, not just the transition — violates "not after"); storing a
separate "was neutral last tick" field in SimState (redundant — the input state already
IS last tick's state, so the edge is derivable without new serialized state); comparing
against post-phase-7 counters (would shift the edge by one tick — off by the counter
decrement).
**Why.** "Become actionable" is a transition, and a transition is a rising edge; the
input state passed to `step` is precisely last tick's state, so the edge needs no extra
serialized field (keeps SimState minimal, AD-001, and the hash small). Match start does
not spuriously fire because both were already actionable the prior tick. Localized to
phase 6 + the one `prev_both_actionable` capture in `step`. Recorded as latitude: it
implements criterion 5's stated semantics exactly; if the Architect intends a different
edge convention it is a one-line change in phase 6.
**Ratified INTO the spec (AD-025)** (Architect, 2026-07-03). This was correctly
scrutinized as contract-adjacent, not pure latitude: multiple roles read
`neutral_restored` (debug mode, QA harness, player-facing UI), and "become actionable"
is a semantics call the whole legibility surface depends on. The rising-edge reading is
the only one that satisfies combat-resolution.md criterion 5's "not before, not after,"
so it is now an OWNED rule in **AD-025** and stated in combat-resolution.md's neutral
bullet. The "no extra serialized field — the input state IS last tick's state" insight
is folded in too (keeps SimState minimal, AD-001). Implementation as written matches.
This is the history-of-under-classification pattern (JC-007 → AD-023) caught correctly
this time: contract-adjacent → owned rule, not a standing dev call.

### JC-019 · 2026-07-02 · TKT-P0-06 · A looping state wraps `frame_in_state` modulo its duration — ratified
**Decided.** In phase 2, a LOOPING state (idle/walk, `loop == true`) whose
`frame_in_state` advances past `duration` wraps back into `[1, duration]`
(`((f-1) % duration) + 1`). Once-through moves do not wrap (they end and return to idle).
**Serves.** move-format.md (`MoveState.loop` — "whether `duration` loops (idle/walk) or
plays once") + AD-001 derived box resolution (boxes resolve from keyframe ranges by
`frame_in_state`). The spec says a loop state loops; the exact frame arithmetic of the
wrap (and that it is 1-indexed) is not spelled out.
**Alternatives passed over.** Letting `frame_in_state` grow unbounded (box resolution
stops matching once it exceeds the loop's keyframe range — an idle character's hurtbox
would vanish after `duration` ticks, breaking overlap; also grows the hashed integer
without bound); resetting to 1 each tick (loses within-loop animation frames for a
multi-frame loop like a walk cycle).
**Why.** A loop must keep `frame_in_state` inside the authored keyframe range so the
derived boxes (and any looped motion) stay correct every tick; modulo wrap is the only
reading that both loops the animation and keeps box resolution matching. 1-indexed to
match keyframe indexing (JC-014). Localized to the phase-2 advance. Recorded as
latitude: it makes `loop` behave as move-format.md names it; a different loop-frame
convention is a one-line change here.
**Same-principle sibling.** A STUN-category state's exit is driven by `stun`, not by
`frame_in_state`, and a tuned stun (hitstun/blockstun frames, move-format.md → HitBox)
can OUTLAST the reaction state's authored keyframe span. To keep the defender's hurtbox
resolving through the whole stun (so it stays a valid combo target — TKT-P0-09), a
stun state CLAMPS `frame_in_state` at `duration` rather than wrapping (a reaction does
not loop its animation). Same "keep frame_in_state inside the authored keyframe range"
principle; clamp (not wrap) because a reaction plays once and then holds. Localized to
the same phase-2 advance; a different convention is a one-line change here.
**Ratified as latitude** (Architect, 2026-07-03). Scrutinized as a possible owned rule
(it is a frame-model behavior content and QA build against). But both halves are the
unique reading that keeps `frame_in_state` inside the authored keyframe range so
derived box resolution stays correct every tick — a loop that grew unbounded would lose
its hurtbox after `duration`; a stun that outlasts its reaction's authored span needs
the hurtbox held so the defender stays a valid combo target (TKT-P0-09). move-format.md
already fixes `loop` ("duration loops or plays once"); wrap-for-loop / clamp-for-stun is
filling that named mechanism, not a new choice, and is 1-indexed consistent with
JC-011/JC-014. This completes the coherent 1-indexed frame model (JC-011/14/19). No new
contract surface beyond move-format.md's existing `loop`; disposition in decisions.md.
No code change.

### JC-020 · 2026-07-03 · F-006 (test fix) · `test_inspection_view` reads hitstop_remaining against the sim's own post-step value, and pins the corrected constant (3→2) — ratified (test-only latitude)
**Decided.** In `test_inspection_view.gd` `_test_core_reads`, the "PlayerView.
hitstop_remaining reads state" check now asserts `pv.hitstop_remaining ==
s.players[0].hitstop` (the view equals the sim's own post-step value — the test's
stated single-source intent) plus a pinned literal check that the value is `2`. The
old expectation of `3` was stale.
**Serves.** F-006 (owner: Developer); combat-resolution.md criterion 4 + AD-010
(hitstop is countdown state the loop advances one tick per step). Verified against live
code: the test pre-sets `hitstop = 3` on the tick-0 state, so `was_frozen[0]` is true in
`step`, and phase 7 decrements the already-active hitstop by one — 3→2 after one step.
Two is the spec-correct value; 3 forgot that `step` advances one tick. (This is NOT the
contact-tick freshly-set-hitstop edge the Strategist described — it is the plainer
pre-existing-hitstop countdown; the `was_frozen` gate correctly decrements it.)
**Alternatives passed over.** Just flip the literal 3→2 (works, but a bare hand-computed
constant re-encodes the decrement and drifts again if the read point moves — the
`== s.players[0].hitstop` form makes the single-source check immune to it); change the
sim to leave a pre-set hitstop at 3 (would violate criterion 4 — hitstop must count down
one per tick — and satisfy a stale test at the cost of correctness; rejected).
**Why.** The check's purpose is "the view reads the sim's own value," so asserting
equality to the sim's own field tests exactly that without duplicating countdown logic;
the added literal `2` keeps the number legible and pinned to the traced spec value.
**Boundary.** TEST-ONLY. No sim code touched; the sim was already spec-correct.
**Ratified as test-only latitude** (Architect, 2026-07-03). No sim code touched; the
sim was already spec-correct (hitstop counts down one per tick, AD-010/criterion 4).
Asserting the view against the sim's own post-step field tests the intended
single-source property without re-encoding the countdown, and the pinned literal `2`
is the correctly-traced value (pre-set 3, `was_frozen` gate decrements once). This is
QA-territory test correctness but the fix is unambiguous and contract-neutral — nothing
to fold. Note for QA: the underlying F-006 is Developer-owned; this ruling covers only
the JC latitude, not that flag's resolution. No spec change.

### JC-021 · 2026-07-03 · F-007 (test fix) · `test_combat` phase-presence check uses `Callable(StepPhases, name).is_valid()` instead of instance `has_method` on the class — ratified (test-only latitude)
**Decided.** In `test_combat.gd` `_test_phase_order_is_load_bearing`, the four
"phase N is a named function" structural checks now bind each phase name as
`Callable(StepPhases, "phaseN").is_valid()` instead of `StepPhases.has_method("phaseN")`.
**Serves.** F-007 (owner: Developer); JC-013 (`StepPhases` is an all-static namespace
module). `has_method` is a non-static `Object` method; calling it on the `StepPhases`
class reference is rejected by Godot 4 ("make an instance instead"), and the parse
failure blocked the ENTIRE file so none of its phase-pipeline checks ran. `Callable(cls,
name).is_valid()` parses cleanly and is true iff the named static function exists — the
same `Callable.is_valid()` idiom already used in `local_device_source.gd`.
**Alternatives passed over.** Instantiate `StepPhases` and call `has_method` on the
instance (contradicts JC-013's never-instantiated static module, and the phases are
static so an instance is meaningless); drop the structural checks and rely only on the
behavioral phase tests (loses the explicit "each phase is a named function" assertion
criterion 2 points at); reflect via `get_method_list()` (more code, same result).
**Why.** The idiom tests exactly the original intent — each phase is a named, callable
function of the pipeline — while parsing under Godot 4's static/instance rules, and it
matches an idiom already in the codebase (consistency).
**Boundary.** TEST-ONLY. No sim code touched.
**Ratified as test-only latitude** (Architect, 2026-07-03). Consistent with JC-013's
`StepPhases` all-static never-instantiated module: `Callable(cls, name).is_valid()` is
the correct static-presence idiom under Godot 4 (instance `has_method` on the class
reference is rejected), and it restored the whole file's phase-pipeline checks that the
parse failure had blocked. Tests exactly criterion 2's "each phase is a named function"
intent, matches an existing codebase idiom, no sim code touched. Note for QA: F-007 is
Developer-owned; this covers only the JC latitude. No spec change.

### JC-022 · 2026-07-03 · TKT-P0-08 · Motion recognition = greedy ordered-token scan over the 9-frame window; a motion-id→token-sequence table — provisional
**Decided.** `InputBuffer.motion_recognized` recognizes a motion by scanning the last
`MOTION_WINDOW` (= 9, AD-022) frames of `input_history` oldest→newest, greedily advancing
a cursor through the motion's ordered direction-token list each time a frame satisfies the
next token; recognized iff all tokens are consumed within the window. The motion-id →
token-sequence mapping lives in one place (`_motion_tokens`): `236` = down, down-forward,
forward; `623` = forward, down, down-forward. Each token is facing-resolved (raw L/R →
forward/back) before matching; intermediate frames between tokens are allowed (leniency).
**Serves.** AD-022 / combat-resolution.md crit 11: "a motion is recognized if its
directions occur IN ORDER within the last 9 frames." The 9-frame WINDOW is the feel value
(AD-022, cited not chosen); *how* the ordered-in-window recognition is computed, and which
concrete motions exist + their token sequences, is left to implementation.
**Alternatives passed over.** Exact-consecutive-frame matching (no leniency — off-genre and
contradicts "occur in order within the window," which permits gaps); a per-character motion
table (drift — the recognizer must be uniform, AD-003/AD-022); storing partial-motion
progress in SimState (unnecessary — buffering is a PURE function of `input_history`, AD-003,
so it is re-derived each tick with no serialized recognizer state).
**Why.** A greedy oldest→newest cursor scan is the minimal computation of "these directions
occurred in this order inside the window," is a pure function of history (so replays/netcode
reproduce it for free), and keeps the leniency the window implies. The token table is the
one place motions are defined, mirroring the single-source packaging (FP/MoveData). If the
Architect wants specific canonical motions or a different leniency model, it is a localized
change in `_motion_tokens` / the scan. Recorded as latitude: it implements AD-022's stated
window semantics; no new serialized state, no contract surface (the buffer output feeds
phase 2 transitions, whose contract — 9f/6f windows — is AD-022's).

### JC-023 · 2026-07-03 · TKT-P0-08 · A CancelRule's `input` command is resolved via the button_map entry whose target == the rule target (raw-button fallback); group targets deferred — provisional
**Decided.** `CancelEval._input_buffered` resolves a cancel rule's required `input` command
by finding the character's `button_map` entry whose `target_state_id` equals the rule's
`target`, then checking that entry's command is buffered through the ONE recognizer
(`InputBuffer.entry_satisfied`) — so a cancel's input is recognized by exactly the same
buffering a neutral transition uses. If no matching entry exists, `input` is treated as a
raw button bitmask (BUTTON_0..7) and checked against the command buffer directly. A
`target_is_group` cancel (rule target names a SET of states) is skipped at P0 (the slice
authors no cancel groups).
**Serves.** move-format.md → CancelRule (`input` = "required command (button/motion)") +
crit 7 (cancels resolve per condition/window/input); AD-015. The format fixes that a cancel
HAS a required input command; *how the command id is matched against the recognizer* is not
spelled out (a `CancelRule.input` is an int; nothing pins whether it is a button bit, a
motion id, or a button_map key).
**Alternatives passed over.** Duplicating button/motion decode logic inside CancelEval
(a second recognition path that could drift from InputBuffer — the thing single-sourcing
prevents); requiring `input` to always be a raw button bit (loses motion-cancel inputs,
which the button_map already knows how to recognize); resolving groups now (no group
targets are authored in the slice, so it would be untested speculative code — Tenet 3 says
build for extension, not build unused).
**Why.** Routing the cancel's input through the button_map entry that already names how to
reach `target` means one recognizer decides "is this command buffered," so a cancel and a
neutral transition into the same state agree. The raw-button fallback keeps a bare-button
cancel authorable without a button_map round-trip. Deferring groups matches AD-016's
"deferred, explicitly" discipline (leave the field, don't build the unused path). Localized
to `_input_buffered`; if the Architect wants a distinct `input`-id namespace or group
resolution, it is a one-function change. Recorded as latitude: it fills the unspecified
command-matching mechanism with the single-recognizer reading; the CancelRule fields
(condition/window/input/requires_tag) are consumed exactly as move-format.md names them.

### JC-024 · 2026-07-03 · TKT-P0-09 · Throw tech-window length authored via the throwbox's (otherwise-unused) `blockstun` field; tech = undo-damage-both-to-idle — provisional (FORMAT-FIELD question for Architect)
**Decided.** The throw tech-window length (frames the defender may tech, AD-016) is read
from the throw `HitBox.blockstun` field, which is otherwise unused on a throwbox (a throw
is never blocked, so it has no blockstun semantics). The tech itself (`_try_throw_tech`)
restores the throw's damage to the defender, clears combo/stun, returns BOTH players to
idle, and pushes them apart by a placeholder constant. The clash (`_resolve_throw_clash`)
does the same push with no damage/stun and no throw at all.
**Serves.** combat-resolution.md "Throws" / AD-016: "a defined window after the throw
connects." The MECHANISM (a tech window opens on connect; a defender throw within it techs
to neutral, no damage; simultaneous throws clash) is the contract and is built to spec.
The window's *length source* is not specified, and the HitBox schema (move-format.md,
Architect-owned) has **no dedicated tech-window field** — so I did NOT add one (a format
change is the Architect's), and instead reused the throwbox's spare `blockstun`.
**Alternatives passed over.** Adding a `HitBox.tech_window` field (the cleanest long-term
shape — but a move-format *contract* change I don't own; raising it here as a question
rather than editing the schema); a sim-wide tech-window constant (uniform like the buffer
windows, but the tech window is not stated to be character-invariant, and a constant can't
be authored/tested per-throw); no tech window (leaves crit 10 unbacked).
**Why.** Reusing the spare `blockstun` keeps the tech window DATA-DRIVEN and testable
without inventing a schema field I don't own or hardcoding a feel value. The tech/clash
resolution (both-to-neutral, damage undone) is AD-016's stated outcome. **FLAG-ADJACENT —
for the Architect:** if throws should carry a dedicated `tech_window` field (clearer than
overloading `blockstun`, and the natural home for this feel value), that is a move-format
addition to decide at ratification; until then the `blockstun` reuse is the localized,
reversible P0 stand-in. The specific window length (8f in the test char) and push constant
are placeholder tuning (Strategist's, like JC-016's scaling numbers), not a golden to lock.

### JC-025 · 2026-07-03 · TKT-P0-09 · Rehit cadence via a parallel `active_hit_frames` run + produced-tick comparison; clash detected when both throwboxes connect the same tick — provisional
**Decided.** Cadenced re-hit (`HitBox.rehit_interval`, AD-016) is tracked with an
`active_hit_frames` PackedInt32Array kept PARALLEL to `active_hit_ids` (AD-026): index i is
the tick `active_hit_ids[i]` last connected. `_rehit_ready` allows a re-hit only when
`candidate_tick − last_connect ≥ rehit_interval` (no hit on the frames between); both the
recorded connect tick and the candidate use the tick the step PRODUCES (`next.tick + 1`),
so the comparison is on one consistent timeline. Simultaneous-throw clash is detected by
scanning the phase-4 contact list for a throw contact from BOTH attackers on the same tick
(`_both_throwboxes_connect`), resolved before any single throw so a mutual throw is a clash,
not one throwing the other.
**Serves.** combat-resolution.md "Multi-hit / rehit" + crit 9 (a rehit hitbox hits on its
cadence and not between) / AD-016; and "Throws" clash-to-tech / crit 10. AD-026 fixes that
single-hit uses per-attacker `active_hit_ids`; the CADENCE (how the interval is measured)
and the clash DETECTION are the implementation of AD-016's stated forms.
**Alternatives passed over.** Storing a single last-hit tick per attacker rather than
per-id_group (wrong for a move with several cadenced groups — each needs its own last-hit,
mirroring why AD-026 rejected keying on the global last_hit); measuring the interval in
`frame_in_state` rather than absolute tick (breaks across hitstop, which freezes
frame_in_state but not the intended cadence — absolute produced-tick is freeze-correct);
detecting a clash by checking both players are in a throw *state* rather than both
throwboxes *connecting* (a throw whose box misses shouldn't clash). The parallel-array shape
(vs. a dict) keeps the hash a simple order-committing run alongside `active_hit_ids`, and
the two stay length-synced (appended/cleared together).
**Why.** A parallel per-id_group last-connect tick is the minimal state that makes the
interval measurable per group and survives snapshot/restore (it is serialized/hashed with
`active_hit_frames`, F-010). Produced-tick comparison keeps cadence correct across hitstop
freezes. Both-throwboxes-connect is the literal reading of AD-016's "simultaneous ground
throw attempts." Localized to `_rehit_ready` / phase-5 dispatch; the `active_hit_frames`
field itself is the flagged contract addition (F-010), not this call. Recorded as latitude:
it implements AD-016's stated cadence + clash with the minimal serialized shape.

### JC-026 · 2026-07-03 · F-011 (test fix) · `_test_cancel_requires_tag` isolates the tag gate to LIGHT's COMMITTED window; adds a gate-liveness assertion — provisional (test-only latitude)
**Decided.** Rewrote `test_buffer_cancels._test_cancel_requires_tag` so it only feeds/inspects
BUTTON_1 while the whiffed LIGHT is still a *committed* move (state == LIGHT AND not
`Actionability.is_actionable`), stopping before LIGHT recovers to idle. Added one check — a
liveness assertion that the whiff/recovery window was actually reached (`move_contact ==
CONTACT_WHIFF` or at least `LIGHT_STARTUP` committed ticks were asserted) — so the isolated
test cannot vacuously pass by stopping before the gate is live. **Sim code untouched.**
**Serves.** F-011; combat-resolution.md crit 8 / move-format.md crit 7 / AD-015/017 — a
whiffed normal grants no cancel tag, so its `requires_tag` special-cancel is correctly gated.
**Root cause (confirms & refines the Strategist's first candidate).** The `requires_tag` gate
in `cancel_eval.gd::find_cancel` is correct and was NOT leaking: for a whiffed LIGHT,
`move_contact == CONTACT_WHIFF`, so the ON_CONTACT `_condition_holds` already returns false,
AND `_has_tag` fails (no tag granted). The cancel is correctly rejected. The failure was a
CONTAMINATED SCENARIO: SPECIAL is *also* directly reachable from neutral via the BUTTON_1
button_map entry (`test_support.gd _map(1,0,0,STATE_SPECIAL)`). The old test fed BUTTON_1 for
20 ticks; within that span the whiffed LIGHT recovers to idle, and the held BUTTON_1 enters
SPECIAL through the ordinary neutral-press path (`_buffered_command`, phase-2 step 5) — correct
sim behavior, but NOT the cancel. The test misread that neutral press as a leaked cancel.
**Alternatives passed over.** (a) Touch the sim — rejected: the gate is correct, the leak was
in the test's reachability, not the code; a sim change would break the correct behavior that a
recovered character can press BUTTON_1 into SPECIAL. (b) Move SPECIAL off the BUTTON_1 neutral
map / give it a distinct input in `test_support.gd` — rejected: BUTTON_1-in-neutral→SPECIAL is
load-bearing for the POSITIVE test `_test_special_cancel_on_hit` and mirrors real special
inputs; changing shared test-support data has wider blast radius than fixing the one scenario.
(c) Keep the check count at 26 by not adding the liveness assertion — rejected: without it the
isolated test can false-pass if the committed window is ever empty; the extra check is cheap
determinism insurance and makes the isolation self-verifying. Check count goes 26 → 27.
**Why safe.** Test-only; the positive cancel path is exercised by `_test_special_cancel_on_hit`
(cancel fires DURING committed LIGHT under hitstop, before recovery). This scenario now
exercises exactly the negative it claims: within LIGHT's committed whiff window, the tag gate
holds and no cancel occurs. Deterministic (pure over recorded input).
**Boundary.** F-009/F-010 (Architect-owned) untouched; no P1 work; no refactor beyond this one
scenario + its helper.
