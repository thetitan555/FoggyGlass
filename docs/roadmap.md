# Roadmap — to the Vertical Slice

> Owned by the **Strategist**. The sequence of what gets built and why, anchored
> to the vertical slice. Later (post-slice) work is gestured at, not specified.
> This is direction, not a spec — the Architect turns each phase into briefs →
> spec → tickets. Revise it when reality demands; it's a plan, not a contract.

## What the slice is for

The slice exists to **prove the architecture, not to be the game.** It is "done"
when it demonstrates — runnably — that the three tenets hold and that the systems
they enable (replays, netcode, CPU, scripted tutorials) are *new input sources,
not new systems*. Everything below is sequenced to reach that proof on the
shortest honest path.

Fixed scope (from the constraints, not negotiable here): a playable 1v1 match, a
debug/technical training mode, a two-player tutorial, and — settled this session
— **two lean characters**. Two because one can't prove the data-driven move
format or exercise the systems/content seam, and a real matchup is the only place
"every option is readable as it happens" becomes testable.

Explicitly **not** in the slice: online/netcode (kept *possible* by determinism,
not built), roster breadth beyond two, and presentation polish. Building any of
these now is scope the slice doesn't need — flag it if it creeps in.

## The spine (why the order is the order)

Each phase depends on the one before it through a real interface, so the order
isn't preference — it's the dependency graph:

```
P0 backbone ─▶ P1 char A + debug training ─▶ P1.1 finish the instrument ─▶ P2 char B + 1v1 match ─▶ P3 2P tutorial ─▶ P4 harden
```

The load-bearing sequencing fact: the debug training mode and the 2P tutorial
both straddle the **systems/content seam** (systems exposes an inspection API and
a scripted-input mechanism; the player-facing side builds on it). At the seam,
the player-facing half is downstream of the simulation-facing interface — so
those interfaces, even as stubs, come first. The determinism harness comes online
*with* the sim loop, not after, because determinism violations are far cheaper to
catch as the sim is written than to chase later.

## Definition of done includes a human-inspection gate

From P1.1 on, any milestone with an **experiential surface** — something a human
must see or operate to confirm (rendering, input-operability, on-screen
legibility) — is not "done" on QA's headless audit alone; the user's
play/overlay-look gate clears it last. Mechanics live in `protocol.md`, what
qualifies in `audit-criterion.md`. **P0** was exempt (pure architecture, nothing
to look at). **P1, P1.1, P2, P3** all carry the gate; **P4** is where the charter
audit itself is the human sign-off. Recorded here because P1 was taken as done
without it — the gap P1.1 now closes.

## P0 — Architecture backbone

The spine everything hangs on. No content, no feature — just the proof surface.

Built here: the input-source interface and per-frame input type (Tenet 2); the
deterministic sim loop on a fixed timestep with fully serializable state
(Tenet 1); the move/state-machine pattern and the **data-driven, serializable
move/frame-data format**; and core frame resolution — hit/hurtbox overlap,
hitstop, hit/block-stun, advantage — exposed through a **read-only inspection
surface** into sim state, so the debug mode can read it out. QA stands up the
determinism + serialization harness against the loop as it lands.

**Done when:** the sim advances purely from `(state, inputs)`; state round-trips
(serialize → restore → resume identically); the determinism harness is green; and
a trivial test "character" defined entirely in move data resolves a hit with
correct advantage, read back through the inspection surface. *This is the tenet
proof — the rest is building on proven ground.*

## P1 — First character + debug/technical training mode

The first real content and the first feature, together — because the debug mode
is the team's **instrumentation**, and it needs something to observe. This is the
first feature brief (drafted next).

Built here: character A — a thin but combo-capable moveset (movement, a small set
of normals, one or two specials, a throw — enough for neutral, a real combo, and
oki), authored as move data against the P0 format. And the debug/technical
training mode reading the inspection surface: frame data, hitbox/hurtbox display,
advantage on block/hit, hitstop, state — the charter's "find out what happened
and why" made literal. Record/playback dummy is an input source writing and
replaying a buffer (Tenet 2), not a special case.

