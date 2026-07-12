# QA Audit — P1.1 Reconciliation, R2 Delta

> Owned by **QA**. Scoped objective audit of the **second (final) fix batch**
> only — TKT-P1.1R2-01 (dummy-control wiring, AD-040/JC-064), TKT-P1.1R2-02
> (jump flush-landing test guard), and the Architect follow-ups (DP-prose
> reconciliation in `spec/character-a.md`, JC-064 ratification). Commits
> `f50944e`, `7389ff2`, `47832a6` (plus `55b00a4`, the source-wiring diff that
> landed under a mis-labeled message — see below). Does **not** re-audit
> TKT-P1.1R-01..05, already covered and PASSed in
> `docs/audits/audit-p1.1-reconciliation.md`. Read alongside that file and
> `docs/spec/decisions.md` AD-040.

## Overall objective verdict: **PASS, with the human-inspection gate still
explicitly OPEN (4th re-gate).**

Every objective, headless-checkable claim this delta makes checks out. The
dummy-control wiring is real, isolated from P1, and stays exactly one
`InputSource` (Tenet 2 intact). Determinism is unaffected. The jump guard is a
genuine, non-vacuous test addition with no production change. The DP prose
edit is prose-only; the move data (grounded, no vertical velocity) is
unchanged and matches the user's Q1 ruling. The independent full-suite run is
green, reproduced myself, not taken on the commit messages' word. **This
objective pass is necessary, not sufficient** — the 4th human re-gate is
still required to close P1.1; see "Human-inspection gate" below.

## What I verified myself (did not take on faith)

- Read the actual diffs for all three named commits plus `55b00a4` (the
  commit the `f50944e` message says actually carries the source-wiring half),
  rather than trusting the commit messages.
- Read `record_playback_source.gd` in full (unchanged by this delta) to
  confirm Tenet 2 still holds structurally.
- Read the DP move builder (`content/character_a.gd`, `_build_dp` and its
  three callers) end-to-end to confirm `MoveState.category =
  CATEGORY_GROUNDED` and no `motion_vel_y` anywhere in the DP keyframes.
- Ran the full 31-suite headless list myself against
  `C:\Users\ryans\Downloads\Godot_v4.3-stable_win64.exe --headless --path game
  -s res://tests/<name>.gd`, one at a time, via `Start-Process -Wait -PassThru`
  so each exit code is captured reliably (a naive `&`-call + redirect
  under-reported exit codes in this shell — worth flagging as a tooling note,
  not a project defect). **31/31 exit 0.** Spot-checked the three
  delta-relevant suites' own internal pass counters
  (`test_control_surface`: 43 checks passed; `test_training_mode_shell`: 56
  checks passed; `test_airborne_actions`: 24 checks passed) to confirm the new
  assertions actually executed and weren't silently skipped, not just that the
  process exit code was 0.

## Per-item results

### TKT-P1.1R2-01 — Dummy-control wiring (AD-040) — **PASS**

- **The sampler is actually injected.** `training_mode.gd`:
  `_source_p2 = RecordPlaybackSource.new(Callable(self, "_sample_device_dummy"))`
  — was previously `RecordPlaybackSource.new()` (no sampler, the D1 defect).
  `_sample_device_dummy()` mirrors `_sample_device_p1()`'s exact `InputFrame`
  OR-composition shape, reading seven new dedicated actions
  (`tm_dummy_up/down/left/right/button_0/1/2`) bound in `project.godot` to
  W/S/A/D/U/I/O.
- **RECORDING captures the dummy's own keys; PLAYBACK loops them — proven
  headless, through the shell, not the class directly.**
  `test_training_mode_shell.gd::_test_dummy_recording_captures_live_input_and_playback_loops_it`
  drives `Input.action_press("tm_dummy_left")` across three ticks in
  RECORDING, reads back `get_dummy_recorded_buffer(1)` and confirms
  `[NEUTRAL, LEFT, NEUTRAL]`, then cycles to PLAYBACK and confirms two full
  loops of that exact captured stream through
  `inspection_view().player(1).input_current`. This is a real round-trip
  through the actual shell-wired dummy (`set_dummy_mode`/`get_dummy_mode`/
  `get_dummy_recorded_buffer`), not a mock.
- **The dedicated key set is isolated from P1 — proven, not assumed.**
  `test_control_surface.gd::_test_dummy_sampler_encodes_attack_buttons_on_its_own_key_set`
  exercises every one of the seven dummy actions individually, then — the
  load-bearing check — presses `ui_left` and `tm_button_0` (P1's own bound
  keys) together and asserts `_sample_device_dummy()` still reads `NEUTRAL`:
  P1's keys do not leak into the dummy's sampler. Recording the dummy does not
  drive P1, and (by construction — P1's source is untouched and keeps
  sampling `_sample_device_p1` every tick regardless of dummy mode) P1 is
  never silently frozen or hijacked either.
