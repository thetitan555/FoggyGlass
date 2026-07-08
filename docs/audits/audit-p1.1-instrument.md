# Audit — P1.1 (Finish the instrument: operable + visible)

> QA audit report. Owner: QA. Routed findings live in `docs/flags.md`.
> Date: 2026-07-08. Auditor: QA (FoggyGlass).
>
> **Per-feature audit** (protocol cadence). Scope: the three P1.1 tickets
> (`docs/tickets/p1.1-finish-instrument.md`) — TKT-P1.1-01 (geometry visible),
> TKT-P1.1-02 (control surface), TKT-P1.1-03 (serialization version) — plus the
> two gate-defect fixes that landed alongside them (walk wiring, JC-046; the
> jump-arc net-zero fix, JC-047, AD-036) and two bookkeeping-flag closures
> (`run_tests.bat` currency; the stale `2H` comment).
>
> Audited against: `docs/spec/training-mode.md` criteria 5, 13, 14;
> AD-034/AD-035/AD-036; `docs/technical-tenets.md` (determinism, serialization);
> `docs/judgment-log.md` (JC-044..048); `docs/audit-criterion.md`'s
> **human-inspection gate**.
>
> **This audit carries a human-inspection gate that is currently OPEN. My
> objective pass below is necessary but not sufficient — P1.1 is NOT done.**
> See "Human-inspection gate" at the end before reading anything else as a
> green light.

---

## Bottom line

**Objective audit: PASSES.** Every acceptance criterion I can verify
headlessly holds against the actual code and a real, executed test run (I ran
Godot myself, not a static trace). Determinism and serialization hold with
direct evidence, including for the one deliberate sim-behavior change in this
batch (the jump-arc fix). The judgment-log drift check finds no drift — all
five P1.1 entries (JC-044..048) are ratified and the ratified calls match spec
and code exactly, folds included.

**But: the human-inspection gate is OPEN, not closed by this audit.** The gate
already ran once (user, 2026-07-08) and found two real defects that all
headless tests missed — a human could not walk left/right, and the character
sank ~5px through the floor on landing. Both are now fixed and ratified
(JC-046/JC-047) and pass their own headless regression, but **the fixes
themselves have not yet been re-confirmed live by the user.** Per
`audit-criterion.md`'s human-inspection gate and `protocol.md`'s
done-mechanics, **QA cannot issue a "done" verdict while that gate stands
open — only the user can close it.** This report is *audit-passed
(objective), pending human re-gate* — not done. See the closing section.

---

## Test run (real execution, not static trace)

Ran all 27 files in `game/tests/` individually against
`C:\Users\ryans\Downloads\Godot_v4.3-stable_win64.exe --headless --path game -s res://tests/<name>.gd`,
capturing each process's real exit code (via `Start-Process -Wait -PassThru`,
not the batch file, to sidestep `run_tests.bat`'s trailing `pause` which hangs
non-interactively) and reading its own printed summary.

| # | File | Result |
|---|---|---|
| 1 | test_fp | OK — 45 checks |
| 2 | test_tick_host | OK — 126 checks |
| 3 | test_input | OK — 104 checks |
| 4 | test_sim_state | OK — 28 checks |
| 5 | test_inspection_view | OK — 42 checks |
| 6 | test_move_format | OK — 44 checks |
| 7 | test_harness | OK — 10 checks |
| 8 | test_combat | OK — 56 checks |
| 9 | test_done_bar | OK — 34 checks |
| 10 | test_overlap_boundary | OK — 10 checks |
| 11 | test_buffer_cancels | OK — 49 checks |
| 12 | test_throws_multihit | OK — 17 checks |
| 13 | test_air_height_scaling | OK — 38 checks |
| 14 | test_character_a | OK — 151 checks |
| 15 | test_command_recognition | OK — 22 checks |
| 16 | test_control_surface | OK — 27 checks |
| 17 | test_frame_control | OK — 26 checks |
| 18 | test_frame_data_panel | OK — 72 checks |
| 19 | test_geometry_overlay | OK — 45 checks |
| 20 | test_input_history_panel | OK — 29 checks |
| 21 | test_invuln | OK — 26 checks |
| 22 | test_live_state_panel | OK — 22 checks |
| 23 | test_projectiles | OK — 62 checks |
| 24 | test_record_playback | OK — 32 checks |
| 25 | test_serialization_version | OK — 15 checks |
| 26 | test_training_harness | OK — 21 checks |
| 27 | test_training_mode_shell | OK — 50 checks |

