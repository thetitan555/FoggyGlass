# Flag Archive

> The permanent record of **resolved and relayed** flags, moved here from
> `flags.md` so the live ledger stays a cheap read. Append-only; never edit an
> archived entry. See `protocol.md` → "How a flag works."

---

### [resolved] 2026-06-27 · raised-by: Architect · owner: Strategist · re: /docs/protocol.md
Problem: the protocol says game code lives in the engine project tree, "path is
the Architect's call; recorded here once set." I've set it: **`/game`** at repo
root (recorded canonically in `/docs/spec/decisions.md`, AD-013). The protocol's
"Where things live" note should mirror this so the path is discoverable from the
protocol, not only the decision record. Low-stakes — a documentation mirror, not
a design change.
---
Resolution (Strategist): Agreed — fixed, not a design change. `/game` is the
Architect's call to make (the protocol explicitly leaves the engine path to
them). Mirrored `/game` into the protocol's "Where things live" prose and the
artifact table so the path is discoverable from the protocol, with AD-013 as the
canonical source. No further action.
---

### [resolved] 2026-06-27 · raised-by: Consultant (via user) · owner: Architect · re: combat-resolution.md (advantage, AD-008)
Problem: The canonical advantage (`defender_remaining_stun − attacker_remaining_recovery`) is computed per-tick but no reference frame is pinned, so there is no defined "the" on-hit/on-block number for content or UI to read; and `attacker_remaining_recovery` is taken from the current move-state's recovery, which is incorrect once cancels let the attacker become actionable early — making the surfaced advantage misleading in exactly the pressure/combo cases the legibility goal most depends on.
Context caveat: raised from chat; owner, confirm against live project state before acting.
---
Resolution (Architect): Confirmed against the spec and accepted — both gaps were
real. Fixed in `combat-resolution.md` (Advantage section) and AD-008: one formula
now surfaces two values — a **static** move frame-advantage pinned at first-active
contact, attacker uncancelled (the canonical number content/UI read), and a
**live** per-tick advantage where `attacker_remaining_recovery` = actual
frames-to-actionable *including committed cancels*, so the readout stays truthful
in pressure/combo cases. Acceptance criterion #3 updated to check both.
---

### [resolved] 2026-06-27 · raised-by: Consultant (via user) · owner: Architect · re: combat-resolution.md (AD-009/AD-010) + move-format.md (cancels)
Problem: The phase order and hitstop rule don't state whether the state-machine/cancel phase (phase 2) processes cancels while a character is frozen in hitstop, nor whether the one-frame path from hit-confirm (cancel_tags granted in phase 5) to cancel-availability (consumed in phase 2 next tick) is intentional. Both are unstated, feel-defining decisions. Relatedly, `cancels` is a single field carrying gatling/special/whiff/rehit semantics with no model spelled out.
Context caveat: raised from chat; owner, confirm against live project state before acting.
---
Resolution (Architect): Accepted. (1) Cancels during hitstop — a frozen character
may *buffer* a cancel but executes it only on the first unfrozen tick (AD-017 +
Hitstop section). (2) The grant→consume path is intentional: `cancel_tags` granted
phase 5 of tick T are usable from tick T+1, a uniform one-tick latency that falls
out of the fixed phase order (AD-009), now stated. (3) `cancels` is no longer one
opaque field — it's a typed `CancelRule` list (target / condition / window / input
/ requires_tag) in `move-format.md` (AD-015), with gatling/special/whiff expressed
as rules, not special cases. Rehit is split out of cancels (AD-016). Acceptance
criteria added (combat #8, move-format #7).
---

### [resolved] 2026-06-27 · raised-by: Consultant (via user) · owner: Architect · re: decisions.md AD-004 (+ simulation.md)
Problem: AD-004 permits in-place mutation of SimState and rejects copy-per-step as "needless allocation pressure," but at slice scale (single machine, 60Hz, two characters) that pressure is likely negligible, while mutability makes the purity contract enforceable only by discipline and leaves purity bugs detectable only when a golden/determinism test happens to hit the offending path — trading away the verifiability the slice exists to prove. Worth re-justifying mutability against this scale and Tenet 3.
Context caveat: raised from chat; owner, confirm against live project state before acting.
---
Resolution (Architect): Agreed — overturned. The verifiability argument is correct
and aligns with Tenets 1 & 3 (the slice exists to *prove* determinism). AD-004
revised and `simulation.md` updated: `step` must not mutate its input; it writes a
distinct output state (buffer reuse of non-live states allowed, so no per-tick
allocation churn). Purity is now a cheap standing assertion — `hash(prev)`
unchanged after `step`. Acceptance criterion #9 added.
---

### [resolved] 2026-06-27 · raised-by: Consultant (via user) · owner: Architect · re: move-format.md + combat-resolution.md (phase 5)
Problem: Hit resolution defines single-hit integrity via `id_group` but specifies no rehit model for intended multi-hit moves (cadenced or sequential hits) and no resolution path for throws (blockstun bypass, tech window, throw-vs-throw, air throw) beyond `throwboxes`/`invuln` existing — so the contract has no answer for two common move classes. Needs either a model or an explicit "deferred."
Context caveat: raised from chat; owner, confirm against live project state before acting.
---
Resolution (Architect): Accepted — both classes now have models (AD-016).
Multi-hit: sequential (distinct `id_group`s across keyframes) or cadenced
(`HitBox.rehit_interval`). Throws: throwbox connect bypasses blockstun, with a tech
window (defender throw input → tech to neutral; simultaneous throws clash to a
tech). Air throws and formal throw-vs-throw priority are **explicitly deferred** —
out of the slice's two grounded movesets — with throwbox / `invuln` /
air-eligibility fields left in place so they're later additions, not rewrites
(Tenet 3). Specced in `move-format.md` + `combat-resolution.md` (Throws / Multi-hit
sections); acceptance criteria added (combat #9–10, move-format #8).
---

### [resolved] 2026-06-27 · raised-by: Architect · owner: Strategist · re: /docs/roadmap.md (P1) + missing character-A brief
Problem: The roadmap scopes P1 as "first character + debug/technical training
mode," built *together* — the debug mode needs something to observe. But the only
P1 brief handed down is `debug-training-mode.md`; there is no brief for character A.
I've specced the training mode against the P0 test character, so the Developer is
**not blocked** (TKT-P1-01…09 can proceed). However, the training mode's value —
and acceptance criteria 5–9 (geometry, real frame data, advantage on real moves,
combo accounting) — only become meaningfully verifiable against a real moveset.
Without a character-A brief, "P1 done" can be demonstrated only against a trivial
test character, which under-proves the feature.
Ask (Strategist's call, not mine): do you intend character A as part of this same
P1 push (then it needs a brief — its archetype/moveset is the roadmap's own open
question), or as a separate phase the training mode formally precedes? Either is
fine for sequencing; I just need to know which so the spec/tickets reference the
right "done" bar. Not urgent for the Developer to *start*; it is needed before P1
can be *audited as done*.
---
Resolution (Strategist): Accepted — the inconsistency was real and mine. Ruling:
**character A is part of the P1 push, not a separate later phase.** The training
mode is the charter's legibility instrument; auditing it against a trivial test
character would stamp "done" on an unproven instrument, which is the one place I
won't accept a soft audit. Delivered the missing brief at
`/docs/briefs/character-a.md` (a grounded, simplified shoto — L/M/H buttons,
cr.MK, fireball, shoryuken, throw + basics; archetype confirmed with the user).
So the **P1 done-bar is the training mode validated against character A.** Per
your note, this does not block the Developer from starting against the P0 test
character (TKT-P1-01…09); character A must land before P1 is *audited* as done.
Two items routed to you in the brief's open questions: (1) the L/M/H three-button
layout is slice-wide — please reflect it in the input contract, not as
character-A-local; (2) all of A's frame data/properties are yours to spec within
the stated identity. Roadmap's character-A open question is now closed.
---

### [resolved] 2026-06-27 · raised-by: Consultant (via user) · owner: Architect · re: inspection-surface.md
Problem: The inspection surface exposes view-only float fields (`position_px`, `rect_px`) on the same returns that QA golden-snapshots (criterion 4) through the same surface QA reads (criterion 11). Per Tenet 1, floats behave differently across platforms/compilers; a golden file that includes `_px` fields risks platform-dependent mismatches, defeating the golden harness. Need a decision: goldens snapshot fixed-point truth only, with `_px` treated as a render-only projection excluded from snapshots (or an equivalent split of the surface's QA vs. render subsets).
Context caveat: raised from chat; owner, confirm against live project state before acting.
---
Resolution (Architect): Confirmed and accepted — real risk. Adopted exactly the
proposed split (AD-019): the snapshot-able surface carries **fixed-point truth
only**, no float fields. Removed `position_px`; `BoxView.rect_px` → `rect`
(fixed-point). Pixel coordinates are now a **render-only projection** (fixed→px)
computed for drawing and excluded from every golden/determinism snapshot — the UI
converts at draw time. Updated `inspection-surface.md` (principles, PlayerView,
BoxView, new "Render projection" section, criteria 4 & 6) and the training-mode
geometry overlay. One surface preserved (AD-011 intact); snapshots stay float-free.
---

### [resolved] 2026-06-27 · raised-by: Consultant (via user) · owner: Architect · re: training-mode.md
Problem: `do_reset()` restores `SimState` only, but the `RecordPlaybackSource` playback cursor lives outside `SimState` (Tenet 2: input sources are external to the sim). So resetting a situation does not re-sync the playback dummy to the reset point — a recorded sequence will not replay in sync with the rep, which breaks the core training-rep loop. The non-re-sync is forced by the seam, not chosen: the current structure cannot express a re-synced reset without explicit handling. No acceptance criterion covers reset+playback interaction (criteria 3 and 4 are tested independently). Define intended behavior (re-sync on reset as the default; independent/"metronome" playback as an explicit option only if wanted) and add coverage. May implicate Tenet 2 interpretation — re-route to the user if resolution needs a tenet change.
Context caveat: raised from chat; owner, confirm against live project state before acting.
---
Resolution (Architect): Confirmed and accepted. Intended behavior = **re-sync on
reset** (AD-020): the reset point captures both the sim `StateBlob` and each
`RecordPlaybackSource`'s playback position, and `do_reset()` restores both, so the
dummy replays in sync every rep. Independent/"metronome" playback is out of slice
scope. **No tenet change needed** — I checked: the coordination lives in the
training-mode harness, which sits above the sim and owns both the runner and the
sources, so the sim still knows nothing about input sources (Tenet 2 holds); the
frame-indexed `InputSource` contract makes the rewind natural. Updated
`training-mode.md` (reset section + new acceptance criterion 12), tickets
TKT-P1-03/04, and added AD-020. So this did **not** route to the user — the seam
already permits a re-synced reset once the reset point includes source position.
---

### [resolved] 2026-07-01 · raised-by: Strategist · owner: Architect · re: /docs/tickets/ (missing P0 decomposition)
Problem: The P0 backbone has spec but no ticket decomposition — `/docs/tickets/`
contains only P1. `spec/README.md` pointed the Developer at TKT-P1-01, but every
P1 ticket depends on P0 deliverables (sim loop, `SimState`, `InputSource`,
inspection-surface stub) that have no tickets to build them by. The Developer's
role prompt says "build per the tickets"; a memory-less Developer session either
stalls or invents its own decomposition. Ask: decompose P0 into tickets
(interfaces-first, per your own seam ordering) before the Developer's first
session — this is the current blocker for development starting at all.
---
Resolution (Architect, 2026-07-02): Done — `/docs/tickets/p0-backbone.md`
decomposes P0 into **TKT-P0-01…11**, interfaces-first: the input contract (02)
and the inspection-surface stub (04) land as real interfaces before the pipeline
that fills them; the done-bar scenario (10) lands as soon as core resolution (07)
does; throws/multi-hit (08–09) complete the spec after the tenet proof; the
determinism/serialization hooks (11) come online with the sim loop, not at the
end. `spec/README.md` now points the Developer at **TKT-P0-01** as the first work.
---

### [resolved] 2026-07-01 · raised-by: Strategist · owner: Architect · re: /docs/spec/character-a.md (BnB routes contradict the frame data)
Problem: Two internal contradictions, checkable by the spec's own link arithmetic
(the same arithmetic that correctly yields the 5H link: window = on-hit advantage
− startup + 1 → 7 − 5 + 1 = 3). (a) Route 3 (`2L , 2L , 2M > 236H`) is impossible
as written: `2L , 2L`, claimed as a 1-frame link, computes to a **0-frame window**
(+3 hit adv vs 4f startup), and `2L , 2M` computes to **−2** (+3 vs 6f). Either
the hitstun table or the route is wrong. (b) Route 5 (`5M (CH) , 2M > 623L`)
depends on counterhit bonus stun, but no counterhit system exists anywhere in
`combat-resolution.md` or `move-format.md`. Fix the data or the routes; if
whether CH belongs in the slice is a design/scope question rather than a spec
gap, kick that part back to me. Note QA impact: criterion 10 ("each required
link window is non-empty") fails this spec as written.
---
Resolution (Architect, 2026-07-02): (a) Data fixed: `2L` hitstun 12 → **15**
(on-hit +3 → +6), making route 3 arithmetic-valid — `2L , 2L` = 3f window,
`2L , 2M` = 1f (the kit's hardest link; the old "1f" claim was misattributed to
`2L , 2L`). (b) Ruled + kicked: correct, no counterhit system exists in the
slice's combat resolution, and I won't grow P0 scope on my own authority — route
5 is removed, replaced with a DP-punish route; whether CH *should* enter the
slice is yours and is raised as a new flag below (owner: Strategist). Criterion
10's link arithmetic now checks out for every route.
---

### [resolved] 2026-07-01 · raised-by: Strategist · owner: Architect · re: /docs/spec/character-a.md (tuning values baked into acceptance criteria)
Problem: Acceptance criteria pin tuning-grade numbers: criterion 3 requires the
5H→5M link window be "exactly 3 frames," and criterion 2 requires derived frame
data "equal the tables" while the DP on-block values are approximate ("≈ −34").
These numbers were authored with no playable sim to feel them in; once one
exists, every tuning pass becomes a criterion failure requiring a flag
round-trip. Ask: re-shape the criteria to pin **structure** (the link exists and
is displayed; advantage derives from the one formula; the DP is full-punishable)
and mark the numeric tables **provisional until playable**, so QA can pass a
tuning change that preserves structure. The exact criterion shape is yours; the
provisional-numbers stance is mine and the user's.
---
Resolution (Architect, 2026-07-02): Adopted. `character-a.md` gains a **Tuning
status** stance — all numeric tables provisional until playable; structure is
binding. Criteria 2, 3, 4, 6 re-shaped to pin structure: derivation-consistency
via the one formula (not exact table values); the `5H` link non-empty, tight, and
displayed (3f is an authored target, provisional); `2H` invuln covering its
active frames and at-worst-slightly-minus; the DP full-punishable **by
construction** (even 25f `5H` punishes) rather than "≈ −34". AD-022's 9f/6f
buffer windows stay pinned — those are system constants, not character tuning.
---

### [resolved] 2026-07-01 · raised-by: Strategist · owner: Architect · re: /docs/spec/character-a.md + /docs/spec/README.md (character B pre-committed in spec)
Problem: Both docs stated character B's identity (gatlings + jump cancels, "per
the peek ahead"), but B's archetype is a roadmap open question owned by the
Strategist and deferred to the P2 brief. Root cause: the user steered A's numbers
in chat "to match up to a B like that"; the direction never landed in an owned
artifact, so the Architect recorded its understanding in the only place it could
— its own spec.
---
Resolution (user directive; edits applied by Strategist on the user's
instruction): Direct B references removed from both docs — A's "no gatlings / no
jump cancels" stance is unchanged and now points at "a later contrast character";
the user's actual leaning is recorded where direction lives (`roadmap.md` → open
questions). The protocol gains a **"direction lives upstream"** working agreement
so chat steers get routed to the owning artifact instead of recorded downstream.
Bundled user-directed hygiene edits, also applied by the Strategist: "awaiting
review" removed from `spec/README.md` status (no such gate exists in the
protocol); a one-line AD index added atop `decisions.md`; resolved flags moved to
`flags-archive.md`. Architect: on your next session, sanity-check that nothing
else in the spec leans on B's specifics, and re-own the touched files.
*(Architect, 2026-07-02: sanity-check done — remaining "later contrast
character" mentions state only A's negative space, not B's identity; touched
files re-owned. Relay complete; ready for archive.)*
---

---

### [resolved] 2026-07-02 · raised-by: Architect · owner: Strategist · re: /docs/briefs/character-a.md (counterhit: in or out of the slice?)
Problem: A's spec briefly leaned on counterhit bonus stun (removed — no CH system
in `combat-resolution.md`; Architect declined to grow P0 scope on its own
authority). CH is a genre-standard reward-for-reads layer, mechanically cheap to
add later (one bonus-stun rule; the move format's fields already suffice), but it
is new system scope and an added legibility surface (a CH cue is one more thing
the player must read in the moment).
---
Resolution (Strategist, 2026-07-02): **CH stays out of the slice.** The vertical
slice exists to prove the architecture, not to add breadth — and CH buys no
architectural proof while adding scope and a read-in-the-moment cue that cuts
against the charter's legibility standard. The move format already supports
adding it cheaply post-slice, so deferring costs nothing now and forecloses
nothing later. Not a P1/P2 brief line; revisit post-slice if a character's
identity actually needs it. Spec's standing assumption (no CH anywhere in the
slice) is correct as-is. Relay complete; archived.
---

### [resolved] 2026-07-02 · raised-by: QA · owner: Strategist · re: /docs/tickets/p0-backbone.md + roadmap "done-when" (TKT-P0-01 audit scope)
Problem: TKT-P0-01's "Acceptance" line names crit 5 and crit 9 as its bar, but the
majority of what makes the ticket's tenet-proof meaningful (purity, round-trip,
determinism) is correctly deferred to 03/11. Raised only so done-tracking is
explicit that "P0-01 passed audit" means its own reachable bar passed, not that
the determinism tenet is proven end-to-end.
---
Resolution (Strategist, 2026-07-02): **Closed as intended — no wording change.**
The roadmap's "done-when" for the P0 tenet-proof already lands on TKT-P0-10 (green
done-bar) + TKT-P0-11 (harness hooks green), not on 01 in isolation; the partial
coverage QA notes is the intended shape of an interfaces-first sequence. Recording
the resolution here is enough to keep done-tracking honest; no roadmap edit
warranted. Relay complete; archived.
---

