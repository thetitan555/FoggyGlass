# Tickets — P2: Character B + 1v1 Match + AD-036 remainder

> Owned by the **Architect**. Decomposed from `spec/character-b.md`,
> `spec/match-flow.md`, and the contract edits in `spec/move-format.md`,
> `spec/combat-resolution.md`, `spec/simulation.md`, `spec/inspection-surface.md`,
> against **AD-043..048** (and the superseded AD-036). Serves briefs
> `character-b.md` and `match-flow.md`, and the roadmap P2 pre-requisite (AD-036
> remainder as the opener). Each ticket names the spec/AD it serves, its
> dependencies, and the acceptance criteria it must satisfy — **QA verifies against
> the spec's criteria, not the ticket's prose.**
>
> **P2 carries a human-inspection gate** (roadmap, `audit-criterion.md`): the
> matchup's legibility (B's air/mixup readability, the match result's legibility) is
> judged live by the user; QA's headless pass is necessary but not sufficient.
>
> **Staging note (size).** P2 is materially larger than P1/P1.1. This spec is
> complete at the **contract/architecture/acceptance-criteria** level (the drift-
> expensive layer); the **frame numbers, divekick trajectories, projectile parabolas,
> and the overhead reaction-window floor are provisional tuning** (Developer's within
> the constraints; the hard legibility *invariants* are pinned) and settle against the
> human gate — the honest place for the "spec + playtest" calls the brief names. Two
> Strategist flags ride with this phase (see "Flags raised" at the end): the AD-045
> high/low-enforcement scope call, and the confirmed (no-flag) character-A dash cost.

## Sequencing (the dispatch order — Architect deliverable, not Developer discretion)

Per protocol § "Token economy": heavy build work defaults to **per-ticket dispatch**;
one **permitted tight cluster** is marked where same-subsystem read-overlap earns it.
Dependency graph and the seam-first rule (sim-facing interfaces land before the
player-facing side builds on them):

```
  01 airborne-physics ─┬─▶ 02 dash+air-action ─┐
   (AD-043, OPENER)    │                        ├─▶ 05 B-content:normals ─▶ 06 B-content:air+specials ─▶ 08 integrate+tune+readouts ─▶ [human gate]
                       ├─▶ 03+04 combat-caps ───┘                                                        ▲
                       │   (AD-044/045/047,                                                              │
                       │    tight cluster)                                                     07 match-layer (AD-048) ─┘
                       └─▶ 07 match-layer  ......... (independent of B content; dispatch any time after 01)
```

**Dispatch order and why:**

1. **TKT-P2-01 (airborne physics — AD-043) FIRST, alone.** The AD-036 remainder is the
   roadmap-mandated opener, ahead of any B or air content. It is an engine change that
   migrates A's jump and re-baselines A's movement goldens — a real checkpoint the user
   will want isolated. *Everything airborne depends on it.* Per-ticket. **Checkpoint:** A
   jumps/lands under gravity (goldens green), airborne velocity persists across state
   transitions, a launched character lands into knockdown; `air_action_used` field +
   reset-on-landing exist.
2. **TKT-P2-02 (dash + air-action — AD-046)** and **TKT-P2-03+04 (combat capabilities —
   AD-044/045/047, a tight cluster)** both depend only on 01 (03+04 depend only on the P1
   base). They are the **engine capabilities B's content authors against**, so they land
   **before** B content (05/06). Dispatch 02, then the 03+04 cluster (or the reverse —
   they are independent of each other). **Seam-first:** the `HitEvent` guard fields (03),
   `PlayerView.air_action_used` (01/02), and later `MatchView` (07) are the read-only
   surface UI/QA build against — they land with their producing ticket, before 08's
   readouts.
3. **TKT-P2-05 (B content: normals + ladder + throw) then TKT-P2-06 (B content: air +
   specials).** Same subsystem (both read `character-b.md` + `move-format.md`) — *high
   read overlap* — but B content is **heavy, novel, and legibility-critical**, and 06 is
   exactly where the user will want a checkpoint before the hardest legibility calls. So
   they run as a **sequence** (05 → 06), per-ticket, **not** a cluster. Depend on 01–04.
