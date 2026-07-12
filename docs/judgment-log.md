# Judgment-Call Log

> Owned by the **Developer** (appends entries); the **Architect** ratifies or
> overturns each at least once per feature, before audit (protocol cadence).
> Written for other roles to pick up: QA reads it for drift, the Architect to
> fold ratified calls into the spec, future work to inherit decisions instead of
> re-deriving them. Every entry is a *latitude* call — how to build something the
> spec already decided *what* it is. Anything touching a contract, feel, or tenet
> is a flag (`flags.md`), not an entry here.
>
> **This file is fronted by an index and holds only _provisional_ (unratified)
> bodies.** Closed entries — ratified, overturned, or superseded — live verbatim
> in `judgment-log-archive.md`; pull one by JC-id from the index below (Read by
> offset, or Grep the id). Do not read the archive whole. This keeps the
> cold-start read flat however long the decision history grows — the token-economy
> reason is in `protocol.md`.
>
> **Maintaining it (same shared-write split as the log itself):** the Developer,
> appending an entry, writes its body under "Provisional" **and** adds its index
> line (status `provisional`); the Architect, ruling, flips that entry's status to
> `ratified`/`overturned` in the body **and** on its index line; the Strategist
> moves closed bodies to `judgment-log-archive.md` on the per-session ledger sweep
> (the index line stays here, its status token now marking it archived). Status
> values: **provisional · ratified · overturned · superseded**.

---

## Index — every judgment call

> One line per entry, in log order. A `provisional` entry's body is under
> "Provisional" below; every other status means the body is in
> `judgment-log-archive.md` — pull it by id.