- **Tenet 2 — the dummy remains exactly one `RecordPlaybackSource`; no
  special-casing crept in.** I read `record_playback_source.gd` in full: it
  is untouched by this delta (confirmed via `git show --stat` on all three
  named commits — no diff to that file). The class still has zero
  Godot-`Input` dependency, no P2-is-special branch, no second `InputSource`
  subtype, and no behavior/AI — the sampler is *injected* the same way
  `_sample_device_p1` always was; this delta only supplies a *different*
  Callable to the *same* constructor parameter. AD-040's own text explicitly
  rejects a "dummy AI"/stance-freeze behavior mode and a second live-human
  P2-takeover model, and neither exists in the diff. This holds.
- **A provenance note, transparently flagged by the Developer/Architect
  themselves, verified rather than waved through.** The commit message on
  `f50944e` states the source-wiring diff (`training_mode.gd`,
  `controls_legend.gd`, `project.godot`) actually landed in the immediately
  preceding commit `55b00a4` ("strategist: rule DP grounded...") because a
  concurrent session's commit swept it in under an unrelated message. I did
  not take this claim on faith: I ran `git show 55b00a4` on all three files
  directly and confirmed the diff is exactly the dummy-sampler wiring
  described (the `_sample_device_dummy` method, the `_source_p2` constructor
  change, the `tm_dummy_*` legend entries and workflow hint, the seven
  `project.godot` input-map actions) — content is correct, nothing else rode
  along in that commit's diff to those three files. This is a git-hygiene
  wrinkle (a commit message that undersells its own diff), not a code defect,
  and the ticket's commit message discloses it plainly rather than hiding it
  — no drift finding needed, but worth naming so the history reads honestly
  for whoever reads it next.
- **JC-064 ratification is faithful.** Compared the ratified body (folded
  into AD-040, `docs/spec/decisions.md` "Dedicated dummy key set" paragraph)
  against the actual code: the "reuse would drive P1 and the dummy on the same
  press" hazard the ratification cites is real and correctly reasoned — P1's
  source samples `_sample_device_p1` unconditionally every tick regardless of
  dummy mode, so a shared key set would have made recording a dummy stance
  simultaneously walk P1. The dedicated-key-set fix is the correct, narrowly
  scoped resolution. No drift between JC-064's text and the shipped code.

### TKT-P1.1R2-02 — Jump flush-landing guard (test-only) — **PASS**

- `test_airborne_actions.gd`'s forward- and back-jump tests each gained the
  same two assertions the neutral-jump test already had:
  `TraceHarness.check(rows, 48, "p0.state", CharacterA.STATE_IDLE)` and
  `TraceHarness.check(rows, 48, "p0.py", 0)`. These are genuine,
  non-vacuous additions — they read the actual traced row at tick 48 through
  the same `TraceHarness` instrument the rest of the file already uses (not a
  hand-rolled shortcut), and I confirmed by running the suite that
  `test_airborne_actions` reports 24 checks passed (up from a lower count pre-delta,
  consistent with the 4 new assertions added: 2 per direction × 2 directions).
- **No production/data change** — confirmed via `git show 7389ff2 --stat`:
  the diff touches only `game/tests/test_airborne_actions.gd`. This matches
  the D2-refutation finding in `flags.md` (all three jump arcs already share
  one identical net-zero `vel_y` profile per JC-047; the "sometimes off
  floor" symptom is the separate, already-deferred AD-036/D3 aerial-float
  gap, not a per-direction arc bug) — the guard is pure regression hardening
  against a future edit desyncing one direction's arc from the others, not a
  fix for a live defect.

### Determinism (Tenet 1) — unaffected — **held**

- The new dummy sampler is an ordinary injected `Callable`, read only via
  `_sample_live()` inside `produce_next()` — the same seam every other
  device/replay/scripted source already uses. No wall-clock or `delta`
  dependency was introduced; `SimState.step` still advances purely from
  `(state, in1, in2)`. The jump-guard commit touches only test code. Combined
  with the unchanged `record_playback_source.gd`, this delta introduces no
  new determinism surface at all — it wires an existing seam, it does not add
  one.

### DP prose reconciliation (`spec/character-a.md`) — **PASS, data unchanged**

- Diff confirmed **prose-only**: the "Recovery (+land)" column header became
  "Recovery (base + tail)"; a new paragraph states the DP is a grounded,
  committed reversal with no vertical trajectory, uncoupled from AD-036/P2;
  "full landing recovery" → "full recovery duration" in the surrounding text.
  No numeric value in the table changed (`623L` 28+12, `623M` 30+12, `623H`
  33+14 — identical before/after).
- **Verified against the actual move builder, not just the spec text.**
  `_build_dp` in `content/character_a.gd`: `m.category =
  MoveState.CATEGORY_GROUNDED`; no `motion_vel_y` field is set anywhere in
  the DP timeline (the only `motion_vel_y` writes in the whole file are in
  the jump-arc builder, an unrelated code path). The DP has no rise
  mechanism to begin with — the prose now accurately describes what was
  already built, matching the user's Q1 ruling ("grounded, committed
  reversal... no data change").

### Trivial cleanup — DP active-keyframe comment — **done, folded in**

