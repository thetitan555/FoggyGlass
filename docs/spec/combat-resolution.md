# Spec — Frame / Combat Resolution (P0)

> Owned by the **Architect**. How one tick resolves combat — overlap, hits,
> hitstop, stun, advantage, combo accounting — and how each result maps to the
> inspection surface so the debug mode can read it out. See AD-008, AD-009,
> AD-010, AD-011.

## The fixed intra-tick phase order (AD-009)

`step` runs exactly this order, every tick:

1. **Read inputs.** Take the two `InputFrame`s; push each into the player's
   `input_history`; apply SOCD normalization; convert raw L/R to forward/back
   using `facing`.
2. **State machine / buffering / cancels.** Advance `frame_in_state`; run
   buffering and motion/command recognition over `input_history`; apply legal
   transitions and `CancelRule`s (`move-format.md`) per their `condition`/`window`
   /`requires_tag`. A character under hitstop is frozen here: cancels may *buffer*
   but no transition executes until the first unfrozen tick (AD-017). **An actionable
   character in a `loop` state re-derives its state from input each tick, falling back
   to idle when no command matches (AD-038)** — the exit for held-input stances
   (walk/crouch return to idle on release); a committed once-through move keeps the
   "run a buffered command, else stay until it ends" behavior.
3. **Movement integration.** Apply per-state/keyframe motion and physics to
   `position`/`velocity` (fixed-point integers, AD-014); resolve pushbox
   collisions and stage bounds. **Airborne physics (AD-043):** an airborne character
   applies `velocity.y += physics.gravity` then integrates `position += velocity`, with
   `velocity` persisting across airborne state transitions; a keyframe `motion` may *set*
   velocity (jump takeoff, air dash, double jump, divekick dive). **After integration**, an
   airborne character whose `pos_y >= ground_y` is clamped to `ground_y` and transitioned
   `AIRBORNE → GROUNDED` (landing) with velocity zeroed — clamp and landing are one mechanism;
   a **launched (airborne HITSTUN)** character instead transitions to the character's dedicated
   grounded **`knockdown_state_id`** reaction (AD-043, ratified from JC-070), not idle, **re-arming
   `stun` to that state's `duration` on the landing tick** so wakeup counts from landing, not from the
   original hit (ratified from JC-088 — note the intended `duration − 1` same-tick readout there).
   Landing
   **resets `air_action_used`** to false (AD-046). Integrate live projectiles'
   positions too — applying each projectile's own `gravity` (AD-047) before its position — and
   process any `spawn` actions firing this tick (subject to the per-owner cap); an arc projectile
   at `pos_y >= ground_y` despawns.
4. **Overlap detection.** Resolve each character's active hitboxes/hurtboxes/
   throwboxes from move data (derived, not stored) and test AABB overlaps. Include
   live projectile hitboxes vs. the opponent's hurtbox (AD-021). Overlap is
   **strict**: boxes that merely *touch* (share an edge, `a.x + a.w == b.x`) do
   **not** overlap — a box exactly adjacent to a hurtbox does not register (AD-027).
   **Invulnerability gates here** (AD-031): a geometric overlap against a defender
   whose covering keyframe has the matching `invuln_*` flag set does **not** become a
   recorded contact — the incoming box *whiffs*. The whiff is recorded observably on
   the *attacker* (invuln whiff, see "Invulnerability" below), never dropped silently.
5. **Hit resolution.** For each confirmed hit (respecting `id_group` single-hit,
   or `rehit_interval` for cadenced multi-hit), apply damage (after scaling), set
   the defender's `hit_reaction`/`block_reaction` state, set stun, set hitstop on
   both parties, apply pushback/launch, grant attacker `cancel_tags`, update combo
   state. Throwbox connects take the throw resolution path (below).
6. **Advantage / neutral update.** Recompute advantage; flag neutral restoration.
7. **Advance counters.** Decrement `hitstop`, `stun`; advance `tick`. Counters
   under active hitstop do not decrement (see below).

A frozen, ordered pipeline is what makes interaction outcomes deterministic and
gives the debug readout a fixed thing to narrate.

## Input buffer (AD-022)

