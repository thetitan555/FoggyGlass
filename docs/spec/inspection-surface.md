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
- **Plain, snapshot-able returns.** Every view returned is plain serializable data
  (no live node refs), so QA can golden-file it and the debug UI can render it.
- **Character-agnostic.** No character-specific code lives here; the surface reads
  whatever character/state exists (the P0 test character, character A, or B).

## The API

```
InspectionView (read-only over the current SimState):
    tick() -> int
    player(i: int) -> PlayerView            # i in {0,1}
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
| `position`, `velocity` | Fixed-point integers (sim truth). |
| `position_px` | View-only float conversion (fixed→px) for rendering. |
| `facing` | Facing direction. |
| `health` | Current health. |
| `hitstop_remaining` | Frozen frames left (AD-010). |
| `stun_remaining`, `stun_kind` | Stun countdown and `hit` / `block` / `none`. |
| `combo` | `{ hit_count, scaling_pct, damage_total }`. |
| `input_current` | The raw `InputFrame` this player's source emitted this tick (Tenet 2). |
| `input_history` | Last N raw `InputFrame`s (ring buffer view). |
| `boxes` | The resolved `BoxView`s active this tick (below). |

### `BoxView` (resolved geometry, world space)
| Field | Meaning |
|---|---|
| `kind` | `HURT` \| `HIT` \| `THROW` \| `PUSH`. |
| `rect_px` | World-space AABB in pixels (fixed→px), ready to draw. |
| `hit` | For `HIT`/`THROW`: `{ damage, hitstun, blockstun, hitstop, id_group, rehit_interval }`. |

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
| Field | Meaning |
|---|---|
| `attacker`, `defender` | Player indices. |
| `damage_dealt`, `was_block` | Damage applied; whether blocked. |
| `scaling_applied`, `combo_count_after` | Scaling at the time; combo count after. |
| `tick` | When it resolved. |

## Acceptance criteria (QA-checkable)

1. **Traceability.** Every readout the brief requires — frame data, advantage,
   box geometry, state+frame, hitstop/stun, input history, damage/combo — maps to
   a field/query above.
2. **Read-only.** No method on the surface mutates `SimState`; after any sequence
   of inspection calls, the state hash is unchanged. No mutator is exposed.
3. **Single source.** `advantage()` returns the value from the sim's one advantage
   function (not a re-implementation); `frame_data()` returns the same derivation
   the sim uses. A test that compares surface output to the sim's internal values
   finds them equal.
4. **Snapshot-stable.** All returned views are plain serializable data; a golden
   snapshot of the surface for a fixed state round-trips identically.
5. **Character-agnostic.** The surface returns correct views for the P0 test
   character with no character-specific branches; adding character A/B requires no
   change here.
