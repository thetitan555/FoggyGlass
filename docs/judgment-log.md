# Judgment-Call Log

> **Live file = provisional (unratified) bodies only.** Every entry is a
> *latitude* call — how to build something the spec already decided *what* it is;
> anything touching a contract, feel, or tenet is a flag (`flags.md`), not an entry
> here. The Developer appends; the Architect ratifies/overturns each before that
> feature's audit.
>
> **Closed entries** (ratified · overturned · superseded) live verbatim in
> `judgment-log-archive.md`, each headed `### JC-NNN` — Grep it by id or keyword,
> never read it whole (`grep "^### JC" …` reconstructs the full log-order list on
> demand). Next id = the highest `### JC-NNN` in the archive, +1.
>
> **Maintenance split:** Developer appends a provisional body below; Architect
> flips its status in place on ruling; Strategist sweeps closed bodies to the
> archive on the per-session ledger sweep. Format/rationale: `protocol.md`.

---

## Provisional (awaiting ratification)

### JC-087 · 2026-07-15 · AD-043 elaboration (JC-070 ratified) · Character A's `STATE_THROWN` renamed/reused as `STATE_KNOCKDOWN`, not a second authored state — **ratified** (2026-07-16; latitude, in place — one state realizing AD-043's convergence is the reading intended; no dead duplicate content)
**Decision.** Implementing `knockdown_state_id`, character A needed SOME `state_id` to point
it at. Rather than authoring a brand-new, near-duplicate grounded-HITSTUN state alongside the
existing `STATE_THROWN` (id 123; duration 30; `CATEGORY_HITSTUN`; standing hurtbox) — which
was already exactly "a grounded, non-actionable hard-knockdown reaction with a fixed wakeup
duration," just throw-specific by name — I renamed it in place to `STATE_KNOCKDOWN` (same id,
same duration/category/hurtbox) and pointed BOTH the throw's `hit_reaction` (direct, grounded
hard-KD) and `Character.knockdown_state_id` (the launched-landing target) at it. This is the
literal convergence AD-043's elaboration asks for ("ground-KD and launch-into-KD converge on
one learnable wakeup") realized as ONE state rather than two states that happen to behave
identically.
**Alternatives considered.** Authoring a genuinely NEW `STATE_KNOCKDOWN` (a fresh id) and
leaving `STATE_THROWN` in place, unused — rejected: it would leave dead, unreferenced content
in the character definition (nothing sets `hit_reaction`/`knockdown_state_id` to it anymore),
and two states with byte-identical authoring is exactly the kind of drift-prone duplication the
format's "one authored definition" discipline (move-format.md criterion 1 in spirit) argues
against. Renaming costs nothing structurally (the id is internal, resolved through
`Character.get_state`) and required updating the handful of tests that named
`CharacterA.STATE_THROWN` directly (`test_character_a.gd`, `test_invuln.gd`) to
`CharacterA.STATE_KNOCKDOWN` — mechanical, no behavior change to those tests.
**Scope.** `character_a.gd` (constant rename + `Character.knockdown_state_id` assignment +
throw's `hit_reaction`/`block_reaction`); `test_character_a.gd` / `test_invuln.gd` (reference
updates only). `data/character-a.tres` re-baked from the builder (`tools/bake_character_a.gd`)
so the shipped artifact reflects the rename — no drift between authored source and baked file.
No `SimState`/`PlayerState` shape change (AD-034): `knockdown_state_id` is `Character` content,
resolved through `MoveRegistry` exactly like `idle_state_id`, not serialized runtime state — no
`FORMAT_VERSION` bump. Log for ratification.