### [resolved] 2026-07-02 · raised-by: QA · owner: Developer · re: game/sim/tick_host.gd (stale `SimSim`/`SimStim` identifier in seam comment)
Problem: The seam comments in `tick_host.gd` (and the JC-004 log) named the future
call `SimSim.step(...)` / `SimStim.step(...)`; the class landing at TKT-P0-03 is
`SimState`/`step`. Cosmetic doc drift flagged so the 03 developer isn't misled.
---
Resolution (owner, Developer, 2026-07-02): Fixed while closing the TKT-P0-03 seam.
`tick_host.gd` `_advance` now calls the real `SimState.step(state, in_p1, in_p2)`
and the comment names it correctly; zero `SimSim`/`SimStim` references remain in
`game/`. JC-004 log entry left as append-only history per supersede-don't-rewrite.
Relay complete; archived by Strategist.
---

### [resolved] 2026-07-02 · raised-by: QA · owner: Architect · re: /docs/spec/simulation.md + /docs/spec/input.md (produce-before-query ordering)
Problem: Specs required inputs be produced before the sim reads them (no future
reads) but didn't make the produce-before-query ordering an owned invariant or a
checkable acceptance criterion — in the scaffold it rested on Godot node tree
order (JC-009). Safe at runtime (sources + host assert against future reads) but
nothing for QA to statically verify the contract against. (F-001)
---
Resolution (Architect, 2026-07-02): FIXED. input.md now owns a "Produce-before-query
ordering (owned invariant)" clause — ordering owned by the *driver* (layer holding
sources + runner, per AD-020), not `step` and not the sources; sampling deliberately
NOT moved into the tick host (would couple it to concrete sources, breaking AD-002).
Added input.md acceptance criterion 7 so QA can assert it statically: (a) a source
faults on an unproduced-frame query; (b) the driver produces-then-advances. JC-009's
wiring-layer sampling ratified as one valid way to satisfy the invariant. Relay
complete; archived by Strategist.
---

### [resolved] 2026-07-02 · raised-by: Consultant (via user) · owner: Strategist · re: /docs/protocol.md (judgment-call ratification + judgment-log format)
Problem: The QA-gatekeeps proposal would route [impl]-tagged calls away from the Architect, but the current judgment log shows Developers can confidently under-classify contract-touching calls as latitude (JC-007 → AD-023; JC-002/006/009 upgraded). Adopting QA-routing now would rest safety on a gate with no track record and zero data on the mislabel rate. Proposed refinement (raise-only): add a Developer-only inert [impl]/[contract] tag ("unsure defaults to [contract]") to each judgment-log entry — recorded, acted on by no one — to accumulate a labelled dataset before any routing change is measured.
Context caveat: raised from chat; confirmed against live state (only P0 landed; JC-001..009 all ratified).
---
Resolution (Strategist): Deferred — not adopted, and correctly so. No change to judgment-call routing or ownership now; the regular Developer→Architect ratification loop stands for the remaining P0 push. The proposed inert [impl]/[contract] tag is a sound instrument, but recording it on *P0* calls builds the wrong dataset: P0 is foundational and contract-dense (companion flag, same date), so its labels cannot estimate a steady-state mislabel rate — and adopting the tag now pays a per-call cost against data already ruled unrepresentative. Decision: keep the flow unchanged; revisit the tag as instrumentation at the first non-foundational (P1) feature, where the ratio is representative and a meaningful labelled set can accumulate before any QA-verify/Architect-subset routing is measured against it. No role-prompt change. Adoption gate recorded in protocol.md ("Consolidate ownership passes"). Relay complete; archived by Strategist.
---

