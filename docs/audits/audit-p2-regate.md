# Audit — P2 Re-gate (post fix-cycle, behavioural re-proof)

> QA audit report. Owner: QA. Routed findings live in `docs/flags.md`.
> Date: 2026-07-17. Auditor: QA (FoggyGlass).
>
> Scope: the five re-gate fixes (air-normal landing, AD-046 air-action gate,
> sudden-death MATCH_END, AD-050 divekick landing, the reaction-identity
> readout) verified **behaviourally**, not structurally; the content-seam
> thesis re-proved via real asymmetric A-vs-B/B-vs-A play; the proxy-test
> sweep (QA's own open flag); determinism/serialization at the new state
> shapes. Audited against `docs/spec/combat-resolution.md`,
> `docs/spec/character-b.md`, `docs/spec/match-flow.md`,
> `docs/spec/inspection-surface.md`, `docs/spec/decisions.md` (AD-046,
> AD-049, AD-050), `docs/technical-tenets.md`, `docs/audit-criterion.md`
> (specifically "Exercise the thing, not a proxy for it").
>
> **Standard applied:** behavioural, per the dispatch. My first P2 audit
> passed via a structural grep that was true but blind to implicit coupling
> (AD-049) and to content never revisited after a mechanism changed
> underneath it (AD-043's air-normal duration). This audit does not repeat
> that shape: every claim below is either driven through `SimState.step`/
> `MatchState.match_step` by me and observed, or explicitly named as
> unverifiable headlessly and routed to the human gate.

---

## Bottom line

**Objective re-audit: PASS on all five re-gate fixes, behaviourally
verified.** The content-seam thesis is **RE-PROVEN** — see below; I recommend
the Strategist restore the "content-seam proven" roadmap claim. Determinism
and serialization hold at every new state shape I could identify, including
cases the existing suite didn't cover (added this session). The proxy-test
sweep found the exact failure shape the flag predicted, in exactly three
places, one of which — pursued to a real engine drive rather than left as a
grep — surfaced a **new, genuine, previously-undetected defect** on B's `6H`
overhead (filed as a new Developer flag). Full suite: **47/47 green**
(45 pre-existing/updated files + 2 new QA files), including the golden-file
net which I found stale (2/3 mismatched against six ratified fixes) and
re-baselined deliberately this session, line-by-line attributed against the
judgment log before doing so.

**This PASS is necessary but not sufficient.** The P2 human-inspection gate
reopens after this audit. I am **not** issuing a "done" verdict — see
"Human-inspection gate" at the end.

---

## 1. The five re-gate fixes — behavioural verification

For each: what I drove through the real engine myself (not a re-read of the
Developer's resolution note), and — for the fixes framed as "false-greens"
(claims my first audit passed while broken) — whether the new regression
test **actually fails against the pre-fix production code**, checked by
building a `git worktree` at each fix's parent commit and running the new
test file against the old code.

### 1a. Air normals carry the fall to real landing (`combat-resolution.md` criterion 15; commit `7c6c14a`)

**PASS.** Read `_build_air_normal` in both `character_a.gd`/`character_b.gd`:
now authors a generous safety-tail `duration` + a tail keyframe supplying
only the airborne hurtbox, so the AD-043 continuous ground clamp — not the
move's own short `duration` — is what ends the state. Ran the new
`test_airborne_physics.gd::_test_velocity_persists_across_airborne_state_
transition` (rewritten this fix): drives a jump-cancelled-into-air-normal all
the way to landing and requires it land on the **exact same physical tick**
an uninterrupted jump does. Passes on current code (30/30 checks).

**Fails-on-old confirmed.** Built a worktree at `41d32ac` (the fix's parent),
copied the new test file in, ran it against the pre-fix `character_a.gd`:

```
FAIL: cancelling into j.L ... lands on the EXACT SAME physical tick as an
      uninterrupted jump ...  (got 25, expected 43)
```

The pre-fix code lands 18 ticks early — the exact "snaps to the floor"
defect. This is not a re-read of the Developer's note; I reproduced the
failure myself against the actual old commit.

### 1b. A has neither air dash nor double jump, data-gated (AD-046; commit `999ddfe`)

**PASS.** Read `StepPhases._apply_air_action`: each branch (double jump, air
dash) now gates the velocity-set and `air_action_used` consumption on
`double_jump_velocity != 0` / `air_dash_speed != 0` respectively; a gated-out
branch touches nothing and falls through. Character A authors neither field
(both default `0`). Ran the new tests in `test_dash_air_action.gd`: drives
A's real, unmodified physics through the exact double-tap/up-edge gestures
and confirms `vel_x`/`vel_y` follow nothing but natural jump-arc gravity,
`air_action_used` never consumed.

**Fails-on-old confirmed.** Worktree at `7c6c14a`, new test file copied in:

```
FAIL: A's vertical velocity follows ONLY its natural jump-arc gravity ...
      (got 65536, expected -589824)
FAIL: A's air_action_used is never consumed ...  (got true, expected false)
FAIL: A's double_jump_velocity==0 ... A keeps falling on its OWN ongoing
      jump-arc trajectory ...  (got 65536, expected -720896)
```

Confirmed: on the pre-fix commit, A's jump arc gets stomped by an
unauthored air action exactly as the flag reported.

### 1c. Sudden death reaches MATCH_END (`match-flow.md` criteria 1–8; commit `82fb2a4`)

**PASS.** Read `MatchState._step_round_end`: now compares the two
`round_wins` counts to **each other**, not each independently to the fixed
threshold — equal-and-at-threshold is a tie (sudden death), unequal is
decisive (`MATCH_END`). Ran the new
`_test_sudden_death_round_resolves_to_match_end_on_outright_win`: drives a
full match through an entire real sudden-death cycle (`ROUND_START` →
`ACTIVE` → `ROUND_END` → `ROUND_START` → `ACTIVE` → `ROUND_END` →
`MATCH_END`), observing an actual `MATCH_END`.

**Fails-on-old confirmed.** Worktree at `999ddfe`, new test copied in:

```
FAIL: an outright single-winner sudden-death round actually reaches
      MATCH_END, not another sudden-death round  (got 0, expected 3)
```

`0` is `PHASE_ACTIVE` — the pre-fix code re-entered sudden death forever, as
the flag described.

### 1d. Divekick landing recovery, height-dependent block advantage (AD-050; criterion 18, B-7; commit `0179ade`)

**PASS.** Read `StepPhases._land`'s new precedence (launched-knockdown →
`landing_state_id` → idle) and `character_b.gd`'s three landing-recovery
states (`STATE_DIVEKICK_{L,M,H}_LANDING`, `duration == that divekick's own
blockstun`, per JC-106). Ran `_test_divekick_reachable_in_air_and_lands_into_
recovery` and the new `_test_divekick_height_dependent_block_advantage_b7`:
drives the M divekick to contact at two different injected heights, drives
**both sides to actual `Actionability.is_actionable`** (not a single
mid-air advantage snapshot — per AD-050's own `frames_to_actionable` scope
note), and confirms low-height block ≈ neutral (gap ≤ 3 ticks) and
high-height block meaningfully more minus (gap ≥ low + 5 ticks). Both hold
on the current build.

**Fails-on-old confirmed** (parse-level, the strongest possible signal): a
worktree at `82fb2a4` (pre-AD-050) with the new `test_character_b_air.gd`
copied in fails to even *load* — `Cannot find member "STATE_DIVEKICK_L_
LANDING"`, `"DIVEKICK_L_BLOCKSTUN"` etc. — because the mechanic and its
symbols didn't exist yet. The new tests are unambiguously load-bearing for
this feature; they cannot pass by accident.

### 1e. Reaction-identity readout (`inspection-surface.md` `PlayerView.reaction_kind`; commit `2d88625`)

**PASS — and this is the headline gate defect, so I gave it the most
scrutiny.** Read `PlayerView.reaction_kind`: a derived field, reverse-resolved
each `_init` from the current `state_id` through the roster character's own
`reaction_map` (the same map AD-049's forward `reaction_state(kind)` reads).
Read `LiveStatePanelModel.identity_name()`: leads each row with the specific
word (knockdown/launch/air reset/hitstun/blockstun/crouch blockstun),
`category_name()` kept alongside (`cat:%s`), never dropped. Ran the new
`test_live_state_panel.gd` tests: drives A's real `STATE_HITSTUN`/
`STATE_HITSTUN_LAUNCH`/`STATE_AIR_RESET`/`STATE_KNOCKDOWN` through the real
readout path and asserts the four rendered lines are distinct and each
contains its correct word.

**Fails-on-old confirmed.** Worktree at `0179ade` (pre-fix), new
`test_live_state_panel.gd` copied in:

```
FAIL: state 125 renders the word 'launch' in the readout
      (got: ... state 125 (hitstun) ...)
FAIL: state 122 renders the word 'air reset' in the readout
      (got: ... state 122 (hitstun) ...)
FAIL: state 123 renders the word 'knockdown' in the readout
      (got: ... state 123 (hitstun) ...)
```

Exactly the collapse the gate-holder hit: all three render as the bare word
"hitstun." Confirmed the fix genuinely resolves it on current code.

### 1f. Display/tuning items (facing surfaced, HUD text overflow, throw hitbox, per-strength slides, JC-095 numbers)

Objectively checkable halves verified: `facing` now reads through
`LiveStatePanelModel` (`test_live_state_panel.gd`); HUD text measured via
real `Font.get_multiline_string_size` against realistic worst-case content,
not `Control.rect` boxes (`test_hud_layout.gd` — I confirmed this test fails
against the pre-fix `.tscn` per JC-110's own note, and separately confirmed
its methodology is sound: it measures rendered glyph extents, not proxy
geometry); throw hitbox retune covered by new down-back-crouch throw-connect
tests for both characters; slide L/M/H sibling states verified distinct with
correctly varying distance (and independently covered by my own new
determinism round-trip tests, below, since the existing suite only ever
round-tripped the unchanged M state). **Rendered legibility on an actual
screen** (does the HUD read as clear to a human, does the facing readout
register at a glance) is explicitly **not** something I can confirm headless
— routed to the human gate per the checklist below.

---

## 2. Content-seam thesis — RE-PROVEN, recommend restoring the roadmap claim

**Verdict: restore "content-seam proven."** The prior claim rested on a
structural grep (zero character-specific branches) that was true but blind
to the AD-049 coupling — a real defect that passed it. This cycle's fix adds
exactly what the criterion demands: **`game/tests/test_reaction_map.gd`**,
which is the real proof, not a rerun of the old one.

What it actually does (I read the full file and ran it):

- **Real A-vs-B and B-vs-A contact, in both directions, for every reaction
  kind that gets inflicted**: hitstun, blockstun, crouch blockstun (A's `2L`
  vs. B's `2L`, each direction), launch-lands-into-own-knockdown (A's `DP_L`
  vs. B's `2H`, each direction), the explicit `AIR_RESET` case (A's `2H` →
  B, the exact content hole AD-049 closed — B never inflicts this kind
  itself, so it's a receive-only proof), and throw-into-knockdown (both
  directions).
- **Disjoint id ranges are load-bearing, not decorative**: A's states run
  100s–160s, B's 300s+, deliberately chosen so a namespace-crossing bug
  cannot coincidentally resolve, unlike a mirror matchup.
- **Every tick of every reaction, `PlayerView.boxes` is asserted non-empty**
  — this is the literal regression net for the box-vanish gate defect
  (a wedged, boxless, unhittable, un-actionable defender).
- **Recovery is asserted through `Actionability.is_actionable`, driven by
  real ticks, no round reset** — proves the defender actually comes back,
  not just that it enters the right state once.
- I independently re-ran the structural grep (`game/sim/*.gd` for
  `CharacterA`/`CharacterB`/`character_a`/`character_b`): still **zero**
  character-specific branches, both hits documentation comments. So the
  format-generality claim now has **both** halves the criterion requires:
  structural absence of coupling **and** behavioural proof the two
  characters actually interoperate through the shared path — a mirror
  matchup, per the file's own header, "cannot prove this fix," and this
  suite never uses one for these cases.

Ran it myself: **521/521 checks pass** (the one printed `ERROR:` line is the
deliberately-rejected duplicate-`data_id` negative-path test, exit code 0
confirms it's expected, not a failure).

**What would have failed this check** (per audit-criterion.md's "it could
fail" bar): any reaction kind resolved against the attacker's own roster
instead of the defender's; any character missing a required reaction-map
entry; any mixed-up id crossing the A/100s ↔ B/300s boundary; a defender
left boxless/unhittable past a hit. All of these are exactly the shape of
the actual AD-049 defect the gate found, so this is not a check that merely
restates the fix — it is built to fail on the specific historical defect and
would fail on any structurally similar future one.

---

## 3. Proxy-test sweep (QA's own flag, `docs/flags.md`) — resolved

Full method, count, and worst offenders are recorded in the flag resolution
(`docs/flags.md`, "re: test_character_b_air.gd and the shape of our tests");
summarized here because it's load-bearing for this report.

**Method:** every `hb.<field> ==` / `.guard_height ==` assertion across all
46 pre-existing test files, checked function-by-function for a
`SimState.step`/`MatchState.match_step` call in the same function (automated
scan), then manually cross-checked each hit against whether a real dynamic
test exists **anywhere else** in the suite proving the same claim.

**Count: ~8 functions carry the tautology shape.**

- **3 worst offenders — zero real backup anywhere in the suite:**
  1. `test_character_b_air.gd::_test_slide_is_a_low_hard_knockdown` — the
     flag's own cited example. **Still present, unresolved.** No test
     anywhere drives the slide to a real on-hit connect and observes
     `STATE_KNOCKDOWN` (only the block path is dynamically proven).
  2. `test_character_b_air.gd::_test_divekick_h_is_the_only_overhead` —
     `test_guard_height.gd` never references `CharacterB` at all. **Closed
     this session** (new file, below).
  3. `test_character_b.gd::_test_6h_is_reachable_and_not_shadowed_by_5h`'s
     `guard_height` tail — same shape. **Closing it surfaced a genuine
     defect** (below).
- **~5 are the same textual shape but honestly redundant** — each paired
  with a real dynamic test proving the same claim (A's `2H`→`AIR_RESET`
  backed by `test_reaction_map.gd`; A's `2L`/`2M` "authored LOW" checks each
  immediately followed by their own file's dynamic companion; the divekick
  hang-duration ordering backed by a dynamic measurement in the same
  function). Not dangerous, not touched.
- **1 partial gap**: the slide's `guard_height=LOW` is proven dynamically
  for the crouch-blocks-correctly half, not for the standing-back-hold-gets-
  hit half. Noted, not fixed (lower priority than the three above).

**How much of the green suite is load-bearing: most of it, but not evenly.**
`test_reaction_map.gd`'s criterion-16 tests, the determinism/round-trip net,
and the bulk of the character test files genuinely drive `SimState.step`.
The tautology shape clustered exactly on **B's three highest-stakes mixup
claims** — the slide's knockdown and both of its named overheads — and the
one place I closed the gap with a real drive, it caught a live defect on the
first try. That is the finding, not the raw count: **the failure mode isn't
randomly distributed risk, it's concentrated on the moves the charter's
no-knowledge-checks principle cares most about.**

**New finding from closing the gap — filed as a new Developer flag
(`docs/flags.md`, "re: `6H`'s hitbox never reaches a crouching hurtbox"):**
character B's `6H` hitbox (`y=-85, h=20` → world y **-85..-65**) never
overlaps a crouching hurtbox (`y=-55, h=55` → world y **-55..0** — a 10-unit
gap) at **any** horizontal spacing. Verified against a **stationary**
crouching defender (not a movement artifact): `6H`'s active window passes
with `move_contact` staying `NONE`, resolving to `WHIFF`. At the identical
spacing, a standing back-hold correctly `BLOCK`s. `combat-resolution.md`'s
own text: *"HIGH (overhead) must be blocked standing (**hits** a crouching
back-hold)"* — 6H instead whiffs outright. **Consequence: a defender who
holds crouch permanently takes zero risk from `6H`** — not "wrong stance
gets hit," but "the attack never arrives." This directly undermines the
high/low guess `character-b.md` B-4 is about, for `6H` specifically (the
H-divekick, B's other overhead, is unaffected — verified both ways). This is
a content/geometry defect, not a spec or engine problem; routed to the
Developer with full repro and a likely-fix pointer.

**New QA test files this session** (test tooling, not production code):
`game/tests/test_qa_p2_regate_overhead_enforcement.gd` — drives `6H` and the
H-divekick through the real engine against standing (must block) and
crouching (must hit) back-holds, plus a negative control (`5L` still blocks
crouching, isolating the `6H` failure to `guard_height` specifically, not a
broken crouch-block in general). **Does not assert the currently-broken
6H-vs-crouch case** — per this project's own convention, a red assertion
isn't committed to the green suite; the fix commit adds the permanent
regression.

---

## 4. Determinism / serialization — hard gate, held

Existing coverage (verified, not just re-read): mid-divekick-flight,
mid-slide-active (the unchanged M state), full-match round-trip with a KO +
timeout.

**Gaps I found and closed this session**
(`game/tests/test_qa_p2_regate_determinism.gd`, 201/201 checks pass):

| Case | Why the existing suite missed it | Result |
|---|---|---|
| Mid-active `STATE_SLIDE_L` / `STATE_SLIDE_H` | The existing round-trip test only ever drove the unchanged `STATE_SLIDE` (M); L/H are JC-112's new sibling states | PASS — snapshot restores to identical hash, both copies settle identically for 20 more ticks |
| Mid-divekick-**landing-recovery** (`STATE_DIVEKICK_M_LANDING`) | This state shape (AD-050's `landing_state_id` redirect) didn't exist before this cycle | PASS — driven to real entry via jump+divekick+landing, then round-tripped |
| Mid-stun `STATE_AIR_RESET` | B's own catch-up reaction (AD-049), never previously round-tripped | PASS |
| A `MatchState` snapshot taken **inside a live sudden-death round**, restored, and driven independently through to `MATCH_END` | The existing full-match golden/determinism proofs use a KO+timeout script that never enters sudden death — this is the exact path AD-048's fix made reachable, never round-tripped | PASS — per-tick hash comparison holds through the entire resolution, both copies reach `MATCH_END` |

No wall-clock/`_process`/unseeded-RNG dependence found anywhere touched this
session (all new/re-verified paths route through the existing fixed-tick
`step`/`match_step`).

**Golden-file net:** found **stale at audit start** — 2/3 mismatched
(character A's movement trace, character B's frame-data dump) against six
ratified fixes that landed since the last baseline (AD-043's air-normal
safety tail, JC-115's `6H` creep, JC-112's slide siblings, JC-111's throw
retune, AD-050's divekick states). Also found `test_golden_regression.gd`
was **never wired into `run_tests.bat`**, so this drift was invisible to
every prior "N/N green" run, including the Developer's own session reports
this cycle. Reviewed every diff line against its corresponding ratified
judgment-log/decisions.md entry before re-baselining (all attributable, none
unexplained) and added the file to `run_tests.bat` so this can't recur
unnoticed.

---

## 5. Full test-suite status

**47/47 green** — the pre-existing 44 (per `run_tests.bat`) + `test_golden_
regression.gd` (existed, unwired — now wired) + 2 new QA files this session.
Ran every file myself via direct Godot invocation (`--headless --path game -s
res://tests/<name>.gd`), reading exit codes, not trusting printed summaries
alone. `test_serialization_version.gd`'s and `test_reaction_map.gd`'s
printed `ERROR:` lines are their own deliberately-rejected negative-path
probes (format-version v99, duplicate `data_id`) — expected, exit 0 confirms
it.

**`test_trace_harness.gd` still prints two `[TraceHarness] assert FAIL`
lines on a passing run** (exit 0, 69/69 checks) — the pre-existing,
already-flagged (Strategist → Developer) negative-path-labeling issue.
Confirmed still present; not mine to fix, noted per the dispatch.

---

## 6. Judgment-log check (JC-106..115)

Read all ten provisional-turned-ratified entries against the current code:
JC-106 (per-strength divekick landing states, not shared) — confirmed three
distinct states with distinct `duration`s matching each divekick's own
`blockstun`. JC-107 (B-7 test methodology, direct `pos_y` injection) —
confirmed the technique and re-derived the reasoning holds. JC-108
(`reaction_kind` field design) — confirmed matches `PlayerView.reaction_kind`
exactly. JC-109 (facing in `LiveStatePanelModel`) — confirmed. JC-110 (HUD
real-measurement layout) — confirmed, and confirmed the claim that it fails
against the pre-fix `.tscn` is consistent with `test_hud_layout.gd`'s own
methodology (real font measurement, not `Control.rect`). JC-111 (throw
hitbox retune) — confirmed geometry and the new down-back-crouch throw test.
JC-112–115 (slide siblings, arc L/H retune + the `_arc_params()` dedup fix,
divekick L/M `dive_vx` floor, `6H` creep) — confirmed each against
`character_b.gd` directly and the golden-file re-baseline (section 4). No
drift found against any ratified entry.

---

## 7. Findings routed

| Finding | Owner | Where |
|---|---|---|
| `6H` hitbox never reaches a crouching hurtbox — free dodge of B's dedicated overhead | Developer | `docs/flags.md`, new entry |
| Proxy-test sweep: slide-knockdown tautology (flag's own cited example) still open | Developer (follow-up) | `docs/flags.md`, resolution note on QA's own flag |
| Slide's `guard_height=LOW` standing-back-hold-gets-hit half never dynamically proven | Developer (follow-up, lower priority) | `docs/flags.md`, resolution note |
| `test_trace_harness.gd` misleading `assert FAIL` output on a passing run | Developer (already flagged by Strategist) | `docs/flags.md`, pre-existing entry — confirmed still present, not re-filed |
| Golden-file net was stale + unwired from `run_tests.bat` | QA (fixed this session) | re-baselined; wired in |

No spec gaps, no charter problems, no audit-criterion problems found this
session.

---

## 8. Human-inspection gate — EXPLICIT OPEN ITEM (not mine to close)

Per `docs/audit-criterion.md`'s human-inspection-gate rule and the P2 gate's
own history (this is a **re**-gate specifically because the first pass found
defects a headless suite couldn't see), the following remain open and
require the user driving `game/scenes/training_mode.tscn` directly. This is
a checklist, not a re-statement of section 1 — each line is something only a
human eye/hand can confirm:

1. **Reaction-identity readout legible at a glance.** The fix (1e) makes the
   readout say "knockdown"/"launch"/"air reset" instead of a collapsed
   "hitstun" — confirm it's actually readable in the corner of your eye
   during play, not just present in the string.
2. **Air normals visually read as carrying the fall** (1a) — does the
   character's sprite/position look like a continuous fall to a real
   landing, not a snap, at normal play speed.
3. **A's air genuinely feels dash/double-jump-less** (1b) — confirm no
   residual visual hitch on A's jump arc from the old gated-out code path.
4. **Sudden death's flow is legible on screen** (1c) — does the match
   actually *look* like it ended when `MATCH_END` fires; is a sudden-death
   round distinguishable on screen from a normal one.
5. **Divekick height-dependent advantage is visible, not just computed**
   (1d, B-7) — can you *see* that hitting high leaves B punishable and
   hitting low doesn't, from the geometry overlay + advantage readout,
   without reading raw numbers.
6. **B-3's pose distinguishability** (the three divekicks look different in
   the air) — still open from the first P2 audit, unchanged by this cycle.
7. **B-5's facing/crossup discoverability** — now surfaced in
   `LiveStatePanel` (JC-109); confirm it reads clearly post-crossup, without
   being a callout/answer-key.
8. **HUD layout at target resolution** — confirm the re-measured layout
   (JC-110) has no visual overlap a human eye catches that the font-metric
   test didn't model (e.g., a genuinely worst-case input history burst).
9. **`6H`'s crouch-whiff, once fixed** — after the Developer's fix lands,
   confirm on screen that `6H` now visibly connects against a crouching
   opponent (not just a headless PASS) — this is exactly the kind of fix
   that could look "fixed" in a box-overlap sense while still reading wrong
   on screen (per audit-criterion.md's own honesty bar).

**Green headless tests do not substitute for this list.** I am **not**
issuing a "done" verdict for the P2 re-gate. The gate reopens after this
audit; only the user, having played it, closes it.

---

## 9. Approximate token spend

This session ran ~140K tokens of tool-call/context volume (reading specs,
running the full suite multiple times, three `git worktree` fail-on-old
probes, several geometry-debugging probe scripts for the `6H` finding, and
writing ~800 lines of new test code + this report). Rough order of
magnitude; not separately instrumented.

---

## Summary table

| Area | Verdict |
|---|---|
| 1a. Air normals carry the fall (criterion 15) | **PASS** — behavioural + fails-on-old confirmed |
| 1b. A has neither air action, data-gated (AD-046) | **PASS** — behavioural + fails-on-old confirmed |
| 1c. Sudden death reaches MATCH_END (criteria 1–8) | **PASS** — behavioural + fails-on-old confirmed |
| 1d. Divekick landing recovery, B-7 (AD-050) | **PASS** — behavioural + fails-on-old confirmed (load error) |
| 1e. Reaction-identity readout | **PASS** — behavioural + fails-on-old confirmed |
| 1f. Display/tuning items (facing, HUD, throw box, slides) | **PASS** on the objective half; on-screen legibility → human gate |
| Content-seam thesis | **RE-PROVEN** — recommend restoring the roadmap claim |
| Proxy-test sweep | Resolved: ~8 instances found, 3 worst offenders (1 still open, 2 closed), 1 new real defect (`6H`) surfaced and flagged |
| Determinism/serialization | **PASS**, including 4 new round-trip cases the suite didn't cover |
| Full suite | **47/47 green** |
| Golden-file net | Found stale, re-baselined deliberately, wired into `run_tests.bat` |
| Human-inspection gate | **OPEN — explicit, not closed by this audit** |

**Objective re-audit: PASS. Overall P2 re-gate status: NOT DONE — the
human-inspection gate stands open and only the user closes it.**
