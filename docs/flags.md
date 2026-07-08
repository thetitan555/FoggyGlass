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

### [resolved] 2026-07-04 · raised-by: QA · owner: Developer · re: /run_tests.bat
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
Resolution (owner fills): `TESTS` brought fully current — not just the 13 named here, but
also the P1.1-phase additions landed since this flag was raised (`test_control_surface`)
and TKT-P1.1-03's own new test (`test_serialization_version`), for **27 runnable
`SceneTree` tests total**, enumerated against a fresh `game/tests/test_*.gd` glob rather
than trusting either this flag's list or the prior 12-file list. `test_support.gd` is
excluded — it is a shared helper (`TestSupport`, programmatic move-data builders), not a
runnable `SceneTree` test; it has no `_init`/`quit` test-runner shape and running it
directly does nothing. Verified: ran all 27 headlessly (directly against Godot, not
through the batch file, to sidestep its trailing `pause`) — 27/27 pass.

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

### [resolved] 2026-07-08 · raised-by: Strategist (from user's P1.1 human-inspection gate) · owner: Developer · re: arrow-key left/right movement does nothing
Problem: first human operation of `training_mode.tscn` after TKT-P1.1-01/02 (user, 2026-07-08).
UP works (jump straight up) but LEFT and RIGHT arrow keys produce no walk — horizontal movement
by keyboard is impossible. Forward displacement from moves works (5H advances forward), so the
sim-side walk is not the suspect; the gap is in the human control path: either
`_sample_device_p1` (`game/scenes/training_mode.gd`) does not sample left/right into the emitted
`InputFrame` the way it samples up, or the `project.godot` input-map bindings for left/right are
missing/overridden (the `[input]` section added in TKT-P1.1-02). Diagnose which and fix so a human
can walk both directions. **Blocks P1.1's "operable by a human" gate** — there is no neutral or
spacing without walk. Add a headless regression asserting the device sampler encodes the left and
right direction bits (mirroring the attack-button-bit test).
---
Resolution (owner fills): Both named candidates checked out FINE — `_sample_device_p1` samples
`ui_left`/`ui_right` identically to `ui_up`, and `project.godot`'s `[input]` section never touches
`ui_left`/`ui_right`/`ui_up`/`ui_down` at all (they fall through to Godot's own built-in arrow-key
defaults, unshadowed). The actual root cause was **sim-side**, not the control path the flag named:
`character_a.gd` had already authored `STATE_WALK_F`/`STATE_WALK_B` (movement-table speeds) with
correct keyframe motion, but no `button_map` entry ever routed a bare held direction into either
state — holding RIGHT/LEFT produced zero state change and zero displacement, confirmed by driving
`SimState.step` directly (state stuck at `STATE_IDLE`, `pos_x` never moved). Fixed by adding two
pure-direction `ButtonMapEntry` entries (mirrors the existing jump entry, AD-032's pattern exactly),
listed after the standing normals so a button held with a direction still performs the normal, not
a walk. Full diagnosis, alternatives, and a boundary note (this touches `character_a.gd`, nominally
out of this dispatch's "no character content changes" bound, but is input-recognition wiring using
already-authored/spec'd values, not new move/damage/timing content) recorded at **JC-046**
(`docs/judgment-log.md`, provisional — flagging for Architect review given it exceeded the
dispatch's anticipated two-candidate diagnosis). Regression: `test_command_recognition.gd`'s
`_test_character_a_walk_forward_reachable_end_to_end` / `_walk_back_reachable_end_to_end` /
`_button_beats_walk_on_same_frame` (live-input only, no state injection), and
`test_control_surface.gd`'s `_test_device_sampler_encodes_left_and_right` (the requested sampler-bit
regression). `data/character-a.tres` re-baked to match. All 26 headless test files pass.

**Not closed by this fix: live human re-confirmation.** Whether a human can actually walk both
directions by pressing the arrow keys in a running `training_mode.tscn` window is the **P1.1
human-inspection gate** — the user's to confirm on return, separate from and not claimed by this
code fix.

### [resolved] 2026-07-08 · raised-by: Strategist (from user's P1.1 human-inspection gate) · owner: Developer · re: player sinks ~5px below the floor on landing
Problem: same human run. On landing from a straight-up jump, the player drops through the floor
slightly (~5px) MOST times. First determine whether this is a SIM defect (the player's sim `pos_y`
actually goes below `ground_y` for one or more ticks — read the Live State `pos_y` against
`ground_y`) or a RENDER defect (sim `pos_y` is correctly clamped at `ground_y`, but the AD-035
render framing / `geometry_overlay` seats the drawn ground line a few px off from the sim floor).
Fix accordingly: if SIM, the landing clamp against `ground_y` (jump arc, JC-A-01) is overshooting —
fix and note that determinism goldens change deliberately (JC-017-style, a conscious golden update);
if RENDER, align the drawn ground line to sim `ground_y` under AD-035. **May bounce to the Architect**
if AD-035 underspecifies where the ground line seats. The floor is a reference the player reads
against, so this is a gate-visible legibility defect and blocks the P1.1 human gate alongside the
movement flag.
---
Resolution (owner fills): **SIM defect, confirmed** — the render layer (AD-035/`geometry_overlay.gd`)
is exonerated: it's a pure linear world→screen transform with no independent vertical-seating bug,
so it faithfully rendered whatever `pos_y` the sim reported. Root cause: `character_a.gd`'s
`_build_jump_arcs` split the 45-frame jump arc as 22 rise frames / 23 fall frames (45 is odd) at
EQUAL magnitude (both 6.0 units/frame) — so the arc's net vertical displacement was `+6` units of
permanent downward drift on EVERY jump (deterministic, not intermittent), landing the character 6
units into the floor. There is no runtime landing clamp anywhere in the engine (movement is pure
keyframe integration by design, AD-014) to correct this after the fact. Fixed by spending the odd
frame as a one-frame, zero-velocity "apex hang" at the top of the arc (22 rise / 1 hang / 22 fall =
45 frames, unchanged duration) — nets to exactly zero, verified headlessly: the character now lands
bit-exact at its starting height, 0 ticks below `ground_y` during the whole flight. This is a
conscious, disclosed sim-behavior change (JC-017-style): no persisted golden-file fixtures exist yet
in the repo, so nothing needed silent regeneration, but `test_character_a.gd`'s
`_test_jump_arc_integrates` — whose PRIOR assertion explicitly tolerated the drift ("lands close to
its start... not bit-exact") — is updated to assert exact equality, since that prior tolerance was,
in hindsight, documenting the very defect this flag reports. Full diagnosis and alternatives-passed-
over (an uneven fall speed instead of a hang frame; a runtime clamp; a parabolic re-bake) recorded at
**JC-047** (`docs/judgment-log.md`, provisional). All 26 headless test files pass.

**Not closed by this fix: live human re-confirmation.** Whether the player visibly lands flush on
the floor in a running `training_mode.tscn` window is the **P1.1 human-inspection gate** — the
user's to confirm on return, separate from and not claimed by this code fix.

### [open] 2026-07-08 · raised-by: Strategist (from user's P1.1 human-inspection gate) · owner: Strategist · re: character A crouching-normal attack heights — confirm design intent (NON-BLOCKING)
Problem: the first visual look at character A's boxes (via the now-working geometry overlay)
surfaced a content-design QUESTION, not a defect: 2L and 2M attack at HEAD-LEVEL while their
hurtbox shrinks (crouch), whereas 2H attacks near the bottom; 5L/5M/5H render lower on the
character (5H advances forward, correct). Crouching light/medium normals hitting at head height is
unusual for a grounded shoto and may or may not be intended authored move data. This is a
design-intent call (character A identity → brief → the user's design taste), **NOT a P1.1
operability item, and does NOT block the P1.1 gate.** Resolve WITH THE USER on return: confirm the
crouching-normal attack heights are intended, or route a content adjustment to the Architect (spec)
/ Developer (move data). Recorded now so the observation isn't lost while the gate closes.
---
Resolution (owner fills): …
