# QA Audit — P1.1 Character-A Movement Reconciliation

> Owned by **QA**. Objective pass covering TKT-P1.1R-01..05 (build through
> `c344fa0`). Verifies against `docs/spec/trace-harness.md`, AD-037/038/039
> (`docs/spec/decisions.md`), `docs/tickets/p1.1-reconciliation.md`, the
> Technical Tenets, and the audit criterion (`docs/audit-criterion.md`).
> Read alongside `docs/audits/audit-p1.1-instrument.md` (the prior P1.1
> checkpoint this extends).

## Overall objective verdict: **PASS, with the human-inspection gate
explicitly OPEN.**

Every objective, headless-checkable claim the build makes for TKT-P1.1R-01
through -05 checks out against its ticket acceptance, the spec criteria the
ticket names, and the Technical Tenets. **This objective pass is necessary,
not sufficient.** P1.1 is not "done" — the render half of the reconciliation
(are the boxes actually right-side-up on screen, is the corrected movement
actually operable and legible to a human) is by design outside what a
headless session can confirm, and per `protocol.md` / `audit-criterion.md`
only the user's live re-gate can close that. See "Human-inspection gate"
below — I am recording it open, not closing it.

## What I verified myself (did not take on faith)

- **Full headless suite, run independently.** All 31 suites in
  `run_tests.bat`'s list, executed directly against
  `C:\Users\ryans\Downloads\Godot_v4.3-stable_win64.exe --headless --path game
  -s res://tests/<name>.gd`, one at a time, exit code checked per-run (not
  just the bat file's own summary). **31/31 green**, matching the commit
  claims. I did not rely on the Developer's or Architect's "31/31 green"
  assertion — I reproduced it.
- Read the actual diffs for every P1.1R commit (`a8cb9d5`, `d752f1d`,
  `3c76ed0`, `f605dfe`, `dd4e0d2`/`400c369`) rather than trusting commit
  messages, and read the resulting source (`input_script.gd`,
  `trace_harness.gd`, `step_phases.gd`, `input_buffer.gd`,
  `content/character_a.gd`'s box constants and `button_map`) and the new test
  files (`test_trace_harness.gd`, `test_geometry_reflection.gd`,
  `test_held_input_stances.gd`, `test_airborne_actions.gd`,
  `test_command_recognition.gd`'s new cases) in full.

## Per-ticket results

### TKT-P1.1R-01 — Scripted-input trace harness — **PASS**
Verified against `trace-harness.md` acceptance criteria 1–6:
1. `InputScript.compile` is pure/total; `test_compile_is_pure` proves
   identical text → identical buffer; every malformed-token case
   (`236H`, `3P`, `0`, empty, `*3`, `6**3`, `6*0`, `6*abc`) is exercised via
   the non-asserting `is_well_formed_token` twin — genuine coverage, not
   vacuous.
2. Numpad→raw mapping and `*count`/`#`-comment handling directly asserted,
   digit-by-digit, against `InputFrame` bit constants.
3. **Source equivalence + determinism — both proven, not asserted.**
   `_test_replay_source_equivalent_to_a_raw_step_loop` drives an independent,
   hand-rolled `SimState.step` loop over the *same* compiled buffers,
   bypassing `RecordPlaybackSource` entirely, and compares state/position
   field-by-field against `TraceHarness.run`'s own rows — this is a real
   source-equivalence proof, not a restatement of the contract.
   `_test_replay_deterministic_across_repeats` re-runs the same scripts twice
   and diffs the formatted trace text. Both pass.
4. `_trace_row` reads only `InspectionView`/`PlayerView`/`AdvantageView`/
   `HitEvent`; `position`/`velocity` are already fixed-point ints in
   `PlayerView` (confirmed by reading `player_view.gd` — no float ever
   enters a row). `_test_trace_field_free_of_floats_and_sim_internals`
   checks every field's `typeof()` and round-trips the formatted dump.
5. `TraceHarness.check` fails loudly on a wrong expected value and on an
   unrecorded tick; verified via `_test_assert_runner_fails_loudly_on_wrong_expectation`.
6. Never calls `px()`/`px_rect()` — confirmed by reading the file; the class
   doc comment states the blindness honestly and the spec's framing is
   preserved (does not overclaim).

Judgment calls JC-049..053 (row encoding, GDScript-API assert host over a
text DSL, grammar edge cases, `assert`-based error mechanism, P2-default
neutral) are all ratified and correctly folded into `trace-harness.md`. No
drift found.

### TKT-P1.1R-02 — Geometry Y-fix (AD-037) — **PASS (sim-truth half only — by design)**
- Box reflection verified in `content/character_a.gd`: `_hurt_stand`
  `(-15,-80,30,80)`, `_hurt_crouch` `(-15,-55,30,55)`, `_hurt_air`
  `(-15,-75,30,75)`, `default_pushbox` `(-10,-40,20,40)` — all feet-anchored
  at `y+h=0`, extending negative-Y (up), matching AD-037's formula exactly.
- `test_geometry_reflection.gd` is genuinely non-vacuous: it asserts the
  standing hurtbox/pushbox bottom edge sits at `pos_y`, the pushbox's top
  edge is *closer* to the feet than the hurtbox's (occupies the lower
  portion), the crouch hurtbox's top edge is closer to the feet than
  standing's *and* shorter, and every grounded normal's hitbox
  (`5L/5M/5H/2L/2M/2H`) stays at or above the floor line on its first active
  frame — for both Character A and the P0 `TestSupport` character (one
  convention, slice-wide, per AD-037's "Consequence"). This is the correct
  sim-truth headless check the ticket calls for.
- **Combat/advantage/determinism goldens verified unchanged, not just
  claimed.** `git show d752f1d --stat` touches only `character_a.gd`,
  `character-a.tres`, `test_support.gd`, `test_geometry_reflection.gd` (new),
  `judgment-log.md`, `run_tests.bat` — **no diff to `test_combat.gd`,
  `test_throws_multihit.gd`, `test_invuln.gd`, `test_projectiles.gd`,
  or `test_done_bar.gd`** in this commit, and all of them are still green in
  my independent run. This is the built-in proof the reflection was uniform,
  and it holds.
- JC-054 (spawn-point scalar reflection `new_y = -old_y`) and JC-055
  (verification-instrument latitude) are ratified and consistent with
  AD-037's text.
- **What this ticket cannot close, and does not claim to:** whether the
  boxes actually *render* right-side-up on screen. `training-mode.md`
  criteria 5/14 are explicitly marked in the ticket as confirmed at the
  human re-gate, not here — and the render code itself (`geometry_overlay.gd`)
  was deliberately *not* touched (AD-037's "rejected" clause: flipping the
  render sign is wrong). I did not attempt to infer a render verdict from the
  data change; that would be exactly the overclaim the audit-criterion's
  human-inspection-gate section exists to prevent.

### TKT-P1.1R-03 — Held-input stances (AD-038, pre-correction) — **PASS**
- `step_phases.gd`'s `phase2_state_machine` actionable+`move.loop` branch
  matches the ticket's described AD-038 mechanism exactly (re-derive per
  tick, target `idle_state_id` when nothing satisfied).
- `content/character_a.gd`'s crouch `button_map` entry (`_map(-1, DOWN, 0,
  STATE_CROUCH)`) is ordered correctly: after the `DOWN+button` crouch
  normals, before the walk entries — matches the ticket's stated ordering
  requirement and JC-056.
- Crouch block "falls out" claim verified directly:
  `_test_crouching_held_back_defender_blocks` drives a real hit exchange
  (P0 `5L` vs. a crouching, held-back P1) and checks `move_contact ==
  CONTACT_BLOCK`, `stun_kind == STUN_BLOCK`, and the reaction state's
  category is `CATEGORY_BLOCKSTUN` — not just a state-id label check.
- The one `test_combat.gd` change in this commit (`_test_movement_integration`
  now drives P0 with `InputFrame.RIGHT` instead of `NEUTRAL`) is a legitimate,
  narrowly-scoped fixture update forced by AD-038 itself (WALK is now a loop
  state that re-derives every tick; without a held direction it would
  collapse to idle before phase 3 integrates), not a weakened assertion — the
  test still checks the same `+2 units/tick` integration.

### TKT-P1.1R-04 — Airborne actions (AD-039) — **PASS**
- `PREJUMP_F`/`PREJUMP_B` mirror the existing `PREJUMP` (window `[3,3]`,
  JC-038's off-by-one), `button_map` diagonal entries (`UP|RIGHT`,
  `UP|LEFT`) are listed before the bare `UP` entry — first-match-wins
  preserved.
- Air-normal `CancelRule`s (`window [1, JUMP_DURATION-1]`, raw-button
  targets) added to `JUMP_N/F/B`, matching JC-059's ratified window bound.
- `test_airborne_actions.gd` is a real behavioral proof, driven through the
  trace harness end-to-end: forward jump reaches `PREJUMP_F`→`JUMP_F` and
  `pos_x` increases; back jump the mirror; neutral jump reaches `JUMP_N` and
  **lands flush at `pos_y=0` exactly** (the JC-047 net-zero invariant,
  re-verified through this new path); a button pressed mid-jump reaches the
  matching `j.L/M/H` state, category `AIRBORNE`, for all three buttons.
- The `_test_no_gatlings_no_jump_cancels` guard update (JC-061) is narrowly
  scoped: it exempts only the jump states' own AD-039-sanctioned cancels into
  their air normals and the prejumps' own lead-in cancels — every other
  state is still checked against the "no gatling / no player-granted
  jump-cancel" invariant. This is not a weakened regression guard; I read
  the diff and confirmed the exemption is structurally narrow.

### TKT-P1.1R-05 — Held-stance exit reads current-tick input (AD-038 correction) — **PASS**
This is the highest-scrutiny ticket in the set because it's a *correction* to
an already-ratified AD, and it touches the state machine a second time.
- The two-tier `phase2_state_machine` branch (`_buffered_discrete_command` /
  `_current_tick_loop_command`) matches AD-038's corrected contract exactly:
  a discrete command still gets full AD-022 buffer leniency and priority; a
  loop-state stance target is read from `InputBuffer.entry_satisfied_now`
  (age-0-only, no buffer/motion carry-over) with `idle_state_id` fallback.
- **The regression guard is real, not decorative.**
  `_test_discrete_command_buffered_through_hitstun_still_fires_first_actionable_frame`
  drops P0 directly into `STATE_HITSTUN` via state injection, holds
  `RIGHT|BUTTON_0` continuously (a direction that *would* satisfy the tier-2
  walk stance, plus a discrete `L` that must win), and asserts the character
  lands in `STATE_5L`, not `STATE_WALK_F`/`STATE_IDLE`, the instant stun
  clears. This is exactly the AD-022-vs-AD-038 conflict case and it is
  checked against the real state machine, not mocked.
- `entry_satisfied_now`'s three new `test_command_recognition.gd` cases
  include the **load-bearing contrast**: the same input history satisfies
  the buffered recognizer (`entry_satisfied`, AD-022 leniency intact) but
  correctly fails the current-tick-only recognizer once the direction has
  released — this is the exact discriminator the correction depends on, and
  it's tested directly at the `InputBuffer` unit level, not only through the
  end-to-end harness.
- Release-timing goldens re-baselined to tick 6 (release-frame's next
  actionable tick), confirmed in `test_held_input_stances.gd`; the *held*
  walk-integration golden in `test_combat.gd` was untouched by this commit
  (`git show 400c369 --stat` touches only `input_buffer.gd`,
  `step_phases.gd`, `test_command_recognition.gd`,
  `test_held_input_stances.gd`, `judgment-log.md`) — matches the ticket's
  "surgical scope" claim (JC-063) exactly.

## Determinism + serialization (Tenet 1) — highest scrutiny, held

- `SimState.step` remains a pure function of `(state, in1, in2)` throughout
  all five tickets — no wall-clock or `delta` dependency was introduced; the
  new engine code (`_buffered_discrete_command`, `_current_tick_loop_command`,
  `entry_satisfied_now`) reads only `p.input_history` and `p.facing`,
  already-serialized state.
- `TraceHarness`'s own determinism/source-equivalence proof
  (criterion 3, see TKT-01 above) is the trace harness's own verification of
  the Tenet, and it is real — I confirmed by reading the test, not by
  trusting the acceptance-criteria checklist.
- `test_sim_state.gd`, `test_harness.gd` (round-trip, replay-determinism,
  snapshot-resume, float/px-free truth dump) are untouched by any P1.1R
  commit and still green in my independent run — the backbone determinism
  net was not weakened or bypassed to land this feature.
- No new float entered any serialized or inspected field: `PlayerView`
  position/velocity are fixed-point ints (confirmed by source read); the
  trace row's float-freedom is independently tested
  (`_test_trace_field_free_of_floats_and_sim_internals`).

## Golden-file regression — verified, not assumed

- **Geometry goldens moved deliberately** (TKT-02): box world-y values
  changed by construction (the reflection), and the new
  `test_geometry_reflection.gd` file *is* the re-baselined golden, authored
  against the corrected convention rather than a blind re-lock of prior
  output — consistent with the spec's discipline against enshrining a bug.
- **Release-timing goldens moved deliberately** (TKT-05): the three
  walk/crouch release-tick assertions in `test_held_input_stances.gd` moved
  from the pre-correction ~tick-11 values to the corrected tick-6 values —
  an intended behavior change, not drift.
- **Combat/advantage/determinism goldens did NOT move** across any of the
  five tickets — confirmed by diff inspection of every commit's `--stat`,
  not by re-running a diff tool against a snapshot I don't have a pre-image
  of. `test_combat.gd` shows exactly one fixture-input change (TKT-03,
  legitimate per AD-038) and is otherwise untouched; `test_throws_multihit`,
  `test_invuln`, `test_projectiles`, `test_done_bar` are untouched entirely
  across all five commits. This is the uniformity proof AD-037 and the
  ticket file both call for, and it holds.

## Judgment-call log — drift check

Scanned the full index (JC-001..063); all P1.1-reconciliation entries
(JC-049..063) are ratified, their bodies swept to the archive, and the live
"Provisional" section is empty. Cross-checked every P1.1R-relevant ratified
call against the AD/spec text it claims to fold into (AD-037 spawn-offset
rule / JC-054; AD-038 corrected contract / JC-062; the surgical golden scope
/ JC-063) — each is a faithful realization, not a reinterpretation. **No
drift found** between the judgment-call log and the spec it was folded into.

## Audit-criterion / charter legibility — objective half

The reconciliation exists because the instrument was unusable
(`pipeline-analysis-completeness-gap.md`). On the **sim-behavior** half —
the half a headless session can actually assess — the fixes read as
legibility improvements, not shortcuts: walk now has an honest stop (no
"why won't this move stop" opacity), crouch is a real, distinguishable stance
with its own hurtbox rather than a phantom that only worked for attacks,
diagonal/directional jumps and air normals are reachable exactly as the
brief promises, and none of it reduces depth (the discrete-command/AD-022
leniency for reversals and cancels is explicitly preserved — a legibility
fix, not a difficulty cut). Per the audit criterion, that judgment of "reads
correctly" versus its **rendered** counterpart is not mine to close from
here — see the gate below.

I found no boundary-case candidate (tax vs. cherished friction, or a
knowledge-check risk) introduced by this reconciliation worth routing to the
Strategist. The one adjacent open design question — crouching-normal-attack
heights — is already an open, correctly-routed flag (owner: Strategist,
`flags.md`), explicitly parked to be re-evaluated after this fix at the
re-gate; I am not re-adjudicating it here, consistent with my role.

## Human-inspection gate — OPEN (I cannot and do not close this)

Per `protocol.md` and `audit-criterion.md`'s "human-inspection gate" section,
and the roadmap's explicit P1.1 declaration (`docs/roadmap.md` → "Done
when... the human-inspection gate clears"), this feature carries an
experiential surface — rendering and human operability — my headless session
cannot confirm. Recording it explicitly, per the checklist in
`briefs/character-a-movement-reconciliation.md` → "Acceptance":

**OPEN — requires the user, live, in `training_mode.tscn`:**
- Walk forward/back both **visibly** enter and **visibly** stop on release.
- Crouch stance and crouch block are both **visible and operable** (not just
  sim-true — I confirmed the sim-truth half; the render half is untested).
- Neutral/forward/back jumps and diagonal (7/9) jumps all **look and feel**
  correct, land flush.
- Jump-in normals are reachable **by human input**, not just by scripted
  replay.
- **All boxes render right-side-up** — this is the crux of AD-037: the data
  reflection is verified sim-true, but whether it draws correctly through
  `geometry_overlay.gd` (which was deliberately not touched by this
  reconciliation) has never been seen by a human or any tool capable of
  seeing pixels.
- The two parked feel calls (frame-step auto-pause JC-045; jump apex-hang
  JC-047) — non-blocking, confirm or ticket at the same session.
- Re-evaluate the crouching-normal-height flag against the now-corrected
  display (likely closes here, per the flag's own note — not mine to close).

**I am not issuing a "done" verdict.** Per protocol, only the user closes
this gate. My verdict is: **audit-passed, pending human inspection.**

## Flags raised

None. I found no implementation defect, spec gap, or drift requiring a new
flag — every ticket's claims held up under independent verification, the
goldens moved exactly where the ticket said they would and nowhere else, and
the existing open flags (dash scope — resolved/parked to P2; the two feel
calls; crouching-normal-height) are already correctly routed and need no
QA action beyond noting them in the human-re-gate checklist above.

## Files touched by this audit

- `docs/audits/audit-p1.1-reconciliation.md` (this file — new)
