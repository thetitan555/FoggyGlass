# Flag Ledger

> Open flags only (plus resolved-awaiting-relay). Closed entries live in
> `flags-archive.md`. Mechanism, ownership, and relay: `protocol.md` → "How a
> flag works."

---

### [resolved] 2026-07-17 · raised-by: User (P2 re-gate) · owner: Developer · re: reaction legibility — THE HEADLINE DEFECT
Problem, as reported: **"the slide doesn't cause a knockdown on A. I can't get a
knockdown by any means, and I can't test an oki setup without a knockdown"** — the
slide read as **state 123, hitstun**; B's `2H` read as **125 then 123**, both
"hitstun"; A's `2H` put B into **325 then 324**, likewise.

**Correction, established before dispatch — knockdown is NOT broken. Every one of
those observations is the system working correctly, and the instrument lying about
it.** Read against `game/content/character_a.gd`:
- **123 = `STATE_KNOCKDOWN`.** The slide *is* causing a hard knockdown, direct to the
  shared knockdown state with no air trip — exactly as B-1 briefs and AD-043 specs.
- **125 = `STATE_HITSTUN_LAUNCH`, 122 = `STATE_AIR_RESET`.** "125 then 123" is a
  launch landing into the shared knockdown — the precise AD-043/AD-049 behaviour.
- **325/324** are B's own equivalents. Cross-character reactions resolve correctly.
- A's `reaction_map` is complete and correct (`REACTION_KNOCKDOWN → STATE_KNOCKDOWN`).
  The AD-049 floor is **not** being hit. There is no content hole.

**The actual defect, and it is one bug, not two:** `live_state_panel_model.gd`'s
`category_name()` labels the readout with the state's **`category`**, and
`STATE_KNOCKDOWN`, `STATE_HITSTUN_LAUNCH`, `STATE_AIR_RESET` and `STATE_HITSTUN` all
carry `CATEGORY_HITSTUN`. So all four render as the single word **"hitstun"**, and the
only thing separating them on screen is a raw integer state id the player would have to
have memorised.

**Why this is the most important finding of the re-gate.** With no art or audio, the
instrument is the *only* channel carrying this information — and its opacity caused
**the project's own gate-holder**, holding the brief, to conclude that a working,
briefed, load-bearing mechanic did not exist, and to report the oki test as
un-runnable. That is not a near-miss. That is `audit-criterion.md` half 1 failing
against us, at full strength, on the charter's centerpiece surface: *the player could
not find out what happened.* Every argument this project makes for legibility just got
demonstrated on ourselves.

