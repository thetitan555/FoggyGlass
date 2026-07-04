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
| `physics` | Walk/dash/jump/gravity constants, as baked fixed-point integers (AD-014). |

### `MoveState`
| Field | Meaning |
|---|---|
| `id` | State id (stored in `SimState.players[i].state_id`). |
| `category` | One of the engine-level categories above. |
| `duration` | Total frames before the state ends / returns to actionable. |
| `timeline` | Ordered list of `Keyframe` ranges. |
| `cancels` | A list of `CancelRule` (see below) — not one opaque field (AD-015). |
| `loop` | Whether `duration` loops (idle/walk) or plays once. |

### `Keyframe` (a frame range within a `MoveState`)
| Field | Meaning |
|---|---|
| `frame_start`, `frame_end` | Inclusive range within the state (1-indexed by `frame_in_state`). |
| `hurtboxes` | List of `Box` active this range. |
| `hitboxes` | List of `HitBox` active this range. |
| `throwboxes` | List of `Box` for throws (optional). |
| `motion` | Per-range movement deltas / velocity sets (optional). |
| `invuln` | Optional invulnerability flags for this range: `invuln_strike` and `invuln_throw` (AD-031). A frame with `invuln_strike` set cannot be contacted by a `hit_kind` of `STRIKE` or `PROJECTILE`; a frame with `invuln_throw` set cannot be contacted by a `THROW`. Enforced in phase 4 (the contact is not recorded — the incoming box **whiffs**), and the whiff is *observable* through the inspection surface so the training mode can show a frame was invulnerable and that a hit whiffed *because of* invuln (see `combat-resolution.md` → phase 4, and `inspection-surface.md`). Invuln gates on the **defender's covering keyframe** for the current `frame_in_state`; both flags may be set (full invuln). Unset ⇒ vulnerable. |
| `spawn` | Optional (AD-021, AD-030). Spawns a projectile this range: `{ projectile, offset, velocity }` — `projectile` names a `ProjectileData` by `data_id`, `offset`/`velocity` are the fixed-point spawn position/velocity supplied to the runtime entity. **Fires once**, on the tick `frame_in_state == frame_start` for this range (AD-030 / JC-033) — *not* once per covered frame; a spawn authored across several frames spawns one projectile. Subject to the owner's live-projectile cap; if the cap is full the spawn is suppressed. |

### `ProjectileData` (authored projectile shell — AD-021, AD-030)
The authored `.tres` shell for a projectile's own **fixed design**. Named
`ProjectileData` (not `Projectile`) because the runtime entity in
`SimState.projectiles[]` owns the `Projectile` identifier (AD-030 / JC-032). Authored
content, resolved through `ProjectileRegistry` — *not* serialized state (AD-024).

| Field | Meaning |
|---|---|
| `id` | Registry key (`data_id`); the runtime entity carries this to re-reach its authored data. |
| `hitbox` | A `HitBox` (geometry + hit data) carried by the projectile. |
| `lifetime` | Frames it persists before despawning; consumed on hit/block. Measured from the tick *after* spawn (AD-030 / JC-034 — see below). |
| `max_per_owner` | Live cap (1 for the slice fireball). |