**27/27 files green, exit code 0 on every file.** `run_tests.bat`'s `TESTS`
list was cross-checked against a fresh `game/tests/test_*.gd` glob: it names
exactly these 27 files (excludes `test_support.gd`, a shared non-runnable
helper with no `_init`/`quit` shape) — the bookkeeping flag closure (F- from
2026-07-04, resolved this batch) holds; the batch file is now current, modulo
its trailing `pause` (a pre-existing, out-of-scope non-interactivity papercut,
not this feature's defect).

---

## Acceptance criteria — training-mode.md

**Criterion 5 (Geometry) — headless half PASSES; pixel half is the gate.**
`test_geometry_overlay.gd` (45 checks, up from P1's 28 — the 17 new checks are
the AD-035 framing suite): boxes resolve at correct world positions from
`GeometryOverlayModel.build_draw_list` (unchanged, still the pure
view-model), and the new framing tests
(`_test_world_framing_centers_stage_and_seats_ground_low`,
`_test_world_framing_puts_symmetric_start_boxes_on_screen_and_clear_of_panels`,
`_test_world_framing_is_render_only_no_effect_on_draw_list_or_state_hash`)
confirm the framing math: zoom is positive and uniform (no stretch), both
symmetric-start players' boxes land within the viewport and clear of the
panel region by the numbers, and — the render-only contract — applying the
live node's framing changes **neither** the draw list **nor** the `SimState`
hash. I read `geometry_overlay.gd` directly: `_apply_world_framing()` sets
only `position`/`scale` on the `GeometryOverlay` node itself, never touches
`SimState` or the model. Pixel-level "are the boxes actually visible on a
real running screen" is explicitly the human-gate half (criterion 5's own
text says so) — not claimed here.

**Criterion 13 (Human-operable) — headless half PASSES; operability itself is
the gate.** `test_control_surface.gd` (27 checks): pause/resume, frame-step,
capture-reset, do-reset, and the dummy mode-cycle each drive through the
`TrainingMode` shell's own control methods when the bound input action fires
(`_test_pause_action_toggles_through_shell`,
`_test_step_action_advances_one_tick_through_shell`,
`_test_reset_actions_through_shell`,
`_test_dummy_mode_cycle_action_through_shell`) — confirmed by reading the
assertions, not just the test names: each drives `Input.action_press(...)`
then asserts the shell's own state (`is_paused()`, a tick advance, etc.)
changed, never reaching into `TickHost`/`TrainingHarness`/
`RecordPlaybackSource` directly. The device sampler now encodes the three
attack buttons (`_test_device_sampler_encodes_attack_buttons`) and, after the
JC-046 walk-wiring fix, left/right (`_test_device_sampler_encodes_left_and_right`).
`_test_input_map_actions_are_registered` confirms the eight `tm_*`
`project.godot` actions exist. A human actually pressing keys on a real
keyboard is, again, the gate's job, not headless-provable.

**Criterion 14 (Framed on screen) — same evidence as criterion 5, PASSES
headlessly.** The render-only proof above is exactly this criterion's
"golden with or without the camera is identical" requirement (AD-019
criterion 6, extended). No new finding beyond criterion 5.

---

## AD-034 (serialization version) — verified directly, non-vacuous