**Fix (the requirement is mine, stated so it isn't re-litigated):** surface the
**`ReactionKind` / the state's own identity** in the readout — knockdown reads
"knockdown," launch reads "launch," air-reset reads "air reset." `briefs/character-b.md`
("What B looks like when it *receives*") requires these three be tellable apart on
sight, because they demand different responses — juggle incoming, wakeup mixup
incoming, or nothing — in the same airborne moment. Category is real information and may
stay; it is not a substitute for identity. Do **not** add a crossup-style answer key —
transparency, never an answer.
**Also fix the class, not the instance:** `category_name()` collapsing four distinct
states into one word is a *labelling* bug of the same shape as AD-049's id bug —
information exists in the sim and is destroyed on the way to the human. Audit the other
readouts for the same collapse and report what you find.
**Gate consequence to relay back:** gate item 9 (oki / B-2) is **testable after all** —
it was never blocked by a missing knockdown.
---
Resolution (Developer, 2026-07-17): Fixed. Added `PlayerView.reaction_kind` — a derived
field (mirrors `invuln`'s pattern) that reverse-resolves the current `state_id` through
the roster character's own `reaction_map` (the same map AD-049's `reaction_state(kind)`
already reads forward) to the state's own `ReactionKind`, or `-1` for an ordinary
non-reaction state. `LiveStatePanelModel.identity_name()` reads it and leads each row
with the specific word — "knockdown" / "launch" / "air reset" / "hitstun" / "blockstun" /
"crouch blockstun" — with `category_name()` kept alongside (`cat:%s`), never dropped, per
the requirement that category "is real information and may stay." No answer-key added —
the fix names WHAT STATE a player is in, never what the opponent should do about it.
Regression test (`test_live_state_panel.gd`) drives character A's actual
`STATE_HITSTUN`/`STATE_HITSTUN_LAUNCH`/`STATE_AIR_RESET`/`STATE_KNOCKDOWN` through the
real readout path and asserts the 4 rendered lines are distinct AND each contains its
correct word — fails against the pre-fix code (all 4 rendered identically). **Audited the
other readouts for the same collapse shape** (frame-data, input-history, match,
dummy-mode indicator) — none found; a repo-wide grep for `category_name`/
`CATEGORY_HITSTUN` usage outside `live_state_panel_model.gd` returns nothing, so the
defect was isolated to this one panel, not a repeated pattern. JC-108 records the field
design. Spec note: `inspection-surface.md`'s `PlayerView` table doesn't yet list
`reaction_kind` — for the Architect to fold in on ratification.

### [open] 2026-07-17 · raised-by: User (P2 re-gate) · owner: Developer · re: AD-043 air-move semantics (`combat-resolution.md` criterion 15)
Problem: **performing an aerial as either character snaps it to the ground** (divekicks
excepted). This is the **exact defect TKT-P2-01 was dispatched to fix** — the roadmap's
P2 opener names it verbatim: *"the P1.1 re-gate found an air normal stops the jump arc
and the character snaps to the floor; carrying fall momentum through an air normal and
easing the descent is exactly this deferred half."* `character-b.md` also requires B's
air normals to **carry the fall**. TKT-P2-01 was reported complete, QA passed criterion
15, and the behaviour is unchanged from the P1.1 re-gate that deferred it into P2.
Determine whether the fix never covered air *normals* (as opposed to jump arcs), or
regressed. This is a P2 acceptance criterion that does not hold.
---
Resolution (owner fills): …

### [open] 2026-07-17 · raised-by: User (P2 re-gate) · owner: Developer · re: AD-046 air-action economy / `briefs/character-a.md`
Problem: **character A can attempt an air dash and a double jump**, which instantly
halt its air momentum. Two defects in one: A should have **neither**, and the thing it
does get is broken.
Air mobility is **B's signature and A's deliberate absence** — `briefs/character-b.md`
is explicit that "A's brief explicitly *reserved* air-mobility complexity for the
contrast," and A's only briefed dash is the **grounded** `66`/`44` (TKT-P2-02, the
"wire existing states to the shared recognizer" call). A having air actions dilutes the
A/B contrast the entire P2 content-seam thesis rests on.
Note the shape: this is the **mirror of AD-049**. There, two characters were coupled
through an id namespace the format never declared; here, the **engine appears to impose
kit on a character its content never authored**. Both are content-seam violations. If
AD-046 genuinely specs the air-action commands as engine-generic rather than
data-gated, that is an **Architect** call — flag it up, don't re-scope it yourself.
---
Resolution (owner fills): …

### [open] 2026-07-17 · raised-by: User (P2 re-gate) · owner: Developer · re: `match-flow.md` (sudden death) criteria 1–8
Problem: **sudden death cannot end the match.** It grants a point to **both** players,
and further wins increment both counts indefinitely — `MATCH_END` is unreachable. The
tie-at-match-point rule is briefed in `briefs/match-flow.md` and specced under AD-048;
this is a state-machine defect against `match-flow.md` criteria 1–8, which QA passed.
Non-blocking observation from the same item, **not** a defect: after the final round the
game shows "match over" and stops until the window is closed. That is acceptable for the
slice (no restart flow is in scope) — see the separate instrument-ergonomics flag below.
---
Resolution (owner fills): …

### [open] 2026-07-17 · raised-by: Strategist · owner: QA · re: `test_character_b_air.gd` and the shape of our tests
Problem: **the slide's knockdown has a test, it passes, and it could not have caught
this.** `test_character_b_air.gd:301` asserts
`hit_reaction == MoveState.REACTION_KNOCKDOWN` — it reads the **authored data field**
back and checks it equals the constant it was authored as. It never drives a slide into
a defender and observes a knockdown happen.
That test cannot fail for any realistic defect in knockdown *resolution*. It is the
exact pattern `audit-criterion.md` → "Exercise the thing, not a proxy for it" now
forbids: assert-the-data-you-authored is a tautology wearing a test's clothes. (In this
instance resolution happened to work — but the test contributed nothing to knowing that,
and it is *why* nobody knew.)
Not a criticism of the method you were given — my cross-cutting check invited exactly
this, and the criterion that forbids it landed after your P2 audit. The ask: **on the
re-audit, sweep the suite for the same shape** — tests that read back authored constants,
assert on `.rect`s instead of rendered output, or verify a field instead of a behaviour —
and report the count. I want to know how much of our 44/44 is load-bearing. If the answer
is "a lot of it isn't," that is a finding I need, not one to soften.
---
Resolution (owner fills): …