**Done when:** character A is playable against a dummy; the training mode shows,
live and correctly, what the sim is doing each frame; the record/playback dummy
round-trips a buffer. *The instrumentation the whole team uses now exists.*
*(Not actually met at first sign-off: the human review of 2026-07-08 found the
mode inoperable and its geometry overlay blank. P1.1 closes that — P1 is not
truly done until P1.1 clears.)*

## P1.1 — Finish the P1 instrument (make it operable and visible)

Not new scope — **completing P1 against its own brief.** The first human run of
the training mode (2026-07-08) surfaced two gaps that all 24 headless tests pass
straight through: nothing in the mode is **operable by a human** (pause /
frame-step / reset / record-playback exist only as methods, bound to no key or
button), and the **geometry overlay renders no boxes** — the charter's centerpiece
surface, blank. Both are already open flags (`flags.md`, 2026-07-08).

Why it precedes P2: the training mode is the team's instrument — the surface we
author, verify, and audit *through*. Building char B and the 1v1 matchup on an
instrument that can't be operated or seen through would author a second character
we equally can't inspect, and try to verify the matchup's legibility — the
charter's whole point — on a surface that shows nothing. Pay the debt before
stacking on it.

The debug-training brief (`briefs/debug-training-mode.md`) already lists frame
control and situation reset as **required outcomes** and describes a human
pressing them, so operability is not new intent. The one open scope question is
the Architect's: was an input-bound control surface in P1's scope (a gap to close
now) or deliberately deferred (driving UI later)? That flag is open to them; if
they rule it deferred, the driving UI's roadmap placement routes back to me.

**Done when:** the training mode is operable by a human — pause, frame-step,
reset, and record/playback all invokable from an actual control — and the geometry
overlay draws both characters' boxes on screen; the two flags are resolved; and
the **human-inspection gate clears** (the user confirms it live). Only then is P1
actually done.

**Status (2026-07-08):** the instrument work landed and passed QA's objective audit
(`audits/audit-p1.1-instrument.md`), but the human re-gate — run twice — found that
**character A itself is materially incomplete against its brief** (walk won't stop,
no crouch stance, no forward/back or diagonal jumps) and the **geometry overlay
renders boxes Y-inverted**. P1.1's scope therefore absorbs a **character-A movement
reconciliation + geometry Y-fix** before it can be done — documented as a
pickup-ready work-order in `briefs/character-a-movement-reconciliation.md` and
**deferred to a fresh session**. Why the pipeline passed A as done while unplayable:
`pipeline-analysis-completeness-gap.md`. The two feel calls (frame-step auto-pause,
jump apex-hang) remain parked per the user.

**Folded into the reconciliation (user, 2026-07-09):** a **minimal scripted-input
behavioral-trace harness** — author an input string, replay it headless through the
existing `RecordPlaybackSource` (Tenet 2), dump a per-tick `InspectionView` state
trace, assert against expected. It mechanizes the *sim-behavior* half of the human
gate (the completeness-gap's element 1) and becomes the reconciliation's own
verification instrument; it stays **blind to render bugs**, so the human gate still
clears visual concerns. Designed **build-for-extension** (Tenet 3), not test-only:
the same replay-a-shareable-input-string mechanism is a player pasting a setup to
practice against, and is **P3's scripted-input source arriving early**. Not a full
TAS framework now. Details in the work-order's "Companion capability" section.

**DONE (2026-07-11) — P1.1 and, with it, P1 are complete.** Full arc in
`flags-archive.md` (reconciliation flag) and
`briefs/character-a-movement-reconciliation.md`; delivered work is folded into
AD-037–042 (trace harness, geometry Y-fix, held-input stances, airborne actions,
dummy-control puppeting, landing snap). Character A is playable and correct against
its brief; the training mode is operable and legible; all judgment calls ratified;
QA audits green; the user's 5th re-gate cleared it. **Two items deferred to P2:**
(1) an air normal stops the jump arc and snaps to the floor — full fall-momentum
air-move semantics fold into P2's AD-036 unit; (2) the grounded **dash** (open
question below).