Buffering is sim-side (AD-003), evaluated in phase 2 over `input_history`:

- **Motion leniency:** a motion (`236`, `623`, …) is recognized if its directions
  occur in order within the last **9 frames**.
- **Command buffer:** a recognized command (special, throw, special-cancel) is held
  up to **6 frames** and executes on the first frame the character is **actionable**
  (reversal on wakeup / after blockstun / after hitstop) or the first frame a
  **cancel window** opens. A `623` buffered during blockstun thus comes out as a
  frame-1 reversal.

Deterministic — a pure function of `input_history`, identical for every input
source (so replays/netcode reproduce it for free).

## Hit vs block

Whether an incoming hit is a block is determined by the defender holding a
blocking direction (raw input resolved to "back" relative to the attacker) in a
blockable state. On block, the defender enters a `BLOCKSTUN` state and takes
`blockstun`/`pushback_block`; on hit, a `HITSTUN` state and `hitstun`/
`pushback_hit`/`launch`. Block correctness is readable (input history + state).

**Directional block enforcement (AD-045).** A back-hold is only a *valid* block if the
defender's **stance** matches the attack's `guard_height` (`move-format.md` → `HitBox`):
`HIGH` (overhead) must be blocked **standing**, `LOW` must be blocked **crouching**, `MID`
either. Stance = the defender's current state's **`MoveState.is_crouch`** flag (ratified from JC-078;
there is no "crouch *category*" — `category` does not distinguish stand from crouch, so stance is this
per-state authored flag resolved off `state_id`).
A back-hold in the **wrong stance** is an **invalid block** and resolves as a **hit**. This is
what makes B's high/low a real, live-readable mixup (charter "no knowledge checks"): the overhead
must *look* like an overhead, and the result is observable — the connecting attack's `guard_height`
and whether the block was valid are surfaced on the `HitRecord`/`HitEvent`, so the training mode
shows *why* a hit landed (a low that beat a stand-block, an overhead that beat a crouch). Default
`guard_height = MID` leaves every P1 move unchanged; this reverses the P1 stance-agnostic-block
simplification (cross-ref AD-045 and its Strategist scope flag).

## Air-normal height-dependent advantage (AD-033)

