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

**Held-input looping-state exit (AD-038).** A `loop` state is the neutral held-input family
(idle, walk, crouch). When a character is **actionable** and in a `loop` state, phase 2
re-derives the desired state from buffered input **every tick** — the first satisfied
`button_map` command, or `idle_state_id` if none — so a held-direction stance enters on hold
(the AD-032 pure-direction command) and **returns to idle on release** with no per-state exit
wiring. A committed once-through move is unaffected (its end is the once-through → idle
transition). This is the exit half of the state model; AD-032 gave only the entry.

**Airborne-action model (AD-039).** A jump's horizontal direction is chosen at takeoff via
**per-direction prejump lead-in** states (`PREJUMP_N/F/B`, each an `input = 0` ALWAYS cancel
into its `JUMP_N/F/B` arc; `button_map` routes composite `UP|FORWARD` / `UP|BACK` / `UP`).
Air normals are reached by **cancelling the jump state** into `j.*` (a `CancelRule` per attack
button). Both are expressed in data with existing mechanisms — no format change.

## The character-namespace rule (AD-049 — read this before authoring anything with an id in it)

> **A `state_id` is meaningful only within its own character.** No field authored on
> character X may contain a `state_id` that is resolved against character Y. Any state a
> character enters that is *named by something outside that character* — the opponent's
> move data, or the engine — is resolved through that character's **own** declared map,
> never by a raw id crossing the boundary.

