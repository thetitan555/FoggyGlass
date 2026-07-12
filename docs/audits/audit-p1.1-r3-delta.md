# QA Audit — P1.1 Reconciliation, R3 Delta

> Owned by **QA**. Scoped objective audit of the **third fix batch** only —
> TKT-P1.1R3-01 (dummy-mode indicator + fresh-record, AD-041/JC-065/066),
> TKT-P1.1R3-02 (ground-contact landing snap, AD-042/JC-067), and
> TKT-P1.1R3-03 (frame-step auto-pause). Commits `b0f1241`, `c42d184`,
> `278d958`, ratification `535557b`. Does **not** re-audit the reconciliation
> batch or the R2 delta — see `audit-p1.1-reconciliation.md` and
> `audit-p1.1-r2-delta.md` for those verdicts, which stand.

## Scope read

Charter, principles, technical-tenets, protocol (per the QA read-first list);
AD-041 and AD-042 in `docs/spec/decisions.md`; `docs/spec/training-mode.md`
("Frame-step auto-pause," criterion 13's dummy-mode-indicator note, criterion
14); `docs/audit-criterion.md`; judgment-log index entries JC-065/066/067
(ratified, folded into AD-041/AD-042 per the `535557b` ratification commit);
the delta files under `/game` named in the dispatch.

## 1. Landing snap — determinism + serialization (Tenet 1)

**PASS.** `game/sim/step_phases.gd`'s `_enter_state` (the one hook every state
transition in the file funnels through, all 10 call sites) reads only
`p.pos_y` (existing `PlayerState` field), `next.stage.ground_y` (existing
`StageState` field, already part of `SimState.hash_state()` at
`sim_state.gd:215` and already round-tripped by `to_dict`/`from_dict`), and
`character.get_state(state_id).category` (static roster/move data, not sim
state). No wall-clock, no engine timing, no RNG — a pure function of
`(next, p, character, state_id)`, called only from inside the phase pipeline
`SimState.step` already drives. It introduces no new serializable field, so
the existing generic round-trip suite (`test_sim_state.gd` criterion 3:
snapshot-at-j → restore → resume-to-K == uninterrupted run to K, and
`test_training_harness.gd`'s `restore(snapshot())` hash-equality check) already
covers any tick the snap fires on — both still pass (see suite run below).
Structurally and by the passing generic determinism/serialization suite, the
snap satisfies Tenet 1. This is the highest-scrutiny item in the delta and it
clears cleanly.

## 2. E2 fixed — held/repeated jumps, no cumulative drift; D3 resolved

**PASS, and the widened coverage is real, not vacuous.**
`game/tests/test_airborne_actions.gd` adds four new scenarios beyond the R2
per-direction test (which released the jump direction after 3 ticks and so
structurally could never reach the held-jump transition):

- `_test_held_up_repeated_jumps_land_flush_no_cumulative_drift` — `8*141`
  (hold UP continuously), asserts `p0.py == 0` at ticks 47/93/139 (after 1/2/3
  completed held jumps). Pre-fix this drifted 0/-6/-12/-18 per the AD-042
  diagnosis; the test's own comments derive the 46-tick cycle arithmetic from
  an actual headless replay, not by hand.
- The same pattern repeated for held-forward (`9*141`) and held-back (`7*141`).
- `_test_air_normal_interrupted_jump_lands_flush` — an air normal cutting a
  forward jump short (`9*3 5*10 L*1 5*20`) now asserts `p0.py == 0` at the
  tick the once-through move ends, resolving the re-gate-3 D3 aerial float as
  a documented side effect of the same snap.

I ran the suite independently (below) rather than trusting the commit
message's "32/32" — confirmed green, including these four scenarios.

## 3. Snap doesn't mask bad arcs (net-zero assertions still active)

**PASS.** TKT-P1.1R2-02's per-direction net-zero assertions are untouched and
still execute in the same file: `_test_forward_jump_reaches_prejump_f_...`
and `_test_back_jump_reaches_prejump_b_...` still assert `p0.py == 0` at tick
48 for the released (non-held) case, explicitly commented as the "D2
regression guard." The new held-jump tests are additive, not a replacement.
The snap is paired with AD-042's "not a bare clamp" framing (a mis-authored
arc is still caught at author time by the net-zero invariant + these
assertions) — this pairing is intact in code, not just in prose.

## 4. Golden scope

**PASS — confirmed via diff, not assertion.** `git diff --stat` across the
three commits touches exactly: `game/scenes/dummy_mode_indicator.gd` (new),
`game/scenes/training_mode.gd`, `game/scenes/training_mode.tscn`,
`game/sim/record_playback_source.gd`, `game/sim/step_phases.gd`,
`game/tests/test_airborne_actions.gd`, `game/tests/test_control_surface.gd`,
`game/tests/test_dummy_mode_indicator.gd` (new),
`game/tests/test_training_mode_shell.gd`. No combat, advantage, determinism,
move-format, geometry, or other non-jump golden/test file (`test_combat.gd`,
`test_character_a.gd`, `test_move_format.gd`, `test_frame_data_panel.gd`,
`test_geometry_overlay.gd`, `test_invuln.gd`, `test_throws_multihit.gd`,
`test_projectiles.gd`, etc.) appears in the diff or moved value. Only the
jump-landing test file (`test_airborne_actions.gd`) gained new held/interrupted
scenarios — deliberate, JC-017-style, exactly as AD-042 records. No flag
needed here.