## P2 — Second character + playable 1v1 match

Proves the format generalizes and gives us a real matchup and a real game loop.

> **Pre-P2 prerequisite (surfaced by P1.1, AD-036) — REDUCED, P1.1 already did the
> landing half.** P2 opens with the remainder of the ground-contact hardening unit,
> **before** char B or any air-movement content. P1.1 landed **AD-042** — the *landing
> snap* half (snap `pos_y → ground_y` on grounded-state entry), which fixed the held-jump
> drift and made the character land. What **remains for P2's AD-036 opener:** (a) the
> full runtime `pos_y ≥ ground_y` clamp (continuous, not just on grounded-entry); (b)
> **variable-height air-move / fall-momentum semantics** — the P1.1 re-gate found an air
> normal stops the jump arc and the character snaps to the floor; carrying fall momentum
> through an air normal and easing the descent is exactly this deferred half; (c)
> knockdown-into-ground semantics. Designed together (a bare clamp alone would mask a
> mis-authored arc — anti-legibility), and load-bearing for a second character + the
> matchup, so it lands first, not as a late P4 pass. The Architect specs the AD-036
> remainder into P2's opening tickets. *(Strategist sequencing call; revisable.)*

Built here: character B, a second lean moveset deliberately distinct from A,
authored purely in move data — the test that the format wasn't secretly
A-shaped. And the 1v1 match flow wrapping the sim: health, KO, round/match
state, win condition — the match layer, not new combat.

**Done when:** A vs B is playable start to finish under the deterministic sim;
both characters obey one move format and one advantage computation (QA verifies
cross-system consistency); the golden-file frame-data/hitbox regression net is
seeded now that there are stable characters to snapshot. *The content seam is
proven: a second character was content, not engineering.*

**Status (2026-07-16) — BUILD COMPLETE; awaiting ratification → QA audit → the
user's gate.** All P2 tickets are landed, committed, and pushed:

- **01** airborne physics (AD-043, supersedes AD-036) — gravity, persistent
  velocity, fused ground-clamp/landing, launch-into-knockdown; A's jump migrated
  off its hand-baked arc and goldens re-baselined.
- **02** double-tap dash + the one-air-action economy (AD-046); A's `66`/`44`
  wired to its existing dash states (confirmed marginal, as briefed).
