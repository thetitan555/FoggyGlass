# Audit — TKT-P0-01 (Project scaffold + fixed-point core)

> Owner: **QA**. Routed findings go to owners as flags (`/docs/flags.md`).
> Method: **static** verification only — Godot is not installed in the audit
> sandbox, so no engine/test-runner execution was possible. Every claim below is
> a read-of-source verdict; anything requiring execution is marked **GATED** and
> deferred to the harness (TKT-P0-11) and real `SimState`/`step` (TKT-P0-03).

**Date:** 2026-07-02
**Verdict:** **PASS (with findings)** — nothing blocks TKT-P0-01 as delivered;
findings are two doc-consistency nits (one to Developer, one process note) and
no objective failure. See split and findings below.

---

## What TKT-P0-01 is accountable for

Per `p0-backbone.md`, this ticket serves AD-013, AD-014, and `simulation.md`'s
tick model; its stated acceptance is `move-format.md` crit 9 (fixed-point data
path) and `simulation.md` crit 5 (tick authority) — with crit 5 explicitly
"fully verifiable once 03 lands." The five judgment calls (JC-001..005) are all
ratified and are the drift feed for this audit.

## Files audited (all under `/game`)

- `sim/fp.gd`, `sim/tick_host.gd`
- `scenes/main.gd`, `scenes/main.tscn`, `project.godot`, `README.md`
- `tests/test_fp.gd`, `tests/test_tick_host.gd`

---

## Verified statically — PASS

### `move-format.md` crit 9 — Fixed-point data path (fully verifiable now)

- **One scalar convention (AD-014).** `FP.SHIFT=16`, `SCALE=1<<16=65536`,
  `HALF=1<<15`. Multiply is `(a*b)>>16`, divide is `(a<<16)/b`. Matches AD-014
  exactly. **PASS.**
- **No float reaches the runtime hot path.** `grep` across `sim/` finds `float`
  only in (a) the three explicitly-quarantined bakes/view fns —
  `from_float`, `from_units`, `to_float` — each documented "authoring/load only,
  never inside `step`" and "view only," and (b) doc comments. No sim arithmetic
  path consumes a float. **PASS** on the static half; the *runtime* guarantee
  "no float reaches `step`" is **GATED** on 03 (no `step` exists yet).
- **No transcendentals (AD-014).** No `sqrt`/`sin`/`cos`/`pow`/`log`/`normalize`
  anywhere in `sim/`. The class provides none by construction. **PASS.**
- **JC-002 two-extractor split (ratified into AD-014).** `to_int` truncates
  toward zero with explicit sign handling — `-((-a)>>SHIFT)` for negatives, so
  `-1.9 -> -1`, NOT the `>>`-floor `-2`. `round_to_int` is round-nearest ties
  away from zero. The prohibited arithmetic-shift truncation (`>>` floor toward
  −∞) is *avoided* in `to_int` precisely as the ratified contract requires.
  Verified by reading both functions and their test vectors. **PASS.**