## 5. Fresh-record

**PASS.** `RecordPlaybackSource.reset_playback_cursor()` is a minimal, dedicated
primitive (rewinds `_playback_cursor` only, per its doc comment, distinct from
`set_playback_position`). It is invoked from `TrainingMode.set_dummy_mode`
guarded exactly on the `!= RECORDING -> RECORDING` transition
(`training_mode.gd:364-369`), pairing a buffer clear
(`source.set_recorded_buffer(PackedInt32Array())`) with the cursor reset —
matching AD-041/JC-066 precisely (fires on entry only, not mid-take, and also
fires for a direct `set_dummy_mode` call, not just the `M`-cycle path).
Headless-verified by two new tests in `test_training_mode_shell.gd`:
`_test_fresh_record_on_recording_entry_replaces_not_concatenates` (a second,
shorter record pass replaces the first, not `3+2=5` concatenated) and
`_test_fresh_record_resets_the_playback_cursor` (a stale mid-buffer cursor
from a first playback does not leak into a shorter second recording). Both
pass.

## 6. Frame-step auto-pause

**PASS.** `training_mode.gd`'s `_unhandled_input` calls `set_paused(true)`
then `step_once()` on `tm_step`, exactly as `training-mode.md` and the ticket
specify; `step_once()` itself is unchanged. `test_control_surface.gd`'s new
`_test_step_action_auto_pauses_from_a_running_sim` confirms: from a running
(unpaused) shell, invoking the bound handler leaves `is_paused() == true` and
advances exactly one tick. Passes.

## 7. Independent full-suite run

**PASS — ran myself, did not trust the commit message.** Ran all 32 suites
listed in `run_tests.bat` directly against
`C:\Users\ryans\Downloads\Godot_v4.3-stable_win64.exe`, individually, capturing
each exit code:

```
32/32 exit=0, including:
test_sim_state: OK — 28 checks passed
test_airborne_actions: OK — 44 checks passed
test_dummy_mode_indicator: OK — 6 checks passed
test_training_mode_shell: OK — 65 checks passed
test_control_surface: OK — 46 checks passed
```

(Two lines printed mid-run — a `SimState.from_dict` bad-version error and two
`[TraceHarness] assert FAIL` lines — are the expected output of deliberate
negative-path tests in `test_serialization_version.gd` and
`test_trace_harness.gd` confirming those harnesses correctly detect bad input;
both suites still exited 0. Confirmed by inspection, not assumed.)

Re-ran `test_sim_state` and `test_airborne_actions` a second time after the
comment cleanup below to confirm the non-behavioral edit changed nothing —
both still green.

## Cleanup folded in (non-behavioral)

Per the dispatch, tidied `_enter_state`'s doc comment
(`game/sim/step_phases.gd`, ~lines 1164-1178): it still described the
pre-ratification root cause ("idle re-derive -> prejump ... with no settled
idle tick, silently dropping the arc's final fall frame"). Replaced with the
`535557b`-ratified mechanism — the held jump exits its arc one tick early at
the `is_actionable(>= duration)` vs. move-ended (`> duration`) boundary
(JC-011/JC-038), so the still-held direction's buffered command re-derives the
grounded transition on the arc's own last frame and the final fall tick never
applies. Comment-only; verified both `test_sim_state` and
`test_airborne_actions` still pass after the edit (no behavior touched).

## Flags raised

None. No non-jump golden moved; no scope conflict found; JC-065/066/067 are
already ratified and folded into AD-041/AD-042 per `535557b` — nothing left
provisional for this delta.

## Verdict

**Objective pass.** All seven verification items in the dispatch pass:
determinism/serialization on the landing snap holds (structurally pure,
generic round-trip suite green), E2's cumulative drift is gone and D3 is
resolved with real (non-vacuous) widened coverage, the net-zero authoring
guard is still active alongside the snap, golden scope is clean, fresh-record
and frame-step auto-pause both behave and are headless-verified, and the
independent 32/32 run confirms all of the above rather than trusting the
commit message. The requested comment tidy is done and non-behavioral.

**Human-inspection gate — recorded OPEN. QA cannot close it.** Per
`protocol.md` and `audit-criterion.md`'s human-inspection-gate rule, the
following remain live-only and are **not** closed by this audit:

1. **Rendered dummy-mode indicator** — the label actually visible on screen,
   correct, and updating as the user cycles `M` through
   PASSTHROUGH/RECORDING/PLAYBACK, with the "REC" tell legible at a glance.
2. **In-app record→playback round-trip** — record a dummy sequence live,
   cycle to PLAYBACK, see it loop; then re-record and confirm the take
   replaces (not concatenates) in hand, not just in the headless assertion.
3. **Pixel-flush landing** — held-to-jump repeatedly with no visible drift,
   and the previously-floating aerial-interrupted-jump case landing flush,
   confirmed by eye.

This objective pass is necessary, not sufficient. Only the user, at the 5th
re-gate, closes P1.1.

## Files touched by this audit

- `game/sim/step_phases.gd` — comment-only tidy (`_enter_state` doc comment,
  root-cause wording corrected to match the ratified AD-042 mechanism).
- `docs/audits/audit-p1.1-r3-delta.md` — this report (new).
