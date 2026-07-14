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
5. **TKT-P2-08 (integrate + tune + readouts) LAST**, after 06 and 07. Health tuned vs. B's
   damage, full A-vs-B match wired, training-mode readouts for the new legibility fields.
   Ends on the **human-inspection gate** + QA's golden-net seeding.

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
