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

---

## Provisional (awaiting ratification)

> Full bodies of not-yet-ruled calls live here until the Architect ratifies or
> overturns them; then the status flips and the Strategist sweeps the body to the
> archive. New entries append to this section.

*(none — all recorded calls are ratified/closed; their bodies are in `judgment-log-archive.md`.)*
