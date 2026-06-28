# Spec — Character A (the baseline shoto)

> Owned by the **Architect**. The concrete frame data, hitboxes, properties, and
> numbers for character A, authored against `move-format.md` (the Developer builds
> this as `.tres` data). Brief: `/docs/briefs/character-a.md` (Strategist owns
> identity; the Architect owns every number here). Roadmap phase **P1**.

## Design stance (and the B-contrast)

A is a **clean, powerful fundamentals shoto**. Per the Strategist's steer and the
peek ahead — **character B will be the test of gatlings and jump cancels** — A
deliberately has **neither**: no normal→normal chains, no jump cancels. Its depth
is *links + special-cancels + footsies + a scary DP*. This is intentional, not a
gap: it reserves the chain/jump-cancel mechanisms for B to exercise, and gives the
matchup a real contrast (grounded reads vs. flashy strings).

"Simplified, not dumbed down" (the brief's charter line) shows up as **few moves,
real ceiling**: the kit is small, but cr.M footsies, DP timing, fireball spacing,
and 1-frame links keep mastery high. Numbers below are **juiced** — A hits hard
and its DP is genuinely scary — within that line.

All distances/speeds are authored in **pixels**, baked to fixed-point (AD-014);
frames are integer ticks at 60 Hz. **Advantage values are static** (first-active
contact, uncancelled — AD-008); the training mode shows the live values.

## System stats

- **Health:** 1000.
- **Buttons:** Light / Medium / Heavy (`BUTTON_0/1/2`, AD-018). No punch/kick divide.
- **Throw input:** L+H. **Fireball:** ↓↘→ + button. **Shoryuken:** →↓↘ + button.

## Movement

| Move | Value | Notes |
|---|---|---|
| Walk forward | 2.2 px/f | Threatening forward walk for footsies. |
| Walk back | 1.8 px/f | Whiff-bait / spacing. |
| Forward dash | 20 f, ~95 px | Step dash, fully committed (no cancel) — keeps neutral honest. |
| Back dash | 22 f, ~80 px, **invuln 1–7** (strike+throw) | Classic escape option with a real recovery tail. |
| Prejump | 4 f | Then airborne. |
| Jump | ~45 f airborne (neutral/fwd/back arcs) | No air dash, no double jump, **no jump cancels** (B's domain). |
| Crouch / Block | — | Stand-block and crouch-block states; cr.L / cr.H must be crouch-blocked (lows). |

## Normals — frame data

| Move | Input | Startup | Active | Recovery | On block | On hit | Special-cancel? | Role |
|---|---|---|---|---|---|---|---|---|
| st.L | st+L | 4 | 3 | 6 | **+1** | **+4** | yes (on contact) | Fast poke / frame trap. |
| st.M | st+M | 5 | 4 | 11 | −2 | **+2** | yes (on contact) | Footsie + DP-cancel confirm. |
| st.H | st+H | 9 | 4 | 18 | −5 | **+3** | yes (**on hit only**) | Big counterhit / whiff-punish starter. |
| cr.L | cr+L | 4 | 3 | 7 | **+1** | **+3** | yes (on contact) | Low pressure starter, links. |
| **cr.M** | cr+M | 6 | 3 | 13 | −1 | **+3** | yes (on contact) | **The signature poke** — long range, whiff-punish, xx fireball/DP. |
| cr.H | cr+H | 8 | 4 | 20 | −8 | **KD** | **no** (sweep) | Hard knockdown → oki. Not cancellable. |
| j.L | air L | 4 | 6 | (land) | — | height-dep. | no | Air-to-air. |
| j.M | air M | 6 | 5 | (land) | — | height-dep. | no | Air-to-air / jump-in. |
| j.H | air H | 8 | 5 | (land) | — | height-dep. (deep = very +) | no | **The jump-in starter.** Deep hit links into st.M / cr.M. |

**Damage & stun** (advantage above = `stun − (active + recovery − 1)`, AD-008):

| Move | Dmg | Blockstun | Hitstun | Hitstop | Pushback (hit/blk) |
|---|---|---|---|---|---|
| st.L | 30 | 9 | 12 | 8 | small |
| st.M | 60 | 12 | 16 | 9 | med |
| st.H | 90 | 16 | 24 | 11 | large |
| cr.L | 20 | 10 | 12 | 8 | small |
| cr.M | 70 | 14 | 18 | 10 | med (good range, low pushback to allow the cancel) |
| cr.H | 80 | 15 | — (KD) | 11 | knockdown |
| j.L / j.M / j.H | 30 / 50 / 80 | — | scales w/ height | 9 / 10 / 11 | air |

Air normals' ground advantage is height-dependent (deep jump-in = very plus,
enabling the grounded link confirms); that is sim truth the training mode reads
out, not a fixed number.

## Specials

### Fireball — ↓↘→ + L/M/H  (a `Projectile`, AD-021)
| Strength | Char startup | Char recovery | Proj. speed | Notes |
|---|---|---|---|---|
| L | 13 | 30 | 5 px/f | Slow — strong far zoning / okizeme. |
| M | 13 | 30 | 7 px/f | Mid. |
| H | 13 | 30 | 9 px/f | Fast — controls neutral, best combo ender. |

- Projectile spawns frame 14 (a `spawn` keyframe), **one fireball per player** on
  screen (cap, AD-021). Projectile: damage 60, hitstun 16, blockstun 12, lifetime
  until off-stage or consumed on contact.
- The character's 30-frame recovery is the risk: a jumped fireball at close range
  is a full punish. Safe at range, committal up close — the zoning read.

### Shoryuken (DP) — →↓↘ + L/M/H  (the juiced reversal/anti-air)
| Strength | Startup | Invuln (frames) | Active | Recovery (+landing) | Dmg | On block | On hit |
|---|---|---|---|---|---|---|---|
| L | 3 | strike 1–5 | 8 | 28 + 12 | 100 | ≈ −34 | launch → hard KD |
| M | 4 | strike 1–6 | 8 | 30 + 12 | 130 | ≈ −36 | launch → hard KD |
| H | 5 | **strike+throw 1–8** | 10 (2 hits) | 33 + 14 | 160 | ≈ −40 | 2-hit launch → hard KD |

- The dedicated reversal is **H** (longest invuln, most damage, most recovery —
  the cleanest risk/reward). L is the fast combo-ender/anti-air.
- Massively minus on block with full landing recovery: blocking a DP = guaranteed
  full punish. This is the "high-commitment get-off-me" the brief asks for. The
  training mode shows, frame for frame, exactly how minus (the brief's example).

### Throw — L+H
- Startup 5, range ~60 px, throwbox (AD-016): bypasses blockstun, **tech window 7
  frames**, whiff recovery 20. Damage 120, **hard knockdown → oki**. Uses the
  system throw/tech model; defines no new throw rules.

## Cancels (CancelRule lists — AD-015), on purpose

A's cancels are **special-cancels + links only**. No gatlings, no jump cancels.

- **Cancellable normals** carry `cancel_tags: ["sp"]` on their hitbox; **Fireball**
  and **Shoryuken** are `CancelRule`s with `requires_tag: "sp"`, `condition:
  on_contact` (st.H is `on_hit` only), `window: active→recovery`.
- Cancellable: st.L, st.M, cr.L, cr.M (on contact — so blockstrings xx fireball
  pressure work) and st.H (on hit only — it is *not* made safe on block).
- **Not** cancellable: cr.H (sweep), all air normals.
- **No `CancelRule` targets another normal** (that's a gatling — reserved for B),
  and **no state grants a jump cancel** (also B). A's combos come from **links**.

## Bread-and-butter routes (the intended ceiling)

Stated so QA and the training mode have concrete targets; the training mode shows
each link window (the brief's literal promise).

1. **Punish / footsie confirm:** `cr.M xx L.DP` → hard KD → oki. (~150 dmg + okizeme; the whiff-punish payoff.)
2. **Jump-in confirm:** `j.H → st.M xx M.DP` → hard KD. (~250 dmg; the big reward.)
3. **Low confirm:** `cr.L → cr.L (1f link) → cr.M xx H.Fireball` — pressure/chip + spacing, fireball oki.
4. **Counterhit:** `st.H (CH) → cr.M xx L.DP` — the whiff-punish-into-knockdown that "feels earned."
5. **Anti-air:** `L.DP` (or `H.DP` on read) vs. a jump-in → launch → KD → oki.

## Oki (knockdown game)

After DP / sweep / throw knockdown, A gets a meaty `cr.L` or `cr.M` (frame-tight,
shown by the training mode), a `L.Fireball` meaty for far oki, or a throw/strike
mix. No vortex; just the archetypal "knockdown → pressure → read" loop.

## Acceptance criteria (QA-checkable)

1. **Authored as data.** Every move above exists purely as `.tres` move data
   against `move-format.md` — no character-specific engine code (move-format
   criterion 1/4).
2. **Frame data matches.** Each move's derived startup/active/recovery and
   on-block/on-hit advantage equal the table (computed via AD-008's static
   definition); the training mode reads them out correctly.
3. **Fireball is a projectile.** Casting spawns one `Projectile` (AD-021); a second
   cast while one is live is suppressed by the cap; the projectile travels, hits/
   blocks once, and is consumed; it is visible in the geometry overlay.
4. **DP invuln + punish.** Each DP has the listed strike(+throw) invuln on the
   listed frames; on block it is full-punishable (advantage matches), and the
   training mode shows the punish window.
5. **Throw.** Connects through block, is techable within the 7-frame window
   (AD-016), and yields a hard knockdown on success.
6. **No gatlings / no jump cancels.** No `CancelRule` targets a normal; no state
   grants a jump cancel — verifiable in A's data.
7. **Bread-and-butter works.** Each listed route is executable in the training
   mode and deals damage in the stated ballpark; each required link window is
   non-empty and displayed.
