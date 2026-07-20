# Judgment-Call Log

> **Live file = provisional (unratified) bodies only.** Every entry is a
> *latitude* call — how to build something the spec already decided *what* it is;
> anything touching a contract, feel, or tenet is a flag (`flags.md`), not an entry
> here. The Developer appends; the Architect ratifies/overturns each before that
> feature's audit.
>
> **Closed entries** (ratified · overturned · superseded) live verbatim in
> `judgment-log-archive.md`, each headed `### JC-NNN` — Grep it by id or keyword,
> never read it whole (`grep "^### JC" …` reconstructs the full log-order list on
> demand). Next id = the highest `### JC-NNN` in the archive, +1.
>
> **Maintenance split:** Developer appends a provisional body below; Architect
> flips its status in place on ruling; Strategist sweeps closed bodies to the
> archive on the per-session ledger sweep. Format/rationale: `protocol.md`.

---

## Provisional (awaiting ratification)

<!-- JC-100..105 ratified and swept to judgment-log-archive.md (Strategist, 2026-07-17). -->
### JC-106 · 2026-07-17 · TKT-P2-11 (AD-050) · divekick landing-recovery authored per-strength, not shared — ratified
**Decided:** each of B's three divekicks (L/M/H) gets its OWN landing-recovery `MoveState`
(`STATE_DIVEKICK_L_LANDING` / `_M_LANDING` / `_H_LANDING`), rather than one shared recovery
state. AD-050 explicitly leaves this call open ("author separate recovery states, or share
where they coincide").
**Why:** L/M/H's currently-authored `HitBox.blockstun` values (9/11/13 — JC-095's own tuning)
are all pairwise distinct, so the AD-050 pinned equality (`recovery.duration ==
that divekick's own blockstun`) requires three different `duration`s — sharing one state
would force one of the three numbers to be wrong. To keep the equality holding **by
construction** rather than by three call sites happening to agree, `_build_divekicks()` and
`_build_divekick_landing_states()` both read the SAME named constant
(`DIVEKICK_{L,M,H}_BLOCKSTUN`) for a given strength, instead of duplicating the blockstun
value as an inline literal in two places.
**Alternative passed over:** one shared `STATE_DIVEKICK_LANDING` state whose `duration` is
authored to the largest of the three blockstun values (13, H's). Rejected: it would make L's
and M's recovery LONGER than their own blockstun, silently breaking the pinned equality for
two of the three divekicks and flattening the height-dependent-advantage shape further behind
a constant offset — the ticket's `combat-resolution.md` criterion 18 language ("recovery ==
blockstun") reads as a per-move invariant, not a character-wide one.
**If JC-095's tuning pass later makes two strengths' blockstun coincide,** the two divekicks
MAY share a landing-recovery state at that point (nothing here blocks it) — not forced now.
Serving: `TKT-P2-11`; `AD-050`; `combat-resolution.md` criterion 18.

### JC-107 · 2026-07-17 · TKT-P2-11 (AD-050) · B-7 regression test drives contact height via direct `PlayerState` injection, not scripted jump timing — ratified
**Decided:** `_test_divekick_height_dependent_block_advantage_b7` (test_character_b_air.gd)
forces B directly into the M divekick's active window at a chosen `pos_y` (mirrors this
file's own established hand-driven-state convention, e.g. the knockdown-landing test), rather
than discovering two jump-altitude/spacing combinations that happen to produce a low vs. high
contact (the technique B-1's own slide test uses for spacing).
**Why:** the divekick's contact height is a function of WHEN during a long, mostly-uniform
descent the hitbox happens to overlap a grounded defender's fixed-height hurtbox — spacing
alone doesn't cleanly select a height the way it selects an active *frame* for the slide
(a single moving hitbox against a stationary defender on the same ground plane). Direct
`pos_y`/`vel_y` injection isolates the CONTACT-HEIGHT variable precisely and deterministically,
without an empirical search over jump-altitude/spacing pairs. A short headless probe (see the
divekick's own trajectory-model header comment for the established practice of discovering
frame numbers this way) found the geometrically valid contact-height band for a standing
defender's hurtbox against this hitbox's box geometry runs roughly `pos_y ∈ (-80, 0)`
(friendly units); heights very close to either edge either land the SAME tick as contact
(pos_y ≈ 0, no room to observe a landing-time difference) or land past the reachable band a
tick or two after the injected position (pos_y ≈ -80, the actual contact height ends up lower
than injected). `-15` (low) and `-60` (high) were chosen from that probe as comfortably inside
the reliable band while maximizing the resulting gap difference (empirically ~5 ticks).
**Also decided:** the test measures relative advantage as `attacker_actionable_tick -
defender_actionable_tick`, driven to BOTH sides actually reaching `Actionability.
is_actionable`, rather than reading `Advantage.live`'s value at the contact tick. AD-050's own
"Observability / `frames_to_actionable`" scope note explains why: read at the exact contact
tick, `frames_to_actionable` uses the divekick's still-generous safety-tail `duration` (not a
fall-time prediction), so a single live-advantage snapshot taken while B is still airborne
would not honestly reflect the eventual outcome — the height-dependent minus is a property of
the interaction RESOLVING, not of the contact-tick instant.
Serving: `TKT-P2-11`; `AD-050`; `character-b.md` criterion B-7.

### JC-108 · 2026-07-17 · flag "re: reaction legibility" (P2-gate headline) · `PlayerView.reaction_kind` — a new DERIVED field resolving state identity, reverse through the character's own `reaction_map` — ratified
**Decided:** the fix for `category_name()` collapsing `STATE_KNOCKDOWN` /
`STATE_HITSTUN_LAUNCH` / `STATE_AIR_RESET` / ordinary hitstun into one word ("hitstun",
since all four share `CATEGORY_HITSTUN`) is a new `PlayerView.reaction_kind: int` field
(default `-1`), computed at `_init` by reverse-scanning the roster character's own
`reaction_map` (`Array[ReactionMapEntry]`) for the entry whose `state_id` equals the
player's current `state_id`. `-1` when no entry matches (an ordinary move/idle/walk
state — ​not a reaction). `LiveStatePanelModel.identity_name()` reads it and leads the
row with the specific word ("knockdown"/"launch"/"air reset"/"hitstun"/"blockstun"/
"crouch blockstun"); `category_name()` is kept and shown ALONGSIDE it in `format_row`
(`cat:%s`), never dropped — per the flag's explicit "category is real information and
may stay alongside; it is not a substitute for identity."
**Why a new PlayerView field, not a panel-local lookup:** the panel model only holds an
`InspectionView`/`PlayerView`, never the character roster (`InspectionView._roster` is
private, with no accessor) — so the identity lookup has to happen wherever the roster is
already in scope, which is `PlayerView._init` (the same place `state_category`/`invuln`/
`boxes` are already resolved off the SAME `character`/`move` lookup, `move-format.md`
"the state-machine reads that need move data"). This mirrors `invuln`'s own documented
shape exactly: "a DERIVED projection (like box geometry) — not a serialized `SimState`
field." No new `SimState` field, no new engine primitive — purely a reverse read of data
`Character.reaction_map` already carries (AD-049's own forward accessor,
`reaction_state(kind)`, is the SAME map read the other direction).
**Ambiguity note, and why it's not a correctness risk for the real roster:** a
`reaction_map` COULD in principle alias two kinds onto the same `state_id` (first match
wins), but JC-104 already established real roster characters (A, B) map every kind to a
DEDICATED state — only pre-AD-049 test-only fixtures alias, and this field is a training-
mode readout concern, not a resolution-path concern (nothing in the sim reads it back).
**Alternative passed over:** add a `display_name`/`state_name` string field authored
directly on `MoveState` (one label per state, set by content). Rejected: broader surface
change (every character's every `MoveState` would need authoring, including non-reaction
states like every normal/idle/walk — a much bigger authoring lift for a defect that's
specifically about the four REACTION states colliding), and it would duplicate
information `Character.reaction_map` already carries for exactly the states in question
— the flag names `ReactionKind` specifically ("surface the ReactionKind / the state's own
identity"), and reusing the existing authored mapping is the minimal, DRY fix.
**Spec note (routing, not asking):** `inspection-surface.md`'s `PlayerView` field table
does not yet list `reaction_kind` — flagging this in the entry so the Architect can fold
it in on ratification (the established pattern for prior additive derived fields, e.g.
AD-046/`air_action_used`), not asking permission to proceed; the fix ships now per the
flag's own "the requirement is mine, stated so it isn't re-litigated."
**Also audited (same flag, "fix the class, not just the instance"):** `FrameDataPanelModel`
(names `guard_height`/`block_valid`/advantage distinctly, no collapse), `InputHistoryPanelModel`
(decodes raw direction/button bits individually, no collapse), `MatchPanelModel` (phase/
reason each have their own name table, no collapse), `DummyModeIndicator` (each of the
three dummy modes already has its own label). A repo-wide grep for `category_name`/
`CATEGORY_HITSTUN`/`state_category` usage outside `live_state_panel_model.gd` returns
nothing — the collapse was isolated to this one panel, not a repeated pattern.
Serving: `docs/flags.md` (2026-07-17, "re: reaction legibility"); `inspection-surface.md`
`PlayerView`; `training-mode.md` "Live-state panel."

### JC-109 · 2026-07-17 · flag "re: B-5 facing readout" · facing surfaced in the live-state row, not a new panel — ratified
**Finding (the flag's concrete question):** facing was **not** exposed in any training-
mode readout before this session. `PlayerView.facing` existed (sim truth, used
internally by `InputHistoryPanelModel.recognized_commands` for command recognition) but
no panel ever displayed it — B-5 was NOT satisfied.
**Decided:** add `facing` to `LiveStatePanelModel`'s existing per-player row/`format_row`
(`"facing right"`/`"facing left"`), rather than a new dedicated panel/overlay. This is
exactly the brief's own instruction — "expose it as ordinary state alongside advantage
and stun" — and the live-state panel is where `state_id`/`stun`/`actionable` already
live; a second panel for one int would fragment the "ordinary state" reading the brief
asks for. No crossup callout, no comparison to the opponent's position, no "you got
crossed up" language — just the raw fact, discoverable on a frame-step after the fact,
exactly like every other field in this row.
**Alternative passed over:** a small dedicated "facing" indicator (mirrors
`DummyModeIndicator`'s own always-on-top single-fact pattern). Rejected: that pattern
exists for state living OUTSIDE `SimState` (dummy mode) that has no natural home in the
`InspectionView`-backed panels; facing IS ordinary `PlayerView` sim truth with an
obvious home already, so a second overlay would be an unnecessary new surface for a
one-field addition the brief explicitly frames as "the same way it exposes advantage and
stun" (i.e., IN that panel).
Serving: `docs/flags.md` (2026-07-17, "re: B-5 facing readout"); `briefs/character-b.md`
"What B-5 actually requires."

### JC-110 · 2026-07-17 · flag "re: HUD (round 2)" · training_mode.tscn layout resized against REAL font-measured worst-case text, not box math — ratified
**Decided:** replaced the prior box-only fix (JC-101, which asserted no two `Control.rect`s
overlap) with a layout resized against the ACTUAL rendered glyph extents Godot's own
`Font.get_multiline_string_size()` produces for each panel's real formatter output under a
realistic worst-case content model, verified in a new `test_hud_layout.gd`:
1. **Enabled `autowrap_mode = 3` (WORD_SMART)** on `FrameDataPanel`/`LiveStatePanel`/
   `InputHistoryPanel`'s Labels (mirrors `ControlsLegend`'s existing convention) — none of
   the three previously wrapped, so a single Live-State row rendered ~1360px wide
   unwrapped from a 16px margin, sailing past every panel to its right regardless of box
   size. This was the root cause the box-rect proxy could never see.
2. **Widened the left column** (`FrameDataPanel`/`LiveStatePanel`/`InputHistoryPanel`)
   from 504px to 720px and **restacked their heights** (154/115/161px content) to fit the
   REAL measured wrapped text — narrower wrapping needs MORE height, so width and height
   trade off; 720px was chosen as the widest the left column can go before the 14px gap
   before the right column (which starts x=750, unchanged).
3. **Lowered `InputHistoryPanel.max_rows` from 16 to 8** (a pre-existing, documented
   display-only cap — "so a long history doesn't have to fully render every tick") — at 16
   rows the panel's real wrapped content needed ~207px, which didn't fit the left column's
   available vertical budget alongside the other two panels; 8 rows is still a materially
   useful recent-input window and fits with real margin.
4. **Reduced `ControlsLegend`'s Label font size from 16 to 14** (a `theme_override_font_
   sizes/font_size` on that one Label only) — its real wrapped content needed 483px height
   at the original 16px size, more than the right column's available room once
   `DummyModeIndicator`/`MatchPanel` are stacked below it; at 14px it needs 400px, which
   fits with margin. Scoped to the legend specifically (a static keybinding reference, not
   a live numeric readout) — every other panel keeps its original font size.
5. **Added `TrainingMode.HUD_LEFT_COLUMN_SAFE_MAX_Y = 442.0`**, a single named constant
   derived from `GeometryOverlay.compute_world_framing(Vector2(1152,648))` applied to the
   idle pushbox height every roster character authors (40 world units) — the symmetric-
   start characters' box top lands at screen y≈456.48 (computed directly, not guessed).
   442 is the actual bottom edge my new left-column layout reaches, with ~14px real margin
   below the true character-occlusion ceiling. `test_geometry_overlay.gd`'s own AD-035
   `PANEL_MAX_Y` (previously a hardcoded, more-conservative `380.0` guess) now reads this
   SAME constant, so the HUD layout and the AD-035 occlusion test can never silently drift
   apart again.
**Why a real-measurement test, not another box assertion:** `docs/flags.md`'s own framing
of this flag names the prior fix's exact failure mode — "measured boxes as a proxy for
text, and text overflows its box." `test_hud_layout.gd` loads the ACTUAL
`training_mode.tscn` (not a hand-rebuilt node tree), drives each panel's REAL static
formatter (`FrameDataPanel._format`, `LiveStatePanel._format`, `InputHistoryPanel._format`,
`ControlsLegend.build_legend_text`, `DummyModeIndicator.build_indicator_text`,
`MatchPanelModel.format` — the exact functions `_refresh()` calls in production) with a
worst-case-but-REALISTIC content model (maxed digit counts a real match can actually
produce simultaneously, not artificially inflated numbers), and measures the resulting
text via the SAME font/TextServer measurement Godot itself uses to lay text out, respecting
each Label's real `autowrap_mode`/width from the `.tscn`. Confirmed this test actually
exercises the claim: run against the PRE-fix `.tscn` (git-stashed for the check, not
committed), it fails with the EXACT shape the flag reports — `LiveStatePanel`'s rendered
text overlapping `ControlsLegend`'s, `ControlsLegend`'s overlapping `DummyModeIndicator`'s,
and `LiveStatePanel` overflowing the viewport horizontally.
**Alternative passed over:** keep panels at their original 380px-and-under vertical
footprint (matching JC-101's stated assumption) and solve the overlap purely by shrinking
font size project-wide. Rejected: font-size reduction was reserved for `ControlsLegend`
specifically (the one panel with no occlusion headroom AND the least need for large
numerals, being a static keybinding reference) — shrinking the numeric readout panels
(frame data / live state / stun / advantage) trades legibility of the actual gameplay
numbers to solve a legend-text problem, which the audit criterion's half 2 ("did it dumb
anything down") would flag; widening + real measurement solved it without touching those.
**Alternative passed over:** a two-column text layout for `ControlsLegend` (JC-101
explicitly declined this for being out of scope of a geometry-only flag). Not revisited
here either — the font-size reduction alone closes the gap with real margin, so the larger
text-layout change wasn't needed.
**Spot-checked, not solved by this ticket:** whether the geometry overlay's own box
rendering (not the readout panels) ever occludes/gets-occluded-by anything is
`test_geometry_overlay.gd`'s existing, unmodified concern (AD-035) — this session only
updated its one `PANEL_MAX_Y` constant to source from the same real-geometry-derived value
my new layout is designed against, per point 5 above; the test's own logic/assertions are
untouched.
Serving: `docs/flags.md` (2026-07-17, "re: HUD (round 2)"); `training-mode.md` criterion
14; AD-035.

### JC-111 · 2026-07-17 · flag "re: throw hitbox geometry" · retuned to ~a tenth AREA (15×25 vs 60×60), re-centered on the torso, not a literal ×0.1 of each dimension — ratified
**Decided:** both characters' throw `HitBox.box` (`character_a.gd`/`character_b.gd`
`_build_throw`) moves from `Box.make(10, -60, 60, 60)` (area 3600; world reach to
attacker+70 — 25 units past even the FAR edge of a defender's 30-wide hurtbox at the
tested 30-unit throw range) to `Box.make(10, -30, 15, 25)` (area 375, ratio ~9.6 —
"roughly a tenth," matching the user's estimate) — kept identical between A and B since
both characters author identical `_hurt_stand`/`_hurt_crouch` dimensions.
**Why NOT a literal ÷10 of width/height (6×6):** the old box's `y=-60` origin already sat
20 units above the character's own head (character hurtbox height is 80, spanning
`-80..0`) — a pure ÷10 scale keeps that same disproportionate origin, shrinking the box to
a tiny sliver floating near head height, comfortably outside a CROUCHING defender's
shorter `-55..0` hurtbox. Instead re-centered vertically on the torso (`y=-30`, `h=25` →
spans `-30..-5`), which sits inside BOTH `_hurt_stand`'s `-80..0` and `_hurt_crouch`'s
`-55..0` ranges — so stance doesn't change whether the throw connects (matching the
existing "throws bypass block" design and the flag's own "beats a downback hold"
confirmation to KEEP). `x=10`/width `15` were sized to still comfortably overlap a
defender's hurtbox at the exact 30-unit gap the existing throw-connect tests (A's and B's
`_test_throw_connects_through_block`/`_tech_window`/`_hard_knockdown`) already exercise —
confirmed by running them green, not by construction alone.
**Verified the retune doesn't quietly break the "beats a downback hold" behavior**, which
had NO prior automated coverage (the existing throw-connect test only held a STANDING
back-block). Added `_test_throw_connects_through_crouch_block_downback` to both
`test_character_a.gd`/`test_character_b.gd`: defender starts in `STATE_CROUCH`, holds
DOWN+RIGHT (down-back) throughout, asserts the throw still lands a hard knockdown.
Confirmed this test can fail (not a tautology): temporarily moved the box to `y=-80,h=5`
(a tiny sliver at head height, outside `_hurt_crouch`'s `-55..0` range) — the new test
failed exactly as expected; reverted to the real tuned value, green again.
**Alternative passed over:** a literal ÷10 scale of each dimension (6×6), keeping `x=10,
y=-60` unchanged. Rejected per the above — it would either whiff entirely at the tested
30-unit throw range (world reach only to attacker+16, short of a defender's hurtbox near
edge at attacker+15... under gap 30 with hurtbox width 30 the near edge sits at
attacker+15, so a 6-wide box barely grazes it with zero real margin) or, if nudged closer
to compensate, still float near head height rather than the torso — a materially worse,
less physically sensible box than a torso-centered one at the SAME "roughly a tenth"
area the user asked for.
Serving: `docs/flags.md` (2026-07-17, "re: throw hitbox geometry"); AD-016/AD-029's throw
model (unchanged — geometry-only tuning, no new throw rule).

### JC-112 · 2026-07-17 · flag "re: JC-095 provisional tuning — settled" · slide distances now vary by strength via THREE sibling states (STATE_SLIDE_L/M/H), not one number bumped — ratified
**Decided:** to satisfy "the slides' distances should vary much more between strengths," first
had to establish there was ANY variation to widen — there wasn't. `236`+L/M/H previously all
routed to the SAME canonical `STATE_SLIDE` (a prior logged latitude call: "the spec describes
exactly one move's behavior under three input strengths"), so button strength had ZERO effect
on distance, not merely a small one. Added `STATE_SLIDE_L` (363) and `STATE_SLIDE_H` (369) as
new sibling states — `STATE_SLIDE` (365) kept as the M-strength id, UNCHANGED, so every
pre-existing test referencing it (`test_character_b_air.gd`'s B-1 spacing tests) keeps testing
the exact same state. All three share EVERY frame-data property (startup/active/recovery/
damage/hitstun/blockstun/hitstop/hit_reaction/hitbox geometry) via one parameterized
`_build_slide(state_id, id_group, speed)`, differing ONLY in `motion_vel_x` (hence total travel
during the active window): `SLIDE_SPEED_L=2.5`, `SLIDE_SPEED` (M)=5.0 (unchanged),
`SLIDE_SPEED_H=9.0` — H now travels 3.6x L's distance (was 1x, i.e. identical). The button_map's
three `MOTION_236` entries now each target their own strength's state instead of all three
collapsing onto one.
**Why this doesn't reopen the prior "one canonical move" call, just extends it:** that call's
own stated reasoning was "the spec describes ONE MOVE'S BEHAVIOR under three strengths, not
three distinct move shapes" — B-1's spacing-dependent-advantage mechanism. Three sibling states
sharing identical frame data and differing only in speed keep that behavior IDENTICAL and
IDENTICALLY-MECHANISMED per strength (each state still has ITS OWN single moving hitbox on one
keyframe spanning the whole active window) — this is "one move's behavior, three speeds," not
three distinct move shapes. The earlier call is about SHAPE (frame data / hit properties), which
is still shared; only DISTANCE (a single scalar) now varies, per this flag's explicit direction.
**New regression coverage** (there was none before — B-1's tests only ever drove
`STATE_SLIDE` directly, never checked strength varied anything): `_test_slide_l_m_h_are_
distinct_with_varying_distance` (three distinct states, shared frame data, H >= 2x L's total
distance) and `_test_slide_button_map_routes_each_strength_to_its_own_state` (236+L/M/H each
resolve their own state, not all three collapsing onto one — the literal pre-fix defect).
**Alternative passed over:** keep one canonical `STATE_SLIDE` and vary distance by reading the
triggering BUTTON strength at resolve time. Rejected: `move-format.md`/AD-018 keep the input
layer semantically blank once resolved to a `state_id` — a `MoveState` has no way to know which
button reached it (by design, so state behavior never depends on input-layer trivia); the only
way to vary behavior by strength in this format is authoring three states, exactly how the
divekick/arc projectile already do it.
Serving: `docs/flags.md` (2026-07-17, "re: JC-095 provisional tuning — settled"); `character-b.md`
"Low slide."

### JC-113 · 2026-07-17 · flag "re: JC-095 provisional tuning — settled" · arc projectile L/H height retune via scaled (vel_y, gravity) — and a real duplication bug it uncovered — ratified
**Decided (the tuning):** B's `H` arc projectile's apex retuned "a little lower," `L`'s "much
higher," per the settled direction. Both changes scale `spawn_vel_y` and `gravity` by the SAME
factor rather than touching either alone or `spawn_vel_x`: apex ∝ vel_y², time-to-apex ∝
vel_y/gravity — scaling BOTH by k scales apex by k while the ratio (hence time-to-apex/total-
airtime/total-horizontal-distance) is unchanged. `L`: `vy -6.0→-24.0`, `gravity 0.5→2.0` (k=4,
apex ~4x, landing spot/timing UNTOUCHED — still the "falls right in front" oki version). `H`:
`vy -13.0→-11.0`, `gravity 0.3→0.25` (a modest, non-uniform-k reduction picked for round numbers
— apex ~282→~242, ~14% lower — reach/hangtime shift by <2%, negligible). `M` untouched (the flag
named only H and L). Real landing distances (not the idealized continuous-physics formula, which
doesn't hold exactly against the discrete sim once the projectile's authored spawn HEIGHT offset
(`-55`, nonzero) is accounted for) verified via `_test_arc_l_falls_closest_to_b_the_oki_version`
run through the actual sim: L now lands ~70 units from B (well under the test's 150-unit "falls
in front" bar), same L<M<H ordering intact.
**A real bug this tuning pass uncovered and fixed:** `character_b.gd` authored EACH arc
projectile's `gravity`/damage/hitstun/etc. in TWO INDEPENDENT PLACES — once embedded in
`_build_arc_projectiles()`'s `kf_spawn.spawn_projectile` (seeds the initial spawn) and again in
`build_projectile_registry()` (the roster a caller installs into `ProjectileRegistry`, which
`step_phases.gd`'s phase-3 integration reads from EVERY TICK for the projectile's ongoing
gravity — NOT the embedded copy). My first tuning pass edited only the first copy, which
silently left the SECOND (the one that actually governs live physics) at the OLD `gravity=0.5`
— `_test_arc_l_falls_closest_to_b_the_oki_version` caught it immediately (measured L landing
214 units out, not ~70). Consolidated both onto ONE source, `_arc_params()` (a plain array of
per-strength tuples), with `_build_arc_projectiles()` and `build_projectile_registry()` both
reading it — this class of drift (two independently-authored copies of the same fact) is exactly
what the project's own single-source-of-truth discipline exists to prevent, and it is now
structurally impossible for these two to disagree again. Added
`_test_arc_projectile_registry_matches_embedded_spawn_data`, a direct field-for-field pin
between the two paths, so a future edit to only one of them (if the consolidation is ever
undone) fails immediately rather than via a downstream landing-distance symptom.
**Not a flag:** the duplication was a pre-existing latent defect (present since AD-047 first
authored these, unrelated to this session's numbers), not a design/contract question — fixing it
is squarely "the authored data was wrong in a way that broke a passing test," Developer-owned.
Serving: `docs/flags.md` (2026-07-17, "re: JC-095 provisional tuning — settled"); AD-047.

### JC-114 · 2026-07-17 · flag "re: JC-095 provisional tuning — settled" · divekick L/M dive_vx increased, capped below the point where a straight-up jump-in whiffs — ratified
**Decided:** `DIVEKICK_L_DIVE_VX` 1.0→2.0, `DIVEKICK_M_DIVE_VX` 4.5→7.0 (H's `0.0` untouched, per
the flag's own "H and the hang profiles are fine"). Not scaled to a larger, rounder-looking
jump (e.g. L→3.0) because `_test_divekick_connects_on_hit` — a straight-up jump then immediate
L divekick onto a defender directly below the TAKEOFF point (the classic "jump up, divekick the
person under you" use) — started failing at `vx=3.0`: the horizontal drift during L's short
hang+dive carries B measurably past a stationary defender's ~15-unit hurtbox half-width before
the active window's hit resolves. `2.0` is the largest value (of the round numbers tried) that
still passes that connect test — a real functional floor, not an arbitrary compromise: a
divekick whose basic straight-down jump-in application whiffs against a stationary target is a
regression, not a legibility improvement. Added a floor assertion to the existing pairwise-
distinct test (`vx[0] >= 2.0`, `vx[1] >= 6.0`) so a future edit can't silently drift the
horizontal component back toward zero without failing a test that says why not to.
**Alternative passed over:** `vx=3.0` for L (a rounder-looking 3x the original). Rejected per
the above — verified failing against `_test_divekick_connects_on_hit`, not assumed.
Serving: `docs/flags.md` (2026-07-17, "re: JC-095 provisional tuning — settled"); `character-b.md`
"Divekick" / B-3.

### JC-115 · 2026-07-17 · flag "re: JC-095 provisional tuning — settled" · 6H forward creep via the same has_motion keyframe mechanism the slide/divekick already use — ratified
**Decided:** 6H's startup keyframe (frames 1-22) now authors `has_motion=true`/
`motion_vel_x=FP.from_units(1.0)` — a modest creep (22 units total over the full startup, about
half the character's own pushbox width) rather than a dash-in, per the flag's own "move forward
SLIGHTLY." Reuses the EXACT mechanism the slide/divekick already exercise (AD-043's keyframe-
motion convention: a fixed velocity re-imposed every covered tick) — no new engine primitive.
Verified through the real engine, not just the authored keyframe flag: a new
`_test_6h_creeps_forward_during_startup` steps 6H for 21 ticks and asserts `pos_x` actually
moved forward, since an authored `has_motion=true` alone doesn't prove the engine applies it
every tick (the class of gap `docs/audit-criterion.md` names — a check that reads authored data
back proves nothing about behavior).
**Why 1.0, not a bigger number:** no test forced a specific ceiling here (unlike the divekick's
connect-test floor above) — 1.0 is a plain judgment call sized to read as a "creep" per the
flag's own wording, not derived from a constraint. If the human gate wants it more pronounced,
that is exactly the kind of numeric follow-up this same flag mechanism handles.
Serving: `docs/flags.md` (2026-07-17, "re: JC-095 provisional tuning — settled"); `character-b.md`
"6H."

### JC-116 · 2026-07-20 · flag "re: instrument ergonomics — match reset" · `do_reset()` in match mode restarts the whole match (fresh `MatchState.new_match`), not a snapshot restore — provisional
**Decided:** `TrainingMode.do_reset()` — what `R`/`tm_do_reset` already binds to (`_unhandled_input`) — now, in match mode, calls a new private `_restart_match()`: build a fresh `MatchState.new_match(CharacterA.CHAR_ID, CharacterB.CHAR_ID)` (the SAME construction `_ready_match_mode()` used to build the match the first time) and hand it to `_match_tick_host` via its own pre-existing `set_match_state()`. `capture_reset()`/`has_reset_point()` — the situation-SNAPSHOT slot — are UNCHANGED, still the JC-098 no-op/false in match mode; this is a narrower, separate operation ("restart from the top"), not the missing MatchState-shaped `TrainingHarness` twin JC-098 declined to build.
**Why this doesn't reopen JC-098:** JC-098's scope trim was specifically about the snapshot/restore slot (`capture_reset`/`do_reset`-as-restore/`has_reset_point`), which needs a MatchState-shaped `TrainingHarness` twin (real, additive control-surface work JC-098 correctly held outside TKT-P2-08's scope). "Restart the match" needs neither a snapshot slot nor a harness twin — both pieces it needs (`MatchState.new_match`, `MatchTickHost.set_match_state`) already existed for other reasons before this change; this is wiring one existing call to another, not new match-layer semantics. Per the dispatch's own instruction, this is exactly the "clean wiring" branch, not the "stop and flag" branch.
**Deliberately untouched:** `_source_p1`/`_source_p2` (their recorded buffers / dummy record-playback mode are orthogonal to match state) and `MatchTickHost._frames_queried` (its own field doc already establishes it is a plain per-real-tick production counter into the sources' growing `_answers` array, decoupled from `state.sim.tick` BY DESIGN — a match restart resets the tick clock, not the sources' production history, so nothing here can desync).
**Alternative passed over:** build the full MatchState-shaped `TrainingHarness` twin JC-098 deferred, and route the match restart through a proper capture/restore slot. Rejected as materially larger than the flag asked for ("bind R to restart the match," not "add mid-match snapshotting to match mode") and exactly the kind of scope growth the dispatch instructed to stop and flag rather than build — this fix needed neither a snapshot nor new state-machine behavior, so it stayed wiring.
**New regression coverage:** `_test_match_mode_do_reset_restarts_the_match` (`test_training_mode_shell.gd`) drives a match past ROUND_START into ACTIVE with real tick progress, calls `do_reset()` through the shell's own public surface, and asserts the match is genuinely back at ROUND_START/full health/tick 0 (not merely that some field changed), then re-drives it through ACTIVE again to confirm the restarted match is still steppable, not half-wired.
Serving: `docs/flags.md` (2026-07-17, "re: instrument ergonomics — match reset"); JC-098.