Read `sim_state.gd` directly and `test_serialization_version.gd`'s 15 checks
in full (not taken on the judgment log's word):

- `to_dict()` emits `"v": FORMAT_VERSION` (=1) **only** at the top level —
  confirmed no sub-dict (`rng`, `stage`, any player) carries its own `"v"`.
- **Hash unaffected, proven by construction, not inspection alone.**
  `_test_hash_unaffected_by_v_presence` builds two dicts differing *only* in
  whether `"v"` is present, restores both through `from_dict`, and asserts
  `hash_state()` is identical — this directly demonstrates `hash_state()`
  never reads the field, rather than trusting the code comment that says so.
- **Round-trip.** `"v"` survives a full `to_dict`/`from_dict` round trip and
  the restored state's hash matches the original.
- **Absent ⇒ 1 (legacy).** A dict with `"v"` erased still restores, to a
  state with an identical hash to the versioned one.
- **Unrecognized ⇒ fail loudly.** A dict with `"v": 2` makes `from_dict`
  return `null` (not a partially-parsed state) — the fail-fast guard AD-034
  and JC-048 specify.

**Verdict: AD-034 PASSES.** No existing state hash changes; the field is
purely additive metadata, exactly as specified.

---

## AD-035 (render framing is render-only) — verified

Covered above under criteria 5/14. Restating the specific claim this audit
was asked to check: **a golden taken with vs. without the framing is
identical.** `_test_world_framing_is_render_only_no_effect_on_draw_list_or_state_hash`
applies the actual live node's `_ready()`/`_apply_world_framing()` path (not a
re-derivation), captures the `SimState` hash and the model's draw list before
and after, and asserts byte/value identity on both. **PASSES** — this is the
strongest form of this claim (drives the real code path, not a parallel
computation of what it "should" do).

---

## AD-036 (jump arc nets zero) — verified, and the fix is a disclosed sim-behavior change

`test_character_a.gd`'s `_test_jump_arc_integrates`: drives `STATE_JUMP_N` for
its full 45-frame authored duration and asserts `pos_y` returns **bit-exact**
to `start_y`, not merely "close" — I read the prior version of this
assertion's intent via JC-047's own log entry, which states the *old*
assertion explicitly tolerated drift ("lands close to its start... not
bit-exact"), and confirms that tolerance was, in hindsight, silently
documenting the +6-unit sink defect the human gate found. The new assertion
is strictly tighter, not loosened. **PASSES.**

This is exactly the kind of change the task flagged for extra scrutiny — a
**deliberate** sim-behavior change (frame 23 becomes a zero-velocity apex
hang instead of a fall frame), not a silent regen. I confirmed this is
disclosed, not silent, three ways: (1) JC-047's log entry states outright
that this changes sim behavior and explains exactly which frame and why; (2)
the log entry explicitly checked for stale golden fixtures and found none
exist yet in the repo (`grep`-verified: no `*golden*` files under version
control), so there was nothing to silently regenerate; (3) the one place this
trajectory was asserted in test form was updated in the same change, in the
direction of a *stricter* assertion, and I re-ran that test myself rather
than trusting the log's claim that it passes. AD-036 itself (the deferred
runtime-clamp decision) is correctly marked provisional/deferred and routed
to the Strategist for roadmap placement (already resolved — placed pre-P2);
nothing here calls that placement into question.

---

## Determinism / serialization tenet — PASS

`test_harness.gd`: 10/10 checks, run by me this session — snapshot round-trip
preserves the canonical hash, replay is deterministic across two independent
runs, a mid-replay snapshot/restore/resume reaches the same final hash as an
uninterrupted run. This harness is untouched by P1.1's changes and stays
green under them, which is itself evidence the new serialization-version
field and the jump-arc fix don't destabilize the primitive everything else
leans on.

**Float audit, re-checked, not taken on trust.** Grepped the P1.1-touched
files (`sim_state.gd`, `geometry_overlay.gd`, `character_a.gd`'s jump-arc
section, `training_mode.gd`) for `float` outside comments/render-only
projection helpers: no float enters `SimState`, `hash_state()`, or the jump
arc's `motion_vel_y` integration — all fixed-point/int, consistent with
AD-005/AD-014/AD-019. The one float surface (`GeometryOverlay`'s
`position`/`scale`) is exactly the render-only layer AD-019/AD-035 carve out,
and is proven non-hash-affecting by the render-only test above, not merely by
convention.

**Verdict: determinism and serialization tenets both PASS**, including
correctly absorbing one *intentional* behavior change without any silent
golden drift.

---

## Walk reachability (JC-046) — verified; no regression to character A's P1 behavior

