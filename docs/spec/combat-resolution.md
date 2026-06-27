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
   transitions and cancels per the character's `cancels` rules.
3. **Movement integration.** Apply per-state/keyframe motion and physics to
   `position`/`velocity` (floats); resolve pushbox collisions and stage bounds.
4. **Overlap detection.** Resolve each character's active hitboxes/hurtboxes/
   throwboxes from move data (derived, not stored) and test AABB overlaps.
5. **Hit resolution.** For each confirmed hit (respecting `id_group` single-hit),
   apply damage (after scaling), set the defender's `hit_reaction`/`block_reaction`
   state, set stun, set hitstop on both parties, apply pushback/launch, grant
   attacker `cancel_tags`, update combo state.
6. **Advantage / neutral update.** Recompute advantage; flag neutral restoration.
7. **Advance counters.** Decrement `hitstop`, `stun`; advance `tick`. Counters
   under active hitstop do not decrement (see below).

A frozen, ordered pipeline is what makes interaction outcomes deterministic and
gives the debug readout a fixed thing to narrate.

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

## Stun & actionability

- `stun` is a per-player countdown (hitstun or blockstun). `stun == 0` and not in
  a committed recovery state ⇒ **actionable**.
- A defender in stun cannot act until it expires; this is the punish/true-string
  window the debug mode surfaces.

## Advantage — the single canonical computation (AD-008)

Computed in **one** function, each tick, surfaced through the inspection surface:

```
advantage(attacker, defender) =
    defender_remaining_stun − attacker_remaining_recovery
```

- Positive ⇒ attacker is plus (recovers and is actionable first); negative ⇒
  minus (defender acts first — the punish window).
- `attacker_remaining_recovery` = frames until the attacker is actionable
  (remaining recovery of the current move state).
- **Neutral restored** = the tick at which *both* players are actionable; the
  inspection surface flags this so "when neutral returns" is observable.
- This formula is the only place advantage is computed; no per-move or
  per-character variant exists.

## Combo & damage accounting

- `combo.hit_count` increments per confirmed hit while the defender stays in
  hitstun-chained states.
- Damage scaling applies from a single scaling definition (per hit-count or per
  scaling state) before damage is subtracted — deterministic and surfaced.
- Combo state resets when the defender returns to actionable/neutral.

## Inspection mapping (brief's required readouts → fields)

Every brief readout reads through the one read-only inspection surface
(`simulation.md`, AD-011):

| Brief readout | Source |
|---|---|
| Frame data (startup/active/recovery, adv on hit/block) | Derived per `move-format.md`; advantage per the formula above. |
| Advantage state (who ±, by how much, when neutral returns) | The advantage function + neutral flag. |
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
3. **Advantage = formula.** For a known interaction, the surfaced advantage equals
   `defender_remaining_stun − attacker_remaining_recovery` by hand, on hit and on
   block, and one function computes it for both characters.
4. **Hitstop semantics.** During `hitstop > 0`, the affected character's
   `frame_in_state`/`stun` hold constant for exactly `hitstop` ticks while the
   loop advances; frame-step crosses hitstop one tick per step.
5. **Neutral flag.** The inspection surface flags neutral restored exactly on the
   tick both players become actionable — not before, not after.
6. **Single hit.** A multi-box attack with one `id_group` deals one hit's damage
   and one combo increment.
7. **Readout completeness.** Every brief-required readout above is retrievable
   through the inspection surface for a live interaction.
