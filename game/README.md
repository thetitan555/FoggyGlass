# game — FoggyGlass engine tree

The Godot project (AD-013). Coordination artifacts live in `/docs`; only build
code lives here.

## Layout (as of TKT-P0-03)

    game/
      project.godot          Godot 4.x project config. physics_ticks_per_second=60.
      sim/
        fp.gd                FP fixed-point math (AD-014). 64-bit, scale 2^16,
                             mul/div as shifts, round-to-nearest ties away from
                             zero, no transcendentals. Static; owns the convention.
        input_frame.gd       The 16-bit InputFrame (AD-002/018). Raw dirs +
                             BUTTON_0..7; reserved bits validated. A frame value
                             is a plain masked int (JC-006); this class is a
                             namespace of bit constants + static helpers.
        input_source.gd      The one InputSource interface (Tenet 2): get_input(
                             frame) -> int, frame-indexed, reproducible, no future
                             reads. Shared reserved-bit validation.
        local_device_source.gd  Samples a device each tick + records into a buffer
                             so past frames stay answerable. Dumb (buffer only).
        replay_source.gd     Reads a recorded buffer frame by frame. A "replay" is
                             a local recording fed back through this — identical
                             stream (input.md crit 3).
        input_history.gd     Per-player ring buffer of raw frames (AD-003/022),
                             CAP=32 (JC-008). The substrate buffering reads.
        rng_state.gd         Seeded SplitMix64 RNG INSIDE serialized state (Tenet
                             1). Pure-integer, platform-stable, round-trips.
        player_state.gd      Per-player state (simulation.md). All fixed-point /
                             int, no floats. clone/to_dict/from_dict.
        stage_state.gd       Stage bounds (walls/ground), fixed-point.
        sim_state.gd         The serializable root + pure non-mutating step(state,
                             in1, in2) (AD-004) + canonical FNV-1a hash (JC-007).
        tick_host.gd         Fixed 60 Hz tick host (AD-004). Advances the sim
                             exactly one tick per physics_process via SimState.step,
                             sourcing inputs through the InputSource contract, off a
                             state-owned tick counter, never delta-scaled.
      scenes/
        main.tscn/.gd        Runtime root; wires the host + local sources, renders
                             the sim clock from state (never advances it).
      tests/
        test_fp.gd           Headless FP checks.
        test_tick_host.gd    Headless tick-authority checks (scope note inside).
        test_input.gd        Headless input-contract checks (input.md 1,2,3,4,6).
        test_sim_state.gd    Headless determinism/round-trip/hash/no-float checks
                             (simulation.md 1,3,4,8,9).

The inspection surface (the read-only seam) is TKT-P0-04; the move format + state
machine, phase pipeline, and hit resolution are TKT-P0-05/06/07. `SimState.step`
currently runs phase 1 (record inputs) + advance-tick; the AD-009 phase order is
the seam those tickets fill in.

## Running the tests (headless, no editor needed)

    godot --headless --path game -s res://tests/test_fp.gd
    godot --headless --path game -s res://tests/test_tick_host.gd
    godot --headless --path game -s res://tests/test_input.gd
    godot --headless --path game -s res://tests/test_sim_state.gd

Each prints a one-line OK/FAIL summary and exits non-zero on failure, so a
harness/CI can gate on the exit code. (These were authored without a Godot
binary available in the dev sandbox — see the TKT-P0-01 report; they should be
run once Godot is present to confirm they execute clean.)