- **Rounding consistency across `mul`/`div`/bakes (JC-002).** All three apply
  round-nearest ties-away-from-zero: `mul` adds `HALF` before the shift with sign
  correction; `div` adds `d>>1` (half the divisor magnitude) before the integer
  divide with sign correction; `from_float` adds `0.5` before `int()` with sign
  correction. Hand-checked: `div(ONE, from_int(3))` → magnitude
  `(65536<<16 + 98304)/196608 = 21845` (matches the test's expected `21845`).
  Rounding rule is single-sourced in behavior across all three. **PASS.**
- **JC-003 `mul` magnitude budget (ratified into AD-014).** `FP.mul` computes the
  64-bit product with no widening/guard, exactly as ratified; the method doc and
  AD-014 both carry the `|a_units*b_units| < 2^31` budget and the escalation
  trigger. The behavior in code matches the ratified contract. **PASS** as a
  *documented, bounded* choice. (Not a defect — see "Standing watch item" below;
  this is a bound to assert against later, not to fix now.)
- **JC-001 `FP` packaging.** `class_name FP extends RefCounted`, all-static
  methods, no instance state, no autoload. Matches the ratified packaging folded
  into AD-014. **PASS.**

### `simulation.md` crit 5 — Tick authority (partially verifiable now)

- **Clock read from state, not an engine counter.** `current_tick()` returns
  `_sim_state` (the stand-in), never `Engine.get_physics_frames()` or a frame
  count. `set_state`/`current_tick` route reads through the state handle. **PASS**
  (static).
- **One `_advance` per `_physics_process`; `delta` never scales.** `_physics_process(_delta)`
  calls `_advance` exactly once when `running`, ignores `_delta` (leading-underscore,
  genuinely unused — verified no read of it in the body). `_advance` adds exactly
  1. No multiplication by delta or frame count anywhere. **PASS** (static).
- **Pause guard.** `running=false` short-circuits before `_advance`; determinism
  is untouched (no ticks run). **PASS** (static).
- **JC-004 seam discipline.** The `_sim_state` handle + single `_advance` seam is
  present and is a bare `int` (tick only), so it cannot prefigure the 03 state
  shape — exactly as ratified (01→03 ordering ruled intended). The clock
  discipline this ticket exists to pin (one tick/physics_process, state-owned
  counter, no delta) is present and load-bearing. **PASS.**

### Tenet-level checks I can make statically

- **Tenet 1 (determinism), static portion:** no wall-clock, no `OS.`/`Time.`, no
  unseeded RNG (`randi`/`randf`) anywhere in `sim/`. No Godot physics body owns
  the tick state (the stand-in is a plain `int`; the host is a `Node`, not a
  physics body). **PASS** on what's present. The *behavioral* determinism
  criteria (purity, replay-determinism, round-trip, no-forbidden-reads
  end-to-end) are **GATED** — see below.
- **Tenet 3 (build-for-extension):** the seam design (opaque handle + single
  advance point, swappable to `step(state,in1,in2)` in one line at 03) is exactly
  what the tenet wants. **PASS** (design-level).

### Tests present (read, not run)

`test_fp.gd` and `test_tick_host.gd` are `extends SceneTree` headless runners
that `quit(0/1)` on pass/fail (JC-005, ratified). The FP suite covers the
extractors, rounding-tie boundaries both signs, mul/div sign cases, the bake
determinism, and the div-rounding vector I hand-checked above. The tick suite
covers state-routed reads, +1-per-advance monotonicity, and the pause/resume
guard with irrelevant delta values. **The assertions are well-targeted at the
acceptance criteria they can reach.** I did **not** execute them (no Godot); that
they run clean is **GATED** on a Godot binary being present (README flags this
same caveat honestly).

---

## GATED — cannot pass or fail here; deferred, by design

None of these are findings against TKT-P0-01 — they are simply out of reach until
03/11 exist, and the ticket says so.

- `simulation.md` crit 1 (purity), 2 (determinism harness), 3 (round-trip), 4
  (no forbidden reads, end-to-end), 9 (immutable input): **no `step` / `SimState`
  exists yet** (TKT-P0-03). Verifiable only under the QA harness (TKT-P0-11).
- `simulation.md` crit 5, the "render-rate changes don't change outcomes" half:
  asserted by construction now (the advance path takes no delta/frame input); a
  true end-to-end check needs 03's render loop + 11's harness.
- `move-format.md` crit 9, the runtime "no float reaches `step`" guarantee: no
  `step` to instrument yet.
- Golden-file frame-data/hitbox regression: no move format / built character yet
  (TKT-P0-05 / -10). Nothing to snapshot.

**QA commitment:** the determinism + serialization harness (crit 1–4, 9) and the
golden-file regression net are QA's TKT-P0-11 work and land *with* 03, per the
roadmap ordering. This audit is the baseline they build on.

---

## Findings (routed as flags)

1. **[Developer, trivial]** Stale identifier in a seam comment: `tick_host.gd`
   line ~71 and the JC-004 log both name the future call `SimSim.step(...)`; the
   class landing at 03 is `SimState`/`step` (README and `main.gd` say `SimState`).
   Cosmetic doc drift, zero code impact — flagged so the 03 developer isn't
   misled by an invented `SimSim` name. Flag raised in `flags.md`.

2. **[Strategist, process note — not a defect]** TKT-P0-01's "Acceptance" line
   names crit 5 and crit 9 as its bar, but the *majority* of what makes this
   ticket's tenet-proof meaningful (purity, round-trip, determinism) is correctly
   deferred to 03/11. This is fine and intended — I raise it only so the
   done-tracking is explicit that TKT-P0-01 "passing audit" means *its own
   reachable bar passed*, not that the determinism tenet is yet proven. No action
   needed unless the Strategist wants the roadmap "done-when" wording to reflect
   the partial coverage. Raised as an FYI flag, owner may close as intended.

No objective failures. No spec gaps requiring the Architect (AD-014's
elaboration already absorbed JC-001/002/003; the seam ordering is ruled intended
under JC-004; crit 5 and crit 9 are testable as written for the reachable half).

## Standing watch item (for QA's own future audits — not a flag)

- **AD-014 `mul` magnitude budget** is now an owned, asserted contract
  (`|a_units*b_units| < 2^31`). When the sim gains real positions/velocities (03+),
  QA should add a harness assertion that no live sim value approaches this budget,
  so the escalation trigger fires as a *test failure*, not a silent overflow. Not
  actionable at TKT-P0-01 (no sim values exist); recorded so it isn't lost.

## Charter / determinism read for the pipeline watcher

- **Determinism tenet:** being *served*, not drifting. Fixed-point from frame one,
  a single owned convention, the hot path provably float-free and
  transcendental-free, the clock pinned to state and never to `delta`, and the
  seam built so 03 can't smuggle in a physics-body state owner. This is the tenet
  taken seriously early, which is exactly where it's cheapest.
- **Legibility standard:** not yet exercisable — there is no player-facing state,
  inspection surface, or advantage readout at this layer (those are 04/07). The
  *precondition* for legibility (AD-011's read-only seam over serializable state)
  is architecturally intact and unblocked. Nothing here dumbs anything down; the
  audit-criterion's half-2 ("did it flatten anything?") is trivially satisfied
  because no play space exists yet to flatten. No legibility drift detected; the
  real legibility audit begins when the inspection surface carries truth (04/07/11).
