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

**The content-seam claim — WITHDRAWN 2026-07-16, RE-PROVEN 2026-07-17.** This section
once read "the content-seam proof held … the P2 thesis, met." That was **premature and
was retracted**: it rested on B's kit being authored as data (true), no engine
primitive invented (true), and QA's grep finding zero character-specific branches
(true) — and was *still* wrong, because the first real A-vs-B hit had **never worked**.
Every cross-character hit left the defender boxless and permanently stuck (AD-049). A
structural grep can't see an **implicit** coupling — an identifier crossing a namespace
the format never declared — and every test before the gate matched a character
**against itself**, where the coupling silently holds. The claim was true of the
evidence; the evidence didn't test the claim.

**Now re-proven, behaviourally.** AD-049 landed (reactions are defender-side content, no
id crosses the boundary), and QA's re-audit (`audits/audit-p2-regate.md`, 2026-07-17)
verified `combat-resolution.md` criteria 15–18 the way they demand: `test_reaction_map.gd`
drives **real A-vs-B and B-vs-A contact, both directions, every inflicted reaction kind,
with deliberately disjoint id ranges** (A 100s–160s, B 300s+) so a namespace bug can't
coincidentally resolve — the exact thing a mirror matchup structurally cannot prove.
Both halves the criterion demands now hold: the behavioural asymmetric matchup **and** a
re-confirmed zero-character-branch grep. This is real evidence, not a proxy for it. **The
content seam is proven: B was content, not engineering — established by exercising the
thing, not by inferring it from structure.** (The lesson is kept in `audit-criterion.md`
→ "Exercise the thing, not a proxy for it," so the *next* such claim is tested the same
way rather than asserted from a grep.)

**Status after the SECOND gate cycle (2026-07-17) — awaiting a third user gate.**
The first re-gate (2026-07-16) found four defects (input lag, boxes-vanish-on-hit,
divekick-unperformable, HUD overlap); the second (2026-07-17) ran on their fixes and
found **ten items** — recorded in the checklist below and worked to resolution this
session:

- **All ten dispositioned.** The headline was a legibility defect, not a broken
  mechanic: knockdown/launch/air-reset all rendered as the word "hitstun" because they
  share `CATEGORY_HITSTUN`, so the gate-holder read a *working* mechanic as absent
  (`reaction_kind` now leads the readout, AD-049-derived). Genuinely broken and now
  fixed: air normals snapped to ground (criterion 15, never-covered), A carried
  air-actions it never authored (AD-046, now data-gated both ways), sudden death
  couldn't reach `MATCH_END` (criteria 1–8), the divekick landing mechanic (AD-050,
  new). Plus the readout/HUD/tuning fixes and the settled JC-095 numbers.
- **Ratified + re-audited.** JC-106..115 all ratified (three contract folds:
  `reaction_kind`, per-strength slides, projectile single-source guard). QA's re-audit
  passed all five fixes **behaviourally** — it verified each fails on the pre-fix commit
  via git worktrees, not by trusting the report.
- **Content seam re-proven** (above) — the milestone-load-bearing result.
- **One new defect surfaced by QA's deeper testing:** `6H`'s hitbox is authored too high
  to ever reach a crouching hurtbox, so crouch is a free dodge of B's dedicated
  overhead — it undermines B-4's high/low guess. A geometry fix (`flags.md`, owner
  Developer). This must land before the re-gate can honestly judge B's overhead.
- **Also found:** the golden-file net was stale *and* never wired into the runner
  (invisible drift the whole cycle) — QA re-baselined and wired it in; suite 47/47.
- **Deferred, non-blocking:** trace-harness misleading output, match-mode `R` reset
  binding, and the slide-knockdown dynamic-coverage gap (rides with the 6H fix). All
  in `flags.md`.

**The historical first-cycle detail below is kept for the record; the current truth is
the block above.**

**Remaining to close P2.**

