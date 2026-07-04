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
   but no transition executes until the first unfrozen tick (AD-017).
3. **Movement integration.** Apply per-state/keyframe motion and physics to
   `position`/`velocity` (fixed-point integers, AD-014); resolve pushbox
   collisions and stage bounds. Integrate live projectiles' positions too (AD-021),
   and process any `spawn` actions firing this tick (subject to the per-owner cap).
4. **Overlap detection.** Resolve each character's active hitboxes/hurtboxes/
   throwboxes from move data (derived, not stored) and test AABB overlaps. Include
   live projectile hitboxes vs. the opponent's hurtbox (AD-021). Overlap is
   **strict**: boxes that merely *touch* (share an edge, `a.x + a.w == b.x`) do
   **not** overlap — a box exactly adjacent to a hurtbox does not register (AD-027).
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
