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

### [resolved] 2026-07-08 · raised-by: Strategist (from user's overlay review) · owner: Developer · re: geometry overlay renders no visible boxes
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
Resolution (owner fills): It was **both**, as the ticket (`p1.1-finish-instrument.md` →
"Geometry ruling") anticipated, and both are now fixed together in **TKT-P1.1-01**:
- **Part A (pure code defect, Developer's).** `training_mode.gd`'s shell left both players at
  `SimState.new_initial()`'s generic `character_id 0 / state_id 0` — never wired to the
  installed roster (`CharacterA.CHAR_ID`) — so `PlayerView.move` was null and `boxes == []` for
  both players at every tick, independent of any rendering question. Fixed: both players now
  start as the installed character in its idle state (character-agnostic — reads
  `_character_id` / `Character.idle_state_id`, no character-A-specific branch). Regression-
  guarded in `test_training_mode_shell.gd`.
- **Part B (render-framing contract, unspecced — the "may bounce to the Architect" clause).**
  Confirmed unspecced: at `PX_PER_UNIT = 1` with no world→viewport framing, world origin sat at
  the viewport top-left, so resolved boxes at `pos_x = ±100` rendered partly off-screen / behind
  the HUD panel region. The Architect settled this as **AD-035** (render-only world→screen
  framing, extending AD-019). Implemented in `geometry_overlay.gd`: a render-only
  position/scale transform on the `GeometryOverlay` node itself (centers the stage horizontally,
  seats the ground line low, zooms to fit stage width with margin) — the HUD panels are
  *siblings*, not children, of that node, so they stay screen-anchored with no further change.
  Latitude on the exact mechanism/numbers recorded at `judgment-log.md` JC-044, pending Architect
  ratification.

Both parts verified headlessly: `test_training_mode_shell.gd` (Part A: both players resolve
`character_id`/`state_id`/a non-empty `boxes` list at tick 0) and `test_geometry_overlay.gd`
(Part B: the framing math centers/seats/fits as specified, both symmetric-start players' boxes
land on-screen and clear of the panel region in the framing math, and a live-node application of
the framing changes neither the draw-list view-model nor the `SimState` hash — AD-019 criterion
6 / AD-035's "golden with vs. without the camera is identical").

**Not closed by this fix: pixel-level live confirmation.** Whether the boxes are *actually*
visible on a real running window is the **P1.1 human-inspection gate** (`audit-criterion.md`,
`p1.1-finish-instrument.md`) — the user's to confirm by running `training_mode.tscn`, separate
from and not claimed by this code fix. This flag closes the code-defect/unspecced-contract
question the geometry finding raised; it does not itself constitute the human sign-off.