1. ~~Architect ratification~~ — **DONE (2026-07-16).** JC-087..099 all ratified,
   none overturned, no flags; contract folds landed in AD-043/047/048,
   `move-format.md`, `character-b.md`, `match-flow.md`. All P2 calls (JC-068..099)
   are ratified and archived; both live ledgers are flat.
2. **QA objective audit — PASSED 2026-07-16 (`audits/audit-p2-feature.md`), but
   its cross-system-consistency finding is SUPERSEDED and must be re-run.**
   Determinism/serialization at the hard cases (mid-match, mid-divekick,
   mid-slide-active, mid-projectile-arc round-trips) stands. What does **not**
   stand: "cross-system consistency passes — an exhaustive grep of `game/sim/*.gd`
   finds zero character-specific branches — the content-seam proof, **verified
   structurally**." The grep was correct; the inference from it was not (see the
   withdrawal above). QA is not at fault for the method — **my** cross-cutting
   check asked for exactly that grep ("no character-specific branch"), so the
   structural reading was the one I invited. Re-run against
   `combat-resolution.md` 15–18 (behavioural, asymmetric, both directions) once
   AD-049 lands. Criterion sharpened in `audit-criterion.md` → "Exercise the
   thing, not a proxy for it."
   The **golden-file regression net was absent and is now seeded** (A movement, B
   frame-data + geometry, full-match hash trace); **43/43** headless green.
