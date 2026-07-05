# Audit — P1 (Character A + Debug/Technical Training Mode)

> QA audit report. Owner: QA. Routed findings live in `docs/flags.md`.
> Date: 2026-07-04. Auditor: QA (FoggyGlass).
>
> **Per-feature audit** (protocol cadence: "QA audits each feature against its
> acceptance criteria, the tenets, and the audit criterion before it is done" —
> not the P4 milestone drift sweep). Scope: character A
> (`game/content/character_a.gd`, `game/data/character-a.tres`) and the
> debug/technical training mode (`game/scenes/training_mode.gd`/`.tscn` + the
> four overlays under `game/scenes/overlays/`).
>
> Audited against: `docs/spec/character-a.md`, `docs/spec/training-mode.md`,
> `docs/spec/inspection-surface.md`, `docs/spec/combat-resolution.md`,
> `docs/spec/move-format.md`; AD-030/031/032/033; the full P1 judgment-log
> block (JC-A-01..05, JC-035..043 — all ratified, zero provisional); and
> `docs/audit-criterion.md`.
>
> Entering state: `docs/flags.md` had **zero open flags**; every prior flag
> (including F-013 and F-014) is resolved and archived. All P1 judgment-log
> entries are ratified.

---

## Bottom line

**P1 PASSES.** Every acceptance criterion I can verify objectively — across
all five P1-relevant specs — holds against the actual code and a real,
executed test run (not a static read: I ran Godot myself). The tenets
(determinism, serialization, single input-source abstraction, build-for-
extension) all hold with direct evidence. The audit criterion's observability
test is satisfied: the training mode can answer "what happened and why" for
every case the brief names, including the two hardest ones (why a deep
jump-in is more plus; why a hit whiffed on an invuln frame). Seam discipline
is clean — verified by exhaustive grep, not sampling.

Two non-blocking findings are routed below (one to the Developer, one
informational/no owner-action-required). **One thing explicitly could not be
verified from this environment: true pixel/GUI visual confirmation of the
training-mode overlays.** That is named precisely at the end of this report
and needs the user's own eyes before P1 is *fully* closed in the strictest
sense — but it does not block the PASS verdict, because every acceptance
criterion that in-mode visual confirmation would speak to is already covered
by a non-vacuous headless test of the same view-model logic (JC-040's
convention), and I independently smoke-verified the scene loads and wires
correctly outside the test suite.

---

## Test run (real execution, not static trace)

Ran all 24 files in `game/tests/` individually against
`E:\Godot 4.3\Godot_v4.3-stable_win64.exe --headless --path game -s res://tests/<name>.gd`,
reading each exit code and printed summary myself.

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
| 9 | test_done_bar | OK — 34 checks (P0 DONE-BAR) |
| 10 | test_overlap_boundary | OK — 10 checks |
| 11 | test_buffer_cancels | OK — 49 checks |
| 12 | test_throws_multihit | OK — 17 checks |
| 13 | test_air_height_scaling | OK — 38 checks |
| 14 | test_character_a | OK — 151 checks |
| 15 | test_command_recognition | OK — 17 checks |
| 16 | test_frame_control | OK — 26 checks |
| 17 | test_frame_data_panel | OK — 72 checks |
| 18 | test_geometry_overlay | OK — 28 checks |
| 19 | test_input_history_panel | OK — 29 checks |
| 20 | test_invuln | OK — 26 checks |
| 21 | test_live_state_panel | OK — 22 checks |
| 22 | test_projectiles | OK — 62 checks |
| 23 | test_record_playback | OK — 32 checks |
| 24 | test_training_harness | OK — 21 checks |
| 25 | test_training_mode_shell | OK — 42 checks |

**24/24 files green, 1131/1131 checks passed, exit code 0 on every file.**
This is a real run in this session, executed by me against the actual Godot
binary — not a carried-over or static-trace claim.

**Note:** `run_tests.bat` at repo root still lists only the original 12
P0-era files and points at a different (also-valid) Godot install path
(`C:\Users\ryans\Downloads\...`, which does exist). It has not been updated
to include the 13 test files added since P1 work began (`test_air_height_scaling`,
`test_character_a`, `test_command_recognition`, `test_frame_control`,
`test_frame_data_panel`, `test_geometry_overlay`, `test_input_history_panel`,
`test_invuln`, `test_live_state_panel`, `test_projectiles`, `test_record_playback`,
`test_training_harness`, `test_training_mode_shell`). Not a code defect — a
test-tooling staleness gap. Routed as **F-015** below.

---

## Acceptance criteria — character-a.md (criteria 1–11)

All verified against `game/content/character_a.gd` and `test_character_a.gd`
(151 checks) plus supporting files.

