# Spec — Character B (pressure / air-mobility)

> Owned by the **Architect**. Turns `briefs/character-b.md` into a buildable
> moveset against the P0/P1 format and the P2 ADs (AD-043 airborne physics,
> AD-044 cancel groups, AD-045 guard height, AD-046 dash/air-action, AD-047 arc
> projectile). **Frame numbers, box geometry, and the exact tuning values here
> are slice-provisional** (Developer's to pick within the constraints, QA goldens
> the *mechanism*, same bar as character A / `DamageScaling` / `AirHeightScaling`).
> **The hard legibility constraints below are contract, not tuning** — they are
> QA-checkable acceptance criteria and human-inspection-gate items.
>
> Read with: `move-format.md`, `combat-resolution.md`, and AD-043..047. B invents
> **no new engine primitive** — that is the point (the format-generality proof).

## Identity in one line

A grounded/air pressure character: gatling strings, a high/low + strike/throw
mixup, one air action per jump (air dash *or* double jump), an arcing setplay
projectile, hard-knockdown oki off a low slide — and **no invincible reversal**
(defense is movement). The contrast to A along every axis (brief).

## States & categories (one pattern — AD-007)

All states declare an engine-level category (`GROUNDED` / `AIRBORNE` / `HITSTUN` /
`BLOCKSTUN` / `HITSTOP`). No bespoke machine. Neutral held-input states are `loop`
(AD-038). New relative to A: air-action states (air dash, double jump), the
divekick, the low slide (hard knockdown), and the arc projectile — all authored
data over the P2 ADs, no engine change.

Character-agnostic infrastructure B relies on (all already built or specced): the
gravity/velocity airborne model + landing + knockdown (AD-043), the double-tap
recognizer + `air_action_used` economy (AD-046), cancel-group resolution (AD-044),
`guard_height` block enforcement (AD-045), arc-projectile gravity (AD-047).

## Movement

