# Judgment-Call Log — Archive

> The permanent, append-only record of **closed** judgment calls (ratified,
> overturned, or superseded). Content ownership is unchanged from the live log —
> **Developer** wrote each entry, **Architect** wrote each ruling; they are
> reproduced here **verbatim** and never edited after archival (supersede in a new
> entry, as in the live log). The **Strategist** moves closed entries here — the
> ledger-archival duty, mirroring `flags-archive.md`.
>
> **Do not cold-read this file whole.** Find an entry via the index at the top of
> `judgment-log.md` and pull it by JC-id (Read by offset, or Grep the id). See
> `protocol.md` → the judgment-log discipline for why this split exists.

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

### JC-010 · 2026-07-02 · TKT-P0-04/05 · Inspection views + serialized-state backing fields packaged as plain-data classes — ratified (packaging latitude; the SimState fields were F-002/AD-024)
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
**Ratified as latitude** (Architect, 2026-07-04). The packaging this entry covers —
RefCounted copy-out view classes under `game/sim/views/`, `Resource` schema types
under `game/sim/data/` (AD-006 `.tres`), the runtime `Projectile` as a plain
`RefCounted` — is internal packaging of API/schema shapes the Architect already owns
(inspection-surface.md fixes the API shape + "no live node refs"; move-format.md fixes
the schema). Copy-out-by-construction is what makes the surface read-only structurally
(inspection-surface.md crit 2); fixed-point-only fields keep views golden-able (crit 4).
The one part that was NOT latitude — the serialized `SimState` fields the views require
(`character_id`, `stun_kind`, `combo_damage`, `last_hit`, `neutral_restored_this_tick`)
— was correctly escalated as **F-002** and is owned via **AD-024** (and AD-025 for the
neutral flag). So this entry's own scope is pure packaging latitude; nothing to fold. No
spec change, no code change.

### JC-011 · 2026-07-02 · TKT-P0-05 · "First actionable frame" for derived recovery = duration+1 (recovery = total − last_active) — ratified INTO the spec
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
**Ratified INTO the spec** (Architect, 2026-07-04). Contract-adjacent, not bare
latitude: frame data is read by the frame-data panel and QA (acceptance criterion 2
tests startup/active/recovery against hand-specified values), so the exact arithmetic
must be unambiguous, not left to a dev to re-derive. move-format.md's "Derived frame
data" section named the parts but not the arithmetic; the ratified reading — startup =
`first_active − 1`, active = `last_active − first_active + 1`, recovery =
`duration − last_active` (first actionable = `duration + 1`), total = `duration`, so the
three parts sum to total — is the unique internally-consistent reading and is now folded
into **move-format.md → "Derived frame data"** with the formulas inline. It is consistent
with the 1-indexed frame model (JC-011/14/19) already ratified in the JC-013..021 block
(`duration + 1` = the `frame_in_state > duration` end edge). Implementation matches; no
code change.

### JC-012 · 2026-07-02 · TKT-P0-07(pre-wired at 05) · Live-advantage party identification reads defender = the player in stun — ratified INTO the spec
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
**Ratified INTO the spec** (Architect, 2026-07-04). Scrutinized as contract-adjacent,
not bare latitude: multiple roles (debug mode, QA harness, player-facing UI) read the
live advantage, so "which player is the defender" is a semantics they must agree on —
the JC-007/JC-018 pattern (contract-adjacent → owned rule). AD-008 owned the formula
and the two surfaced values but was **silent on defender identification**; the
`stun > 0` reading is the formula's own meaning (`defender_remaining_stun` IS the
stunned party's count), the neither-stunned ⇒ 0/none is the "no interaction" reading,
and the both-stunned ⇒ greater-remaining-stun tiebreak keeps the hash deterministic.
Folded into **AD-008** ("Defender identification for the live value") and surfaced in
**combat-resolution.md**'s Advantage section. The `last_hit`-role-tracking alternative
is now explicitly rejected in the AD (it couples a continuing per-tick situation to the
last discrete hit). Implementation as written matches; no code change.

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

### JC-022 · 2026-07-03 · TKT-P0-08 · Motion recognition = greedy ordered-token scan over the 9-frame window; a motion-id→token-sequence table — ratified
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
**Ratified as latitude** (Architect, 2026-07-03). Scrutinized as contract-adjacent (content
authors and QA build against motion semantics). But the load-bearing contract — the 9-frame
in-order-within-window recognition — is already owned in AD-022; the greedy oldest→newest
cursor scan is the minimal *computation* of that stated semantics, and the motion-id→token
table is single-source packaging (FP/MoveData pattern), not a new rule. No serialized
recognizer state (buffering is a pure function of `input_history`, AD-003), no new contract
surface. Disposition in decisions.md (JC-022..027 block). **For QA:** the concrete slice
motions (`236`, `623`) and their token sequences are implementation the recognizer resolves
uniformly — golden the "in-order-within-9f" behavior, not a specific motion's internal
token list as a locked contract. No spec change, no code change.

### JC-023 · 2026-07-03 · TKT-P0-08 · A CancelRule's `input` command is resolved via the button_map entry whose target == the rule target (raw-button fallback); group targets deferred — ratified
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
**Ratified as latitude** (Architect, 2026-07-03). Scrutinized as contract-adjacent (how a
cancel's input is recognized is something authors reason about). But move-format.md already
fixes that a `CancelRule` HAS a required input command; routing it through the ONE
`InputBuffer` recognizer via the `button_map` entry that names how to reach `target` is the
single-recognizer reading — it makes a cancel and a neutral transition into the same state
agree, which is the consistency the format wants, not a new contract. The raw-button
fallback keeps a bare-button cancel authorable, and deferring group targets matches AD-016's
"leave the field, don't build the unused path" (no group cancels are authored in the slice).
Disposition in decisions.md (JC-022..027 block). No spec change, no code change.

### JC-024 · 2026-07-03 · TKT-P0-09 · Throw tech-window length authored via the throwbox's (otherwise-unused) `blockstun` field; tech = undo-damage-both-to-idle — overturned (folded into AD-029: dedicated `HitBox.tech_window`)
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
**OVERTURNED — resolved into an owned format decision (Architect, 2026-07-03, AD-029).** The
Developer correctly flagged this as a move-format contract question I own and did NOT edit
the schema — right call. Ruling: the `blockstun` reuse is **overturned** as the durable
shape. A `blockstun` value that means "on-block stun" on a normal but "tech-window length"
on a throwbox is exactly the implicit, dual-meaning field-overload that makes the format
harder to author against and harder for QA to golden (the field's meaning would depend on a
sibling `is_throw` flag). A throw's tech window is a genuine per-throw feel value and gets a
**dedicated `HitBox.tech_window` field** (AD-029, folded into move-format.md). The tech/clash
*resolution* the Developer built (both-to-neutral, damage undone, clash) is AD-016's stated
outcome and is unchanged — only the window's *authoring home* moves. **Back to the Developer:**
migrate `test_support.gd` (`tb.blockstun = THROW_TECH_WINDOW`) and the throw-path read off
`blockstun` to the new `tech_window` field; add the field to `hit_box.gd`. Localized,
reversible; the 8f length stays placeholder tuning. This is a schema question ratified into
the format, not dev latitude, and it is *not* a code defect (the sim behavior was correct) —
it is a durability/legibility improvement to where the value lives.

### JC-025 · 2026-07-03 · TKT-P0-09 · Rehit cadence via a parallel `active_hit_frames` run + produced-tick comparison; clash detected when both throwboxes connect the same tick — ratified
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
**Ratified as latitude** (Architect, 2026-07-03). The `active_hit_frames` *field* is the
owned contract addition — ratified separately into simulation.md under AD-028 (F-010); THIS
call is the cadence/clash *logic* that consumes it, and it implements AD-016's stated forms
with the minimal shape. Two implementation choices are correct and worth pinning: (1)
produced-tick comparison (not `frame_in_state`) is the freeze-correct reading — hitstop
freezes `frame_in_state` but not the intended real-time cadence, so absolute tick is right;
(2) both-throwboxes-*connect* (not both-in-throw-*state*) is the literal reading of AD-016's
"simultaneous ground throw attempts" — a throw whose box misses shouldn't clash. Disposition
in decisions.md (JC-022..027 block). No spec change beyond AD-028's field; no code change.

### JC-026 · 2026-07-03 · F-011 (test fix) · `_test_cancel_requires_tag` isolates the tag gate to LIGHT's COMMITTED window; adds a gate-liveness assertion — superseded by JC-027
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
**SUPERSEDED (Architect, 2026-07-03).** This fix was insufficient — its committed-window
isolation still let the 6-frame command buffer (AD-022) carry a held BUTTON_1 across LIGHT's
recovery boundary into SPECIAL via the *neutral* path (`_buffered_command`), which the test
misread as a leaked cancel; "reached SPECIAL" cannot distinguish a cancel from a buffered
neutral press. Corrected by JC-027 (whiff-vs-hit contrast at a fixed non-actionable frame +
positive control). No independent ratification: this entry is superseded, not ratified —
JC-027 is the ruled disposition. The sim was spec-correct throughout (no code defect); the
under-count was purely in the test's reachability premise.

### JC-027 · 2026-07-03 · F-011 recurrence (test fix) · `_test_cancel_requires_tag` gate isolation via committed-window CONTRAST + positive control — ratified (test-only latitude) — SUPERSEDES/CORRECTS JC-026
**Decided.** Rewrote `test_buffer_cancels._test_cancel_requires_tag` so it proves the tag
gate by a whiff-vs-hit CONTRAST asserted at a committed, NON-actionable frame — never by
observing "did P0 reach SPECIAL." Negative: a whiffed LIGHT is fed BUTTON_1 and asserted
STILL in LIGHT across its whole committed window (frames 1..11 of a duration-12 move),
with a liveness check that `move_contact == CONTACT_WHIFF` was reached (gate live). The
loop bound is fixed by frame math (`LIGHT_DURATION - 2` = 10 steps → frame 11), NOT by
`is_actionable`, so it NEVER steps to LIGHT's actionable frame (frame 12). Positive
control (added): a CONNECTING LIGHT (grants TAG_SPECIAL) fed the same buffered BUTTON_1
DOES special-cancel to SPECIAL via `find_cancel` DURING its committed window (before the
actionable frame). **Sim code untouched.**
**Serves.** F-011 (recurrence); combat-resolution.md crit 8 / move-format.md crit 7 /
AD-015/017/022 — a whiffed normal grants no cancel tag, so its requires_tag/on_contact
special-cancel is denied, while a connecting one is granted and cancels.
**Why JC-026 was insufficient (the correction).** JC-026 isolated *feeding* BUTTON_1 to
the committed window but did NOT account for the 6-frame COMMAND BUFFER (AD-022) carrying
a HELD BUTTON_1 across LIGHT's recovery boundary. SPECIAL is reachable by TWO paths — the
tag-gated cancel (find_cancel) AND a plain neutral press (`test_support.gd
_map(1,0,0,STATE_SPECIAL)`, via `_buffered_command`). On LIGHT's first ACTIONABLE frame
(frame == duration) the buffered press fires into SPECIAL through the NEUTRAL path — correct
AD-022 behavior, NOT a cancel. JC-026's loop still stepped to that frame (its top-of-loop
`is_actionable` guard breaks only on the NEXT iteration, but the buffered command enters
SPECIAL on the SAME tick frame reaches 12), so `cancelled` read true. Observing "reached
SPECIAL" simply cannot distinguish cancel from buffered-neutral-press when the buffer carries
the input across recovery. JC-027 fixes this by NEVER reaching the actionable frame in the
negative, and by making the positive/negative CONTRAST — not a reachability probe — the signal.
**Diagnosis confirmed against live code (Strategist's static read verified).** `find_cancel`
enforces requires_tag AND ON_CONTACT correctly; on a whiff `move_contact == CONTACT_WHIFF`
and no tag is granted, so the cancel is denied in the committed window — no sim leak. The
post-recovery buffered neutral press into SPECIAL is intended AD-022 and is NOT suppressed
(that would be a contract question to FLAG the Architect, not a code change).
**Alternatives passed over.** (a) Touch the sim to suppress the post-recovery neutral press —
rejected: it is correct AD-022 behavior (a held button comes out frame-1 on the first
actionable frame); suppressing it is a contract change, not a test fix. (b) Keep JC-026's
"stop before actionable via is_actionable guard" without changing the reachability premise —
rejected: that is exactly what failed (the buffered press fires ON the actionable-transition
tick, so the guard can't prevent the misattribution). (c) Move SPECIAL off the BUTTON_1
neutral map in test_support.gd — rejected (JC-026 reasoning still holds): that entry is
load-bearing for `_test_special_cancel_on_hit` and mirrors real special inputs; the fix
belongs in the one scenario, not shared test-support data.
**Why safe / correct by construction (no Godot available here).** The negative's loop count
is derived purely from LIGHT's authored frame data (startup 3 / active 3 / recovery 6,
duration 12): 10 whiff steps advance frame 1 → 11, all strictly below the actionable frame
12, so the neutral-press path is provably unreachable and the only route to SPECIAL is the
tag-gated cancel — which is denied. The positive control fires the cancel at the connect
frame (~4) under find_cancel while hitstop-frozen then first-unfrozen, far below frame 12.
Deterministic (pure over recorded input); no tick-precise timing that needs execution to trust.
**Boundary.** TEST-ONLY; sim spec-correct and untouched. F-009/F-010 (Architect-owned)
untouched; no P1 work; no refactor beyond this one scenario. Recurrence of archived F-011;
per the Strategist, correcting my own test needs no new flag. Check count of this scenario
rises (per-committed-frame state + non-actionable assertions, a whiff-liveness check, and
the positive-control cancel check) vs. JC-026's shape. Entry is append-only: JC-026 is
superseded, not rewritten.
**Ratified as test-only latitude (Architect, 2026-07-03).** This is the correct fix and
supersedes JC-026. The diagnosis is sound: the tag gate in `find_cancel` (requires_tag AND
on_contact) was spec-correct throughout — on a whiff, `move_contact == CONTACT_WHIFF` and no
tag is granted, so the cancel is denied — and the post-recovery buffered *neutral* press into
SPECIAL is intended AD-022 behavior, correctly left unsuppressed (suppressing it would be a
contract change, which the Developer rightly declined to make as a "test fix"). Proving the
gate by a whiff-vs-hit *contrast* asserted at a frame that never reaches the actionable frame
(so the neutral-press path is provably unreachable) is the right construction — it tests the
gate, not a reachability accident. No sim code touched. Note for QA: this validates the
`requires_tag`/`on_contact` gate (crit 8) is correct; the interaction between the 6-frame
command buffer and a move's recovery boundary (a held button firing frame-1 on the first
actionable frame) is intended AD-022 and is *not* a leak — worth a glance in the drift sweep
but it is spec-correct. No spec change, no code change.