The stale comment at `content/character_a.gd`'s DP active keyframe read `# DP
leaves the ground; airborne-shaped hurtbox during active`, directly
contradicting the just-ruled grounded DP. This was a comment only — the
hurtbox value itself (`_hurt_air()`, a narrower profile than standing) is
correct and unchanged; the *reason* stated in the stale comment was wrong. I
reworded it to explain the real reason the narrower hurtbox is reused here
(the DP's extended-limb pose presents a smaller silhouette during active,
independent of whether the character is airborne) and to cite the grounded
ruling, so a future reader isn't misled into thinking this move rises. This
is the one edit I made to production-adjacent code in this audit, scoped
exactly as instructed (comment wording only, no behavior change) — verified
by re-running the full suite after the edit (still 31/31 green, since a
comment cannot change test outcomes, confirmed anyway for completeness).

### Independent full-suite run — **31/31 green, reproduced by me**

Ran all 31 suites in `run_tests.bat`'s list individually against the same
Godot binary the prior audit used, via `Start-Process -Wait -PassThru` (a
naive `&`-call with output redirection under-reported `$LASTEXITCODE` in this
shell — switched instruments mid-run rather than trust a falsely-green
signal). All 31 returned exit code 0. Did not rely on the "31 green" claim
already recorded on the prior audit or in commit messages for this delta.

## Judgment-call log — drift check (delta scope only)

- **JC-064** — ratified, correctly folded into AD-040 (verified above). Index
  line and body both flipped to `ratified` in `docs/judgment-log.md`.
- No other new judgment calls in this delta. Scanned the index tail (JC-060
  through JC-064) — nothing else provisional.

## Audit-criterion / charter legibility — objective half

The dummy-control fix is a pure operability completion — it makes an
already-specced capability (the record/playback dummy) actually reachable by
a human, which is squarely a **tax removal** (opacity/inoperability → fixed),
not a depth or difficulty change. Nothing was dumbed down: the dummy's
capability set is unchanged (still record-then-playback, still no AI), only
its reachability changed. The jump-guard addition and DP-prose fix are
test/documentation hygiene with no player-facing surface. I found no
boundary-case candidate (tax vs. cherished friction, knowledge-check risk)
in this delta worth routing to the Strategist.

## Human-inspection gate — still OPEN (I cannot and do not close this)

This is the **4th** re-gate per `flags.md`'s reconciliation flag (still
`[open]`, 2026-07-11 diagnosis update) and the roadmap's P1.1 declaration.
My objective pass on this delta is necessary, not sufficient. Recording the
explicit open items for the user's live session in `training_mode.tscn`:

- **Crouch-block via the now-controllable dummy.** Drive the dummy through
  the actual record→playback workflow (cycle to `RECORDING` on the `tm_dummy_*`
  keys, hold down-back, cycle to `PLAYBACK`) and confirm it visibly holds
  crouch-block, and that a human can then practice against it. I verified the
  headless round-trip; a human has not yet watched it happen on screen.
- **Clean jumps land flush, visibly, in all directions** (neutral/forward/
  back). I verified this sim-true (`py=0` at tick 48, all three directions,
  now test-guarded). Confirmed separately: the **aerial-interrupted float**
  (AD-036/D3, jump-in-normal-then-interrupted landings) is a **stated P2
  deferral, not a P1.1 failure** — per the user's own re-gate-3 ruling
  recorded in `flags.md`. The gate checklist item is specifically "does a
  *clean* (uninterrupted) jump land flush," not the deferred aerial case.
- **The two parked feel flags** (`flags.md`, both non-blocking, both still
  `[open]`, owner Strategist):
  - Frame-step auto-pause (whether `tm_step` should also pause, or stay a
    bare passthrough).
  - Jump apex-hang (the one-frame zero-velocity hang at the arc's peak —
    does it read acceptably, or does a future parabolic re-bake want a look).
  These are the user's feel calls to make or defer; not mine to rule on.
- **Controls legend readability** — the new dummy-workflow hint line and the
  seven new key entries are present in the legend text (confirmed by reading
  `controls_legend.gd`'s `_ACTIONS` array and `_DUMMY_WORKFLOW_HINT`
  constant), but whether the on-screen legend is actually legible at a glance
  with 7 more lines added is a rendering/legibility question only a human eye
  at the display can answer — folding this into the existing legend-legibility
  scope of the human gate rather than raising it as a separate item.

**I am not issuing a "done" verdict for P1.1.** Per protocol, only the user
closes this gate, at the 4th re-gate. My verdict on this delta specifically
is: **audit-passed, pending human inspection** — consistent with, and now
completing the objective side of, the standing P1.1 gate.

## Flags raised

None. This delta introduced no implementation defect, spec gap, or drift
requiring a new flag. The one procedural wrinkle (the source-wiring diff
landing under a differently-named commit) was already self-disclosed by the
commit message and I verified its content directly rather than needing to
raise it — no action item follows from it beyond the note above, since the
history is honest about what happened and the content is correct.

## Files touched by this audit

- `docs/audits/audit-p1.1-r2-delta.md` (this file — new)
- `game/content/character_a.gd` (comment-only edit: reworded the stale DP
  active-keyframe comment that implied a rise, per the cleanup folded into
  this audit's scope — no behavior change, re-verified green after edit)
