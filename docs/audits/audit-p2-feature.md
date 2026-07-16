# Audit — P2 (Character B + 1v1 Match + AD-036 remainder)

> QA audit report. Owner: QA. Routed findings live in `docs/flags.md`.
> Date: 2026-07-16. Auditor: QA (FoggyGlass).
>
> Scope: character B (`game/content/character_b.gd`, `game/data/character-b.tres`),
> the match layer (`game/sim/sim_state.gd`'s match wrapper: `MatchState`/
> `match_step`/`MatchView`/`MatchTickHost`), the AD-036 remainder (airborne
> physics: `game/sim/step_phases.gd` phase 3 + `air_action`/knockdown), and the
> cross-cutting P2 done-conditions (cross-system consistency, golden-file net).
>
> Audited against: `docs/spec/character-b.md` (criteria 1–6, B-1..B-6),
> `docs/spec/match-flow.md` (criteria 1–8), `docs/spec/move-format.md`,
> `docs/spec/combat-resolution.md`, `docs/spec/inspection-surface.md`,
> `docs/technical-tenets.md`, `docs/audit-criterion.md`, `docs/roadmap.md` → P2.
>
> Entering state: `docs/flags.md` has one entry, already
> `[resolved-awaiting-relay]` (the AD-044 exact-self-repeat `CancelEval` fix —
> confirmed landed, see below). All P2 judgment-log entries (JC-068..099) are
> ratified and archived (`docs/judgment-log-archive.md`); the live
> `docs/judgment-log.md` is empty. No provisional calls outstanding.

---

## Bottom line

**Objective audit: PASS.** Every P2 acceptance criterion I can verify headlessly
holds against the actual code and a real, executed test run (I ran Godot
myself, not a static read). Determinism/serialization hold across a full
match, including mid-match snapshot/restore/resume. Cross-system consistency
(one move format, one advantage computation, no character-specific branch) is
verified by direct grep of the sim layer, not inference. The golden-file
regression net (a P2 done-condition, QA-owned) was **not yet seeded** at audit
start — I built and seeded it this session (below). No implementation defects
found; no spec gaps found; no drift found across any ratified P2 judgment-log
entry.

**This PASS is necessary but not sufficient.** Per the roadmap and
`audit-criterion.md`, **P2 carries a human-inspection gate** covering B's
mixup readability, the divekick/crossup/slide legibility, and the match
result's on-screen legibility — none of which a headless run can confirm.
**That gate is OPEN and this audit does not and cannot close it.** See "Human-
inspection gate" at the end — recorded as an explicit open item. **No "done"
verdict is issued.**

---

## Test run (real execution)

Ran all 43 files in `game/tests/` individually against
`Godot_v4.3-stable_win64.exe --headless --path game -s res://tests/<name>.gd`,
reading each exit code and printed summary myself.

**43/43 runnable test files green** (`test_support.gd` is a non-runnable
helper class, not a test — expected, matches the existing convention).
Included in that count: the new `test_golden_regression.gd` I added this
session (below). Representative counts for the P2-relevant files:

| File | Result |
|---|---|
| test_airborne_physics | OK — 26 checks |
| test_airborne_actions | OK — 51 checks |
| test_dash_air_action | OK — 36 checks |
| test_cancel_groups | OK — 8 checks |
| test_guard_height | OK — 31 checks |
| test_arc_projectile | OK — 27 checks |
| test_character_b | OK — 110 checks |
| test_character_b_air | OK — 113 checks |
| test_match_state | OK — 71 checks |
| test_match_tick_host | OK — 130 checks |
| test_match_panel | OK — 29 checks |
| test_serialization_version | OK — 21 checks |
| test_golden_regression (new, this session) | OK — 3 checks |

`test_serialization_version.gd` prints an expected `ERROR:` line (a
deliberately-rejected v99 format-version probe) — that is the test exercising
the rejection path, not a failure; exit code 0 confirms it.

---

## character-b.md — criteria 1–6, B-1..B-6

1. **Authored purely in data — PASS.** `_test_authored_as_data`/
   `_test_authored_as_data_air` confirm; `CharacterB.build_character()` is
   `MoveState`/`Keyframe`/`HitBox`/`CancelRule`-shaped data, no new engine
   primitive. I independently grepped `game/sim/*.gd` (the engine layer) for
   `CharacterA`/`CharacterB`/`character_a`/`character_b` — **zero hits**
   outside two comments (`air_height_scaling.gd`, `step_phases.gd`, both
   citing character A only as a documentation example, no branch). B's whole
   kit resolves through the same engine code A does.
