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

### [open] 2026-07-04 · raised-by: Strategist · owner: Strategist · re: /docs/protocol.md (commit cadence / interruption resilience)
Problem: across the P1 run, three separate sessions hit token/session limits mid-work and
terminated with uncommitted changes in the working tree (Batch 3 overlays ~608 lines; the
AD-033 spec draft; a partial engine edit). Nothing was ultimately lost — the shared working
tree persisted each change and all were recovered — but every recovery cost a fresh session
to verify-and-resume orphaned work, and the botched QA run cost ~150k tokens for zero
output. The token-economy section already says "commit as you go," but it is advisory; under
large batches the commit consistently came too late. This is a protocol weakness I own.
Candidate fixes for a future Strategist session (deliberately NOT applied now — session
ending, pipeline work halted): (a) promote "commit the first logical unit before any further
work, then per-unit" to a hard working-agreement; (b) right-size batches smaller so one
interruption spans less uncommitted work; (c) add a dispatch-brief guard that a subagent must
perform its own work and never delegate/spawn (the QA run mis-scoped its role and narrated
delegating the audit). Raised as the last-chance record so the lesson survives the session
boundary.
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
