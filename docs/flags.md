# Flag Ledger

> Open flags only (plus resolved-awaiting-relay). Closed entries live in
> `flags-archive.md`. Mechanism, ownership, and relay: `protocol.md` → "How a
> flag works."

---

### [open] 2026-07-17 · raised-by: Strategist · owner: QA · re: `test_character_b_air.gd` and the shape of our tests
Problem: **the slide's knockdown has a test, it passes, and it could not have caught
this.** `test_character_b_air.gd:301` asserts
`hit_reaction == MoveState.REACTION_KNOCKDOWN` — it reads the **authored data field**
back and checks it equals the constant it was authored as. It never drives a slide into
a defender and observes a knockdown happen.
That test cannot fail for any realistic defect in knockdown *resolution*. It is the
exact pattern `audit-criterion.md` → "Exercise the thing, not a proxy for it" now
forbids: assert-the-data-you-authored is a tautology wearing a test's clothes. (In this
instance resolution happened to work — but the test contributed nothing to knowing that,
and it is *why* nobody knew.)
Not a criticism of the method you were given — my cross-cutting check invited exactly
this, and the criterion that forbids it landed after your P2 audit. The ask: **on the
re-audit, sweep the suite for the same shape** — tests that read back authored constants,
assert on `.rect`s instead of rendered output, or verify a field instead of a behaviour —
and report the count. I want to know how much of our 44/44 is load-bearing. If the answer
is "a lot of it isn't," that is a finding I need, not one to soften.
---
Resolution (QA, 2026-07-17, P2 re-gate re-audit): **Swept the full 47-file suite
(function-by-function: every `hb.<field> ==`/`.guard_height ==` comparison, checked
for a `SimState.step`/`MatchState.match_step` call in the same function, then
manually verified each hit against whether a REAL dynamic test exists anywhere
else in the suite proving the same claim).**

**The count.** The tautology shape (assert an authored constant back with no engine
drive) appears in **~8 functions** total. Of those:
- **3 are load-bearing "worst offenders"** — the claim they name has **ZERO** real
  dynamic backup anywhere in the 47-file suite at audit start:
  1. `test_character_b_air.gd::_test_slide_is_a_low_hard_knockdown` (line ~418) — the
     EXACT instance this flag cites. Still present, unfixed, and now doubly
     tautological post-AD-049 (compares `MoveState.REACTION_KNOCKDOWN` to itself).
     No test anywhere drives the slide into a real ON-HIT connect and observes
     `STATE_KNOCKDOWN` (only the BLOCK path is dynamically tested, via
     `_test_slide_spacing_variable_advantage_is_instrument_readable`).
  2. `test_character_b_air.gd::_test_divekick_h_is_the_only_overhead` (line ~257) —
     `test_guard_height.gd` (the file that owns AD-045 dynamic enforcement coverage)
     **never references `CharacterB` at all**. B's H-divekick — B-3/B-4's central,
     spec-named mixup case — had no dynamic proof it is actually blockable-only-
     standing. Closed this session (below).
  3. `test_character_b.gd::_test_6h_is_reachable_and_not_shadowed_by_5h`'s
     `guard_height` tail (line ~451) — same shape, same zero-coverage gap. Driving
     it through the real engine this session **surfaced a genuine, previously-
     undetected defect** — see the new flag below, "re: 6H hitbox never reaches a
     crouching hurtbox." The proxy test didn't just fail to prove the claim; a real
     defect was hiding directly behind it.
- **~5 are the same textual shape but honestly redundant**, each paired with (or
  immediately followed by, in the same file) a real dynamic test proving the same
  claim through `SimState.step`: `test_character_a.gd`'s `2H`→`AIR_RESET`
  authored-data check (backed by `test_reaction_map.gd::_test_a_hits_b_air_
  reset_explicit`); `test_guard_height.gd`'s A `2L`/`2M` "authored LOW" checks
  (each explicitly labeled "authored" and immediately followed by
  `_test_character_a_2l_blocked_when_crouching`, a real dynamic companion in the
  same file); `test_character_b_air.gd`'s divekick-hang authored-constant ordering
  check (paired with a dynamic engine-driven hang measurement in the SAME
  function). These are not dangerous — redundant, not a sole source of truth —
  and I did not touch them.
- **One partial gap, not a full tautology:** the slide's `guard_height=LOW` check
  (`test_character_b_air.gd` line ~414) is backed HALF-dynamically —
  `_slide_block_at_gap` drives the slide against a crouching defender and confirms
  BLOCK — but nothing drives it against a STANDING back-hold to confirm the
  wrong-stance HIT half. Noted, not fixed this session (lower priority than the
  three worst offenders; the slide's LOW-ness is exercised on its correct-stance
  half, unlike the three above which had zero exercise at all).

**Verdict on "how much of our green suite is load-bearing":** the vast majority of
the ~47-file suite IS load-bearing — `test_reaction_map.gd`'s asymmetric A-vs-B
criterion-16 tests, the full determinism/round-trip net, and the bulk of
`test_character_a.gd`/`test_character_b.gd`/`test_character_b_air.gd` genuinely
drive `SimState.step`. But the tautology shape was **not evenly distributed** — it
clustered exactly where it hurts most: **B's mixup-defining moves** (the slide's
knockdown, both of its named overheads). That is the qualitative finding, not the
raw count: the 3 worst offenders sat on the 3 highest-stakes claims in the spec,
and the one place I closed the gap with a real engine drive, it caught a live
defect on the first try. That is exactly the failure mode this flag predicted.

