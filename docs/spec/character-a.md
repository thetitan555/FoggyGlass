# Spec — Character A (the baseline shoto)

> Owned by the **Architect**. The concrete frame data, hitboxes, properties, and
> numbers for character A, authored against `move-format.md` (the Developer builds
> this as `.tres` data). Brief: `/docs/briefs/character-a.md` (Strategist owns
> identity; the Architect owns every number here). Roadmap phase **P1**.

## Notation (anime / numpad)

- **Directions:** numpad — `5` neutral, `2` down/crouch, `6` forward, `4` back,
  `8` up, `1/3/7/9` diagonals. `j.` = airborne. Dashes: `66` forward, `44` back.
- **Buttons:** `L` / `M` / `H` (`BUTTON_0/1/2`, AD-018). So `5H` = standing Heavy,
  `2M` = crouching Medium, `j.H` = jumping Heavy.
- **Motions:** `236` = quarter-circle forward (fireball), `623` = dragon-punch
  (shoryuken). `L+H` = throw.
- **`>` = cancel** (special-cancel). **`,` = link.** (A has no gatlings, so `>`
  here always means a special-cancel.)

## Design stance

A is a **clean, powerful fundamentals shoto**. A deliberately has **no gatlings
and no jump cancels**: no normal→normal chains, no jump-cancel states. Its depth
is *links + special-cancels + footsies + a scary DP*. Intentional, not a gap: the
slice's novelty budget is reserved for the P2 contrast character, whose archetype
is the Strategist's open question (see `roadmap.md`) — A stays the clean baseline
the contrast is measured against.

"Simplified, not dumbed down" shows up as **few moves, real ceiling**: small kit,
but `2M` footsies, DP timing, fireball spacing, and tight links keep mastery high.
Numbers are **juiced** — A hits hard, the DP is scary — within that line.

Distances/speeds authored in **pixels**, baked to fixed-point (AD-014); frames are
integer ticks at 60 Hz. **Advantage values are static** (first-active, uncancelled
— AD-008); the training mode shows live values.

**Tuning status — numbers provisional until playable.** Every number in this spec
(frame counts, stun, damage, distances) was authored before a playable sim exists;
once the training mode is live they get tuned by feel. What is **binding** is
structure: which links exist (non-empty windows), which moves cancel, `5H` plus on
block and advancing, the DP full-punishable on block, each move's role. The
acceptance criteria pin structure; a tuning pass that preserves it passes QA
without a flag round-trip. (Flag-resolved 2026-07-02; see the flag ledger.)

## System stats

- **Health:** 1000.
- **Buttons:** L / M / H, no punch/kick divide.
- **Inputs:** Fireball `236L/M/H` · Shoryuken `623L/M/H` · Throw `L+H`. Recognized
  through the system **input buffer** (AD-022) — see Specials.

## Movement

| Move | Value | Notes |
|---|---|---|
| Walk forward / back | 2.2 / 1.8 px/f | Threatening forward walk for footsies. |
| Forward dash `66` | 20 f, ~95 px | Step dash, fully committed (no cancel). |
| Back dash `44` | 22 f, ~80 px, **invuln 1–7** (strike+throw) | Escape with a real recovery tail. |
| Prejump | 4 f | Then airborne. |
| Jump `7/8/9` | ~45 f airborne | No air dash, no double jump, **no jump cancels** (reserved for a later contrast character). |
| Crouch / Block | — | Stand- and crouch-block; `2L`/`2M` are lows. |

## Normals — frame data

