# Flag Ledger

> Any role appends; the **owner** of the flagged artifact resolves. This ledger
> holds **open flags** (plus recently-resolved ones awaiting relay); once a
> resolution has been relayed, the entry moves to `flags-archive.md` — the
> permanent record — so this file stays a cheap read. Mechanism: raiser appends +
> tells the user; user relays to the owner; owner writes the resolution line,
> flips `[open]` to `[resolved]`, saves (git checkpoints happen via the user's
> helpers, per the protocol); user relays back. See `protocol.md` → "How a flag
> works."

---

### [resolved] 2026-07-03 · raised-by: QA · owner: Developer · re: /game/tests/test_throws_multihit.gd
Problem: `_test_simultaneous_throw_clash` can pass VACUOUSLY. It asserts only that
neither player is in `STATE_THROWN` and neither took damage — both of which are
equally true for a correct clash AND for throws that never connect (a broken
button map, drifted throwbox geometry, or an accidental early return would still
pass). There is no positive liveness check that both players reached `STATE_THROW`,
that the throwboxes reached their active window, or that a clash was actually
detected. This is the F-011 lineage (a green test that hides drift by asserting the
absence of the wrong thing). The SIM clash behavior is correct (traced: geometry
strictly overlaps, `_both_throwboxes_connect` → `_resolve_throw_clash` runs) — only
the test is weak, so the clash arm of combat-resolution.md crit 10 is not yet
locked by a self-verifying test. Fix: add a positive liveness assertion (both
reached `STATE_THROW`; the clash path ran / both throwboxes hit their active
window). Non-blocking; does not gate the P0 milestone.
---
Resolution: Strengthened `_test_simultaneous_throw_clash` in
game/tests/test_throws_multihit.gd with positive liveness assertions, added
immediately after the throw-input tick and before the clash-detection loop:
(1) both `s.players[0].state_id` and `s.players[1].state_id` equal
`STATE_THROW` (both attempts are live, not whiffed/blocked by a button-map or
geometry regression), and (2) both players' `frame_in_state` is within 1..3,
the throwbox's authored active window (`TestSupport._build_throw`) — i.e. the
throwboxes are actually on their active frames when the clash is checked.
Also added a proof the clash path itself ran (not just "throws never
connected"): captured `separation` between the two players' `pos_x` before the
throw-input tick and again after the clash resolves, and asserted it strictly
increased — `_resolve_throw_clash` (game/sim/step_phases.gd) applies a
deterministic symmetric pushback keyed off the throw hitbox's `pushback_hit`,
so a real clash is now independently observable via position, not just via
the absence of `STATE_THROWN`/damage.

Fixture gap found and fixed along the way: `TestSupport._build_throw()`
(game/tests/test_support.gd) never set `pushback_hit` on the throwbox (default
0), so `_resolve_throw_clash`'s pushback was a no-op in this fixture — the sim
was correct, but there was nothing to observe. Added
`THROW_PUSHBACK: float = 3.0` and set `tb.pushback_hit =
FP.from_units(THROW_PUSHBACK)` in `_build_throw()`. Verified this only affects
`_resolve_throw_clash` (the only reader of `pushback_hit` on a throwbox —
`_resolve_throw`, the single-throw connect path, never reads it) and that no
other test file exercises the throw command, so the other two throw scenarios
(`_test_throw_bypasses_block`, `_test_throw_tech_to_neutral`) and all other
test files are unaffected.

Verified: `"E:\Godot 4.3\Godot_v4.3-stable_win64.exe" --headless --path game -s
res://tests/test_throws_multihit.gd` → `[test_throws_multihit] OK — 17 checks
passed` (up from 12; 5 new assertions). Also re-ran test_combat (56 OK),
test_buffer_cancels (49 OK), test_inspection_view (22 OK), and test_done_bar
(34 OK) to confirm the shared fixture change caused no regressions elsewhere.
The clash arm of combat-resolution.md crit 10 is now locked by a
self-verifying (non-vacuous) test.

### [open] 2026-07-03 · raised-by: QA · owner: Architect · re: /docs/spec/inspection-surface.md
Problem: batch 2 (TKT-P0-08/09, AD-028) added mutable, legibility-relevant
serialized `SimState` state — `throw_tech_window`, `thrown_by`, `move_contact`,
`cancel_tags` — but NONE of it is surfaced through the inspection seam: the
`inspection-surface.md` `PlayerView` table does not list these fields, so the debug
training mode reading through `InspectionView`/`PlayerView` has no way to observe
whether a defender is in a tech window (and how many frames remain), who threw
them, or that a cancel window is open. This is observable-in-principle (it is in
serialized, hashed state) but not actually surfaced through the seam — the drift
the milestone sweep targets. The charter's north star is "you can find out what
happened and why, every time," and the audit criterion's backstop is that the
training mode is where "what just happened?" always has an answer; throws and
cancels being discoverable is a charter-legibility surface. This is NOT an
implementation bug — `PlayerView` faithfully implements the current (spec-owned)
table — so it routes to the Architect (spec owner), parallel to F-002 (inspection
reads were a spec gap the build surfaced). Question: should the surface expose the
batch-2 tech-window / cancel-window state, and is that P0 or P1 (TKT-P1-01 completes
the surface)? Non-blocking — the full inspection-surface implementation is
explicitly TKT-P1-01 and no P0 acceptance criterion requires these reads; it does
not gate the P0 milestone. Surfaced (legibility judgment), not adjudicated, per QA's
subjective-handling role.
---
Resolution (owner fills): …