### JC-088 · 2026-07-15 · AD-043 elaboration (JC-070 ratified) · `_land`'s knockdown transition re-arms `p.stun` to the knockdown state's own `duration`; the natural same-tick decrement is accepted, not specially frozen — **ratified, folded into AD-043** (2026-07-16; the re-arm is contract — a bare state transition does not deliver "counts from landing" — and the `duration − 1` readout is now a pinned intended semantic, not an off-by-one)
**Decision.** The AD's contract ("fixed wakeup `duration` counted from entry/landing,
independent of air-time") is NOT satisfied merely by transitioning `state_id` on landing:
`p.stun` — the actual engine countdown that gates the "become actionable" transition
(`step_phases.gd` phase 2, `p.stun == 0`) — is set ONCE, at the original hit (phase 5), and
decrements every unfrozen tick (phase 7) regardless of any later `state_id` change; a bare
state transition would leave wakeup governed by whatever stun happened to remain after the
flight, which is exactly the air-time-dependent behavior AD-043 exists to eliminate. So
`StepPhases._land`'s knockdown branch explicitly re-arms `p.stun = knockdown_move.duration` (and
`stun_kind = STUN_HIT`) on the landing tick itself, making the wakeup countdown restart fresh at
that instant. One accepted consequence, verified by headless replay rather than assumed: unlike
an ordinary hit-connect (which ALSO sets `hitstop` the same tick, freezing `stun` via phase 7's
`was_frozen` gate until hitstop elapses — AD-010), this transition sets no hitstop, so phase 7's
plain decrement runs on the SAME tick `p.stun` is re-armed — the value observed immediately after
the landing tick's full `step()` is `duration - 1`, not `duration`. The wakeup still lands exactly
`duration` ticks after (and including) the landing tick, so time-to-wakeup-from-landing is fixed
regardless of air-time — the actual contract — this is a one-tick bookkeeping artifact of reusing
the existing phase-7 decrement path, not a shortfall of the contract itself.
**Alternatives considered.** Adding a hitstop-style "was just re-armed this tick" freeze flag so
`p.stun` reads exactly `duration` immediately after landing (parity with the hit-connect case) —
rejected as unnecessary complexity (a new per-player flag plus a phase-7 branch) to fix a
one-tick cosmetic difference nothing observable actually depends on (the wakeup TICK is identical
either way; only the intermediate `stun` READOUT differs by one for a single frame). Leaving
`p.stun` untouched on the landing transition (JC-070's original, since-overturned reading in
spirit) — rejected outright: this is precisely the air-time-dependent wakeup AD-043's elaboration
was written to eliminate.
**Scope.** `step_phases.gd`'s `_land` only (the `elif character.knockdown_state_id != 0` branch);
test-covered by a new regression, `test_airborne_physics.gd`'s
`_test_knockdown_wakeup_counts_from_landing_not_from_the_original_hit`, which asserts the
empirically-verified `duration - 1` readout and that it derives from `knockdown_move.duration`,
not from whatever remained of the original hit's stun. Log for ratification.

### JC-089 · 2026-07-15 · AD-043 elaboration (JC-070 ratified) · `STATE_KNOCKDOWN` keeps the standing hurtbox inherited from `STATE_THROWN`; no distinct downed-hurtbox geometry authored — **ratified; deferral confirmed** (2026-07-16; AD-043 says "may," not "must" — this is optional content the mechanism already supports adding as a pure data edit)
**Decision.** AD-043's elaboration says the knockdown state "MAY author a downed hurtbox
distinct from the airborne launch hurtbox" — permissive, not required. `STATE_KNOCKDOWN`
(renamed from `STATE_THROWN`, JC-087) keeps its existing `_hurt_stand()` geometry unchanged;
no new lying-down hurtbox shape was authored. This is genuinely optional content-authoring
scope (box geometry is exactly the kind of thing `character-a.gd`'s own header note calls
"slice-provisional tuning"), not a contract gap — the engine mechanism (a real, distinct
`state_id` with its own resolvable hurtbox list) already supports adding one later with zero
structural change, only a data edit.
**Alternatives considered.** Authoring a genuinely shorter/prone hurtbox now — passed over as
unnecessary scope beyond what these two fixes need (neither fix's acceptance bar mentions
hurtbox shape) and easy to add later without touching any of the logic these two fixes changed.
**Scope.** None (no code change) — recorded so the deferral is visible rather than silently
assumed. Log for ratification (or explicit deferral confirmation).