2. **Gatling ladder resolves exactly (AD-044) — PASS.** `test_character_b.gd`
   drives the brief's own worked example, `5L 2L 2L 5M 2M 2H 5H`, end to end
   through the real engine; every step fires including the exact-self-repeat
   step (`2L→2L`), confirming the AD-044 `CancelEval` fix (below) is live, not
   just ratified on paper. `5M→5M` and `5M→5L` are both confirmed rejected.
3. **One air action (AD-046) — PASS.** `_test_2h_jump_cancel_into_airdash`
   and `test_dash_air_action.gd` confirm air dash/double jump each spend
   `air_action_used`, the second is suppressed until landing, and the
   divekick spends neither.
4. **Airborne carry (AD-043) — PASS.** `_test_air_normals_carry_the_fall`
   confirms `j.L`'s `vel_y` is the prior velocity plus one more tick of
   gravity (inherited, not reset); the slide's hard knockdown routes directly
   into `STATE_KNOCKDOWN` (confirmed by hitbox `hit_reaction` inspection).
5. **B-1 (low-slide spacing-variable advantage, instrument-readable) — PASS.**
   `_test_slide_spacing_variable_advantage_is_instrument_readable` connects
   the same slide at two different spacings, gets contact on two genuinely
   different active frames, and confirms the live advantage differs and is
   **formula-correctly ordered** (later active-frame contact → less attacker
   recovery remaining → higher/better live advantage, per AD-008) — not just
   "different," but different in the right direction.
6. **B-2 (arc-projectile falls-in-front oki, never unblockable) — PASS.** Two
   layers both verified: **by construction** — all three arc strengths are
   `guard_height = MID` (blockable either stance) and B authors no untechable
   throw, so an opposite-`guard_height` or block-vs-untechable-throw conflict
   is structurally impossible (`_test_arc_projectiles_are_guard_mid_by_construction`);
   **and dynamically** — `_test_arc_and_strike_never_require_incompatible_defense`
   drives a live projectile contact and a real `2L` strike against the *same
   held stance*, no switch in between, both resolve BLOCKED. I additionally
   confirm the *standing condition* AD-047/JC-093 flags (this proof holds only
   while all three arc strengths stay MID and B authors no untechable throw)
   — both premises verified true in the current build (spot-checked
   `character_b.gd`'s throw authoring: standard tech-window throw, no
   untechable variant).
7. **B-3 (three divekicks distinguishable in the air) — PASS (headless
   half).** Hang durations strictly increase L<M<H (both the authored
   constants and a dynamic measurement through the real engine); dive vectors
   are pairwise distinct; H is confirmed the sole `guard_height = HIGH`
   version. The **visual** distinguishability (pose) is explicitly a
   human-gate item per the spec itself — not claimed here.
8. **B-4 (reaction-window floor mechanism) — PASS on the mechanism; the
   number is NOT a defect.** `_test_h_divekick_reaction_window_floor_placeholder`
   confirms H-divekick's entry-to-active delay (17 ticks, both by arithmetic
   over the authored hang+impulse and by driving the real engine) exceeds the
   **placeholder** floor (12). Per the task's explicit instruction, I audited
   the *invariant* (the delay is measurable and route-independent — one
   measurement bounds every entry sequence, since all routes converge on the
   same authored state) and did **not** treat the 12-vs-17 placeholder tuning
   as a finding. Both numbers settle at the human gate, per spec.
9. **B-5 (air-dash crossup side readable) — correctly NOT headless-tested; a
   human-gate item.** The spec itself scopes this to the human gate
   (`character-b.md`: "Human-gate item"). No headless test claims it; none
   should. Confirmed via grep — no test file references "crossup."
10. **B-6 (`5H` whiff punishable) — PASS.** `_test_5h_whiff_is_severely_punishable_vs_block_cancels_early`
    confirms a clean whiff leaves B uncancelled through the full 30f duration
    (no `on_whiff` escape authored) while a blocked `5H` cancels into `2H`
    well before that duration elapses — the effective-recovery gap the spec's
    JC-083 interpretation describes, verified dynamically, not asserted.

**character-b.md verdict: PASS on every headlessly-checkable criterion.**
B-3 (visual pose) and B-5 (crossup side) are correctly deferred to the human
gate by the spec's own scope, not gaps in this audit.

---

## match-flow.md — criteria 1–8

1. **Deterministic per match — PASS.**
   `_test_full_match_determinism_round_trip` (`test_match_state.gd`) runs a
   fixed ≥2-round script (a KO ending round 1, a timeout ending round 2,
   `MATCH_END`), serializes mid-round-1, restores, resumes the *same* script,
   and confirms the final `MatchState` hash matches the uninterrupted run
   exactly. This is the real per-match proof, not a single-tick stand-in.