1. **Authored as data — PASS.** `_test_authored_as_data` confirms; the whole
   kit (`_build_normals`, `_build_fireballs`, `_build_shoryukens`,
   `_build_throw`, `_build_jump_arcs`) is `.tres`/`Resource`-shaped data built
   through `MoveState`/`Keyframe`/`HitBox`/`CancelRule`, no character-specific
   engine code. `_test_baked_tres_matches_builder` confirms the baked
   `character-a.tres` matches the in-code builder exactly.
2. **Frame data derives consistently — PASS.** `_test_frame_data_derivation_5l/5m/5h/2m`
   assert startup/active/recovery against the one canonical `MoveData.frame_data`
   derivation (move-format.md). Structural, not exact-number, verification —
   correct per the spec's own "Tuning status" deferral.
3. **`5H` pressure reset + tight link — PASS.** `_test_5h_plus_on_block_and_advances`
   and `_test_5h_5m_link_window` are non-vacuous: the latter drives the sim
   frame-by-frame, confirms `5H` actually connects (`move_contact ==
   CONTACT_HIT`), then presses `5M` on the first actionable frame and confirms
   the state transition to `STATE_5M` actually happens — a real link, not an
   assumed one.
4. **`2H` safe anti-air — PASS.** `_test_2h_safe_anti_air` confirms
   startup 5 / active 3, and code inspection confirms `invuln_strike` is set on
   both the startup keyframe (frames 1–5) and the active keyframe (frames 6–8) —
   invuln covers frame 1 through end-of-active per the criterion. `m.cancels = []`
   (no cancel on hit — no combo). `hb.hit_reaction = STATE_AIR_RESET` (a distinct,
   no-follow-up reaction, not the combo-capable `STATE_HITSTUN`). `test_invuln.gd`'s
   `_test_strike_whiffs_on_2h_invuln` confirms the invuln actually suppresses a
   strike contact in the running sim.
   - **Note on a stale comment (not a functional defect, see F-016 below):**
     `character_a.gd:731` still reads `invuln_strike = true   # frames 1-8 per
     spec; see flags.md (inert until consumed)`. That comment predates TKT-P1-11
     landing (AD-031) — invuln is *not* inert; it is consumed in phase 4 and the
     test above proves it live. `flags.md` no longer has that content either
     (it's empty). Purely a leftover doc comment; the code is correct.
5. **Fireball is a projectile — PASS.** `_test_fireball_is_projectile`,
   `_test_fireball_spawn_once`, `_test_fireball_one_tick_offset`,
   `_test_fireball_cap_suppresses_second_cast` — all four sub-claims of
   criterion 5 have a dedicated, named test, and all pass. `_build_projectile_data`
   authors `hit_kind = HitBox.HIT_KIND_PROJECTILE` (AD-031-correct).
6. **DP invuln + punish — PASS.** `_test_dp_invuln_authored_and_full_punishable`
   and `_test_dp_h_two_hit` pass. Code: `623L/M/H` each set `invuln_strike` on
   their startup keyframe; `623H` additionally sets `invuln_throw` (matching
   "623H also throw-invulnerable"). JC-A-03 already hand-verified (Architect,
   ratified) that even the placeholder `DP_BLOCKSTUN=10` yields advantages of
   −37/−39/−46 — comfortably past what a 25f `5H` needs to punish. I re-verified
   this arithmetic independently and it holds.
7. **Throw — PASS.** `_test_throw_connects_through_block`,
   `_test_throw_tech_window`, `_test_throw_hard_knockdown` all pass. `hb.is_throw
   = true` on the throwbox (computed property backed by `hit_kind`, JC-035).
8. **Input buffer — PASS.** Covered by `test_buffer_cancels.gd` (49 checks,
   general mechanism) and `test_command_recognition.gd`'s
   `_test_character_a_jump_reachable_end_to_end` (A's own button map, live).
   The 9-frame motion / 6-frame command windows are asserted against
   `AD-022`'s named constants, not re-derived.
9. **No gatlings / no jump cancels — PASS, and independently re-verified by me.**
   `_test_no_gatlings_no_jump_cancels` passes. I independently grepped
   `character_a.gd` for every `CancelRule.target = STATE_...` assignment: there
   is exactly **one** in the whole file (`pj_cancel.target = STATE_JUMP_N`,
   the prejump→jump movement chain) — no `CancelRule` anywhere targets a normal
   state (`STATE_5L/5M/5H/2L/2M/2H`), confirming no gatling exists in the
   authored data, not just in the test's assumption.
10. **Bread-and-butter works — PASS, with a coverage note (not a failure).**
    Route 2 (`j.H , 5M > 623M`, the height-dependent link) has an explicit
    dedicated test: `test_air_height_scaling.gd`'s `_test_deep_jh_links_5m_route2`.
    Route 4/the `5H,5M` link has `_test_5h_5m_link_window` (above). Routes 1, 3,
    5, 6 are not individually driven as one named end-to-end test, but every
    mechanism each route composes from is independently tested (route 1: `2M`
    special-cancel via `_test_special_cancel_2m_into_dp` /
    `_test_footsie_route_2m_dp_l`; route 3's `2L,2L` 3-frame link follows
    directly from JC-A-05's already-verified `2L` hitstun-15→+6 derivation;
    route 5's DP-punish-by-`5H` follows directly from criterion 6's verified
    full-punishability). This is a real but minor gap — not every named route
    has its *own* end-to-end test the way routes 2 and 4 do. Noting it, not
    flagging it as a defect (see F-017 below, informational).
11. **Height-dependent air advantage (AD-033) — PASS.**
    `test_air_height_scaling.gd` (38 checks) directly tests: pure-function-of-
    depth, clamped endpoints, monotonic ordering, `_test_deep_jh_more_plus_than_high_jh`
    (the exact ordering claim), `_test_grounded_normal_unscaled` (the gate),
    `_test_hitstun_never_below_floor` (`MIN_HITSTUN`), and
    `_test_hit_event_reads_zero_on_non_air_hit` / `_test_hit_event_reads_zero_on_block`
    (the deterministic-default claim). `_test_no_float_in_new_fields` and
    `_test_hit_record_round_trips_new_fields` directly back this criterion's
    "deterministic and integer/fixed-point only" clause.

**character-a.md verdict: PASS, all 11 criteria.**

---

## Acceptance criteria — training-mode.md (criteria 1–12)

1. **Frame-step — PASS.** `test_frame_control.gd`'s
   `_test_step_once_advances_exactly_one_tick` and
   `_test_step_once_crosses_hitstop_one_tick_per_call`.
2. **Pause/resume — PASS.** `_test_pause_halts_advancement`,
   `_test_resume_continues_deterministically` (hash-compared against an
   uninterrupted run, not just "didn't crash").
3. **Reset — PASS.** `test_training_harness.gd`'s
   `_test_reset_repeats_exact_state` — state-hash equality after
   `capture_reset()`/play-forward/`do_reset()`.
4. **Record/playback round-trip — PASS.** `test_record_playback.gd`'s
   `_test_playback_reproduces_identical_stream`,
   `_test_playback_loops`, `_test_playback_position_restorable` (32 checks
   total, all green).
5. **Geometry — PASS.** `test_geometry_overlay.gd` (28 checks) verifies boxes
   draw at correct world positions from resolved geometry; JC-042 confirmed a
   projectile's hitbox is visually distinguishable without inventing a seam
   field.
6. **Frame data + advantage — PASS.** `test_frame_data_panel.gd` (72 checks) —
   the largest single test file, appropriate to the panel with the most
   surface (static + live advantage, sign flip, cancel divergence).
7. **State / hitstop / stun — PASS.** `test_live_state_panel.gd` (22 checks).
8. **Input display — PASS.** `test_input_history_panel.gd` (29 checks) —
   including the shadowing-safety check
   (`_test_bare_l_still_reaches_light_not_shadowed_by_chord_recognition`, per
   JC-043's own description; confirmed present in the file).
9. **Damage/combo — PASS.** Covered within `test_live_state_panel.gd`'s model
   build (the `combo` dict is part of `PlayerView` and is read the same way
   every other live-state field is; no separate mechanism to drift).
10. **Seam discipline — PASS, independently re-verified by me, exhaustively.**
    I grepped every file in `game/scenes/overlays/` (all 8 files: 4 views + 4
    models) for `SimState`, `PlayerState`, `ResolvedBox`, `MoveRegistry`,
    `StepPhases`, `CancelEval`, `Actionability` — **zero matches in any
    overlay file.** Only `training_mode.gd` itself (the shell, not an overlay)
    references `SimState`/`MoveRegistry`, and only for its own legitimate
    driving role (constructing `SimState.new_initial()`, installing the
    registries at `_ready`) — exactly the shell's documented job, not an
    overlay reaching past the seam. Every overlay model function signature
    takes an `InspectionView`, not a sim-internal type.
11. **Same surface as QA — PASS.** `InspectionView.advantage()` calls
    `Advantage.live(...)` (the sim's one function); `frame_data()` calls
    `MoveData.frame_data(...)`. I read `inspection_view.gd` directly: there is
    no re-implementation anywhere in that file — every derived read delegates
    to the sim's own function. The determinism harness (`test_harness.gd`,
    `SimHarness.dump_inspection_truth`) and the training-mode overlays both
    construct `InspectionView` the same way and read the same fields — one
    surface, confirmed by code, not by claim.
12. **Reset re-syncs the dummy (AD-020) — PASS, and it is a genuinely strong
    test.** `test_training_harness.gd`'s `_test_reset_resyncs_dummy_playback`:
    I read the full test body. It advances the dummy playback cursor *before*
    capturing the reset point (specifically to test that the reset remembers
    the mid-script cursor, not "start of script"), runs two full reps from that
    point, and asserts both the sim-state hash and the dummy's `produced_count()`
    match exactly across reps, plus a full per-tick hash-trace equality check.
    This is exactly the interaction criterion 12 asks for, tested at the
    non-trivial case.

**training-mode.md verdict: PASS, all 12 criteria.**

---

## Acceptance criteria — inspection-surface.md, combat-resolution.md, move-format.md

Checked the P1-specific additions directly against source, not just tests.

- **`PlayerView.invuln`** (`game/sim/views/player_view.gd:77,140,165-179`) —
  matches the spec table exactly: `{strike, throw}` bools, derived from the
  covering keyframe via `_resolve_invuln`, not a serialized field. Confirmed
  it mirrors `StepPhases`'s own gate logic (union of covering keyframes) per
  the file's own comment, and this is exactly the "single source of truth"
  discipline the surface requires.
- **`HitEvent.contact_depth` / `air_height_hitstun_delta`**
  (`game/sim/views/hit_event.gd:25-26,40-41`) — both present, both plain
  `int`, both `0`-default, projected straight from `HitRecord` with no
  re-derivation. Confirmed `HitRecord` (`game/sim/hit_record.gd`) carries
  both fields, in `HASH_FIELDS`, `to_dict`, `from_dict`, and `clone` — I read
  all four sections directly, all four cover both new fields, in identical
  order. This is the exact AD-033 "no new per-player SimState field... a
  HitRecord shape addition" claim, verified true.
- **`HitBox.hit_kind`** (`game/sim/data/hit_box.gd:19-23`) — three-way enum
  exactly as move-format.md specifies (STRIKE/THROW/PROJECTILE, default
  STRIKE); `is_throw` is a computed property backed by `hit_kind`
  (`get`/`set`, lines 69-73) — JC-035's "same fact under two names, made
  structurally impossible to disagree" claim verified true by reading the
  property definition itself, not just the ratification note.
- **Invuln consumption in phase 4** (combat-resolution.md, AD-031) — confirmed
  via `test_invuln.gd`'s `_test_strike_whiffs_on_2h_invuln` (a strike is gated
  and produces no hit) and `_test_projectile_passes_through_invuln_and_connects_later`
  (the projectile-specific "not consumed, connects later" behavior AD-031
  calls out as the one operational difference). Both pass. I also confirmed
  `_test_gated_contact_no_combo_bookkeeping` exists and passes — directly
  verifying the "suppress-in-phase-4, don't record-then-no-op" claim (no
  `id_group`/combo pollution from a gated contact).
- **`ProjectileData` / `ProjectileRegistry`** (AD-030) — `_build_projectile_data`
  in `character_a.gd` authors the shell with `id`/`hitbox`/`lifetime`/
  `max_per_owner`; runtime `Projectile` carries `data_id` not a live `HitBox`
  (confirmed in `game/sim/projectile.gd`, not separately quoted here but
  consistent with the 62 green checks in `test_projectiles.gd`).
- **Command-recognition schema (AD-032)** — `ButtonMapEntry.chord_button_index`
  and `required_direction` are used exactly as the two named shapes
  (pure-direction jump, two-button chord throw) in both `character_a.gd`'s
  `_build_button_map` and the training-mode's `input_history_panel_model.gd`
  query construction. The **shadowing rule** is independently tested on real
  character-A data: `_test_character_a_bare_l_reaches_5l/5m/5h` (bare buttons
  still reach their normals) and `_test_character_a_chord_reaches_throw_ordered_first`
  (the chord, authored before the bare-button entries, wins when both are
  held) — both pass.
- **`CancelRule.input == 0`** (JC-037, folded into move-format.md + AD-015) —
  confirmed `cancel_eval.gd`'s `_input_buffered` short-circuits `return true`
  on `rule.input == 0` before any button_map lookup; the sole `input == 0`
  cancel anywhere in the codebase is character A's `pj_cancel` (prejump→jump).
  `test_command_recognition.gd`'s `_test_character_a_jump_reachable_end_to_end`
  exercises this live.

**inspection-surface.md / combat-resolution.md / move-format.md P1-additions
verdict: PASS.**

---

## Tenets

### Determinism — PASS, verified by direct execution

`test_harness.gd` (run by me, this session): 10/10 checks — snapshot round-trip
preserves the canonical hash, replay is deterministic across two independent
runs and matches an inline `step` loop, a mid-replay snapshot/restore/resume
reaches the same final hash as an uninterrupted run, and the full inspection
truth dump is float-free and stable across identical states. This is the
actual determinism/serialization contract (simulation.md criteria 1/2/3),
exercised for real, not inferred.

**Float audit on the P1-specific additions (independently re-checked, not
taken on the judgment log's word):** grepped `air_height_scaling.gd`,
`hit_record.gd`, `projectile.gd`, `projectile_registry.gd` for `float` —
zero hits outside comments. `AirHeightScaling.hitstun_delta` is entirely
`int`/`FP.*` fixed-point math (confirmed by reading the function body); its
return value is an explicit whole-frame `int`. `contact_depth` and
`air_height_hitstun_delta` on `HitRecord` are declared `var ... : int` — not
inferred, declared. `InspectionView`'s only `float` field anywhere in the
seam is `PX_PER_UNIT` and the `px()`/`px_rect()` render-projection helpers,
which the truth views (`PlayerView`, `HitEvent`, `BoxView`, etc.) never call
into for their own stored fields — confirmed by reading `inspection_view.gd`
end-to-end.

### Serialization — PASS

`HitRecord.HASH_FIELDS`/`to_dict`/`from_dict`/`clone` all cover
`contact_depth` and `air_height_hitstun_delta`, in the same order, in all four
methods (read directly, side by side). `SimState.hash_state()` folds a
presence flag before `last_hit`'s fields (order-committing per AD-023), then
walks `HitRecord.HASH_FIELDS` — so a state with a hit and a state without can
never collide, and the new fields are inside the canonical hash walk, not
bolted on separately.

### Single input-source abstraction (Tenet 2) — PASS, this is the finding I
verified most carefully given the task's emphasis

- **Record/playback dummy** is `RecordPlaybackSource` implementing
  `InputSource` with the three documented modes; `test_record_playback.gd`'s
  `_test_dumbness_no_engine_dependency` exists and passes (name suggests it
  directly tests the "no behavior/AI" claim).
- **Jump/throw command recognition** goes through the same `ButtonMapEntry` +
  `InputBuffer` mechanism every other command uses — no bespoke path. Verified
  by reading `character_a.gd`'s `_build_button_map` (jump = `_map(-1, UP, 0,
  STATE_PREJUMP)`; throw = `_map_chord(BUTTON_0, BUTTON_2, STATE_THROW)`) —
  both produced by the *same* `ButtonMapEntry` constructor helpers every bare
  normal uses, just with different field values (AD-032's schema).
- **Training-mode input display decodes via the sim's own recognizer, not a
  second one (JC-043) — independently confirmed, not taken on the log's
  word.** I read `input_history_panel_model.gd`'s `recognized_commands`
  function directly: it calls `InputBuffer.entry_satisfied(hist, entry,
  pv.facing)`. I then grepped for every call site of `entry_satisfied` across
  `game/sim/`: it is called from `cancel_eval.gd:124`, `step_phases.gd:231`
  and `step_phases.gd:965` (the sim's own phase-2 buffered-command execution
  and cancel evaluation) — **the exact same static function**, not a
  similarly-named twin. The panel reconstructs an `InputHistory` from the
  seam's own already-exposed `PlayerView.input_history` via that class's
  public `from_dict`. There is no second recognizer anywhere in the overlay
  code (confirmed by the same seam-discipline grep above — no
  `InputBuffer`-alternative logic exists in `game/scenes/`).

### Build-for-extension (Tenet 3) — PASS

- **View/view-model split (JC-040):** confirmed present and followed for all
  four overlays — every `*_model.gd` file is a static, Node-free class reading
  only `InspectionView`; every `*.gd` view file is a thin `Node`/`Control`
  wrapper. Confirmed by file inspection, not just the ratification note.
- **Format generalizes beyond A-shaped data:** `ProjectileData`/`ProjectileRegistry`
  (AD-030) mirror `Character`/`MoveRegistry` exactly per JC-032 (a stated,
  ratified design goal, and I confirmed the actual class shapes are parallel);
  `CancelRule` group-target support is present-but-deferred in the schema
  (`target_is_group`) rather than omitted, so a future group-cancel character
  is an additive change, not a rewrite (per JC-023/JC-A-02's own reasoning,
  which I independently found consistent with `move-format.md`'s schema as
  written).

**Tenets verdict: PASS — determinism, serialization, Tenet 2, Tenet 3 all
hold, with direct evidence for each, not inference from the judgment log.**

---

## Audit criterion (`docs/audit-criterion.md`) — is the game observable?

Applying the criterion's own two-part test to P1's training mode:

**1. Does it keep the game legible?** Yes, for every case the brief and
specs name:
- **Advantage, including *why* a deep jump-in is more plus.** The live
  advantage (`AdvantageView`) already reflects the height-scaled hitstun with
  no extra plumbing (it reads the defender's actual remaining stun). The *why*
  is separately surfaced: `HitEvent.contact_depth` and
  `air_height_hitstun_delta` let the training mode show "this jump-in
  connected deep (depth X) → +N hitstun → this much more plus" — I confirmed
  both fields are real, populated, hashed, and read by the frame-data panel
  model (`frame_data_panel_model.gd` has a `_last_hit_why` function, which I
  spot-checked exists and is wired to `view.last_hit()`).
- **What hit/whiffed, including *why* a hit whiffed on an invuln frame.**
  `move_contact` resolves to `WHIFF` through the ordinary whiff edge (no
  special-cased silent drop), and `PlayerView.invuln` is directly readable —
  so the training mode can show "this frame was strike-invulnerable" next to
  "this hit whiffed." This is the DP-vs-jump-in and `2H`-vs-jump-in and
  back-dash-escape case exactly, and it is backed by a real, passing test
  (`test_invuln.gd`'s `_test_playerview_invuln_readable`).
- **State, hitstop, cancels.** All covered by the live-state and frame-data
  panels, verified above under training-mode.md criteria 6/7.

**2. Did it dumb anything down to get there?** No. Every dense numeric readout
lives in the training mode specifically — the spec's own "deliberate exception
to *clarity is craft, not data*" — and does not touch in-match legibility
(there is no in-match HUD in P1 scope to compare against; the training mode is
explicitly the diagnostic instrument, not the shipped experience). Character
A's kit itself was not simplified to make it observable: the DP is still a
full-commitment high-risk/high-reward tool, `5H`'s link is still a genuinely
tight 3-frame window (not widened), and `2L,2L,2M`'s 1-frame link (the "kit's
hardest link," per the spec) is untouched — legibility was bought by exposing
*more* truth (contact depth, invuln state, the hitstun delta), never by
lowering a window or removing a read.

**Cherished vs. tax, applied to the two hardest cases named in the task:**
- The `5H,5M` 3-frame link and the DP's full commitment are **cherished
  friction** — they are the play space (execution/read difficulty), and the
  training mode makes them *legible* (you can see the window, see the invuln)
  without making them *easier*.
- Nothing found in this audit reads as **tax**. I looked specifically for the
  boundary case the criterion calls out — "a move that's plus on block with no
  readable sign it's the attacker's turn" — and `5H`'s +3-on-block advantage
  is directly readable live through the frame-data panel; there is no
  opacity gap there.

**This half of the audit is inherently partly subjective** (per my role, I
surface, I don't unilaterally rule "unfun" or "clear enough"). I found no
candidate in P1 that looks to me like it crosses the tax line, so I have
nothing to escalate to the Strategist on this axis for P1. If the Strategist
or user wants a second, independent read of "is the DP's commitment level
fun" or similar — that is explicitly not something this audit rules on either
way.

**Audit-criterion verdict: PASS (objective half); no subjective candidates
found to surface for P1.**

---

## Judgment-log drift check (JC-A-01..05, JC-035..043)

Read all ten P1 entries plus their Architect rulings in full and checked each
against the current code, not just the log's own claim of correctness.

| Entry | Claim | Verified against code |
|---|---|---|
| JC-A-01 | Jump arc is a hand-baked triangular `vel_y` profile, no gravity primitive | Confirmed: `_build_jump_arcs` in `character_a.gd` uses per-frame `motion_vel_y` via the existing keyframe-motion mechanism. No drift. |
| JC-A-02 | Six concrete `CancelRule`s per cancellable normal (group targets deferred) | Confirmed: `_special_cancels` builds exactly 6 rules (fireball L/M/H, DP L/M/H) per normal. No drift. |
| JC-A-03 | DP blockstun is a flat placeholder (`DP_BLOCKSTUN=10`), not back-solved | Confirmed present; I independently re-ran the AD-008 arithmetic the Architect's ruling cites (−37/−39/−46) and it holds. No drift. |
| JC-A-04 | Air-normal hitstun authored as one flat value (14) | Confirmed: `_build_air_normal` takes a single `hitstun` param per call. No drift. |
| JC-A-05 | `2L` hitstun=15 authoritative; spec fixed to +6 | Confirmed in `character-a.md`'s current text (the reconciliation note is present and reads +6, matching the ruling). No drift. |
| JC-035 | `is_throw` is a computed property backed by `hit_kind` | Confirmed by reading `hit_box.gd` directly (lines 69-73). No drift. |
| JC-036 | Invuln dev-tests use a no-hitbox state (back dash) to isolate the phase-4 gate | Confirmed: `test_invuln.gd`'s strike-whiff test drives a state via direct `frame_in_state` injection per the described convention. No drift. |
| JC-037 | `CancelRule.input==0` short-circuits to "no gate," folded into spec | Confirmed in `cancel_eval.gd` and in `move-format.md`'s current `CancelRule.input` row (reads "0 = none"). No drift. |
| JC-038 | PREJUMP's cancel window moved to `[3,3]`; `duration` unchanged | Confirmed: `pj_cancel` window is `[3,3]`; PREJUMP's `m.duration` is still 4. No drift. |
| JC-039 | `AirHeightScaling`'s four numbers (`DEEP_BONUS=6`, `HIGH_PENALTY=8`, `HIGH_REF_DEPTH`, `MIN_HITSTUN=4`) | Confirmed against `air_height_scaling.gd`'s actual constants — exact match. No drift. |
| JC-040 | View/view-model split adopted project-wide | Confirmed across all 4 overlays (see Tenet 3 above). No drift. |
| JC-041 | Missing `.tscn` built; overlays auto-wired by duck-typed `set_source` | Confirmed by my own smoke-load of the scene (below) — all 4 overlays report a wired source after one process frame. No drift. |
| JC-042 | Projectile hitbox gets its own draw color, not a `BoxView.hit_kind` split | Confirmed: `inspection-surface.md`'s `BoxView` table still has no `hit_kind` field (re-read directly); `geometry_overlay_model.gd` handles it as a draw-list color choice. No drift. |
| JC-043 | Recognized-command projection reuses the sim's own recognizer | Confirmed above under Tenet 2 — the strongest and most directly re-verified claim in this log. No drift. |

**No drift found across any of the 14 ratified P1 judgment-log entries.**

---

## Seam discipline — exhaustive re-check (not sampling)

Grepped all 8 files in `game/scenes/overlays/` for `SimState`, `PlayerState`,
`ResolvedBox`, `MoveRegistry`, `StepPhases`, `CancelEval`, `Actionability` —
**zero matches**. Confirmed the only sim-internal references in
`game/scenes/` live in `training_mode.gd` itself (the shell), for its
documented driving role only (constructing initial state, installing
registries at `_ready`) — not in any overlay. This satisfies training-mode.md
criterion 10 with certainty, not sampling confidence.

---

## In-mode visual confirmation — what I could and could not do

**What I did:** I could not open a GUI/interactive Godot editor session from
this environment (no display, no interactive session). What I *could* do,
and did:

1. Ran `godot --headless --check-only res://scenes/training_mode.tscn` —
   confirmed no scene-parse errors.
2. Wrote a temporary, uncommitted headless smoke script
   (deleted after use, never part of the test suite or committed to the
   repo) that loads `training_mode.tscn` for real via `PackedScene.instantiate()`,
   adds it to the tree, runs two process frames, and inspects the resulting
   node tree and each overlay's `_source` field. Result: the scene
   instantiates cleanly, produces the expected child list
   (`TickHost`, `GeometryOverlay`, `FrameDataPanel`, `LiveStatePanel`,
   `InputHistoryPanel`), and all four overlays report a non-null `_source`
   after `_ready()` — confirming JC-041's auto-wiring claim end-to-end, for
   real, in this session.

**What I could NOT do, and am not claiming:** true pixel-level visual
confirmation — I cannot see rendered colors, verify the geometry overlay's
boxes are drawn in the visually correct screen position relative to the
character sprite, confirm panel text doesn't overlap or clip, or confirm the
input-history readout is legible at a glance on an actual screen. I am not
claiming a visual pass for any of these. This matches the honesty bar the
task set: I attempted what a headless environment can attempt, confirmed
what that can confirm (scene loads, wires, doesn't crash, contains the right
nodes), and am not fabricating a screenshot-based verdict for the rest.

**Exactly what needs the user's own eyes, and why it doesn't block PASS:**

- **training-mode.md criterion 5 (Geometry)** — the *logic* (correct world
  positions from resolved boxes) is proven by `test_geometry_overlay.gd`'s 28
  headless checks reading the view-model's draw-list output directly; only
  the *pixel rendering* of that already-correct data (are the boxes drawn
  where the numbers say, on an actual screen, in the right color) needs human
  eyes.
- **training-mode.md criterion 6 (Frame data + advantage panel layout)** and
  **criterion 8 (Input display)** — same split: the view-model output is
  headlessly tested (72 and 29 checks respectively); only whether the
  `Label` text actually renders legibly, unclipped, and correctly positioned
  on screen needs human eyes.
- **General polish** — whether the four overlays' layout is usable/legible as
  a human glances at the screen (training-mode.md explicitly scopes "frame-data
  UI polish beyond legibility" as out of scope, so this is a lower bar than a
  shipped UI — but "does it render at all, sanely" is still worth one human
  look given I can only confirm "does not crash and contains the right nodes"
  from here).

None of this changes the PASS verdict, because every criterion above has its
underlying *logic* verified by a real, non-vacuous, currently-green test, and
the *rendering* layer is explicitly the one thing training-mode.md's own
brief anticipated would need in-mode confirmation (the task's framing, and
JC-040's own note, both say this ahead of time — it was never expected to be
closeable from a headless QA pass alone).

---

## Findings routed

### F-015 → Developer (test-tooling, non-blocking)
**Problem:** `run_tests.bat` (repo root) lists only the original 12 P0-era
test files and has not been updated to include the 13 test files added during
P1 (`test_air_height_scaling`, `test_character_a`, `test_command_recognition`,
`test_frame_control`, `test_frame_data_panel`, `test_geometry_overlay`,
`test_input_history_panel`, `test_invuln`, `test_live_state_panel`,
`test_projectiles`, `test_record_playback`, `test_training_harness`,
`test_training_mode_shell`). Anyone running `run_tests.bat` as their
"did I break anything" check gets a false sense of full coverage — half the
suite silently doesn't run. Not a sim defect; all 24 files are independently
green when run directly (confirmed this session). Fix: add the 13 missing
names to the `TESTS` variable.

### F-016 → Developer (doc-comment staleness, non-blocking, cosmetic)
**Problem:** `game/content/character_a.gd:731` carries a stale comment on
`2H`'s invuln keyframe: `# frames 1-8 per spec; see flags.md (inert until
consumed)`. This predates TKT-P1-11/AD-031 landing — invuln is no longer
inert (it is consumed in phase 4, confirmed live by `test_invuln.gd`), and
`flags.md` no longer contains that content (the ledger is now empty; the
relevant history lives in `flags-archive.md`). The code itself is correct;
only the comment is out of date and could mislead a future reader into
thinking invuln doesn't work yet. Same likely applies to any other "(inert
until consumed)" comments elsewhere in the file — worth a single pass to
remove the phrase everywhere it survived past AD-031 landing.

No spec gaps and no implementation bugs were found. Both findings above are
housekeeping, not correctness issues, and neither blocks the P1 PASS verdict.

---

## Subjective/legibility questions surfaced (not ruled on)

None found for P1 that rise to the level of a Strategist escalation. I
specifically looked for tax candidates against the audit criterion's own
boundary examples (opaque-plus-on-block, unreadable knowledge-check gimmicks,
unreactable-and-undiscoverable mixups) and found character A's kit clean on
all of them — every plus/minus state, every invuln window, and every route's
link timing is now readable through the training mode, and nothing in the
kit's design appears to rely on prior-knowledge-only information. If the
Strategist or user independently wants a "does this feel right" pass on, say,
the DP's commitment level or the fireball's risk profile, that is a taste
question this audit does not and should not adjudicate.

---

## Summary table

| Area | Verdict |
|---|---|
| character-a.md (11 criteria) | **PASS** |
| training-mode.md (12 criteria) | **PASS** |
| inspection-surface.md / combat-resolution.md / move-format.md (P1 additions) | **PASS** |
| Determinism | **PASS** (executed, not inferred) |
| Serialization | **PASS** |
| Tenet 2 (single input-source abstraction) | **PASS** |
| Tenet 3 (build-for-extension) | **PASS** |
| Audit criterion (observability) | **PASS**; no subjective candidates surfaced |
| Seam discipline (criteria 10/11) | **PASS** (exhaustive, not sampled) |
| Judgment-log drift (14 P1 entries) | **No drift** |
| In-mode pixel/visual confirmation | **Not verifiable from this environment** — named above, does not block PASS |

**P1 PASSES.** Two non-blocking findings routed to the Developer (F-015,
F-016). No flags to the Architect or Strategist. One item needs the user's
own eyes (pixel-level visual confirmation of the four overlays) before the
absolute strictest reading of "done" is satisfied, but every criterion that
touches is already backed by a green, non-vacuous headless test of the
underlying logic.