3. **The user's human-inspection gate — RUN 2026-07-16. NOT CLEARED.** QA's
   objective pass is necessary but *not* sufficient, and QA correctly declined to
   issue a done verdict while this stood. The user ran it and it **did not clear**
   — four defects, all open to the Developer in `flags.md`:
   - **~1s input lag on both characters** (play/pause unaffected). Tax, and it
     makes every readable-as-it-happens judgment on this gate unanswerable.
   - **Collision + hurtbox vanish when a character is hit**, until their next input.
     Correctness hole or overlay defect — diagnosis decides which.
   - **The divekick cannot be performed at all** — so B-3 (the three divekicks
     visually distinguishable) could not be judged. Likely downstream of the lag.
   - **HUD text overlaps** and is becoming hard to read; the match result must be
     legible on its face.

   **Judged, standing:** *reactability* and the **JC-095 provisional tuning** both
   take a **vacuous pass** — there is no art or audio yet, so there is nothing to
   read a tell off, and tuning judged against a placeholder presentation through a
   second of lag would be judgment we'd only have to redo. Both re-open at the
   re-gate. The user's one substantive tuning observation: **the slide's advantage
   does change live with spacing** (B-1's intent, holding).

   **Same-day disposition of the four (Developer + Architect, 2026-07-16):**
   - **Input lag — FIXED.** `MatchTickHost` queried input sources by
     `state.sim.tick`, which freezes during the non-`ACTIVE` `ROUND_START` beat
     while the driver keeps producing frames — a permanent 60-tick (exactly 1s)
     query offset once `ACTIVE` began. `P`/`N` were unaffected because they never
     touch the `InputSource` path, which is precisely what the user's own
     observation pointed at. Ratified to contract in `input.md` (JC-100).
   - **Divekick — FIXED, no separate defect.** Downstream of the lag exactly as
     suspected: B's jump lasts 50 ticks and the input echoed 60 ticks stale, so
     the airborne window closed before any air command could land.
   - **HUD overlap — FIXED.** `ControlsLegend` renders ~18 lines in a box sized
     for fewer, since it was first authored — not a TKT-P2-08 regression. Resized
     and the right column restacked; the user's gate-time workaround is superseded.
   - **Boxes vanish on hit — NOT a render defect. The severe reading was the true
     one**, and it opened AD-049 (above). Fix pending TKT-P2-09+10.

4. **Build AD-049 (TKT-P2-09+10) — OPEN.** Reactions become defender-side content:
   `HitBox.hit_reaction`/`block_reaction` carry a semantic `ReactionKind`, resolved
   through the defender's own required `reaction_map`. No id crosses the boundary.
   Also declares projectile `data_id` global and rejects duplicate installs — the
   one other live instance of the same class (A: 201–203, B: 220–222 were disjoint
   **by convention only**, and roster merge silently overwrote). Carries a known
   content hole: **B has no `AIR_RESET` state** — it inflicts none, but A's `2H`
   launches it. That is a **feel question on `briefs/character-b.md`, which is
   mine** — see below.
5. **QA re-audit — OPEN.** Cross-system consistency re-run behaviourally per item 2.
6. **The user's re-gate — OPEN**, against the checklist below, not a fresh
   improvisation.

**The through-line worth keeping.** Ids crossing an undeclared namespace is now the
**third** instance of one class (TKT-P1.1-01's `character_id 0`/`state_id 0` defaults;
JC-099's round-start idle, which "only looked correct because the P0 test character's
idle happens to be id `0`"; now reactions). The Architect's response was to write the
**character-namespace rule** as a stated invariant rather than fix the instance —
which is the right altitude, and the reason I'm recording it here too: three
same-shaped bugs is a design signal, not bad luck.

### P2 human-gate checklist (Strategist-attached, per `audit-criterion.md`)

The 2026-07-16 run exposed a defect in **my** artifact, recorded here rather than
quietly fixed: `audit-criterion.md` requires the Strategist to attach a checklist
**derived from the owning brief's enumerated surface** when declaring a gate. What I
declared above ("What the gate must judge") was a 3-item summary, thinner than the
briefs it was supposed to enumerate; QA correctly declined to author the list in its
place, and the user ran the gate off QA's enumeration of unclosed items instead. That
is the P1.1 completeness-gap lesson recurring in the exact place the rule was written
to prevent it. The checklist below is derived from `spec/character-b.md` (1–6,
B-1..B-6) and `spec/match-flow.md` (1–8) and is the standing list for the re-gate; the
Architect's ticket "Cross-cutting" section is its other source.

**Operability floor (new — the 07-16 run says this must be checked first).** Every
item below assumes a human hand can reach the move. Before judging any legibility
question: inputs register without perceptible lag, and every one of B's moves named
below can actually be executed. A gate cannot judge readability through an input path
that doesn't work — that is what happened this run, and it is why the list starts
here rather than assuming it.

1. **Every B move is executable by hand** — the 6 normals and the gatling ladder,
   `5H`, `6H`, `2H`, the throw, all **three divekicks**, the slide, all three
   projectile strengths, the airdash, the double jump, `2H`-JC→airdash.
2. **The `6H` overhead reads as an overhead** as it happens (B-4's reaction-window
   floor: placeholder 12 ticks vs. measured 17 — settles here).
3. **The H-divekick reads as an overhead**, and the other two read as *not* overheads.
4. **The three divekicks are visually distinguishable** in pose, not just trajectory
   (B-3; the trajectory/timing half is headlessly proven).
5. **The airdash crossup side is readable** (B-5).
6. **The slide's advantage is visible on the instrument** — not merely computed
   correctly — and tracks spacing (B-1). *Confirmed live on the 07-16 run.*
7. **No unblockable off the projectile oki** as a human perceives it (B-2).
8. **A's `2L`/`2M` enforce LOW and B's high/low mixup is answerable** by blocking,
   not by knowing (AD-045; the no-knowledge-checks line).
9. **The match result is legible on its face** — KO, TIMEOUT, and DOUBLE_KO each
   read at a glance, without hunting through overlapping text.
10. **Round/match flow reads** — best-of-3 scoring, the timer, sudden death.
11. **The JC-095 tuning bundle settles** — divekick hang/dive profiles, projectile
    parabolas, slide numbers, the B-4 floor. Keep or retune (spec says it settles
    here; not a defect to audit).

Items 2–5 and 11 are **presentation-limited until there is art or audio** and take a
vacuous pass while that holds — recorded so we don't mistake a vacuous pass for a
judged one when the slice's presentation phase lands.

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
