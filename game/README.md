# game — FoggyGlass engine tree

The Godot project (AD-013). Coordination artifacts live in `/docs`; only build
code lives here.

## Layout (through TKT-P0-10, the P0 done-bar)

    game/
      project.godot          Godot 4.x project config. physics_ticks_per_second=60.
      data/
        test_character.tres  P0 test character, authored PURELY as .tres data
                             (TKT-P0-10, NOT character A): idle, walk, LIGHT normal
                             with hand-computable frame data, hit/block reactions.
                             All values baked fixed-point (AD-014). The .tres twin of
                             TestSupport.build_test_character().
      sim/
        fp.gd                FP fixed-point math (AD-014). 64-bit, scale 2^16.
        input_frame.gd       The 16-bit InputFrame (AD-002/018). Namespace of bit
                             constants + static helpers over a plain masked int.
        input_source.gd      The one InputSource interface (Tenet 2).
        local_device_source.gd / replay_source.gd  Concrete sources (input.md).
        input_history.gd     Per-player raw-frame ring buffer (AD-003/022), CAP=32.
        rng_state.gd         Seeded SplitMix64 RNG inside serialized state (Tenet 1).
        player_state.gd      Per-player state (simulation.md). Fixed-point/int only.
        stage_state.gd       Stage bounds (walls/ground), fixed-point.
        hit_record.gd        Serialized last-hit record (F-002); the sim-side truth
                             HitEvent projects.
        sim_state.gd         The serializable root + pure non-mutating step(state,
                             in1, in2) (AD-004), orchestrating the AD-009 phase order
                             + canonical FNV-1a hash (AD-023).
        step_phases.gd       The intra-tick phase pipeline (AD-009), one static
                             function per phase (inputs/SOCD/facing -> state machine
                             -> movement/pushbox -> overlap -> hit resolution ->
                             advantage/neutral -> advance counters). TKT-P0-06/07.
        damage_scaling.gd    The ONE damage-scaling definition (combat-resolution.md).
        move_registry.gd     Immutable authored-move-data roster the pure step reads
                             (F-004): installed once at wiring, character_id ->
                             Character. Authored data is a fixed input, not sim state.
        move_data.gd         The ONE box-resolution + frame-data derivation (AD-001/
                             008). resolve_boxes (facing flip + position offset),
                             frame_data (startup/active/recovery/total).
        actionability.gd     The ONE actionability definition (stun/hitstop/recovery).
        advantage.gd         The ONE advantage function (AD-008): static pinned +
                             live cancel-aware; two surfaced values, one formula.
        resolved_box.gd      World-space AABB + STRICT overlap (F-003).
        projectile.gd        Runtime projectile entity (AD-021). Empty at P0.
        inspection_view.gd   The read-only inspection surface (the seam, AD-011).
        sim_harness.gd       Determinism/serialization harness HOOKS (TKT-P0-11):
                             snapshot dump/load, headless replay runner, golden
                             fixed-point-only inspection truth dump. QA owns verdicts.
        data/                .tres schema Resource types (Character, MoveState,
                             Keyframe, Box, HitBox, CancelRule, ButtonMapEntry,
                             CharacterPhysics) — TKT-P0-05.
        views/               Plain-data inspection view classes (PlayerView, BoxView,
                             ProjectileView, FrameData, AdvantageView, HitEvent).
        tick_host.gd         Fixed 60 Hz tick host (AD-004).
      scenes/
        main.tscn/.gd        Runtime root; wires the host + local sources, renders
                             the sim clock from state (never advances it).
      tests/
        test_support.gd      Programmatic test-character builder (twin of the .tres).
        test_fp.gd / test_tick_host.gd / test_input.gd / test_sim_state.gd
                             Backbone checks (FP, tick authority, input contract,
                             determinism/round-trip/hash/no-float).
        test_inspection_view.gd  Read-only seam checks (inspection-surface.md 2/4).
        test_move_format.gd  Derivation / per-frame boxes / facing / single id_group
                             / categories / no-float (move-format.md 1,2,3,6,9).
        test_harness.gd      Harness-hook checks (round-trip, replay determinism,
                             snapshot-resume, float/px-free truth dump).
        test_combat.gd       Phase-pipeline checks (SOCD, facing, movement, direct
                             transitions, single-hit, hit/block advantage, hitstop
                             freeze, neutral edge, phase-order structure).
        test_done_bar.gd     THE P0 DONE-BAR (TKT-P0-10): the .tres character resolves
                             a hit, advantage/frame-data read back through the
                             inspection surface and match hand-computed values; the
                             scenario replays deterministically and snapshot/resumes.

`SimState.step` now runs the full AD-009 phase order (StepPhases). With no roster
installed it degrades to a pure clock+input advance (no character to move/hit), so
the backbone determinism tests remain valid. Input buffer + cancels (TKT-P0-08) and
throws + multi-hit (TKT-P0-09) are deliberately deferred to batch 2 (after the
done-bar, which needs neither).

## Running the tests (headless, no editor needed)

    godot --headless --path game -s res://tests/test_fp.gd
    godot --headless --path game -s res://tests/test_tick_host.gd
    godot --headless --path game -s res://tests/test_input.gd
    godot --headless --path game -s res://tests/test_sim_state.gd
    godot --headless --path game -s res://tests/test_inspection_view.gd
    godot --headless --path game -s res://tests/test_move_format.gd
    godot --headless --path game -s res://tests/test_harness.gd
    godot --headless --path game -s res://tests/test_combat.gd
    godot --headless --path game -s res://tests/test_done_bar.gd

Each prints a one-line OK/FAIL summary and exits non-zero on failure, so a
harness/CI can gate on the exit code. (Authored without a Godot binary in the dev
sandbox; run once Godot is present to confirm they execute clean — QA owns the
verdicts.)
