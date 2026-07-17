# Spec — Inspection Surface (the seam read API)

> Owned by the **Architect**. The concrete read-only API over `SimState`,
> introduced abstractly in `simulation.md` (AD-011). This is the **systems/content
> seam interface**: the debug training mode, the QA determinism/golden harness,
> and any player-facing UI all read sim truth *through this one surface* and never
> reach into sim internals. The Developer implements it and *raises* problems; it
> does not redefine it.

## Principles

- **Read-only.** The surface exposes state and cheap derived reads. It offers no
  mutator and no path to advance the sim. Driving the game is the control layer's
  job (`training-mode.md`), never this surface's.
- **Single source of truth.** Values come from the sim's own state and its own
  functions — e.g. advantage is read from the *one* advantage computation
  (`combat-resolution.md`, AD-008), never re-derived here. Debug mode and QA can't
  disagree because they read the same numbers.
- **Fixed-point truth only; pixel projection is render-only (AD-019).** The
  snapshot-able surface carries **only** fixed-point integer truth — no floats —
  so QA can golden-file it without cross-platform float drift defeating the harness
  (Tenet 1). Pixel coordinates are a deterministic render-only projection
  (fixed→px) computed for drawing and **excluded from every golden/determinism
  snapshot**. Float never enters the snapshot set.
- **Plain, snapshot-able returns.** Every truth view returned is plain serializable
  data (no live node refs), so QA can golden-file it and the debug UI can render it.
- **Character-agnostic.** No character-specific code lives here; the surface reads
  whatever character/state exists (the P0 test character, character A, or B).

## The API

```
InspectionView (read-only over the current SimState):
    tick() -> int
    player(i: int) -> PlayerView            # i in {0,1}
    projectiles() -> Array[ProjectileView]  # live projectiles (AD-021)
    frame_data(character_id, state_id) -> FrameData   # static, pinned
    advantage() -> AdvantageView            # live (cancel-aware)
    last_hit() -> HitEvent | null           # most recent resolved hit
```