### JC-028 · 2026-07-03 · AD-024 / F-009 (simulation.md crit 11) · `MoveRegistry` install-generation token packaged as a static `int` counter with an `install_generation()` accessor — ratified
**Decided.** The install-generation token AD-024/F-009 requires is a process-wide static
`int` counter (`MoveRegistry._install_generation`) incremented by one on every `install`
and every `clear`, exposed read-only through a static `install_generation() -> int`
accessor. No inspection-surface field, no serialization, no clone, no hash — it is
observable only through the accessor. QA reads `MoveRegistry.install_generation()`
directly at `step` time (the registry is a static namespace already globally reachable),
which is what the ticket names as sufficient absent a natural harness hook.
**Serves.** AD-024 ("the `MoveRegistry` exposes an install-generation token — a monotonic
counter bumped on every `install`/`clear`") + simulation.md crit 11 (the token captured
at a run's first `step` is identical at every subsequent `step`). The AD fixes THAT the
token exists, that it bumps on install/clear, and that it is observable-not-serialized;
its exact TYPE, NAME, and read-path packaging are left to implementation.
**Alternatives passed over.** A monotonic timestamp / uuid "identity" (the AD allows
"or equivalent identity", but a plain `int` counter is the minimal thing that satisfies
"monotonic, bumped on install/clear, comparable across steps" and is trivially
hand-checkable); adding the token to the inspection surface / a `SimState` field
(explicitly wrong — AD-024 keeps it OUT of state; it is not mutable sim truth, Tenet 2 /
AD-001, and must never enter the hash); a dedicated harness inspection hook (unnecessary —
the static accessor on a globally-reachable namespace is the natural read path the ticket
sanctions when no harness hook is more natural).
**Why.** A static `int` bumped on install/clear is the minimal implementation of the
monotonic token; the static accessor keeps the read observable without adding it to the
snapshot-able surface (which would risk it entering a golden — the exact thing AD-024/
AD-019 guard against for non-sim-truth). Purely additive to `MoveRegistry`; reversible;
touches no `SimState` shape, no contract the seam exposes. If QA (harness) prefers a
different read path or identity form, it is a localized change here.
**Boundary.** Wiring/precondition state only — NOT `SimState`. Explicitly not serialized,
cloned, or hashed.
**Ratified as latitude** (Architect, 2026-07-04). The load-bearing contract — the token
exists, is a monotonic counter bumped on every `install`/`clear`, is observable-not-
serialized, and the per-run stability invariant is assertable — is ALREADY owned in
**AD-024** and **simulation.md** (crit 11 + the install-generation invariant text). AD-024
explicitly leaves "a monotonic counter, **or equivalent identity**" and the read-path
packaging to implementation. So a static `int` counter + a static `install_generation()`
accessor on the globally-reachable `MoveRegistry` namespace is the minimal packaging of an
already-pinned token — genuine latitude, nothing new to fold. Correctly kept OFF the
inspection surface / out of `SimState` (Tenet 2 / AD-001 / AD-024), so it can never enter a
golden hash. Verified passing under the TKT-P0-11 audit. No spec change, no code change.

### JC-029 · 2026-07-03 · simulation.md crit 11 · The crit-11 install-generation assertion lives in `test_sim_state.gd` — ratified (test-only latitude)
**Decided.** The acceptance-criterion-11 check (token stable across a run's steps; bumps
on install/clear; NOT in the state hash) is added as `_test_roster_install_generation_
stable()` in `test_sim_state.gd` — the existing determinism/serialization test file that
already covers simulation.md crits 1/3/4/8/9. It installs `TestSupport.build_roster()`,
captures the token at the first step, asserts it is unchanged across six steps, asserts a
token bump does not change the `SimState` hash, and asserts install/clear each bump it;
`_init` now `MoveRegistry.clear()`s at teardown for isolation (matching `test_done_bar`).
**Serves.** simulation.md crit 11 + the ticket ("update/extend affected tests"). QA owns
what "verified" means (TKT-P0-11 harness); this is the developer-side test written as I
build, not a harness verdict.
**Alternatives passed over.** A new standalone test file (more headless runners for QA to
wire; crit 11 is a determinism-precondition, so it belongs with the other simulation.md
determinism crits already in `test_sim_state.gd`); asserting via the inspection surface
(the token is deliberately NOT on the surface — JC-028 — so there is nothing to read
there); folding it into `test_done_bar` (that file is the DONE-BAR scenario, not the
determinism-crit home).
**Why.** Co-locating crit 11 with the sibling determinism crits it belongs to keeps the
one determinism/serialization test file the single place those criteria are exercised, and
the teardown `clear()` keeps the per-run token semantics clean between test files.
**Boundary.** TEST-ONLY. No sim code touched by THIS call (the sim change is JC-028's
accessor). Provisional pending QA's TKT-P0-11 harness, which may supersede or relocate it.
**Ratified as test-only latitude — the pending condition is now met** (Architect,
2026-07-04). The blocking condition ("provisional pending QA's TKT-P0-11 harness") is
resolved: TKT-P0-11 landed and PASSED (`docs/audits/audit-tkt-p0-batch1.md`: TKT-P0-11
PASS, all 9 test files pass). Verified the harness did **not** relocate or supersede the
assertion — `_test_roster_install_generation_stable()` still lives in `test_sim_state.gd`
(lines 178+) alongside the sibling determinism crits (1/3/4/8/9), which is the correct home
for a determinism-precondition. Co-locating there (rather than a standalone runner or
`test_done_bar`) is sound test latitude; the surface-read alternative is correctly rejected
(the token is deliberately not on the surface, JC-028). No sim code touched; no spec change.

### JC-030 · 2026-07-04 · TKT-P1-04 · `RecordPlaybackSource` production model: one `produce_next()` per tick feeding a uniform `_answers` reproducibility history, distinct from the mode-specific `_buffer` script — ratified
**Decided.** `RecordPlaybackSource` (`game/sim/record_playback_source.gd`) tracks TWO
parallel arrays: `_buffer` (the RECORDING artifact / PLAYBACK script — what training-
mode.md calls "the buffer") and `_answers` (every frame this source has actually
produced, in order, regardless of mode — the InputSource reproducibility history
`get_input(frame)` answers from). `produce_next()` is the one driver-facing method
that advances both mode-specific behavior and the answer history in lockstep; a
looped PLAYBACK re-reads `_buffer` at a wrapped cursor but still appends a NEW entry
to `_answers` each call, so `get_input` stays a simple, uniformly-growing indexed
read (mirroring `LocalDeviceSource`/`ReplaySource`) even though PLAYBACK's underlying
script is fixed-length and reread.
**Serves.** TKT-P1-04 (`RecordPlaybackSource : InputSource` with PASSTHROUGH/
RECORDING/PLAYBACK over a raw InputFrame buffer, looping) + input.md's `InputSource`
contract (frame-indexed, reproducible, no-future-reads) which every producer —
including this one — must satisfy uniformly. The ticket fixes the three modes and
looping; it does not fix the internal storage split.
**Alternatives passed over.** A single array serving both roles (in PLAYBACK, once the
cursor loops, `get_input(frame)` for two different `frame` values would have to map to
the same buffer slot by `frame % buffer.size()` — correct for the contract, but it
makes `get_input`'s indexing mode-dependent, which the training-mode reset harness
(TKT-P1-03) and any QA replay tooling would then need to know about instead of
treating every `InputSource` identically); recomputing `produced_count` from
mode+cursor arithmetic instead of storing it (fragile across the restore path — AD-020
needs `produced_count`/history restored atomically as one position, not re-derived).
**Why.** Keeping `get_input` a plain, uniformly-growing indexed read over `_answers` —
never a modulo/branch on mode — means this source honors the InputSource contract
exactly like `LocalDeviceSource`/`ReplaySource` do, so nothing downstream (the tick
host, a rollback re-simulation, QA's replay runner) needs mode-aware special-casing.
The cost is a second parallel array, which is cheap (frame counts are small) and
mirrors the `active_hit_ids`/`active_hit_frames` parallel-array pattern already
ratified in `SimState` (AD-028). If the Architect prefers a single derived-index
scheme instead, it is a localized change to `get_input` + the position dict shape.
**Restorable position (AD-020).** `get_playback_position()`/`set_playback_position()`
snapshot `{playback_cursor, produced_count, answers}` as one plain Dictionary (no
floats, no live refs) — deliberately NOT `_buffer` (the recorded/authored script is
not part of "position"; AD-020 restores the reset point's sim state and *playback
position*, not the recording itself). This is external to `SimState` throughout
(Tenet 2); TKT-P1-03's reset harness is the one place this position is bundled with
the sim `StateBlob`.
**Boundary.** New sim-facing source type; no existing contract file touched. Recorded
as latitude because input.md fixes the `InputSource` interface and reproducibility
contract precisely, and every choice here is in service of satisfying that contract
uniformly — not inventing new contract surface.
**Ratified as latitude** (Architect, 2026-07-04). Correct build of input.md's already-owned
`InputSource` contract (frame-indexed, reproducible, no-future-reads), which every producer
must satisfy uniformly. The dual `_buffer` (recording/playback script) vs `_answers`
(uniform reproducibility history) split is the reading that keeps `get_input` a plain
uniformly-growing indexed read — never a mode-dependent modulo/branch — so nothing
downstream (tick host, rollback re-sim, QA replay runner) needs mode-aware special-casing.
That is exactly what the contract wants; the parallel-array cost mirrors the ratified
`active_hit_ids`/`active_hit_frames` pattern (AD-028). The restorable-position dict
(`{playback_cursor, produced_count, answers}`, no `_buffer`) correctly honors AD-020
("restore the reset point's sim state *and playback position*, not the recording itself")
and stays external to `SimState` (Tenet 2). No contract surface moves; nothing to fold —
the `InputSource`/AD-020 contracts already own everything this call satisfies. No spec
change, no code change.

### JC-031 · 2026-07-04 · TKT-P1-03 · `TrainingHarness` (new class) owns snapshot/restore + the single reset slot, sits above `TickHost`, and is the "driver" that produces registered dummies before stepping — ratified
**Decided.** A new `game/sim/training_harness.gd` (`class_name TrainingHarness`)
holds a `TickHost` reference and a `{id -> RecordPlaybackSource}` registry.
`snapshot()`/`restore()` thin-wrap `SimHarness.dump_state`/`load_state` (the
existing StateBlob format — no second serialization path). `capture_reset()`/
`do_reset()` bundle the sim StateBlob with every registered source's
`get_playback_position()`/`set_playback_position()` into ONE reset-point
Dictionary (single slot, overwritten wholesale each capture — training-mode.md).
`TrainingHarness.step_once()` additionally calls `produce_next()` on every
registered source BEFORE calling `TickHost.step_once()` — i.e. this harness is
the "driver" input.md's produce-before-query ordering names as owned by
"whatever layer holds both the sources and the runner," which training-mode.md /
AD-020 already identify as this harness for the reset coordination.
**Serves.** training-mode.md "Control layer" (snapshot/restore, single reset
slot, restores sim AND playback position — AD-020) + input.md's owned
produce-before-query invariant (criterion 7: "the ordering is owned by the layer
that drives the tick... not by the sources themselves"). The spec fixes WHAT the
reset point bundles and WHO coordinates it (this harness); it does not fix the
harness's class shape or that it also has to double as the tick driver for a
source with no engine-side production hook of its own.
**Alternatives passed over.** Making `RecordPlaybackSource` self-driving (e.g.
producing its own frame lazily inside `get_input` the first time a tick is
queried) — this would violate input.md's explicit "no future reads" / "sources
never know if a query is current or future" design (input.md: "a source cannot
know whether the frame it is asked for is current or future; only the driver
knows") and would silently reintroduce per-source ordering assumptions; pushing
production into `TickHost._advance` itself — rejected for the same reason
JC-009/F-001 already rejected it for device sources: the host holds only the
abstract `InputSource` (no `produce_next`), and coupling it to a concrete source
type breaks "nothing in the sim knows which concrete source it holds"; requiring
the CALLER to manually call `produce_next()` on every dummy before every
`TickHost.step_once()` (works, but duplicates exactly the bookkeeping this
harness already does for reset — the registry that knows "which sources exist"
is the natural single owner of "which sources need producing this tick").
**Why.** `TrainingHarness` already sits in the one place AD-020 names as owning
reset coordination — above the sim, holding both the runner and the sources — so
it is also the natural, already-justified owner of produce-before-query for
those SAME sources (a second location would duplicate the registry). A caller
driving a 2P-local match with a real device for P1 still produces that device's
frame however it already does (tree order / explicit poll, JC-009's precedent);
`TrainingHarness.step_once()` only drives the sources IT owns (registered
dummies), so it composes with an externally-produced device source rather than
assuming exclusive control of the tick. This surfaced empirically: a test
driving `TickHost.step_once()` directly with a `RecordPlaybackSource` in
PLAYBACK asserted (future-read) because nothing had called `produce_next()` for
that tick — confirming the ordering must be owned somewhere, and this harness is
where AD-020 already put the coordinating authority.
**Alternatives for the class shape.** Folding this directly into `TickHost`
(rejected: `TickHost` is sim-clock-only per its own docs — "the host owns only
the sim clock," reset/source coordination explicitly deferred to "the
training-mode harness above the sim," AD-020's own words); a bare set of static
functions instead of an instantiable class (rejected: the reset slot and source
registry are genuinely per-match-instance state, not stateless computation —
unlike `Advantage`/`MoveData`'s static-namespace pattern, which have no instance
state to hold).
**Boundary.** New harness class above the sim; no sim-facing contract changed
(`SimState`, `step`, `InputSource`, `TickHost`'s existing frame-control API are
all unchanged). Recorded as latitude because training-mode.md/AD-020 already
name what this class must do and who is responsible for it; the class's shape
and its `step_once()` driver responsibility are the implementation filling that
already-owned mandate.
**Ratified as latitude** (Architect, 2026-07-04). `TrainingHarness` fills an
already-owned mandate: AD-020 puts reset coordination "above the sim, holding both
the runner and the sources," and input.md's produce-before-query invariant (criterion 7)
explicitly assigns ordering to "the layer that drives the tick... not the sources
themselves." This harness *is* that layer, so it owning `step_once()`'s
produce-before-query for the sources it registers is the invariant's own placement, not
a new rule. The rejected alternatives are all correctly ruled out on already-settled
grounds: self-driving sources violate input.md's "no future reads / a source cannot know
if a query is current or future"; pushing production into `TickHost._advance` repeats the
exact coupling JC-009/F-001 already rejected for device sources ("the host holds only the
abstract `InputSource`; nothing in the sim knows which concrete source it holds"). Thin-
wrapping `SimHarness.dump_state`/`load_state` (no second serialization path) is right —
it keeps one StateBlob format. It composes with an externally-produced device source
(drives only the sources it owns), so it does not assume exclusive tick control. No sim-
facing contract moves; nothing to fold beyond noting this harness is the concrete "driver"
input.md criterion 7 and AD-020 already name. No spec change, no code change.

### JC-032 · 2026-07-04 · TKT-P1-0P · Authored projectile shell named `ProjectileData` (not `Projectile`), resolved through a new `ProjectileRegistry` by `data_id` — mirrors `Character`/`MoveRegistry` exactly — ratified INTO the spec (AD-030)
**Decided.** move-format.md's authored `Projectile` table is implemented as
`game/sim/data/projectile_data.gd`, `class_name ProjectileData extends Resource`
— NOT named `Projectile`, because the runtime SimState entity already owns that
identifier (`game/sim/projectile.gd`, a `RefCounted` living in
`SimState.projectiles`, wired at TKT-P0-05 per JC-010's packaging). A new
`ProjectileRegistry` (`game/sim/projectile_registry.gd`) holds the authored
`data_id -> ProjectileData` roster, install-once per run, exactly mirroring
`MoveRegistry`'s shape/rationale (AD-024: authored content is a fixed input, not
`SimState`). The runtime `Projectile` entity carries a plain int `data_id`
(serialized/hashed) instead of a live `HitBox` reference; `Projectile.from_dict`
re-attaches `hitbox` via `ProjectileRegistry.data(data_id).hitbox` on restore —
this is exactly the gap the existing P0-era comment in `projectile.gd` already
flagged ("re-attaches it from move data by projectile id at spawn re-derivation
(TKT-P1)").
**Serves.** move-format.md → `Projectile` (authored fields: owner, position,
velocity, hitbox, lifetime, max_per_owner) + AD-021 (projectiles are first-class
serialized sim entities) + AD-024 (authored content stays out of serialized
state, resolved through an installed roster). The format NAMES the authored
shell "Projectile" and its fields; it does not anticipate the GDScript identifier
collision with the already-built runtime entity of the same conceptual role, nor
say how a live projectile resolves its authored hitbox across a restore.
**Alternatives passed over.** Naming the runtime entity something else instead
(e.g. `LiveProjectile`) to free up `Projectile` for the authored shell — rejected
because the runtime entity was already ratified and built at TKT-P0-05 (JC-010)
and is the class every other file (`SimState.projectiles`, `ProjectileView`,
`SimHarness`) already references by that name; renaming it now touches more
surface than naming the NEW authored type differently. Serializing the `HitBox`
object directly on the runtime entity (rejected: authored data does not belong
in the snapshot, per AD-024's exact reasoning for `character_id`/`MoveRegistry` —
a HitBox is fixed content, and serializing it would put non-hashed-consistently
authored geometry inside the "mutable sim truth" the canonical hash commits to).
A single shared registry keyed by an opaque handle across both `Character` moves
and projectiles (rejected: conflates two different authored-content domains for
no benefit; `MoveRegistry`/`ProjectileRegistry` mirroring each other 1:1 is more
legible than one registry with two id namespaces).
**Field split from the spec table (see file header comment for detail).**
move-format.md's `Projectile` table lists `owner, position, velocity, hitbox,
lifetime, max_per_owner`. Of these, `owner` is known only at spawn time (the
casting player, from `SimState`) and `position`/`velocity` are already carried on
the spawning `Keyframe` (`spawn_offset_x/y`, `spawn_velocity_x/y` — move-format.md
Keyframe.spawn: "{ projectile, offset, velocity }"). So `ProjectileData` authors
only what is genuinely part of the projectile's own fixed design: `hitbox`,
`lifetime`, `max_per_owner` (plus the new `id` for registry resolution). This is
a reading of an already-fixed table, not a new field invented — the ticket text
explicitly separates "spawn keyframe action with per-owner cap" (the mechanism)
from what the shell itself needs to author.
**Why.** The 1:1 mirror of `MoveRegistry`'s already-ratified pattern (F-004/
AD-024) is the cheapest-to-reason-about resolution: anyone who understands how
`character_id` resolves through `MoveRegistry` already understands how
`data_id` resolves through `ProjectileRegistry`, with identical install/clear/
determinism discipline. Keeping the runtime entity's existing name and giving
the NEW authored type a distinct one is the smaller diff against already-shipped
P0 code.
**Boundary.** New authored resource type + new registry; no existing contract
file's fields renamed. Recorded as latitude because AD-021/AD-024 already fix
the shape's principles (first-class serialized entity; authored content stays
out of state, resolved via an installed roster) — the class-naming collision and
its resolution are implementation, not a new design decision.
**Ratified INTO the spec (AD-030), not as bare latitude** (Architect, 2026-07-04).
The Developer built the right thing on the right principles (AD-021/AD-024), but two
parts of this call are move-format *contract* I own, not standing dev latitude, so they
must live in the spec: (1) the naming collision was a genuine **defect in move-format.md**
— the table named an authored shell `Projectile` that must coexist with a shipped runtime
class of the same conceptual role, so the authored type is renamed `ProjectileData` and
the format text is fixed to match; and (2) the **authored field split** (`ProjectileData`
authors `id`/`hitbox`/`lifetime`/`max_per_owner`; `owner`/`position`/`velocity` are
spawn-time/keyframe values on the runtime entity) and the **`data_id`-carries-across-
restore** rule (runtime entity serializes a plain int, re-attaches `hitbox` via
`ProjectileRegistry` on `from_dict` — never serializing the `HitBox`, per AD-024) are
contract multiple roles author and golden against. All folded into **AD-030** and
reflected in move-format.md's `ProjectileData` table + a "Projectile resolution &
serialization" note. The `ProjectileRegistry` 1:1 mirror of `MoveRegistry` (install/clear/
generation-token) is exactly right and inherits AD-024/F-009's install-generation
invariant. This is the JC-007→AD-023, JC-018→AD-025 pattern applied again: a call touching
an owned format is ratified into an owned rule, not left a standing dev decision. Code as
built matches AD-030; no code change required — the ruling folds the contract into the spec
where authors and QA read it.

### JC-033 · 2026-07-04 · TKT-P1-0P · Spawn fires once on the exact tick a spawning keyframe's range is ENTERED (`frame_in_state == frame_start`), not once per covered frame — ratified INTO the spec (AD-030)
**Decided.** `StepPhases._process_spawn` (phase 3) fires a keyframe's `spawn`
action only on the tick `frame_in_state` equals that keyframe's `frame_start` —
a one-shot per keyframe range. A `spawn` keyframe spanning multiple frames (e.g.
frames 3..5) still spawns exactly once, on frame 3.
**Serves.** move-format.md → `Keyframe.spawn` ("Optional. Spawns a projectile
this range") + AD-021/combat-resolution.md phase 3 ("process any spawn actions
firing this tick"). The format says a spawn action is attached to a frame
RANGE, not a single frame, but does not say whether it fires once (at the
range's start) or on every frame the range covers.
**Alternatives passed over.** Firing on EVERY covered frame (rejected outright:
a 3-frame spawn range would spawn 3 projectiles from one authored action,
silently defeating the whole per-owner cap mechanism the ticket names — an
author writing "this attack releases one fireball, active for a few frames of
authoring convenience" would get a burst instead); firing only once per MOVE
regardless of how many spawn keyframes it has (rejected: this format already
supports multiple DISTINCT spawn keyframes in one move's timeline for a
multi-projectile attack — e.g. a double-fireball special — and collapsing to
"once per move" would break that authorable case for no reason the format
implies).
**Why.** A keyframe range is authoring convenience (move-format.md: "Keyframed,
not per-frame ... compact to author"), not a per-frame repeat instruction — this
matches how hitboxes work (a hitbox authored across frames 4..6 does not deal
damage three times; it is one hit, collapsed by `id_group`). Firing once at
`frame_start` is the projectile-spawn analogue: an author names "release on
frame N, and the geometry/keyframe range around it is just how long that
authoring block covers," which is exactly what "this attack releases a fireball
on frame N" means in fighting-game authoring convention. If the Architect
intends spawn ranges to matter differently (e.g. "spawns once, but may occur
anywhere the tick first enters the range after a cancel/rewind" edge case), that
is a one-line change to the trigger condition in `_process_spawn`.
**Boundary.** Implementation of an under-specified mechanism; no field renamed
or added beyond what move-format.md already names (`has_spawn`, `spawn_offset_*`,
`spawn_velocity_*`). Recorded as latitude, not a flag, because move-format.md's
"per-owner cap" and "if the cap is full the spawn is suppressed" language already
presumes a single discrete spawn EVENT per firing, which the once-per-range
reading is the natural way to produce.
**Ratified INTO the spec (AD-030)** (Architect, 2026-07-04). The Developer read the
under-specified mechanism correctly — the once-at-`frame_start` firing is the unique
reading consistent with the per-owner cap language (which presumes one discrete spawn
event) and with how a hitbox authored across an active range is one hit, not one per
frame. But this is **release-timing contract that character A's fireball is tuned
against** (character-a.md: "projectile spawns frame 14"), so it must not stay a standing
dev call — it is folded into **AD-030** and stated in move-format.md's `spawn` keyframe
row. An author now reads "a spawn fires once, on the `frame_start` tick of its keyframe
range" directly in the format. Ratified-into-spec, not bare latitude, precisely because
character-A authoring (Batch 2) tunes the fireball's release frame against it. No code
change (build matches AD-030).

### JC-034 · 2026-07-04 · TKT-P1-0P · A projectile does not integrate (move) or age (lifetime decrement) on the same tick it spawns — mirrors the existing `was_frozen` hitstop convention — ratified INTO the spec (AD-030)
**Decided.** `SimState.step` captures `existing_projectile_count` (how many
projectiles existed in the PRE-step state, before phase 3 can append new ones)
alongside the existing `was_frozen` hitstop capture. Phase 3's "integrate every
live projectile" loop only integrates projectiles at index `< pre_spawn_count`
(captured locally at the top of `phase3_movement`, before that tick's spawns are
appended); phase 7's lifetime/despawn pass only decrements/off-stage-checks
projectiles at index `< existing_projectile_count` (the value threaded from
`step`). A projectile spawned this tick appears at its exact authored spawn
position, with its full authored lifetime, and starts integrating/aging on the
FOLLOWING tick.
**Serves.** combat-resolution.md phase 3 ("Integrate live projectiles' positions
too ... and process any spawn actions firing this tick") + AD-021 ("integrates
each tick independently of the owner") + "despawns when lifetime elapses." The
spec fixes THAT integration and spawn happen in phase 3 and that lifetime/
despawn happens as counters advance; it is silent on whether a projectile
spawned THIS tick is also integrated/aged THIS SAME tick.
**Alternatives passed over.** Integrating/aging a projectile the same tick it
spawns (this was the FIRST implementation and was caught by this ticket's own
tests: with the fireball's authored spawn offset landing exactly at a stage
wall in one test, the projectile would integrate one more step and immediately
register as off-stage the SAME tick it appeared — an artifact of applying two
different "advance" operations to the same tick's data, not a real gameplay
result. It also silently shortens the authored lifetime by one tick relative to
what a frame-data reader would expect from the authored value, and depends on
spawn-vs-integration ORDER within phase 3 in a way nothing pins).
**Why.** This is the exact same "a freshly set N does not count down/advance the
same tick it is set" principle AD-010 already establishes for hitstop (a
freeze of N frames must hold for N FOLLOWING ticks, not N-1) — `was_frozen`
already exists in `step` for precisely this reason. Applying the identical
convention to projectile spawn/lifetime keeps the mental model uniform: "a
newly-created countdown/position starts exactly at its authored value and only
changes starting the next tick," rather than projectiles being a special case
with their own off-by-one rule. Implemented via the same technique (`step`
captures a PRE-phase-3 count, threaded through to the phases that need to
distinguish new-this-tick from pre-existing).
**Boundary.** Internal step-pipeline sequencing; does not change any authored
field's meaning (a `lifetime` of 40 still means "40 ticks of life," now measured
starting the tick AFTER it spawns, matching how `hitstop` is already measured).
Recorded as latitude because it is filling an unstated edge case using an
already-established, spec-adjacent convention (AD-010's own reasoning), not
inventing a new rule from nothing — flag-worthy only if the Architect wants
spawn-tick integration to behave differently for feel reasons.
**Ratified INTO the spec (AD-030)** (Architect, 2026-07-04). The convention is the
right one — it is AD-010's own `was_frozen` reasoning ("a freshly-set countdown holds
for N *following* ticks, not N-1") applied to projectile spawn/lifetime, which keeps the
mental model uniform and avoids the double-advance artifact the Developer's own tests
caught (a spawn landing at a wall reading off-stage the same tick). Ratified into the
spec rather than left as bare latitude because it is **directly load-bearing for tuning
character A's fireball lifetime and reach** (character-a.md § Fireball): an author must
know that a `lifetime` of N is counted from the tick *after* the spawn frame, and that
travel begins the tick after the projectile appears — otherwise the fireball's on-screen
reach is mis-tuned by one tick. Folded into **AD-030** with the explicit authoring
consequence spelled out (spawn frame 14 ⇒ exists at frame 14, first moves/ages frame 15).
No code change (build matches AD-030).

---

### JC-A-01 · 2026-07-04 · TKT-P1-10 · Jump arc authored as a hand-baked triangular vel_y profile (no gravity primitive) — ratified
**Decided.** Character A's ~45-frame jump (`STATE_JUMP_N/F/B`, `game/content/
character_a.gd`) is authored as one-frame `Keyframe`s carrying an explicit
per-frame `motion_vel_y`: a constant rise velocity for the first 22 frames, a
constant fall velocity (same magnitude) for the remaining 23, sign-flipped at
the apex — a triangular position curve, not a true parabola. Horizontal carry
(0 / forward / back) is a constant `motion_vel_x` per state, matching the
existing keyframe-motion mechanism exactly (`StepPhases._apply_keyframe_motion`
already applies whatever `vel_x`/`vel_y` a covering keyframe authors, integrated
by plain fixed-point add — no new engine code needed).
**Serves.** `character-a.md` → Movement table (`Jump 7/8/9`, "~45f airborne, no
air dash, no double jump, no jump cancels").
**Alternatives passed over.** A true parabolic arc (a per-frame table baked from
a quadratic) — mechanically identical authoring cost (still one `vel_y` value per
frame; the engine has no gravity constant to lean on either way, so "parabolic"
vs. "triangular" is purely which numbers I bake, not a different mechanism) but
more frames of hand-tuned numbers for a P1 batch whose numbers are already
provisional-until-playable (`character-a.md` "Tuning status"). Escalating jump
entirely (declining to author it) — rejected because the movement table's
authored values are real content the ticket asks for and nothing about a
keyframe-driven arc requires an engine change.
**Why latitude, not a flag.** The *shape* of a jump arc (triangular vs.
parabolic vs. any other curve) is exactly the kind of tuning-by-feel number
`character-a.md`'s "Tuning status" section already defers to the training mode
("every number ... provisional until playable ... tuned by feel"); the
*structural* fact the spec pins is "player jumps and airborne category holds
for ~45f," which this satisfies. No tenet or contract is touched (no new
`SimState` field, no new phase, no new authored-format field).
**Boundary / reversibility.** Purely a content choice inside one file; swapping
to a smoother per-frame curve later is a data-only edit, no format change.
**Note.** The jump states are authored but **not reachable via `button_map`** in
this batch (see `docs/flags.md`'s command-recognition flag) — the arc's shape is
therefore unverified in a live input stream; dev tests drive the state directly
to assert the keyframe motion integrates correctly.

---

### JC-A-02 · 2026-07-04 · TKT-P1-10 · Six concrete `CancelRule`s per cancellable normal, not one group-targeted rule — ratified
**Decided.** Each of A's four special-cancellable normals (`5L`/`5M`/`2L`/`2M`)
carries **six** `CancelRule`s (one per concrete target: fireball L/M/H, DP L/M/H),
all sharing `condition = ON_CONTACT`, `requires_tag = TAG_SP`, default window,
differing only in `target`/`input` — rather than one rule targeting a "specials"
group.
**Serves.** `character-a.md` → Cancels ("Cancellable normals carry
`cancel_tags: ["sp"]`; Fireball and Shoryuken are `CancelRule`s with
`requires_tag: "sp"` ... `> 236/623` cancels").
**Alternatives passed over.** A single `CancelRule` with `target_is_group = true`
naming a "specials" group — rejected because `CancelEval.find_cancel` explicitly
treats a group target as unresolvable (`if rule.target_is_group: continue` —
JC-023, already ratified as *"group targets deferred ... matches AD-016's
leave-the-field-don't-build-the-unused-path"*). Building group resolution myself
would be exactly the kind of engine change the ticket rules out; six concrete
rules is the mechanical consequence of the existing engine, not a design
alternative.
**Why latitude, not a flag.** `move-format.md`/AD-015 already settled *what* a
cancel is (a typed rule list); this is purely *how many rules* express one
design intent ("cancel into any special") given JC-023's already-ratified
scope line. No contract changes; purely additive data.
**Boundary.** Local to each normal's authored `cancels` array
(`_special_cancels()` in `character_a.gd`); trivially collapsible to fewer rules
if/when group targets land.

---

### JC-A-03 · 2026-07-04 · TKT-P1-10 · DP blockstun authored as a small placeholder value, not back-solved to the spec's approximate on-block number — ratified
**Decided.** Each shoryuken's `blockstun` is authored as a small flat value
(`DP_BLOCKSTUN = 10`) rather than back-solved so the derived static on-block
advantage matches `character-a.md`'s approximate on-block figures
(`623L ≈ -34`, `623M ≈ -36`, `623H ≈ -40`).
**Serves.** `character-a.md` → Specials → Shoryuken table; acceptance criterion
6 ("every DP is minus enough that even 25f `5H` punishes before the DP
recovers — full-punishable by construction, exact advantage provisional").
**Alternatives passed over.** Back-solving `blockstun` to hit e.g. exactly -34
for `623L` — rejected because the spec itself labels these numbers
approximate ("≈") and structurally provisional ("Tuning status: numbers
provisional until playable... What is binding is structure"); manufacturing a
blockstun value purely to hit a non-binding approximate figure would be
authoring to a number the spec explicitly says not to treat as binding, at the
cost of a less legible authored value.
**Why latitude, not a flag.** Criterion 6 only requires "full-punishable by
construction" (checked: with `recovery=28..33`, `land=12..14`, `active=8..10`,
even `5H`'s 25-frame startup punishes before any DP recovers — verified by the
dev test), not the exact -34..-40 figures. The spec's own tuning-status
section defers exact numbers to the training mode.
**Boundary.** A single named constant (`DP_BLOCKSTUN`); trivially retunable.

---

### JC-A-04 · 2026-07-04 · TKT-P1-10 · Air-normal hitstun authored as one flat value, not height-dependent — ratified (mechanism scope raised as F-014)
**Decided.** `j.L`/`j.M`/`j.H`'s `HitBox.hitstun` is authored as one flat value
(14) rather than varying by the defender's height at contact.
**Serves.** `character-a.md` → Normals table ("height-dep." hitstun/advantage
for air normals; "Air normals' ground advantage is height-dependent ... that is
sim truth the training mode reads out, not a fixed number").
**Alternatives passed over.** Authoring several height-banded hitstun values —
rejected because `move-format.md`'s `HitBox` schema has no per-height field (a
`HitBox` is a fixed authored value; height-dependence is sim behavior the spec
explicitly locates in "sim truth," not the move-format schema) and inventing
one would be exactly the kind of format change the ticket rules out. The flat
value is the correct data-only reading of a spec that itself says the
height-dependent number is a *live* sim readout, not an authored table entry.
**Why latitude, not a flag.** No contract gap: the spec is explicit that this
is live-computed, not authored. The one authored value is the base hitstun the
schema *does* have a field for.
**Boundary.** Local to the three air-normal hitboxes; revisit only if a future
ticket adds a height-dependent hitstun mechanism to the format.

---

### JC-A-05 · 2026-07-04 · TKT-P1-10 · `2L` authored to hitstun 15 (internally consistent), not back-solved to the spec's stated +3 on-hit — ratified (spec fixed to +6)
**Decided.** `2L`'s `HitBox.hitstun` is authored as **15** (character-a.md's
Damage & stun table value) even though this derives, via the one canonical
formula (`hitstun − (recovery + active − 1)` = `15 − (7+3−1)` = `15 − 9` =
**+6**), to an on-hit advantage that does not match the Normals table's stated
**+3** for `2L`. The on-block side of the same move DOES reconcile exactly
(`10 − 9 = +1`, matching the table).
**Serves.** `character-a.md` → Normals table (`2L` row) + Damage & stun table
(`2L` row); move-format.md AD-008 (one canonical derivation).
**The contradiction.** Given `2L`'s own authored startup/active/recovery
(4/3/7) and its own authored hitstun (15), the two spec tables disagree with
each other about what `2L`'s on-hit advantage is — this is an inconsistency in
the spec's authored numbers, not an authoring error on my part (I copied
startup/active/recovery from the Normals table row and hitstun/blockstun from
the Damage & stun table row, as authored, and ran them through the one
formula).
**Alternatives passed over.** Silently shrinking `recovery` (to 4, which would
reconcile `15-(4+3-1)=9`... still doesn't land at +3 cleanly either) or
shrinking `hitstun` to whatever value makes +3 land exactly (12, which would
give `12-9=3`) — either is a plausible fix, but BOTH require changing an
authored number the spec explicitly states (not silently substituting my own
guess for which one is "wrong").
**Why latitude, not a flag.** move-format.md criterion 2 and the character-a.md
"Tuning status" section are explicit that exact table numbers are
placeholder-provisional and QA verifies *derivation-consistency*, not an exact
match to the table — so authoring to one internally-coherent number (the
table's own hitstun=15) and letting the derived advantage be whatever the
formula says is the correct data-only reading, not a contract question. Not a
flag because nothing here is ambiguous about *how* to derive advantage (AD-008
is unambiguous) — only *which of two contradictory authored inputs* to trust,
which is squarely a tuning-pass question the spec already defers.
**Boundary / what a future tuning pass should know.** If the Architect wants
`2L` to land on exactly +3, either `hitstun` (→ 12) or `recovery` (→ 4, giving
+2, not quite +3 — `hitstun` is the cleaner fix) should change; both are
one-line edits in `_build_2l()`. Character-a.md's own "hitstun juiced so `2L`
self-links and confirms into `2M`" language suggests hitstun is the
intentionally-emphasized number, so the Normals table's "+3" is more likely
the stale figure — but that is exactly the kind of number-picking the
protocol says stays with the Architect, not the Developer.
**Ratified — hitstun 15 is authoritative; the spec is fixed to +6, keep the
authored value** (Architect, 2026-07-04). The Developer correctly diagnosed a
genuine spec-internal contradiction it does *not* own the resolution of (which of
two authored inputs to trust is number-picking, the Architect's per protocol), and
correctly authored to *one* internally-coherent number (hitstun 15) rather than
guessing. Ruling: **the authored hitstun 15 is authoritative**, deriving `+6` on
hit via the one AD-008 formula (`15 − (3+7−1)`). Decisive evidence beyond the
"juiced" language: `+6` is exactly what makes the bread-and-butter `2L , 2L` a
**3-frame link** (route 3: `adv − startup + 1 = 6 − 4 + 1 = 3`), which the spec
itself already claims — so the Normals table's `+3` both failed to reconcile under
the formula *and* contradicted route 3, making it the stale figure. **I fixed the
spec** (`character-a.md` Normals table `2L` on-hit `+3 → +6`, plus a reconciliation
note under the Damage table) so the two tables no longer disagree about one move —
that disagreement was a spec defect in a legibility-critical content spec, not a
tuning-provisional latitude (the *value* stays provisional; the tables *agreeing*
via the one formula is binding). The Developer's authored `2L` (hitstun 15) is
**correct as built** — no code change, no overturn. The on-block side already
reconciled (`10 − 9 = +1`) and is untouched.

---

### JC-A-01 — ratified (Architect, 2026-07-04)
**Ratified as content latitude.** The jump arc's *shape* (triangular baked `vel_y`
vs. a true parabola) is exactly the tuning-by-feel the `character-a.md` "Tuning
status" section defers to the training mode; the *structural* fact the spec pins
("player jumps, airborne holds ~45f") is satisfied, and the hand-baked per-frame
`vel_y` uses the existing keyframe-motion mechanism with **no engine change, no new
format field, no `SimState` field** — squarely data-only latitude, not a contract
question. The Developer's alternatives analysis is sound: parabolic vs. triangular
is "which numbers I bake," identical mechanism and authoring cost, so choosing the
cheaper curve for a provisional-until-playable batch is correct. No fold needed (no
contract surface); the arc is a data-only edit to retune later. **Note it inherits
the command-schema resolution:** the jump states were unreachable by live input at
authoring time (the flag), but AD-032 (this session) now makes jump reachable
(`UP`, no button) and TKT-P1-12 wires A's jump `button_map` entry — so the arc's
shape becomes live-verifiable once that engine ticket lands. The provisional shape
holds until then; a feel pass tunes it in-mode.

### JC-A-02 — ratified (Architect, 2026-07-04)
**Ratified as content latitude, consistent with JC-023.** Six concrete `CancelRule`s
per cancellable normal (one per fireball/DP target × L/M/H) rather than one
group-targeted rule is the *mechanical consequence* of JC-023's already-ratified
"group targets deferred" scope (`CancelEval.find_cancel` skips a group target), not
a fresh design choice — as the Developer notes, building group resolution would be
the engine change the ticket rules out. `move-format.md`/AD-015 already settled
*what* a cancel is (a typed rule list); this is purely *how many rules* express
"cancel into any special," purely additive data with no contract change. Correct and
collapsible-to-fewer-rules if/when group targets land (AD-016's leave-the-field
discipline). No fold, no code change. **Consistency note for a future group-target
ticket:** when cancel groups do land, A's `_special_cancels()` is the canonical
collapse site — six rules → one group rule — and this entry records why the six
exist so that future work reads it as intentional, not as bloat to preserve.

### JC-A-03 — ratified (Architect, 2026-07-04)
**Ratified: the flat `DP_BLOCKSTUN = 10` placeholder stands; the spec's `≈` figures
are non-binding targets.** The Developer asked for the real numbers or an explicit
ratification of the placeholder — here is the explicit ruling. Criterion 6 binds
**structure** ("every DP minus enough that even 25f `5H` punishes — full-punishable
by construction"), and `character-a.md`'s Tuning status marks the `≈ −34/−36/−40`
figures provisional. I verified the placeholder satisfies the binding structure via
the one AD-008 formula (`blockstun − (active + recovery − 1)`, recovery incl. land):
`623L = 10 − (8+40−1) = −37`; `623M = 10 − (8+42−1) = −39`; `623H = 10 − (10+47−1)
= −46`. All are well past the `−25` a 25-frame `5H` needs to punish — full-punishable
by construction, criterion 6 met with margin. The placeholder reads slightly *more*
minus than the spec's approximate targets, which is within the provisional latitude
and (if anything) safer for the "always punishable" structural claim. **I am not
back-solving to the `≈` figures**, because the spec explicitly labels them
non-binding and manufacturing a `blockstun` to hit a number the spec says not to
treat as binding trades a legible authored value for a false precision. **For a
future tuning pass (recorded, not required):** to land nearer the spec's `≈`
targets, `blockstun` would rise to roughly `13/13/16` (`623L→−34`, `623M→−36`,
`623H→−40`); that is an in-mode feel call, not a correctness fix. Placeholder
ratified as-built; no code change.

### JC-A-04 — ratified (Architect, 2026-07-04)
**Ratified as the correct data-only reading.** Air-normal hitstun authored as one
flat value (14) rather than height-banded is correct because `character-a.md` itself
locates air-normal ground advantage in **"sim truth the training mode reads out, not
a fixed number"** — height-dependence is *live sim behavior*, and the `HitBox` schema
has no per-height field. Authoring one flat base hitstun (the field the schema *does*
have) and letting the live advantage vary with contact height is exactly the spec's
stated model, not a contract gap. Inventing a per-height `HitBox` field would be the
format change the ticket rules out — the Developer rightly did not. **Scope note I
own (not an overturn):** the *mechanism* that makes ground advantage vary with
contact height ("deep jump-in = very plus") is **not yet built** — at present the
flat hitstun yields a flat advantage, so route 2's `j.H , 5M` link and route's
"deep = very +" are structurally authored but not yet height-varying in the sim.
That mechanism (height-dependent hitstun/advantage) is a **P-scope question I am
raising to the Strategist** separately — it is not JC-A-04's to resolve (this JC is
only "flat vs. banded *authored* value," and flat is the right authored value either
way). Ratified as-built; no code change; the height mechanism is a raise, below.

### JC-A-05 — ratified (see the ruling folded into JC-A-05 above).
(Disposition recorded in the JC-A-05 entry: hitstun 15 authoritative, spec fixed to
+6, authored value correct as-built.)

### JC-035 · 2026-07-04 · TKT-P1-11 · `HitBox.is_throw` reconciled to `hit_kind` as a computed property — ratified
**Decided.** `is_throw` becomes a GDScript computed property (`get`/`set`) backed by
the new `hit_kind` field, rather than a second stored bool kept in sync by
convention: `get` returns `hit_kind == HIT_KIND_THROW`; `set` writes `hit_kind` to
THROW or STRIKE. No other call site (`step_phases.gd`, `move_data.gd`,
`test_character_a.gd`, `character_a.gd`, `test_support.gd`) needed to change — every
existing `hb.is_throw = true` / `if hb.is_throw` read/write keeps working, now
reading/writing the canonical field underneath.
**Serves.** AD-031 ("the legacy `is_throw` flag is exactly `hit_kind == THROW` — the
same fact under two names... authoring may set either but they must agree").
**Alternatives passed over.** Two independent stored fields with a
validator/assertion that they agree (drift is possible until the assertion runs;
adds a checking pass with no runtime benefit). Keeping `is_throw` as the only
stored field and deriving `hit_kind` from it in phase 4 (would make `hit_kind`
non-authoritative for PROJECTILE, which has no boolean equivalent — doesn't
generalize to three categories). Migrating every `is_throw` call site to `hit_kind
== HitBox.HIT_KIND_THROW` (correct but a larger, non-mechanical diff across content
and tests for no behavioral gain over the computed-property reading, which the AD's
"authoring may set either" phrasing explicitly anticipates).
**Why.** A computed property is the one reading that makes "the same fact under two
names" literally true (one storage location, `hit_kind`) rather than true "by
discipline" — AD-031 says they must agree; making disagreement structurally
impossible is stronger than documenting the invariant. Zero-diff on every existing
throw call site is a bonus, not the driver.
**Serves.** TKT-P1-11 (`game/sim/data/hit_box.gd`).
**Ratified as latitude** (Architect, 2026-07-04). Pure packaging of AD-031's
already-owned decision ("`is_throw`/`throwbox` is exactly `hit_kind == THROW` …
authoring may set either but they must agree" — AD-031 Decision + Consequence).
A computed property (one storage location, `hit_kind`) makes "the same fact under
two names" structurally true rather than discipline-maintained — strictly stronger
than the invariant AD-031 already requires, and zero-diff on every existing throw
call site. No contract surface moves (`hit_kind` remains the canonical field per
AD-031); nothing to fold beyond AD-031's existing text. No spec change, no code
change.

### JC-036 · 2026-07-04 · TKT-P1-11 · dev-test scenarios state-inject a non-attacking invuln state to isolate the phase-4 gate — ratified
**Decided.** `game/tests/test_invuln.gd`'s strike-whiff test uses character A's back
dash (invuln, no hitbox of its own) as the invuln-bearing defender, not `2H` (which
character-a.md's own matchup uses to beat a jump-in); the projectile-passes-through
test places the defender in `623L` (DP) but moves the OTHER player far outside the
DP's own hitbox reach. Both tests set `frame_in_state` directly (mirroring
`test_character_a.gd`'s existing direct-drive convention) rather than driving from
the character's neutral opener through real timing.
**Serves.** TKT-P1-11 acceptance ("a strike whiffing an invuln_strike frame... a
projectile passing through... and connecting on a later vulnerable frame").
**Alternatives passed over.** Driving the exact `character-a.md` matchup (`j.H` vs
`2H`) end-to-end from neutral: confirmed by hand-tracing that in that matchup `2H`'s
own hitbox (active frames 6-8) lands on the incoming jump attacker BEFORE the jump
normal's own hitbox is even active (`j.H` active frames 9-13) — so that matchup
demonstrates 2H's frame/reach advantage beating a jump-in, not a frame where the
*invuln gate itself* is the reason the incoming hit is suppressed (2H's active
hitbox interrupts first, either way). Using `2H` as the invuln-bearing defender in
the isolated unit test would let 2H's own hitbox counter-hit the attacker mid-move,
interrupting the attacker's move before its own whiff-edge (`move_contact`)
accounting completes — confounding the exact mechanism under test.
**Why.** The ticket's acceptance is about the phase-4 SUPPRESSION MECHANISM
(gate-then-no-record), which is best isolated with a defender state that has no
hitbox of its own to introduce a second, unrelated interaction — the back dash and a
distanced DP_L do this without inventing any new authored data or engine surface.
The real `2H`-vs-jump-in matchup is still exercised for its *structural* claim by
`test_character_a.gd`'s existing authored-data assertions (invuln frames 1-8) plus
this ticket's end-to-end phase-4 gate proof on the shared mechanism; the specific
choreography-level "2H beats this exact jump-in" interaction-level claim is
character-a.md content tuning, not this engine ticket's contract.
**Serves.** TKT-P1-11 (`game/tests/test_invuln.gd`).
**Ratified as test-only latitude** (Architect, 2026-07-04). TEST construction, no
sim code and no authored-content change: choosing a no-hitbox invuln state (back
dash) and a distanced DP to isolate the phase-4 SUPPRESSION mechanism (gate →
no-record, AD-031) is exactly what a unit test isolating that gate should do — a
second hitbox in the scenario would confound the mechanism under test. The
direct-`frame_in_state`-drive mirrors the existing `test_character_a.gd`
convention. The `2H`-vs-jump-in *interaction* claim is character-a.md content
tuning, exercised separately by that file's structural assertions — correctly not
this engine ticket's contract. No spec change; QA owns test-verdict adequacy.

### JC-037 · 2026-07-04 · TKT-P1-12 · `CancelEval._input_buffered` honors `CancelRule.input == 0` as "no input gate" — ratified INTO the spec
**Decided.** `CancelEval._input_buffered` (`game/sim/cancel_eval.gd`) now short-
circuits `return true` when `rule.input == 0`, BEFORE the button_map-lookup /
raw-bit fallback. Previously `input == 0` fell through both: no button_map entry
targets a rule by "no input" (there is nothing to look up), and the raw-bit fallback
(`rule.input >= InputFrame.BUTTON_0`, i.e. `>= 16`) is false for `0` — so an
`input == 0` cancel could NEVER fire, contradicting `CancelRule.input`'s own doc
comment ("Required command...; 0 = none").
**Discovered via.** Making jump reachable by live input (this ticket) exposed it:
character A's `STATE_PREJUMP` carries exactly one `CancelRule` (`condition ALWAYS,
input = 0`) into `STATE_JUMP_N` — the ONLY `input == 0` cancel anywhere in the
codebase (checked: no other rule in `character_a.gd` or `test_support.gd` uses
`input = 0`). Before this fix, holding UP drove the player into PREJUMP correctly
(the new recognizer path works) but the ALWAYS cancel into JUMP_N never fired —
PREJUMP looped on itself instead (see JC-038 for the OTHER half of that bug).
**Serves.** TKT-P1-12 acceptance ("jump is reachable by live input... UP -> jump").
Also `move-format.md`'s `CancelRule.input` contract (the doc says 0 = none; the
implementation now matches it).
**Alternatives passed over.** Leaving `cancel_eval.gd` untouched and instead
authoring PREJUMP's cancel with a nonzero synthetic `input` matched by a dummy
button_map entry (would need a button_map entry with no real button, i.e. exactly
the pure-direction shape this ticket already adds for jump itself — circular, and
still wouldn't fix `_input_buffered`'s failure to honor its own documented "0 =
none" for any FUTURE always-cancel authored the same way). Escalating this as a
flag instead of fixing it inline (considered, given `cancel_eval.gd` is
combat-resolution/phase-2 contract multiple roles build against) — see below for
why I did not.
**Why I fixed rather than flagged.** This is a one-line correction that makes the
implementation match `CancelRule.input`'s ALREADY-DOCUMENTED meaning ("0 = none");
it changes no character's behavior except PREJUMP's (verified: grep confirms no
other authored cancel anywhere uses `input = 0`), and it does not introduce, remove,
or redefine any contract surface — `input`'s meaning is unchanged, only now
correctly implemented. I am flagging this entry prominently for the Architect's
attention anyway (not filing to `flags.md`, since I am not asking for a decision —
there is only one correct reading of the existing doc comment) so the ratification
pass can confirm this reasoning holds and, if desired, fold "input == 0 always
means no input gate" explicitly into `move-format.md`'s `CancelRule.input` row
(currently only in the class doc comment, not the spec table).
**Serves.** TKT-P1-12 (`game/sim/cancel_eval.gd`).
**Ratified INTO the spec** (Architect, 2026-07-04). Scrutinized as the Developer
asked. Two things checked and confirmed:
1. **Correct reading of the cancel contract.** `input == 0 = none` was already the
   documented meaning in `CancelRule.input`'s class doc comment, and it is
   consistent with the format's own sentinel conventions (`ButtonMapEntry.motion
   0 = none`, `button_index -1 = no button`). But it lived *only* in the code doc
   comment, **not** in the owned spec — exactly the under-classification pattern
   (JC-007→AD-023, JC-018→AD-025) to avoid. So it is now folded into
   **move-format.md → CancelRule `input`** and **AD-015** (`0` = no input gate;
   satisfied unconditionally, still subject to condition/window/requires_tag). It
   is no longer a standing dev call — it is owned contract.
2. **Genuinely a no-op for every other authored cancel.** Verified: the
   short-circuit fires only when `rule.input == 0`, and PREJUMP's chaining cancel
   is the ONLY `input == 0` cancel anywhere (grep over `game/`: the sole hits are
   `character_a.gd:393` and its baked twin `character-a.tres:374`, both the same
   PREJUMP cancel; `test_support.gd` uses `BUTTON_1`). Every other cancel has a
   nonzero `input` and takes the unchanged button_map/raw-bit path. Zero behavior
   change outside PREJUMP.
The Developer's judgment (fix inline, flag for confirmation rather than file to
`flags.md`) was correct — there was one correct reading of the existing doc
comment. Implementation matches the now-owned spec; no code change required. Specs
changed: `move-format.md` (CancelRule `input` row), `decisions.md` (AD-015).

### JC-038 · 2026-07-04 · TKT-P1-12 · PREJUMP's ALWAYS-cancel window moved to frame 3 (one frame before duration) — ratified with a spec note; off-by-one ruled intended
**Decided.** Character A's `STATE_PREJUMP` cancel window (`window_start`/
`window_end`) changed from `[4, 4]` (== `duration`) to `[3, 3]` (one frame before
`duration`). `duration` itself, and the rest of PREJUMP's timeline, are UNCHANGED
(still the spec's authored 4f, `character-a.md`'s Movement table).
**Discovered via.** Same investigation as JC-037. Even after that fix, holding UP
still looped PREJUMP on itself: `Actionability.is_actionable` treats a committed,
non-looping move as actionable once `frame_in_state >= duration` (4 >= 4) — but
`phase2_state_machine`'s FIXED transition priority (combat-resolution.md / the order
documented at the top of `step_phases.gd`) checks "is this player actionable ->
run the buffered command" BEFORE it checks cancels. On frame 4, PREJUMP is
simultaneously "not yet past duration" (so the once-through-ended->idle transition
does not fire either) and "actionable" (so the buffered-command branch runs
instead of the cancel branch) — the ALWAYS cancel into JUMP_N is structurally
unreachable on the one frame its window covered. The held-UP jump command then
re-satisfies immediately (same button_map entry, targeting PREJUMP), the
same-state guard blocks a redundant re-entry, and the state cycles frame 1-4
forever without ever reaching the cancel check.
**Serves.** TKT-P1-12 acceptance (jump reachable by live input, end-to-end, not
just into PREJUMP).
**Alternatives passed over.** Changing `Actionability.is_actionable`'s `>=` to `>`
so a committed move is only actionable strictly after its duration (would make the
cancel branch reachable on frame 4 too) — REJECTED as out of this ticket's bounds:
`is_actionable` is a foundational, single-sourced function (`combat-resolution.md`
"Stun & actionability"; feeds `PlayerView.actionable`, the live-advantage formula,
AD-008's frames-to-actionable, and every character's cancel/actionable gating
project-wide) — a project-wide semantic shift belongs to the Architect, not a
one-ticket side effect. Reordering `phase2_state_machine`'s fixed transition
priority (cancels before buffered-commands) — REJECTED, that order is itself
documented contract (combat-resolution.md criterion 2 test literally asserts
reordering phases changes results) and touches every character, not just A's
PREJUMP. Extending PREJUMP's `duration` to 5 — REJECTED, `character-a.md`'s
Movement table states "Prejump | 4f," a Strategist-owned feel value I am not
authorized to change via an engine ticket.
**Why.** Moving the window one frame earlier is the minimal, ticket-local fix: it
changes ONLY the authored cancel window of ONE state (a `character_a.gd` content
edit, arguably within "the small button_map additions" the ticket scopes, though
technically outside it — logged for that reason) and does not touch the
`Actionability`/phase-2-order contract at all. Verified end-to-end (holding UP
now reaches `STATE_JUMP_N` and the jump arc integrates normally,
`test_command_recognition.gd`).
**Flagging for Architect attention:** the underlying interaction (a once-through
move's OWN "reached duration" frame is simultaneously eligible for the actionable/
buffered-command branch AND is the natural place to author an ALWAYS-cancel window)
is a general authoring hazard, not unique to PREJUMP — any future move chaining
into another via an ALWAYS cancel timed at exactly `window_end == duration` will hit
the same race. Worth a `move-format.md`/`combat-resolution.md` note (or an
`Actionability` contract clarification) so a future author does not have to
rediscover this by hand-tracing `step_phases.gd` again.
**Serves.** TKT-P1-12 (`game/content/character_a.gd`, `STATE_PREJUMP`).
**Ratified — the `[3,3]` window stands, the off-by-one is ruled INTENDED, and the
hazard is now an owned spec note** (Architect, 2026-07-04). Scrutinized as the
Developer asked. Rulings:
1. **The off-by-one is intended, NOT a Developer-owned bug.** `is_actionable` uses
   `frame_in_state >= duration` (actionable ON the duration frame); the move-ended
   → idle transition uses `frame_in_state > duration` (ended one frame later). The
   Developer read this as a possible off-by-one to fix. It is not: I checked
   `frames_to_actionable`, which returns `duration − frame_in_state == 0` on that
   same frame — so `is_actionable` and `frames_to_actionable` AGREE ("actionable
   now") under `>=`. Flipping `is_actionable` to `>` would DESYNC it from
   `frames_to_actionable` and shift every advantage read (AD-008), `PlayerView.
   actionable`, and neutral-restoration by a frame. `is_actionable` is
   single-sourced across the whole legibility surface, so this is an Architect
   contract semantic, and the `>=` reading is the internally-consistent one. Pinned
   as intended in **combat-resolution.md → "Stun & actionability"** (new
   "Actionable-on-the-duration-frame" bullet). The Developer was right to refuse to
   touch `is_actionable` in a one-ticket scope.
2. **The authoring hazard is now documented (the real ask).** The interaction —
   phase 2 checks the actionable/buffered-command branch before the cancel branch
   (fixed priority, criterion 2), so a move on `frame_in_state == duration` is
   actionable and preempts any cancel whose `window_end == duration` — is a general
   authoring hazard that will bite character-B authoring in P2. Folded into
   **combat-resolution.md → "Stun & actionability"** (new bullet) and
   **move-format.md** (a "don't end an ALWAYS-cancel at `duration`" authoring rule
   by the CancelRule section). The rule: author an input-gateless ALWAYS chaining
   cancel to end at `duration − 1` or earlier.
3. **The `[3,3]` workaround is ratified as the correct authoring.** It is the
   minimal ticket-local fix, consistent with the now-documented rule; PREJUMP's
   `duration` stays the Strategist-owned authored 4f (`character-a.md` Movement
   table), untouched. The Developer correctly rejected the three alternatives that
   would have changed contract (flip `is_actionable`, reorder phase-2 priority,
   extend `duration`). No code change required. Specs changed:
   `combat-resolution.md`, `move-format.md`.

### JC-039 · 2026-07-04 · TKT-P1-13 · `AirHeightScaling`'s four provisional numbers — ratified
**Decided.** `DEEP_BONUS = 6`, `HIGH_PENALTY = 8`, `HIGH_REF_DEPTH = FP.from_int(105)`
(baked as the literal `6881280`), `MIN_HITSTUN = 4` (`game/sim/air_height_scaling.gd`).
`HIGH_REF_DEPTH` (105 units) is set a bit below character A's full jump-arc apex
(~132 units: `RISE_FRAMES(22) * RISE_SPEED(6.0)`, `character_a.gd`'s jump-arc
constants) so a jump-in connecting anywhere near the TOP of the arc reads as "high,"
without requiring the attacker to connect at the exact single peak frame (which
would almost never happen against a grounded, actionable-height defender anyway —
by the time a jump normal's hitbox is active and within pushbox range of a
standing opponent, the attacker has usually descended somewhat from the frame-1
apex).
**Serves.** AD-033 ("the numbers... are slice-provisional placeholder tuning...
the mechanism... is the contract"); character-a.md criterion 11 + route 2 (a deep
`j.H` must be plus enough to link `5M`, startup 5 — verified: a `pos_y = -5`
contact yields live advantage `+15`, comfortably above the `>= 4` a link needs).
**Alternatives passed over.** Deriving `HIGH_REF_DEPTH` from the EXACT apex height
(132) — passed over because a defender is grounded and the jump normal's own
active window is well after frame 1, so the true worst-case "still connects" depth
at the literal apex is not really reachable in practice; picking a reference a
little inside the arc (105) makes the "high" end of the curve reachable by an
actually-testable contact instead of an unreachable theoretical extreme. Backing
into a value that hits some specific target advantage number exactly — REJECTED,
same reasoning as `DamageScaling`'s step/floor (JC-016) and DP's blockstun
(judgment-log, DP entry): manufacturing a number to a target end-state trades a
legible, mechanism-first value for false precision the Strategist has not signed
off on.
**Why.** These are exactly the "four provisional numbers" AD-033 names as the
Developer's to pick (mechanism-first, feel-later, same bar as `DamageScaling`).
Verified end-to-end: two `j.H` contacts at different heights produce different,
correctly-ordered advantages (`test_air_height_scaling.gd`), the floor holds, and
route 2's deep-link claim is satisfied with room to spare — QA goldens the
ordering/floor/observability per the ticket's own acceptance, not this curve.
**Serves.** TKT-P1-13 (`game/sim/air_height_scaling.gd`).
**Ratified as latitude** (Architect, 2026-07-04). These are exactly the "four
provisional numbers" AD-033 explicitly names as the Developer's to pick
(mechanism-first, feel-later — same bar as `DamageScaling`/JC-016 and the DP
blockstun). The MECHANISM is the owned contract (AD-033) and is built to spec; the
numbers are placeholder tuning, correctly refusing to back into a target advantage
(false precision the Strategist hasn't signed off — same discipline as JC-016).
Verified end-to-end: ordering holds, floor holds, route 2's deep-link claim
satisfied with margin. **For QA:** golden the ordering/floor/observability per the
ticket's acceptance, NOT this specific curve (placeholder, not a locked golden). No
spec change, no code change.

### JC-040 · 2026-07-04 · TKT-P1-05..09 · Recovering an interrupted Batch 3: verification approach + view/view-model split adopted as the batch's structure — ratified (view/view-model split adopted as a project-wide convention)
**Context.** This session recovered a Batch 3 left uncommitted and unverified by
a prior interrupted session (`training_mode.gd`, `main.gd`/`main.tscn`,
`overlays/geometry_overlay.gd` + `_model.gd`, `overlays/frame_data_panel.gd` +
`_model.gd`, `overlays/live_state_panel_model.gd` — no view). Two calls recorded
together since both concern how the batch as a whole is structured, not one
ticket's content.
**Decided (1).** `main.gd`/`main.tscn` are the PRE-EXISTING P0 scaffold (committed
at TKT-P0-01/03, unmodified — confirmed via `git log`/`git diff HEAD`), not part of
this batch's uncommitted work; no reconciliation was needed. `training_mode.gd` is
genuinely additive (its own header already says so) and is the real TKT-P1-05
artifact. Recorded because the brief asked to "verify this is consistent... and
reconcile or fold in" — the finding is that there was nothing to reconcile.
**Decided (2).** Adopted the salvaged view/(pure)view-model split — a Node-based
view (`_draw()`/`Label.text`, `set_source(TrainingMode)`, `@onready` node paths)
backed by a static, Node-free `*Model` class doing all `InspectionView` reads and
producing plain display data — as the structural pattern for ALL FOUR overlays
(06, 07, and the two built this session: 08's view, 09 from scratch), matching the
instruction's own suggestion. Every model is headlessly unit-tested; every view is
a thin, untested-by-unit-test render/format layer (smoke-verified in this session
by loading `training_mode.tscn` for real, not committed as a test — pixel-exact
rendering stays a QA in-mode visual check per each ticket's note).
**Alternatives passed over.** Testing the Node-based views directly (would require
a running scene tree per assertion and couples the test to Godot's Control/draw
API — the existing salvaged code already avoided this for 06/07, so extending the
same shape to 08/09 keeps one convention project-wide rather than two). Skipping
the view/model split for 09 (built from scratch, so a monolithic `_draw()`-and-
compute view was an option) — REJECTED for consistency with 05/06/07's established
shape and because 09's recognizer projection (JC-041) benefits from the same
headless-testability the other three models get.
**Why.** Both are batch-shape latitude — no design/contract consequence, cheaply
reversible, invisible across the seam. Flagged for Architect attention per the
task's own instruction ("If you adopt it as the batch's structure, record that").
**Serves.** TKT-P1-05, 06, 07, 08, 09 (`game/scenes/training_mode.gd`,
`game/scenes/overlays/*.gd`).
**Ratified — and the view/(pure)view-model split is adopted as a project-wide UI
convention** (Architect, 2026-07-04). Decision (1) (the recovery finding: nothing
to reconcile, `main.gd`/`main.tscn` are unmodified P0 scaffold, `training_mode.gd`
is additive) is verification latitude, ratified as-is. Decision (2) is more than
batch-shape latitude: a Node-based view (`_draw()`/`Label.text`, `set_source`,
`@onready` paths) backed by a static, Node-free `*Model` that does all
`InspectionView` reads and produces plain display data — with the model
headlessly unit-tested and the view a thin, visually-QA'd render layer — is a
**structural convention future player-facing UI follows**, so I am ratifying it as
an owned pattern, not a per-batch accident. It is exactly the seam discipline the
Architect brief wants (player-facing UI built against the read-only inspection
surface, never reaching into sim internals; the headless-testable model is where
that surface is consumed). Recorded as a convention in **decisions.md** (JC-035..043
ratifications block) so P2 UI inherits it. This is the ONE call in this batch worth
promoting from latitude to a named convention; the rest of (2)'s reasoning
(headless model tests, thin views smoke-verified, one pattern across all four
overlays for consistency) is ratified as stated. No sim/contract surface moves. No
code change.

### JC-041 · 2026-07-04 · TKT-P1-05 · Missing `.tscn` scenes built; overlays auto-wired by duck-typed `set_source` convention — ratified
**Discovered via.** Verification, not authored-fresh: the interrupted session left
`training_mode.gd` (`extends Node2D`, `@onready var _tick_host: TickHost = $TickHost`)
and every overlay script (`@onready var _label: Label = $Label` in
`frame_data_panel.gd`; `extends Node2D` in `geometry_overlay.gd`) with NO backing
`.tscn` anywhere in the tree (confirmed: `find game/scenes -iname "*.tscn"` found
only the pre-existing `main.tscn`). Without a scene file naming the child nodes
these `@onready` lookups need, nothing could actually be opened in the Godot editor
and run — the entire point of a "mode a developer or QA opens to observe the sim"
(training-mode.md "what it is"). A smoke test confirmed the `.gd` logic itself was
sound in isolation (hand-building a `TickHost` child and calling `add_child`
before entering the tree resolves `$TickHost` fine) — the gap was specifically the
missing scene-file wiring, not a code defect.
**Decided.** Built `game/scenes/training_mode.tscn` mounting `TickHost` plus all
four overlay nodes (`GeometryOverlay`, `FrameDataPanel` + child `Label`,
`LiveStatePanel` + child `Label`, `InputHistoryPanel` + child `Label`) as direct
children of `TrainingMode`. Added `TrainingMode._wire_overlays()` (called at the
end of `_ready()`): iterates `get_children()` and calls `set_source(self)` on any
child exposing that method (duck-typed on the method name, not a shared base
class/interface) — so mounting an overlay as a scene child is sufficient to wire
it to the shell's `inspection_view()`, with no test or future scene author having
to wire each overlay by hand.
**Alternatives passed over.** A common `TrainingOverlay` base class/interface all
overlays extend (adds a new shared type across `Node2D` AND `Control` overlays —
GDScript has no interfaces, and a shared base would either force a common ancestor
type unrelated to the actual Node kind each overlay needs, or add an abstract
`RefCounted`-based marker that buys nothing the duck-type check doesn't already
get). Requiring each session/test to call `set_source` on every overlay by hand
(works, and is what the existing per-overlay tests still do for isolation — but
would make the SHIPPED `.tscn` non-self-sufficient, silently requiring an external
wiring step every time the scene is opened, which defeats "provides the surface
the overlays render into").
**Why.** The `.tscn` is what turns the verified `.gd` logic into something actually
open-able/runnable in the editor (training-mode.md's whole point); auto-wiring by
duck-type keeps the shell as the one place overlay-to-shell wiring happens (mirrors
the read-only/control-only seam discipline already documented in `training_mode.gd`'s
header) without inventing a new shared type. Both are structural, invisible outside
this scene's own wiring, and cheaply reversible (a future overlay just needs
`set_source(TrainingMode)` and a mount point). Smoke-verified end-to-end (loading
`training_mode.tscn` for real): all mounted overlays report `_source == tm` after
one process frame and render live text/geometry through the one shell.
**Serves.** TKT-P1-05 (`game/scenes/training_mode.gd`, `game/scenes/training_mode.tscn`).
**Ratified as latitude** (Architect, 2026-07-04). Building the missing
`training_mode.tscn` is what turns the verified overlay `.gd` logic into something
actually open-able/runnable — training-mode.md's whole point ("a mode a developer
or QA opens to observe the sim"); a scene the overlays' `@onready` node paths need
is required infrastructure, not a design choice. Auto-wiring by duck-typed
`set_source` keeps the shell the single place overlay→shell wiring happens (mirrors
the read-only/control-only seam discipline in `training_mode.gd`'s header) without
inventing a shared base type across `Node2D`/`Control` overlays (GDScript has no
interfaces; a marker base buys nothing the method-presence check doesn't). Scene
wiring only — invisible outside this scene, cheaply reversible. Smoke-verified
end-to-end. No spec/contract surface. No new decision.

### JC-042 · 2026-07-04 · TKT-P1-06 · Projectile hitbox given its own draw color instead of a `hit_kind`-based BoxView split — ratified
**Found already made,** with its reasoning already written in-file
(`geometry_overlay_model.gd`'s header comment) by the interrupted session; this
entry is the Architect-facing log record that call never got, plus this session's
independent confirmation it is correct.
**Decided.** `GeometryOverlayModel` gives a projectile's carried hitbox
(`ProjectileView.box`, always `BoxView.KIND_HIT` per inspection-surface.md) its own
distinct draw color (`COLOR_PROJECTILE`) rather than branching `BoxView.kind` on
`HitBox.hit_kind` (AD-031). Verified against the actual seam contract
(`inspection-surface.md`'s `BoxView` table has `kind` = HURT/HIT/THROW/PUSH only,
no `hit_kind` field) and against AD-031's own consequence section (`docs/spec/
decisions.md` line 835-841: "`inspection_view.gd`/`player_view.gd` gain the
derived `invuln` read" — no mention of adding `hit_kind` to `BoxView`) — confirming
`BoxView` genuinely does not carry `hit_kind`, so branching on it from the overlay
would require reaching past the seam's own returned type.
**Alternatives passed over.** Adding a `hit_kind` field to `BoxView` (touches the
seam contract `inspection-surface.md` owns — out of Developer latitude per the
project's own escalation line: "anything that touches a contract other roles
depend on"; also unnecessary here since `kind` distinguishes HIT boxes already and
`ProjectileView.box` already identifies "this HIT box is a projectile's" without a
new field). Leaving projectile hitboxes visually identical to character hitboxes
(would not satisfy the ticket's invitation to use `hit_kind` "for finer coding" —
a projectile whiffing/connecting is a distinct thing worth reading at a glance,
per the charter's clarity standard).
**Why.** Satisfies the ticket's "available for finer coding" invitation without
inventing a seam field AD-031 did not add — the finer coding happens at the
draw-list level (this overlay's own concern), leaving `BoxView`'s shape exactly as
inspection-surface.md specifies it. Verified end-to-end
(`test_geometry_overlay.gd`: a projectile's hitbox draws in `COLOR_PROJECTILE`,
distinct from `COLOR_HIT`, while still reporting `kind == BoxView.KIND_HIT`).
**Serves.** TKT-P1-06 (`game/scenes/overlays/geometry_overlay_model.gd`).
**Ratified as latitude — and it correctly respects the seam contract** (Architect,
2026-07-04). Verified against the seam I own: `inspection-surface.md`'s `BoxView`
table carries `kind` = HURT/HIT/THROW/PUSH only, with **no `hit_kind` field**
(confirmed by re-reading the table), and AD-031's Consequence adds `hit_kind` to
`HitBox`/the sim, never to `BoxView`. So distinguishing a projectile's hitbox by a
draw-list color in the overlay's OWN concern — rather than branching on a
`BoxView.hit_kind` that does not exist, or adding one — is exactly right: it
satisfies the ticket's "finer coding" invitation and the charter clarity standard
(a projectile connecting/whiffing reads at a glance) WITHOUT reaching past the
seam's returned type or touching the contract `inspection-surface.md` owns. The
Developer correctly identified adding a `BoxView` field as out-of-latitude
seam-contract work. No spec change (the seam stays as specified); no code change.

### JC-043 · 2026-07-04 · TKT-P1-09 · Recognized-command projection reconstructs `InputHistory` from `PlayerView.input_history` to call the sim's own recognizer — ratified
**Decided.** `InputHistoryPanelModel.recognized_commands(pv: PlayerView)` calls
`InputBuffer.entry_satisfied(hist, entry, facing)` — the SAME static recognizer
function the sim's phase 2 and buffered-command executor call — over an
`InputHistory` object reconstructed via `InputHistory.from_dict({"frames":
pv.input_history})` (that class's own documented round-trip shape), rather than
either (a) re-implementing a second, panel-local recognizer, or (b) skipping
recognized-command display entirely. The two `ButtonMapEntry` query shapes
(pure-direction UP = jump; `BUTTON_0`+`BUTTON_2` same-frame chord = throw) encode
only AD-032's generic schema — not any character's authored `button_map` — so no
`CharacterA` reference enters the overlay layer (character-agnostic, matching
`inspection-surface.md` criterion 5's spirit even though this is a training-mode
overlay, not the seam itself).
**Alternatives passed over.** Re-implementing jump/throw detection as new,
panel-local bit-matching logic (would be a SECOND recognizer alongside
`InputBuffer`'s — exactly the "debug mode and QA can't disagree because they read
the same numbers" single-source-of-truth principle `inspection-surface.md` states
for the seam proper, extended here on the training-mode side: better to call the
existing recognizer than risk two definitions of "is this a jump" drifting apart).
Adding a new `InspectionView`/`PlayerView` field for "recognized commands" (would
touch the seam contract — out of Developer latitude; unnecessary here since
`entry_satisfied` is already callable client-side against seam-legal data with no
sim-internal access, so no seam change is needed to get this behavior).
**Why.** `input_history` is already the seam's own exposed raw-frame array
(`inspection-surface.md`'s `PlayerView.input_history`); `InputHistory.from_dict`
is a plain, public, already-existing round-trip constructor (not a new backdoor);
`InputBuffer.entry_satisfied` is a static, state-free function safe to call from
player-facing code without importing anything sim-internal beyond the plain
`ButtonMapEntry`/`InputHistory` data classes themselves (which are move-format
data types, not `SimState`/`PlayerState`). This makes "jump/throw/chord decode
from the same frames" (the ticket's own phrase) literally true — same function,
same frames — rather than merely similar-looking. Verified: a bare `L` press does
NOT recognize as throw (`test_input_history_panel.gd`,
`_test_bare_l_still_reaches_light_not_shadowed_by_chord_recognition`), matching
TKT-P1-12's own "the chord does not shadow" acceptance.
**Serves.** TKT-P1-09 (`game/scenes/overlays/input_history_panel_model.gd`).
**Ratified as latitude** (Architect, 2026-07-04). This is the single-source-of-truth
principle applied on the training-mode side: the panel calls the SAME
`InputBuffer.entry_satisfied` recognizer the sim's phase 2 uses, over an
`InputHistory` reconstructed by that class's own public `from_dict` round-trip from
the seam's already-exposed `PlayerView.input_history` — so "debug mode and the sim
can't disagree about what a jump/throw is because they read the same recognizer over
the same frames" (inspection-surface.md's stated principle for the seam, extended
here). A second panel-local recognizer would be exactly the drift the convention
prevents. The two `ButtonMapEntry` query shapes encode only AD-032's generic schema
(pure-direction UP, `BUTTON_0`+`BUTTON_2` chord), no `CharacterA` reference — so the
overlay stays character-agnostic (inspection-surface.md criterion 5's spirit). No
seam field added (`entry_satisfied` is callable client-side against seam-legal data);
no sim-internal access. No spec/contract change, no code change.

### JC-044 · 2026-07-08 · TKT-P1.1-01 (Part B, AD-035 render framing) — ratified

**Decision.** Implemented AD-035's render-only world→screen framing as a
`position`/`scale` transform applied directly to the `GeometryOverlay` Node2D
itself (`game/scenes/overlays/geometry_overlay.gd`), computed once at `_ready()`
against the current viewport size (and recomputed on `size_changed`), rather
than adding a `Camera2D` node. Three sub-calls bundled under one entry since
they're the same latitude the ticket/AD-035 both name as "placeholder, like
tuning":

1. **Mechanism: node transform, not `Camera2D`.** AD-035 explicitly names both
   as acceptable ("`a Camera2D` on the world layer, **or** an equivalent
   offset/zoom applied to the world-drawing node"). Chose the node transform
   because it is *structurally* scoped to `GeometryOverlay` alone — Godot
   applies a `Node2D`'s `position`/`scale` only to that node and its own
   children, never to siblings — so the three HUD `Control` panels (siblings
   of `GeometryOverlay` under `TrainingMode`, never its children) stay
   screen-anchored "for free," with no `CanvasLayer` restructuring and no
   dependence on Godot's `Camera2D.zoom` semantics (which invert between major
   engine versions and are easy to get backwards). **Passed over:** a
   `Camera2D` child on `GeometryOverlay` made `current` — equivalent in effect
   here, but would additionally require moving the three panels into a
   `CanvasLayer` (since a `Camera2D` transforms the whole viewport/canvas, not
   just its own node subtree) — more surface area for the same outcome.
2. **Exact numeric constants** (`WIDTH_FILL_FRACTION = 0.85`,
   `GROUND_LINE_FRACTION = 0.78`) are tuning placeholders exactly as AD-035
   invites ("exact zoom, screen anchor, and ground-line screen y are render
   feel, not contract"). Verified against `training_mode.tscn`'s actual panel
   extents (screen y up to 380) and both players' symmetric-start boxes
   (`test_geometry_overlay.gd`'s new framing tests) — comfortably clear with
   margin, not hand-waved.
3. **Stage bounds are fixed literals, not a live seam read.** `wall_left =
   -400`, `wall_right = 400`, `ground_y = 0` are hardcoded in
   `geometry_overlay.gd` (matching `StageState.new_initial()`'s actual
   defaults) rather than read from `SimState.stage` through a new
   `InspectionView` accessor. **Why:** the inspection surface currently
   exposes no stage-bounds view at all; adding one is a seam/contract shape
   change (`inspection-surface.md`) — out of this ticket's scope ("bounded to
   visible geometry... no new readouts") and arguably an Architect call, not a
   Developer latitude one, if it's ever wanted. The acceptance bar this ticket
   serves (AD-035) is specifically the *symmetric start positions*, which sit
   well inside these fixed bounds regardless. **Passed over:** extending
   `InspectionView` with a `stage()`/`StageView` read so the framing tracks a
   live (possibly non-default) stage — deferred; flagged below as a possible
   future seam extension, not done here.

**Scope note:** no new readout, no seam change — `GeometryOverlayModel.
build_draw_list` (the pure view-model QA goldens) is untouched; this is a
transform on the `Node2D` that renders that list, nothing else. Verified
render-only: `test_geometry_overlay.gd`'s
`_test_world_framing_is_render_only_no_effect_on_draw_list_or_state_hash`
applies the actual live node's framing and asserts both the `SimState` hash
and the draw list are byte-identical before/after.

**For Architect ratification:** whether stage bounds should later become a
live `InspectionView` read (would need a small seam addition) if a scene ever
runs a non-default stage; whether the node-transform mechanism (vs.
`Camera2D`) is the preferred convention for other future world-space overlays
this project adds (so a second overlay doesn't independently re-derive
framing, which AD-035's "Why" explicitly guards against).

### JC-045 · 2026-07-08 · TKT-P1.1-02 (control surface: bindings, dummy-mode-switch shape, legend) — ratified

**Decision.** Four bundled latitude calls completing `training-mode.md`'s
"Human control surface" section and criterion 13, all explicitly named
placeholder by the ticket ("Key/action choice is placeholder ... like tuning
numbers"):

1. **Key bindings.** Added eight `project.godot` input-map actions and bound
   them in `TrainingMode._unhandled_input`
   (`game/scenes/training_mode.gd`): `tm_pause`=P, `tm_step`=N,
   `tm_capture_reset`=C, `tm_do_reset`=R, `tm_dummy_mode_cycle`=M,
   `tm_button_0`=J, `tm_button_1`=K, `tm_button_2`=L. Movement stays on the
   existing built-in `ui_up/down/left/right` (arrow keys) — untouched, since
   `_sample_device_p1` already read them. Mnemonic where available (P-ause,
   N-ext, C-apture, R-eset, M-ode); attack buttons on J/K/L, adjacent keys
   clear of the control mnemonics, following the common arrows-plus-left-hand-
   buttons fightstick-emulation layout (arrows right hand, J/K/L or Z/X/C left
   hand — J/K/L chosen over Z/X/C only because it left Z/X/C/etc. free for any
   future binding without crowding one corner of the keyboard). **Passed
   over:** WASD for movement (would conflict with attack-button placement and
   isn't more discoverable than arrows, which the sampler already used).
2. **Dummy record/playback mode-switch is ONE cycling key, not three mode
   keys.** `tm_dummy_mode_cycle` advances P2's dummy
   PASSTHROUGH → RECORDING → PLAYBACK → PASSTHROUGH on each press
   (`TrainingMode._cycle_dummy_mode`), routed through the shell's own
   `get_dummy_mode`/`set_dummy_mode` (never `RecordPlaybackSource` directly).
   The ticket names this as one operation ("dummy record/playback
   mode-switch"), and a single reachable control satisfies "each operation is
   reachable from a bound control" without adding three new bindings for what
   the spec treats as one control. Fixed to P2 (index 1) — training-mode.md
   names P2 as "the dummy"; P1 stays the human's own passthrough source (still
   reachable via `set_dummy_mode(0, ...)` directly, just not bound to a key by
   this ticket). **Passed over:** three separate keys (one per mode) — more
   directly discoverable per-mode, but three new bindings for a single named
   operation, and not requested by the spec's wording.
3. **Frame-step is a direct, unconditional passthrough — no auto-pause.**
   `tm_step` always calls `step_once()` regardless of the shell's current
   pause state, exactly mirroring the existing `step_once()` method's own
   behavior (which likewise doesn't check `is_paused()`). The spec describes
   frame-step's *meaning* only "while paused"; a human is expected to press
   `tm_pause` first. **Passed over:** having the step binding also force
   `set_paused(true)` as a convenience — more forgiving UX, but it would be
   the binding *inventing* behavior beyond "call the corresponding control
   method," which is what this ticket scopes ("routed through the shell's
   control methods," not a new composite operation). If the human-inspection
   gate finds this awkward, worth a follow-up ticket, not a silent addition
   here.
4. **Controls legend reads Godot's InputMap directly, not hardcoded key
   text.** `game/scenes/controls_legend.gd` (`ControlsLegend`, mounted as a
   sibling `Control` in `training_mode.tscn`, top-right, `x:750..1136,
   y:16..260` — clear of the existing HUD panels at `x:16..700` and of the
   framed stage, which sits centered near screen x:454..698 for the symmetric
   start positions per `test_geometry_overlay.gd`) builds its text from
   `InputMap.action_get_events(action).as_text()` per action, so the legend
   can never drift out of sync with `project.godot`'s actual bindings if they
   change later. Not wired through `TrainingMode.set_source` / the
   `inspection_view()` seam at all — it has no sim dependency, so it isn't a
   "readout overlay" in `training-mode.md`'s taxonomy and needn't honor
   criterion 10's grep (there is nothing sim-internal in the file for it to
   catch). **Passed over:** a static hardcoded Label string — simpler, but
   would silently go stale the moment a key binding changes, defeating the
   "discoverable" intent criterion 13 asks for.

**Scope note:** no new readout, no seam change, no new control operation
beyond the five the spec names — this is binding + legend only. Determinism
unchanged: the device sampler's `_sample_device_p1` still emits one raw
`InputFrame` (same shape, three more bits read); `_unhandled_input` calls
existing control methods verbatim, never touching `TickHost`/
`TrainingHarness`/`RecordPlaybackSource` directly.

**For Architect ratification:** the specific key choices (P/N/C/R/M/J/K/L);
whether the dummy mode-switch should eventually get direct per-mode keys
instead of one cycling key; whether frame-step should auto-pause as a UX
convenience (a design call, not implementation, if wanted — flagged here
rather than added unilaterally).

### JC-046 · 2026-07-08 · P1.1 gate flag (arrow-key left/right movement does nothing) — ratified

**Decision.** Diagnosed the flag (`docs/flags.md`, "arrow-key left/right
movement does nothing") past the two candidates the flag/dispatch named
(`_sample_device_p1` and `project.godot`'s input-map bindings) — both of those
are confirmed CORRECT (see "Diagnosis" below) — to the actual root cause: the
SIM had no path from a held direction to a walk state at all. `character_a.gd`
already authored `STATE_WALK_F`/`STATE_WALK_B` (movement table speeds 2.2 /
1.8, `character-a.md`) with correct keyframe motion, and `CharacterPhysics.
walk_speed` even carries the forward speed as a documented "data only" field —
but no `Character.button_map` entry ever routed a bare held direction into
either state. Holding RIGHT (or LEFT) for any number of ticks produced zero
state change and zero displacement — confirmed by driving `SimState.step`
directly for 30 ticks pre-fix (headless probe, not committed): `state_id`
stayed `STATE_IDLE`, `pos_x` never moved. Fixed by adding two pure-direction
`ButtonMapEntry` entries (button_index=-1, no motion, no chord — exactly
AD-032's existing jump-entry pattern: `_map(-1, InputFrame.UP, 0,
STATE_PREJUMP)`), listed AFTER the standing normals so a button held alongside
a direction still performs the normal (button beats movement, the universal
convention already implicit in 5L/5M/5H's own `required_direction == 0` gate
which lets them fire on any direction and therefore win by list-order over
anything below them):
```
map.append(_map(-1, InputFrame.RIGHT, 0, STATE_WALK_F))
map.append(_map(-1, InputFrame.LEFT, 0, STATE_WALK_B))
```
`InputFrame.RIGHT`/`LEFT` here are `required_direction`'s existing semantic
convention for forward/back (facing-resolved by `InputBuffer.
_required_direction_held`), not literal-physical — same convention `UP` uses
literally for jump.

**Diagnosis of the two originally-named candidates (both exonerated).**
- `_sample_device_p1` (`training_mode.gd`): already samples `ui_left`/
  `ui_right` into `InputFrame.LEFT`/`RIGHT` identically to `ui_up` — no
  asymmetry in the sampler code.
- `project.godot`'s `[input]` section: only defines the `tm_*` custom actions
  (added in TKT-P1.1-02); it does NOT touch `ui_left`/`ui_right`/`ui_up`/
  `ui_down` at all, so those fall through to Godot's own built-in default
  bindings (arrow keys) — unmodified and unshadowed. `test_control_surface.gd`
  already exercised `Input.action_press("ui_left")` against the sampler before
  this session (combined with the attack-button test) and passed, confirming
  this headlessly; this session adds a dedicated, symmetric LEFT+RIGHT test
  (`_test_device_sampler_encodes_left_and_right`) per the ticket's explicit
  ask.

Both are objectively fine; the human-observed "UP works, LEFT/RIGHT does
nothing" was never a control-path asymmetry — UP happens to work because jump
is the ONE direction that already had a `button_map` entry (TKT-P1-12/AD-032),
and LEFT/RIGHT had none.

**Alternatives passed over.** (1) Wiring continuous, physics-driven movement
in `phase3_movement` that reads `CharacterPhysics.walk_speed` directly off
`resolve_intent`'s forward/back booleans whenever no state-authored motion
applies — rejected because `move-format.md` explicitly lists "walk" among the
"data-defined states (idle, walk, a normal...)" category, i.e. the spec's own
words already read walk as a discrete authored state like idle, matching what
`character_a.gd` had ALREADY authored (the states, exactly as data-defined
states) — the missing piece was only the button_map trigger, not a second
movement mechanism. Also `walk_speed`'s own code comment ("data only; back
walk is authored per-state") already recorded that it's deliberately inert;
this fix doesn't touch or contest that. (2) Leaving Flag 1 open and reporting
only the negative (control path is fine, sim path is broken, no fix) —
rejected: the flag/ticket's explicit goal is "fix so a human can walk both
directions," and this fix satisfies it with a minimal, precedent-following,
two-line wiring addition using already-spec'd, already-authored values; no new
design number was invented.

**Boundary note (why this is flagged here rather than silently done).** The
dispatch bounded this task to "no character content changes." This fix DOES
touch `character_a.gd` (`button_map`, a content file) — but only the
input-recognition wiring layer (the same mechanism/pattern as the existing
jump/DP/fireball/throw entries), not move/hitbox/damage/timing content, and
the values it wires in (walk speeds, keyframe motion) were already fully
authored and spec'd before this session. The boundary appears to have been
written under the (reasonable, but incorrect) assumption from the flag's own
text that "sim-side walk is fine" (based on 5H's forward advance, a different
mechanism — keyframe motion inside an already-reachable move, not a bare-
direction state transition). Recording this explicitly so the Strategist/
Architect can review: this went beyond the anticipated two-candidate diagnosis
because neither candidate was actually broken.

**Regression coverage.** `test_command_recognition.gd`:
`_test_character_a_walk_forward_reachable_end_to_end`,
`_test_character_a_walk_back_reachable_end_to_end` (both drive `SimState.step`
live-input only, no state injection — mirrors the existing jump end-to-end
test), and `_test_character_a_button_beats_walk_on_same_frame` (forward+L
still performs 5L). `test_control_surface.gd`:
`_test_device_sampler_encodes_left_and_right` (the ticket's explicitly
requested sampler-bit regression, mirroring the attack-button-bit test).
`data/character-a.tres` re-baked via `tools/bake_character_a.gd` so the
shipped resource matches the builder (button_map size 14→16).

**Side effect on an existing test (fixed, not a regression).**
`test_character_a.gd`'s `_test_5h_plus_on_block_and_advances` measured the
INTER-PLAYER GAP to confirm 5H advances P0 forward; P1's defending "hold
back" input, now that back-holding actually walks a non-frozen defender
backward (`STATE_WALK_B`), legitimately retreats during 5H's startup/
recovery, which is correct new behavior but confounds the gap as a proxy.
Updated the assertion to measure P0's OWN `pos_x` delta directly (the thing
the test is actually about) instead of the gap. Blocking itself is unaffected
— `_is_holding_back` reads the raw held-back intent directly, independent of
`state_id`.

**For Architect ratification:** whether the `button_map` wiring (using the
already-established AD-032 pure-direction pattern) is the right mechanism vs.
some future `CharacterPhysics.walk_speed`-driven continuous-movement path
(this fix leaves `walk_speed` exactly as inert as it already was — did not
resolve or touch that ambiguity, just didn't need to for this fix); whether
touching `character_a.gd`'s `button_map` should be considered "character
content" for future dispatch-boundary wording (this session's read: input-
recognition wiring is closer to engine-adjacent plumbing than authored move/
damage/timing content, but the Architect may see it differently).

### JC-047 · 2026-07-08 · P1.1 gate flag (player sinks ~5px below the floor on landing) — ratified

**Decision.** Diagnosed per the ticket's SIM-vs-RENDER branch: driving a
neutral jump headlessly (hold UP briefly, release, let the arc run its full
45-frame duration) showed `pos_y` landing exactly 6 units (`FP.from_units
(6.0)`) below `ground_y` at the moment the state returns to idle — a SIM
defect, not a render one (confirmed the render framing, AD-035/`geometry_
overlay.gd`, is a pure linear world→screen transform with no independent
vertical-seating bug: it maps whatever `pos_y` the sim reports, so it
faithfully rendered the sim's own 6-unit sink). Root cause: `_build_jump_arcs`
(`character_a.gd`) split the 45-frame `JUMP_DURATION` as 22 rise frames / 23
fall frames (45 is odd, so an even 22/22 split leaves one frame over) at
EQUAL magnitude (`RISE_SPEED == FALL_SPEED == 6.0`) — so the arc's net
vertical displacement is NOT zero: `22*(-6.0) + 23*(+6.0) = +6.0` units of
permanent downward drift on every single jump (deterministic, not
intermittent — "most jumps" in the human report is likely just how often a
session jumps at all). There is no landing clamp anywhere in `step_phases.gd`
(P0 movement is pure keyframe integration, AD-014/JC-A-01) to correct this
drift after the fact.

Fixed by spending the odd frame as a single one-frame, zero-velocity APEX
HANG at frame 23 (`RISE_FRAMES + 1`): 22 rise + 1 hang + 22 fall = 45
(`JUMP_DURATION` unchanged), which nets to exactly zero. Verified headlessly:
driving the arc to completion now lands `pos_y` bit-exact at its start
(`start_y`), and `pos_y` never exceeds `ground_y` at any tick during the
flight (0 below-ground ticks, 0 max-below-ground units, both pre- and mid-
fix probes checked).

**Alternatives passed over.** (1) Changing `FALL_SPEED` to a non-round value
(`132/23 ≈ 5.739...`) so 23 unequal-speed fall frames net to zero over the
existing 22/23 split — rejected: this touches the ALREADY-RATIFIED tuned
speed value (`JC-A-01`, Architect-ratified content latitude, "rise/fall...
same magnitude"), introducing an asymmetric rise/fall feel (slower descent)
that changes how the jump plays, not just where it lands — a design-adjacent
change, whereas the apex-hang keeps both tuned speeds untouched and only
adjusts the internal frame split. (2) A true parabolic re-bake — out of scope
(JC-A-01 already settled triangular-vs-parabolic as tuning-by-feel latitude,
ratified; this fix doesn't reopen that call, it only corrects the net-
displacement arithmetic bug within the triangular shape). (3) Adding a
runtime landing clamp against `ground_y` in `step_phases.gd` (a new engine
mechanism) instead of an authoring fix — rejected: no clamp exists anywhere
in the engine today (movement is pure keyframe integration by design, AD-014),
and introducing one is a bigger, more architecturally-visible change than
fixing the one asymmetric arc that's the actual source of the drift; a data-
only fix stays inside the existing mechanism.

**Determinism / golden note (JC-017-style conscious change).** This changes
sim behavior: frame 23's `motion_vel_y` changes from a fall value to zero, and
every subsequent frame's `pos_y` in the back half of the arc shifts (by up to
6 units, tapering to 0 at landing) versus the pre-fix trajectory. This is a
DELIBERATE, disclosed change, not a silent regeneration — no persisted golden-
file fixtures exist yet in the repo (checked: no `*golden*` files under
version control; `SimHarness`/`InspectionView` exist as the infrastructure a
future QA golden harness would read, per their own doc comments, but nothing
is checked in yet), so there is nothing stale to regenerate. The one place
this trajectory was asserted in test form, `test_character_a.gd`'s
`_test_jump_arc_integrates`, is updated in this same change: its prior
assertion explicitly TOLERATED the drift ("assert it LANDS CLOSE to its start
... within one frame's worth of velocity, not bit-exact") — that tolerance
was, in hindsight, documenting the very defect this flag reports. Updated to
assert exact equality (`pos_y == start_y`) now that the fix makes it exact.

**Regression coverage.** `test_character_a.gd`'s `_test_jump_arc_integrates`
(updated, asserts bit-exact return to start height). Not yet covered:
an end-to-end (live-input, not state-injected) landing assertion through
`test_command_recognition.gd`'s existing jump test — that test only checks
`STATE_JUMP_N` is reached, not the full landing; left as-is since it wasn't
in this flag's path and adding it would be a training-suite feature beyond
this dispatch's two defects, per the boundary. Worth a follow-up if QA wants
belt-and-suspenders live-input landing coverage.

**For Architect ratification:** the apex-hang mechanism itself (vs. an
uneven-speed fall, vs. a runtime clamp) as the general pattern for any future
arc whose frame count doesn't evenly split its rise/fall — this fix is scoped
to `STATE_JUMP_N/F/B`'s specific numbers, but the "authored arcs must net to
zero displacement" invariant it protects is arguably worth stating explicitly
somewhere (`character-a.md` or a movement-authoring note) so a future
character's jump arc doesn't reintroduce the same class of bug.

### JC-048 · 2026-07-08 · TKT-P1.1-03 (AD-034 fail-fast mechanism; new test file) — ratified

**Decision.** AD-034 and the ticket both specify the *behavior* on an
unrecognized `"v"` — "fail loudly (`push_error` naming the unexpected
version); do not silently proceed" — but not the concrete mechanism by which
`from_dict` (a function typed `-> SimState`) refuses to proceed. `push_error`
alone is non-fatal in GDScript: it writes to the error console but does not
halt execution or unwind the call, so something has to happen after it for
"do not silently proceed" to actually hold. Implemented as: call
`push_error` with a message naming both the unexpected and expected version,
then `return null` immediately, before touching any other field of `d`. A
caller that ignores the return value and tries to use the result gets an
immediate, loud null-reference failure rather than a silently-misparsed
`SimState` limping through a run.

**Alternatives passed over.** (1) `assert(false, ...)` — rejected: Godot
strips `assert` in release/non-debug export builds, so it is not a reliable
fail-fast in the one context (a build a player or CI runs release-mode)
where a format mismatch would matter most; `push_error` fires in every
build. (2) Returning a partially-parsed `SimState` (parse what's parseable,
warn, continue) — rejected outright: this is exactly the "silent mis-parse"
AD-034 rules out; a partially-built state that then runs is worse than an
obvious null-deref crash. (3) Raising/throwing an actual exception — not
available as an idiomatic GDScript mechanism (no `throw`/`try` in GDScript
4.3); `push_error` + sentinel return is the closest idiomatic equivalent.

**Also recorded here (packaging, not behavior):** the acceptance tests for
this ticket live in a new dedicated file, `game/tests/test_serialization_
version.gd`, rather than being folded into `test_sim_state.gd`'s existing
suite. Passed over: adding cases to `test_sim_state.gd` directly (it already
covers `SimState` round-trip/hash broadly) — rejected in favor of a
dedicated file so the format-version-specific behavior (AD-034: presence,
absence, mismatch, hash-exclusion) reads as its own clearly-scoped unit
mirroring the ticket 1:1, and so QA's golden/regression work can point at
one file for "is the version guard intact" without wading through the
general round-trip suite. The new file follows `test_sim_state.gd`'s own
`SceneTree`-runner shape (`_init`/`_eq`/`_true`/`quit(0|1)`) exactly — no new
test-harness convention introduced. Added to `run_tests.bat`'s `TESTS` list
as part of this same dispatch's bookkeeping-flag work.

**For Architect ratification:** the `null`-return convention for a fail-fast
`from_dict` — this is the first place in the codebase a *loader* function
can fail and needs to signal it structurally (every other `from_dict` in the
graph assumes a well-formed sub-dict and has no analogous guard); if a
future ticket adds more versions/migrations, worth deciding once whether
`null`-return is the standing convention for "reject this dict" or whether a
richer result type (ok/error) is worth introducing then.

### JC-049 · 2026-07-09 · TKT-P1.1R-01 · Trace-row exact field order/text encoding — ratified
**Serves:** `docs/spec/trace-harness.md` Contract 3 ("Row = one dumped tick... fixed
field order") and acceptance criterion 4 (round-trip identically).
**Decision.** `TraceHarness.format_row` emits, in order: `tick=<n>`, then for
player 0 the fields `state, frame, cat, px, py, vx, vy, act, stun, sk, face` (each
`p0.<field>=<value>`), then the identical set for player 1 (`p1.*`), then any
requested optional fields in the order `boxes` (per player, immediately after
that player's default block), `advantage` (`adv.value`, `adv.plus_player`,
`adv.neutral_restored`), `last_hit` (`hit.attacker`, `hit.defender`,
`hit.damage_dealt`, `hit.was_block`, `hit.contact_depth`,
`hit.air_height_hitstun_delta`). Optional `boxes` renders as
`KIND:x,y,w,h` box entries `;`-joined within one `p{i}.boxes=` field (KIND one of
`HURT/HIT/THROW/PUSH`, `BoxView`'s own kind names).
**Alternative considered.** Interleaving p0/p1 per-field (`p0.state p1.state
p0.frame p1.frame ...`) instead of a full block per player. Passed over: a
per-player block reads as one coherent "this player's row" at a glance (the way
a fighting-game frame-data tool typically groups a combatant's stats), and
matches the table's own presentation (one Field column, `p{i}.` prefix implying
"repeat this whole list per player").
**Why latitude, not escalation.** Contract 3 fixes the field SET and that the
order is fixed; it does not fix the literal token sequence. One reasonable
reading, cheaply reversible (a caller reads named `key=value` pairs by name, not
position), invisible across the seam.
**Ruling (Architect, 2026-07-10).** Ratified and **folded into the spec**: the emitted
row encoding is now pinned in `trace-harness.md` Contract 3 ("Emitted row encoding")
verbatim — `tick`, then each player's full default block (`p{i}.` over `state, frame,
cat, px, py, vx, vy, act, stun, sk, face`) p0-before-p1, then opt-in fields (`boxes`
after that player's block; `advantage`/`last_hit` after both), with `boxes` as
`;`-joined `KIND:x,y,w,h`. Pinning it makes a `.trace` a stable, diffable golden format
(the spec's own long-term intent), so QA's later golden-lock has a fixed contract.

### JC-050 · 2026-07-09 · TKT-P1.1R-01 · Inline-assert runner is a GDScript API, not a text-DSL parser — ratified
**Serves:** `docs/spec/trace-harness.md` Contract 3 "Assert" mode; acceptance
criterion 5.
**Decision.** Built the inline-assert runner as a GDScript API —
`TraceHarness.check(rows, tick, field, expected) -> bool` (fails loudly, prints
tick/field/expected/actual, mirrors every existing test file's `_eq`/`_true`
convention) plus `TraceHarness.row_at` — rather than a parser for the spec's
worked illustration (a `.script`-style text file with `P1:`/`P2:` input lines and
`assert tick=<n> <field>=<expected>` lines, using symbolic state names like
`p0.state=WALK_F`).
**Alternative considered.** A literal text-file parser matching the illustration
verbatim. Passed over: resolving a symbolic name like `WALK_F` against a raw
`state_id` in a CHARACTER-AGNOSTIC harness (inspection-surface.md criterion 5 —
no character-specific code in the seam) needs a per-character symbol table
(name -> id) that no contract defines yet — inventing one would be a new,
un-spec'd resolution mechanism (contract-adjacent), not an implementation detail.
The GDScript-API form delivers the identical semantics Contract 3 actually
specifies as the contract — "(tick, field, expected)" checked against the trace,
failing loudly by name — while staying inside this codebase's existing,
already-audited test-authoring convention.
**Why latitude, not escalation (with a caveat).** The (tick,field,expected) +
loud-failure CONTRACT is fully preserved; only the host mechanism (GDScript call
vs. parsed text file) differs from the spec's illustrative shorthand. Flagged
here rather than silently decided because it has real drift-risk for QA's
long-term authoring plan (`trace-harness.md`: "QA (long-term): authors the
brief-derived trace-scripts") — if the Architect intends literal `.script` text
files (with a symbol-table contract to match), that is a small, additive
follow-up ticket, not a rewrite of what's built here.
**Ruling (Architect, 2026-07-10) — the caveat resolved, not rubber-stamped.** Ratified:
**the GDScript `TraceHarness.check`/`row_at` API is the ratified assert host for this
build and for QA's near-term authoring surface.** Trace-harness.md's illustrated
`P1:`/`assert tick=… field=…` block with symbolic names (`WALK_F`) is **illustrative of
the assertion *semantics* — `(tick, field, expected)` checked against the trace, failing
loudly by name — not a pinned file grammar** the build must match. The Developer's core
reasoning is sound and is the deciding factor: a literal text-DSL resolving a symbolic
state name against a raw `state_id` needs a per-character symbol table (name→id) that
**no contract defines**, and inventing one in a **character-agnostic** seam
(inspection-surface.md criterion 5) would be a new, un-spec'd, contract-adjacent
mechanism — correctly escalated, not silently built. A literal text `.script` DSL (with
a symbol-table contract to match) is an **explicitly-deferred, additive extension**, not
a defect in this build and **not** part of the P1.1 bar; it becomes a spec item only if/
when QA's authoring plan calls for pasteable text files (the same build-for-extension
horizon as the "share a setup" / P3-tutorial hooks the spec already parks). Folded both
clarifications into `trace-harness.md` (Contract 3 Assert mode + Ownership) so QA reads
the correct authoring surface going into the audit. **Reported to the Strategist: QA's
current authoring surface is the GDScript API; the text-DSL is not built and not owed.**

### JC-051 · 2026-07-09 · TKT-P1.1R-01 · InputScript grammar edge cases — ratified
**Serves:** `docs/spec/trace-harness.md` Contract 1 grammar + acceptance criteria
1/2.
**Decision.** (a) A repeated button letter within one token (e.g. `LL`) compiles
without error — the grammar's `button...` literally permits repetition, and OR-ing
the same bit twice is a no-op, so it is harmless rather than a typo class. (b)
Digit `0`, and any character outside `1..9`/`L`/`M`/`H`, is a malformed token
(hard error). (c) Button letters are case-sensitive — only uppercase `L`/`M`/`H`
match; no lowercase convenience-aliasing was added.
**Alternative considered.** Rejecting a repeated button letter as malformed (extra
typo-catching strictness); accepting lowercase `l`/`m`/`h` as aliases (authoring
convenience). Passed over both: the spec's literal grammar already answers (a)
by definition and doesn't ask for (c), and adding either invents behavior beyond
the letter of Contract 1 for no stated need.
**Why latitude.** Pure grammar-boundary detail with one reasonable reading per
the spec's own literal production rules; no design/feel consequence.
**Ruling (Architect, 2026-07-10).** Ratified and **folded into the spec**: a "Grammar
edge cases" note added to `trace-harness.md` Contract 1 pins all three — repeated button
letters are idempotent-accepted, button letters are case-sensitive (uppercase only), and
`0`/any character outside `1-9`/`L`/`M`/`H` is a malformed hard error — so the shared-
artifact grammar has one durable reading (a typo cannot silently re-mean a shared setup).

### JC-052 · 2026-07-09 · TKT-P1.1R-01 · Hard-error mechanism + testing hook — ratified
**Serves:** `docs/spec/trace-harness.md` Contract 1 "Validation"; acceptance
criterion 1 ("a malformed token or reserved bit is a hard error, not a
dropped/altered frame").
**Decision.** `InputScript.compile`'s hard-error boundary is `assert(false, msg)`
on a malformed token/count, mirroring the codebase's EXISTING hard-error-at-the-
boundary convention (`InputSource.validate` / `InputFrame.is_valid`,
`input_source.gd`) rather than inventing a new error-signaling shape — Contract 1
fixes `compile`'s signature as the single pure `(text) -> PackedInt32Array`, which
leaves no room for an error-tuple return without changing that contract. Because
a tripped GDScript `assert` isn't reliably catchable/introspectable from a
headless test (this codebase's own established precedent —
`test_record_playback.gd`'s `_test_reproducibility_and_future_read_contract`
note on the same class of boundary), added a non-asserting
`InputScript.is_well_formed_token(token) -> bool` exposing the IDENTICAL grammar
check as a plain bool, so malformed-input detection is testable without tripping
the crash path. This helper is additive — not part of Contract 1's `compile`
signature.
**Alternative considered.** Changing `compile` to return an error-carrying
Dictionary/tuple instead of a bare `PackedInt32Array`. Passed over: Contract 1
fixes the signature; changing it would be a contract edit, not an implementation
choice.
**Why latitude.** The error-signaling MECHANISM (assert vs. a different return
shape) is implementation detail once the contract's signature is held fixed; the
codebase already has one established convention for this exact class of boundary,
and this reuses it rather than inventing a second one.
**Ruling (Architect, 2026-07-10).** Ratified as mechanism latitude — Contract 1's pure
`compile(text) -> PackedInt32Array` signature is held fixed, the assert boundary reuses
the codebase's one established hard-error convention (`InputSource.validate`), and
`is_well_formed_token` is a clearly-additive, non-contract testing hook. No spec change
(the contract signature is unchanged; the helper is outside it).

### JC-053 · 2026-07-09 · TKT-P1.1R-01 · P2 default-neutral via an empty buffer — ratified
**Serves:** `docs/spec/trace-harness.md` Contract 2 ("The P2 source defaults to a
neutral (idle) script when only P1 is driven").
**Decision.** `TraceHarness.run`'s `p2_text` default (`""`) compiles to an empty
`PackedInt32Array`, loaded into P2's `RecordPlaybackSource` as-is; that source's
OWN already-documented empty-buffer behavior (`_read_playback_and_advance`:
"An empty buffer plays back as NEUTRAL forever") supplies the neutral stream —
no explicit N-tick neutral buffer is compiled for P2.
**Alternative considered.** Compiling an explicit `"5*<ticks>"` P2 script sized to
the run length. Passed over: it would require threading `ticks` into the default-
script construction and produces byte-for-byte the same observable stream as the
simpler empty-buffer path, which is already a first-class, tested behavior of
`RecordPlaybackSource` (`test_record_playback.gd`) — reusing it is the smaller
surface.
**Why latitude.** Internal driver plumbing with one reasonable reading; the
observable P2 behavior (neutral forever) is exactly what Contract 2 specifies
either way.
**Ruling (Architect, 2026-07-10).** Ratified — the observable P2 stream (neutral
forever) is exactly Contract 2, and reusing `RecordPlaybackSource`'s already-tested
empty-buffer behavior is the smaller surface. No spec change.

### JC-054 · 2026-07-10 · TKT-P1.1R-02 · Spawn-offset vertical reflection as scalar-point negation — ratified
**Serves:** AD-037's consequence note ("record any box whose 'correct' reflected
height is a judgment call, e.g. a spawn offset"); `character_a.gd`'s
`STATE_FIREBALL_*` spawn keyframes and `TestSupport._build_fireball`'s mirror.
**Decision.** `Keyframe.spawn_offset_y` (the fireball's vertical release point,
consumed as `spawn_y = p.pos_y + kf.spawn_offset_y`, `step_phases.gd
_try_spawn_projectile` — the identical `pos_y + local_y` shape `MoveData.
resolve_box` uses for a box) is reflected as a bare scalar negation:
`new_offset_y = -old_offset_y` (character A: `45 -> -45`; TestSupport: `40 ->
-40`). Not run through the box formula `new_y = -(y+h)` with some inferred `h`.
**Alternative considered.** Treating the offset as a box with an authored-but-
implicit height (e.g. some notional "hand width") and reflecting via the full
box formula. Passed over: a spawn offset is a POINT (no `w`/`h` fields exist on
it at all — `move-format.md`'s `Keyframe` has no such fields), and the box
formula's `-(y+h)` is exactly `-y` in the degenerate `h=0` case — a point is a
zero-height box reflected about its own single edge, so the two readings
coincide; there is no second box-shaped alternative that produces a different
number, only a question of which formula-instance to cite.
**Why latitude.** The reflected VALUE is unambiguous (both framings agree); the
only judgment is characterizing it as "the point form of AD-037's formula" for
a future reader who might otherwise wonder why no `+h` term appears. Logged per
AD-037's explicit instruction to record spawn-offset reflections, not because
another value was plausible.
**Ruling (Architect, 2026-07-10).** Ratified and **folded into AD-037**: an authored
`Keyframe.spawn_offset_y` (a spawn *point*, no `h`) reflects as `new_y = -old_y` — the
degenerate `h=0` case of AD-037's `-(y+h)` box formula. Pinned in AD-037's Consequence
note so a future character authoring a spawn point inherits the rule instead of re-deriving
it.

### JC-055 · 2026-07-10 · TKT-P1.1R-02 · Orientation verified via direct InspectionView reads; CROUCH exercised by state-injection — ratified
**Serves:** AD-037 acceptance ("a harness/test asserts the sim-truth
orientation... right-side-up"); `training-mode.md` criteria 5/14.
**Decision.** The new `game/tests/test_geometry_reflection.gd` asserts box
orientation by reading `InspectionView.new(state, roster).player(0).boxes`
directly (typed `BoxView.rect` ints) rather than driving `TraceHarness.run` and
parsing its formatted `"KIND:x,y,w,h"` `boxes` string field, and exercises
`STATE_CROUCH` by setting `s.players[0].state_id` directly (mirrors the
existing state-injection pattern in `test_character_a.gd`/
`test_geometry_overlay.gd`) rather than through a scripted held-`2` input.
**Alternative considered.** Driving everything through `TraceHarness.run` +
`TraceHarness.check`/`row_at` (the ticket's named verification instrument) for
uniformity. Passed over for CROUCH specifically: held-`DOWN` -> `STATE_CROUCH`
command recognition is AD-038/TKT-P1.1R-03's engine change (the bare-`DOWN`
`button_map` entry does not exist yet this ticket), so no scripted input
reaches CROUCH at all pre-TKT-03 — direct injection is the only way to assert
its geometry now, and using the same direct-read approach for the standing/
pushbox/hitbox assertions keeps one consistent test shape rather than splitting
the file across two verification styles for no reason. Passed over for the
STRING-matching alternative specifically (even where scripted input does
reach, e.g. standing IDLE): matching `TraceHarness`'s exact formatted string
requires hand-computing scaled fixed-point values (`FP.SCALE = 65536`) inline,
which is exactly the "elaborate assertion scaffolding" JC-050 says not to
over-invest in for this provisional surface; reading the same underlying
`BoxView` ints directly is the smaller, more robust surface (AD-011 still
respected — `InspectionView` is `TraceHarness`'s own read path).
**Why latitude.** Internal test-authoring choice with no observable consequence
outside the test file; the sim-truth surface read (`InspectionView`) is
identical either way, and the acceptance bar ("a harness/test asserts...") is
satisfied by a test using the same AD-011 surface the harness is built on, not
necessarily `TraceHarness`'s own row-string API.
**Ruling (Architect, 2026-07-10).** Ratified as test-authoring latitude — the acceptance
bar ("a harness/test asserts the sim-truth orientation") is met by a test reading the same
AD-011 `InspectionView` surface the harness itself reads; using `TraceHarness`'s own
row-string is not required, and direct `BoxView` int reads avoid hand-scaling fixed-point
in-line (the over-investment JC-050 warns off for this provisional surface). No spec change.

### JC-056 · 2026-07-10 · TKT-P1.1R-03 · Crouch `button_map` entry placed immediately after the DOWN+button crouch normals — ratified
**Serves:** TKT-P1.1R-03's ordering instruction ("after the DOWN+button crouching
normals... and before the walk entries"); AD-032's first-match-wins shadowing
rule; `character_a.gd` `_build_button_map`.
**Decision.** `_map(-1, InputFrame.DOWN, 0, STATE_CROUCH)` is appended
immediately after the three `2L/2M/2H` entries (before the jump entry, the
standing normals, and the walk entries) rather than, say, immediately before
the walk entries at the bottom of the list.
**Alternative considered.** Placing the bare-`DOWN` entry directly above the
walk entries (still satisfying "before the walk entries," the ticket's literal
floor) instead of directly below the crouching normals. Passed over: nothing in
the recognizer requires it further down (`button_index == -1` pure-direction
entries never compete with the `button_index >= 0` jump/standing-normal entries
above them — different `button_index`, so first-match-wins never has to choose
between them), so placement anywhere in `[after 2L/2M/2H, before WALK_F/WALK_B]`
is behaviorally identical; adjacency to the crouching normals it is ordered
against (readability — the "DOWN routes low, with or without a button" cluster
stays together) was the only real consideration, not a reachability difference.
**Why latitude.** Any placement satisfying the ticket's two named constraints
produces the identical recognizer result (verified: `2L/2M/2H` still win over
bare `2` when a button is held; `3` — DOWN+FORWARD — still crouches, not walks,
regardless of where in that span CROUCH sits). Purely a readability/authoring-
order call with no behavioral difference among the reasonable alternatives.
**Ruling (Architect, 2026-07-10).** Ratified as authoring-order latitude — both named
ticket constraints (after `2L/2M/2H`, before the walk entries) are satisfied and the
recognizer result is identical for every placement in that span; adjacency to the
crouching normals is a readability choice with no behavioral consequence. No spec change.

### JC-057 · 2026-07-10 · TKT-P1.1R-03 · Crouch-block scenario verified via a direct `SimState.step` + `InspectionView` test, not `TraceHarness` — ratified
**Serves:** TKT-P1.1R-03 acceptance ("a crouching held-back defender blocks a
hit — enters a blockstun category"); `trace-harness.md` (the named instrument).
**Decision.** `game/tests/test_held_input_stances.gd`'s walk-exit and crouch-
enter/exit assertions run through `TraceHarness`/`InputScript` (the ticket's
named instrument, a clean fit — pure scripted-input movement). The crouch-BLOCK
scenario instead builds a `SimState` directly (attacker/defender positioned at
a proximity gap that puts 5L's hitbox in reach of the defender's crouching
hurtbox — mirrors `test_character_a.gd`'s `_two_char_state`/`_test_5h_5m_link_
window` gap pattern) and steps it directly, reading the result through
`InspectionView` (still AD-011).
**Alternative considered.** Driving the block scenario through `TraceHarness.
run` too, for one consistent instrument across the whole file. Passed over:
`TraceHarness.run` fixes both players at `SimState.new_initial()`'s spawn gap
(200 units) with no position-override parameter (`trace-harness.md` names no
such contract) — closing that gap by scripted walking alone (character A's
walk speed is ~2.2 units/tick) would need ~70+ scripted ticks of pure
choreography with no bearing on what the assertion is actually about (block
resolution on contact), obscuring the scenario's point for no verification
gain over the direct-`SimState` proximity pattern the rest of the combat suite
(`test_character_a.gd`, `test_invuln.gd`) already uses for exactly this shape
of test. `trace-harness.md`'s own header calls out that it is "not a TAS
framework" for elaborate choreography — this is that case.
**Why latitude.** Test-instrument choice per scenario, not a contract or feel
call; both paths read sim truth exclusively through `InspectionView`/
`PlayerView` (AD-011), so the thing being verified (a crouching held-back
defender's hit resolves to a blockstun category) is identical either way.
**Ruling (Architect, 2026-07-10).** Ratified as test-instrument latitude — `TraceHarness.run`
fixes both players at the 200-unit initial spawn gap with no position-override contract, so a
contact scenario is legitimately built by the direct-`SimState` proximity pattern the combat
suite already uses; both paths read sim truth through `InspectionView` (AD-011). (A harness
position-override hook is a plausible future build-for-extension convenience, not owed now.)
No spec change.

### JC-058 · 2026-07-10 · TKT-P1.1R-03 · `TestSupport` (P0 test character) gains a bare-RIGHT `button_map` entry -> `STATE_WALK`, and `test_combat.gd`'s walk-integration test now holds that input — ratified
**Serves:** keeping the full suite green under AD-038's deliberate, spec'd
behavior change ("movement goldens change deliberately — walk now terminates");
`test_combat.gd::_test_movement_integration` (pre-existing, not part of this
ticket's named read-set).
**Decision.** AD-038 makes every ACTIONABLE LOOP state (idle/walk/crouch)
re-derive from input every tick, for every character generically (the engine
change is character-agnostic by design). `TestSupport` (the P0 test character,
`game/tests/test_support.gd`), unlike `character_a.gd`, had `STATE_WALK`
authored as data but no `button_map` entry ever targeting it — walking was only
ever reached by test code poking `p.state_id` directly, a path AD-038 now
immediately re-derives away from on the very same actionable tick (no held
input recognizes it, so `target` resolves to idle before phase 3 can integrate
its motion). This broke `test_combat.gd::_test_movement_integration` ("walk
integrates +2 units/tick"), a pre-existing engine-level (not character-A)
regression test. Fix: add `_map(-1, InputFrame.RIGHT, 0, STATE_WALK)` (the same
AD-032 pure-direction pattern character A's own walk entries use) as the LAST
`button_map` entry, and change the test to feed `InputFrame.RIGHT` (P0 faces
+1) instead of `InputFrame.NEUTRAL` so the re-derivation re-selects WALK
(`target == current`, a no-op) instead of collapsing to idle.
**Alternative considered.** Leaving `test_combat.gd` red as a known, documented
"movement golden that changed" and letting QA/the Architect decide. Passed
over: the ticket's own acceptance bar is "run the full suite and confirm
green," and this is squarely the class of change the ticket already
anticipates and blesses ("movement goldens change deliberately"), not a new
design question — the fix is mechanical (bring the shared test fixture's
`button_map` in line with the same pattern already used for the shipped
character) and carries no risk (test-only content, no engine or character-A
change). Also considered: making P0 non-actionable that tick via some other
means (e.g. injecting stun) to dodge AD-038's re-derivation entirely without
adding a `button_map` entry. Passed over: stun's absence of a real input-driven
walk command was the actual gap this exposed (mirrors the exact class of gap
AD-032 fixed for character A); routing around it with an artificial non-
actionable state would leave `TestSupport` permanently unable to express a real
walk command, a worse and less honest fixture than character A's own.
**Why latitude.** Test-fixture-only content change (no engine, no shipped
character, no contract) needed to keep a pre-existing, in-scope-suite test
green under this ticket's own engine change; the pattern added is not new
(copies AD-032's established pure-direction shape) and record-worthy only
because it touches a shared fixture other tests also depend on.
**Ruling (Architect, 2026-07-10).** Ratified as test-fixture latitude — bringing
`TestSupport`'s `button_map` in line with the same AD-032 pure-direction pattern the
shipped character uses is the honest fix (not routing around AD-038 with an artificial
non-actionable state), and the held-RIGHT integration test still holds under the AD-038
exit correction ruled in this pass (a continuously-held direction re-selects walk under
current-direction re-derivation just as it did under the buffered path). No spec change.

### JC-059 · 2026-07-10 · TKT-P1.1R-04 · Air-normal `CancelRule` window authored as `[1, JUMP_DURATION-1]` — ratified
**Serves:** AD-039 ("air normals via jump-state cancels" — "window = the
airborne frames"); the ticket's own worked example (`[1, JUMP_DURATION - 1]`).
**Decision.** Each of `JUMP_N/F/B`'s three air-normal `CancelRule`s
(`_air_normal_cancels`, `content/character_a.gd`) is windowed `[1,
JUMP_DURATION-1]` = `[1, 44]` — open from the first airborne frame through the
frame BEFORE the jump's own 45-frame duration elapses, not `[1, 45]` (the full
duration).
**Alternative considered.** `[1, JUMP_DURATION]` (the full arc, frame 45
included). Passed over: `Actionability.is_actionable` treats a committed
once-through move as actionable once `frame_in_state >= duration` (the same
"recovery has ended" reading `PREJUMP`'s own window-3 authoring already
relies on, JC-038) — on frame 45 itself, phase 2's fixed priority order
(`phase2_state_machine`) takes the ACTIONABLE/buffered-command branch INSTEAD
of the cancel branch, so a `CancelRule` window that included frame 45 would
never actually be evaluated there; the cancel is legal-on-paper but
dead-on-that-frame either way. `JUMP_DURATION-1` states the TRUE reachable
window instead of an window whose top edge is silently unreachable.
**Why latitude.** The ticket's own worked example already writes `[1,
JUMP_DURATION - 1]` verbatim — this is confirming/authoring exactly that
bound, not inventing a new one; recorded because AD-039 says "e.g." (leaves
the precise bound to the Developer) and the off-by-one reasoning is the same
class of authoring subtlety JC-038 already established for the prejump
lead-ins, worth citing for a future reader/character.
**Ruling (Architect, 2026-07-10).** Ratified and **folded into AD-039**: an air-normal (and
prejump) `CancelRule` window ends at `duration - 1`, since on the duration frame itself the
committed move is already actionable and phase 2's fixed priority takes the actionable/
buffered branch over the cancel branch (the JC-038 off-by-one), making a frame-`duration`
window edge silently unreachable. Pinned in AD-039 so future air normals inherit the true
reachable bound.

### JC-060 · 2026-07-10 · TKT-P1.1R-04 · `PREJUMP_F`/`PREJUMP_B` factored through a shared builder; new state ids placed outside the movement block — ratified
**Serves:** AD-039 ("author `PREJUMP_F`/`PREJUMP_B` mirroring the existing
`PREJUMP`"); `content/character_a.gd`'s state-id allocation.
**Decision.** (a) `PREJUMP`/`PREJUMP_F`/`PREJUMP_B` are all built by one new
`_build_prejump(state_id, target) -> MoveState` (same 4f duration, same
window-3 ALWAYS cancel, differing only in id and cancel target) rather than
three hand-copied blocks. (b) `STATE_PREJUMP_F = 160` / `STATE_PREJUMP_B =
161` — placed outside the contiguous `100-109` "Movement states" id block
(already fully allocated) rather than renumbering any existing state id.
**Alternative considered.** (a) Three separate hand-authored `MoveState`
blocks (mirrors the ORIGINAL `PREJUMP` code's own shape most literally).
Passed over: the three states are identical apart from id/target, and the
existing code's own comment already flagged the eventual F/B lead-ins as
"authored the same way" — a shared builder is the smaller, more obviously-
correct diff and removes two copies of the window-3 rationale comment that
would otherwise need to stay in lockstep. (b) Renumbering the movement block
to make room for contiguous ids. Passed over: would touch `STATE_CROUCH`/
`STATE_JUMP_*`'s existing values for no behavioral gain — ids are opaque
integers to the engine, and gratuitously renumbering shipped, already-baked
ids is pure churn/risk for a cosmetic grouping preference.
**Why latitude.** Both are internal data-structure/id-allocation choices with
no design consequence and one reasonable reading each; invisible across the
seam (nothing outside this builder reads a `MoveState`'s numeric id as
meaningful beyond equality).
**Ruling (Architect, 2026-07-10).** Ratified as data-structure/id-allocation latitude — a
shared `_build_prejump` builder and non-contiguous ids (160/161) are invisible across the
seam (engine treats a state id as an opaque equality token); renumbering shipped ids would
be pure churn. No spec change.

### JC-061 · 2026-07-10 · TKT-P1.1R-04 · `_test_no_gatlings_no_jump_cancels` updated to exempt the new AD-039-sanctioned jump-state cancels — ratified
**Serves:** keeping the full suite green under AD-039's deliberate, spec'd
content (air normals reachable via a jump-state cancel); `test_character_a.gd`
criterion-9 test (pre-existing, not part of this ticket's named read-set).
**Decision.** `_test_no_gatlings_no_jump_cancels` (character-a.md criterion 9:
"no gatlings... no jump cancels") had two blanket guards written before any
jump state carried a `CancelRule`: (1) no state's `CancelRule` targets a
"normal" (`5L/5M/5H/2L/2M/2H/j.L/j.M/j.H`) — the anti-gatling check; (2) no
state's `CancelRule` targets a jump state, except `PREJUMP` itself (its own
lead-in). AD-039 legitimately adds `CancelRule`s FROM `JUMP_N/F/B` INTO
`j.L/M/H`, which trips guard (1) as written (the air normals are in its
`normal_state_ids` list), and adds `PREJUMP_F`/`PREJUMP_B`'s own lead-ins into
`JUMP_F`/`JUMP_B`, which trips guard (2)'s single-exception (`PREJUMP` only).
Fixed: guard (1) now skips `JUMP_N/F/B` as SOURCE states (a jump state
cancelling into its own air normal is the airborne-action model, not a
grounded normal-to-normal gatling chain); guard (2)'s exception list now
includes all three prejump states.
**Alternative considered.** Splitting `normal_state_ids` into a grounded-only
list for guard (1) instead of skipping the jump states as sources. Passed
over: equivalent in effect, but skipping the jump states as sources reads
more directly as "this guard is about a NORMAL cancelling into another
normal" (matching the criterion's own "no gatlings" framing) — the target
list stays the single complete "these are the normals" list used elsewhere in
the file, and only the source-side loop changes.
**Why latitude.** Test-only content change (no engine, no shipped character
behavior, no contract) required to keep a pre-existing, in-scope-suite test
green under this ticket's own AD-039-sanctioned content — the same class of
call JC-058 already made one ticket ago for an analogous pre-existing-test
collision.
**Ruling (Architect, 2026-07-10).** Ratified as test-guard latitude (JC-058 class) —
exempting `JUMP_N/F/B` and the three prejumps as *source* states aligns the criterion-9
guard with what AD-039 now sanctions (a jump state cancelling into its own air normal is
the airborne-action model, not a grounded gatling); the guard's target list stays the
single complete "these are the normals" list. No engine or shipped-character change. No
spec change.

**JC-062** · 2026-07-10 · TKT-P1.1R-05 · AD-038 (corrected) two-tier detection mechanism.
**Decision.** Implemented the loop-state branch's two tiers as two independent full
scans over `character.button_map`, each first-match-wins in authored order:
`_buffered_discrete_command` (tier 1 — skips any entry whose target's `move.loop` is
true, returns the first entry satisfied via the existing buffered `InputBuffer.
entry_satisfied`) and `_current_tick_loop_command` (tier 2 — skips any entry whose
target is not `loop`, returns the first entry satisfied via a new `InputBuffer.
entry_satisfied_now`). An entry whose target state cannot be resolved (`character.
get_state` returns null) is treated as discrete (tier 1's job) — the same default the
pre-correction single-tier code implicitly had for an unresolvable target. `entry_
satisfied_now` mirrors `entry_satisfied`'s structure (chord / pure-direction / plain
button) but checks ONLY `hist.at(0)` — no `COMMAND_BUFFER`/`MOTION_WINDOW` lookback —
and unconditionally returns false for a motion entry (a multi-frame ordered sequence
cannot complete in one tick; no authored loop-state target in this slice uses a motion
command, so this is a completeness guarantee, not a reachability path).
**Alternatives passed over.** (a) One combined scan branching per-entry on `target.
loop` inside a single loop, tracking the first discrete AND first loop-target match in
one pass — rejected as marginally more efficient but harder to read as "two independent
questions," and the ticket's own framing ("tier 1 / tier 2") maps cleanly onto two named
functions. (b) Reusing `entry_satisfied` with a new `window` parameter (defaulting the
existing buffered calls to `COMMAND_BUFFER`/`MOTION_WINDOW` and passing 1 for the
current-tick case) instead of a sibling function — rejected: motion recognition's
window is structurally different from a lookback count (it is "the last N frames, in
order," not "look back N frames each"), so forcing both call shapes through one
parameterized function would have made the motion branch's "always false at window=1"
case implicit/fragile rather than the explicit early-return `entry_satisfied_now` gives
it.
**Why.** Both are read-only implementation shape with no observable behavioral
difference from any other reasonable factoring — a genuine "how," not a "what": the
corrected AD-038 already specifies the discriminator (`move.loop`), the priority order
(discrete first), and the current-tick-only semantics (no buffer carry-over) exactly.
Cheaply reversible; invisible across the seam (nothing outside `step_phases.gd`/
`input_buffer.gd` calls either new function). — ratified
**Ruling (Architect, 2026-07-10).** Ratified — this is a faithful realization of the
corrected AD-038 contract, not a reinterpretation of it: (1) discrete-first **priority**
holds (tier 1 scanned/preferred before tier 2); (2) the **discriminator** is `move.loop`
on the target, as the contract specifies; (3) the load-bearing **current-tick-only / no
buffer carry-over** stance semantics are exactly what `entry_satisfied_now`'s age-0-only
check delivers (a released direction is neutral at age 0 ⇒ not satisfied ⇒ idle
fallback). Two separate scans vs. one combined scan is observably identical (both yield
first-discrete-then-first-loop-target). The two-scan shape, the sibling `entry_satisfied_
now`, and the "unresolvable target ⇒ discrete" default are read-only implementation
factoring. **Folded into AD-038** the two contract-adjacent facts this surfaced (so future
content/implementers inherit them): a **loop-state (stance) command must be current-tick-
recognizable** — a multi-frame **motion cannot be a stance command** (it can never satisfy
the current-tick tier), and an **unresolvable target defaults to the discrete tier**.

**JC-063** · 2026-07-10 · TKT-P1.1R-05 · AD-022 regression-guard test instrument +
golden-scope confirmation.
**Decision.** The new AD-022 discrete-command regression guard (`test_held_input_
stances.gd::_test_discrete_command_buffered_through_hitstun_still_fires_first_
actionable_frame`) is written as a direct `SimState.step` loop over a hand-injected
`PlayerState` (`state_id = CharacterA.STATE_HITSTUN`, `stun = 4`, held forward+L every
tick), not through `TraceHarness`/`InputScript` — mirrors the existing crouch-block
scenario's instrument choice (JC-057) and the invuln suite's state-injection pattern
(JC-036), for the same reason: `TraceHarness.run` has no hook to start a player mid-move
in a stun category, and this guard needs exactly that ("recovering from a real hit," not
"idle at tick 0"). Also recorded: the ticket's "surgical golden scope" held —
`test_held_input_stances.gd`'s three walk/crouch release-timing assertions (tick values
+ expected state) are the ONLY assertion values changed anywhere in the suite; every
combat/advantage/determinism test and every held-direction (continuously-fed) movement
test (`test_combat.gd`'s walk-integration test, `test_command_recognition.gd`'s
walk-forward/back end-to-end tests, `test_character_a.gd`'s 5H-advance test) was left
untouched and stayed green unmodified.
**Alternatives passed over.** Driving the guard through a live hit exchange (attacker
actually connects a normal on the defender) instead of directly injecting `STATE_
HITSTUN` — rejected as unnecessary indirection for what this guard is actually testing
(the phase-2 branch's tier priority, not hit resolution itself); the existing combat
suite already covers live hit-into-stun paths.
**Why.** Test-authoring latitude only — reads the same `InspectionView`/`SimState.step`
surface either way (AD-011), no contract or behavior difference from how the assertion
is driven. — ratified
**Ruling (Architect, 2026-07-10).** Ratified as test-instrument latitude — the same
state-injection pattern already ratified for exactly this shape of scenario (JC-057
crouch-block, JC-036 invuln), correctly chosen because `TraceHarness` cannot start a
player mid-move in a stun category, and the guard needs "recovering from a real hit," not
"idle at tick 0." The **surgical golden-scope confirmation** (only the three walk/crouch
release-timing assertions moved; combat/advantage/determinism and every *held*-direction
movement test untouched and green) is exactly the ticket's scope bar — recorded here as
evidence for QA's audit; no spec change. Both reads are AD-011.