| Move | Value (provisional) | Notes |
|---|---|---|
| Walk f / b | ~2.0 / ~1.8 px/f | Serviceable, not A's footsie walk (B is not a footsies character). |
| Ground dash `66` | double-tap fwd (AD-046) | B's stagger-pressure / approach tool. Runs the shared recognizer. |
| Back dash `44` | double-tap back, brief low-commit | Escape tool (B's defense is movement — no reversal). Not invulnerable (or minimal), so it is a *read-beatable* escape, not a reversal. |
| Jump `7/8/9` | gravity model (AD-043) | Takeoff impulse + gravity + clamp-landing. Diagonals via per-direction prejump (AD-039), same as A. |
| **Air action (one per jump)** | air dash **or** double jump (AD-046) | Spends `air_action_used`; reset on landing. See below. |

**Air action — one per jump (brief; AD-046).** In the air, before the air action
is spent:
- **Double jump** = `up` (a fresh takeoff-velocity impulse). Jukes a reactive/normal
  anti-air; **loses to a DP** (A's reversal read) — a read-beatable mobility option.
- **Air dash** = double-tap forward/back in the air (sets a horizontal velocity,
  zeros vertical). A **high-commitment** way to blow past a fireball; **punished if
  read** (committed, no cancel out except into an air special). The committed
  approach option.

Exactly one is usable per jump (`air_action_used`); the second is suppressed. The
**divekick does not spend the air action** (AD-046) — so `airdash → divekick` is a
real option, and its reactability is bounded by the legibility criteria below.

## Normals — provisional frame data

Strength/stance tags drive the gatling ladder (AD-044): L<M<H, stand/crouch.
`guard_height` drives the mixup (AD-045). Numbers provisional.

| Move | Strength/stance | Startup | Active | Recovery | guard_height | Role |
|---|---|---|---|---|---|---|
| `5L` | L / stand | 4 | 3 | 7 | MID | Fast pressure starter; self-chains. |
| `2L` | L / crouch | 4 | 3 | 8 | **LOW** | Low pressure starter; self-chains. |
| `5M` | M / stand | 6 | 3 | 12 | MID | Ground poke (B's strongest *ground* poke, still weak absolute — brief). |
| `2M` | M / crouch | 7 | 4 | 13 | **LOW** | Low mid; string filler. |
| `5H` | H / stand | **fast** (~7) | 3 | **severe (~20)** | MID | **Whiff punisher** — lightning startup, **severe recovery on its own whiff** (whiffing 5H is punishable — the risk that pays for the startup; brief). |
| `2H` | H / crouch | ~9 | 4 | 14 | MID | **Anti-air launcher, jump-cancellable on block** (see below). |
| `6H` | command normal | ~22 (reactable) | 3 | ~18 | **HIGH** | **Command overhead** — the dedicated high in B's mixup. Must *look* like an overhead (AD-045 legibility). Startup slow enough to be reactable in isolation. |
| `j.L/M/H` | air normals | — | — | (carry fall) | j.L/M MID, j.H per divekick | Air-to-air / jump-in; carry the fall (AD-043), do **not** stop the arc. |

**`2H` — anti-air launcher, jump-cancellable on block (brief).** Slower-startup
anti-air that **launches** on hit (→ air combo / knockdown-into-ground oki). **On
block it is jump-cancellable** (a `CancelRule` `on_block` into a prejump/jump), so
B can jump-cancel into air pressure. The **follow-up airdash to reach a *crouching*
defender must leave a reactable window** (brief hard constraint) — see the air/mixup
legibility criteria. The `2H`-JC spends B's air action for that jump.

## Cancel model — the strength ladder (AD-044)

The **format-generality test, specced.** B's chainable normals (`5L 2L 5M 2M 5H 2H`)
carry `on_contact` cancels to **cancel groups** encoding: *higher strength*, OR
*same-strength opposite stance*, OR *light self-chain*. So `5L 2L 2L 5M 2M 2H 5H` is
legal; `5M 5M` and `5M 5L` are not. Authored as `Character.cancel_groups` + one/two
`on_contact` `CancelRule`s per normal (AD-044 owns the precise legality rule). `6H`
(overhead) and the specials are **special-cancel targets** where authored (via
`requires_tag`), not part of the auto-ladder. No engine special-casing; this is the
proof the format is not A-shaped.

## Specials

### Low slide (`236L/M/H` or a command — provisional input)
**Three per-strength distance variants (JC-112, superseding JC-092).** The slide is authored as
**three sibling states** — `STATE_SLIDE_L/M/H` — that `236L`, `236M`, `236H` route to respectively.
All three share **every** frame-data property (startup / active / recovery / damage / hitstun /
blockstun / hitstop / hitbox geometry) and differ **only** in travel distance (`motion_vel_x` over
the active window): L short, M mid, H long. This supersedes the earlier "one canonical move, three
inputs" ratification (JC-092): the P2 human-inspection gate directed that the slides' distances vary
much more between strengths (the JC-095-settled tuning flag), which is exactly the "contract addition
here" that ratification reserved to the Architect. Per-strength differentiation is now intended, and
is limited to **distance** — the move's *shape* (frame data / hit properties) stays shared, so B-1's
spacing-variable advantage mechanism is identical per strength (each state still has several active
frames; contact on a later active frame ⇒ different live advantage). Varying behaviour by button
strength requires distinct states because the input layer is semantically blank once resolved to a
state (AD-018) — the same reason the divekick and arc projectile already enumerate per-strength
versions.

A low-hitting slide. **`guard_height = LOW`** (must be crouch-blocked). Causes a
**hard knockdown** (→ knockdown-into-ground reaction, AD-043) and is B's **most
desirable combo ender** (→ oki). **Hard legibility constraint (brief):** its **block
advantage varies by which active frame it is blocked on** (spacing-dependent) and
that variance must be **instrument-readable**. This falls out of AD-008's *live*
advantage for free: the slide has several active frames; contact on a later active
frame leaves the attacker less recovery ⇒ different live advantage, which the training
mode reads out per block — and the spacing that caused it is **visible on screen**
(the geometry overlay shows the distance at contact). See acceptance criterion B-1.

### Arc projectile (`214L/M/H` or a command — provisional input; AD-047)
A high-angle projectile that **covers air space** then falls in an arc
(`ProjectileData.gravity != 0`). Strengths are **different parabolas** (different
initial `velocity` + `gravity`); one version **falls right in front** for
**oki setplay / pressure resets**. Role: **air-space control + setplay, not ground
zoning** — *not* a second horizontal fireball (brief; keeps the two-layer matchup).
Despawns on ground contact (AD-047). **Hard legibility constraint (brief):** the
falls-in-front setup must resolve into a **readable mixup, never an unblockable** —
see acceptance criterion B-2 (the AD-047 guard-height-compatibility invariant).

**Pinned (ratified from JC-093):**
- **`guard_height = MID` on all three strengths.** B-2 is satisfied **by construction** — a MID hit is
  blockable from either stance, so the projectile can never be the opposite half of a guard-height
  conflict with any simultaneous B strike, and B authors no untechable throw. See AD-047's
  "Satisfied by construction" note for the full invariant and its standing condition (it holds only
  while both facts do). The mixup's guess stays on the visible high/low or strike/throw axis.
- **L is the falls-in-front (oki) version** — the shortest parabola of the three, landing closest to B;
  M and H reach progressively further (the genre-conventional L = quick/close, H = long-reach read).
  The spec previously named only "one version"; it is L.

### Divekick (aerial special — `2+attack` in air, provisional; three versions)
An air special (does **not** spend the air action). Three versions, visually
distinguishable in the air (brief hard constraint):
- **L** — brief hang, fast dive. `guard_height = MID` (or high per feel — **not** the
  overhead).
- **M** — slightly longer hang, more horizontal travel. `guard_height = MID`.
- **H** — long hang then near-vertical plummet. **The only overhead version**
  (`guard_height = HIGH`).

Authored via AD-043 velocity-sets: each version sets its dive velocity after its hang
(the hang = zero/low vertical velocity for N frames, then the dive impulse). The
**long hang of H is the telegraph** that an overhead is coming. **Hard legibility
constraint (brief):** the three must be **visually distinguishable in the air** so the
defender can read whether the overhead (H) is coming — see acceptance criterion B-3.

**Landing — active until ground, recovery == blockstun (AD-050; supersedes JC-094).** The P2
re-gate settled the divekick with a **mechanical** call (not a number): a divekick **stays active
until it reaches the ground**, and its **ground recovery equals its blockstun**. Authored via the
new `MoveState.landing_state_id` (AD-050): the divekick's active hitbox runs through its descent
(the AD-043 landing clamp ends the state, so the hitbox is active from the dive until landing —
`active_hit_ids` keeps it **one hit per contact**), and on landing it redirects into a grounded,
non-actionable recovery state whose `duration` is authored **equal to that divekick's `blockstun`**.
This replaces JC-094's land-straight-to-idle deferral (which the Open items predicted would become
exactly this Architect format call — it did). The two clauses together produce **height-dependent
block advantage as an emergent property**: hit low ⇒ B lands almost immediately ⇒ ≈ neutral; hit
high ⇒ B falls the remaining distance while the defender's blockstun ticks out ⇒ deeply minus. Same
cherished-friction shape as B-1's slide, and observable because *how high you hit* is the most
visible thing on screen — see acceptance criterion **B-7**. The numeric tuning (hang, dive vectors,
the blockstun/recovery value) is the separate JC-095 Developer flag; this half is the **mechanic +
the recovery==blockstun equality**, which is contract.

## Mixup layer

- **High/low:** `6H` / H-divekick (HIGH) vs. the lows (`2L/2M`, slide) (LOW). Real
  because of AD-045 enforcement; readable because the highs *look* high (animation) and
  the instrument attributes each hit (`HitEvent.guard_height`/`block_valid`).
- **Strike/throw:** the shared throw (B uses the existing throw/tech model, AD-016/029
  — it defines **no new throw rules**) vs. strikes.
- **No invincible reversal (brief).** B authors **no** invuln reversal special. This is
  a *known, readable* weakness, not a knowledge check. Load-bearing for the A/B contrast.

## The concentrated air/mixup interaction (the phase's hardest legibility call)

B's one-air-action economy, the divekick, the `2H`-JC → airdash pressure, and the
projectile setplay share the **same air-mobility/mixup space** (brief risk-
concentration). The central question: can these combine into **unreactable mixups**
(e.g. `airdash → H-divekick` as a near-instant ambiguous overhead)? The spec's
resolution is the set of invariants in criteria B-2..B-5 below, which every resulting
mixup must satisfy; QA audits B's pressure against the no-knowledge-checks line at the
human-inspection gate (brief). The **reaction-window floor** is a Strategist feel value
(placeholder, like `AirHeightScaling`); the **mechanism and its measurability** are the
Architect's contract here.

## Acceptance criteria (QA-checkable; hard legibility constraints are contract)

Format/mechanism criteria (frame numbers are provisional; these are the invariants):

1. **Authored purely in data.** Every B state/normal/special/cancel is `.tres`/authored
   data over the P0 format + P2 ADs; **no new engine primitive is added for B** (the
   format-generality proof — `move-format.md` criterion 4). Both A and B resolve frame
   data through the one code path.
2. **The gatling ladder resolves exactly (AD-044).** `5L 2L 2L 5M 2M 2H 5H` chains
   through; `5M 5M` and `5M 5L` are rejected; the ladder is authored as cancel groups,
   not engine-special-cased (`move-format.md` criterion 10).
3. **One air action (AD-046).** Air dash and double jump each spend the single air
   action; the second air movement is suppressed until landing resets it; the divekick
   does not spend it.
4. **Airborne carry (AD-043).** A jump-cancelled air normal / a divekick carries the
   fall (does not stop the arc); B's jump lands flush with no net-zero authored arc; the
   slide's hard knockdown lands into the knockdown reaction (oki timer).

**Hard legibility constraints (contract — QA + human gate):**

- **B-1 · Low-slide spacing-variable advantage is instrument-readable.** Blocking the
  slide on different active frames yields different *live* advantage (AD-008), each
  correctly read out by the training mode, and the causing spacing is visible in the
  geometry overlay. Verified by a scripted-input trace: two blocks of the same slide at
  different distances produce different, formula-correct live advantages surfaced through
  the seam. Spacing-dependent frame data is cherished friction **only because it is
  observable** — never a memorized number.
- **B-2 · Arc-projectile falls-in-front oki is a readable mixup, never an unblockable
  (AD-047/AD-045).** Over the falls-in-front oki setup, **no frame exists** where the
  projectile's active hitbox and a simultaneous B strike both connect while requiring
  mutually-incompatible defense (opposite `guard_height`, or block-vs-untechable-throw):
  a single defensive stance/action always defends the projectile, leaving the guess to a
  **visible** high/low or strike/throw. Verified by a scripted-input trace over the setup
  + human gate.
- **B-3 · The three divekicks are distinguishable in the air.** The L/M/H versions have
  measurably distinct trajectories (hang duration + dive vector differ — headless-
  checkable) **and** visually distinct poses (human gate). The **H (overhead) is
  distinguishable before its active frame** — its long hang is a readable tell that the
  overhead is coming.
- **B-4 · Overhead mixups are reactable, not near-instant ambiguous overheads.** No input
  sequence (`airdash → H-divekick`, `2H`-JC → `airdash` → divekick, `6H`, etc.) produces
  an **active overhead hitbox sooner than the reaction-window floor** measured from the
  earliest on-screen frame that distinguishes the overhead (the state change / hang tell).
  The floor is a Strategist feel value (placeholder); the criterion is that the delay is
  **measurable via scripted-input trace** and audited at the human gate. If any sequence
  violates it, that is a spec/tuning correction, not a shipped knowledge check.
  **Current placeholder: 12 ticks** (a stand-in pending the Strategist's feel value — see Open items).
  **Measured against it:** H-divekick's entry-to-active-hitbox delay is **17 ticks** (16 hang + 1
  dive-impulse frame), clearing the placeholder floor. The 17 is the number the human gate judges; the
  12 is only a sanity bound and is not load-bearing design.
- **B-5 · Air-dash crossup side is readable.** When an air dash crosses up, which side it
  lands on is readable as it happens (position/facing legible on screen). No ambiguous-
  side crossup you cannot tell the side of (principles). Human-gate item.
- **B-6 · `5H` whiff is punishable.** Whiffing `5H` leaves B in severe recovery — a real,
  readable risk that pays for the fast startup (brief). Verified: `5H` whiff recovery ≫
  its on-block recovery. **This is an *effective*-recovery comparison delivered by the
  ladder's `on_contact`-gated cancel (ratified from JC-083), not a separately-authored whiff
  recovery:** `5H` has one authored recovery, and its cancel into `2H` is `on_contact` — so on
  hit/block B escapes most of the recovery by chaining, while on a clean whiff (no contact, no
  cancel) B eats the full `duration`. This is the genre-standard "safe on block *because*
  cancellable on contact, punishable on whiff *because* not" model; `MoveState.duration` is
  single-valued, so no outcome-dependent authored recovery exists (or is wanted). QA checks the
  effective-recovery gap via scripted trace (whiff vs. block), not an authored whiff tail.
- **B-7 · Divekick height-dependent block advantage is instrument-readable (AD-050).** A divekick
  stays active until it lands and lands into a recovery state whose `duration == its blockstun`, so
  **blocking the same divekick at different contact heights yields different, formula-correct block
  advantage** — a low block ≈ neutral, a high block deeply minus (roughly the remaining descent),
  read through the one AD-008 live-advantage formula and the neutral-restoration edge as the
  situation resolves, and the causal spacing (contact height) is visible in the geometry overlay.
  Verified by a scripted-input trace (mirrors B-1): two blocks of the same divekick at different
  heights produce different, correctly-ordered advantages / neutral-restoration timings surfaced
  through the seam. **This is cherished friction only because it is observable** — never a memorized
  number. (Scope, per AD-050: the difference is delivered by B's landing-recovery resolving later
  for a higher block, not by a fall-time-prediction primitive in `frames_to_actionable`; the
  contact-height variance being real, one-formula-computed, and on-screen is the bar.) The active
  hitbox is **one hit per contact** (`active_hit_ids`), not a machine-gun.

## Open items routed with this spec

- **Reaction-window floor for overhead mixups (B-4)** — a feel number, Strategist's via
  the spec. **Placeholder 12 ticks; H-divekick currently measures 17.** The mechanism is pinned; the
  floor settles at the human-inspection gate against the measured value.
- **Divekick landing recovery — RESOLVED (AD-050, 2026-07-17).** The JC-094 deferral predicted this
  would become an Architect format call if the gate found the divekicks needed real landing
  punishment. The gate found exactly that: the user settled it with the mechanical ruling now specced
  as **AD-050** — active-until-ground + a `MoveState.landing_state_id` recovery redirect whose
  `duration == blockstun`, giving the emergent height-dependent block advantage (criterion **B-7**).
  The `MoveState.landing_state_id` field is the predicted landing-redirect hook. Numeric tuning stays
  the separate JC-095 Developer flag.
- **Does B need a low-committal "get in" tool beyond air mobility + ground dash** (brief
  open question) — surfaced to the Strategist **only if** playtest/QA finds B cannot
  legibly approach a zoning A (a flag, not a silent addition).
- **Health tuning vs. B's damage** — lands in the match layer after B's damage numbers
  are set (`match-flow.md`, AD-048).