4. **TKT-P2-07 (match layer — AD-048)** is **structurally independent of B content** (it
   wraps the sim). It may be dispatched **any time after 01** — a steerability lever the
   Strategist may place earlier or later. Its *health tuning* is deferred to 08.
5. **TKT-P2-08 (integrate + tune + readouts)**, after 06 and 07. Health tuned vs. B's
   damage, full A-vs-B match wired, training-mode readouts for the new legibility fields.
   Ends on the **human-inspection gate** + QA's golden-net seeding.
6. **TKT-P2-09+10 (AD-049 repair — defender-resolved reactions + projectile-id uniqueness),
   added 2026-07-16 after the human gate, and now the highest-priority P2 work.** The gate
   exposed that **every cross-character hit is broken** (the reaction `state_id` crossed a
   character boundary; see AD-049) — which means 08's integration was never actually
   exercised and the human gate could not be judged. This is a **tight cluster, one session**
   (see the ticket). **Dispatch before anything else in P2 resumes.** **Checkpoint:** A and B
   hit each other correctly in both directions for every reaction kind. The human gate and
   QA's cross-system consistency check both **re-run after it** — see the Cross-cutting note.

**Cluster exception (the only one):** **03+04 run in one Developer session** — both are
combat-resolution engine capabilities with high spec-read overlap (`combat-resolution.md`
+ `move-format.md` + the projectile/cancel/hitbox code), each small, ending on one
checkpoint ("B's combat capabilities — groups, guard height, arc gravity — exist and are
test-covered"). Commit each AD's work as its own unit *within* the session (protocol hard
rule). Every other ticket is per-ticket dispatch. **The Strategist may widen or narrow on
steerability grounds** (e.g. split 06, or move 07 earlier); the mechanical ordering above
is the Architect's.

---

### TKT-P2-01 · Airborne physics: gravity + persistent velocity + continuous clamp/landing + knockdown (AD-043)
**Serves:** **AD-043** (supersedes AD-036); `move-format.md` → movement invariants;
`combat-resolution.md` → phase 3 + criterion 15; `simulation.md` (velocity meaning,
`air_action_used` field). **Depends:** the P1 sim (landed). **Opener — dispatch first.**
**Scope:**
- Phase 3: apply `velocity.y += physics.gravity` to airborne characters, integrate
  `position += velocity`, with `velocity` **persisting across airborne state transitions**;
  a keyframe `motion` may *set* velocity (impulse). Add `gravity` to each character's
  `physics`.
- After integration: the **continuous `pos_y ≥ ground_y` clamp fused with landing**
  (`AIRBORNE → GROUNDED`, velocity zeroed); a **launched (airborne HITSTUN)** character
  lands into a **knockdown** reaction (grounded, non-actionable, fixed wakeup). Subsumes
  AD-042's grounded-entry snap.
- Add serialized `players[i].air_action_used` (bool; 0/1; hashed in fixed order) and
  **reset it to false on the landing transition** (its consumption lands in 02).
- **Migrate character A's jump** to the gravity model (takeoff impulse + gravity + clamp);
  re-baseline A's movement goldens deliberately (JC-017 style).
**Acceptance:** `combat-resolution.md` criterion 15; `move-format.md` criterion 13;
`simulation.md` determinism/round-trip/hash criteria stay green with the new `velocity`
meaning + `air_action_used` field. **Judgment-log:** record `gravity` values, knockdown
wakeup duration, and any latitude for ratification.

### TKT-P2-02 · Double-tap dash + one-air-action economy (AD-046)
**Serves:** **AD-046**; `move-format.md` → `ButtonMapEntry.double_tap` + criterion 12;
`combat-resolution.md` criterion 16; `inspection-surface.md` → `PlayerView.air_action_used`.
**Depends:** **TKT-P2-01** (airborne physics for air dash / double jump).
**Scope:**
- Double-tap recognition in the one recognizer (press→release→press of `required_direction`
  within the double-tap window, pure function of `input_history`), routing to a dash state.