2. **`step` untouched — PASS.** Every `match_step` call site passes
   `(sim, in_p1, in_p2)` unchanged; combat determinism tests (`test_sim_state`,
   `test_combat`, etc.) are unaffected by the match wrapper's existence.
3. **KO resolution — PASS.** `_test_ko_ends_round`/`_test_double_ko_awards_both`
   confirm `REASON_KO` + single-award, and simultaneous zero-health →
   `REASON_DOUBLE_KO` + both-awarded.
4. **Timeout resolution — PASS.** `_test_timeout_higher_health_wins`/
   `_test_timeout_equal_health_ties` confirm both branches.
5. **Scoring + match end — PASS.** `_test_match_end_on_threshold` (clean 2-0)
   and `_test_sudden_death_on_simultaneous_threshold` (a simultaneous
   double-KO at match point → one sudden-death round, not `MATCH_END`) both
   pass.
6. **Legibility (`MatchView`) — PASS.** `_test_match_view_legibility` confirms
   health/round_wins/phase/`last_round_end_reason` are all exposed as
   serialized truth (not a render inference) — `inspection-surface.md`
   criterion 7 is the same claim, also verified there.
7. **Round reset — PASS.** `_test_round_reset_matches_canonical_fresh_round`
   hash-compares a real post-KO round-2 reset against an independently-built
   canonical fresh-round `SimState` — exact hash equality, not a
   field-by-field spot check. This also exercises the JC-099 fix
   (`fresh_round_sim` resolving each side's own `idle_state_id` through
   `MoveRegistry`, not a generic `0` default) — confirmed live via
   `_test_fresh_round_resolves_real_character_idle_state`.
8. **No new combat / no float — PASS.** `_test_no_floats` walks the entire
   serialized `MatchState` dict recursively; zero float/packed-float values.

**match-flow.md verdict: PASS, all 8 criteria**, with the human-inspection
gate (health/pips/clock/result legible **on screen**) explicitly still open
per the spec's own text — not claimed closed here.

---

## Tenet 1 (determinism) — across a full match

- **Full-match round-trip** — covered above (match-flow.md criterion 1); this
  is the P2-specific extension of Tenet 1 the phase exists to prove and it
  holds with direct evidence.