### [resolved] 2026-07-02 · raised-by: Consultant (via user) · owner: Strategist · re: /docs/protocol.md (Token economy — judgment-call review consolidation)
Problem: The proposal's ROI rests on pure-impl calls being "often the majority," but the only judgment log so far is the P0 backbone, which is contract-dense by nature — the Architect folded ~5 of 9 entries (JC-002/003/006/007/009) into spec. P0 lays foundational primitives, so its impl:contract ratio is not steady-state; adopting on that basis while paying the four-role-prompt rewrite could be net-negative. Proposed refinement (raise-only): before adopting, measure the [impl]:[contract] ratio on a non-foundational feature's judgment log and treat that — not P0 — as the adoption signal.
Context caveat: raised from chat; confirmed against live state.
---
Resolution (Strategist): Accepted and folded into the companion deferral above. The QA-gatekeeps consolidation is not adopted on P0 evidence. Agreed: P0's ~5/9 contract-fold ratio is foundational, not steady-state, and must not be the adoption signal. The adoption gate is now explicit and recorded — before any change to judgment-call routing, measure the [impl]:[contract] ratio on a *completed non-foundational (P1) feature* and treat that as the signal. Both flags resolve together; no protocol behavior change now beyond recording this standing gate. Relay complete; archived by Strategist.
---

### [resolved] 2026-07-03 · raised-by: Consultant (via user) · owner: Developer · re: game/sim/inspection_view.gd + game/tests/test_inspection_view.gd
Problem (F-006): test_inspection_view fails 1 of 21 checks — "PlayerView.hitstop_remaining reads state" got 2, expected 3. Unresolved whether the sim/view decrements hitstop at the wrong phase point or the test's expected constant is stale.
---
Resolution (Developer): STALE TEST EXPECTATION — sim/view correct; fix TEST-ONLY. `_test_core_reads` pre-sets `players[0].hitstop = 3` on the tick-0 state, then calls `step` once. `was_frozen[0]` is true (already active at tick start), so phase 7 decrements 3→2. Per combat-resolution.md crit 4 / AD-010, hitstop is countdown state advanced one tick per step, so 2 is spec-correct after one step; `3` forgot the step's tick advance (this is the plain pre-existing-hitstop countdown, not the contact-tick freshly-set edge in the raise's framing). `PlayerView.hitstop_remaining` is a verbatim single-source read. Fix: assert `pv.hitstop_remaining == s.players[0].hitstop` plus pinned literal `2`; sim untouched. JC-020. Boundary held (F-006 only; 08/09 untouched). Relay complete; archived by Strategist.
---

### [resolved] 2026-07-03 · raised-by: Consultant (via user) · owner: Developer · re: game/tests/test_combat.gd (lines 248–251)
Problem (F-007): test_combat.gd fails to load — StepPhases.has_method(...) called on the class directly, rejected by Godot 4 for a non-static function. The parse failure blocks the whole file, so none of the phase-pipeline checks run.
---
Resolution (Developer): CONFIRMED — TEST-ONLY parse fix. `StepPhases` is an all-static namespace module (JC-013); `Object.has_method` is a non-static instance method, so calling it on the class reference is rejected and the parse failure blocked the file. Fix: the four "phase N is a named function" structural checks now use `Callable(StepPhases, "phaseN").is_valid()` (parses cleanly, true iff the static function exists), matching the `Callable.is_valid()` idiom in `local_device_source.gd`. No sim code touched. JC-021. Boundary held (test-only). All of test_combat's phase-pipeline checks now run. Relay complete; archived by Strategist.
---

### [resolved] 2026-07-02 · raised-by: Developer · owner: Architect · re: /docs/spec/simulation.md (SimState shape), inspection-surface.md
**Problem (F-002): the inspection surface contract requires sim-state fields the
SimState table does not name.** inspection-surface.md's `PlayerView` and
`InspectionView` enumerate `character_id`, `stun_kind`, combo `damage_total`, and
`last_hit()` as required reads, and `AdvantageView.neutral_restored` requires a
per-tick "both became actionable this tick" flag (combat-resolution.md criterion 5,
"not before, not after"). But simulation.md's SimState / players[i] table lists
none of these. To make the required reads readable AND deterministic (survive
snapshot/restore, be covered by the canonical hash — AD-023 total coverage), I
added them to serialized state:
  - `players[i].character_id` (int) — which Character this player is; box/frame
    resolution and PlayerView.character_id need it.
  - `players[i].stun_kind` (int 0/1/2 none/hit/block) — backs PlayerView.stun_kind.
  - `players[i].combo_damage` (int) — backs PlayerView.combo.damage_total.
  - `last_hit` (HitRecord | null) — backs InspectionView.last_hit(); a plain
    serialized record, not the HitEvent view.
  - `neutral_restored_this_tick` (bool) — the phase-6 neutral-restored edge flag
    AdvantageView.neutral_restored reads.
All are serialized (to_dict/from_dict), deep-cloned, and folded into hash_state in
fixed order (a presence flag precedes the variable-length `last_hit` per AD-023).
This is a change to an owned contract (the SimState shape), so I am flagging rather
than treating it as latitude: the fields are a genuine gap the inspection contract
already implies, but their names/types/serialization belong in simulation.md's
table for QA and future work to build against. **Requested resolution:** ratify
these fields into the simulation.md SimState/players table (or correct their
shape), and note last_hit's canonical-hash treatment in AD-023's covered set.
---
Resolution (Architect, 2026-07-03): **Ratified into the SimState tables.** All five
fields are folded into `simulation.md`'s SimState-root / `players[i]` tables with
names/types/serialization/hash treatment, and recorded in **AD-024** (the
inspection-backing-fields half). `last_hit`'s canonical-hash treatment is pinned in
AD-024 and the SimState-root table: folded behind a presence flag (0/1) so no-hit vs.
hit states cannot collide, then its integer fields in fixed `HASH_FIELDS` order —
this is its coverage under AD-023's total-coverage rule. `neutral_restored_this_tick`
is additionally governed by AD-025 (rising-edge semantics). Implementation as written
(sim_state.gd, player_state.gd, hit_record.gd) matches the ratified shape — no code
change required. Also settled forward: `simulation.md` now states the SimState table
is **extensible-as-systems-land** (not presumed-complete), with the bar for a table
addition, so 08/09/P1 additions have a defined home instead of each re-becoming a flag.

### [resolved] 2026-07-02 · raised-by: Developer · owner: Architect · re: /docs/spec/simulation.md (how the pure `step` reaches authored move data)
**Problem (F-004): the pure `step(state, in1, in2)` must resolve authored move data
(box geometry, transitions, frame data), but the simulation.md `step` contract names
only `(state, in1, in2)` — it does not say how the sim reaches the character roster.**
This is a data-access model QA and future devs build against, and it is
determinism-relevant (the sim must read the SAME authored data every tick for
`step` to stay a pure function of its named inputs), so it is contract-adjacent
rather than pure latitude. Two reasonable models: (a) a process-wide immutable
static roster the sim reads (`MoveRegistry`, set once at match/scenario wiring,
never mutated mid-run — the same "authored content is a fixed input, not sim state"
reasoning that keeps input SOURCES external and out of SimState); (b) threading the
roster through `step` as an explicit parameter, so the data dependency is visible in
the signature. I implemented **(a)** — `MoveRegistry` is a static namespace over one
immutable roster, installed at wiring, read by `step`'s phase pipeline and by the
inspection surface. Rationale for (a): it keeps `step`'s signature exactly the
simulation.md contract (`state, in1, in2`), matches AD-001's "SimState is the
minimal MUTABLE graph — authored content is not sim state," and mirrors how input
sources live outside SimState; a snapshot/restore/replay reproduces identically
because the same immutable roster is present and carries no per-tick state to
serialize. The risk (a) carries: a process-wide static is global state, so a
mis-wired or mid-run-mutated roster is a determinism hazard the type system does not
prevent (mitigated: `install` is documented once-at-wiring, `clear` is test-only).
**Build-on-as-is note:** the prior session created `MoveRegistry` citing this flag
but did not record it here; I am recording it now and building 06/07/10 on model
(a). **Requested resolution:** ratify the roster-access model into simulation.md
(name it as the sim's authored-data source, or specify threading it through `step`
instead) so the data-access contract is owned, not an implementation accident. If
the Architect prefers (b), it is a localized change at `step`, the phase pipeline
entry, and the inspection surface — no phase logic changes.
---
Resolution (Architect, 2026-07-03): **Ratified model (a) — `MoveRegistry`, the
process-wide immutable roster.** Recorded in **AD-024** (the authored-data-model
half) and named in `simulation.md`'s step-function section as the sim's
authored-data source: `step`'s signature stays `(state, in_p1, in_p2)`; the roster
is installed once at wiring, never mutated mid-run; `players[i].character_id` is the
resolution key. Model (b) (threading the roster through `step`) rejected — it changes
the contract signature for no determinism gain, since the immutable-roster invariant
already gives the same guarantee. The global-static risk is recorded in AD-024 as a
wiring-layer contract (install-once, `clear` test-only) and flagged for QA to assert
(roster installed before first `step`, unchanged across a run). Implementation
(move_registry.gd) matches — no code change required.

### [resolved] 2026-07-02 · raised-by: Developer · owner: Architect · re: /docs/spec/combat-resolution.md, simulation.md (AD-012 AABB overlap)
**Problem (F-003): the AABB overlap convention (touching edges) is unpinned but is
determinism- and feel-relevant.** AD-012 / simulation.md fix that overlap is "our
own AABB test" on fixed-point integers, but do not state whether boxes that merely
TOUCH (share an edge: `a.x + a.w == b.x`) count as overlapping. This decides
whether a hit lands at exact adjacency — a hit/no-hit outcome content and QA
goldens depend on. I implemented STRICT overlap (touching edges do NOT overlap;
`ResolvedBox.overlaps` uses strict `<`/`>`), which is the common fighting-game
convention and keeps a box exactly adjacent to a hurtbox from registering. Raising
rather than logging as latitude because it is a resolution rule multiple roles
build against and could read materially differently. **Requested resolution:** pin
the touching-edge convention (strict vs. inclusive) in combat-resolution.md so it
is an owned rule, not an implementation accident. If strict is wrong for feel, that
is a one-line change in `ResolvedBox.overlaps`.
---
Resolution (Architect, 2026-07-03): **Ratified STRICT — pinned as an owned rule.**
Recorded in **AD-027** and stated in `combat-resolution.md` phase 4: boxes that
merely touch (share an edge) do not overlap; a box exactly adjacent to a hurtbox does
not register. Strict is the fighting-game convention and matches how box geometry is
authored (reaching *to* an edge is not reaching *into* it). Inclusive is a legitimate
feel alternative but off-convention; if feel ever wants it, that is a revision to
AD-027 plus the one-line `ResolvedBox.overlaps` change, not a silent edit.
Implementation (resolved_box.gd, strict `<`/`>`) matches — no code change required.

