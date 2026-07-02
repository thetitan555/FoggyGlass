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