| Move | Startup | Active | Recovery | On block | On hit | `>` cancel? | Role |
|---|---|---|---|---|---|---|---|
| `5L` | 4 | 3 | 6 | **+1** | **+4** | yes (on contact) | Fast poke / frame trap. |
| `5M` | 5 | 4 | 11 | −2 | **+2** | yes (on contact) | Footsie + DP-cancel confirm. |
| **`5H`** | 25 | 3 | 13 | **+3** | **+7** | no | **Forward-advancing pressure reset / hard-read poke.** Very slow (reactable) and committal; plus on block and, on hit, the **3-frame link** into the high-damage combo. Advances ~30 px. |
| `2L` | 4 | 3 | 7 | **+1** | **+6** | yes (on contact) | Low pressure starter, links. |
| **`2M`** | 6 | 3 | 13 | −1 | **+3** | yes (on contact) | **The signature poke** — long range, whiff-punish, `> 236/623`. |
| **`2H`** | 5 | 3 | 13 | −2 | air reset (no combo) | no | **Fast get-off-me anti-air.** Upper-body invuln **1–8**; low reward — a safer, weaker DP. |
| `j.L` | 4 | 6 | (land) | — | height-dep. | no | Air-to-air. |
| `j.M` | 6 | 5 | (land) | — | height-dep. | no | Air-to-air / jump-in. |
| `j.H` | 8 | 5 | (land) | — | height-dep. (deep = very +) | no | **The jump-in starter.** Deep hit links into `5M` / `2M`. |

**Damage & stun** (advantage = `stun − (active + recovery − 1)`, AD-008):

| Move | Dmg | Blockstun | Hitstun | Hitstop | Notes |
|---|---|---|---|---|---|
| `5L` | 30 | 9 | 12 | 8 | small pushback |
| `5M` | 60 | 12 | 16 | 9 | med pushback |
| `5H` | 80 | 18 | 22 | 11 | forward-advancing; +3 blk / +7 hit |
| `2L` | 20 | 10 | 15 | 8 | low; hitstun juiced so `2L` self-links and confirms into `2M` (see routes) |
| `2M` | 70 | 14 | 18 | 10 | long range, low pushback (allows the cancel) |
| `2H` | 60 | 13 | air | 10 | upper-body invuln 1–8; on hit knocks the airborne foe away, **no follow-up** |
| `j.L`/`j.M`/`j.H` | 30/50/80 | — | scales w/ height | 9/10/11 | air |

`5H` is the **only** plus-on-block grounded normal — a forward-advancing pressure
reset (keeps your turn, closes space). Air normals' ground advantage is
height-dependent (deep jump-in = very plus, enabling the grounded links); that is
sim truth the training mode reads out, not a fixed number.

