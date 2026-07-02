# game — FoggyGlass engine tree

The Godot project (AD-013). Coordination artifacts live in `/docs`; only build
code lives here.

## Layout (as of TKT-P0-01)

    game/
      project.godot        Godot 4.x project config. physics_ticks_per_second=60.
      sim/
        fp.gd              FP fixed-point math (AD-014). 64-bit, scale 2^16,
                           mul/div as shifts, round-to-nearest ties away from
                           zero, no transcendentals. Static; owns the convention.
        tick_host.gd       Fixed 60 Hz tick host (AD-004). Advances the sim
                           exactly one tick per physics_process, off a
                           state-owned tick counter, never delta-scaled.
      scenes/
        main.tscn/.gd      Runtime root; hosts the tick host in the physics loop.
      tests/
        test_fp.gd         Headless FP checks (fully verifiable now).
        test_tick_host.gd  Headless tick-authority checks (scope note inside:
                           full simulation.md crit-5 coverage lands with 03).

`SimState`, the pure `step`, the input contract, and the inspection surface are
NOT here yet — they are TKT-P0-02/03/04. `tick_host.gd` advances against a
minimal seam (a tick-only stand-in state) documented in that file; 03 swaps the
stand-in for the real `SimState`/`step` without changing the tick discipline.

## Running the tests (headless, no editor needed)

    godot --headless --path game -s res://tests/test_fp.gd
    godot --headless --path game -s res://tests/test_tick_host.gd

Each prints a one-line OK/FAIL summary and exits non-zero on failure, so a
harness/CI can gate on the exit code. (These were authored without a Godot
binary available in the dev sandbox — see the TKT-P0-01 report; they should be
run once Godot is present to confirm they execute clean.)