- Air-action commands: **air dash** (double-tap fwd/back in air → set horizontal velocity,
  zero vertical, spend `air_action_used`); **double jump** (`up` in air → re-impulse, spend
  `air_action_used`); suppress the second air action until landing resets it. Divekick does
  **not** spend it.
- **Wire character A's `66`/`44`** to its existing `STATE_DASH_F/B` via two double-tap
  `button_map` entries — **no A engine/state change** (confirmed marginal, AD-046).
- Surface `PlayerView.air_action_used`.
**Acceptance:** `move-format.md` criterion 12; `combat-resolution.md` criterion 16;
`character-b.md` criterion 3. Determinism unchanged (recognition is pure over history).
**Judgment-log:** double-tap window value, air-dash/double-jump velocities, any latitude.

### TKT-P2-03 + TKT-P2-04 · Combat capabilities: cancel groups (AD-044) + guard height (AD-045) + arc-projectile gravity (AD-047) — TIGHT CLUSTER, one session
**Serves:** **AD-044, AD-045, AD-047**; `move-format.md` criteria 10/11/14;
`combat-resolution.md` criteria 14/17; `inspection-surface.md` `HitEvent` additions.
**Depends:** the P1 combat pipeline (landed) — independent of 01/02. **Commit each AD as
its own unit within the session.**
**Scope (03 — cancel groups + guard height):**
- **AD-044:** group-target resolution in `CancelEval` (a `target` naming a
  `Character.cancel_groups` set is satisfied when the buffered command's destination state
  is a member). No new field; `CancelRule.target` accepts a group name.
- **AD-045:** `HitBox.guard_height` (HIGH/LOW/MID, default MID); phase-5 block validity by
  defender stance (crouch-category = crouched); a wrong-stance back-hold resolves as a
  **hit**. Add `guard_height` + `block_valid` to `HitRecord`/`HitEvent`
  (HASH_FIELDS/to_dict/from_dict/clone; hashed per AD-023). Set A's `2L/2M` to LOW.
**Scope (04 — arc projectile):**
- **AD-047:** `ProjectileData.gravity` (default 0); phase-3 projectile
  `velocity.y += gravity` before integration; despawn on `pos_y ≥ ground_y`. A's fireball
  (gravity 0) unchanged.
**Acceptance:** `move-format.md` criteria 10, 11, 14; `combat-resolution.md` criteria 14, 17;
`inspection-surface.md` criterion 8. Existing A/test goldens unaffected except A's now-LOW
lows (deliberate). **Judgment-log:** any latitude per AD, recorded separately.

### TKT-P2-05 · Character B content, part 1: normals + gatling ladder + throw + ground movement
**Serves:** `character-b.md` (Normals, Cancel model, Movement, throw) criteria 1, 2;
**AD-044** (ladder), **AD-045** (guard heights). **Depends:** TKT-P2-01, -02, -03/04.
**Scope:** author (data only) B's `Character`: the 6 chainable normals (strength/stance
tags, guard_heights, `on_contact` cancels to the declared `cancel_groups` ladder), `5H`
(fast/severe-whiff), `6H` (HIGH overhead), `2H` (anti-air launcher, jump-cancellable on
block), the throw (existing AD-016/029 model — **no new throw rules**), and walk/dash/jump
wiring. No engine change.
**Acceptance:** `character-b.md` criteria 1, 2, 4 (ground part), 6; `move-format.md`
criterion 10. **Checkpoint:** B is playable on the ground vs. a dummy — gatling strings +
high/low + throw work; the ladder resolves exactly. **Judgment-log:** provisional frame
numbers, cancel-group membership, any latitude.

