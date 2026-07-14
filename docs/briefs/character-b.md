# Brief — Character B (the pressure/air-mobility contrast)

> Owned by the **Strategist**. A brief states **intent and constraints, not
> implementation** — the Architect owns the spec (frame data, hitboxes, exact
> normal list, cancel routes, damage, properties). This says *what the character
> is for*, *what it must feel like*, and *within what bounds*. Raise anything
> faulty or under-specified rather than building around it.
>
> Roadmap phase: **P2**, alongside the 1v1 match layer. This brief closes the
> roadmap's open question on character B's archetype and resolves the deferred
> character-A dash question. It is the anchor for P2's direction; the match layer
> gets its own short brief (`match-flow.md`).

## The problem it solves — for the charter

Character A proved a person can play a moveset authored in the P0 format. It did
**not** prove the format is *general* — A is a grounded shoto with no gatlings, no
air mobility, and no projectile-less approach game, and every system it exercises
was arguably built to fit it. Character B is the test that the format wasn't
secretly A-shaped: a second character, **deliberately built from the systems A
omits**, authored purely in move data with no new engine primitives invented for
it.

B is also the other half of the slice's first **real matchup** — and the matchup
is the only place the charter's hardest promise, *every option is readable as it
happens*, becomes testable. A single character can be legible in a vacuum; only a
live A-vs-B exchange, with two players making reads against each other, shows
whether the game communicates state well enough to be *played*, not just observed.

## The contrast — the thesis, not decoration

B is chosen as A's opposite along every axis that matters, because the contrast
*is* the format test. A grounded footsies-and-zoning shoto against a second
grounded footsies character would prove almost nothing; against a pressure
character it proves the format spans the genre.

| Axis | Character A | Character B |
|---|---|---|
| Space | Controls it from the ground (fireball, shoryuken) | Collapses it from the air (mobility, approach) |
| Offense | A few committal pokes; zoning | Layered gatling strings; mixups |
| Cancel model | Deliberately sparse — no gatlings | Gatling / chain / air-cancel heavy |
| Reward shape | High per touch (juiced numbers, big punishes) | Lower per hit; relentless pressure → oki loops |
| Defense | An invincible reversal (the "get off me" button) | **No invincible reversal** — defense is movement |
| Range identity | Zones and anti-airs; wants you out | Rushes in and stays in; wants you cornered |

The matchup this produces reads cleanly and asymmetrically: **A controls the
ground horizontally with fireball and anti-airs to keep B out; B contests the
*air* space with an arcing projectile and its air mobility, earns its way in past
A's fireball, and once in buries A under gatling strings, 50/50s, and
slide-knockdown oki; A's escape is a strong anti-air/reversal read and B's approach
risk, B's problem is that it must still earn every entry and has no button to
reverse a bad situation once A gets its turn.** The two projectiles never contest
the same space — A's walls the ground, B's controls the sky and feeds setplay — so
it stays a two-layer zoning/approach puzzle, not a fireball war. Both sides always
have a readable answer — which is exactly what P2 exists to prove.

## Who it's for

- **The veteran**, who reads "pressure/rushdown with air mobility and no reversal"
  on sight and instantly knows the gameplan — the charter's *genre knowledge pays
  off immediately*, now from the opposite pole to A.
- **The learner**, who meets the genre's *other* natural first lessons here:
  blockstrings, high/low and strike/throw mixups, and how to defend and escape
  pressure — the counterpart classroom to A's neutral/whiff-punish one.
- **The team**, because B is the moveset that forces the `CancelRule` model and the
  air-movement engine work (AD-036) to prove themselves, and seeds the golden-file
  regression net with a second, structurally different character to snapshot.

## What success feels like

The pressure character's archetypal moments, each doubling as a legibility lesson:

- You air-dash in past a fireball, land a gatling string, and the training mode
  shows you exactly how plus you were on block and which normal to continue with —
  the pressure is *readable*, not a memorized rote.
- You run a high/low on a downed A, they guess wrong, and the overhead's distinct
  startup *showed* the mixup as it happened — you won a live read, not a knowledge
  check.