The runtime entity additionally carries, set at spawn time (not authored on the shell):
`owner` (casting player index, from `SimState` — for cap, facing, combo attribution),
and initial `position`/`velocity` (from the `spawn` keyframe's `offset`/`velocity`),
which then integrate each tick independently of the owner.

**Projectile resolution & serialization (AD-030).** The runtime `Projectile` serializes
a plain int `data_id`, **not** a live `HitBox` — authored geometry stays out of the
snapshot (AD-024) — and re-attaches its `hitbox` via `ProjectileRegistry.data(data_id).hitbox`
on `from_dict`, exactly as `character_id` re-reaches move data through `MoveRegistry`.
`ProjectileRegistry` is installed once per run with the same install/clear/generation-token
discipline as `MoveRegistry` (AD-024/F-009).

**Spawn-tick timing (AD-030 / JC-034).** A projectile spawned on tick T appears at its
authored spawn position with its full `lifetime`, and first **integrates (moves) and ages
(decrements `lifetime`) on tick T+1** — the same convention AD-010 fixes for hitstop. So a
`spawn` keyframe on frame F means the projectile exists starting frame F and begins
travelling frame F+1; author a `lifetime` and reach with that one-tick offset in mind.

### `CancelRule` (one entry in `MoveState.cancels` — AD-015)
| Field | Meaning |
|---|---|
| `target` | Destination `state_id`, or a tag/group naming a set of states. |
| `condition` | `on_hit` \| `on_block` \| `on_contact` \| `on_whiff` \| `always`. |
| `window` | Frame range within the move the cancel is allowed; default first-active→end. |
| `input` | Required command (button/motion) to take the cancel. |
| `requires_tag` | Optional cancel tag that must be present (granted by a connecting `HitBox.cancel_tags`). |

Move classes are expressed, not special-cased: **gatling/chain** = `on_contact`
to another normal within a `window`; **special-cancel** = `requires_tag` granted
by the hit; **whiff-cancel** = `on_whiff`. Rehit/multi-hit is *not* a cancel —
see `HitBox.rehit_interval` and AD-016.

### `Box` (geometry, character-local)
| Field | Meaning |
|---|---|
| `x`, `y`, `w`, `h` | AABB in character-local space, **fixed-point units** (AD-014); flipped by `facing`, offset by `position`. |

`pushbox` (collision box) is defined per `MoveState`/category rather than
per-keyframe unless a move overrides it.

### `HitBox` (a `Box` plus hit data)
| Field | Meaning |
|---|---|
| `box` | The AABB. |
| `hit_kind` | The contact category (AD-031): `STRIKE` \| `THROW` \| `PROJECTILE`. Determines which of a defender's `invuln_*` flags gates it (a `STRIKE` is whiffed by `invuln_strike`; a `THROW` by `invuln_throw`; a `PROJECTILE` by `invuln_strike` — a projectile is a strike delivered at range). The **canonical** category field; the legacy `throwbox` flag is exactly `hit_kind == THROW` (see below). Default `STRIKE`. |
| `damage` | Base damage. |
| `hitstun`, `blockstun` | Frames of stun inflicted on hit / on block. |
| `hitstop` | Freeze frames applied to both parties on contact (AD-010). |
| `pushback_hit`, `pushback_block` | Positional pushback. |
| `launch` / `juggle` | Vertical/launch properties + juggle limit interaction (optional). |
| `hit_reaction`, `block_reaction` | Which defender `state_id` (category `HITSTUN`/`BLOCKSTUN`) the hit forces. |
| `cancel_tags` | Tags this hitbox grants for the attacker's cancels (e.g. enables special-cancel). |
| `id_group` | Groups hitboxes of one attack so a single attack hits once (no multi-count from overlapping boxes). |
| `rehit_interval` | Optional (AD-016). If set, this `id_group` may hit the same target again after this many frames — the cadenced multi-hit form. Unset ⇒ one hit per contact. |
| `throwbox` flag | A `HitBox`/`Box` may be marked a throw (AD-016): on connect it bypasses blockstun and enters the throw resolution path (see `combat-resolution.md`). **Equivalent to `hit_kind == THROW`** (AD-031) — the same fact under two names for continuity; the throw resolution path keys on it either way. Authoring may set either; they must agree. |
| `tech_window` | Throw-only (AD-029). Frames the thrown defender may tech after this throwbox connects (AD-016 tech window). Meaningful only when the throwbox flag is set — a throw is never blocked, so it carries no `blockstun`; the tech window is its own authored feel value, **not** `blockstun` reuse. `0` on a non-throw box. |

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
   one hit, not several — including across a multi-frame active window, enforced by
   per-attacker `active_hit_ids` memory cleared on state entry (AD-026). AABB
   overlap is strict (touching edges do not overlap, AD-027).
6. **One pattern.** Every character's states declare a valid engine-level
   `category`; no character introduces a state machine outside this pattern.
7. **Typed cancels.** A `MoveState`'s cancels are a list of `CancelRule`s; a
   gatling, a special-cancel (tag-gated), and a whiff-cancel are each authorable
   purely as data with no engine change, and resolve per their `condition`/`window`.
8. **Multi-hit forms.** A sequential multi-hit (distinct `id_group`s across
   keyframes) lands each hit once; a `rehit_interval` hitbox re-hits the same
   target on its cadence and not between intervals.
9. **Fixed-point data.** All geometry/physics values consumed by the runtime are
   integers (baked fixed-point, AD-014); no float reaches `step`.