- **03+04** combat capabilities — AD-044 cancel groups, AD-045 directional
  block enforcement (A's `2L`/`2M` now enforced LOW), AD-047 arc gravity.
- **05** character B ground content — 6 chainable normals, the gatling
  strength-ladder, `6H` overhead, `2H` JC-launcher, throw.
- **06** character B air toolkit + specials — three divekicks (H the sole
  overhead), the low slide into knockdown-oki, the three-parabola arc
  projectile, air normals that carry the fall, `2H`-JC→airdash pressure.
- **07** match layer — `MatchState`/`match_step`/`MatchView`, best-of-3,
  frame-counted timer, timeout/KO/double-KO/sudden-death.
- **08** integrate + health tuning (`FULL_HEALTH = 500`) + training-mode
  readouts for the new legibility truth.
- Plus two engine corrections surfaced by the build and specced by the
  ratification pass: the **dedicated knockdown state** (JC-070 overturned) and
  the **AD-044 exact-self-repeat `CancelEval` fix**.

**The content-seam proof held.** B's entire kit was authored as **data** over the
existing engine; the only code touched was adding one motion token (`214`) to the
*already-generic* recognizer table (JC-090). No engine primitive was invented and
no format-generality flag was raised — the P2 thesis, met. Suite: **42/42**
headless green, determinism/round-trip included.

**Remaining to close P2:**

1. **Architect ratification** of JC-087..099 (the last provisional calls).
2. **QA objective audit** against acceptance criteria, the tenets
   (determinism/serialization across a full match), and the audit criterion, plus
   a judgment-log drift read. QA also **seeds the golden-file regression net** and
   verifies **cross-system consistency** (one move format, one advantage
   computation across A and B) — both are P2 done-conditions.
3. **The user's human-inspection gate** — the stopping point. QA's objective pass
   is necessary but *not* sufficient; only the user closes this.

**How to run the gate:** open the project in Godot 4.3 and run
`game/scenes/training_mode.tscn` (F6) — it boots the real A-vs-B match. P1
(character A) = arrows + `J`/`K`/`L`; P2 (character B) = WASD + `U`/`I`/`O`, both
directly controllable. `P` pause / `N` frame-step work; `C`/`R` are documented
no-ops in match mode (JC-098).

**What the gate must judge:** (a) B's mixups readable *as they happen* — the
`6H`/H-divekick overhead tells, the airdash crossup side, the slide's advantage on
the instrument, no unblockable off projectile oki (the no-knowledge-checks line);
(b) the match result legible on its face (KO / TIMEOUT / DOUBLE_KO); (c) the
**JC-095 provisional tuning** — divekick hang/dive profiles, projectile parabolas,
slide numbers, and the **B-4 reaction-window floor (placeholder 12 ticks)** — keep
or retune.

## P3 — Two-player tutorial

The second seam-straddling feature: a scripted-input source plus authored
content.

Built here: a scripted-input source (another implementation of the one input
interface — Tenet 2 again) and the authored tutorial sequence on top of it. Keeps
the charter's "no knowledge checks" honest by teaching in-the-moment legibility
rather than memorized answers.

**Done when:** the tutorial plays a scripted sequence deterministically through
the normal input path, with two players, teaching the systems the slice has.
*Scripted tutorials are proven to be input sources, not bespoke systems.*

## P4 — Harden and audit the slice

Not new features — the proof, made durable.

QA runs the first full **drift sweep** (cumulative behavior vs charter,
spec vs implementation) and the charter audit against the audit criterion; the
golden-file and determinism nets are confirmed as the standing safety net;
recorded judgment calls are ratified into the spec.

**Done when:** the slice passes the audit criterion, the regression/determinism
nets are green and trusted, and no judgment call sits unresolved. *The slice is
not just runnable but defensible — and the architecture is proven extensible.*

## Open questions (resolve before the phase that needs them)

- **Character A archetype** — *resolved:* a grounded, simplified shoto, briefed
  in `/docs/briefs/character-a.md`. **Character B archetype** — *resolved
  2026-07-14:* a strings-and-air-mobility pressure character (gatling normals, air
  mobility, mixups, an arcing setplay projectile, no invincible reversal), briefed
  in `/docs/briefs/character-b.md`. Chosen to contrast A along every axis so the move
  format proves general and the matchup is legibly asymmetric. Exact moveset is the
  Architect's to spec.
- **Character A grounded dash** — *resolved 2026-07-14: folded into P2 (yes).* The
  double-tap recognizer is built for character B's movement regardless, so wiring
  A's already-authored-but-unreachable dash states (`66`/`44`) to it completes A's
  intended kit at near-marginal cost. Recorded in `/docs/briefs/character-b.md`
  ("Scope notes"); the Architect confirms the actual cost and flags back if it's
  materially more than wiring existing states to the shared recognizer.
- **Match rules** — *resolved 2026-07-14:* briefed in `/docs/briefs/match-flow.md`
  (best-of-3, ~99-tick frame-counted timer, higher-health-on-timeout, Architect
  tunes health vs damage). One sub-question left open to the user in that brief:
  the tie-at-match-point rule (sudden-death vs no-score replay).
- **What the training mode must expose, exactly** — the P1 brief pins this; it's
  the operational form of the charter's legibility promise, so it's worth getting
  right there.

## After the slice (sketch only — not committed)

Beyond the slice, in rough order and explicitly not planned in detail yet: more
characters (now cheap, if the format held), netcode built on the determinism the
slice preserved, CPU opponents as another input source, and presentation polish.
The slice's whole job is to make these *additions* rather than *rewrites*.