### [resolved] 2026-07-17 · raised-by: User (P2 re-gate) · owner: Developer · re: `game/scenes/training_mode.tscn` (HUD, round 2)
Problem: **text still overlaps.** Specifically: the **Live State** lines extend right
past their box and collide with the controls legend; the **dummy-passthrough** and
**match** overlay text collide with the bottom of the controls text. The match result
itself is now legible (that half of the prior fix worked).
Note for the owner, and it is the point of this flag: the previous fix was verified by
loading the `.tscn` and asserting that no two `Control.rect`s overlap. **That measured
boxes as a proxy for text**, and text overflows its box — which is precisely the failure
`audit-criterion.md` → "Exercise the thing, not a proxy for it" now names. Verify
**rendered text extents**, not rects, or say plainly that you cannot and route it to the
gate.
---
Resolution (Developer, 2026-07-17): **Rendered text extents ARE headlessly measurable in
Godot** (via `Font.get_multiline_string_size`, the same measurement the engine's own
TextServer uses to lay text out) — no routing to the gate needed for the objective half.
Root cause: none of `FrameDataPanel`/`LiveStatePanel`/`InputHistoryPanel`'s Labels had
autowrap enabled, so their text rendered on a single unbounded line (a 2-player Live-State
row measured ~1360px wide from a 16px margin) regardless of box size — the exact reason a
box-rect check (JC-101) could never catch it. Fixed: enabled autowrap on all three, resized
the whole layout (left column widened to 720px / restacked heights; `InputHistoryPanel.
max_rows` 16→8; `ControlsLegend`'s Label font 16→14) against REAL measured worst-case
content, and added `test_hud_layout.gd`, which loads the actual `.tscn`, drives each
panel's real formatter with realistic worst-case content, measures the real rendered
extents, and asserts no two overlap (and none crosses the AD-035 character-occlusion line,
via a new shared `TrainingMode.HUD_LEFT_COLUMN_SAFE_MAX_Y` constant also now used by
`test_geometry_overlay.gd`). Verified the new test actually catches the regression: run
against the pre-fix `.tscn`, it fails with the exact overlaps this flag reports. JC-110
records the layout design in full.

### [resolved] 2026-07-17 · raised-by: User (P2 re-gate) · owner: Developer · re: throw hitbox geometry
Problem: **the grab hitbox is comically large** — the user's estimate is that it should
be roughly **a tenth** of its current size. Positive confirmation from the same item, to
keep: **the throw correctly beats a downback hold** (AD-016/029 model working as
intended).
---
Resolution (Developer, 2026-07-17): Retuned both characters' throw hitbox from
`Box.make(10, -60, 60, 60)` (area 3600 — reached 25 units past even the FAR edge of a
defender's hurtbox at the tested range) to `Box.make(10, -30, 15, 25)` (area 375, ~a
tenth), re-centered vertically on the torso rather than a literal ÷10 of the old
(disproportionately head-height) origin. Preserved the positive behavior with a NEW
regression test — the existing suite only covered a standing-block throw connect, never a
down-back/crouch one — `_test_throw_connects_through_crouch_block_downback` (both
characters) drives a `STATE_CROUCH` defender holding down-back and confirms the throw
still lands; confirmed the test can actually fail (tried a deliberately-too-high box,
watched it fail, reverted). All existing throw-connect/tech/knockdown tests (gap=30, the
same spacing this box is tuned against) stay green. JC-111 records the full sizing
rationale.

### [resolved] 2026-07-17 · raised-by: Strategist (from user re-gate) · owner: Architect · re: divekick active/recovery semantics (`character-b.md`, JC-095)
Problem: the user's re-gate settles the JC-095 divekick tuning with a call that is
**mechanical, not numeric**, so it needs speccing rather than a Developer tuning pass:
**the divekicks should remain active until they reach the ground, and their ground
recovery should equal their blockstun.**
Why I'm routing this as a contract change and endorsing it rather than passing it
through as a number: the two clauses together generate **height-dependent block
advantage as an emergent property** — hit low and you land almost immediately, so
recovery ≈ blockstun ≈ neutral; hit high and you must still fall the remaining distance
while their blockstun ticks out, so you land deeply negative. That is the *same* shape
as B-1's spacing-dependent slide advantage, which the brief already calls cherished
friction **on the condition that it is observable** — and here the causal variable
(how high you hit) is the most visible thing on screen. It is a better mechanic than a
flat number, and it is not a Developer latitude call.
Constraint carried from the brief: whatever you spec must keep the three divekicks'
**trajectories legibly distinct** (B-3) and keep **H the sole overhead** (B-4).
---
Resolution (Architect, 2026-07-17): Specced as **AD-050** (with the index line and full entry
in `decisions.md`). One new authored `MoveState.landing_state_id` field (default `0`), no new
engine primitive: a divekick's active hitbox is authored through its descent (the AD-043 landing
clamp ends it — `active_hit_ids` keeps it one hit per contact), and on landing it redirects into a
grounded, non-actionable recovery state whose `duration` is authored **equal to the divekick's
`blockstun`** (the pinned equality invariant). `_land` precedence: launched-knockdown →
`landing_state_id` → idle; jumps/air normals (field unset) land to idle unchanged. The two clauses
produce **height-dependent block advantage** as an emergent property (hit low ⇒ ≈ neutral, hit high
⇒ deeply minus), read through the one AD-008 live-advantage formula + neutral-restoration — same
observable-friction shape as B-1, and the causal variable (contact height) is on-screen. Spec:
`decisions.md` AD-050; `move-format.md` (`MoveState.landing_state_id` + movement invariant);
`combat-resolution.md` (phase-3 landing precedence + criterion 18); `character-b.md` (Divekick
"Landing" + criterion **B-7** + Open items closed). Build: **TKT-P2-11**. Constraints honored:
B-3 (trajectories untouched), B-4 (H sole overhead, `guard_height` unchanged, no overhead comes
out sooner), B-2 (holds by construction). The numeric tuning is left to the separate JC-095
Developer flag, as instructed — this resolves the **mechanic** half only. **Scope note ruled in
AD-050:** the emergent advantage is delivered by B's landing-recovery resolving later for a higher
block (read across the interaction, the B-1 bar), *not* by a new fall-time-prediction primitive in
`frames_to_actionable` — that speculative complexity is deferred behind a real need (Tenet 3).