- **No wall-clock / `_process` / unseeded RNG** — `round_timer` counts down on
  the fixed tick inside `match_step` (frame-counted, confirmed by reading
  `match_state.gd`'s decrement site); `MatchTickHost._physics_process` drives
  exactly one tick per call regardless of `delta` (`test_match_tick_host.gd`'s
  `_physics_process(9.999)` still advances exactly one tick — directly
  disproves any delta-scaling). `MatchState.sim.rng` reuses `SimState`'s
  existing seeded RNG; no second RNG source introduced.
- **Airborne physics (AD-043) determinism** — `test_airborne_physics.gd` (26
  checks) and the divekick/slide mid-flight round-trip tests in
  `test_character_b_air.gd` (`_test_divekick_mid_flight_round_trip`,
  `_test_slide_mid_active_round_trip`) confirm a snapshot taken **mid-gravity-
  integration** and mid-active-hitbox restores and continues identically —
  the harder case than a snapshot at a state boundary.
- **Arc-projectile gravity determinism** — `test_arc_projectile.gd`'s
  `_test_arc_projectile_serialization_round_trip` confirms a mid-arc
  projectile snapshot/restore/resume matches.

**Tenet 1 verdict: PASS, with direct evidence at the hardest cases (mid-match,
mid-divekick, mid-slide-active, mid-projectile-arc), not just state
boundaries.**

---

## Cross-system consistency (the P2 done-condition; one format, one advantage computation)

**PASS, verified structurally, not by sampling.** I grepped
`game/sim/*.gd` (the entire engine layer — `move_data.gd`, `advantage.gd`,
`step_phases.gd`, `actionability.gd`, `inspection_view.gd`, etc.) for any
reference to `CharacterA`/`CharacterB`/`character_a`/`character_b`: **zero
character-specific branches** — the two hits that exist are documentation
comments citing character A as an illustrative example, not code paths. Both
characters' frame data resolves through the single `MoveData.frame_data`
function and both characters' advantage resolves through the single
`Advantage` formula (`combat-resolution.md` AD-008) — confirmed by reading
`move_data.gd`/`advantage.gd` directly: neither file names a character id
anywhere.

I additionally built this proof into the new golden-file dumper (below): the
same `_character_frame_data_dump()` function, with no branch or
character-specific parameter beyond `(char_id, Character)`, produces both A's
and B's frame-data/geometry goldens — the content-seam proof made structural
in the test tooling itself, not just asserted in prose.

---

## Golden-file regression net (P2 done-condition, QA-owned) — seeded this session

**Status at audit start: not yet seeded** — no `goldens/` directory existed.
I built and seeded it this session as this audit's required deliverable
(roadmap P2 done-condition; ticket "Cross-cutting" section: "QA owns building
it").

**New files:**
- `game/tests/test_golden_regression.gd` — the harness (QA test tooling, not
  production code).
- `game/tests/goldens/character_a_movement.golden.txt` — a fixed
  `TraceHarness` script (walk F/B, ground dash `66`/`44`, jump neutral/back/
  forward, crouch hold; 419 ticks, exact — no playback looping) dumped
  through the one canonical scripted-input path, **with resolved box
  geometry per tick** (the hitbox/hurtbox regression half), re-baselined
  against the current AD-043 gravity model (post-JC-072).
- `game/tests/goldens/character_b_frame_data.golden.txt` — every authored B
  state's canonical derived frame data (`MoveData.frame_data`: startup/
  active/recovery/total/on_hit_adv/on_block_adv) plus, per keyframe, the
  resolved world-space box set (`MoveData.resolve_boxes`) — the same
  box-resolution path phase 4 tests for overlap. Spot-checked against
  already-passing unit-test expectations (e.g. `5L` 4/3/7, `2L` 4/3/8, `5M`
  6/3/12, `2M` 7/4/13, `5H` 7/3/20, H-divekick's 17-tick entry-to-active delay
  matching B-4's own cited measurement) — all agree.
- `game/tests/goldens/match_full.golden.txt` — the per-tick `MatchState` hash
  trace + final result summary over the same fixed ≥2-round (KO + timeout)
  script `test_match_state.gd`'s own determinism proof uses; final result
  confirmed 2-0, `TIMEOUT`-decided, matching that test's own assertions.

All three were generated by running the real engine (not hand-derived),
reviewed against already-passing test expectations for consistency, and
seeded as the deliberate first baseline (JC-017/JC-072-style — a re-baseline
is a deliberate act, never a silent one; the harness writes a `.actual.txt`
sibling on any future mismatch rather than overwriting the golden). Re-ran
`test_golden_regression.gd` after seeding: **3/3 checks pass** against the
now-checked-in fixtures.

---

## Judgment-log drift check (JC-068..099, all ratified)

Read every entry's ratified body (`docs/judgment-log-archive.md`) and spot-
checked the higher-risk ones directly against the current code:

| Entry | Claim | Verified against code |
|---|---|---|
| JC-070 (overturned) → AD-043 elaboration | Knockdown is a dedicated state, not the launched-HITSTUN state reused | Confirmed: `character.knockdown_state_id` set for both A and B; `step_phases.gd`'s landing clamp branches into it. |
| JC-088 | Landing re-arms `stun` to the knockdown state's own `duration` | Confirmed: `step_phases.gd:498`, `p.stun = knockdown_move.duration` on the landing-into-knockdown branch. |
| JC-090 | `214`/`DIR_DOWN_BACK` populate the existing motion-token table, not a new recognizer | Confirmed: no second recognizer exists; `move-format.md`'s `ButtonMapEntry.motion` row documents this as the pinned line. |
| JC-093 | All three arc strengths `GUARD_MID`; B-2 satisfied by construction with a standing condition | Confirmed both premises hold in the current build (see B-2 above). |
| JC-096 | `FULL_HEALTH` 500 | Confirmed: `MatchState.FULL_HEALTH == 500`, used by `_test_new_match_shape`. |
| JC-097 | `MatchTickHost` is its own class, not a generalized `TickHost` | Confirmed: `test_match_tick_host.gd` exercises `MatchTickHost` directly; `TickHost` unmodified (still passes its own unchanged test). |
| JC-098 | Match-mode capture/reset trimmed to documented no-ops | Confirmed in `match-flow.md`'s own text and consistent with the ticket's "not a gap" framing — not separately re-tested (correctly out of scope per the spec's own carve-out). |
| JC-099 | `fresh_round_sim` resolves `idle_state_id` through `MoveRegistry` | Confirmed live via `_test_fresh_round_resolves_real_character_idle_state`. |
| flags.md (resolved-awaiting-relay) | AD-044 exact-self-repeat `CancelEval` fix | Confirmed live: `_test_ladder_self_repeat_5l_currently_blocked`/`_2l_...` now assert the self-repeat **fires**, and the full worked-example chain test drives `5L→5L`-adjacent steps through the real engine. |

**No drift found across any of the 32 ratified P2 judgment-log entries** I
checked (either directly or by the representative sample above for the
lower-risk authoring/tuning ones, e.g. JC-081/082/084/085/086 — B's damage/
physics-reuse/back-dash-invuln/`6H`-ordering/cancel-group-split calls — which
I confirmed by reading `character_b.gd` directly and cross-checking against
the passing `test_character_b.gd`/`test_character_b_air.gd` suites).

---

## Audit criterion (`docs/audit-criterion.md`)

**Objective half — PASS.** Every information-exposure question the criterion
puts in QA's own lane (is the info exposed; correct; consistent; one formula/
format) is answered above: `HitEvent.guard_height`/`block_valid` correctly
attribute a mixup hit (`test_guard_height.gd`); the slide's spacing-variable
advantage is instrument-readable (B-1); B-2's construction is verified.

**Subjective half — surfaced, not adjudicated (correctly, per my role).** The
concentrated air/mixup interaction (`character-b.md`'s "hardest legibility
call") is exactly the kind of "is this friction cherished or tax" question the
criterion reserves for the human gate. I found no candidate that looks like
tax in the mechanism (every invariant B-2/B-3/B-4/B-6 name is either
structurally guaranteed or measured, not asserted on faith) — but whether the
*combination* reads as fun/clear "in the moment" to a human is explicitly not
mine to rule on, and I am not ruling on it. That question routes to the
human gate below, per the ticket's own routing.

---

## Findings routed

**None.** No implementation defects, no spec gaps, and no audit-criterion/
charter problems found this session. The one prior open item
(`docs/flags.md`'s AD-044 `CancelEval` fix) is confirmed **resolved and
landed** in code — it is marked `[resolved-awaiting-relay]` pending the
Strategist's routine archive sweep, which is not a QA action.

---

## Human-inspection gate — EXPLICIT OPEN ITEM (not mine to close)

Per `docs/roadmap.md` (P2), `docs/tickets/p2-char-b-match.md` ("Cross-cutting"),
and `docs/audit-criterion.md`, **P2 carries a human-inspection gate that this
audit does not and cannot close.** Recording it explicitly, as required:

- **B's mixups readable as they happen:** the `6H`/H-divekick overhead tells,
  the airdash crossup side (B-5), the slide's advantage genuinely visible on
  the instrument (not just computed correctly), no unblockable off the
  projectile oki *as a human perceives it*.
- **The three divekicks visually distinguishable** (B-3's pose half — the
  trajectory/timing half is headlessly proven above; the pose is not).
- **The match result legible on its face** (KO / TIMEOUT / DOUBLE_KO —
  serialized truth is proven above; whether a human can read it at a glance
  on screen is not).
- **JC-095's provisional tuning bundle** (divekick hang/dive profiles,
  projectile parabolas, slide numbers, and the B-4 floor: placeholder 12
  vs. measured 17) — settles at this gate, per spec. **Not audited as a
  defect here**, per the task's explicit instruction.
- **The gate's checklist** should derive from `character-b.md`'s and
  `match-flow.md`'s own enumerated surfaces (per `audit-criterion.md`'s
  "gate runs off a brief-derived checklist, not improvisation" rule) — that
  checklist is the Strategist's to attach when declaring the gate, not
  mine to author here.

**This audit issues no "done" verdict.** The objective pass above is
necessary but not sufficient; only the user, having played A vs B through
`game/scenes/training_mode.tscn`, closes this gate.

---

## Summary table

| Area | Verdict |
|---|---|
| character-b.md (criteria 1–6, B-1..B-6) | **PASS** (headlessly-checkable parts); B-3 pose / B-5 crossup correctly deferred to human gate |
| match-flow.md (criteria 1–8) | **PASS** |
| Tenet 1 (determinism, full-match + mid-gravity/mid-projectile/mid-slide) | **PASS** |
| Cross-system consistency (one format, one advantage computation) | **PASS**, verified structurally (exhaustive grep) |
| Golden-file regression net | **SEEDED this session** (was absent at audit start) — 3/3 checks green |
| Judgment-log drift (JC-068..099 + the AD-044 flag) | **No drift found** |
| Audit criterion — objective half | **PASS** |
| Audit criterion — subjective half | Surfaced to the human gate, not adjudicated |
| Human-inspection gate | **OPEN — explicit, not closed by this audit** |

**Objective audit: PASS. Overall P2 status: NOT DONE — the human-inspection
gate stands open and only the user closes it.**