### TKT-P2-06 · Character B content, part 2: air toolkit + specials + oki
**Serves:** `character-b.md` (Specials, Divekick, air movement, mixup, the concentrated
interaction) criteria 4, B-1, B-2, B-3, B-5; **AD-043/046/047**. **Depends:** TKT-P2-05
(B shell) + -04 (arc). **The legibility-critical ticket.**
**Scope:** author (data only) the **three divekicks** (velocity-set hangs/dives, H = HIGH
overhead), the **low slide** (LOW, hard knockdown → knockdown-into-ground oki, spacing-
variable advantage), the **arc projectile** strengths (parabolas via initial velocity +
`gravity`; the falls-in-front oki), the **2H-JC → airdash** pressure, and the air normals
(carry the fall). **No new engine primitive** — all over 01–04.
**Acceptance:** `character-b.md` criteria 4, B-1, B-2, B-3, B-5 (headless-checkable parts);
`combat-resolution.md` criterion 17. **The hard legibility constraints are the bar** —
verify the slide's advantage is instrument-readable (B-1), the falls-in-front oki has no
unblockable frame (B-2), the divekicks' trajectories differ (B-3). **Provisional numbers /
divekick trajectories / parabolas / the overhead reaction-window floor (B-4) tune against
the human gate.** **Judgment-log:** all provisional tuning + latitude.

### TKT-P2-07 · Match layer: `MatchState` + `match_step` + `MatchView` (AD-048)
**Serves:** `match-flow.md` (all); **AD-048**; `simulation.md` (harness extension);
`inspection-surface.md` `MatchView`. **Depends:** TKT-P2-01 (a stable sim). **Independent
of B content — dispatch any time after 01** (Strategist steerability lever).
**Scope:** `MatchState` (wraps `SimState` + match fields), pure `match_step` (wraps `step`,
signature untouched), the ROUND_START/ACTIVE/ROUND_END/MATCH_END + sudden-death state
machine, health/KO/timer/timeout/scoring/ties per the rules, `MatchView`, and **extend the
determinism/serialization harness to a full match round-trip.** Fixed A-vs-B side
assignment (wiring constant). **Placeholder health** (tuned in 08).
**Acceptance:** `match-flow.md` criteria 1–8; `inspection-surface.md` criterion 7.
**Checkpoint:** a full match runs start-to-finish deterministically; a mid-match
snapshot/restore reproduces the same final hash; MatchView is legible. **Judgment-log:**
round length, transition-beat lengths, any latitude.

### TKT-P2-08 · Integrate + health tuning + training-mode legibility readouts
**Serves:** `match-flow.md` (health tuning), `character-b.md` (B-4 human-gate), the P2
done-conditions. **Depends:** TKT-P2-06 (B damage) + TKT-P2-07 (match structure).
**Scope:** tune `SimState.players[i].health` vs. B's damage (default: a couple of touches
decide a round); wire the full A-vs-B match; add training-mode readouts (view/view-model
split, JC-040) for the new legibility truth — `air_action_used`, the high/low attribution
(`HitEvent.guard_height`/`block_valid`), and the match state via `MatchView`. No new
mechanics.
**Acceptance:** roadmap P2 done-conditions (A vs B playable start to finish; one move
format + one advantage computation across both — QA cross-system consistency); the human-
inspection gate on B's air/mixup readability and the match result's legibility.
**Judgment-log:** health value + any latitude.

---

### TKT-P2-09 + TKT-P2-10 · AD-049 repair: defender-resolved reactions + projectile-id uniqueness — TIGHT CLUSTER, one session
**Serves:** **AD-049** (all three decisions); `move-format.md` → "The character-namespace
rule" + "Reactions" + `Character.reaction_map` + `HitBox.hit_reaction`/`block_reaction` +
`ProjectileData.id` + criteria **15–18**; `combat-resolution.md` → phase 5 (reaction state
resolved on the defender) + the throw path. **Depends:** TKT-P2-01…08 (landed).
**Resolves:** `flags.md` 2026-07-16 (Developer → Architect, `HitBox.hit_reaction`/
`block_reaction`) and the box-vanish flag above it — the same defect from the symptom side.
**Blocks:** P2's re-audit and the human-inspection gate. **Every A-vs-B hit is currently
broken; nothing about P2 can be judged until this lands.**