`test_command_recognition.gd`'s three new tests, read and re-run:
`_test_character_a_walk_forward_reachable_end_to_end` and
`_..._walk_back_reachable_end_to_end` drive `SimState.step` with **live
input only** (no state injection) and confirm a bare held forward/back
direction actually reaches `STATE_WALK_F`/`STATE_WALK_B` and displaces
`pos_x` — this is the actual defect the human gate found (holding
left/right previously produced zero state change and zero displacement),
now closed and proven end-to-end, not just unit-isolated.
`_test_character_a_button_beats_walk_on_same_frame` confirms the
first-match-wins ordering holds: a button held alongside a direction still
performs the normal, not a walk — the correct precedence per AD-32's
existing convention, and the thing that would silently break every existing
normal-into-walk interaction if the ordering were wrong.

**Regression check on prior P1 content.** JC-046's log entry flags that this
walk fix legitimately changes `test_character_a.gd`'s
`_test_5h_plus_on_block_and_advances`, because P1's defending dummy now
*actually* retreats when holding back (previously inert). I read the updated
test directly: it now measures **P0's own `pos_x` delta** rather than the
inter-player gap, which correctly isolates "does 5H advance P0" from "does
P1's now-functional walk change the gap" — the fix is to the test's
measurement, not a loosening of what it verifies, and 5H's block-frame
advantage/blocking behavior itself is untouched (`_is_holding_back` still
reads raw held-back intent independent of `state_id`). This is the right
fix, not a silent weakening, and I confirmed by reading the actual assertion
rather than trusting the log's characterization of it.

**Verdict: walk reachability PASSES, and the one touched pre-existing test
was correctly repaired, not weakened, to stay meaningful under the new
(correct) behavior.**

---

## Drift check — judgment-log (JC-044..048)

Read all five P1.1 entries in full (`judgment-log.md`'s "Provisional"
section — not yet swept to the archive, which is fine; the index already
shows all five as `ratified` and that's the status that matters for this
check) and verified each ratified call against current spec/code, not the
log's own claim:

| Entry | Ratified claim | Verified against code/spec |
|---|---|---|
| JC-044 | AD-035 framing as a node `position`/`scale` transform (not `Camera2D`); placeholder constants; fixed stage-bounds literals | Confirmed: `geometry_overlay.gd` applies the transform to itself, not a `Camera2D`; the three HUD panels are siblings under `training_mode.tscn`, not children of `GeometryOverlay` — screen-anchored "for free," matching the ratified rationale. No drift. |
| JC-045 | Control-surface bindings (P/N/C/R/M/J/K/L), one cycling dummy-mode key, InputMap-reading legend; frame-step auto-pause carved out to the Strategist | Confirmed: `project.godot`'s `[input]` section defines exactly these eight `tm_*` actions; `controls_legend.gd` builds its text from `InputMap.action_get_events(...).as_text()`, not hardcoded strings — it cannot drift from the actual bindings. The auto-pause carve-out is the open, non-blocking Strategist flag referenced below — correctly not folded as settled. No drift. |
| JC-046 | Walk wiring via two pure-direction `button_map` entries, listed after standing normals | Confirmed directly in `character_a.gd`'s `_build_button_map` and by the live-input end-to-end tests above. `move-format.md` now names walk as a canonical pure-direction command (line 149-152) and `character-a.md` documents it (line 62) — the folds are real, not just claimed. No drift. |
| JC-047 | Jump arc: 22 rise / 1 zero-velocity apex hang / 22 fall = 45, nets zero; both tuned speeds preserved | Confirmed against `_test_jump_arc_integrates`'s bit-exact assertion and `move-format.md`'s new net-zero-arc authoring invariant (line 218-222, cites JC-047/AD-036 by name). No drift. |
| JC-048 | `push_error` + `null`-return fail-fast; dedicated `test_serialization_version.gd` | Confirmed: `sim_state.gd`'s `from_dict` does exactly this (line ~159-160); the dedicated test file exists, follows the established `SceneTree`-runner shape, and is in `run_tests.bat`'s `TESTS` list. No drift. |

All five ratified calls match their folded spec text and the running code
exactly. **No drift found.** The two carved-out feel sub-items (frame-step
auto-pause; jump apex-hang feel) and one design question (crouching-normal
attack heights) are correctly routed to the Strategist as open, explicitly
non-blocking flags — I am not re-raising them; they are referenced, not
re-litigated, per the task's steer.

---

## Findings routed