### `PlayerView`
| Field | Meaning |
|---|---|
| `character_id`, `state_id`, `state_category` | Identity + current state-machine state and its category. |
| `frame_in_state`, `state_duration` | Frame within the state and its length. |
| `actionable` | True when `stun == 0` and not in committed recovery. |
| `position`, `velocity` | Fixed-point integers (sim truth; snapshot-able). |
| `facing` | Facing direction. |
| `health` | Current health. |
| `hitstop_remaining` | Frozen frames left (AD-010). |
| `stun_remaining`, `stun_kind` | Stun countdown and `hit` / `block` / `none`. |
| `combo` | `{ hit_count, scaling_pct, damage_total }`. |
| `move_contact` | This player's current-move outcome as attacker (AD-028): `none` / `hit` / `block` / `whiff`. Backs "did my move connect / whiff" and gates which cancels are live. Plain int enum (0/1/2/3, mirrors `PlayerState.CONTACT_*`). |
| `cancel_tags` | The cancel tags this player currently holds as attacker (AD-017/028) — i.e. an *open cancel window*: the set of tags a buffered cancel can consume this tick. Snapshot-able `PackedInt32Array` (empty ⇒ no cancel window open). |
| `throw_tech_window` | Frames remaining in which this player (as thrown defender) may still tech the throw (AD-016/028). `0` ⇒ not in a tech window; `> 0` ⇒ the live count of tech frames left. |
| `thrown_by` | The attacker index that threw this player, or `-1` if not currently thrown (AD-028). |
| `invuln` | This player's **current-frame** invulnerability, as read from its covering keyframe (AD-031): `{ strike, throw }` bools. Backs "this frame is invulnerable" and — with `move_contact == whiff` on the opponent — "the hit whiffed *because of* invuln" (charter legibility). A **derived** projection of the defender's authored keyframe (like box geometry), not a serialized `SimState` field; snapshot-able (two plain bools, no float). |
| `air_action_used` | Bool (AD-046) — whether this player has spent its one air action (air dash / double jump) this jump. Backs the air-economy readout ("your air action is spent"). Reset on landing. |
| `reaction_kind` | The engine-level `ReactionKind` (AD-049) the player's current state *is*, or `-1` when the state is not a reaction (idle / walk / a normal). A **derived** projection (like `invuln` / box geometry) — **not** a serialized `SimState` field: resolved in `PlayerView._init` by reverse-reading the character's **own** `reaction_map` for the entry whose `state_id` matches the current state (the same authored map AD-049's forward `reaction_state(kind)` reads the other direction). Backs the training mode leading a reaction row with its *specific* identity — knockdown / launch / air reset / hitstun / blockstun / crouch blockstun — where `state_category` alone collapses all four hitstun reactions (`STATE_KNOCKDOWN` / `_HITSTUN_LAUNCH` / `_AIR_RESET` / ordinary hitstun) into one word. `state_category` stays shown *alongside* it, never replaced. Snapshot-shaped (plain int). **Read-only readout truth:** nothing in the sim reads it back, so a `reaction_map` that aliased two kinds onto one `state_id` (first match wins) is a display-only ambiguity, not a resolution risk — real roster characters map every kind to a dedicated state (JC-104). |
| `input_current` | The raw `InputFrame` this player's source emitted this tick (Tenet 2). |
| `input_history` | Last N raw `InputFrame`s (ring buffer view). |
| `boxes` | The resolved `BoxView`s active this tick (below). |

### `BoxView` (resolved geometry, world space)
| Field | Meaning |
|---|---|
| `kind` | `HURT` \| `HIT` \| `THROW` \| `PUSH`. |
| `rect` | World-space AABB in **fixed-point** (sim truth; snapshot-able). The UI converts to px for drawing via the render projection below. |
| `hit` | For `HIT`/`THROW`: `{ damage, hitstun, blockstun, hitstop, id_group, rehit_interval }`. |

### `ProjectileView` (live projectile — AD-021)
| Field | Meaning |
|---|---|
| `owner` | Player index that spawned it. |
| `position` | Fixed-point (sim truth; snapshot-able). |
| `box` | A `BoxView` (`HIT`) for its hitbox — drawn by the geometry overlay. |
| `lifetime_remaining` | Frames left before it despawns. |

### `FrameData` (static, the pinned move property — AD-008)
| Field | Meaning |
|---|---|
| `startup`, `active`, `recovery`, `total` | Derived per `move-format.md`. |
| `on_hit_adv`, `on_block_adv` | Static advantage: first-active contact, uncancelled. |

### `AdvantageView` (live — AD-008)
| Field | Meaning |
|---|---|
| `value` | `defender_remaining_stun − attacker_remaining_recovery`, cancel-aware. |
| `plus_player` | `0` \| `1` \| `none`. |
| `frames_to_neutral` | Frames until both actionable. |
| `neutral_restored` | True on the tick both players become actionable. |

### `HitEvent`
The seam-side projection of `SimState.last_hit` (a plain `HitRecord`, AD-024). The
sim owns the record; this view is read-only over it.

| Field | Meaning |
|---|---|
| `attacker`, `defender` | Player indices. |
| `damage_dealt`, `was_block` | Damage applied; whether blocked. |
| `scaling_applied`, `combo_count_after` | Scaling at the time; combo count after. |
| `tick` | When it resolved. |
| `contact_depth` | Fixed-point (sim truth; snapshot-able). The attacker's depth above ground at contact (`ground_y − attacker.pos_y`, AD-033); `0` on a non-air-normal hit. Backs "this jump-in connected deep." |
| `air_height_hitstun_delta` | The signed hitstun-frame delta the air-normal height scaling contributed at this hit (AD-033); `0` on a non-air-normal hit. Backs "…deep → +N hitstun → this much more plus" — the *why* behind a deep jump-in's advantage. Plain int (whole frames). |
| `guard_height` | The connecting attack's block-height requirement (AD-045): `HIGH` / `LOW` / `MID`. Backs "this was an overhead / a low." Plain int enum. |
| `block_valid` | Whether the defender's block was stance-valid for `guard_height` (AD-045). When the defender held back but in the wrong stance (`block_valid == false`, `was_block == false`), the training mode shows *why* the hit landed — the overhead beat a crouch, the low beat a stand-block. Backs the "no knowledge checks" readout of the high/low mixup. |

### `MatchView` (read-only over `MatchState` — AD-048)
The seam projection of the match layer. Read-only, plain, snapshot-able (all integer truth).

| Field | Meaning |
|---|---|
| `health` | Per-player current health (`[h0, h1]`; also on `PlayerView.health`). |
| `round_wins` | Per-player round wins (`[w0, w1]`) — the round pips. |
| `round_timer` | Frames remaining in the round (the clock; frame-counted, not wall-clock — AD-048/Tenet 1). |
| `match_phase` | `ROUND_START` / `ACTIVE` / `ROUND_END` / `MATCH_END`, plus a `sudden_death` flag. |
| `last_round_end_reason` | `KO` / `TIMEOUT` / `DOUBLE_KO` — **serialized truth**, so *why* a round ended is legible on its face (charter), not a render inference. |

## Render projection (render-only, never snapshotted — AD-019)

For drawing, the surface offers a deterministic fixed→px conversion (a helper such
as `px(fixed)` / `px_rect(rect)`), or the UI performs it itself. Either way the
resulting float pixel values are a **render-only projection**: they are not fields
of the snapshot-able truth views above, and the golden/determinism harness never
snapshots them. The single source of truth that QA snapshots stays fixed-point.

## Acceptance criteria (QA-checkable)

1. **Traceability.** Every readout the brief requires — frame data, advantage,
   box geometry, state+frame, hitstop/stun, input history, damage/combo, and the
   batch-2 legibility state (move contact/whiff, open cancel window, throw
   tech-window + who threw whom) — maps to a field/query above. Specifically, a
   thrown defender's remaining tech frames (`throw_tech_window` > 0), the attacker
   who threw them (`thrown_by`), an open cancel window (`cancel_tags` non-empty),
   and a move's connect/whiff outcome (`move_contact`) are each readable through
   `PlayerView` — no legibility-relevant serialized `SimState` field is truth the
   seam cannot surface (F-013). A defender frame's **invulnerability** (`invuln`,
   AD-031) is likewise readable through `PlayerView`, so a whiff-by-invuln is
   attributable in the training mode (charter: "find out what happened and why").
   An air normal's **contact depth and height-scaled hitstun delta** (`HitEvent.
   contact_depth`, `HitEvent.air_height_hitstun_delta`, AD-033) are readable through
   `last_hit()`, so *why* a deep jump-in is more plus is attributable (both `0` on a
   non-air-normal hit). A reaction state's **specific identity** (`reaction_kind`,
   AD-049) is readable through `PlayerView`, so the training mode names *which*
   reaction a defender is in (knockdown vs. launch vs. air reset vs. ordinary
   hitstun) rather than collapsing all four onto their shared `state_category`.
2. **Read-only.** No method on the surface mutates `SimState`; after any sequence
   of inspection calls, the state hash is unchanged. No mutator is exposed.
3. **Single source.** `advantage()` returns the value from the sim's one advantage
   function (not a re-implementation); `frame_data()` returns the same derivation
   the sim uses. A test that compares surface output to the sim's internal values
   finds them equal.
4. **Snapshot-stable, fixed-point only.** The snapshot-able truth views are plain
   serializable data containing **no float fields**; a golden snapshot for a fixed
   state round-trips identically (AD-019).
5. **Character-agnostic.** The surface returns correct views for the P0 test
   character with no character-specific branches; adding character A/B requires no
   change here.
7. **Match legibility (AD-048).** `MatchView` exposes health, round wins, timer,
   phase, and the round-end reason; a KO, a timeout, and a double-KO each yield the
   correct `last_round_end_reason` as serialized truth (not a render inference), so
   *why* a round/match ended is readable. All fields are integer/enum, snapshot-able.
8. **High/low attribution (AD-045).** `HitEvent.guard_height` and `block_valid` let the
   training mode attribute a mixup hit: an overhead that beat a crouch, a low that beat a
   stand-block, each read as *why the hit landed* rather than an inexplicable non-block.
6. **Render projection excluded.** Pixel (`px`) projections are render-only and do
   not appear in any golden/determinism snapshot; a golden taken with and without
   the UI active is identical.