An **airborne attacker's** connecting strike scales the **hitstun it inflicts** by the
attacker's **contact height** — a *deep* jump-in (attacker close to the ground when the
air normal lands) inflicts more hitstun and so leaves the attacker more plus after
landing; a *high/early* air hit inflicts less and is far less plus (or minus). This is the
mechanism `character-a.md` promises ("deep jump-in = very plus, enabling the grounded
links … sim truth the training mode reads out, not a fixed number"), and it is what makes
route 2 (`j.H , 5M > 623M`) real behaviorally, not just structurally.

- **Where it lives — phase 5, on `hitstun`, through the one advantage formula.** The rule
  scales the **hitstun input** to hit resolution, *not* advantage directly: advantage is
  derived from hitstun by the single AD-008 formula, so scaling the input keeps one
  advantage computation and one place the number comes from (the consistency guard). The
  authored base `HitBox.hitstun` (one flat value — JC-A-04) is the reference; height scales
  a **signed frame delta** on top of it. Block is unaffected (a blocked air normal uses
  `blockstun` as authored — height-scaled *hitstun* only applies on hit; a defender who
  blocks in the air is out of P1 scope anyway).
- **Height reference — the attacker's depth above ground.** `depth = ground_y −
  attacker.pos_y` in fixed-point (screen convention: up is `−y`, so an airborne attacker
  has `pos_y < ground_y` and `depth > 0`; `depth == 0` at the ground). Depth, not raw
  `pos_y`, so the rule is stage-relative and character-agnostic. The **attacker's** height
  is the reference (how deep the *jumping* attacker is), not the defender's — a jump-in is
  "deep" when the attacker connects low.
- **The scaling — one definition, `AirHeightScaling` (mirrors `DamageScaling`).** A single
  sim-wide definition maps `depth` → a signed hitstun **delta** (a pure function of `depth`
  alone, independent of the base — so the surfaced `air_height_hitstun_delta` is exactly
  what height contributed): linearly interpolated and clamped so at `depth ≤ 0` (deepest,
  at/below ground) it returns the maximum bonus (`+DEEP_BONUS`); at or above a reference
  height (`HIGH_REF_DEPTH`, ~the jump apex) it returns the maximum penalty (`−HIGH_PENALTY`);
  between, it interpolates linearly. The final applied hitstun is
  `max(base_hitstun + delta, MIN_HITSTUN)` — a floor so a high hit still leaves the defender
  in a real (if brief) hitstun, never zero or negative. (No separate upper clamp is needed:
  `delta ≤ +DEEP_BONUS` by construction, so the deep-hit ceiling is `base + DEEP_BONUS`
  automatically.) **Single-sourced, no per-move/per-character variant** — the consistency
  guard (an air normal on character B scales the same way). The numbers (`DEEP_BONUS`,
  `HIGH_PENALTY`, `HIGH_REF_DEPTH`, `MIN_HITSTUN`) are **slice-provisional placeholder
  tuning** (feel is the Strategist's via the spec, exactly like `DamageScaling`'s
  step/floor — JC-016); the **mechanism** (single definition, depth→delta, applied
  pre-stun, clamped, surfaced) is the contract. Integer/fixed-point only (AD-014); the
  interpolation is integer FP math, no float — the `depth` and interpolation reference
  points are fixed-point, the returned delta a whole frame count.
- **The gate — attacker is airborne (`category == AIRBORNE`) and the hit is on-hit.** The
  rule applies exactly when the connecting attacker's current state category is `AIRBORNE`
  and the contact is a hit (not block, not throw). A grounded normal is untouched (its
  hitstun is the authored value, unscaled). This is the character-agnostic definition of
  "air normal": an airborne strike, not a named move list.
- **Observable — the live advantage reflects it, and contact height is legible (AD-033).**
  The live advantage read (`AdvantageView`, AD-008) already reflects the scaled hitstun
  because it reads the defender's *actual* remaining stun — so a deep jump-in shows a
  larger plus, live, with no extra plumbing. To answer *why* (charter: "find out what
  happened and why"), the resolved contact height and the hitstun delta it produced are
  surfaced on the hit record: `HitEvent.air_height_hitstun_delta` and
  `HitEvent.contact_depth` (`inspection-surface.md`), so the training mode can show "this
  jump-in connected deep (depth X) → +N hitstun → this much more plus." Without this the
  scaling would be real but invisible — exactly the least-observable thing in most fighting
  games, which is why the Strategist ruled it a legibility win worth building.

No new **per-player** serialized `SimState` field: the scaling is computed in phase 5 from
the attacker's `pos_y` (already serialized) and the authored base hitstun, and its result
flows into the defender's `stun` (already serialized). The two surfaced values live on the
existing `last_hit`/`HitRecord` — a **`HitRecord` shape addition** (two `int` fields:
`contact_depth`, `air_height_hitstun_delta`) that is Architect-owned like every other
serialized-shape change (the AD-024/AD-028 precedent), added to `HASH_FIELDS`/`to_dict`/
`from_dict`/`clone` and covered by the canonical hash (AD-023). On a non-air-normal hit both
are `0` (deterministic default), so ground hits do not perturb the record's meaning — the
fields read "no height scaling applied." This is the same home the other hit-legibility
reads use (`damage_dealt`, `scaling_applied_pct`, …).

## Invulnerability (AD-031)

Invulnerability is a **defender-frame** property authored per keyframe
(`move-format.md` → `Keyframe.invuln`) and consumed in **phase 4**, so an
invulnerable frame never produces a recorded contact for phase 5 to resolve.

- **Kind-gated.** Each incoming box carries a `hit_kind` (`STRIKE` / `THROW` /
  `PROJECTILE`, `move-format.md` → `HitBox.hit_kind`). A defender frame with
  `invuln_strike` set whiffs a `STRIKE` **or** a `PROJECTILE` (a projectile is a
  strike delivered at range — the same immunity beats both); a frame with
  `invuln_throw` set whiffs a `THROW`. Both flags may be set (full invuln). The
  gate reads the **defender's covering keyframe** for its current `frame_in_state`
  — invuln is a property of the frame the defender is *in*, not of the attacker.
- **Suppress-in-phase-4, don't record-then-no-op.** The geometric overlap still
  computes; but a gated overlap is **not appended to the contact list**. It never
  reaches phase 5, so it interacts with nothing there — no `id_group` single-hit
  bookkeeping, no throw-clash scan, no combo/scaling — because a whiffed box is not
  a hit. This is why the check lives in phase 4, at the point contacts are recorded,
  rather than as a phase-5 veto.
- **Projectiles too.** A projectile contact is gated by the defender's
  `invuln_strike` exactly like a character strike (its `hit_kind` is `PROJECTILE`).
  A projectile whiffed by invuln is **not consumed** — it passes through the
  invulnerable frames and may still connect on a later, vulnerable frame (invuln
  makes the *defender* immune this frame; it does not destroy the projectile). This
  is the one place invuln differs operationally from a character strike, and it
  falls out of the suppress-in-phase-4 rule: no contact is recorded, so the phase-5
  "consume on connect" path (which despawns the projectile) never runs.
- **Observable — the whiff has a reason (charter: "find out what happened and
  why").** A hit suppressed by invuln is not dropped silently. The attacker's
  move-contact resolves to **whiff** on the normal whiff edge (its last active frame
  passing with no recorded connect — `move_contact` becomes `WHIFF`, AD-028), and
  the *defender's* current invuln state is directly readable through the inspection
  surface (`PlayerView.invuln`, `inspection-surface.md`). Together these let the
  training mode show "this frame was strike-invulnerable" and attribute a whiff to
  it — the DP beating a jump-in, `2H`'s anti-air invuln, the back dash's escape are
  each legible as *why the hit didn't land*, not just *that it didn't*.

Invuln adds **no new serialized `SimState` field**: it is derived each tick from
the defender's authored keyframe (like box geometry — AD-001), and the whiff it
produces is already carried by the existing `move_contact` truth (AD-028). The
inspection read (`PlayerView.invuln`) is a projection of that derived keyframe
property, not new state.

## Hitstop (AD-010)

- On contact, both attacker and defender receive `hitstop` frames.
- While `hitstop > 0` for a character, that character's `frame_in_state` and
  `stun` **do not advance** — the action is frozen in place.
- The **sim loop keeps ticking**; hitstop is countdown state, not a paused loop.
  Frame-step advances *through* hitstop one tick at a time.
- **Cancels and hitstop (AD-017).** Inputs are still recorded each tick (phase 1
  always runs), so a cancel may be *buffered* during hitstop; the transition
  executes on the first unfrozen tick. `cancel_tags` granted in phase 5 of tick T
  are available to the cancel phase starting tick **T+1** — a uniform one-tick
  grant→consume latency, an inherent consequence of the fixed phase order, not a
  bug.

## Stun & actionability

- `stun` is a per-player countdown (hitstun or blockstun). `stun == 0` and not in
  a committed recovery state ⇒ **actionable**.
- A defender in stun cannot act until it expires; this is the punish/true-string
  window the debug mode surfaces.
- **Actionable-on-the-duration-frame (pinned; ratified from JC-038).** A
  once-through move becomes **actionable on the frame `frame_in_state == duration`**
  itself (`is_actionable` uses `frame_in_state >= duration`), while the
  move-*ended* → return-to-idle transition fires one frame later, on
  `frame_in_state > duration`. This one-frame straddle is **intended and
  load-bearing**: `frames_to_actionable` returns `0` on that same frame (`duration
  − frame_in_state == 0`), so `is_actionable` and `frames_to_actionable` agree
  (both say "actionable now") — the live-advantage formula (AD-008), `PlayerView.
  actionable`, and neutral-restoration all read one consistent answer. It is
  **not** an off-by-one bug: flipping `is_actionable` to `>` would desync it from
  `frames_to_actionable` and shift every advantage read by a frame. This is a
  single-sourced project-wide semantic; any change to it is an Architect contract
  revision (re-verifying every advantage golden), never a per-ticket edit.
- **Authoring hazard — an ALWAYS-cancel window ending at `duration` loses its last
  frame (ratified from JC-038).** Because phase 2 checks the actionable/
  buffered-command branch *before* the cancel branch (the fixed transition
  priority — criterion 2), a move on its `frame_in_state == duration` frame is
  actionable and takes the buffered-command branch, so the cancel branch is never
  reached on that frame. Consequently an ALWAYS-cancel whose `window_end ==
  duration` is structurally **unreachable on its own last frame**. **Rule:** author
  such an ALWAYS (input-gateless) cancel window to end at **`duration − 1`** (or
  earlier), not at `duration`. This is a frame-authoring constraint, not an engine
  bug — the priority order is itself contract. (Character A's prejump→jump cancel
  is authored `[3,3]` for exactly this reason; its `duration` stays the authored
  4f.) See the same note in `move-format.md`.

## Advantage — one formula, two surfaced values (AD-008)

A single function computes:

```
advantage = defender_remaining_stun − attacker_remaining_recovery
```

where `attacker_remaining_recovery` is the attacker's **actual frames until
actionable** in the current situation — *including any committed cancel*, not the
raw recovery of the move state. Two distinct values are surfaced from this one
function:

- **Static move frame-advantage** (frame data / UI). Computed at a **pinned
  reference**: contact on the move's **first active frame**, attacker
  **uncancelled**. This is the conventional on-hit / on-block number and a
  property of the move in isolation. It is what a frame-data display reads.
- **Live advantage** (training-mode, per tick). The same formula evaluated on the
  real situation, so it reflects cancels, late (meaty) contact, and current
  remaining recovery. This is the truthful "who is plus *right now*."

Why both: a per-tick-only value gave content/UI no canonical "the" number to read;
a raw-recovery-only value lied the moment a cancel shortened recovery — exactly
the pressure/combo cases legibility most depends on. The static value answers
"what is this move," the live value answers "what is true now."

- Positive ⇒ attacker is actionable first (plus); negative ⇒ defender acts first
  (the punish window).
- **Defender identification (live value, AD-008/JC-012).** The live value reads the
  current situation: the **defender is the player with `stun > 0`**, the attacker
  the other. Neither stunned ⇒ no interaction (value `0`, no plus-player). Both
  stunned (a trade) ⇒ the greater-remaining-stun player is the read-defender (a
  deterministic tiebreak). Roles are **not** read from `last_hit` — the live value
  must track the continuing situation, not the last discrete hit.
- **Neutral restored** = the *rising edge* — the tick at which *both* players
  *become* actionable (both-actionable now AND not both-actionable at the start of
  this tick), not merely any tick both happen to be actionable (AD-025). The
  pre-step condition is read from `step`'s input state (which *is* last tick's
  state), so no extra serialized field is needed. `neutral_restored_this_tick` is
  false on every other tick, including match start (both were already actionable).
  The inspection surface flags this so "when neutral returns" is observable.
- One function, no per-move or per-character variant — the consistency guard.

## Combo & damage accounting

- `combo.hit_count` increments per confirmed hit while the defender stays in
  hitstun-chained states.
- Damage scaling applies from a single scaling definition (per hit-count or per
  scaling state) before damage is subtracted — deterministic and surfaced.
- Combo state resets when the defender returns to actionable/neutral.

## Projectiles (AD-021, AD-030)

- A `spawn` keyframe creates a runtime `Projectile` in `SimState.projectiles` if the
  owner is under the per-owner cap (1 for the slice); otherwise the spawn is suppressed.
  The spawn **fires once**, on the tick `frame_in_state == frame_start` for that keyframe
  range (AD-030 / JC-033) — not once per covered frame. The authored design comes from a
  `ProjectileData` resolved by `data_id` through `ProjectileRegistry`; the runtime entity
  carries a plain `data_id` (re-attaching its `hitbox` on restore), not a serialized
  `HitBox` (AD-030).
- Each tick a projectile integrates its own fixed-point position (phase 3), its
  hitbox is tested against the opponent's hurtbox (phase 4), and on hit/block it
  resolves like any hit (phase 5) — damage, stun, hitstop, pushback — then is
  **consumed**. It also despawns when `lifetime` elapses or it leaves the stage.
  A projectile spawned this tick does **not** integrate or age on its spawn tick — it
  first moves and decrements `lifetime` on the following tick (AD-030 / JC-034, the same
  convention AD-010 fixes for hitstop).
- A projectile's hit is attributed to its `owner` for combo/advantage accounting.
  Projectile-vs-projectile interaction is out of slice scope (AD-021).

## Multi-hit / rehit (AD-016)

- **Sequential** multi-hits are authored as distinct hitboxes in distinct
  `id_group`s across timeline keyframes; each lands once by the single-hit rule.
- **Single-hit across active frames.** "One hit per group per contact" (AD-016) is
  enforced by per-attacker memory of the `id_group`s already connected during the
  *current* move — `players[i].active_hit_ids` (AD-026), cleared on every state
  entry (a new move is a new contact). A hitbox whose `id_group` is present does
  not re-hit, so a multi-frame active window (and every frozen hitstop tick) lands
  one hit, not one per active frame. Cadenced re-hit (`rehit_interval` > 0)
  consults this same memory with an interval (TKT-P0-09).
- **Cadenced** rehits use a hitbox's `rehit_interval`: after it hits a target,
  the same `id_group` may hit that target again only once `rehit_interval` frames
  have elapsed — no hit on the frames between.
- Each connected hit increments combo and applies scaling like any other hit.

## Throws (AD-016)

- A **throwbox** overlapping a throwable hurtbox connects and **bypasses
  blockstun** — throws are not blocked. On connect the defender enters the throw's
  reaction state.
- **Tech window.** If the defender inputs a throw within a defined window after
  the throw connects, the throw is **teched**: both players are pushed back to
  neutral, no damage. Simultaneous ground throw attempts within the window resolve
  as a tech (clash). The window length is authored on the throwbox's dedicated
  `HitBox.tech_window` field (AD-029) — not `blockstun` reuse — and the remaining
  window lives in `players[i].throw_tech_window` (AD-028).
- **Deferred, explicitly (not in the slice):** air throws and formal
  throw-vs-throw priority beyond the clash rule. The `throwbox` / `invuln` /
  air-eligibility fields exist so these are additions, not rewrites (Tenet 3) —
  flag if the slice grows a need for them.

## Inspection mapping (brief's required readouts → fields)

Every brief readout reads through the one read-only inspection surface
(`simulation.md`, AD-011):

| Brief readout | Source |
|---|---|
| Frame data (startup/active/recovery, adv on hit/block) | Derived per `move-format.md`; advantage = the **static** pinned value. |
| Advantage state (who ±, by how much, when neutral returns) | The **live** (cancel-aware) advantage + neutral flag. |
| Hitbox / hurtbox / collision geometry | Resolved boxes from phase 4 (derived). |
| Current state + frame | `state_id`, `frame_in_state`. |
| Hitstop & stun | `hitstop`, `stun` counters. |
| Input display / history | `input_history` (raw `InputFrame`s, per Tenet 2). |
| Damage / combo / scaling | `combo` + applied scaling. |
| Frame control (pause / step) | Sim save + single `step` calls (`simulation.md`). |
| Situation reset / restore | Snapshot restore (`simulation.md`). |
| Record/playback dummy | An `InputSource` writing/replaying a buffer (`input.md`). |

Frame-control and reset are **not new mechanisms** — they are uses of the
deterministic, serializable sim.

## Acceptance criteria (QA-checkable)

1. **P0 done-bar.** A trivial test character defined entirely in move data
   resolves a hit with correct advantage, read back through the inspection
   surface (matches the roadmap P0 "done when").
2. **Phase order.** Interaction outcomes are stable and match the specified phase
   order; reordering phases changes results (i.e., the order is load-bearing and
   pinned).
3. **Advantage = formula, both values.** For a known interaction the **static**
   advantage (pinned: first-active contact, uncancelled) and the **live** advantage
   (cancel-aware) each equal the by-hand value on hit and on block, and one
   function computes both for both characters. A move that special-cancels shows a
   live advantage that differs from its static number, correctly.
4. **Hitstop semantics.** During `hitstop > 0`, the affected character's
   `frame_in_state`/`stun` hold constant for exactly `hitstop` ticks while the
   loop advances; frame-step crosses hitstop one tick per step.
5. **Neutral flag.** The inspection surface flags neutral restored exactly on the
   tick both players become actionable — not before, not after.
6. **Single hit.** A multi-box attack with one `id_group` deals one hit's damage
   and one combo increment.
7. **Readout completeness.** Every brief-required readout above is retrievable
   through the inspection surface for a live interaction.
8. **Cancel timing.** A cancel input during hitstop executes on the first unfrozen
   tick, not during the freeze; a `cancel_tag` granted on tick T is first usable on
   T+1 (AD-017).
9. **Multi-hit.** A sequential multi-hit registers each hit once; a `rehit_interval`
   hitbox hits on its cadence and not on the intervening frames (AD-016).
10. **Throws.** A throw connects through block (bypasses blockstun); a defender
    throw input within the tech window techs it to neutral with no damage;
    simultaneous throws within the window clash to a tech (AD-016).
11. **Input buffer.** A motion recognizes only if completed within the 9-frame
    window; a command buffered up to 6 frames executes on the first actionable
    frame (a `623` held through blockstun fires frame-1) and within a cancel window
    fires at the cancel point (AD-022). Deterministic across input sources.
12. **Invulnerability (AD-031).** A `STRIKE` overlapping a defender frame with
    `invuln_strike` set records **no** hit (the box whiffs) and deals no damage/stun;
    the same frame is still hit by a `THROW` unless `invuln_throw` is also set (and
    vice-versa). A `PROJECTILE` overlapping an `invuln_strike` frame whiffs and the
    projectile is **not** consumed (it may connect on a later vulnerable frame). The
    attacker's `move_contact` resolves to `WHIFF` on an all-invuln whiff, and the
    defender's live invuln state is readable through the inspection surface — the
    whiff is attributable, not silent.
13. **Air-normal height-dependent advantage (AD-033).** An airborne attacker's on-hit
    air normal inflicts hitstun scaled by contact depth via the one `AirHeightScaling`
    definition: a *deeper* contact (attacker closer to the ground, smaller `depth`)
    yields **more** hitstun than a *higher* one for the same authored base, so the live
    advantage (AD-008) is more plus for the deep hit — verified by two contacts of the
    same air normal at different heights producing different, correctly-ordered live
    advantages. A grounded normal's hitstun is unscaled (the gate is attacker
    `AIRBORNE` + on-hit). The applied hitstun never drops below `MIN_HITSTUN`. The
    resolved `contact_depth` and `air_height_hitstun_delta` are readable through the
    inspection surface (`0`/`0` on a non-air-normal hit), so *why* a deep jump-in is
    more plus is observable. Deterministic and integer/fixed-point only.
14. **Directional block (AD-045).** A `HIGH` attack is blocked only standing (hits a crouching
    back-hold); a `LOW` only crouching (hits a standing back-hold); `MID` either. The connecting
    attack's `guard_height` and block validity are readable through `HitEvent`; a wrong-stance
    block deals hitstun/damage, not blockstun. Default `MID` moves are unchanged.
15. **Airborne physics + landing (AD-043).** An airborne character accelerates under `gravity`,
    persists velocity across airborne state transitions, and on `pos_y >= ground_y` clamps and
    lands (velocity zeroed, `air_action_used` reset); an air normal carries the fall rather than
    stopping the arc; a launched character lands into a knockdown reaction. Integer/FP only.
16. **One air action (AD-046).** Exactly one air movement action (air dash **or** double jump) is
    usable per jump; the second is suppressed while `air_action_used` is true; landing resets it.
    A divekick does not consume the air action.
17. **Arc projectile is readable, never unblockable (AD-047).** B's arc projectile follows a
    parabola (`gravity != 0`) and despawns on ground contact; at the "falls-in-front" oki, no frame
    exists where the projectile and a simultaneous B strike require mutually-incompatible defense
    (opposite `guard_height`, or block-vs-untechable-throw) — a single defensive stance/action
    always defends the projectile, leaving the guess to a visible high/low or strike/throw.