### [open] 2026-07-17 · raised-by: Strategist (from user re-gate) · owner: Developer · re: JC-095 provisional tuning — settled
Problem: the user's re-gate settles the remaining JC-095 numbers. These are **direction,
now recorded** (protocol: a steer in chat is provisional until the owning artifact
records it) — apply them as tuning, and flag back only if one conflicts with a
legibility invariant rather than quietly splitting the difference:
- **B's `H` projectile** — travel distance a little **lower**.
- **B's `L` projectile** — should travel **much higher** before coming down.
- **The slides** — their distances should vary **much more** between strengths.
- **The `L` and `M` divekicks** — should travel **more horizontally**, to read as
  distinct from `H`'s near-vertical plummet (B-3). `H` and the hang profiles are fine.
- **`6H`** — 23f startup and a high hit both read correctly; the user's improvement:
  it **could move forward slightly during startup** to make the overhead tell clearer.
Judged and passing, recorded so they aren't re-opened: the three divekicks' guard
heights (`j.2H` HIGH, `j.2L`/`j.2M` MID) are **fine**; the slide's spacing-dependent
advantage is **still good** (B-1 holding, second confirmation); `2L`/`2M` **enforce
LOW** (AD-045 working).
See the separate Architect flag above for the divekick active/recovery **mechanic** —
do not implement that half from this entry.
---
Resolution (owner fills): …

### [resolved] 2026-07-17 · raised-by: Strategist (from user re-gate) · owner: Developer · re: B-5 facing readout
Problem: the user asks whether it is intended that an airdash crossup shows **nothing
special in the overlay**. **Answered on `briefs/character-b.md`** (new section, "What
B-5 actually requires") — read it; the short version is that no crossup *indicator* is
intended or wanted (it would answer the read the option exists to pose), but B-5 still
requires the **side be discoverable after the fact**.
The concrete question for you: **is facing / blocking-side exposed in `PlayerView` and
shown in the training-mode readouts?** If yes, B-5 is met and this closes as "intended,
already satisfied." If no, expose it as ordinary state alongside advantage and stun —
not as a crossup callout.
---
Resolution (Developer, 2026-07-17): **Not previously satisfied — the gap, not the missing
indicator.** `PlayerView.facing` existed (sim truth) but no training-mode panel displayed
it; it was used only internally by `InputHistoryPanelModel`'s command recognizer. Fixed
by adding `facing` to `LiveStatePanelModel`'s existing per-player row (`"facing
right"`/`"facing left"` in `format_row`) — the same panel that already shows
state/stun/actionable, per the brief's own "the same way it exposes advantage and stun."
No crossup indicator, no comparison to the opponent, no "you got crossed up" language —
the raw fact only, discoverable on a frame-step after the fact. Regression test drives a
facing flip (the crossup shape) through the real readout path and asserts the rendered
line reflects the new facing. JC-109 records the surfacing choice.

### [open] 2026-07-17 · raised-by: Strategist · owner: Developer · re: instrument ergonomics — match reset
Problem: at match end the game stops until the window is closed, and `R` (`do_reset`) is
a **no-op in match mode** (JC-098). Correct as specced, but it means **every re-gate
costs the user a full app relaunch per match** — and the user has now gated this project
six-plus times.
This is tax on our own process, not on the player: the instrument is the surface we
audit *through* (`roadmap.md` P1.1), and the charter's legibility promise is not served
by a gate that is expensive to run. Bind `R` to restart the match in match mode (or say
why that is more than it looks and I'll drop it). **Low priority — do not let this
displace the correctness flags above.**
---
Resolution (owner fills): …