- You get anti-aired out of a sloppy approach and eat A's full punish — and you can
  read, frame for frame, why the approach lost, so the lesson is legible.
- You're cornered with no reversal, you defend a real blockstring by watching for
  its gaps, and you movement your way out — defense is a skill you can *see* to
  execute, not a button you press.

The throughline is identical to A's: **honest, readable interactions whose
outcomes you can always find out.** Only the archetype flips.

## The defining toolkit (identity, not spec)

Stated as identity. The Architect owns every property, number, frame, and cancel
route; this fixes only *what tools exist and what role each plays*.

- **Buttons: Light, Medium, Heavy** — the same slice-wide three-button layout A
  established (AD-002). B does **not** get a new button or redefine the input
  contract; it gets a different *use* of the same three.
- **Gatling-chainable normals** — fast, cancel-rich normals that chain into
  strings; the heart of B's pressure and the reason it exists as a format test.
  This is where the `CancelRule` model has to earn its generality, applied *on
  purpose* to this character (per the same "no reflexive UNI conventions" steer
  that governed A — B's chains come from authored cancel rules, not a genre
  default reverse-beat).
- **Air mobility** — B's signature system and the thing A structurally lacks.
  **One air action per jump, spent on either an air dash or a double jump**
  (detailed in the moveset section) — each a distinct, read-beatable approach
  option. A's brief explicitly *reserved* air-mobility complexity for the contrast
  character, and this is that character.