State ids are **character-local** and always were (A's run 100s–160s, B's 300s+, by each
character's own convention). The format never required two characters to share an id
namespace, so nothing may depend on them doing so. This rule exists because three separate
defects have now come from an identifier silently crossing a boundary the format never
declared (AD-049 lists them); it is stated here as an invariant so it is checkable rather
than remembered.

**Which namespace is which:**

| Identifier | Namespace | Resolved against |
|---|---|---|
| `MoveState.id` (`state_id`) | **Character-local.** | Its own `Character.states` — *never* another character's. |
| `HitBox.id_group` | **Character-local**, attacker-only. | The attacker's own `active_hit_ids` memory. Never crosses. |
| `CancelGroup.id`, `CancelRule.requires_tag` | **Character-local**, attacker-only. | The attacker's own `cancel_groups` / granted tags. |
| `ReactionKind` | **Engine-level** (shared vocabulary, not an id). | The **defender's** own `reaction_map`. |
| `MoveState.category`, `guard_height` | **Engine-level** (shared vocabulary). | Engine semantics. |
| `ProjectileData.id` (`data_id`) | **GLOBAL** across the whole roster (AD-049). | `ProjectileRegistry`, with no character context. **Must be unique roster-wide**; `install` rejects duplicates. Allocate a fresh range per character (A: 201–203, B: 220–222). |
| `Character.id` | **Global.** | `MoveRegistry`. |

The pattern: what crosses a character boundary is engine-level **semantics**, never a
character-local **identifier**.

## Reactions (AD-049)

**Reactions are defender-side content.** An attacker's `HitBox` names *what happens*
semantically (`REACTION_LAUNCH`); the defender's `reaction_map` decides *what state that is
on me*. This is why the id never crosses: a defender must look like itself while being hit.

**`ReactionKind`** — the engine-level set (closed; adding one is an Architect call and
engine work, not authoring):

| Kind | Meaning |
|---|---|
| `REACTION_HITSTUN` | Standard grounded hitstun. |
| `REACTION_LAUNCH` | Airborne launch hitstun; juggle-continuable, lands into `REACTION_KNOCKDOWN` (AD-043). |
| `REACTION_AIR_RESET` | Airborne knock-away, **no follow-up** (character A's `2H`). |
| `REACTION_KNOCKDOWN` | Grounded hard knockdown / the shared wakeup (AD-043). |
| `REACTION_BLOCKSTUN` | Standing blockstun. |
| `REACTION_CROUCH_BLOCKSTUN` | Crouching blockstun. |

**Every character must author a state for every kind.** Not "every kind it inflicts" —
**every kind it can receive**, which is all of them. A character with no launcher of its own
still gets launched by one that has one. This is the authoring obligation that replaces the
old (broken) assumption that the attacker could supply the state. QA checks it statically
over the roster (criterion 15); a character missing a kind is a **content error**, caught
before it is ever played.

**Resolution floor (a guardrail, not a license).** If a kind is somehow unmapped, resolution
falls back `kind → REACTION_HITSTUN → idle_state_id`. This exists so the worst case is a
*wrong-looking reaction* rather than the AD-049 failure mode (a defender entered into a
nonexistent state: no boxes, unhittable, permanently un-actionable, since phase 2's
`move != null` guards gate even stun-expiry). Content that fires the floor fails the static
check first — do not author against it.

**Categories still bind.** A state mapped to a `REACTION_*` kind must declare a sane
engine-level `category`: the hitstun family (`HITSTUN`, `LAUNCH`, `AIR_RESET`, `KNOCKDOWN`)
must be `HITSTUN`-category; the blockstun family must be `BLOCKSTUN`-category. The kind names
the *situation*; `category` still governs physics and legal transitions.

## Schema

### `Character`
| Field | Meaning |
|---|---|
| `id` | Stable identifier. |
| `states` | The set of `MoveState`s this character has. |
| `button_map` | Maps generic `BUTTON_n` (+ direction/motion) → `state_id`. The only place buttons gain meaning. |
| `cancel_groups` | Optional (AD-044). Named sets of `state_id`s a `CancelRule.target` may reference (character B's gatling strength/stance ladder). Authored data; empty for characters with no group targets. |
| `physics` | Walk/dash/jump/**gravity** constants, as baked fixed-point integers (AD-014). `gravity` is the per-tick `velocity.y` acceleration applied to an **airborne** character (AD-043); jumps set a takeoff velocity and land by the runtime clamp — no hand-balanced net-zero arc (supersedes the old invariant). Also carries the air-action constants **`air_dash_speed`** and **`double_jump_velocity`** (AD-046, ratified from JC-075); both default `0` (= no such action, same 0-disables convention as `gravity`/`jump_velocity`). |
| `idle_state_id` | The character's neutral/idle `state_id` — the fallback a released held-input stance returns to (AD-038) and the target the ordinary jump-landing clamp enters (AD-043). Idle is **not** a reaction; this field stays as-is under AD-049. |
| `reaction_map` | **Required (AD-049).** `ReactionKind → this character's own `state_id``. Every reaction kind must be mapped (see "Reactions"). This is how a state named by *someone else* (the opponent's `HitBox`, or the engine) is reached without a raw id crossing a character boundary. |
| ~~`knockdown_state_id`~~ | **Retired (AD-049)** — folded into `reaction_map[REACTION_KNOCKDOWN]`, which is the same concept under a second name. `_land`'s launched-into-ground transition (AD-043) now resolves `reaction_state(REACTION_KNOCKDOWN)`. Semantics otherwise unchanged: non-actionable, HITSTUN-category, fixed wakeup `duration` counted **from entry (landing)** so oki timing is independent of air-time; may author a downed hurtbox distinct from the airborne launch hurtbox; grounded hard-knockdown hits (a low slide, a throw) converge on the **same** state via `hit_reaction = REACTION_KNOCKDOWN`. |

### `MoveState`
| Field | Meaning |
|---|---|
| `id` | State id (stored in `SimState.players[i].state_id`). |
| `category` | One of the engine-level categories above. |
| `duration` | Total frames before the state ends / returns to actionable. |
| `timeline` | Ordered list of `Keyframe` ranges. |
| `cancels` | A list of `CancelRule` (see below) — not one opaque field (AD-015). |
| `loop` | Whether `duration` loops (idle/walk) or plays once. |
| `is_crouch` | Optional (AD-045, ratified from JC-078); default `false`. Marks this state as a **crouching stance** — the signal directional block enforcement reads to derive defender stance (a `LOW` is blocked only while `is_crouch`, a `HIGH` only while standing). Authored content, resolved off the defender's current `state_id` through `MoveRegistry` (no `SimState` change). Exists because engine `category` does not distinguish stand from crouch (both are `GROUNDED`). Character A authors `is_crouch = true` on its crouch + crouch-blockstun states; every other state defaults `false`. |
| `landing_state_id` | Optional (AD-050); default `0` (unset). A **landing-recovery redirect** for an `AIRBORNE` state: when this state reaches the ground via the AD-043 clamp *and is not a launched HITSTUN reaction*, `_land` transitions it to `landing_state_id` (a grounded, non-actionable, once-through recovery state) **instead of** `idle_state_id`. Precedence in `_land`: launched-HITSTUN → `reaction_map[REACTION_KNOCKDOWN]` (re-arms `stun`); else `landing_state_id != 0` → that state; else `idle_state_id`. Unlike knockdown it does **not** re-arm `stun` — the recovery is the character's own commitment, governed by `duration`/actionability. Character B's **divekicks** set it (each pointing at a recovery state whose `duration == that divekick's `HitBox.blockstun``, the AD-050 equality invariant); jumps and air normals leave it `0` and land to idle exactly as before. |

### `Keyframe` (a frame range within a `MoveState`)
| Field | Meaning |
|---|---|
| `frame_start`, `frame_end` | Inclusive range within the state (1-indexed by `frame_in_state`). |
| `hurtboxes` | List of `Box` active this range. |
| `hitboxes` | List of `HitBox` active this range. |
| `throwboxes` | List of `Box` for throws (optional). |
| `motion` | Per-range movement deltas / velocity sets (optional). |
| `invuln` | Optional invulnerability flags for this range: `invuln_strike` and `invuln_throw` (AD-031). A frame with `invuln_strike` set cannot be contacted by a `hit_kind` of `STRIKE` or `PROJECTILE`; a frame with `invuln_throw` set cannot be contacted by a `THROW`. Enforced in phase 4 (the contact is not recorded — the incoming box **whiffs**), and the whiff is *observable* through the inspection surface so the training mode can show a frame was invulnerable and that a hit whiffed *because of* invuln (see `combat-resolution.md` → phase 4, and `inspection-surface.md`). Invuln gates on the **defender's covering keyframe** for the current `frame_in_state`; both flags may be set (full invuln). Unset ⇒ vulnerable. |
| `spawn` | Optional (AD-021, AD-030). Spawns a projectile this range: `{ projectile, offset, velocity }` — `projectile` names a `ProjectileData` by `data_id`, `offset`/`velocity` are the fixed-point spawn position/velocity supplied to the runtime entity. **Fires once**, on the tick `frame_in_state == frame_start` for this range (AD-030 / JC-033) — *not* once per covered frame; a spawn authored across several frames spawns one projectile. Subject to the owner's live-projectile cap; if the cap is full the spawn is suppressed. **Single source (JC-113):** the spawn carries **only** these spawn-time values — it references the projectile's fixed design by `data_id` and never re-authors that design's fields (`gravity`, `hitbox`, hit data, `lifetime`). Those live **once** on the registry `ProjectileData` (the copy phase-3 integration reads *every tick* for ongoing physics); a second copy embedded at the spawn site is the two-independently-drifting-authorings drift the AD-030 field split forbids and the project's single-source discipline (AD-049) exists to prevent — author both from one shared source. |

### `ProjectileData` (authored projectile shell — AD-021, AD-030)
The authored `.tres` shell for a projectile's own **fixed design**. Named
`ProjectileData` (not `Projectile`) because the runtime entity in
`SimState.projectiles[]` owns the `Projectile` identifier (AD-030 / JC-032). Authored
content, resolved through `ProjectileRegistry` — *not* serialized state (AD-024).

| Field | Meaning |
|---|---|
| `id` | Registry key (`data_id`); the runtime entity carries this to re-reach its authored data. **GLOBAL namespace (AD-049)** — `ProjectileRegistry` is one flat roster with no character context (the id is serialized bare in `Projectile.to_dict`), so `data_id` must be **unique across the entire roster**, not merely within a character. Allocate a fresh range per character (A: 201–203, B: 220–222). `ProjectileRegistry.install` **rejects duplicates** rather than silently overwriting — the collision that would otherwise let character C's projectile quietly replace character A's. |
| `hitbox` | A `HitBox` (geometry + hit data) carried by the projectile. |
| `lifetime` | Frames it persists before despawning; consumed on hit/block. Measured from the tick *after* spawn (AD-030 / JC-034 — see below). |
| `max_per_owner` | Live cap (1 for the slice fireball). |
| `gravity` | Optional (AD-047). Baked-FP vertical acceleration applied to the runtime entity's `velocity.y` each tick (phase 3) → a **parabolic arc**. `0` (default) = straight-line (character A's fireball). Character B's high-angle setplay projectile authors different initial `velocity` + `gravity` per strength for **different parabolas**; a projectile whose `pos_y >= ground_y` **despawns** (ground contact). The "falls-in-front" oki must stay a *readable mixup* (AD-047), never an unblockable. |

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
| `target` | Destination `state_id`, **or a cancel-group name** (a set of `state_id`s the `Character` declares). Group-target **resolution is built as of P2 (AD-044)** — the AD-015 group path JC-023 deferred: a buffered command whose destination state is a *member* of the target group satisfies the cancel (subject to `condition`/`window`/`requires_tag`, through the one recognizer). Character B's gatling ladder is authored as group targets. |
| `condition` | `on_hit` \| `on_block` \| `on_contact` \| `on_whiff` \| `always`. |
| `window` | Frame range within the move the cancel is allowed; default first-active→end. |
| `input` | Required command (button/motion) to take the cancel. **`0` = none** — no input gate at all: the cancel is satisfied on input unconditionally (still subject to `condition`/`window`/`requires_tag`). Used for an `always`, window-gated transition that carries a state into the next with no button/motion (e.g. a prejump into the neutral jump arc). Mirrors the `ButtonMapEntry` sentinel convention (`motion 0 = none`, `button_index -1 = no button`). A nonzero `input` is resolved through the one recognizer via the `button_map` entry targeting the same state (raw-button fallback) — JC-023/AD-015. |
| `requires_tag` | Optional cancel tag that must be present (granted by a connecting `HitBox.cancel_tags`). |

Move classes are expressed, not special-cased: **gatling/chain** = `on_contact`
to another normal within a `window`; **special-cancel** = `requires_tag` granted
by the hit; **whiff-cancel** = `on_whiff`. Rehit/multi-hit is *not* a cancel —
see `HitBox.rehit_interval` and AD-016.

**Gatling strength-ladder (character B; AD-044 — the format-generality test, passed).** B's chain
model — "cancel into a **higher strength**, OR into the **same-strength normal of the other stance**;
**lights self-chain**" — is expressed with **no format extension**, as `on_contact` cancels to
**cancel groups**. Each chainable normal is tagged `strength` (L<M<H) and `stance` (stand/crouch); a
cancel `source → target` is legal iff `target.strength > source.strength`, **or**
`target.strength == source.strength && target.stance != source.stance`, **or** both are lights
(`strength == L`, including exact self-repeat). So `5L 2L 2L 5M 2M 2H 5H` is legal, `5M 5M` and `5M 5L`
are not (AD-044 owns the precise rule and the resolved brief ambiguity on equal-strength stance
toggling). The groups are authored data; the ladder is not engine-special-cased.

**Authoring rule — don't end an ALWAYS-cancel window at `duration` (JC-038).** A
once-through move is *actionable on its `frame_in_state == duration` frame*, and
phase 2 runs the actionable/buffered-command branch **before** the cancel branch
(fixed transition priority, `combat-resolution.md` criterion 2). So a cancel whose
`window` ends exactly at `duration` is unreachable on its own last frame — the
buffered-command branch preempts it. **Author an ALWAYS (input-gateless,
`input = 0`) chaining cancel to end at `duration − 1` or earlier.** This is a
frame-authoring constraint for character authors (it will bite character-B
authoring in P2 otherwise); the priority order and the actionable-on-`duration`
semantics are pinned contract — see `combat-resolution.md` → "Stun &
actionability".

### `ButtonMapEntry` (one entry in `Character.button_map`) — command recognition contract (AD-018, AD-032)

Maps a generic input command to a destination `state_id`. This is the only place
buttons gain meaning (AD-002/AD-018). Entries are evaluated in **authored order**;
the **first entry whose command is satisfied wins** (first-match-wins). A command is
"satisfied" when it is recognized within the input buffer (motion within the 9-frame
window, buttons/directions within the 6-frame command buffer — AD-022), read through
the one recognizer.

| Field | Meaning |
|---|---|
| `motion` | Optional motion id (`236`, `623`, `214`, …); `0` = none. Recognized in the 9-frame motion window. **The motion set is open and data-populated** (ratified from JC-090): a motion id is an entry in the one recognizer's motion-id → ordered-direction-token table, so adding a motion a character spec names (B's `214` = `down, down-back, back`, with its symmetric `DIR_DOWN_BACK` token) is **populating an existing mechanism, not extending the format** — the same standing as AD-044's cancel-group resolution. Two things this does *not* license: a second recognizer or any bespoke per-character motion check (one recognizer, Tenet 2 — every consumer reads buffering identically), and a genuinely new **recognition shape** (a re-press, a charge, a chord), which is a format matter and an Architect call (`double_tap`/`chord_button_index` are the precedent — AD-032/AD-046). |
| `button_index` | The primary generic button (`BUTTON_0…7`), or **`-1` = no button** (a pure-direction / motion-only command). |
| `chord_button_index` | Optional **second** required button (AD-032); `-1` = none. When set, the command requires `button_index` **and** `chord_button_index` both held on the **same** frame within the command buffer — a two-button *chord* (e.g. throw `L+H`). |
| `required_direction` | Optional direction gate (raw direction bits; the sim resolves forward/back by facing before matching). For a pure-direction command (`button_index == -1`, no `motion`) this is the *whole* command (e.g. jump = `UP`). |
| `double_tap` | Optional (AD-046). When set, the command is a **double-tap** of `required_direction`: the direction pressed → released → pressed within the slice-wide double-tap window (a sim-side feel constant, AD-022 family). Recognized by the one recognizer over `input_history` (pure function of history, Tenet 2). Routes to a dash state — character B's ground dash, and character A's `66`/`44` (wiring A's existing `STATE_DASH_F/B`). |
| `target_state_id` | Destination `state_id`. |

**Two command shapes this contract must express (AD-032):**

- **Pure-direction command** (jump, `7/8/9`): `button_index = -1`, `motion = 0`, and a
  `required_direction` (e.g. `UP`). Recognized when the required direction is held on any
  of the last 6 (command-buffer) frames — no button needed. This is the directionless/
  button-less path the P0 recognizer lacked. (A jump is a *held direction*, not a motion
  sequence, so it is a `required_direction` gate, **not** a new `motion` token — keeping
  `_motion_tokens` reserved for actual multi-direction sequences.) **Walk is the other
  canonical pure-direction command** (ratified from JC-046): a bare held forward/back
  (`button_index = -1`, `motion = 0`, `required_direction = RIGHT`/`LEFT`, facing-resolved)
  routes to the character's `WALK_F`/`WALK_B` state. It is listed **after** the standing
  normals so a button held together with a direction still performs the normal (first-match-
  wins; the normals match on any direction via their own `required_direction == 0` gate, so
  they win by list order over a bare walk). Every character's walk uses this one shape — it
  is recognition wiring, not authored move content.
- **Two-button chord** (throw, `L+H`): `button_index` = one button, `chord_button_index` =
  the other, both required on the **same** frame (not merely both somewhere in the window,
  which a naive per-button buffer scan would wrongly accept). `required_direction`/`motion`
  optional.

**First-match-wins and shadowing (the reachability rule, AD-032).** Because the first
satisfied entry wins, a **chord entry must be listed *before* the bare-button entries it
shares a button with**, so a simultaneous `L+H` resolves to the throw, not to `5L`. A bare
`L` alone does **not** satisfy the chord (both bits required on one frame), so `5L`/`5H`
stay reachable when pressed alone — the chord does not shadow its component normals. This
ordering requirement is an **authoring rule the format guarantees is expressible**, not new
engine behavior: the recognizer already resolves entries in authored order; the chord field
is what lets the throw be authored at all without stealing a bare button (the exact problem
that left `L+H` unreachable — three buttons all taken by standing normals). QA can assert
`5L`/`5M`/`5H` each remain reachable alongside the throw.

### `Box` (geometry, character-local)
| Field | Meaning |
|---|---|
| `x`, `y`, `w`, `h` | AABB in character-local space, **fixed-point units** (AD-014); flipped by `facing`, offset by `position`. |

**Vertical convention (AD-037): up is −Y, one shared axis with world position.** Box
resolution is a pure translate + facing-x-flip (`wy = pos_y + b.y`), so character-local Y
shares the world axis fixed by AD-033: **up = −Y**. The character's `position` anchor is its
**feet** at `pos_y = ground_y`; a box's `y` is its **min corner (head/top) edge** and the box
spans `[y, y+h]` **downward toward the feet**, so a grounded body occupies local `y ∈ [−H, 0]`
(head at `−H`, feet at `0`). Authoring a body with *positive* downward `y` is the JC-inversion
AD-037 diagnosed (it renders below the floor / upside-down while passing every *relative*-overlap
test); the fix is data (reflect across the feet line, `new_y = −(y+h)`), never a render sign flip.

`pushbox` (collision box) is defined per `MoveState`/category rather than
per-keyframe unless a move overrides it.

### `HitBox` (a `Box` plus hit data)
| Field | Meaning |
|---|---|
| `box` | The AABB. |
| `hit_kind` | The contact category (AD-031): `STRIKE` \| `THROW` \| `PROJECTILE`. Determines which of a defender's `invuln_*` flags gates it (a `STRIKE` is whiffed by `invuln_strike`; a `THROW` by `invuln_throw`; a `PROJECTILE` by `invuln_strike` — a projectile is a strike delivered at range). The **canonical** category field; the legacy `throwbox` flag is exactly `hit_kind == THROW` (see below). Default `STRIKE`. |
| `guard_height` | Block-height requirement (AD-045): `HIGH` (overhead — must be **stood** to block), `LOW` (must be **crouched** to block), `MID` (blockable either stance). Default `MID` (existing A/test moves unaffected). A back-hold in the **wrong stance** is an *invalid block* and resolves as a **hit** — the mechanism that makes B's high/low a real, readable mixup. The attack's `guard_height` must match its animation (charter: the overhead *looks* like an overhead); the outcome is observable via `HitEvent.guard_height`/`block_valid`. |
| `damage` | Base damage. |
| `hitstun`, `blockstun` | Frames of stun inflicted on hit / on block. |
| `hitstop` | Freeze frames applied to both parties on contact (AD-010). |
| `pushback_hit`, `pushback_block` | Positional pushback. |
| `launch` / `juggle` | Vertical/launch properties + juggle limit interaction (optional). |
| `hit_reaction`, `block_reaction` | **A `ReactionKind`** (AD-049) — the engine-level *semantic* reaction this box inflicts on hit / on block (e.g. `REACTION_LAUNCH`, `REACTION_CROUCH_BLOCKSTUN`). **Not a `state_id`.** The defender's own state is resolved through the **defender's** `Character.reaction_map` (see "Reactions" below). An attacker names *what happens*; the defender owns *what that looks like on itself*. |
| `cancel_tags` | Tags this hitbox grants for the attacker's cancels (e.g. enables special-cancel). |
| `id_group` | Groups hitboxes of one attack so a single attack hits once (no multi-count from overlapping boxes). |
| `rehit_interval` | Optional (AD-016). If set, this `id_group` may hit the same target again after this many frames — the cadenced multi-hit form. Unset ⇒ one hit per contact. |
| `throwbox` flag | A `HitBox`/`Box` may be marked a throw (AD-016): on connect it bypasses blockstun and enters the throw resolution path (see `combat-resolution.md`). **Equivalent to `hit_kind == THROW`** (AD-031) — the same fact under two names for continuity; the throw resolution path keys on it either way. Authoring may set either; they must agree. |
| `tech_window` | Throw-only (AD-029). Frames the thrown defender may tech after this throwbox connects (AD-016 tech window). Meaningful only when the throwbox flag is set — a throw is never blocked, so it carries no `blockstun`; the tech window is its own authored feel value, **not** `blockstun` reuse. `0` on a non-throw box. |

## Derived frame data (one canonical definition — AD-008)

Computed from a `MoveState`'s timeline, exposed via the inspection surface:

- **Startup** = frames before the first frame any `HitBox` is active
  (`first_active − 1`).
- **Active** = frames during which any `HitBox` is active, first to last inclusive
  (`last_active − first_active + 1`).
- **Recovery** = frames from end of active to the first actionable frame
  (`duration − last_active`). Equivalently, the first actionable frame of a
  once-through move is **`duration + 1`** — the frame after the state ends
  (`frame_in_state > duration`; 1-indexed inclusive, consistent with the frame
  model, JC-011/JC-014/JC-019). **Total** = `duration`, so
  `startup + active + recovery == total` exactly. (Ratified from JC-011.)
- **On-hit / on-block advantage** = the single formula in `combat-resolution.md`
  (`defender_remaining_stun − attacker_remaining_recovery`). Defined there, in
  one place; this format only supplies the inputs (stun values, recovery).

These definitions are canonical: every character's frame data is derived this one
way, so two characters can't disagree about what "startup" or "advantage" means.

## Movement authoring invariants

- **Airborne movement is velocity + gravity, landed by the runtime clamp (AD-043 — supersedes
  the net-zero-arc invariant).** An airborne character integrates `position += velocity` with
  `velocity.y += physics.gravity` each tick; `velocity` **persists across airborne state
  transitions**. A jump authors a **takeoff velocity** (an impulse `motion` set on frame 1), and
  gravity + the **continuous `pos_y ≥ ground_y` clamp fused with landing** bring it down and land it
  flush — **no hand-balanced net-zero arc is authored or required** (the JC-047/AD-036 net-zero
  invariant is retired). Author air moves this way: a state that **sets** velocity on a frame does
  so (double jump re-sets up-velocity; air dash sets horizontal + zeros vertical; a divekick sets
  its dive velocity after the hang); a state that authors **no** velocity-set (an air normal)
  **inherits the ongoing fall** — which is exactly the fix for "an air normal stops the jump arc."
  Grounded horizontal movement (walk, dash) stays authored displacement/velocity, `pos_y` pinned at
  `ground_y`, no gravity.
- **Knockdown lands into a dedicated grounded state (AD-043, ratified from JC-070; re-expressed by
  AD-049).** A launched (airborne HITSTUN) character that reaches the ground **transitions to its own
  `reaction_map[REACTION_KNOCKDOWN]`** — a grounded, non-actionable knockdown reaction (fixed wakeup
  `duration` counted **from landing**, so oki timing is independent of launch/air-time) — rather than
  snapping to idle or continuing the airborne reaction in place. Grounded hard-knockdown hits (a low
  slide, a throw KD) reach the **same** state via `hit_reaction = REACTION_KNOCKDOWN`, so both converge
  on one learnable wakeup. The old `knockdown_state_id` field and its `== 0` no-transition fallback are
  **retired** (AD-049): the reaction is now required content, resolved on the defender's own map.
- **A divekick stays active until it lands, then lands into a recovery redirect (AD-050).** Author a
  divekick's active hitbox to run through its descent — the AD-043 landing clamp (which ends the state)
  is what stops it, so the hitbox is active from the dive impulse until landing; `active_hit_ids`
  (AD-026) keeps it **one hit per contact**, not a machine-gun. Set the divekick's `landing_state_id`
  (above) to a **grounded, non-actionable recovery state** whose `duration` is authored **equal to the
  divekick's `HitBox.blockstun`** (the AD-050 invariant). The two together produce **height-dependent
  block advantage** as an emergent property — hit low ⇒ ≈ neutral, hit high ⇒ deeply minus — read out
  through the one AD-008 live-advantage formula and neutral-restoration, the same observable-friction
  shape as B-1's slide. This is the only place `landing_state_id` is used in the slice.

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
10. **Cancel groups + strength ladder (AD-044).** A `CancelRule` whose `target` names a
    cancel group is satisfied by any buffered command whose destination state is a member.
    Character B's chainable normals produce exactly the legal ladder — `5L 2L 2L 5M 2M 2H 5H`
    resolves through, `5M 5M` and `5M 5L` are rejected — authored purely as data groups, no
    engine special-casing (the format-generality test passing).
11. **Guard height (AD-045).** A `HitBox` with `guard_height = HIGH` is blocked only from a
    standing block and hits a crouching back-hold; `LOW` is blocked only crouching and hits a
    standing back-hold; `MID` is blocked either. The connecting attack's `guard_height` and the
    block validity are readable through `HitEvent`. Default `MID` leaves existing moves unchanged.
12. **Double-tap dash (AD-046).** A double-tap of a `required_direction` within the double-tap
    window routes to the dash state; a single tap or a too-slow second tap does not. Character A's
    `66`/`44` reach `STATE_DASH_F/B` through this with no A engine change.
13. **Airborne physics (AD-043).** A jump authored as a takeoff-velocity impulse rises, decelerates
    under `gravity`, and lands flush via the continuous clamp with **no net-zero authored arc**; an
    air normal cancelled from a jump **carries the fall** (does not stop the arc); a launched
    character lands into a knockdown reaction. Velocity persists across airborne state transitions.
    All integer/FP.
14. **Arc projectile (AD-047).** A `ProjectileData` with `gravity != 0` follows a parabola and
    despawns on ground contact; `gravity = 0` stays straight (A's fireball unchanged).
15. **Reaction-map completeness (AD-049).** Every character in the roster maps **every**
    `ReactionKind` to one of its **own** `state_id`s, and each mapped state exists in that
    character's `states` and declares the category its kind requires (hitstun family ⇒
    `HITSTUN`; blockstun family ⇒ `BLOCKSTUN`). Checkable statically over the roster with no
    sim run — a character missing a kind fails here, not in play. This is the check that
    would have caught the P2 defect.
16. **Cross-character reactions resolve (AD-049 — the regression this exists to prevent).**
    Character **A hits character B** (and B hits A — *asymmetric*, never a mirror): the
    defender enters a state **from its own roster**, `PlayerView.boxes` is **non-empty** on
    every tick of the reaction, and the defender **becomes actionable again** when stun
    expires without any external reset. Asserted for each `ReactionKind` — including
    `REACTION_AIR_RESET`, which only A inflicts and only B receives. **A mirror matchup
    cannot satisfy this criterion**; the test must use two characters with disjoint state-id
    ranges. (Every pre-P2 test matched a character against itself, which is exactly why this
    shipped.)
17. **No raw `state_id` crosses a character boundary (AD-049).** No `HitBox`/`Character`
    field authored on one character carries a `state_id` resolved against another. The
    defender-facing lookups in hit/throw/land resolution take a `ReactionKind` and resolve it
    through the **defender's own** `reaction_map`. Greppable: `get_state(` is never called on
    one character with an id sourced from another's authored data.
18. **Projectile `data_id` uniqueness (AD-049).** Installing a roster whose characters
    declare a duplicate `data_id` **fails loudly at install time**; it never silently
    overwrites. A and B install clean.