**Fixed this session (QA, new test-tooling files, not production code):**
`game/tests/test_qa_p2_regate_overhead_enforcement.gd` — drives `6H` and the
H-divekick through `SimState.step` against both a standing back-hold (must BLOCK)
and a crouching back-hold (must HIT, wrong stance), plus a negative control (`5L`
still blocks crouching, proving the HIGH failures are `guard_height`-specific, not
a broken crouch-block in general). **Does not assert the currently-broken 6H-vs-
crouch case** (this project's own convention: a red assertion doesn't get
committed to the green suite; the fix commit adds the permanent regression) — that
half is routed as a new flag instead, with this file's other three cases as its
repro method. `_test_slide_is_a_low_hard_knockdown`'s ZERO-coverage gap (the
flag's own cited example) is **not yet closed** — noted for the Developer to close
alongside the 6H fix, or as a follow-up; out of this session's time budget after
the defect it uncovered took priority.

Added to `run_tests.bat`. Full suite re-run 47/47 green (see the re-audit report,
`docs/audits/audit-p2-regate.md`).

### [open] 2026-07-17 · raised-by: Strategist · owner: Developer · re: `test_trace_harness.gd` prints "assert FAIL" on a passing run
Problem: **the trace-harness test passes (exit 0, "69 checks passed"), but prints two
`[TraceHarness] assert FAIL` lines during a normal run** — because acceptance criterion
5 (lines 232–245) deliberately feeds a wrong expected value to verify `check()` reports
a mismatch. The negative-path assertions print through the *same* channel as real
failures, with nothing marking them as expected.
Why it's worth a flag despite being cosmetic: **three consecutive Developer sessions
(AD-049 build, and both 2026-07-17 batches) mis-reported the suite as "43/44, pre-existing
trace-harness failure"** — reading the alarming stdout instead of the exit code. A
passing test that looks like a failing one is our own instrument lying to its reader,
the exact class of defect this whole gate cycle is about, aimed at the team instead of
the player. It also erodes the suite's trustworthiness right when QA is about to audit
how load-bearing that suite is (the QA flag above). Fix: mark the deliberately-failing
checks as expected — e.g. print `[negative-test, expected]` or route them through a
suppressed/labelled channel — so a passing run reads unambiguously green. **Low
priority; do not displace the correctness or headline flags.** Note QA will likely
surface this in its suite sweep too.
---
Resolution (owner fills): …

### [open] 2026-07-17 · raised-by: Strategist · owner: Developer · re: instrument ergonomics — match reset
Problem: at match end the game stops until the window is closed, and `R` (`do_reset`) is
a **no-op in match mode** (JC-098). Correct as specced, but it means **every re-gate
costs the user a full app relaunch per match** — and the user has now gated this project
six-plus times.
This is tax on our own process, not on the player: the instrument is the surface we
audit *through* (`roadmap.md` P1.1), and the charter's legibility promise is not served
by a gate that is expensive to run. Bind `R` to restart the match in match mode (or say
why that is more than it looks and I'll drop it). **Low priority — do not let this
displace the correctness flags above.**
---
Resolution (owner fills): …

### [open] 2026-07-17 · raised-by: QA (P2 re-gate re-audit) · owner: Developer · re: `6H`'s hitbox never reaches a crouching hurtbox — the overhead is a free dodge, not a mixup
Problem, found while closing the proxy-test-sweep gap on B's overheads (see the resolved
flag above): character B's `6H` hitbox is authored `Box.make(x=20, y=-85, w=30, h=20)` —
world y-range **-85..-65**. A crouching defender's hurtbox (`_hurt_crouch`,
`Box.make(x=-15, y=-55, w=30, h=55)`) spans world y **-55..0**. There is a **10-unit
vertical gap between them** (`-65` to `-55`) that no horizontal spacing can close: `6H`
**geometrically cannot overlap a crouching hurtbox at any range.**

**Verified, not inferred:** drove `6H` against a defender held in `STATE_CROUCH`
(stationary, not a movement artifact) through the real engine — `6H`'s active window
(frames 23-25) passes with `move_contact` staying `NONE`, then resolves to `WHIFF` once
the active window ends. At the SAME horizontal spacing, a STANDING back-hold correctly
resolves `BLOCK` (confirmed the horizontal reach is sufficient; the failure is purely
vertical).

**Why this is a real defect, not a design choice:** `combat-resolution.md`'s own
"Directional block enforcement (AD-045)" section states the general rule in these exact
words: *"HIGH (overhead) must be blocked **standing** (**hits** a crouching back-hold)."*
The engine mechanism for this (guard_height vs. is_crouch, phase-5 resolution) is generic
and correct — verified working for both A's grounded lows and B's H-divekick (which DOES
correctly hit a crouching defender, since its hitbox tracks B's falling position rather
than a fixed high offset). `6H`'s hitbox is simply authored too high to ever reach the
case the spec describes. The practical consequence: **a defender who simply holds crouch
permanently takes zero risk from `6H`** — it isn't "wrong stance gets punished," it's "the
attack never arrives." This undermines exactly the high/low guess `character-b.md` B-4
is about for `6H` specifically (the H-divekick, B's OTHER overhead, is unaffected and
correctly enforces both stances — verified in the same session).

**Likely fix shape (Developer's to determine):** lower the hitbox's `y` (and/or increase
`h`) so it overlaps `_hurt_crouch`'s `-55..0` range while still landing in the "over a low
poke" head/shoulder area against a standing hurtbox — a geometry/tuning fix, not a spec or
engine change. Re-verify against `test_character_b.gd::_test_6h_is_reachable_and_not_
shadowed_by_5h` (guard_height=HIGH stays authored) and add the dynamic crouch-connect case
to `game/tests/test_qa_p2_regate_overhead_enforcement.gd` (a placeholder for exactly this
assertion is described but deliberately not committed red — see that file's header) once
fixed, so the fix and its regression net land together.
---
Resolution (owner fills): …