### JC-090 · 2026-07-15 · TKT-P2-06 (character-b.md Arc projectile, AD-047) · `InputBuffer.MOTION_214` + `DIR_DOWN_BACK` added to the existing motion-token table — **ratified, clarification folded into `move-format.md`** (2026-07-16; latitude confirmed — the motion set is open and data-populated, so adding a motion the spec names populates the existing recognizer rather than extending the format. The `ButtonMapEntry.motion` row now pins that, and pins the line: a new *recognition shape* would be a format matter, a new motion id is not)
**Decision.** B's arc projectile is specced as `214L/M/H` (a reverse quarter-circle). The one
motion recognizer (`InputBuffer.motion_recognized`) already generalizes over a
motion-id -> ordered-token-sequence table (`_motion_tokens`), populated so far with `MOTION_236`
and `MOTION_623` (JC-022's own characterization: "the scan and token table are implementation").
Rather than inventing a second recognizer or hand-rolling a bespoke "back-quarter-circle" check,
I added `MOTION_214` as a THIRD entry in that same table (`[DIR_DOWN, DIR_DOWN_BACK, DIR_BACK]`),
and — since no down-back token existed yet (only `DIR_DOWN_FORWARD`) — added the symmetric
`DIR_DOWN_BACK` token (`down AND back`) alongside it in `_frame_satisfies`. This is the ticket's
own framing exactly: "no new engine primitive... all over 01-04" — the motion-recognition
PRIMITIVE already exists; this populates it with one more data point, structurally identical to
the two already there.
**Alternatives considered.** A bespoke one-off check outside `InputBuffer` (e.g. a
character-B-local helper scanning `input_history` for the 214 pattern) — rejected: it would
duplicate the exact scan `motion_recognized` already performs, violate "one recognizer" (Tenet 2
in spirit — every input consumer should read buffering identically), and be exactly the kind of
character-specific engine-adjacent code the ticket's "no new engine primitive" line forbids in
spirit even if not in the letter. Not adding it and instead giving B a plain-button special
(dropping the spec's own `214` framing) — rejected: the spec's contract names the motion
explicitly, and the existing table is designed for exactly this kind of extension (Tenet 3).
**Scope.** `game/sim/input_buffer.gd` only (`MOTION_214`, `DIR_DOWN_BACK` constants;
`_motion_tokens`/`_frame_satisfies` match arms). No `SimState`/`PlayerState` shape change, no new
recognition SHAPE (still the same ordered-token-sequence scan `motion_recognized` already runs) —
determinism/round-trip untouched. Character A is unaffected (never references `MOTION_214`). Log
for ratification.

### JC-091 · 2026-07-15 · TKT-P2-06 (AD-043 elaboration, JC-070 ratified) · Character B's `STATE_THROWN` renamed/reused as `STATE_KNOCKDOWN`; throw + the new low slide both route directly into it — **ratified** (2026-07-16; latitude — applying an already-ratified AD to owned content, mirroring JC-087. All three of B's hard-KD sources converging on one authored 28-tick wakeup is exactly AD-043's "one learnable wakeup")
**Decision.** TKT-P2-05 (B's ground content) landed BEFORE JC-070's overturn was ratified
(2026-07-15), so B's throw still routed its hard knockdown to a standalone `STATE_THROWN`, and
`Character.knockdown_state_id` was never set for B at all. This ticket's own scope item (the low
slide's "hard knockdown routing into the shared knockdown state via `hit_reaction`") cannot be
built correctly without that field existing on B in the first place, so closing this gap is
necessary work for THIS ticket, not scope creep. Mirroring character A's own identical fix
(JC-087): renamed `STATE_THROWN` (id 324, unchanged) to `STATE_KNOCKDOWN`, set
`c.knockdown_state_id = STATE_KNOCKDOWN`, pointed the throw's `hit_reaction`/`block_reaction` at
it directly, and left 2H's launch (`STATE_HITSTUN_LAUNCH`) untouched — its landing now
automatically redirects to `STATE_KNOCKDOWN` via the already-built engine mechanism
(`StepPhases._land`) the instant `knockdown_state_id` is nonzero, no further authoring needed. All
three hard-knockdown sources (throw, slide, 2H-launch-landing) now share ONE authored wakeup
number (28 ticks — the slide's `hb.hitstun` is deliberately set to the SAME value as
`THROW_HITSTUN`, not merely the same mechanism), which is the literal point AD-043's elaboration
makes ("one learnable wakeup... a per-source guess" is what this avoids).
**Alternatives considered.** Leaving B's throw on its own separate `STATE_THROWN` wakeup and
giving ONLY the new slide a fresh, second `knockdown_state_id`-style state — rejected: two
grounded hard-KD reactions with different (or coincidentally-equal-but-separately-tracked) wakeup
numbers is exactly the "per-source guess" AD-043 exists to eliminate, and would leave B
permanently inconsistent with the ratified contract character A already satisfies. Filing this as
a flag instead of just fixing it — considered, but this is squarely "apply an already-ratified
Architect decision to content I own," not a new design call or a contract dispute; nothing here
invents or reinterprets AD-043, it completes B's catch-up to it.
**Scope.** `character_b.gd` (constant rename, `knockdown_state_id` assignment, throw's
`hit_reaction`/`block_reaction`, the new `STATE_KNOCKDOWN` reaction builder); `test_character_b.gd`
(mechanical `STATE_THROWN` -> `STATE_KNOCKDOWN` reference updates, no behavior change to those
tests — all still pass unmodified in substance); `data/character-b.tres` re-baked. No
`SimState`/`PlayerState` shape change (AD-034) — `knockdown_state_id` is `Character` content, not
serialized runtime state. Log for ratification.

### JC-092 · 2026-07-15 · TKT-P2-06 (character-b.md Specials -> Low slide) · The low slide is ONE canonical move reachable via all of `236L/M/H`, not three distinct strength variants — **ratified, pinned in `character-b.md`** (2026-07-16; the reading is correct and confirmed against the spec — the slide subsection describes one behavior with no per-strength detail, unlike the divekick/projectile sections that explicitly enumerate three. Three slides would be a contract addition; the spec now says so in place)
**Decision.** character-b.md's Specials section headers the slide `` `236L/M/H` or a command —
provisional input `` and then describes exactly ONE move's behavior (LOW guard, hard knockdown,
spacing-variable block advantage, "B's most desirable combo ender") — no per-strength
differentiation is named anywhere in that subsection, unlike the divekick and the arc projectile,
which EXPLICITLY enumerate three behaviorally distinct versions each. Read literally, `236L/M/H`
describes three INPUT ways to reach the SAME move (mirroring, e.g., a single special reachable off
any button in some genre conventions), not three moves. Authored `STATE_SLIDE` as one state, with
all three motion+button `button_map` entries (`236`+L, `236`+M, `236`+H) targeting it.
**Alternatives considered.** Three genuinely distinct slides (e.g. varying range/speed per
strength, mirroring the divekick/projectile's explicit three-version pattern) — passed over: the
spec's own text gives no differentiating detail to author against for the slide specifically (no
"L is shorter, H is longer" language the way the divekick/projectile sections have), so
inventing three distinct behaviors would be filling a gap with NEW design rather than a defensible
reading of what's already there — exactly the line between latitude and invention this project
draws. If the Architect intends three distinct slides, that is a contract addition (specific
per-strength values), not an implementation detail — flag-worthy if so, not assumed here.
**Scope.** `character_b.gd` only (`_build_slide`, three `button_map` entries). No engine change.
B-1's acceptance (spacing-variable, instrument-readable advantage) is fully satisfied by the one
canonical move (see the "several active frames" mechanism, character-b.md's own text). Log for
ratification.

### JC-093 · 2026-07-15 · TKT-P2-06 (character-b.md Arc projectile; AD-047/B-2) · All three arc-projectile strengths authored `guard_height = GUARD_MID`; L designated the "falls-in-front" oki version — **ratified, folded into AD-047 + `character-b.md`** (2026-07-16; **confirmed: this satisfies B-2** — MID blockable-either-stance plus B's no-untechable-throw closes both halves of the invariant structurally. Promoted from an authoring choice to a stated invariant with a standing condition, since a future non-MID arc projectile or an untechable throw would silently reopen B-2. L-as-oki pinned in the spec)
**Decision.** AD-047/B-2 require that the falls-in-front oki setup never force a defender into
incompatible simultaneous defense (opposite `guard_height`, or block-vs-untechable-throw). Rather
than carefully timing the projectile's active window to never OVERLAP a same-tick opposite-guard
B strike (a fragile, re-litigated-per-patch invariant), I authored the projectile's OWN
`guard_height` as `GUARD_MID` for all three strengths — a MID hit is blockable from EITHER stance
(already true and tested, `test_guard_height.gd`'s `_test_mid_blocked_either_stance`), so the
projectile can NEVER be the "opposite" half of an opposite-guard conflict with ANY simultaneous B
strike, regardless of what that strike's own `guard_height` is. This satisfies the invariant BY
CONSTRUCTION — a structural proof, not a timing argument — while the real high/low or strike/throw
guess is still carried entirely by B's own strike/throw layer (a single, readable axis), exactly
matching the brief's "readable mixup, never an unblockable." Separately: character-b.md does not
name which of the three strengths is the "falls right in front" oki version, so I designated L
(authored with the shortest travel of the three, confirmed via headless replay to land closest to
B) as that version — the genre-conventional reading (L = quick/close, H = long-reach zoning).
**Alternatives considered.** Authoring the projectile with a "real" `guard_height` (HIGH or LOW)
and proving no-overlap by careful frame-window analysis against every B strike — rejected as
fragile (a future strike addition could silently reopen the very unblockable AD-047 forbids,
with no structural guard against it) and unnecessarily hard to verify exhaustively; the MID
reading is both simpler and provably robust to future content. Deferring the "which strength is
the oki version" question to the Architect as a flag — considered, but this is squarely an
implementation-detail gap-fill (the brief's intent — SOME version falls close for oki — is clear;
which letter it's named is not a contract question) and cheaply reversible (swapping which
strength's numbers designate "closest" is a one-line change).
**Scope.** `character_b.gd` (`_build_arc_projectile`/`_arc_projectile_data`, all three strengths).
Verified: `test_character_b_air.gd`'s `_test_arc_projectiles_are_guard_mid_by_construction`,
`_test_arc_l_falls_closest_to_b_the_oki_version`, `_test_arc_and_strike_never_require_incompatible_defense`
(the last a dynamic same-held-stance proof: a live projectile hit and a genuine 2L both resolve as
BLOCKED against one continuously-held crouch-block, no stance switch). Log for ratification.

### JC-094 · 2026-07-15 · TKT-P2-06 (character-b.md Divekick) · Divekicks land like an ordinary jump/air-normal (continuous ground clamp -> idle); no bespoke landing-recovery state authored — **ratified; deferral confirmed + routed** (2026-07-16; correct call — a landing-redirect hook is a format/AD change, not a content session's to invent. `character-b.md` now records the absence as a deliberate deferral and carries it as a live human-gate open item, since a divekick with no landing recovery is a strong, low-risk approach)
**Decision.** `StepPhases._land` unconditionally transitions an `AIRBORNE`-category move's landing
to `character.idle_state_id` — this is hardcoded engine behavior, not something a `MoveState` can
override by authoring alone. Since the ticket forbids adding a new engine primitive, and a
divekick-specific forced landing-recovery tail (a common genre convention — a divekick that
whiffed or was blocked close often eats extra recovery on landing) would require exactly that (a
new hook so a specific AIRBORNE state's landing redirects somewhere other than idle), I authored
all three divekicks as ordinary `CATEGORY_AIRBORNE` moves: their landing recovery is whatever is
IMPLICITLY true of "the move's own timeline hasn't finished, but the ground clamp ended it early
anyway" — i.e., none, beyond the state itself ending. A divekick that lands (hit, blocked, or
whiffed) returns to idle immediately, same as an ordinary air normal or the plain jump.
**Alternatives considered.** Adding a new `Character`/`MoveState` field naming a distinct
landing-recovery target for an AIRBORNE state (parallel to `knockdown_state_id`) — this IS a new
engine primitive (a new redirect mechanism `StepPhases._land` would need to consult), squarely the
kind of change this ticket is scoped to avoid and the kind of call that belongs to the Architect
(a contract addition to `move-format.md`/`combat-resolution.md`), not something to invent here.
Authoring a same-tick GROUNDED "fake landing" state some other way — rejected as a workaround
around the very engine constraint the ticket names, not a legitimate authoring trick.
**Scope.** `character_b.gd` (`_build_divekick`; category choice + doc comment only — no code
change). If playtest/the human gate finds divekicks need real landing punishment, that is a
flag to the Architect (a genuine format/engine gap, not a data fix), per the ticket's own routing
instruction for exactly this situation. Log for ratification.

### JC-095 · 2026-07-15 · TKT-P2-06 · Provisional tuning bundle — divekick hang/dive numbers, low-slide frame/speed/stun numbers, arc-projectile parabolas, and the B-4 reaction-window-floor placeholder — **ratified as provisional-pending-gate** (2026-07-16; ratified *as staged*, not frozen — these are explicitly the gate's to settle and no final value is forced now. The B-4 floor placeholder (12) and H-divekick's measured 17-tick delay are now recorded in `character-b.md` so the gate has both numbers in front of it; the floor stays the Strategist's feel value)
**Decision.** Per character-b.md's own staging note ("frame numbers, divekick trajectories,
projectile parabolas, and the overhead reaction-window floor are provisional tuning... settle
against the human gate"), the following are authored as sensible, internally-consistent
placeholder values — NOT hand-fit to pass headless assertions, verified only for the STRUCTURAL
invariants (B-1/B-2/B-3) the acceptance criteria actually pin:
- **Divekick hang/dive** (`character_b.gd` `DIVEKICK_*` constants): L hang 4f / dive (vx 1.0, vy
  9.0); M hang 9f / dive (vx 4.5, vy 6.0); H hang 16f / dive (vx 0.0, vy 10.0). Chosen so hang
  strictly increases L<M<H (H's tell is the longest) and dive vectors are pairwise distinct
  (B-3), with H deliberately zero-horizontal ("near-vertical plummet," the brief's own phrase).
- **Low slide** (`SLIDE_*` constants): 12f startup / 8f active / 10f recovery, 5.0 px/f forward
  during active, damage 50, hitstun 28 (matched to the shared knockdown wakeup, JC-091), blockstun
  14, hitstop 8. The 8-frame active window is what gives B-1's spacing-variance real room to show
  up (confirmed empirically: gap 40 blocks on active frame 13 at live advantage -3; gap 95 blocks
  on active frame 19 at live advantage +3 — a striking, genuinely readable swing).
- **Arc projectile parabolas** (`_build_arc_projectiles`): L (vx 2.0, vy0 -6.0, gravity 0.5, dmg
  30); M (vx 4.0, vy0 -9.0, gravity 0.4, dmg 38); H (vx 6.0, vy0 -13.0, gravity 0.3, dmg 46) —
  increasing reach/hangtime L->H, confirmed via headless replay to land at genuinely different
  distances (~80 / ~216 / ~554 units from B).
- **B-4 reaction-window floor** (`test_character_b_air.gd`'s `REACTION_WINDOW_FLOOR_TICKS = 12`):
  a placeholder Strategist feel value (the ticket's own framing — "like `AirHeightScaling`"), used
  only to bound-check that H-divekick's entry-to-active-hitbox delay (17 ticks: 16 hang + 1 dive-
  impulse frame) clears SOME reasonable floor; the number 12 itself is not load-bearing design,
  only a sanity placeholder pending the gate.
None of these numbers were adjusted to make a specific test pass after the fact — the mechanism
(hang/dive/active-frame timing, live advantage's formula) was built first and these are the first
sensible values tried, then verified.
**Alternatives considered.** Hand-deriving "realistic" frame-data-style numbers by comparing
against genre references — passed over as false precision: the spec explicitly defers exact
tuning to human playtest, and the Developer's job here is a plausible, internally-consistent
placeholder the mechanism can be judged through, not a pre-guessed final balance pass.
**Scope.** `game/content/character_b.gd`, `game/tests/test_character_b_air.gd`. Every number above
is trivially adjustable without touching the mechanism they ride on (AD-008's live-advantage
formula, AD-043's velocity-set model, AD-047's gravity field) — that mechanism, not these values,
is the contract. Log for ratification alongside the human-gate tuning pass.

### JC-096 · 2026-07-16 · TKT-P2-08 (match-flow.md "Health") · `MatchState.FULL_HEALTH` tuned 1000 -> 500 against A's and B's authored damage — **ratified, folded into `match-flow.md`** (2026-07-16; this is an Architect-owned tuning the spec had left open, so ratifying it in code alone would have left the spec stale — 500 and its derivation are now the specced value and the Open item is closed. The reasoning holds against the brief's target, and the refusal to split health per character is the right read of the "one conventional total" contract. Slice-provisional; the gate may move it)
**Decision.** Set `MatchState.FULL_HEALTH = 500`, replacing the prior 1000 placeholder (which
only mirrored `SimState.new_initial()`'s own untuned P0 scaffold default — "data, not feel,"
per that constructor's own comment — not a real tuning pass). Chosen by hand-summing both
characters' AUTHORED `hb.damage` values (`game/content/character_{a,b}.gd`) through the one
`DamageScaling` definition (100% hit 1, -10%/hit floored at 10%), against match-flow.md's own
stated target: "a couple of good touches decide a round, not thirty pokes."
- **A's best realistic hit-confirmed combos** land 180-270: `2M(70) xx DP-M(130*.9≈117) ≈ 187`;
  a deep jump-in `jH(80) -> 2M(70*.9≈63) xx DP-H(160*.8≈128) ≈ 271`. At 500 health, ONE such
  combo is roughly half the bar — two plausibly close a round.
- **B has no comparable single-move payoff** (2H's launch has no juggle follow-up, matching A's
  own 2H) — B's damage lives in the LADDER. The spec's own worked example,
  `5L 2L 2L 5M 2M 2H 5H` (character-b.md "Cancel model"), scaled hit-by-hit, totals ~155-160 (a
  full hand-sum: 20+16+14+31+24+27+26≈158). At 500, that's ~30% — B's own "couple of good
  touches" is 2-3 such landed strings, not one, which is consistent with the brief (B's identity
  is pressure/mixup volume, not one-touch payoff) rather than a balance defect.
- **A single UNCOMBOED poke** (B's `5L`=20, A's `5L`=30) alone still needs ~15-25 hits to kill —
  deliberately NOT a fast poke-race, so it is combo/confirm play, not raw poke attrition, that
  actually decides a round, matching the brief's explicit contrast ("not thirty pokes").
- 500 is also a clean, round number a health BAR reads cleanly against (quarter/half marks),
  which the prior 1000 also had going for it, so switching costs nothing on that axis.
**Alternatives considered.** Backing directly off A's single highest-damage 2-hit DP combo alone
(e.g. tuning so exactly 2 max-optimal combos kill) — rejected: over-indexes on A's execution
ceiling (character-a.md's own "the ceiling is real and high" framing) rather than the more
representative BREAD-AND-BUTTER numbers used above, and would make ordinary (non-optimal) play
feel like it never threatens a KO. A per-character health split (asymmetric totals) — rejected
outright: match-flow.md's own contract is explicit ("one conventional total"), not per-character
values; a split would be a contract change, not tuning latitude.
**Scope.** `game/sim/match_state.gd` (`FULL_HEALTH` + the reasoning comment on it),
`game/tests/test_match_state.gd` (the full-match-determinism script's injected health value,
previously hardcoded against the old 1000 placeholder — updated to a value still below the new
500 so the intended "p0 wins on higher current health" timeout scenario still holds). A pure
feel value per match-flow.md's own "Open items" note ("tuned after B's damage lands... the
mechanism is done") — settles at the human-inspection gate like every other slice-provisional
number this phase. Log for ratification.

### JC-097 · 2026-07-16 · TKT-P2-08 (match-flow.md / AD-048; "wire the full A-vs-B match") · `MatchTickHost` built as its OWN class mirroring `TickHost`, rather than generalizing `TickHost` to carry either `SimState` or `MatchState` — **ratified** (2026-07-16; latitude — host structure is implementation. Tenet 3 reasoning is right: a narrow twin leaves the landed `TickHost` seam untouched and gives a future MatchState-shaped harness a clean home)
**Decision.** Added `game/sim/match_tick_host.gd` — a small, self-contained twin of `TickHost`
(same fixed-tick discipline: `_physics_process`, no `delta`, tick read from state, exactly one
`_advance` per call) that walks `MatchState.match_step` instead of `SimState.step`. `TickHost`
itself is untouched: still SimState-specific, exactly as every existing caller (the sandbox
training-mode path, `TrainingHarness`, every pre-P2-08 overlay test's `_make_shell()`-style
helper) already depends on it.
**Alternatives considered.** Generalizing `TickHost` to hold either a `SimState` or a
`MatchState` (a type union / duck-typed "advance" callable) — rejected: `TickHost` is a landed,
tested contract several other roles' test helpers construct directly (`TickHost.new()` + manual
`setup()`); broadening its shape for this ticket's scope (integration/tuning/readouts, "no new
mechanics") would touch a stable seam for no benefit this ticket needs, and risks destabilizing
tests this ticket does not own. A duplicated-but-narrow twin costs a small amount of repetition
(documented in the new file's own header) in exchange for zero risk to the existing seam — the
"leaves more doors open" reading (Tenet 3): a future MatchState-shaped harness/reset control (see
JC-098) has a clean, uncoupled home to extend, and `TickHost`'s own contract stays exactly what
QA/other roles already verified it to be.
**Scope.** `game/sim/match_tick_host.gd` (new), `game/tests/test_match_tick_host.gd` (new,
mirrors `test_tick_host.gd`'s own assertions one level up). Log for ratification.

### JC-098 · 2026-07-16 · TKT-P2-08 (match-flow.md / AD-048; "wire the full A-vs-B match end to end") · Match mode as an opt-in `start_in_match_mode` export on `TrainingMode`, fixed A-vs-B roster, reset/snapshot control-surface trimmed for match mode — **ratified; trim accepted and documented in `match-flow.md`** (2026-07-16; **the trim is acceptable — no flag.** Checked against the match brief and this spec: neither asks for an interactive match reset; capture/reset is training-mode (sandbox) scope, and the match layer's determinism bar is proven headlessly where it belongs. Now a stated scope line so QA does not audit it as a gap. The opt-in export over a default flip is also the right call — no silent behavior change to existing callers)
**Decision.** Extended `TrainingMode` (rather than a new scene/script) with an opt-in
`@export var start_in_match_mode: bool = false`. False (the existing sandbox single-`SimState`/
single-character path, `_ready_sandbox_mode`) is the default for EVERY existing caller
(`TrainingMode.new()` + a hand-added `TickHost` child, per every pre-P2-08 test helper) — a
strict addition, not a default-behavior change. The actual `training_mode.tscn` (the scene a
human opens for the P2 gate) sets it `true`, so opening that exact scene is what plays the real
A-vs-B match. True routes to `_ready_match_mode`: installs BOTH `CharacterA`/`CharacterB` into
one combined `MoveRegistry`/`ProjectileRegistry` (disjoint ids by construction), builds a fresh
`MatchState` via `MatchState.new_match(CharacterA.CHAR_ID, CharacterB.CHAR_ID)` (AD-048's fixed
wiring constant — hardcoded, not a configurable "pick your characters" API, exactly like
`_configure_default_character_a` already hardcodes A for the sandbox path), and drives it through
`MatchTickHost` (JC-097). The pre-existing `TickHost` child is left present (every `.tscn`/test
helper already wires one, so `@onready var _tick_host: TickHost = $TickHost` must keep resolving)
but explicitly PAUSED and never `setup()` in match mode, so it does not silently churn an
orphan SimState nobody reads. `inspection_view()`/`set_paused`/`is_paused`/`step_once` all branch
on `_match_mode` to route to the correct host; a new `match_view()` (returns null outside match
mode) and `is_match_mode()` round out the surface.
**Scope trim (same entry, closely related): `capture_reset`/`do_reset`/`has_reset_point` are a
documented no-op / `false` in match mode.** `TrainingHarness` is built over
`TickHost.get_state()`/`set_state()`, both SimState-specific — it has no MatchState-shaped twin.
Building one is real, additive interactive-control-surface work outside this ticket's named scope
("integration, tuning, and readout instruments only — no new mechanics"); the match layer's OWN
determinism/round-trip bar is already proven headlessly by TKT-P2-07's `test_match_state.gd`,
independent of any interactive reset control. Guarding these methods to no-op/false in match mode
(rather than silently reaching into the wrong host, which would corrupt the SANDBOX state instead)
is the safe, honest choice; a future ticket that wants an interactive match reset builds the
MatchState-shaped harness twin then (the same "leaves doors open" reasoning as JC-097).
**Alternatives considered.** Making match mode the training-mode shell's DEFAULT (flip
`start_in_match_mode`'s default to `true`) — rejected: would silently change the behavior of
every existing `TrainingMode.new()` caller (a wide swath of already-green P1/P2 overlay tests),
for a ticket whose own constraint is "no new mechanics" — an opt-in export flag gets the SAME
end-user-visible outcome (the actual `.tscn` a human opens plays the match) with zero risk to the
existing test surface. A wholly separate `match_mode.gd`/`.tscn` scene (duplicating the shell) —
rejected: `TrainingMode` already owns exactly the wiring/control-surface/overlay-mounting
machinery a match session needs (sources, pause/step, overlay auto-wiring); duplicating that
shell to avoid one export flag would be needless drift risk for zero benefit.
**Scope.** `game/scenes/training_mode.gd`, `game/scenes/training_mode.tscn` (sets the export +
mounts the new `MatchPanel`), `game/tests/test_training_mode_shell.gd` (match-mode smoke test +
the sandbox-mode-unaffected regression test). Log for ratification.

### JC-099 · 2026-07-16 · TKT-P2-08 (integration correctness; AD-048) · `MatchState.fresh_round_sim` now resolves each side's `state_id` through `MoveRegistry` (a real defect found wiring the actual A-vs-B match) — **ratified, folded into AD-048 as a contract clarification** (2026-07-16; a real latent defect and the right fix — `idle_state_id` through `MoveRegistry` is the one lookup this codebase uses, and adding caller parameters would have widened `MatchState`'s surface for nothing. AD-048 now states that "fresh symmetric start" includes per-character idle `state_id`, so the P0-character masking cannot recur)
**Decision.** `fresh_round_sim` built a bare `PlayerState` and set `character_id` but never
`state_id`, leaving it at the struct default (`0`). This is silently correct for
`TestSupport.CHAR_ID` (the P0 test character's own idle state IS id `0`, by convention) — every
one of TKT-P2-07's own match-layer tests uses that character, so the gap was invisible until a
REAL character (A's idle is `100`, B's is `300`) was actually plugged into the match layer this
ticket (exactly the "P1 was falsely called done" class of integration gap this ticket's brief
warns against, and the same class of defect TKT-P1.1-01 Part A already fixed once for the
sandbox training-mode path). Fixed by resolving each side's idle state through `MoveRegistry` —
the SAME single source of truth every other character-id -> state lookup in this codebase
already uses (`Character.idle_state_id`) — with a `0` fallback when no roster is installed for
that id (preserving the exact prior behavior for every already-green match-layer unit test that
never calls `MoveRegistry.install()` first, so no existing hash changed).
**Alternatives considered.** Requiring every `fresh_round_sim`/`new_match` caller to pass the
idle state ids explicitly as extra parameters — rejected: `Character.idle_state_id` already
exists precisely so a caller does NOT need to know/pass it (mirrors `character_id` itself being
the only identity a caller supplies everywhere else in this codebase); adding redundant
parameters here would be a needless, drift-prone widening of `MatchState`'s own public surface
for something one `MoveRegistry.character()` call already resolves correctly.
**Scope.** `game/sim/match_state.gd` (`fresh_round_sim` + the new `_idle_state_id` helper),
`game/tests/test_match_state.gd` (a new test pinning the real-character resolution + a sanity
note on the pre-existing no-roster-installed fallback). Verified: every pre-existing
`test_match_state.gd` hash-sensitive test is unaffected (checked by full re-run, all green); the
fix is exercised end-to-end by `test_training_mode_shell.gd`'s new match-mode smoke test (A/B
each resolve onto their OWN idle state from tick 0). Log for ratification.