### [resolved] 2026-07-02 · raised-by: Developer · owner: Architect · re: /docs/spec/simulation.md (SimState shape), combat-resolution.md (single-hit)
**Problem (F-005): single-hit integrity ACROSS active frames needs per-attacker memory
of which id_groups have already connected, which is not a field the SimState table
names.** combat-resolution.md criterion 6 / move-format.md criterion 5 require a
multi-box attack in one `id_group` to register ONE hit, and AD-016 states "one hit per
group per contact" with `rehit_interval` unset ⇒ "one hit per contact." A hitbox is
active for its whole active window (the test move's 3 active frames); without memory of
"this id_group already hit this move," the SAME hitbox re-connects on every active
frame (and every frozen hitstop tick), registering 2–3 hits instead of one and
inflating the combo count — which breaks the done-bar's "one hit" assertion. To make
single-hit deterministic (survive snapshot/restore, be covered by the canonical hash),
I added a serialized field:
  - `players[i].active_hit_ids` (`PackedInt32Array`) — the hitbox `id_group`s that have
    already connected during this player's CURRENT move (as attacker). A hitbox whose
    id_group is present does not re-hit (rehit_interval == 0). Cleared on every state
    entry (a new move is a new contact). Cadenced re-hit (rehit_interval > 0) is
    TKT-P0-09 and will consult this same set with an interval.
It is serialized (to_dict/from_dict), deep-copied (clone), and folded into hash_state as
an order-committing variable-length run (size then each id, AD-023 total coverage).
This is a change to the owned SimState shape (like F-002), so I flag rather than treat
as latitude. **Requested resolution:** ratify `active_hit_ids` into the simulation.md
players table (name/type/serialization) and note its canonical-hash treatment, or
specify a different single-hit-tracking model (e.g. keyed on the last_hit record, or a
per-move-instance token). The single-hit MECHANISM is spec-required; only where the
tracking state lives is the contract question.
---
Resolution (Architect, 2026-07-03): **Ratified `active_hit_ids` into the SimState
players table.** Recorded in **AD-026** and folded into `simulation.md`'s `players[i]`
table (name `active_hit_ids`, type `PackedInt32Array`, serialized/cloned/hashed as a
variable-length count-then-ids run per AD-023) and cited in `combat-resolution.md`'s
multi-hit section + `move-format.md` criterion 5. The tracking model is correct:
per-attacker, cleared on every state entry (a new move is a new contact), consulted
with an interval by cadenced re-hit (TKT-P0-09). Alternatives rejected in AD-026
(keying on `last_hit` couples per-target tracking to one global record; a non-state
token would not survive restore). Implementation (player_state.gd, hash fold in
sim_state.gd) matches — no code change required. Same "extensible-as-systems-land"
note as F-002 applies: this is a ratified table addition under the stated bar, not a
new class of flag.
### [resolved] 2026-07-03 · raised-by: QA · owner: Developer · re: game/tests (AD-027 strict overlap)
Problem (F-008): No test pins the AD-027 strict-overlap boundary at exact adjacency. `ResolvedBox.overlaps` is correct (strict `<`/`>`), but nothing locks touching-edge = no-hit against a future accidental flip to `<=`/`>=`. Add a boundary golden: boxes at `a.x + a.w == b.x` do NOT overlap; a 1-subunit penetration DOES. Test-tooling only; non-blocking.
---
Resolution (Developer, 2026-07-03): Added `game/tests/test_overlap_boundary.gd` — a headless SceneTree runner (JC-005 pattern) pinning the AD-027 boundary on BOTH axes and the corner: exact edge touch (`a.x+a.w == b.x`, `a.y+a.h == b.y`, corner-to-corner) does NOT overlap; a 1-subunit penetration DOES; a 1-subunit gap does NOT (bracketing the boundary from both sides so the strict test is not vacuously passing). No sim code touched — `ResolvedBox.overlaps` was already correct; this locks it against a future `<`→`<=` flip. Relay complete; archived by Strategist.
---

### [resolved] 2026-07-03 · F-011 · raised-by: Consultant (via user) · owner: Developer · re: game/sim/cancel_eval.gd + game/tests/test_buffer_cancels.gd (cancel/requires_tag)
Problem: test_buffer_cancels fails 1 of 26 checks — a whiffed LIGHT grants no cancel tag, so BUTTON_1's special-cancel should be gated by requires_tag, but the check got true (cancel allowed) where false expected. Framed as: the requires_tag gate not being enforced (whiffed normal permits the special-cancel).
---
Resolution (Developer, 2026-07-03): NOT a sim bug — "gate not enforced" premise corrected. `cancel_eval.gd::find_cancel` enforces requires_tag correctly, and for a whiffed LIGHT the ON_CONTACT condition ALSO rejects the cancel (`move_contact == CONTACT_WHIFF`, set step_phases phase 2). The cancel never leaked. Real cause: a CONTAMINATED TEST SCENARIO — SPECIAL is directly reachable from neutral via the BUTTON_1 button_map entry (`test_support.gd _map(1,0,0,STATE_SPECIAL)`), so feeding BUTTON_1 for 20 ticks let the whiffed LIGHT recover to idle and then enter SPECIAL via the ordinary neutral-press path — correct behavior, misread as a leaked cancel. Fix (test-only, sim untouched): `_test_cancel_requires_tag` now feeds/asserts BUTTON_1 only while LIGHT is a COMMITTED move (the sole path to SPECIAL there is the tag-gated cancel), plus a liveness assertion so it can't pass vacuously. JC-026 (provisional). Check count 26→27. Boundary held (F-009/F-010 untouched, no P1). Relay complete; archived by Strategist.
---

### [resolved] 2026-07-03 · raised-by: QA · owner: Architect · re: /docs/spec/simulation.md (AD-024)
Problem: AD-024 states the immutable-roster / install-once determinism precondition
(MoveRegistry), but no acceptance criterion gives QA something to *assert* it
against — it rests on wiring discipline (the code is compliant) plus a QA harness
watch item. The type system does not prevent a mid-run `install()`/`clear()`, which
would be a silent determinism break. Ask: should install-once / immutable-across-a-
run be a stated, checkable invariant (as F-001 did for produce-before-query ordering
→ input.md crit 7), so the precondition is verifiable rather than only conventional?
Spec-observability question, not an implementation bug; non-blocking (F-009).
---
Resolution (Architect, 2026-07-03): **Made a stated, checkable invariant** — the F-001
precedent, applied. The `MoveRegistry` exposes an **install-generation token** (a monotonic
counter bumped on every `install`/`clear`); the owned invariant is *the token observed at a
run's first `step` is identical at every subsequent `step` of that run*, so a mid-run
mutation is detectable, not silent. Folded into **AD-024** (Risk paragraph, now
"checkable invariant") and surfaced as **simulation.md acceptance criterion 11** so QA
asserts it rather than only watching for it. The token is wiring/precondition state, NOT
`SimState` — deliberately not serialized/hashed (it is the fixed-content precondition
AD-024 keeps out of state, Tenet 2/AD-001), but observable. Per-run, not per-process: a
test's `clear`+`install` starts a fresh run whose token is re-captured. **For the
Developer:** if the `MoveRegistry` does not yet expose an install-generation token, add
one (monotonic, bumped on install/clear) — a localized addition; the invariant text and
crit 11 name the observable QA needs. Non-blocking to batch-2 landing.

### [resolved] 2026-07-03 · raised-by: Developer · owner: Architect · re: /docs/spec/simulation.md (SimState table — TKT-P0-08/09 fields)
Problem (raise-only — a SimState *shape* addition, so a contract change I flag, not
latitude — per AD-024 "extensible-as-systems-land … added here under an AD at the
ratification pass" and the F-002/F-005 precedent). TKT-P0-08 (input buffer + cancels)
and TKT-P0-09 (throws + multi-hit/rehit) each need new MUTABLE, per-tick sim truth
that must survive snapshot/restore and be canonically hashed (AD-023). All are
serialized (`to_dict`/`from_dict`), deep-cloned (`clone`), and covered by the hash in
fixed field order; variable-length runs fold a count separator first (AD-023). Five
new `players[i]` fields, grouped by the ticket that introduces each:

TKT-P0-08 (cancels; AD-015/017/022):
  - `cancel_tags: PackedInt32Array` — cancel tags granted to THIS player (as attacker)
    by a connecting hitbox in phase 5 of tick T, consumable by the cancel phase (phase 2)
    starting T+1 (AD-017 grant→consume latency — because phase 2 precedes phase 5, a tag
    set in phase 5 of T is first visible to phase 2 of T+1 for free). Cleared on every
    state entry (a new move's tags are its own). Hashed as a variable-length run
    (count-then-tags, order-committing).
  - `move_contact: int` — the outcome of this player's CURRENT move for CancelRule
    `condition` evaluation: 0 none / 1 hit / 2 block / 3 whiff-resolved. Set on the
    ATTACKER in phase 5 on connect (hit/block); set to whiff once the move's last active
    frame passes with no connect (so `on_whiff` cancels can fire). Cleared on state entry.
    Plain int. (An `on_contact` cancel matches contact == hit OR block.)

TKT-P0-09 (throws + rehit; AD-016):
  - `active_hit_frames: PackedInt32Array` — PARALLEL to `active_hit_ids` (AD-026): index
    i holds the tick `active_hit_ids[i]` last connected, so a `rehit_interval` hitbox can
    cadence (re-hit only once `rehit_interval` frames have elapsed since the last connect
    of that id_group). Same variable-length-run hash treatment as `active_hit_ids`;
    cleared on state entry alongside it (they stay length-synced).
  - `throw_tech_window: int` — frames remaining in which the thrown DEFENDER may tech
    (input a throw to escape to neutral, no damage — AD-016). Set on throw connect,
    decremented in phase 7 (not frozen by hitstop — a throw connect sets no mutual
    hitstop at P0). 0 = not in a tech window. Plain int.
  - `thrown_by: int` — the attacker index that threw this player (for tech resolution /
    combo attribution), or -1 if not thrown. Set on throw connect, cleared when the tech
    window closes or the throw resolves. Plain int.

Ask: ratify these five into the simulation.md SimState per-player table under an AD
(as AD-024 folded F-002 and AD-026 folded F-005), or prefer a different shape (e.g.
throw state on a nested record, or deriving `move_contact` from `last_hit` rather than
a per-attacker field — I chose a per-attacker field because `last_hit` is a single
global record and cannot express two attackers' independent contact outcomes, mirroring
why AD-026 rejected keying single-hit on `last_hit`). Implemented now so 08/09 land and
tests run; provisional until ratified. Non-blocking to the batch; a shape change is a
localized edit to PlayerState + the hash.
---
Resolution (Architect, 2026-07-03): **Ratified all five into the simulation.md per-player
table under AD-028**, in the exact shape built and validated on Godot (all 12 test files
pass; verified against `player_state.gd` serialize/clone + `sim_state.gd` hash walk — the
three PackedInt32Arrays fold count-first, order-committing per AD-023; the two plain ints
fold in fixed order). The Developer's shape reasoning is accepted verbatim: `move_contact`
is per-attacker (not derived from the single global `last_hit`) and `active_hit_frames` is a
per-`id_group` parallel run (not a single last-hit tick), each mirroring AD-026's reason a
global record can't express two attackers' independent outcomes. No alternate shape preferred
— the flat per-attacker fields + parallel run are the minimal correct home and keep the hash
a simple order-committing run. This is the F-002/F-005 precedent at the batch-2 pass: a
SimState *shape* addition is a flag ratified under an AD, never dev latitude. The cadence
logic (JC-025) and clash detection that consume these fields are ratified separately as
latitude. No code change required — implementation already matches AD-028.

### [resolved] 2026-07-03 · raised-by: QA · owner: Developer · re: /game/tests/test_throws_multihit.gd
Problem: `_test_simultaneous_throw_clash` can pass VACUOUSLY. It asserts only that
neither player is in `STATE_THROWN` and neither took damage — both of which are
equally true for a correct clash AND for throws that never connect (a broken
button map, drifted throwbox geometry, or an accidental early return would still
pass). There is no positive liveness check that both players reached `STATE_THROW`,
that the throwboxes reached their active window, or that a clash was actually
detected. This is the F-011 lineage (a green test that hides drift by asserting the
absence of the wrong thing). The SIM clash behavior is correct (traced: geometry
strictly overlaps, `_both_throwboxes_connect` → `_resolve_throw_clash` runs) — only
the test is weak, so the clash arm of combat-resolution.md crit 10 is not yet
locked by a self-verifying test. Fix: add a positive liveness assertion (both
reached `STATE_THROW`; the clash path ran / both throwboxes hit their active
window). Non-blocking; does not gate the P0 milestone.
---
Resolution: Strengthened `_test_simultaneous_throw_clash` in
game/tests/test_throws_multihit.gd with positive liveness assertions, added
immediately after the throw-input tick and before the clash-detection loop:
(1) both `s.players[0].state_id` and `s.players[1].state_id` equal
`STATE_THROW` (both attempts are live, not whiffed/blocked by a button-map or
geometry regression), and (2) both players' `frame_in_state` is within 1..3,
the throwbox's authored active window (`TestSupport._build_throw`) — i.e. the
throwboxes are actually on their active frames when the clash is checked.
Also added a proof the clash path itself ran (not just "throws never
connected"): captured `separation` between the two players' `pos_x` before the
throw-input tick and again after the clash resolves, and asserted it strictly
increased — `_resolve_throw_clash` (game/sim/step_phases.gd) applies a
deterministic symmetric pushback keyed off the throw hitbox's `pushback_hit`,
so a real clash is now independently observable via position, not just via
the absence of `STATE_THROWN`/damage.

Fixture gap found and fixed along the way: `TestSupport._build_throw()`
(game/tests/test_support.gd) never set `pushback_hit` on the throwbox (default
0), so `_resolve_throw_clash`'s pushback was a no-op in this fixture — the sim
was correct, but there was nothing to observe. Added
`THROW_PUSHBACK: float = 3.0` and set `tb.pushback_hit =
FP.from_units(THROW_PUSHBACK)` in `_build_throw()`. Verified this only affects
`_resolve_throw_clash` (the only reader of `pushback_hit` on a throwbox —
`_resolve_throw`, the single-throw connect path, never reads it) and that no
other test file exercises the throw command, so the other two throw scenarios
(`_test_throw_bypasses_block`, `_test_throw_tech_to_neutral`) and all other
test files are unaffected.

Verified: `"E:\Godot 4.3\Godot_v4.3-stable_win64.exe" --headless --path game -s
res://tests/test_throws_multihit.gd` → `[test_throws_multihit] OK — 17 checks
passed` (up from 12; 5 new assertions). Also re-ran test_combat (56 OK),
test_buffer_cancels (49 OK), test_inspection_view (22 OK), and test_done_bar
(34 OK) to confirm the shared fixture change caused no regressions elsewhere.
The clash arm of combat-resolution.md crit 10 is now locked by a
self-verifying (non-vacuous) test.
---

### [resolved] 2026-07-03 · raised-by: QA · owner: Architect · re: /docs/spec/inspection-surface.md
Problem: batch 2 (TKT-P0-08/09, AD-028) added mutable, legibility-relevant
serialized `SimState` state — `throw_tech_window`, `thrown_by`, `move_contact`,
`cancel_tags` — but NONE of it is surfaced through the inspection seam: the
`inspection-surface.md` `PlayerView` table does not list these fields, so the debug
training mode reading through `InspectionView`/`PlayerView` has no way to observe
whether a defender is in a tech window (and how many frames remain), who threw
them, or that a cancel window is open. This is observable-in-principle (it is in
serialized, hashed state) but not actually surfaced through the seam — the drift
the milestone sweep targets. The charter's north star is "you can find out what
happened and why, every time," and the audit criterion's backstop is that the
training mode is where "what just happened?" always has an answer; throws and
cancels being discoverable is a charter-legibility surface. This is NOT an
implementation bug — `PlayerView` faithfully implements the current (spec-owned)
table — so it routes to the Architect (spec owner), parallel to F-002 (inspection
reads were a spec gap the build surfaced). Question: should the surface expose the
batch-2 tech-window / cancel-window state, and is that P0 or P1 (TKT-P1-01 completes
the surface)? Non-blocking — the full inspection-surface implementation is
explicitly TKT-P1-01 and no P0 acceptance criterion requires these reads; it does
not gate the P0 milestone. Surfaced (legibility judgment), not adjudicated, per QA's
subjective-handling role.
---
Resolution (owner fills): FIXED — surface these fields. The four batch-2 fields are
legibility-relevant sim truth and belong on the seam; leaving them observable-in-
principle-only is exactly the drift the charter's "find out what happened, every time"
forbids, and AD-011 makes the seam the *single* read surface for sim truth (F-002
precedent, AD-024). Added to `inspection-surface.md` → `PlayerView`: `move_contact`
(int enum none/hit/block/whiff, mirrors `PlayerState.CONTACT_*`), `cancel_tags`
(`PackedInt32Array`; non-empty ⇒ open cancel window), `throw_tech_window` (int; >0 ⇒
live tech frames left), `thrown_by` (int; -1 ⇒ not thrown). All plain int / int-array
truth — no floats, so AD-019 snapshot discipline is untouched — surfaced read-only as a
projection of existing `SimState` fields (no re-derivation). Scope: **P1, TKT-P1-01**
(the concrete `InspectionView` read API) — no P0 criterion needs it and the surface
first materializes in P1; ticket scope + acceptance criterion 1 (traceability) updated
to name these reads. No new AD (shapes are AD-028; the surface is AD-011); consequence
note appended under AD-028. Confirmed the four names/types against
`game/sim/player_state.gd`.
---

### [resolved] 2026-07-04 · raised-by: Developer · owner: Architect · re: move-format.md (Keyframe.invuln) / combat-resolution.md (phase 4/5)
Problem: `character-a.md` structurally requires invulnerability to be a real, enforced
mechanic — `2H` "upper-body strike invuln 1–8" beating a jump-in (criterion 4), each DP
"strike-invulnerable from frame 1 through at least its first active frame" and `623H`
"also throw-invulnerable" (criterion 6), and back dash "invuln 1–7 (strike+throw)"
(Movement table) — but the engine has no consumption path for invulnerability at all.
`Keyframe.invuln_strike` / `invuln_throw` (move-format.md → Keyframe) are authored fields
only: nothing in `step_phases.gd` reads them. Phase 4 (`phase4_overlap`) records a contact
whenever an attacker's hitbox/throwbox overlaps a defender's hurtbox, with no check against
the defender's own invuln state; phase 5 resolves every such contact as hit-or-block. There
is also no notion of a "throw" vs "strike" hit *category* on `HitBox` to gate throw-invuln
against (only the `is_throw` flag, which marks the attacking box, not what a defender is
immune to). This is a genuine format/engine gap, not a per-move authoring choice — I can
author the `invuln_strike`/`invuln_throw` flags on A's keyframes (DP, `2H`, back dash) so
the data is ready, but they will be **inert**: nothing in the sim will make those frames
actually whiff an incoming hit, so criteria 4 and 6 (and the back dash's invuln) cannot
pass end-to-end until this is resolved. Per the ticket ("no engine changes... if you find
yourself needing an engine change to author a move, that's a spec/format gap — flag it"),
raising rather than adding ad hoc consumption code myself, since this touches phase 4/5
(a contract multiple roles build against) and needs a real design (does invuln fully
prevent the contact from being recorded, or does it record-but-no-op; does a `HitBox` need
a `hit_kind` — strike/throw/projectile — to check the right invuln flag against; how does
this interact with projectile contacts, which bypass the character's active-hit-id memory
entirely).
---
Resolution (owner, Architect, 2026-07-04): Resolved as **AD-031**. Invuln becomes an
enforced mechanic, **consumed in phase 4** (a gated overlap is not appended to the contact
list — the box whiffs), *not* record-then-no-op in phase 5 (which would force phase 5 to
un-do id_group/throw-clash/combo bookkeeping — the clean cut is to not record). `HitBox`
gains a **`hit_kind` (STRIKE/THROW/PROJECTILE)**: `invuln_strike` whiffs STRIKE **and**
PROJECTILE (a projectile is a strike at range); `invuln_throw` whiffs THROW; the legacy
`is_throw` is folded to `hit_kind == THROW`. **Projectiles gate but are not consumed** —
a projectile whiffed by invuln passes through and may connect on a later vulnerable frame.
The gate reads the defender's covering keyframe (derived, AD-001 — **no new SimState
field**). The whiff is **observable**: the attacker's `move_contact` resolves to WHIFF on
the existing whiff edge, and the defender's invuln is surfaced as `PlayerView.invuln`
(derived), so the training mode shows *why* a hit whiffed (charter). Specs changed:
`combat-resolution.md` (phase 4 + Invulnerability section + criterion 12), `move-format.md`
(`HitBox.hit_kind`, `Keyframe.invuln`), `inspection-surface.md` (`PlayerView.invuln` +
criterion 1). Engine implementation is the Developer's — **ticket TKT-P1-11**. Overlay
sequencing: the invuln read is a derived projection, surfaceable in TKT-P1-01 with no
dependency on the phase-4 change; full whiff-attribution display verifies once TKT-P1-11
lands, but overlay UI can be built in parallel against the read (see report).
---

### [resolved] 2026-07-04 · raised-by: Developer · owner: Architect · re: move-format.md (ButtonMapEntry) / input_buffer.gd (command recognition)
Problem: authoring character A's movement and throw surfaced two commands the current
command-recognition schema (`ButtonMapEntry` + `InputBuffer`) cannot express:
1. **A pure-direction command (jump, `7/8/9`).** `InputBuffer.button_buffered` returns
   `false` outright when `button_index < 0` ("no button"), so a directionless command has
   no recognition path at all. A jump could in principle be authored as a one-token
   "UP" `motion` (the schema already lets a motion-only entry trigger with no button, per
   `InputBuffer.entry_satisfied`'s `button_index < 0` branch for motions), but the token
   vocabulary (`InputBuffer._motion_tokens`) is a fixed `match` over `MOTION_236`/
   `MOTION_623` in `input_buffer.gd` — adding a jump motion id means editing engine code,
   which this ticket may not do.
2. **A two-button chord (throw, `L+H`).** `ButtonMapEntry` names exactly one button bit
   (`button_index`) plus a *direction* gate (`required_direction`, which only inspects
   direction bits, never button bits) — there is no way to require two buttons at once.
   Unlike jump, there is no safe single-button stand-in for A: all three buttons already
   have standing normals (`5L`/`5M`/`5H`), and `button_map` resolves first-match-wins, so
   aliasing the throw to any bare button would permanently shadow that normal (I checked —
   authoring it on `BUTTON_2` alone makes `5H`, load-bearing for the kit's 3-frame-link
   route, unreachable).
Both are authored as real `MoveState`s with full frame data (`STATE_PREJUMP`/`STATE_JUMP_*`
in `game/content/character_a.gd`'s jump arc; `STATE_THROW` with its throwbox/tech-window/
knockdown) — the content is ready — but neither has a `button_map` entry in this batch, so
neither is reachable by a live input stream. Dev tests exercise both by driving a player
directly into the state (so the throw's connect/tech/knockdown *resolution* and the jump
arc's *keyframe motion* are still verified), but "press up to jump" / "press L+H to throw"
are not yet playable end-to-end. Per the ticket, flagging rather than editing
`input_buffer.gd`/`ButtonMapEntry` myself, since both are contract surface
(`move-format.md`) other content and the training-mode input-display ticket (TKT-P1-09)
will read through.
---
Resolution (owner, Architect, 2026-07-04): Resolved as **AD-032**. The command-recognition
schema is extended for both shapes. **Pure-direction command (jump):** a `ButtonMapEntry`
with `button_index == -1` and `motion == 0` is recognized by its `required_direction` alone
(held within the 6-frame command buffer) — jump = `UP`, no button. A jump is a held
direction, **not** a new `_motion_tokens` sequence (keeping that fixed `match` reserved for
real multi-direction motions). **Two-button chord (throw):** `ButtonMapEntry` gains
`chord_button_index` (`-1` = none); when set the command requires `button_index` **and**
`chord_button_index` on the **same** frame (not merely both somewhere in the window).
**Shadowing rule:** the chord entry is authored **before** the bare-button normals it shares
a button with, so `L+H` resolves to the throw while a bare `L`/`M`/`H` still reaches
`5L`/`5M`/`5H` (a bare press does not satisfy the two-bit-same-frame chord) — the throw is
reachable without stealing a bare button. Specs changed: `move-format.md` (new
`ButtonMapEntry` schema section + command-recognition contract). Engine implementation is
the Developer's — **ticket TKT-P1-12** (adds the `chord_button_index` field + the two
recognizer branches, then authors A's jump/throw `button_map` entries). Read by TKT-P1-09
(input display): the recognizer stays a pure function of `input_history`, so the display
decodes jump/throw/chord from the same raw frames — kept legible.
---

### [resolved] F-014 · 2026-07-04 · raised-by: Architect · owner: Strategist · re: roadmap scope — height-dependent air-normal advantage mechanism
Problem (a scope question I own the *technical* half of but not the *whether/when*):
ratifying JC-A-04 surfaced that `character-a.md` promises air normals' ground advantage is
**height-dependent** ("deep jump-in = very plus, enabling the grounded links … sim truth the
training mode reads out, not a fixed number"), and routes 2 (`j.H , 5M > 623M`) and the
"deep = very +" note lean on it. But **no engine mechanism computes height-dependent
hitstun/advantage** — air-normal hitstun is authored as one flat value (JC-A-04, correctly,
since the `HitBox` schema has no per-height field and the spec locates height-dependence in
*live sim behavior*, not authored data). So today a `j.H` gives a *flat* advantage regardless
of contact height: the grounded links off a jump-in are structurally authored but not yet
height-varying. This is not an authoring gap (JC-A-04 authored the right flat value) and not
a move-format gap I can close by adding a field (height-dependence is a *resolution*
behavior — advantage as a function of the defender's y at contact — not an authored
constant). It is a **P-scope question: is the height-dependent air-advantage mechanism in
P1's done-bar, or deferred?** If in P1, I will spec it (a phase-5 rule: air-normal hitstun/
advantage scales with contact height, surfaced live through the inspection seam — a real
combat-resolution design and its own engine ticket, sibling to TKT-P1-11's invuln work). If
deferred, `character-a.md`'s "height-dependent" language and route 2's "deep = very +" should
be marked provisional/deferred so QA does not audit A against a mechanism the slice doesn't
yet build (criterion 10's "deals damage in the stated ballpark" is unaffected; only the
*height-varying* clause is). Raising rather than deciding scope myself, per the session's
instruction (scope/whether-a-mechanic-is-in-P1 is the Strategist's). The invuln and
command-schema flags this session are unaffected — this is a separate, narrower question that
JC-A-04's ratification made visible.
---
Resolution (owner, Strategist, 2026-07-04): **In P1.** Height-dependent air-normal advantage
is in P1's done-bar, not deferred. Three reasons: (1) it is already in `character-a.md` and
route 2 (`j.H , 5M > 623M`) leans on it — deferring would leave character A incomplete to its
own criteria and make a specified combo route only structurally (not behaviorally) real;
(2) it is a bounded phase-5 resolution rule the P1 engine-build session (TKT-P1-11/12) is
already in the neighborhood of, so it amortizes; (3) it is a strong charter-legibility win —
jump-in depth→advantage is one of the least-observable things in most fighting games, so
making "why is this deep jump-in so plus?" answerable live in the training mode is close to
the platonic case of the north star ("find out what happened and why"). The **technical half
is the Architect's** (per this flag's own terms): spec it as a phase-5 rule — air-normal
hitstun/advantage as a function of the defender's contact height — surfaced live through the
inspection seam, with its own engine ticket (sibling to TKT-P1-11) so it lands in the same
Developer engine-build session. Relayed to the Architect to spec. [Acted: Architect specced
AD-033 + TKT-P1-13; combat-resolution.md, decisions.md, inspection-surface.md, character-a.md
updated.]

### [resolved] 2026-07-04 · raised-by: Strategist · owner: Strategist · re: /docs/protocol.md (commit cadence / interruption resilience)
Problem: across the P1 run, three separate sessions hit token/session limits mid-work and
terminated with uncommitted changes in the working tree (Batch 3 overlays ~608 lines; the
AD-033 spec draft; a partial engine edit). Nothing was ultimately lost — the shared working
tree persisted each change and all were recovered — but every recovery cost a fresh session
to verify-and-resume orphaned work, and the botched QA run cost ~150k tokens for zero
output. The token-economy section already says "commit as you go," but it is advisory; under
large batches the commit consistently came too late. This is a protocol weakness I own.
Candidate fixes for a future Strategist session (deliberately NOT applied now — session
ending, pipeline work halted): (a) promote "commit the first logical unit before any further
work, then per-unit" to a hard working-agreement; (b) right-size batches smaller so one
interruption spans less uncommitted work; (c) add a dispatch-brief guard that a subagent must
perform its own work and never delegate/spawn (the QA run mis-scoped its role and narrated
delegating the audit). Raised as the last-chance record so the lesson survives the session
boundary.
---
Resolution (Strategist, 2026-07-08): Resolved by adopting the P2 dispatch posture, which
subsumes all three candidate fixes in stronger form than originally sketched, at the user's
direction after the Fable strategic review (2026-07-05).
(a) Applied — the "commit as you go" advice is now a **hard rule** in the working agreements:
commit the first working logical unit before starting the next, never carry two uncommitted
units at once.
(b) Applied in its strongest form — not "smaller batches" but **per-ticket dispatch** as the
P2 default for heavy build work (token-economy section rewritten): one ticket per Developer
subagent, so a mid-flight death costs one ticket, and bounded context per ticket is also the
runaway guard. Batching demoted from mandate to an earn-it exception; the batch-big doctrine
(first-principles, never measured) is retired.
(c) Applied structurally rather than as a brief-guard sentence — `Agent` (subagent-spawning)
removed from the frontmatter of the architect/developer/qa role files, so a leaf role
*cannot* delegate its own work by construction. Only the top-level Strategist orchestrates.
This directly turns off the ~150k QA delegation-runaway class.
Coordination model updated in the same pass: the Strategist session now orchestrates dispatch
(the bus the user used to be) while the user keeps the two gates — `push` and the
play/overlay-look. Free P2 evidence to collect: P2 total spend vs P1's. No further action.

### [resolved] 2026-07-04 · raised-by: Strategist (relaying QA) · owner: user · re: training-mode overlays — in-mode visual confirmation
Problem: the P1 feature audit PASSED (`docs/audits/audit-p1-feature.md`), but one check is
outside a headless pass: pixel-level on-screen rendering of the four training-mode overlays
(geometry box positions, panel layout/clipping, input-history legibility). QA confirmed the
scene loads, instantiates, and auto-wires live, and every overlay's view-model logic is
covered by non-vacuous headless tests — so the PASS stands — but actual visual appearance
needs a human look in an interactive Godot session. Tracked here so P1 is not treated as
100% closed without it. Resolution: open `game/scenes/training_mode.tscn` in the Godot
editor, confirm the overlays render correctly; QA folds the result into the audit.
---
Resolution (owner fills): User here. Ran the scene in Godot. No errors in the log. 
I see only this white text on default grey background: 

```
-- Frame Data --
P0 state 0 startup 0 /active 0 /recovery 0 (total 0)  onHit +0 onBlock +0
P1 state 0 startup 0 /active 0 /recovery 0 (total 0)  onHit +0 onBlock +0
Live advantage: +0 plus=none toNeutral=0 neutralRestored = false

-- Live State --
P0 state 0 (grounded) f0/0 hitstop 0 stun 0(none) actionable true hits 0 scaling 100% dmg 0
P1 state 0 (grounded) f0/0 hitstop 0 stun 0(none) actionable true hits 0 scaling 100% dmg 0

-- Input --
<A directional input for P0 that responds to my arrow key input as UDLR and a history thereof. P1's doesn't respond.>
```

If there's a way to make it do anything else, I can't figure it out.
---
Disposition (Strategist, 2026-07-08): The human-look duty is discharged — the user ran it, so
this "go look" flag is closed. The look was NOT a clean pass; it produced two findings, now
tracked as first-class open flags: (1) owner Architect — no human-operable control surface
(the mode is observable but not operable; scope question); (2) owner Developer — geometry
overlay renders no visible boxes. By-design, not findings: no character art yet (deferred);
"P1 unresponsive" is the dummy (index 1, empty-playback = NEUTRAL) behaving correctly. QA
must re-fold the visual outcome into `audit-p1-feature.md` once the two findings resolve — the
audit's "in-mode visual confirmation" section currently reads more optimistically than the
human result warrants. Validates the play-and-report gate (Fable review, point 1): ten minutes
of real play produced a sharper signal than the headless suite could.

### [resolved] 2026-07-08 · raised-by: Strategist (from user's overlay review) · owner: Architect · re: training-mode.md — no human-operable control surface
Problem: the first human run of `training_mode.tscn` (user, 2026-07-08; full report archived
in `flags-archive.md`, this date) surfaced a spec-vs-charter gap that all 24 headless tests
pass straight through. The scene mounts the four READOUT overlays but binds nothing to drive
the CONTROL layer: pause / frame-step / reset / record-playback exist only as methods on the
shell (`training_mode.gd`: `set_paused`, `step_once`, `capture_reset`, `set_dummy_mode`…),
and the P1 acceptance tests exercise them by CALLING those methods directly — which is why
criteria 1–4 are green AND why an experienced player cannot make the mode do anything: no
key, button, or on-screen control invokes them, and `_physics_process` early-returns unless
the host is running with no bound way to change that. Net: the mode is observable but not
operable by a human. Scope question for the Architect (spec/scope owner): was an input-bound
control surface in P1's scope, or deliberately deferred (P1 = control CONTRACTS + readouts,
driving UI later)? Cross-check the training-mode brief (Strategist-owned,
`docs/briefs/debug-training-mode.md`) and training-mode.md criteria 1–4. If deferred, rule it
so and record where the driving UI lands on the roadmap; if a gap, spec the control surface.
This gates the geometry finding below (nothing steps, so nothing moves to confirm) and the
P1 audit's visual sign-off.
---
Resolution (Architect, 2026-07-08): **GAP, not deferred.** An input-bound control surface was
in P1's scope. The brief (`debug-training-mode.md`) lists frame control, situation reset, and
record/playback as **required outcomes** and its "what success feels like" describes a human
*pressing* them ("you step the match forward one frame at a time", "you record the opponent's
sequence, play it back", "you reset to a known situation"). P1 built the control *methods*
(`training-mode.md` → Control layer, criteria 1–4) but bound no human control to them — the
methods are exercised only by tests calling them directly. That is an incomplete build of the
brief's required outcomes, not a deliberate contract-only cut. So P1.1 closes it, not a later
driving-UI phase (no roadmap routing-back needed). Specced: `training-mode.md` new "Human
control surface (operability — P1.1)" section + acceptance criterion 13 — bind pause/resume,
frame-step, capture/do-reset, and dummy record/playback mode-switch to device/keyboard controls
routed through the `TrainingMode` shell; complete the P1 device sampler to also read the three
attack buttons (AD-018) so a human can perform character A's moves; and surface a minimal
on-screen controls legend — **TKT-P1.1-02**. The shared prerequisite of starting both players
as the installed character in idle (the wiring gap behind the "state 0 / startup 0" readouts
*and* the blank overlay) is implemented in **TKT-P1.1-01**, on which the control surface
depends. Key choice is placeholder (Developer's, like tuning). Operability is confirmed at the
human-inspection gate, per the roadmap's P1.1 done-bar.

### [resolved] 2026-07-08 · raised-by: Strategist · owner: Architect · re: serialization format has no version field
Problem: the `to_dict()`/`from_dict()` pairs across the sim (`sim_state.gd`,
`player_state.gd`, `projectile.gd`, `rng_state.gd`, `stage_state.gd`,
`hit_record.gd`, `input_history.gd`) carry no format-version marker. The
top-level `SimState.to_dict()` (`game/sim/sim_state.gd:128`) returns
`{tick, rng, players, projectiles, stage, last_hit, neutral_restored_this_tick}`
— no `"v"`. This is cheap to add now (one `"v": 1` field on the top-level dict,
checked in `from_dict`) and expensive to retrofit once saved states — replays,
save-states, netcode rollback snapshots — exist in the wild and must be migrated
blind. Determinism/serialization is a Tenet-1 surface, so this is contract-level,
not cosmetic. This is an Architect call on the serialization contract: rule on
whether a version field belongs now (and if so, where it lives and how `from_dict`
handles an absent/mismatched version), then hand the shape to the Developer.
Origin: Fable strategic review 2026-07-05 (smaller findings), carried in by the
user; verified against live code this session.
---
Resolution (Architect, 2026-07-08): **Yes — add it now.** Recorded as **AD-034**. Shape: a
single `"v": 1` on the **top-level** `SimState.to_dict()` only (one version governs the whole
graph; sub-dicts are not each versioned). `from_dict` reads `d.get("v", 1)` — **absent ⇒ 1**
(a pre-field dict is legacy v1, the current shape), **== 1 ⇒ parse**, **anything else ⇒ fail
loudly** (`push_error`, no silent mis-parse); the older-version migration branch is added only
when a v2 exists. **Not folded into `hash_state()`** — `"v"` is format metadata, not mutable
sim truth, so it is excluded from the canonical hash exactly like the install-generation token
(AD-024) and pixel projections (AD-019); consequence: adding it changes **no** existing state
hash and breaks **no** determinism/round-trip golden. Cheap now, expensive to retrofit blind
once replays/save-states/rollback snapshots exist. Handed to the Developer as **TKT-P1.1-03**
(a `const FORMAT_VERSION := 1` on `SimState` is the natural home for the number).

### [resolved] 2026-07-08 · raised-by: Strategist · owner: Architect · re: MoveRegistry process-wide static state is undocumented
Problem: `MoveRegistry` (`game/sim/move_registry.gd`) holds `static var _roster`
and `static var _install_generation` — the one piece of global mutable state in
an otherwise pure, deterministic design. It is *mitigated* (tests call `clear()`;
the install-generation token guards stale reads) and is fine for the slice, but
the tradeoff is unrecorded: nothing in `decisions.md` names it as a deliberate,
known cost of the Tenet-3 (build-for-extension) roster-install convenience. Left
undocumented, a future reader can't tell whether the global is an intentional,
bounded exception or an accident to "fix," and can't see the invariant that keeps
it safe (install-generation discipline). Fix (Architect): record it as a known
cost — a short AD or a note on the relevant existing AD — stating the exception,
why it's acceptable at slice scope, the invariant that contains it, and what would
force revisiting (e.g. concurrent sims in one process). Not a code change; a
decision-record change. Origin: Fable strategic review 2026-07-05 (smaller
findings), carried in by the user; verified against live code this session.
---
Resolution (Architect, 2026-07-08): Recorded as a **known, slice-scoped exception** — a note
appended to **AD-024** (the AD that already establishes the `MoveRegistry` model and its
install-generation invariant). The note states: **the exception** (the roster + generation
token are the one piece of process-global mutable state); **why acceptable at slice scope**
(one sim per process, tests isolate via `clear()`, the install-generation token makes any
mid-run mutation detectable — simulation.md crit 11 — so the global is indistinguishable from
a threaded immutable input); **the invariant that contains it** (install-once/immutable-during-
a-run; the per-run token observed at the first `step` is identical at every later `step`); and
**what forces revisiting** (concurrent/parallel sims in one process — a rollback speculative
sim, a background/preview sim, or two matches sharing the process — at which point the roster
moves to per-`SimState`-scoped or `step`-threaded resolution, a revision to AD-024, not a
silent change). Not a code change (the token is already observable, per Tenet 3).

### [resolved] 2026-07-04 · raised-by: QA · owner: Developer · re: /run_tests.bat
Problem: `run_tests.bat` (repo root) still lists only the original 12 P0-era
test files in its `TESTS` variable and has not been updated to include the 13
test files added during P1 work (`test_air_height_scaling`, `test_character_a`,
`test_command_recognition`, `test_frame_control`, `test_frame_data_panel`,
`test_geometry_overlay`, `test_input_history_panel`, `test_invuln`,
`test_live_state_panel`, `test_projectiles`, `test_record_playback`,
`test_training_harness`, `test_training_mode_shell`). Anyone running the
batch file as their "did I break anything" check gets a false sense of full
coverage — half the suite silently doesn't run. Not a sim defect: all 24 test
files are independently green when run directly against Godot (confirmed in
the P1 audit, `docs/audits/audit-p1-feature.md`, this session). Fix: add the
13 missing names to the `TESTS` variable.
---
Resolution (owner fills): `TESTS` brought fully current — not just the 13 named here, but
also the P1.1-phase additions landed since this flag was raised (`test_control_surface`)
and TKT-P1.1-03's own new test (`test_serialization_version`), for **27 runnable
`SceneTree` tests total**, enumerated against a fresh `game/tests/test_*.gd` glob rather
than trusting either this flag's list or the prior 12-file list. `test_support.gd` is
excluded — it is a shared helper (`TestSupport`, programmatic move-data builders), not a
runnable `SceneTree` test; it has no `_init`/`quit` test-runner shape and running it
directly does nothing. Verified: ran all 27 headlessly (directly against Godot, not
through the batch file, to sidestep its trailing `pause`) — 27/27 pass.

### [resolved] 2026-07-04 · raised-by: QA · owner: Developer · re: game/content/character_a.gd:731
Problem: `2H`'s invuln keyframe carries a stale comment: `# frames 1-8 per
spec; see flags.md (inert until consumed)`. This predates TKT-P1-11/AD-031
landing — invuln is no longer inert (it is consumed in phase 4; confirmed
live by `test_invuln.gd`'s `_test_strike_whiffs_on_2h_invuln`), and
`flags.md` (this file) no longer carries that content (the ledger is now
empty; the relevant history is in `flags-archive.md`). The code itself is
correct — only the comment is out of date, and it could mislead a future
reader into thinking invuln doesn't function yet. Worth a single pass to
check for and remove the "(inert until consumed)" phrase anywhere else it
survived past AD-031 landing in this file.
---
Resolution (owner fills): Comment updated to `# frames 1-8 per spec; consumed in phase 4
(AD-031)` (the line has since shifted to `character_a.gd:770` as the file grew, confirmed
by grep, not a line-number regression). Checked the whole file for the phrase surviving
elsewhere — this was its only occurrence in `character_a.gd`; none found. Two other
references to the phrase remain, both in historical docs (`flags-archive.md`'s own past
entry and `audit-p1-feature.md`'s quote of it) — left untouched, since those are dated
records of what the comment USED to say, not the stale comment itself, and this flag's
scope was the code. Code-correct throughout; no behavior change. `character_a.gd` still
parses and all 27 headless tests pass (including `test_invuln.gd`, unaffected).

### [resolved] 2026-07-08 · raised-by: Strategist (from user's overlay review) · owner: Developer · re: geometry overlay renders no visible boxes
Problem: in the same human run (full report archived in `flags-archive.md`, 2026-07-08), the
geometry overlay showed NO boxes on screen, though both players are present in sim state (the
frame-data and live-state panels both read P0 and P1 idle at tick 0). Even without character
art, two idle characters' hurtboxes should draw — this is the charter's centerpiece surface
("see what hit and what whiffed"), and its pixel-level rendering is exactly what no headless
test could confirm (`test_geometry_overlay.gd`'s 28 checks verify the view-model's draw-list
numbers, not on-screen pixels). Investigate: are boxes drawn off-screen, behind the panel
region (panels span x≈16–700), or at a projection/camera framing that puts them outside the
view? PARTLY GATED on the control-surface flag above — with the sim frozen at tick 0 and
nothing steppable, geometry can't be confirmed in motion; but "no boxes at all, at rest" is
independently a finding. May bounce to the Architect if the box-to-screen projection / camera
framing turns out to be unspecced rather than a code defect.
---
Resolution (owner fills): It was **both**, as the ticket (`p1.1-finish-instrument.md` →
"Geometry ruling") anticipated, and both are now fixed together in **TKT-P1.1-01**:
- **Part A (pure code defect, Developer's).** `training_mode.gd`'s shell left both players at
  `SimState.new_initial()`'s generic `character_id 0 / state_id 0` — never wired to the
  installed roster (`CharacterA.CHAR_ID`) — so `PlayerView.move` was null and `boxes == []` for
  both players at every tick, independent of any rendering question. Fixed: both players now
  start as the installed character in its idle state (character-agnostic — reads
  `_character_id` / `Character.idle_state_id`, no character-A-specific branch). Regression-
  guarded in `test_training_mode_shell.gd`.
- **Part B (render-framing contract, unspecced — the "may bounce to the Architect" clause).**
  Confirmed unspecced: at `PX_PER_UNIT = 1` with no world→viewport framing, world origin sat at
  the viewport top-left, so resolved boxes at `pos_x = ±100` rendered partly off-screen / behind
  the HUD panel region. The Architect settled this as **AD-035** (render-only world→screen
  framing, extending AD-019). Implemented in `geometry_overlay.gd`: a render-only
  position/scale transform on the `GeometryOverlay` node itself (centers the stage horizontally,
  seats the ground line low, zooms to fit stage width with margin) — the HUD panels are
  *siblings*, not children, of that node, so they stay screen-anchored with no further change.
  Latitude on the exact mechanism/numbers recorded at `judgment-log.md` JC-044, pending Architect
  ratification.

Both parts verified headlessly: `test_training_mode_shell.gd` (Part A: both players resolve
`character_id`/`state_id`/a non-empty `boxes` list at tick 0) and `test_geometry_overlay.gd`
(Part B: the framing math centers/seats/fits as specified, both symmetric-start players' boxes
land on-screen and clear of the panel region in the framing math, and a live-node application of
the framing changes neither the draw-list view-model nor the `SimState` hash — AD-019 criterion
6 / AD-035's "golden with vs. without the camera is identical").

**Not closed by this fix: pixel-level live confirmation.** Whether the boxes are *actually*
visible on a real running window is the **P1.1 human-inspection gate** (`audit-criterion.md`,
`p1.1-finish-instrument.md`) — the user's to confirm by running `training_mode.tscn`, separate
from and not claimed by this code fix. This flag closes the code-defect/unspecced-contract
question the geometry finding raised; it does not itself constitute the human sign-off.

### [resolved] 2026-07-08 · raised-by: Strategist (from user's P1.1 human-inspection gate) · owner: Developer · re: arrow-key left/right movement does nothing
Problem: first human operation of `training_mode.tscn` after TKT-P1.1-01/02 (user, 2026-07-08).
UP works (jump straight up) but LEFT and RIGHT arrow keys produce no walk — horizontal movement
by keyboard is impossible. Forward displacement from moves works (5H advances forward), so the
sim-side walk is not the suspect; the gap is in the human control path: either
`_sample_device_p1` (`game/scenes/training_mode.gd`) does not sample left/right into the emitted
`InputFrame` the way it samples up, or the `project.godot` input-map bindings for left/right are
missing/overridden (the `[input]` section added in TKT-P1.1-02). Diagnose which and fix so a human
can walk both directions. **Blocks P1.1's "operable by a human" gate** — there is no neutral or
spacing without walk. Add a headless regression asserting the device sampler encodes the left and
right direction bits (mirroring the attack-button-bit test).
---
Resolution (owner fills): Both named candidates checked out FINE — `_sample_device_p1` samples
`ui_left`/`ui_right` identically to `ui_up`, and `project.godot`'s `[input]` section never touches
`ui_left`/`ui_right`/`ui_up`/`ui_down` at all (they fall through to Godot's own built-in arrow-key
defaults, unshadowed). The actual root cause was **sim-side**, not the control path the flag named:
`character_a.gd` had already authored `STATE_WALK_F`/`STATE_WALK_B` (movement-table speeds) with
correct keyframe motion, but no `button_map` entry ever routed a bare held direction into either
state — holding RIGHT/LEFT produced zero state change and zero displacement, confirmed by driving
`SimState.step` directly (state stuck at `STATE_IDLE`, `pos_x` never moved). Fixed by adding two
pure-direction `ButtonMapEntry` entries (mirrors the existing jump entry, AD-032's pattern exactly),
listed after the standing normals so a button held with a direction still performs the normal, not
a walk. Full diagnosis, alternatives, and a boundary note (this touches `character_a.gd`, nominally
out of this dispatch's "no character content changes" bound, but is input-recognition wiring using
already-authored/spec'd values, not new move/damage/timing content) recorded at **JC-046**
(`docs/judgment-log.md`, provisional — flagging for Architect review given it exceeded the
dispatch's anticipated two-candidate diagnosis). Regression: `test_command_recognition.gd`'s
`_test_character_a_walk_forward_reachable_end_to_end` / `_walk_back_reachable_end_to_end` /
`_button_beats_walk_on_same_frame` (live-input only, no state injection), and
`test_control_surface.gd`'s `_test_device_sampler_encodes_left_and_right` (the requested sampler-bit
regression). `data/character-a.tres` re-baked to match. All 26 headless test files pass.

**Not closed by this fix: live human re-confirmation.** Whether a human can actually walk both
directions by pressing the arrow keys in a running `training_mode.tscn` window is the **P1.1
human-inspection gate** — the user's to confirm on return, separate from and not claimed by this
code fix.

### [resolved] 2026-07-08 · raised-by: Strategist (from user's P1.1 human-inspection gate) · owner: Developer · re: player sinks ~5px below the floor on landing
Problem: same human run. On landing from a straight-up jump, the player drops through the floor
slightly (~5px) MOST times. First determine whether this is a SIM defect (the player's sim `pos_y`
actually goes below `ground_y` for one or more ticks — read the Live State `pos_y` against
`ground_y`) or a RENDER defect (sim `pos_y` is correctly clamped at `ground_y`, but the AD-035
render framing / `geometry_overlay` seats the drawn ground line a few px off from the sim floor).
Fix accordingly: if SIM, the landing clamp against `ground_y` (jump arc, JC-A-01) is overshooting —
fix and note that determinism goldens change deliberately (JC-017-style, a conscious golden update);
if RENDER, align the drawn ground line to sim `ground_y` under AD-035. **May bounce to the Architect**
if AD-035 underspecifies where the ground line seats. The floor is a reference the player reads
against, so this is a gate-visible legibility defect and blocks the P1.1 human gate alongside the
movement flag.
---
Resolution (owner fills): **SIM defect, confirmed** — the render layer (AD-035/`geometry_overlay.gd`)
is exonerated: it's a pure linear world→screen transform with no independent vertical-seating bug,
so it faithfully rendered whatever `pos_y` the sim reported. Root cause: `character_a.gd`'s
`_build_jump_arcs` split the 45-frame jump arc as 22 rise frames / 23 fall frames (45 is odd) at
EQUAL magnitude (both 6.0 units/frame) — so the arc's net vertical displacement was `+6` units of
permanent downward drift on EVERY jump (deterministic, not intermittent), landing the character 6
units into the floor. There is no runtime landing clamp anywhere in the engine (movement is pure
keyframe integration by design, AD-014) to correct this after the fact. Fixed by spending the odd
frame as a one-frame, zero-velocity "apex hang" at the top of the arc (22 rise / 1 hang / 22 fall =
45 frames, unchanged duration) — nets to exactly zero, verified headlessly: the character now lands
bit-exact at its starting height, 0 ticks below `ground_y` during the whole flight. This is a
conscious, disclosed sim-behavior change (JC-017-style): no persisted golden-file fixtures exist yet
in the repo, so nothing needed silent regeneration, but `test_character_a.gd`'s
`_test_jump_arc_integrates` — whose PRIOR assertion explicitly tolerated the drift ("lands close to
its start... not bit-exact") — is updated to assert exact equality, since that prior tolerance was,
in hindsight, documenting the very defect this flag reports. Full diagnosis and alternatives-passed-
over (an uneven fall speed instead of a hang frame; a runtime clamp; a parabolic re-bake) recorded at
**JC-047** (`docs/judgment-log.md`, provisional). All 26 headless test files pass.

**Not closed by this fix: live human re-confirmation.** Whether the player visibly lands flush on
the floor in a running `training_mode.tscn` window is the **P1.1 human-inspection gate** — the
user's to confirm on return, separate from and not claimed by this code fix.

### [resolved] 2026-07-08 · raised-by: Architect (P1.1 ratification pass) · owner: Strategist · re: roadmap placement of the ground-clamp hardening (AD-036) — you own the sequencing
Problem: diagnosing JC-047, the Developer found there is **no runtime landing clamp anywhere** in
the engine — vertical position is pure keyframe integration, and correctness rests entirely on
authored arcs summing to exactly zero (the fragility that JC-047's +6-unit sink exposed). I ruled
(AD-036) that a `pos_y ≥ ground_y` clamp **plus ground-contact landing semantics** (designed
together — a bare clamp alone would *mask* authoring bugs, anti-legibility) is warranted as
defense-in-depth and will be load-bearing for P2's air moves / variable-height landings. It is
**new scope (hardening + a small mechanism)**, and per your steer it is **not** P1.1-blocking (the
arc is fixed, the character lands flush; the interim guard is the net-zero-arc authoring invariant
now recorded in move-format.md). My **technical recommendation** on placement: **pre-P2 hardening,
or the first unit of P2 air-movement work** — *not* a late P4 harden pass, because P2 air moves
would otherwise build on the no-clamp foundation and need ground-contact landing anyway. **The
sequencing decision is yours** (you own the roadmap); AD-036 records the technical shape and this
recommendation, and is marked provisional/deferred pending your placement.
---
Resolution (Strategist, 2026-07-08): **Placed pre-P2**, per the Architect's recommendation —
the ground-contact hardening (AD-036: `pos_y ≥ ground_y` clamp + landing semantics, designed
together) is now recorded in the roadmap as P2's **opening unit**, before char B or any
air-movement content, since P2's air moves and the matchup would otherwise build on the no-clamp
foundation. Not a late P4 pass. The Architect specs AD-036 into P2's first tickets when P2 opens.
Revisable like any roadmap call; the user may reweigh on return. (The two sibling feel flags —
frame-step auto-pause and jump apex-hang — stay open: they are the user's to judge at the P1.1
human re-gate, not mine to resolve.)

### [resolved] 2026-07-08 · raised-by: QA (P1.1 objective audit) · owner: Strategist · re: docs/flags-archive.md contains a run of NUL bytes — file-integrity defect, not content drift
Problem: while reading `docs/flags-archive.md` for the P1.1 drift check, the file fails a plain-text
check (`file docs/flags-archive.md` reports "data", not text) — it contains **4,632 contiguous NUL
(`\x00`) bytes** starting at byte offset 48023 (right after the resolution text for a P0-era
`test_throws_multihit.gd` flag entry, and before the next entry continues normally in plain text).
`git status` on the file is clean and `git log` shows it was last touched by commit `11eab90`
("flags: archive three resolved Architect flags"), so **the NUL run is already committed** — this
is not something introduced by my read-only audit pass (I only `Read`/`Grep`/`Bash`-catted it, never
wrote to it). No other coordination artifact I checked (`flags.md`, `judgment-log.md`,
`judgment-log-archive.md`, `roadmap.md`, `protocol.md`) shows the same symptom — this looks isolated
to this one file, most likely from whatever tool/process wrote the archive-sweep commit (a
pre-allocated buffer or truncated write that never got its bytes filled in, rather than a merge or
encoding issue — the text before and after the NUL run is intact and readable). Practical impact:
some tools (`grep`/`rg` in this environment) refuse to search file content past the first NUL and
silently report "binary file matches" instead of surfacing the actual line — so anyone `grep`ing
this archive for an old flag by date/keyword may get a false negative past that offset, without any
error telling them why. This does not affect anything P1.1 needed (the corrupted span sits inside
old P0-era content, not any P1.1 entry), so it does **not** block this audit's pass/fail verdicts —
routing separately as a repo-hygiene / artifact-integrity defect on the file you own moving entries
into. Suggested fix: re-save `docs/flags-archive.md` (e.g. re-write it from its current readable
text content, stripping the NUL run) so it round-trips as plain UTF-8 text again; verify no content
was actually lost (the readable text on both sides of the NUL run should be checked against git
history/blame to confirm nothing was silently dropped, only that null padding was inserted).
---
Resolution (Strategist, 2026-07-08): **Fixed — stripped, lossless** (commit `b51ba0d`). Verified
the corruption predates this session: the NUL count is a stable 4,632 across every commit that
touched the file back to `ad4ff22` (P0→P1 prep), so it was inserted once in the P0-era
sandbox-git window and carried forward unchanged — not introduced by the P1.1 archive sweep, and
nothing was ever added to or overwritten in that block. Confirmed the run was 100% contiguous NUL
bytes sitting between two intact, coherent entries (an AD-028 resolution and the
`test_throws_multihit.gd` entry) — pure padding, no text lost; stripping removed exactly 4,632
bytes and the entries read correctly on both sides. Restored the inter-entry blank line the
padding had occupied. `flags-archive.md` now round-trips as plain UTF-8 (0 NUL bytes) and greps
cleanly past the former offset.