**TKT-P2-09 — the reaction model.**

1. **`ReactionKind`** — the closed engine-level enum, exactly the six kinds in
   `move-format.md` → "Reactions". Engine-side, alongside the existing `MoveState` category
   constants.
2. **`Character.reaction_map`** (`ReactionKind → own state_id`) + a `reaction_state(kind)`
   accessor implementing the resolution floor (`kind → REACTION_HITSTUN → idle_state_id`).
   The floor is a guardrail against the wedge, **not** an authoring fallback — see below.
3. **`HitBox.hit_reaction`/`block_reaction` carry a `ReactionKind`, not a `state_id`.**
4. **Resolution sites take the defender's map.** `StepPhases._resolve_one_hit` (~line 915/919
   and the reaction-entry at ~958) and `_resolve_throw` (~line 1127) resolve
   `defender_character.reaction_state(hb.hit_reaction)`. **The bug is precisely that these
   used the attacker's authored id against `character_def` (the defender) — the id must not
   cross at all now.**
5. **Retire `Character.knockdown_state_id`** → `reaction_map[REACTION_KNOCKDOWN]`.
   `StepPhases._land` (~line 494) resolves the kind. Remove the field and its `== 0`
   no-transition fallback (AD-049; the reaction is required content now). Do **not** leave
   both mechanisms live.
6. **Re-author both characters' reaction data.** `character_a.gd` / `character_b.gd` (and
   their baked `.tres`, and `test_character.tres` / `test_support.gd`): each `hit_reaction`/
   `block_reaction` becomes a kind; each character declares a full `reaction_map`. The
   existing states map straight across (A: 120/125/122/123/121/124; B: 320/323/**—**/324/321/322).
7. **Character B must author an `AIR_RESET` state** — it has none, because it inflicts none.
   **A's `2H` inflicts it and B receives it.** This is the content hole the old model hid;
   it is the concrete proof the fix is doing work. Author it consistent with B (airborne
   HITSTUN-category knock-away, no follow-up) — B's own reaction, not a copy of A's. *If the
   right feel for B's air-reset is not obvious from `character-b.md`, that is a **feel**
   question: flag it, don't invent it.*

**TKT-P2-10 — projectile-id uniqueness.** `ProjectileRegistry.install` **rejects duplicate
`data_id`s** (loud failure at wiring time) instead of silently overwriting; `training_mode.gd`'s
A+B roster merge (~lines 160–169) goes through it. A/B install clean today — this is closing
the hole before character C hits it, per AD-049 Decision 3. Commit as its own unit.

**Acceptance criteria:**
1. **`move-format.md` criteria 15–18 pass**, criterion 16 above all.
2. **The regression test is ASYMMETRIC — A vs B, not a mirror.** For **each**
   `ReactionKind`, an A-vs-B contact (both directions) leaves the defender in a state **from
   its own roster**; `PlayerView.boxes` is **non-empty on every tick of the reaction**; and
   the defender **becomes actionable when stun expires**, with no round reset. **A mirror
   matchup cannot satisfy this** — a mirror is what let the bug ship, so a mirror test is not
   evidence. Verify it **fails on the current code** before fixing (it must reproduce the
   wedge), then passes.
3. **The `AIR_RESET` case is covered explicitly**: A's `2H` hits B → B enters **B's own**
   air-reset state, keeps its boxes, and recovers.
4. **Knockdown convergence still holds (AD-043)**, now via the kind: a launched character
   landing, a grounded hard-KD hit (B's slide), and a throw KD all reach **that character's
   own** knockdown state, wakeup counted from landing.
5. **No raw `state_id` crosses a character boundary** (criterion 17) — greppable.
6. **Duplicate `data_id` install fails loudly**; A+B install clean.
7. **Full headless suite green**, goldens re-baselined where the reaction re-author moves
   resolved frame data (QA's P2 net). A golden diff here is *expected*; an unexplained one is
   not — say which and why.

**Judgment-log:** any latitude — notably B's air-reset framing (if it stays latitude and not
a flag), and the `.tres` re-bake mechanics.

**Checkpoint:** *A and B hit each other correctly, in both directions, for every reaction
kind — the defender always keeps its boxes and always recovers — and no identifier crosses a
character boundary unchecked.*

**Why a cluster:** P2-10 is a single install-time guard plus a test, sharing P2-09's exact
spec read (AD-049 + the namespace rule) and its one checkpoint. It is the only cluster in
this repair; commit each ticket's work as its own unit within the session (protocol hard
rule).