- **A mixup layer** — an **overhead** and the shared **throw** (B uses the existing
  throw/tech model, it doesn't define new throw rules), plus its lows, giving the
  high/low and strike/throw guessing game that makes pressure a *real* decision
  rather than chip. The overhead must be **visually legible as an overhead** (the
  clarity principle — the art teaches the mixup before the HUD does).
- **A grounded dash** — B is a natural user of the double-tap dash recognizer P2 is
  building; it uses it for ground approach and stagger pressure.
- **An arcing, air-space projectile — for setplay and sky-control, *not* ground
  zoning** (user direction, 2026-07-14; overrides my earlier no-projectile call). B
  is still not a neutral zoner and must *earn its way in* on the ground — the arc
  projectile contests the air and feeds oki/pressure resets, occupying space A's
  horizontal fireball doesn't. See the revised matchup note above for why this
  keeps the contrast intact rather than turning B into a second zoner. Detailed in
  the moveset section.
- **No invincible reversal.** B's defense is movement and blocking, not a button.
  This sharpens the offense-heavy / defense-light contrast with A and is a *known,
  readable* weakness — not a knowledge check (see below).

**Discretion calls (updated by user direction, 2026-07-14):** the air-mobility and
projectile calls are now the user's — both air dash *and* double jump under one air
action, and an arcing setplay projectile. What stands from my original cuts: **no
invincible reversal** — B's defense is movement, load-bearing for the
offense/defense contrast with A and confirmed by the user's "[double jump] usually
loses to the DP" framing, which reads *A's* reversal, not one of B's. The mixup
layer stays deliberately legible-over-broad; the specific tools and their hard
legibility constraints are in the moveset section below.

## The charter call B lives or dies on: pressure without knowledge checks

This is the reason B is the harder character and the most important thing this
brief adds. A strings-and-mixup character is precisely where the *no knowledge
checks* principle gets stress-tested, and it is easy to get wrong.

The line, stated so no one downstream blurs it:

- **Cherished friction (build this):** *I can see the high/low or strike/throw
  coming and have to read or guess it live.* A blockstring whose gaps are
  *visible* and whose mixup *telegraphs in the animation* is a real, legible
  decision — hard, but the charter's kind of hard.
- **Tax to remove (never ship this):** *I lost because I didn't already know this
  string has a gap on frame 14, or that this normal is secretly plus.* A mixup
  that is only solvable with prior metagame knowledge — an ambiguous crossup you
  can't tell the side of, a frame trap indistinguishable from a true blockstring —
  is a knowledge check, and it violates the charter this slice exists to honor.

So B's pressure must be **observable pressure**: the training mode already shows
advantage on block, gaps, and state, and B is the character that makes those
readouts matter. The overhead must *look* like an overhead; the air-dash crossup
must be *readable as to which side it lands*; a gap in a string must be *findable
in the moment* (the instrument shows it) rather than memorized. This is a
constraint on B's *design*, handed to the Architect as a hard requirement — not a
number to tune later. If a proposed B tool can only be defended as "strong because
the opponent won't know," it's out.

## Moveset intent — the specific tools (user direction, 2026-07-14)

> These come from the user as direction and are recorded here at brief altitude:
> each states *what the tool is for and what interaction it must produce*, plus the
> charter constraint it carries. **The Architect owns every number, frame,
> active-frame property, cancel-route realization, and the `CancelRule`-format
> expression** — the brief fixes intent, not spec. Where a tool concentrates
> legibility risk, that's a **hard constraint**, not a preference.

**Normals & command normals**

- **5M — the poke.** B's strongest *ground* poke, but still weak in absolute terms.
  B is not a footsies character; this is a serviceable button, not A's cr.MK.
- **5H — the whiff punisher.** Lightning-fast startup to punish whiffs, balanced by
  **severe recovery on its own whiff** (whiffing 5H is punishable — the risk that
  pays for the startup; user-confirmed 2026-07-14).
- **6H — command overhead.** The dedicated high in B's mixup. Must **look like an
  overhead** (clarity principle — the animation teaches the high before the HUD).
- **2H — antiair launcher, jump-cancellable on block.** Slower-startup antiair that
  launches; on block it's jump-cancellable into pressure. The follow-up airdash to
  reach a *crouching* defender must leave a **reactable window** — the crouch-block
  mixup off 2H is a live read by design, not a knowledge check. (Spends B's one air
  action — see below.)

**Air movement — one air action, two options** *(resolves the prior open question)*

- B gets exactly **one air action per jump**, spent on **either**:
  - **Double jump** — jukes a *reactive/normal* antiair, but **loses to the DP**.
    A read-beatable mobility option.
  - **Air dash** — a **high-commitment** way to **blow up a fireball**; punished if
    read. The committed approach option.
  The economy *is* the design: one approach-mixup option per jump, each with a
  clean, readable counter. (Overrides my earlier "air dash over double jump" call.)

**Specials**

- **Low slide** — a low-hitting slide whose **block advantage varies by which
  active frame it's blocked on** (spacing-dependent). Causes a **hard knockdown**
  and is B's **most desirable combo ender** (→ oki). **Legibility constraint
  (hard):** the varying advantage must be *readable in the moment* — the instrument
  shows the actual +/- on each block and the spacing that caused it is *visible on
  screen*. Spacing-dependent frame data is cherished friction only if observable;
  if it can only be learned by memorization it's a knowledge check and it's out.
- **High-angle arc projectile** — thrown at a high angle to **cover air space**,
  then falling in an arc. Strengths are **different parabolas**; one version **falls
  right in front** for **oki setplay / pressure resets**. Role is **air-space
  control and setplay, not ground neutral zoning** — *not* a second horizontal
  fireball. **Legibility constraint (hard):** the "falls in front" setplay must
  resolve into a **readable mixup** (high/low/throw the defender can see and
  contest), never an ambiguous unblockable-style setup.
- **Divekick (aerial special)** — L: brief hang, fast dive. M: slightly longer
  hang, more horizontal travel. H: long hang then near-vertical plummet, and **the
  only overhead version**. **Legibility constraint (hard):** the three versions
  must be **visually distinguishable in the air** so the defender can read whether
  the overhead (H) is coming — a divekick you can't tell apart by sight is a
  knowledge check.

**Cancel model — the tag-game strength ladder**

- A normal cancels **into a higher strength**, or **into the crouching normal of
  its current strength**; **lights cancel into themselves.** So `5L 2L 2L 5M 2M 2H
  5H` is legal; `5M 5M` and `5M 5L` are not. This is B's whole string identity —
  legible (a clear ladder), general (not a UNI reverse-beat import), and the
  concrete **format-generality test**: if the existing `CancelRule` model can't
  express "higher-strength OR crouching-of-same-strength, plus light self-chain,"
  that's a **flag to the Architect** and possibly a format extension — exactly what
  P2 exists to surface.

### Where the charter risk concentrates (hand-off, not mine to resolve)

B's one-air-action economy, the divekick, and the 2H jump-cancel→airdash pressure
all share the **same air-mobility/mixup space**, and the arc projectile feeds oki
setplay on top of it. **The central legibility question for B is whether these
combine into unreactable mixups** (e.g. airdash→H-divekick as a near-instant
ambiguous overhead, or projectile setplay that becomes an unblockable). That is a
**spec + playtest** question, not a brief one: the Architect specs the
air-action / divekick / cancel interactions so every resulting mixup stays
*readable as it happens*, and **QA audits B's pressure against the
no-knowledge-checks line** at the human-inspection gate. I name the concentration
so it gets deliberate scrutiny; I don't resolve it here.

## What it trades against

- **It cashes the air-movement debt now.** B *needs* the AD-036 remainder (fall
  momentum, air-move semantics) and the air-dash / double-tap movement work solid
  before its kit is authorable — which is why the roadmap sequences that hardening
  as P2's opener, ahead of B. B is the reason that debt is load-bearing, not
  deferrable.
- **It is the format's real stress test, and might find cracks.** If the
  `CancelRule` model or the move format turns out to be A-shaped, B is where that
  surfaces — as flags back to the Architect, not as B being quietly bent to fit.
  That's the point of B; budget for it rather than treating a flag as failure.
- **Legibility work is heaviest here.** Getting "pressure without knowledge checks"
  right is the hardest legibility design in the slice so far. It is real work, not
  a tuning pass, and the human-inspection gate (below) is where it's ultimately
  judged.

## Scope notes that ride with this brief

- **Character-A dash — resolved: folded into P2 (yes).** The double-tap recognizer
  lands for B's movement regardless, so wiring A's already-authored-but-unreachable
  dash states (`66`/`44`) to it completes A's intended kit at near-marginal cost.
  The Architect confirms the actual cost and specs the mechanism; if it turns out
  materially more than "wire existing states to the shared recognizer," flag it
  back to me and I'll reconsider.
- **The AD-036 ground-contact remainder is P2's opener, not this brief's content.**
  Its direction lives in the roadmap's P2 pre-requisite note; the Architect specs
  it into P2's opening tickets *before* B's kit. Named here only so the dependency
  is explicit: B is not authorable until it lands.
- **Match rules** (rounds, timer, health) live in the companion `match-flow.md`
  brief, not here — they're the match layer's identity, not B's.

## Open questions (route as noted)

- **Air movement — resolved:** one air action, air dash *or* double jump (moveset
  section). The *shapes* (dash distance/momentum, double-jump height, whether the
  dash crosses up) are the Architect's within the readable-crossup constraint.
- **The concentrated air/mixup interactions** (Architect specs, QA audits) — how
  the air-action budget, divekick, 2H-JC pressure, and projectile setplay combine
  (esp. whether an airdash can chain into the H-divekick overhead, and how fast the
  resulting overhead is). This is the spec's hardest legibility call; see the
  risk-concentration note above. Not resolvable in the brief.
- **Can the `CancelRule` format express B's strength-ladder** (Architect) — if
  "higher-strength OR crouching-of-same-strength + light self-chain" doesn't fit the
  existing model, flag it; a format extension here is P2's format-generality test
  paying off, not a failure.
- **Does B need a low-committal "get in" tool beyond air mobility + ground dash**
  (Architect surfaces if the approach game feels non-functional in practice) — I've
  deliberately kept the approach kit lean; if playtest/QA finds B *cannot* legibly
  approach a zoning A, that's a flag to me, not a silent addition.
- **Exact normal set, cancel routes, and every move property** (Architect) — all
  yours to spec within the identity and the hard legibility constraints above. The
  brief fixes roles and charter bars, not frames.
