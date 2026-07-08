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
- JC-044 · 2026-07-08 · TKT-P1.1-01 · AD-035 render framing implemented as a position/scale transform on `GeometryOverlay` itself (not a `Camera2D`); exact zoom/ground-line/margin constants and fixed placeholder stage bounds (not a live seam read) — provisional
- JC-045 · 2026-07-08 · TKT-P1.1-02 · Control-surface key bindings (P/N/C/R/M/J/K/L), a single cycling key for the dummy mode-switch (not three mode keys), frame-step bound as a direct passthrough with no auto-pause, and a static-InputMap-reading `ControlsLegend` node — provisional
- JC-046 · 2026-07-08 · P1.1 gate flag (arrow-key left/right) · Wired `STATE_WALK_F`/`STATE_WALK_B` into `character_a.gd`'s `button_map` as pure-direction commands (AD-032 pattern, mirroring jump) — these states/keyframes were already authored but unreachable from any input; button_index=-1 entries listed after the standing normals so a button always wins over a bare directional hold — provisional
- JC-047 · 2026-07-08 · P1.1 gate flag (player sinks below the floor) · Jump arc's 22-rise/23-fall frame split (equal magnitude both halves) nets +6 units of permanent downward drift every jump; fixed to 22 rise / 1 zero-velocity apex hang / 22 fall (nets exactly zero) rather than changing either tuned speed value — provisional
- JC-048 · 2026-07-08 · TKT-P1.1-03 · AD-034's fail-fast guard implemented as `push_error` + `from_dict` returning `null` on an unrecognized `"v"` (rather than raising/crashing or returning a still-parsed state); new dedicated test file `test_serialization_version.gd` (mirrors `test_sim_state.gd`'s SceneTree-runner shape) — provisional

---

## Provisional (awaiting ratification)

> Full bodies of not-yet-ruled calls live here until the Architect ratifies or
> overturns them; then the status flips and the Strategist sweeps the body to the
> archive. New entries append to this section.

### JC-044 · 2026-07-08 · TKT-P1.1-01 (Part B, AD-035 render framing) — provisional

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

### JC-045 · 2026-07-08 · TKT-P1.1-02 (control surface: bindings, dummy-mode-switch shape, legend) — provisional

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

### JC-046 · 2026-07-08 · P1.1 gate flag (arrow-key left/right movement does nothing) — provisional

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

### JC-047 · 2026-07-08 · P1.1 gate flag (player sinks ~5px below the floor on landing) — provisional

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

### JC-048 · 2026-07-08 · TKT-P1.1-03 (AD-034 fail-fast mechanism; new test file) — provisional

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
