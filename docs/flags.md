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

### [open] 2026-07-08 · raised-by: Strategist (from user's overlay review) · owner: Architect · re: training-mode.md — no human-operable control surface
Problem: the first human run of `training_mode.tscn` (user, 2026-07-08; full report archived
in `flags-archive.md`, this date) surfaced a spec-vs-charter gap that all 24 headless tests
pass straight through. The scene mounts the four READOUT overlays but binds nothing to drive
the CONTROL layer: pause / frame-step / reset / record-playback exist only as methods on the
shell (`training_mode.gd`: `set_paused`, `step_once`, `capture_reset`, `set_dummy_mode`…),
and the P1 acceptance tests exercise them by CALLING those methods directly — which is why
criteria 1–4 are green AND why an experienced player cannot make the mode do anything: no
key, button, or on-screen control invokes them, and `_physics_process` early-returns unless
the host is running with no bound way to change that. Net: the mode is observable but not
operable by a human. Scope question for the Architect (spec/scope owner): was an input-bound
control surface in P1's scope, or deliberately deferred (P1 = control CONTRACTS + readouts,
driving UI later)? Cross-check the training-mode brief (Strategist-owned,
`docs/briefs/debug-training-mode.md`) and training-mode.md criteria 1–4. If deferred, rule it
so and record where the driving UI lands on the roadmap; if a gap, spec the control surface.
This gates the geometry finding below (nothing steps, so nothing moves to confirm) and the
P1 audit's visual sign-off.
---
Resolution (owner fills): …

### [open] 2026-07-08 · raised-by: Strategist (from user's overlay review) · owner: Developer · re: geometry overlay renders no visible boxes
Problem: in the same human run (full report archived in `flags-archive.md`, 2026-07-08), the
geometry overlay showed NO boxes on screen, though both players are present in sim state (the
frame-data and live-state panels both read P0 and P1 idle at tick 0). Even without character
art, two idle characters' hurtboxes should draw — this is the charter's centerpiece surface
("see what hit and what whiffed"), and its pixel-level rendering is exactly what no headless
test could confirm (`test_geometry_overlay.gd`'s 28 checks verify the view-model's draw-list
numbers, not on-screen pixels). Investigate: are boxes drawn off-screen, behind the panel
region (panels span x≈16–700), or at a projection/camera framing that puts them outside the
view? PARTLY GATED on the control-surface flag above — with the sim frozen at tick 0 and
nothing steppable, geometry can't be confirmed in motion; but "no boxes at all, at rest" is
independently a finding. May bounce to the Architect if the box-to-screen projection / camera
framing turns out to be unspecced rather than a code defect.
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
