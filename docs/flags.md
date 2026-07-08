# Flag Ledger

> Any role appends; the **owner** of the flagged artifact resolves. This ledger
> holds **open flags** (plus recently-resolved ones awaiting relay); once a
> resolution has been relayed, the entry moves to `flags-archive.md` — the
> permanent record — so this file stays a cheap read. Mechanism: raiser appends +
> tells the user; user relays to the owner; owner writes the resolution line,
> flips `[open]` to `[resolved]`, saves (git checkpoints happen per the
> protocol); user relays back. See `protocol.md` → "How a flag
> works."

---

### [open] 2026-07-04 · raised-by: QA · owner: Developer · re: /run_tests.bat
Problem: `run_tests.bat` (repo root) still lists only the original 12 P0-era
test files in its `TESTS` variable and has not been updated to include the 13
test files added during P1 work (`test_air_height_scaling`, `test_character_a`,
`test_command_recognition`, `test_frame_control`, `test_frame_data_panel`,
`test_geometry_overlay`, `test_input_history_panel`, `test_invuln`,
`test_live_state_panel`, `test_projectiles`, `test_record_playback`,
`test_training_harness`, `test_training_mode_shell`). Anyone running the
batch file as their "did I break anything" check gets a false sense of full
coverage — half the suite silently doesn't run. Not a sim defect: all 24 test
files are independently green when run directly against Godot (confirmed in
the P1 audit, `docs/audits/audit-p1-feature.md`, this session). Fix: add the
13 missing names to the `TESTS` variable.
---
Resolution (owner fills): …

### [open] 2026-07-04 · raised-by: QA · owner: Developer · re: game/content/character_a.gd:731
Problem: `2H`'s invuln keyframe carries a stale comment: `# frames 1-8 per
spec; see flags.md (inert until consumed)`. This predates TKT-P1-11/AD-031
landing — invuln is no longer inert (it is consumed in phase 4; confirmed
live by `test_invuln.gd`'s `_test_strike_whiffs_on_2h_invuln`), and
`flags.md` (this file) no longer carries that content (the ledger is now
empty; the relevant history is in `flags-archive.md`). The code itself is
correct — only the comment is out of date, and it could mislead a future
reader into thinking invuln doesn't function yet. Worth a single pass to
check for and remove the "(inert until consumed)" phrase anywhere else it
survived past AD-031 landing in this file.
---
Resolution (owner fills): …

### [open] 2026-07-04 · raised-by: Strategist (relaying QA) · owner: user · re: training-mode overlays — in-mode visual confirmation
Problem: the P1 feature audit PASSED (`docs/audits/audit-p1-feature.md`), but one check is
outside a headless pass: pixel-level on-screen rendering of the four training-mode overlays
(geometry box positions, panel layout/clipping, input-history legibility). QA confirmed the
scene loads, instantiates, and auto-wires live, and every overlay's view-model logic is
covered by non-vacuous headless tests — so the PASS stands — but actual visual appearance
needs a human look in an interactive Godot session. Tracked here so P1 is not treated as
100% closed without it. Resolution: open `game/scenes/training_mode.tscn` in the Godot
editor, confirm the overlays render correctly; QA folds the result into the audit.
---
Resolution (owner fills): …

### [open] 2026-07-08 · raised-by: Strategist · owner: Architect · re: serialization format has no version field
Problem: the `to_dict()`/`from_dict()` pairs across the sim (`sim_state.gd`,
`player_state.gd`, `projectile.gd`, `rng_state.gd`, `stage_state.gd`,
`hit_record.gd`, `input_history.gd`) carry no format-version marker. The
top-level `SimState.to_dict()` (`game/sim/sim_state.gd:128`) returns
`{tick, rng, players, projectiles, stage, last_hit, neutral_restored_this_tick}`
— no `"v"`. This is cheap to add now (one `"v": 1` field on the top-level dict,
checked in `from_dict`) and expensive to retrofit once saved states — replays,
save-states, netcode rollback snapshots — exist in the wild and must be migrated
blind. Determinism/serialization is a Tenet-1 surface, so this is contract-level,
not cosmetic. This is an Architect call on the serialization contract: rule on
whether a version field belongs now (and if so, where it lives and how `from_dict`
handles an absent/mismatched version), then hand the shape to the Developer.
Origin: Fable strategic review 2026-07-05 (smaller findings), carried in by the
user; verified against live code this session.
---
Resolution (owner fills): …

### [open] 2026-07-08 · raised-by: Strategist · owner: Architect · re: MoveRegistry process-wide static state is undocumented
Problem: `MoveRegistry` (`game/sim/move_registry.gd`) holds `static var _roster`
and `static var _install_generation` — the one piece of global mutable state in
an otherwise pure, deterministic design. It is *mitigated* (tests call `clear()`;
the install-generation token guards stale reads) and is fine for the slice, but
the tradeoff is unrecorded: nothing in `decisions.md` names it as a deliberate,
known cost of the Tenet-3 (build-for-extension) roster-install convenience. Left
undocumented, a future reader can't tell whether the global is an intentional,
bounded exception or an accident to "fix," and can't see the invariant that keeps
it safe (install-generation discipline). Fix (Architect): record it as a known
cost — a short AD or a note on the relevant existing AD — stating the exception,
why it's acceptable at slice scope, the invariant that contains it, and what would
force revisiting (e.g. concurrent sims in one process). Not a code change; a
decision-record change. Origin: Fable strategic review 2026-07-05 (smaller
findings), carried in by the user; verified against live code this session.
---
Resolution (owner fills): …
