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

## Design stance (and the B-contrast)

A is a **clean, powerful fundamentals shoto**. Per the peek ahead — **character B
will be the test of gatlings and jump cancels** — A deliberately has **neither**:
no normal→normal chains, no jump cancels. Its depth is *links + special-cancels +
footsies + a scary DP*. Intentional, not a gap: it reserves chains/jump-cancels
for B and gives the matchup a real contrast (grounded reads vs. flashy strings).

"Simplified, not dumbed down" shows up as **few moves, real ceiling**: small kit,
but `2M` footsies, DP timing, fireball spacing, and tight links keep mastery high.
Numbers are **juiced** — A hits hard, the DP is scary — within that line.

Distances/speeds authored in **pixels**, baked to fixed-point (AD-014); frames are
integer ticks at 60 Hz. **Advantage values are static** (first-active, uncancelled
— AD-008); the training mode shows live values.

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
| Jump `7/8/9` | ~45 f airborne | No air dash, no double jump, **no jump cancels** (B's domain). |
| Crouch / Block | — | Stand- and crouch-block; `2L`/`2M` are lows. |

## Normals — frame data

| Move | Startup | Active | Recovery | On block | On hit | `>` cancel? | Role |
|---|---|---|---|---|---|---|---|
| `5L` | 4 | 3 | 6 | **+1** | **+4** | yes (on contact) | Fast poke / frame trap. |
| `5M` | 5 | 4 | 11 | −2 | **+2** | yes (on contact) | Footsie + DP-cancel confirm. |
| **`5H`** | 25 | 3 | 13 | **+3** | **+7** | no | **Forward-advancing pressure reset / hard-read poke.** Very slow (reactable) and committal; plus on block and, on hit, the **3-frame link** into the high-damage combo. Advances ~30 px. |
| `2L` | 4 | 3 | 7 | **+1** | **+3** | yes (on contact) | Low pressure starter, links. |
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
| `2L` | 20 | 10 | 12 | 8 | low |
| `2M` | 70 | 14 | 18 | 10 | long range, low pushback (allows the cancel) |
| `2H` | 60 | 13 | air | 10 | upper-body invuln 1–8; on hit knocks the airborne foe away, **no follow-up** |
| `j.L`/`j.M`/`j.H` | 30/50/80 | — | scales w/ height | 9/10/11 | air |

`5H` is the **only** plus-on-block grounded normal — a forward-advancing pressure
reset (keeps your turn, closes space). Air normals' ground advantage is
height-dependent (deep jump-in = very plus, enabling the grounded links); that is
sim truth the training mode reads out, not a fixed number.

Note: with `2H` now an anti-air rather than a sweep, A's **knockdowns come from the
DP and the throw** (no low sweep) — a deliberate narrowing of the simplified kit.

## Specials

### Fireball — `236L/M/H` (a `Projectile`, AD-021)
| Strength | Char startup | Char recovery | Proj. speed |
|---|---|---|---|
| `236L` | 13 | 30 | 5 px/f (far zoning / oki) |
| `236M` | 13 | 30 | 7 px/f |
| `236H` | 13 | 30 | 9 px/f (neutral control, best ender) |

Projectile spawns frame 14 (`spawn` keyframe), **one fireball per player** (cap,
AD-021): damage 60, hitstun 16, blockstun 12, lifetime until off-stage/consumed.
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
- **No `CancelRule` targets another normal** (gatling = B); **no state grants a
  jump cancel** (also B). A's combos come from **links**.

## Bread-and-butter routes (the intended ceiling)

`>` cancel, `,` link. The training mode shows each link window (the brief's promise).

1. **Footsie / whiff-punish:** `2M > 623L` → hard KD → oki (~150).
2. **Jump-in:** `j.H , 5M > 623M` → hard KD (~250).
3. **Low confirm:** `2L , 2L , 2M > 236H` — pressure + fireball oki. (`2L,2L` = 1f link.)
4. **The 5H combo (the 3-frame link):** `5H , 5M > 623M` — `5H` on hit (+7) links
   `5M` on a **3-frame window**, cancel into DP for high damage (~270). On block
   `5H` is +3 → forward-advancing pressure reset, your turn continues.
5. **Counterhit:** `5M (CH) , 2M > 623L`.
6. **Anti-air:** `623` (big reward, full-punishable) **or** `2H` (safe, low reward)
   — the core risk/reward read.

## Oki

After `623` / throw knockdown: meaty `2L` / `2M` (frame-tight, shown by the
training mode), a `236L` meaty for far oki, or a throw/strike mix. No vortex — the
archetypal "knockdown → pressure → read" loop.

## Acceptance criteria (QA-checkable)

1. **Authored as data.** Every move exists purely as `.tres` data against
   `move-format.md` — no character-specific engine code.
2. **Frame data matches.** Each move's derived startup/active/recovery and on-
   block/on-hit advantage equal the tables (AD-008 static); the training mode reads
   them out correctly.
3. **`5H` pressure reset + 3-frame link.** `5H` is +3 on block and advances
   forward; on hit (+7) the link into `5M` has a window of **exactly 3 frames**
   (verifiable), enabling `5H , 5M > 623` for high damage.
4. **`2H` safe anti-air.** `2H` has upper-body invuln on frames **1–8**, beats a
   jump-in, gives **no combo** on hit, and is only −2 on block — distinct from the
   DP's high-risk/high-reward. (No sweep exists in the kit.)
5. **Fireball is a projectile.** Casting spawns one `Projectile` (AD-021); a second
   cast while one is live is suppressed; it travels, hits/blocks once, is consumed,
   and is visible in the geometry overlay.
6. **DP invuln + punish.** Each DP has the listed invuln on the listed frames; on
   block it is full-punishable (advantage matches); the training mode shows the
   punish window.
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
