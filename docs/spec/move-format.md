# Spec — Move / Frame-Data Format & State-Machine Pattern (P0)

> Owned by the **Architect** (settled: the Architect owns this format). The
> data-driven, serializable contract move data is authored against, and the one
> state-machine pattern every character uses. The Developer implements against
> this and *raises* problems; it does not redefine it. See AD-006, AD-007, AD-008.

## Authoring format

Move data is authored as Godot custom **`Resource` (`.tres`)** files conforming
to the schema below (AD-006). Properties:

- **Data-driven:** authoring a move/character touches data, never engine code.
- **Serializable + diffable:** `.tres` is text — QA can golden-file resolved
  frame data and box geometry for regression (seeded in P2).
- **Keyframed, not per-frame:** timelines are frame *ranges*, compact to author,
  resolving to exact per-frame truth.

## The character state machine (one pattern for all — AD-007)

A character is a state machine. Each state references move data. Two layers:

1. **Engine-level state categories** — a small fixed set the engine understands
   and uses to govern physics and legal transitions. Slice set:
   `GROUNDED`, `AIRBORNE`, `HITSTUN`, `BLOCKSTUN`, `HITSTOP` (frozen overlay).
   *(Extendable later; this is the slice's set.)*
2. **Data-defined states** — concrete moves/actions (idle, walk, a normal, a
   special, a throw) each declaring which category they belong to. Per-move
   specifics live entirely in data.

Every character uses this one pattern — no bespoke per-character machines. This
is the consistency guard that lets character B be *content, not engineering*.

## Schema

### `Character`
| Field | Meaning |
|---|---|
| `id` | Stable identifier. |
| `states` | The set of `MoveState`s this character has. |
| `button_map` | Maps generic `BUTTON_n` (+ direction/motion) → `state_id`. The only place buttons gain meaning. |
| `physics` | Walk/dash/jump/gravity constants (floats). |

### `MoveState`
| Field | Meaning |
|---|---|
| `id` | State id (stored in `SimState.players[i].state_id`). |
| `category` | One of the engine-level categories above. |
| `duration` | Total frames before the state ends / returns to actionable. |
| `timeline` | Ordered list of `Keyframe` ranges. |
| `cancels` | Cancel rules: which `state_id`s this can transition into, and the window/condition (e.g. on-hit, on-block, frame range, special-cancel tag). |
| `loop` | Whether `duration` loops (idle/walk) or plays once. |

### `Keyframe` (a frame range within a `MoveState`)
| Field | Meaning |
|---|---|
| `frame_start`, `frame_end` | Inclusive range within the state (1-indexed by `frame_in_state`). |
| `hurtboxes` | List of `Box` active this range. |
| `hitboxes` | List of `HitBox` active this range. |
| `throwboxes` | List of `Box` for throws (optional). |
| `motion` | Per-range movement deltas / velocity sets (optional). |
| `invuln` | Optional invulnerability flags (e.g. throw-invuln, strike-invuln) for this range. |

### `Box` (geometry, character-local)
| Field | Meaning |
|---|---|
| `x`, `y`, `w`, `h` | AABB in character-local space; flipped by `facing`, offset by `position`. |

`pushbox` (collision box) is defined per `MoveState`/category rather than
per-keyframe unless a move overrides it.

### `HitBox` (a `Box` plus hit data)
| Field | Meaning |
|---|---|
| `box` | The AABB. |
| `damage` | Base damage. |
| `hitstun`, `blockstun` | Frames of stun inflicted on hit / on block. |
| `hitstop` | Freeze frames applied to both parties on contact (AD-010). |
| `pushback_hit`, `pushback_block` | Positional pushback. |
| `launch` / `juggle` | Vertical/launch properties + juggle limit interaction (optional). |
| `hit_reaction`, `block_reaction` | Which defender `state_id` (category `HITSTUN`/`BLOCKSTUN`) the hit forces. |
| `cancel_tags` | Tags this hitbox grants for the attacker's cancels (e.g. enables special-cancel). |
| `id_group` | Groups hitboxes of one attack so a single attack hits once (no multi-count from overlapping boxes). |

## Derived frame data (one canonical definition — AD-008)

Computed from a `MoveState`'s timeline, exposed via the inspection surface:

- **Startup** = frames before the first frame any `HitBox` is active.
- **Active** = frames during which any `HitBox` is active (first to last active).
- **Recovery** = frames from end of active to the first actionable frame.
- **On-hit / on-block advantage** = the single formula in `combat-resolution.md`
  (`defender_remaining_stun − attacker_remaining_recovery`). Defined there, in
  one place; this format only supplies the inputs (stun values, recovery).

These definitions are canonical: every character's frame data is derived this one
way, so two characters can't disagree about what "startup" or "advantage" means.

## Acceptance criteria (QA-checkable)

1. **Data-only authoring.** A new move added purely as `.tres` data (no engine
   code change) resolves to the correct active box set on each frame of its range.
2. **Derivation correctness.** Startup/active/recovery computed from a known test
   move's timeline match hand-specified values.
3. **Golden-able.** Re-exporting an unchanged move yields byte-identical text
   (stable serialization suitable for golden-file regression).
4. **One path, two characters.** Two characters differing only in data produce
   different but correctly-derived frame data through the same code path (the
   format is not "character-A-shaped").
5. **Single-hit integrity.** Overlapping hitboxes sharing an `id_group` register
   one hit, not several.
6. **One pattern.** Every character's states declare a valid engine-level
   `category`; no character introduces a state machine outside this pattern.