**One new finding, unrelated to P1.1's own scope but discovered while reading
this audit's inputs:** `docs/flags-archive.md` contains a 4,632-byte run of
NUL bytes (confirmed via raw byte read, not a text-tool artifact) that
predates this session (already committed; `git status` on the file is
clean), causing some text-search tools to silently stop matching past that
offset without an error. It sits inside old P0-era content, not any P1.1
entry, so it does not affect anything this audit needed and does **not**
change any verdict above. Routed to the Strategist (owner of
`flags-archive.md`) as `docs/flags.md`'s newest open entry
(2026-07-08, re: "docs/flags-archive.md contains a run of NUL bytes").

No implementation bugs and no spec gaps were found in P1.1 itself. No new
subjective/legibility candidates surfaced beyond the three already-open,
already-routed Strategist flags (frame-step auto-pause, jump apex-hang feel,
crouching-normal attack heights) — I looked specifically and found nothing
further that reads as a tax candidate under the audit criterion.

---

## Human-inspection gate — OPEN. P1.1 is NOT done.

Per `audit-criterion.md`'s human-inspection gate and `protocol.md`'s
done-mechanics: **any change with an experiential surface carries this gate,
and QA's objective verdict does not close it — only the user, having seen
and operated the thing, does.**

**Status: the gate has been run once (user, 2026-07-08) and found two
defects.** Both are now fixed and ratified (JC-046 walk wiring, JC-047
jump-arc net-zero) and both pass non-vacuous headless regression as detailed
above. **But the fixes have not yet been re-confirmed live.** The gate must
be **re-run by the user** — operating `training_mode.tscn` directly — to
confirm:

1. Both characters' boxes actually render on screen, fully visible and
   unoccluded by the panels (criteria 5/14's pixel half).
2. Every control operation is actually operable from the keyboard, and the
   on-screen legend is actually discoverable/legible (criterion 13's pixel
   half).
3. **Specifically re-confirming the two prior defects are gone:** left/right
   arrow keys now walk the character in both directions; the character now
   lands flush on the floor with no visible sink-through on landing.
4. While there, weighing the three open, non-blocking Strategist flags if
   they want to (frame-step auto-pause feel, jump apex-hang feel,
   crouching-normal attack heights) — none of these block the gate closing.

**Green headless tests are not a substitute for this.** That is the standing
lesson P1 already taught and P1.1 exists to close: the P1 audit
(`docs/audits/audit-p1-feature.md`) called P1 a full PASS on 24/24 green
headless tests while the geometry overlay drew nothing and nothing in the
mode was human-operable — defects only a human at a keyboard and a screen
could find, and did find, on the very first real run. This audit's own
27/27 green result is the same category of evidence as that prior 24/24 —
necessary, and, on its own, **not sufficient**.

**Verdict: P1.1 is audit-passed (objective) — pending human re-gate. Not
done**, per `protocol.md`'s explicit rule that QA cannot issue a done verdict
while the gate stands open.

---

## Summary table

| Area | Verdict |
|---|---|
| training-mode.md criterion 5 (Geometry) | **PASS (headless half)** — pixel half is the open gate |
| training-mode.md criterion 13 (Human-operable) | **PASS (headless half)** — operability itself is the open gate |
| training-mode.md criterion 14 (Framed on screen) | **PASS (headless half)** — same gate |
| AD-034 (serialization version) | **PASS** |
| AD-035 (render framing is render-only) | **PASS** |
| AD-036 (jump arc nets zero) | **PASS** — disclosed, not silent, sim-behavior change |
| Determinism | **PASS** |
| Serialization | **PASS** |
| Walk reachability (JC-046) | **PASS** — no regression to character A's P1 behavior |
| Judgment-log drift (JC-044..048) | **No drift** |
| Full suite | **27/27 files green** |
| **Human-inspection gate** | **OPEN — re-run required.** P1.1 is not "done." |

Also re-folding into `docs/audits/audit-p1-feature.md` (see the addendum
added at its top): that report's unqualified "P1 PASSES" reads more
optimistic than the human result (2026-07-08) warranted, because it predates
that gate finding. This report is the honest correction, kept as a separate
file rather than rewritten in place so the original P1 audit stands as the
dated record of what was known at the time.
