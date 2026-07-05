# Strategic Review — FoggyGlass (full project)

*Written by Fable, 2026-07-05, at the request of the user's father. Placed in
consultant-corner because it is outside-the-pipeline input: read it, argue with
it, and carry anything actionable in through the front door (a flag or a
Strategist session). Nothing here is a decision.*

*Basis: full read of the charter/principles/tenets, protocol, roadmap, all four
role prompts, the migration plan, the consultant analysis, flags (live +
archive), and deep-review passes over the spec (33 ADs), judgment log (43
entries), all audits, and the code (~7,500 lines of sim/game, ~6,200 lines of
tests). Claims below were spot-verified against the repo.*

---

## Verdict up front

This is an unusually disciplined project, and the discipline is real, not
performed. The code honors all three tenets (fixed-point math, seeded RNG
inside serialized state, a pure non-mutating `step`, one input abstraction, a
clean read-only inspection seam). The specs have numbered, checkable acceptance
criteria and the audits actually verify them — the P1 audit's 1131 checks are
real assertions, not vacuous ones, and QA caught things (a stale comment, a
stale test runner, a vacuously-green test back in P0) that a rubber-stamp
process never would. The governance layer — one owner per artifact, upstream
correction, the flag ledger, the judgment log with Architect ratification, the
milestone drift sweep — worked *under load*: contract gaps were flagged rather
than hacked around, every time, across two milestones.

The build quality is not the strategic risk. The risks are all in the
economics and in what the pipeline *hasn't* touched yet: a player.

## The five things worth acting on

### 1. The design has never met a human (biggest risk)

The charter is entirely about a player's experience — legibility, curiosity,
"find out what happened and why." Two milestones in, no human has played a
single frame. Character A's tuning is hand-computed and marked provisional;
the training-mode overlays have never been *seen* (that's an open flag); the
"no knowledge checks" principle has never been tested against an actual
confused person. The pipeline is now very good at verifying the game against
the spec — but nothing verifies the spec against the charter's real subject.
The README says the user is "waiting on a playable vertical slice around
P3–P4." I'd pull that forward: make *"the user plays it and reports back"* a
first-class milestone gate starting at P2, not an afterthought. Ten minutes of
human play will generate better briefs than another thousand lines of spec.
This also fixes the user's stated problem ("I don't have anything I can really
look at") — the human checkpoint should be a *build*, not a document.

### 2. The batching doctrine is probably wrong — and the user already suspects it

The protocol's token-economy section reasons that cold-start re-reads dominate
cost, so batch big. But context grows within a session: a 100k+-token batch
session pays escalating per-message costs that likely exceed several small
cold starts, and a mid-batch death (which happened three times in P1) loses
the most work exactly when the session was most expensive. The user's README
note calls this out correctly. The fix is already named in the migration plan
but not adopted: **fresh-subagent-per-ticket dispatch** — a thin orchestrator
holds the thread; each ticket gets a clean, small context; nothing dies at a
ceiling. This preserves the ownership model (the orchestrator is just the bus
the user used to be). Measure one milestone both ways; my expectation is the
per-ticket dispatch wins clearly. This is the protocol's own "revise when
reality demands" clause coming due.

### 3. The 150k-token QA runaway needs a structural fix, not a prompt fix

The QA session that tried to delegate its own audit is the worst incident on
record, and the flag's proposed fix (a dispatch-brief guard sentence) is the
weak version. Subagent frontmatter supports a `tools:` allowlist — remove the
Task/Agent tool from all four role definitions so a role *cannot* spawn
subagents, regardless of what it decides. Turn the failure class off instead
of instructing against it. Same lever for other risks: QA arguably doesn't
need Write access outside `docs/audits/`. The roles are constitutionally
constrained on paper; make them constrained in fact.

### 4. The binding read is growing without a compaction mechanism

`decisions.md` is 1,075 lines, the judgment log 2,042, the flags archive 784 —
after two milestones. The archiving discipline is good (live ledgers stay
small) but nothing ever *shrinks* the spec-side record, and the protocol's own
scaling threat ("the binding read grows every milestone") has no standing
counter-cadence. Add one: at each milestone boundary, the Architect runs a
compaction pass — superseded ADs collapse to one-line tombstones, ratified JCs
that were folded into spec get pruned to their index line, per-ticket audit
files roll up into the feature audit. The pipeline has cadences for drift and
flags; give the record's *size* a cadence too. (Related small item: the
judgment log at 2k lines should be split or index-fronted like decisions.md
already is — it's the one large file without a cheap-read front door.)

### 5. Decision debt is due: the user-as-bus question

The protocol deliberately deferred agent-teams / orchestration until "one
milestone has run on the new substrate." P1 has now run and passed. The
deferral was correct (don't change substrate and coordination model at once),
but the condition is met, and item 2 above effectively forces the question —
per-ticket dispatch *is* a mild orchestration model. Recommendation: adopt
orchestration for *dispatch only* (a session that spawns roles in sequence and
relays artifacts) while keeping the human on the same two gates as today: push
to origin, and the new play-and-report gate from item 1. The user stops being
the serialization bottleneck for handoffs but stays the authority on the
irreversible and the experiential.

## Smaller findings (worth a flag each, not a section)

- **Serialization has no format version.** `to_dict()/from_dict()` are
  hand-maintained pairs. One `"v": 1` field now is cheap; retrofitting after
  saved states exist in the wild is not. (Architect-owned.)
- **`MoveRegistry` is a process-wide static.** Tests manage it with `clear()`
  and the install-generation token mitigates, but it's the one piece of global
  mutable state in an otherwise pure design. Fine for the slice; note it as a
  known cost of Tenet-3 convenience.
- **`run_tests.bat` hand-lists test files** (12 of 24 currently — already
  flagged as F-015). The category fix beats the instance fix: glob
  `game/tests/test_*.gd` so the runner can never go stale again.
- **The Consultant's stale-context caveat is a genuinely good invention** —
  provenance-tagging advice from an out-of-repo advisor so the owner
  sanity-checks it. Keep it; most multi-agent setups lack exactly this.

## What I would *not* change

The one-owner/upstream-correction core; the flag ledger mechanics; the
judgment-log-with-ratification pattern (the JC-024 → AD-029 case is textbook);
the audit criterion's cherished-friction-vs-tax test (this is a better
articulation of design-values-made-testable than most shipped studios have);
the decision to keep the human on the push gate; and the ~1:1 doc-to-code
ratio, which reads as heavy but is the actual price of a memory-less
multi-role system — every line of it earned its keep at least once in the
record. Don't let anyone (including me) talk the project out of the governance
layer. It is the project's real invention; the fighting game is the proof of
it.

## Sequenced recommendation

1. **Now:** tool-restrict the role definitions (item 3) and version the save
   format — both are one-session fixes.
2. **P2 planning:** adopt per-ticket dispatch for one milestone and measure
   against P1's spend (item 2); add the play-and-report gate to the P2 done
   bar (item 1); rule on the orchestration question explicitly (item 5).
3. **P2 close:** first compaction pass (item 4), then re-measure the binding
   read.

The project is in better shape than its author's cost anxiety suggests. $42
bought a deterministic engine, a real test net, and a governance system that
demonstrably self-corrects. The next $42 should buy the thing the first $42
couldn't: evidence a player can feel what the charter promises.