**Height-dependent air advantage is a real mechanism (AD-033, F-014 in P1).** The
"height-dependent" clause above is **backed by an engine rule**, not provisional
hand-waving: an airborne attacker's on-hit air normal scales the hitstun it inflicts
by the attacker's **contact depth** — deeper (closer to the ground) inflicts more
hitstun, so a deep jump-in is more plus (a high/early hit is far less plus). The rule
is the sim-wide `AirHeightScaling` definition (`combat-resolution.md` → "Air-normal
height-dependent advantage"), and the live advantage / contact depth / hitstun delta
are readable through the inspection surface, so the training mode shows *why* a deep
`j.H` is so plus. **Reconciliation with the authored `HitBox.hitstun` (JC-A-04):** the
flat `j.L`/`j.M`/`j.H` hitstun (14) in the Damage & stun table is the **base** the
scaling starts from — height adds a signed delta on top at contact, it does not
replace the authored value. So the flat authored number and the "height-dependent"
prose are consistent: one is the authored base, the other is the live sim scaling.
(The scaling's own numbers are slice-provisional, like all Tuning-status values; the
*mechanism* — deep = more plus, observable — is what makes route 2 real.)

**`2L` on-hit reconciliation (2026-07-04, ruling JC-A-05).** The Normals table's
`2L` on-hit is **+6**, derived from the authored hitstun 15 via the one canonical
formula (`15 − (3+7−1) = +6`) — *not* the stale +3 that previously sat here. The
authored **hitstun (15) is authoritative**: it is the intentionally-juiced number
("hitstun juiced so `2L` self-links and confirms into `2M`", below), and +6 is
exactly what makes the bread-and-butter `2L , 2L` a **3-frame link** (route 3:
`adv − startup + 1 = 6 − 4 + 1 = 3`). The old +3 could not reconcile with the
authored hitstun under the one formula and contradicted route 3's own claim, so it
was the stale figure. On-block already reconciled (`10 − 9 = +1`) and is unchanged.
This keeps both tables internally consistent through the single AD-008 derivation
(the value stays tuning-provisional per "Tuning status," but the two tables must not
*disagree* about the same move — that is a spec defect, now fixed).

Note: with `2H` now an anti-air rather than a sweep, A's **knockdowns come from the
DP and the throw** (no low sweep) — a deliberate narrowing of the simplified kit.

## Specials

### Fireball — `236L/M/H` (a `Projectile`, AD-021)
| Strength | Char startup | Char recovery | Proj. speed |
|---|---|---|---|
| `236L` | 13 | 30 | 5 px/f (far zoning / oki) |
| `236M` | 13 | 30 | 7 px/f |
| `236H` | 13 | 30 | 9 px/f (neutral control, best ender) |

Projectile spawns frame 14 — the `frame_start` of its `spawn` keyframe (AD-030 /
JC-033: the spawn fires **once**, on that tick, not per covered frame), **one fireball
per player** (cap, AD-021): damage 60, hitstun 16, blockstun 12, lifetime until
off-stage/consumed. The fireball appears at its spawn position on frame 14 and begins
travelling on frame 15 (AD-030 / JC-034: a projectile does not integrate or age its
spawn tick — its `lifetime`, if a finite value is authored rather than off-stage-only,
counts from frame 15). Tune the fireball's speed/reach against that one-tick offset. The
authored shell is a `ProjectileData` resolved through `ProjectileRegistry` by `data_id`
(AD-030); the `.tres` authors only `id`/`hitbox`/`lifetime`/`max_per_owner` — `owner`
and initial position/velocity come from the cast and the `spawn` keyframe.
The 30-frame recovery is the risk — a jumped fireball up close is a full punish.

### Shoryuken (DP) — `623L/M/H` (the juiced reversal/anti-air)
| Strength | Startup | Invuln | Active | Recovery (+land) | Dmg | On block | On hit |
|---|---|---|---|---|---|---|---|
| `623L` | 3 | strike 1–5 | 8 | 28 + 12 | 100 | ≈ −34 | launch → hard KD |
| `623M` | 4 | strike 1–6 | 8 | 30 + 12 | 130 | ≈ −36 | launch → hard KD |
| `623H` | 5 | **strike+throw 1–8** | 10 (2 hits) | 33 + 14 | 160 | ≈ −40 | 2-hit launch → hard KD |

The dedicated reversal is `623H` (longest invuln, most damage, most recovery).
Massively minus on block with full landing recovery: blocking a DP = guaranteed
full punish — the high-commitment "get off me." (Contrast `2H`: safe, low reward.)

### Throw — `L+H`
Startup 5, range ~60 px, throwbox (AD-016): bypasses blockstun, **tech window 7
frames**, whiff recovery 20. Damage 120, **hard knockdown → oki**.

### Input buffer (slice-wide, AD-022)
All special motions are recognized through the system input buffer: a **9-frame
motion window** for the directional sequence, and a **6-frame command buffer** that
fires the move on the first actionable frame. So a `623` buffered during
blockstun/hitstop/wakeup comes out as a **frame-1 reversal**, and `> 236/623`
cancels have consistent leniency. Same buffer for every character and every input
source (deterministic, reads `input_history`).

## Cancels (CancelRule lists — AD-015), on purpose

Special-cancels + links only. No gatlings, no jump cancels.

- Cancellable normals carry `cancel_tags: ["sp"]`; **Fireball** and **Shoryuken**
  are `CancelRule`s with `requires_tag: "sp"`, `condition: on_contact`,
  `window: active→recovery`.
- Cancellable: `5L`, `5M`, `2L`, `2M` (on contact — blockstrings `> 236` pressure
  work). **Not** cancellable: `5H` (its reward is the link), `2H` (anti-air), the
  sweep-less kit, all air normals.
- **No `CancelRule` targets another normal** (no gatlings); **no state grants a
  jump cancel** — both reserved for a later contrast character (the Strategist's
  P2 call). A's combos come from **links**.

## Bread-and-butter routes (the intended ceiling)

`>` cancel, `,` link. The training mode shows each link window (the brief's promise).

1. **Footsie / whiff-punish:** `2M > 623L` → hard KD → oki (~150).
2. **Jump-in:** `j.H , 5M > 623M` → hard KD (~250). The `j.H , 5M` link requires a
   **deep** `j.H` (attacker low at contact): the height-dependent air-advantage rule
   (AD-033) makes a deep `j.H` plus enough to link `5M`, while a high/early `j.H` is
   not — a real, observable read the training mode shows (contact depth → hitstun →
   advantage), not a fixed number. This route is backed behaviorally now, not just
   structurally.
3. **Low confirm:** `2L , 2L , 2M > 236H` — pressure + fireball oki. (`2L , 2L` =
   3f link; `2L , 2M` = **1f** — the kit's hardest link.)
4. **The 5H combo (the 3-frame link):** `5H , 5M > 623M` — `5H` on hit (+7) links
   `5M` on a **3-frame window**, cancel into DP for high damage (~270). On block
   `5H` is +3 → forward-advancing pressure reset, your turn continues.
5. **DP punish:** (blocked `623`) → `5H , 5M > 623M` (~270) — a blocked DP is
   minus enough that even 25f `5H` punishes; the max punish is the same 3f-link
   route. (No counterhit system exists in the slice — see `flags.md`, kicked to
   the Strategist as a scope question.)
6. **Anti-air:** `623` (big reward, full-punishable) **or** `2H` (safe, low reward)
   — the core risk/reward read.

## Oki

After `623` / throw knockdown: meaty `2L` / `2M` (frame-tight, shown by the
training mode), a `236L` meaty for far oki, or a throw/strike mix. No vortex — the
archetypal "knockdown → pressure → read" loop.

## Acceptance criteria (QA-checkable)

1. **Authored as data.** Every move exists purely as `.tres` data against
   `move-format.md` — no character-specific engine code.
2. **Frame data derives consistently.** Each move's startup/active/recovery and
   on-block/on-hit advantage derive from its *authored data* via the one canonical
   derivation and formula (AD-008 static), and the training mode reads them out
   correctly. The specific table values are provisional (see Tuning status); QA
   verifies derivation-consistency plus the structural criteria below, not exact
   numbers.
3. **`5H` pressure reset + tight link.** `5H` is plus on block and advances
   forward; on hit the link into `5M` has a **non-empty, deliberately tight
   window** (authored target: 3 frames — provisional), enabling `5H , 5M > 623`
   for high damage; the window is displayed by the training mode.
4. **`2H` safe anti-air.** `2H` has upper-body strike invuln from frame 1 through
   the end of its active frames, beats a jump-in, gives **no combo** on hit, and
   is at worst slightly minus on block (not punishable) — distinct from the DP's
   high-risk/high-reward. (No sweep exists in the kit.)
5. **Fireball is a projectile.** Casting spawns one runtime `Projectile` from a
   `ProjectileData` (AD-021, AD-030); a second cast while one is live is suppressed; it
   travels (from the tick after spawn, AD-030), hits/blocks once, is consumed, and is
   visible in the geometry overlay.
6. **DP invuln + punish.** Each DP is strike-invulnerable from frame 1 through at
   least its first active frame (`623H` also throw-invulnerable); on block every
   DP is minus enough that **even 25f `5H` punishes before the DP recovers** —
   full-punishable by construction, exact advantage provisional. The training mode
   shows the punish window.
7. **Throw.** Connects through block, techable within 7 frames (AD-016), hard
   knockdown on success.
8. **Input buffer.** A `623` buffered during blockstun/wakeup executes on the first
   actionable frame (frame-1 reversal); motion recognition honors the 9-frame
   window and 6-frame command buffer (AD-022).
9. **No gatlings / no jump cancels.** No `CancelRule` targets a normal; no state
   grants a jump cancel — verifiable in A's data.
10. **Bread-and-butter works.** Each route is executable in the training mode and
    deals damage in the stated ballpark; each required link window is non-empty and
    displayed.
11. **Height-dependent air advantage (AD-033).** A deep `j.H` (attacker low at
    contact) is more plus than a high/early one — the same air normal at two contact
    heights yields different, correctly-ordered live advantages, and a deep `j.H`
    is plus enough to link `5M` (route 2). The contact depth and the height-scaled
    hitstun delta are readable through the inspection surface so the read is
    attributable. The flat authored air-normal hitstun is the *base* the scaling
    starts from (JC-A-04), consistent with the height-dependent prose. Scaling
    numbers are provisional (Tuning status); QA verifies the ordering (deep > high),
    the floor, and observability, not the specific curve.