**Note for the Developer:** you declined to patch this and escalated it — that was the right
call and it is why the fix is a contract and not a workaround. AD-049 is now the contract;
build against it and raise anything it still leaves ambiguous.

---
## Cross-cutting (verified at feature audit / human gate / by QA, not separate build tickets)

- **Golden-file regression net seeding (QA; roadmap P2 done-condition).** Once A
  (re-goldened jump), B (resolved frame data + hitbox geometry), and the match determinism
  are stable (after 06/07/08), QA seeds the golden net. Targets I name: A's re-baselined
  movement goldens; B's per-move resolved frame data + box geometry (the second,
  structurally different character to snapshot); a full-match determinism golden
  (serialize/restore/re-run). QA owns building it.
- **Cross-system consistency (QA).** Both characters obey **one move format** and **one
  advantage computation** — QA verifies A and B resolve frame data / advantage through the
  same code path with no character-specific branch (`move-format.md` criterion 4;
  `character-b.md` criterion 1). This is the content-seam proof P2 is for.
  **Re-scoped 2026-07-16 (AD-049) — this check passed while every A-vs-B hit was broken, and
  must not be run the same way again.** The prior pass grepped `game/sim/*.gd` for
  character-specific branches and found zero. That was **true and insufficient**: the defect
  was not a branch but an *implicit coupling* — the engine worked only because both
  characters happened to share a state-id namespace the format never required them to share.
  **A structural grep cannot see an implicit coupling; only an asymmetric behavioural test
  can.** So the check now additionally requires: **`move-format.md` criteria 15–18**, with
  **criterion 16 (asymmetric A-vs-B reactions) as the load-bearing one** — the content-seam
  thesis is proven by two *different* characters interacting correctly, never by a mirror
  matchup or a code-shape grep. Where a check *could* be satisfied by both characters
  agreeing on something by convention, it isn't evidence.
- **Human-inspection gate (roadmap P2).** After 08, the user plays A vs B: confirms B's
  mixups are **readable as they happen** (the overhead looks like an overhead, the divekick
  version is tellable, the crossup side is readable, the slide's advantage is on-screen, no
  unblockable), and the match result (KO/timeout/double-KO) is legible on its face. QA
  cannot issue "done" while this stands open; only the user closes it.
- **B's pressure vs. the no-knowledge-checks line (QA + human gate, brief).** QA audits B's
  pressure against principles' "no knowledge checks" at the human gate — the concentrated
  air/mixup interaction (`character-b.md` B-4) is where this concentrates.
- **Judgment-call ratification.** Any latitude recorded on these tickets is ratified by the
  Architect (riding an open Architect session per protocol) before P2 is audited.

## Flags raised with this phase (to the Strategist)

1. **AD-045 high/low block enforcement — scope call.** B's briefed overhead/high-low mixup
   requires directional block enforcement, which the P1 slice deliberately omitted
   (character-a reconciliation: "stance-agnostic hold-back, no high/low enforcement"). This
   reverses that simplification and makes A's `2L/2M` enforced lows. Specced against
   "enforcement added" (recommended — it is core to B's brief and the charter's readable-
   mixup thesis), but the Strategist owns whether P2 accepts the scope. **`flags.md`.**
2. **Character-A dash cost — confirmed marginal, no flag needed.** Recorded here for the
   report: wiring A's `66`/`44` to the shared double-tap recognizer is exactly "wire
   existing states to the shared recognizer" (two `button_map` entries, no A engine/state
   work), as the brief predicted. No cost flag.