- JC-001 · 2026-07-02 · TKT-P0-01 · `FP` as a static-function class — ratified
- JC-002 · 2026-07-02 · TKT-P0-01 · `to_int` truncates toward zero; `round_to_int` is the AD-014 rounding rule — ratified
- JC-003 · 2026-07-02 · TKT-P0-01 · 64-bit product overflow left unguarded, documented — ratified (behavior) + contract fixed in AD-014
- JC-004 · 2026-07-02 · TKT-P0-01 · Tick host advances against a minimal seam, not real `SimState`/`step` — ratified (01→03 ordering ruled intended)
- JC-005 · 2026-07-02 · TKT-P0-01 · Headless `SceneTree` test runners with exit-code gating — ratified
- JC-006 · 2026-07-02 · TKT-P0-02 · `InputFrame` value is a plain masked `int`, class is a namespace — ratified
- JC-007 · 2026-07-02 · TKT-P0-03 · Canonical state hash is FNV-1a over an ordered integer value stream — ratified into spec (AD-023)
- JC-008 · 2026-07-02 · TKT-P0-03 · `InputHistory` capacity CAP = 32 frames — ratified
- JC-009 · 2026-07-02 · TKT-P0-03 · Input sources sampled parent-before-child via tree order in the scaffold — ratified (ordering now an owned invariant via F-001)
- JC-010 · 2026-07-02 · TKT-P0-04/05 · Inspection views + serialized-state backing fields packaged as plain-data classes — ratified (packaging latitude; the SimState fields were F-002/AD-024)
- JC-011 · 2026-07-02 · TKT-P0-05 · "First actionable frame" for derived recovery = duration+1 (recovery = total − last_active) — ratified INTO the spec
- JC-012 · 2026-07-02 · TKT-P0-07(pre-wired at 05) · Live-advantage party identification reads defender = the player in stun — ratified INTO the spec
- JC-013 · 2026-07-02 · TKT-P0-06 · Phase pipeline packaged as a `StepPhases` static module; each AD-009 phase a named function — ratified
- JC-014 · 2026-07-02 · TKT-P0-06 · `_enter_state` puts a freshly-entered state ON frame 1 this tick; phase 2 skips the advance for a same-tick entry — ratified
- JC-015 · 2026-07-02 · TKT-P0-06 · SOCD default (LR→neutral, UD→up) + facing resolution as one `resolve_intent`; raw stays raw in history — ratified into spec
- JC-016 · 2026-07-02 · TKT-P0-07 · Damage scaling as a single `DamageScaling` definition (hit-count table); the done-bar's single hit is unscaled 100% — ratified
- JC-017 · 2026-07-02 · TKT-P0-06 · Pushbox mutual separation splits the overlap in half, odd remainder to player 1 (deterministic) — ratified
- JC-018 · 2026-07-02 · TKT-P0-07 · `neutral_restored_this_tick` is a RISING EDGE: both-actionable now AND not both-actionable at the start of this tick — ratified into spec (AD-025)
- JC-019 · 2026-07-02 · TKT-P0-06 · A looping state wraps `frame_in_state` modulo its duration — ratified
- JC-020 · 2026-07-03 · F-006 (test fix) · `test_inspection_view` reads hitstop_remaining against the sim's own post-step value, and pins the corrected constant (3→2) — ratified (test-only latitude)
- JC-021 · 2026-07-03 · F-007 (test fix) · `test_combat` phase-presence check uses `Callable(StepPhases, name).is_valid()` instead of instance `has_method` on the class — ratified (test-only latitude)
- JC-022 · 2026-07-03 · TKT-P0-08 · Motion recognition = greedy ordered-token scan over the 9-frame window; a motion-id→token-sequence table — ratified
- JC-023 · 2026-07-03 · TKT-P0-08 · A CancelRule's `input` command is resolved via the button_map entry whose target == the rule target (raw-button fallback); group targets deferred — ratified
- JC-024 · 2026-07-03 · TKT-P0-09 · Throw tech-window length authored via the throwbox's (otherwise-unused) `blockstun` field; tech = undo-damage-both-to-idle — overturned (folded into AD-029: dedicated `HitBox.tech_window`)
- JC-025 · 2026-07-03 · TKT-P0-09 · Rehit cadence via a parallel `active_hit_frames` run + produced-tick comparison; clash detected when both throwboxes connect the same tick — ratified
- JC-026 · 2026-07-03 · F-011 (test fix) · `_test_cancel_requires_tag` isolates the tag gate to LIGHT's COMMITTED window; adds a gate-liveness assertion — superseded by JC-027
- JC-027 · 2026-07-03 · F-011 recurrence (test fix) · `_test_cancel_requires_tag` gate isolation via committed-window CONTRAST + positive control — ratified (test-only latitude) — SUPERSEDES/CORRECTS JC-026
- JC-028 · 2026-07-03 · AD-024 / F-009 (simulation.md crit 11) · `MoveRegistry` install-generation token packaged as a static `int` counter with an `install_generation()` accessor — ratified
- JC-029 · 2026-07-03 · simulation.md crit 11 · The crit-11 install-generation assertion lives in `test_sim_state.gd` — ratified (test-only latitude)
- JC-030 · 2026-07-04 · TKT-P1-04 · `RecordPlaybackSource` production model: one `produce_next()` per tick feeding a uniform `_answers` reproducibility history, distinct from the mode-specific `_buffer` script — ratified
- JC-031 · 2026-07-04 · TKT-P1-03 · `TrainingHarness` (new class) owns snapshot/restore + the single reset slot, sits above `TickHost`, and is the "driver" that produces registered dummies before stepping — ratified
- JC-032 · 2026-07-04 · TKT-P1-0P · Authored projectile shell named `ProjectileData` (not `Projectile`), resolved through a new `ProjectileRegistry` by `data_id` — mirrors `Character`/`MoveRegistry` exactly — ratified INTO the spec (AD-030)
- JC-033 · 2026-07-04 · TKT-P1-0P · Spawn fires once on the exact tick a spawning keyframe's range is ENTERED (`frame_in_state == frame_start`), not once per covered frame — ratified INTO the spec (AD-030)
- JC-034 · 2026-07-04 · TKT-P1-0P · A projectile does not integrate (move) or age (lifetime decrement) on the same tick it spawns — mirrors the existing `was_frozen` hitstop convention — ratified INTO the spec (AD-030)
- JC-A-01 · 2026-07-04 · TKT-P1-10 · Jump arc authored as a hand-baked triangular vel_y profile (no gravity primitive) — ratified
- JC-A-02 · 2026-07-04 · TKT-P1-10 · Six concrete `CancelRule`s per cancellable normal, not one group-targeted rule — ratified
- JC-A-03 · 2026-07-04 · TKT-P1-10 · DP blockstun authored as a small placeholder value, not back-solved to the spec's approximate on-block number — ratified
- JC-A-04 · 2026-07-04 · TKT-P1-10 · Air-normal hitstun authored as one flat value, not height-dependent — ratified (mechanism scope raised as F-014)
- JC-A-05 · 2026-07-04 · TKT-P1-10 · `2L` authored to hitstun 15 (internally consistent), not back-solved to the spec's stated +3 on-hit — ratified (spec fixed to +6)
- JC-035 · 2026-07-04 · TKT-P1-11 · `HitBox.is_throw` reconciled to `hit_kind` as a computed property — ratified
- JC-036 · 2026-07-04 · TKT-P1-11 · dev-test scenarios state-inject a non-attacking invuln state to isolate the phase-4 gate — ratified
- JC-037 · 2026-07-04 · TKT-P1-12 · `CancelEval._input_buffered` honors `CancelRule.input == 0` as "no input gate" — ratified INTO the spec
- JC-038 · 2026-07-04 · TKT-P1-12 · PREJUMP's ALWAYS-cancel window moved to frame 3 (one frame before duration) — ratified with a spec note; off-by-one ruled intended
- JC-039 · 2026-07-04 · TKT-P1-13 · `AirHeightScaling`'s four provisional numbers — ratified
- JC-040 · 2026-07-04 · TKT-P1-05..09 · Recovering an interrupted Batch 3: verification approach + view/view-model split adopted as the batch's structure — ratified (view/view-model split adopted as a project-wide convention)
- JC-041 · 2026-07-04 · TKT-P1-05 · Missing `.tscn` scenes built; overlays auto-wired by duck-typed `set_source` convention — ratified
- JC-042 · 2026-07-04 · TKT-P1-06 · Projectile hitbox given its own draw color instead of a `hit_kind`-based BoxView split — ratified
- JC-043 · 2026-07-04 · TKT-P1-09 · Recognized-command projection reconstructs `InputHistory` from `PlayerView.input_history` to call the sim's own recognizer — ratified
- JC-044 · 2026-07-08 · TKT-P1.1-01 · AD-035 render framing implemented as a position/scale transform on `GeometryOverlay` itself (not a `Camera2D`); exact zoom/ground-line/margin constants and fixed placeholder stage bounds (not a live seam read) — ratified
- JC-045 · 2026-07-08 · TKT-P1.1-02 · Control-surface key bindings (P/N/C/R/M/J/K/L), a single cycling key for the dummy mode-switch (not three mode keys), frame-step bound as a direct passthrough with no auto-pause, and a static-InputMap-reading `ControlsLegend` node — ratified
- JC-046 · 2026-07-08 · P1.1 gate flag (arrow-key left/right) · Wired `STATE_WALK_F`/`STATE_WALK_B` into `character_a.gd`'s `button_map` as pure-direction commands (AD-032 pattern, mirroring jump) — these states/keyframes were already authored but unreachable from any input; button_index=-1 entries listed after the standing normals so a button always wins over a bare directional hold — ratified
- JC-047 · 2026-07-08 · P1.1 gate flag (player sinks below the floor) · Jump arc's 22-rise/23-fall frame split (equal magnitude both halves) nets +6 units of permanent downward drift every jump; fixed to 22 rise / 1 zero-velocity apex hang / 22 fall (nets exactly zero) rather than changing either tuned speed value — ratified
- JC-048 · 2026-07-08 · TKT-P1.1-03 · AD-034's fail-fast guard implemented as `push_error` + `from_dict` returning `null` on an unrecognized `"v"` (rather than raising/crashing or returning a still-parsed state); new dedicated test file `test_serialization_version.gd` (mirrors `test_sim_state.gd`'s SceneTree-runner shape) — ratified
- JC-049 · 2026-07-09 · TKT-P1.1R-01 · Trace-row exact field order/text encoding: `tick`, then `p0.*` over `{state,frame,cat,px,py,vx,vy,act,stun,sk,face}`, then `p1.*` (same order), then any requested optional fields; optional `boxes` renders as `KIND:x,y,w,h` entries `;`-joined per player — ratified (folded into trace-harness.md Contract 3)
- JC-050 · 2026-07-09 · TKT-P1.1R-01 · The inline-assert runner is a GDScript API (`TraceHarness.check`/`row_at`), not a parser for Contract 3's illustrated `P1:`/`assert tick=... field=...` text-DSL — ratified (GDScript API is the near-term assert host; text-DSL is illustrative-only + a deferred additive extension — folded into trace-harness.md)
- JC-051 · 2026-07-09 · TKT-P1.1R-01 · `InputScript` grammar edge cases: a repeated button letter in one token (e.g. `LL`) is accepted (idempotent OR); digit `0` and any character outside `1-9`/`L`/`M`/`H` is malformed; button letters are case-sensitive (no lowercase aliasing) — ratified (folded into trace-harness.md Contract 1)
- JC-052 · 2026-07-09 · TKT-P1.1R-01 · `InputScript.compile`'s hard-error boundary uses `assert(false, msg)` (mirrors `InputSource.validate`); added a non-asserting `InputScript.is_well_formed_token` as an additive testing hook, not part of Contract 1's `compile` signature — ratified (error-mechanism + additive-helper latitude)
- JC-053 · 2026-07-09 · TKT-P1.1R-01 · An empty/omitted P2 script defaults to neutral via `RecordPlaybackSource`'s existing empty-buffer-loops-neutral behavior, not an explicitly-compiled N-tick neutral buffer — ratified (observable P2 behavior matches Contract 2)
- JC-054 · 2026-07-10 · TKT-P1.1R-02 · A `Keyframe.spawn_offset_y` (fireball release point) reflected as a scalar-point negation (`new_y = -old_y`) rather than the box formula `-(y+h)` — ratified (point-form of AD-037's reflection; folded into AD-037)
- JC-055 · 2026-07-10 · TKT-P1.1R-02 · Orientation verified via direct `InspectionView`/`PlayerView` reads, not `TraceHarness`'s formatted `boxes` string; CROUCH exercised by direct state-injection, not scripted input — ratified (test-authoring latitude; same AD-011 surface)
- JC-056 · 2026-07-10 · TKT-P1.1R-03 · Crouch `button_map` entry placed immediately after the DOWN+button crouch normals (still before the walk entries) — ratified (authoring-order latitude; behaviorally identical)
- JC-057 · 2026-07-10 · TKT-P1.1R-03 · Crouch-block scenario verified via a direct `SimState.step` + `InspectionView` test, not `TraceHarness` (fixed 200-unit spawn gap has no position-override hook) — ratified (test-instrument latitude; reads AD-011 either way)
- JC-058 · 2026-07-10 · TKT-P1.1R-03 · `TestSupport` (P0 test character) gains a bare-RIGHT `button_map` entry -> `STATE_WALK` so `test_combat.gd`'s walk-integration test can hold AD-038's re-derivation — ratified (test-fixture latitude; holds under the AD-038 exit correction)
- JC-059 · 2026-07-10 · TKT-P1.1R-04 · Air-normal `CancelRule` window authored as `[1, JUMP_DURATION-1]` (frames 1..44 of the 45-frame arc), not `[1, JUMP_DURATION]` — ratified (true reachable window; folded into AD-039)
- JC-060 · 2026-07-10 · TKT-P1.1R-04 · `PREJUMP_F`/`PREJUMP_B` factored through a shared `_build_prejump(state_id, target)` builder; new state ids (160/161) placed outside the full 100-109 movement block rather than renumbering existing ids — ratified (data-structure/id-allocation latitude)
- JC-061 · 2026-07-10 · TKT-P1.1R-04 · `test_character_a.gd::_test_no_gatlings_no_jump_cancels` updated to exempt `JUMP_N/F/B` (source) and `PREJUMP_F/B` (source) from the pre-existing gatling/jump-cancel guards, since AD-039 makes a jump state's ALWAYS-cancel into `j.L/M/H` (and each prejump's into its jump) sanctioned content, not a violation the guard was meant to catch — ratified (test-guard latitude; JC-058 class)
- JC-062 · 2026-07-10 · TKT-P1.1R-05 · The two-tier loop-state branch implemented as two SEPARATE full `button_map` scans (`_buffered_discrete_command` / `_current_tick_loop_command`, each first-match-wins in authored order) rather than one combined scan branching per-entry on `target.loop`; a new `InputBuffer.entry_satisfied_now` (age-0-only recognizer, motion entries always false) backs tier 2 instead of reusing `entry_satisfied` with a window param of 1 — ratified (faithful realization of corrected AD-038; current-tick/motion clarification folded into AD-038)
- JC-063 · 2026-07-10 · TKT-P1.1R-05 · AD-022 regression guard test uses direct `SimState.step` + `PlayerState` state-injection into `STATE_HITSTUN` (mirrors JC-057/JC-036), not `TraceHarness`; walk/crouch release-timing goldens re-baselined to the corrected release-tick values in `test_held_input_stances.gd` (ticket-named surgical scope — no other test file's assertions changed) — ratified (test-instrument latitude; surgical golden scope confirmed)
- JC-064 · 2026-07-11 · TKT-P1.1R2-01 · Dummy given a DEDICATED live sampler (`_sample_device_dummy`, new `tm_dummy_up/down/left/right/button_0/1/2` actions on WASD+U/I/O) rather than reusing `_sample_device_p1`'s key set; P1's passthrough source is untouched and left mirroring the SAME device the whole time (no "hold P1 neutral" mechanism needed) — ratified (operability latitude under AD-040; folded into AD-040)
- JC-065 · 2026-07-11 · TKT-P1.1R3-01 · Dummy-mode indicator built as `scenes/dummy_mode_indicator.gd` (sibling to `ControlsLegend`, outside `scenes/overlays/`), one Label + a static `build_indicator_text`, refreshed every `_process` frame rather than on `TrainingMode.ticked` — ratified (folded into AD-041)
- JC-066 · 2026-07-11 · TKT-P1.1R3-01 · Fresh-record implemented as a new `RecordPlaybackSource.reset_playback_cursor()` primitive, invoked from `TrainingMode.set_dummy_mode` guarded on the PASSTHROUGH/PLAYBACK -> RECORDING transition (not `_cycle_dummy_mode`, so a direct `set_dummy_mode` call also gets fresh-record) — ratified (folded into AD-041)
- JC-067 · 2026-07-11 · TKT-P1.1R3-02 · AD-042's grounded-entry snap placed INSIDE the shared `_enter_state` helper (widened to take `next: SimState` for `stage.ground_y`) rather than as a separate post-transition pass in `phase2_state_machine` — ratified (folded into AD-042: hook point pinned to the shared `_enter_state` helper, all transitions)

---

## Provisional (awaiting ratification)

> Full bodies of not-yet-ruled calls live here until the Architect ratifies or
> overturns them; then the status flips and the Strategist sweeps the body to the
> archive. New entries append to this section.

### JC-065 · 2026-07-11 · TKT-P1.1R3-01 · Dummy-mode indicator placement + refresh mechanism — ratified
**Decision.** Built the AD-041 mode indicator as a new file, `scenes/dummy_mode_indicator.gd`
(`class_name DummyModeIndicator`), a plain `Control` with one `Label` child and one static,
Node-free text builder (`build_indicator_text(mode: int) -> String`) — mirroring
`ControlsLegend`'s exact shape (static builder, one Label, headlessly testable without a live
node). Placed as a **sibling of `ControlsLegend`** at `scenes/`, **not** under `scenes/overlays/`
— the overlays directory is reserved for `InspectionView`-backed readouts (training-mode.md's
"Readout layer"), and this indicator explicitly is **not** one (AD-041: "outside the
InspectionView seam, like ControlsLegend"), so it does not belong alongside them.
Refreshes every engine `_process(delta)` frame (a plain per-frame poll: read
`_source.get_dummy_mode(1)`, write the label text) rather than the `ticked`-signal-driven
pattern every other overlay (`FrameDataPanel`/`LiveStatePanel`/`InputHistoryPanel`) uses.
**Alternatives considered.** (a) Follow the `ticked`-signal convention exactly (refresh only on
a sim tick) — rejected: the dummy's mode changes via the `M` key **independent of ticking**
(`_cycle_dummy_mode` runs from `_unhandled_input`, not gated on the sim running), and a human
can cycle modes **while paused** (no tick fires) to set up a recording before stepping — under
the `ticked`-only convention the label would silently go stale exactly when a paused human is
most likely to be checking it, reproducing the "no live feedback" failure mode AD-041 exists to
close. (b) A `mode_changed` signal on the shell, emitted from `set_dummy_mode`/`_cycle_dummy_mode`
— cleaner (event-driven, no idle polling) but a real API addition to `TrainingMode` (a new public
signal other future callers would need to know about) for a single-consumer need; a `_process`
poll is one Label's cost and needs no shell change at all. **Why this reading.** The per-frame
poll is the cheapest correct fix for the "must reflect changes while paused" requirement, costs
nothing measurable (one dictionary lookup + a string write per frame), and needs zero shell-side
API surface — reversible to (b) later with no external-behavior change if a second consumer ever
wants the same event. **Scope/reversibility.** Entirely internal to `DummyModeIndicator`; no
contract, seam, or tenet surface. Log for ratification/QA awareness — the placement-outside-
`overlays/` choice in particular sets a naming/location precedent a second non-sim-truth
indicator would want to follow.

### JC-066 · 2026-07-11 · TKT-P1.1R3-01 · Fresh-record mechanism + invocation point — ratified
**Decision.** AD-041 offered two shapes ("using the existing `set_recorded_buffer([])` + cursor
reset, or a small `begin_fresh_recording` shell step"). Implemented as: (1) a new, minimal
`RecordPlaybackSource.reset_playback_cursor()` method (sets `_playback_cursor = 0` only — does
**not** touch `_produced_count`/`_answers`, unlike the existing `set_playback_position`, which
would also rewind those and desync the source from how many frames the driver has actually
produced); (2) orchestration inside `TrainingMode.set_dummy_mode(player_index, mode)` itself —
if `mode == RECORDING` and the source's **current** mode is not already `RECORDING`, call
`set_recorded_buffer(PackedInt32Array())` + `reset_playback_cursor()` **before** `set_mode(mode)`.
Placed in `set_dummy_mode` (not only in `_cycle_dummy_mode`, the `M`-key handler) so a **direct**
`set_dummy_mode(i, RECORDING)` call (e.g. from a test, or a future non-keyboard driver) also gets
fresh-record — the shell has exactly one entry point into a mode change, and fresh-record is a
property of "entering RECORDING," not of "the cycle key specifically."
**Alternatives considered.** (a) Reuse `set_playback_position` with a hand-built dict resetting
only `playback_cursor` to 0 while re-supplying the CURRENT `produced_count`/`answers` — works, but
piggybacks on a method documented for a different purpose (restoring a captured position) and
reads less clearly at the call site than a dedicated one-line primitive. (b) Put the guard only in
`_cycle_dummy_mode` — rejected per the "keep exactly one entry point" reasoning above; it would
create two divergent RECORDING-entry behaviors depending on which method a caller used.
**Why this reading.** A dedicated single-purpose method is the smallest primitive that does
exactly what AD-041 asks (clear buffer + rewind cursor, nothing else), keeps
`RecordPlaybackSource`'s existing primitives (`RECORDING` appends; `set_playback_position`
restores a full position) untouched and undocumented-behavior-free, and the `set_dummy_mode`
placement matches AD-041's own words ("orchestrated in the shell — `_cycle_dummy_mode` /
`set_dummy_mode`"). **Scope/reversibility.** `reset_playback_cursor()` is a small, additive
`RecordPlaybackSource` method (no existing behavior changed); the guard is a few lines in
`set_dummy_mode`. Log for ratification.

### JC-067 · 2026-07-11 · TKT-P1.1R3-02 · AD-042 grounded-entry snap hook point — ratified
**Decision.** Placed the ground-contact landing snap **inside the shared `_enter_state` helper**
in `step_phases.gd` (widened its signature from `_enter_state(p, character, state_id)` to
`_enter_state(next: SimState, p, character, state_id)` so it can read `next.stage.ground_y`),
rather than as a separate check run after each of `phase2_state_machine`'s six `_enter_state`
call sites. The snap reads the **target** state (`character.get_state(state_id)`) and, if its
category is `CATEGORY_GROUNDED` and `p.pos_y != next.stage.ground_y`, sets `p.pos_y =
next.stage.ground_y` — placed after `_enter_state`'s existing bookkeeping resets (hit-id/contact/
cancel-tag clears), so it runs unconditionally on literally every state transition in the sim
(idle, walk, crouch, normals, specials, throws, reactions — not just jump-related ones).
**Alternatives considered.** (a) A dedicated helper (`_snap_to_ground_on_grounded_entry`) called
individually at each of the 10 call sites — rejected: `_enter_state` is already the single,
unconditional "a state transition just happened" hook every call site already funnels through
(AD-001's "one state-machine pattern" spirit extended to this correction); duplicating the check
at 10 call sites is strictly more code with more chances to miss one (e.g. a future 11th call
site added without the paired snap call). (b) A check scoped only to the airborne-related
call sites (the once-through-ended and cancel branches phase2 uses for jumps/air-normals) —
rejected: AD-042 explicitly wants a GENERIC, category-driven rule ("on entry to any
GROUNDED-category state"), not a jump-specific patch; scoping it narrower would silently miss
a future grounded transition from an unexpected source (e.g. a knockdown-recovery state, P2)
that also needs the invariant. **Why this reading.** `_enter_state` is the one place `state_id`/
`frame_in_state`/velocity/hit-memory are reset together for a transition — the natural single
point to also reconcile height, and it is trivially character-agnostic (reads only the target's
authored `category` + the stage's `ground_y`, per AD-042's own text). Widening the private
static helper's signature is internal packaging (no `SimState.step`, `MoveState`, or any
documented contract signature changes) — every call site already had `next: SimState` in local
scope, so the change is mechanical. **Category-edge note.** No category besides `GROUNDED`
triggers the snap (an `AIRBORNE`-entry, e.g. a jump's own re-entry into another jump variant,
correctly does NOT snap — verified by the widened harness coverage: the mid-arc position is
untouched while airborne). **Scope/reversibility.** Confined to `step_phases.gd`'s private
`_enter_state` and its 10 call sites (all in the same file); no public signature, format, or
seam surface changes. Log for ratification.

