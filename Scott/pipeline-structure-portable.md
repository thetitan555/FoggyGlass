# The FoggyGlass Pipeline — a portable description

*Domain-agnostic write-up of how this project is structured, extracted for
reuse in other projects (written 2026-07-05 for the user's father, who runs
his own Claude-based project). Everything game-specific has been stripped;
what remains is the coordination system, which is the transferable part.*

---

## The problem it solves

AI agent sessions have no memory across sessions and drift when unsupervised.
This system gets reliable multi-week output from memory-less agents by making
**the file tree the memory** and **ownership the drift control**. Two
milestones of evidence: contract gaps got flagged instead of hacked around,
spec and code never diverged, and a milestone review caught a test that
passed for the wrong reason.

## The six load-bearing ideas

**1. Artifacts are the memory; if it isn't saved, it didn't happen.**
Roles coordinate only through files in a shared working tree. No role may
rely on anything another role "knows" — only on what is on disk. Every
decision, judgment call, and open problem is written down at the moment it
happens, because the session that made it will not exist tomorrow.

**2. A small pipeline of roles, each a separate agent with its own prompt.**
Four here: *Strategist* (direction, priority, briefs — the "what and why"),
*Architect* (spec, contracts, decision record, tickets — the "exactly what"),
*Developer* (implementation + tests — the "how"), *QA* (audit and drift
control — the "is it actually done"). Work flows one way:
`idea → brief → spec → code → audit → done`. Nothing is done until it clears
audit — not when the builder thinks it's finished. Each role prompt states
who it is, what it reads first, what it owns, and — as important — what it
does NOT do.

**3. One owner per artifact.** Every file has exactly one role that may write
it. Everyone else reads and may *flag*, never edit. This is the single rule
doing the most work: it makes drift attributable and correction routable.

**4. Upstream correction: anyone raises, only the owner resolves.**
Any role may raise a problem with anything it inherited — up to the project's
founding documents. But only the artifact's owner resolves it, by fixing it
or ruling it intended. A downstream role never patches around an upstream
defect or silently redefines what it was handed. This turns "the agent
noticed something wrong" from a drift vector into a self-correction loop.

**5. Bounded latitude, with a ratification loop.** The builder has freedom
over *how* to build what's already decided, and zero freedom over *what*
things are (contracts, formats, anything another role depends on, anything
touching intent). Every latitude call is logged in one running file — what
was decided, alternatives passed over, why — and the builder proceeds
immediately (recording never blocks). Before each feature is audited, the
Architect reads the log and either *ratifies* each call (folds it into the
spec) or *overturns* it. Provisional decisions never silently become
permanent.

**6. Values made testable.** The project's philosophy (a charter) is
operationalized into an explicit *audit criterion* the QA role checks every
change against, with a bright-line test and worked boundary cases. Objective
failures are pass/fail and QA owns the call; subjective judgments QA
*surfaces* to the human, never adjudicates. Per milestone, QA additionally
runs a *drift sweep*: does the accumulated whole still match the charter,
even though every individual change passed?

## The file layout (template)

```
/.claude/agents/          one .md per role (prompt + model tier in frontmatter)
/.claude/CLAUDE.md        auto-loaded pointer to the binding docs (keep tiny)
/docs/charter.md          the WHY — owned by the human, argued with, rarely edited
/docs/principles.md       the values, stated as enforceable standards
/docs/technical-tenets.md non-negotiable ground rules (owned by the human)
/docs/protocol.md         this whole coordination system, written down (Strategist)
/docs/roadmap.md          sequence + why the order is the order (Strategist)
/docs/audit-criterion.md  the charter made testable (Strategist writes, QA applies)
/docs/briefs/             intent + constraints per feature, never implementation
/docs/spec/               precise buildable spec, each section with numbered
                          acceptance criteria; decisions.md = the decision record
/docs/tickets/            spec decomposed into build-sized units, each citing
                          the spec sections it serves
/docs/judgment-log.md     builder's latitude calls; Architect appends rulings
/docs/flags.md            OPEN cross-role problems only (cheap to read)
/docs/flags-archive.md    resolved flags, moved out by the Strategist
/docs/audits/             QA's evidence-backed verdicts
<the actual work product>  owned by the builder
```

A flag entry (the mechanism that makes upstream correction concrete):

```
### [open] YYYY-MM-DD · raised-by: <role> · owner: <role> · re: <artifact>
Problem: <one concrete issue>
---
Resolution (owner fills): …
```

## Cost discipline (hard-won lessons, including the negative ones)

- The dominant cost is each session **re-reading its binding inputs**, not
  producing work. So: keep the always-read set small and pointer-based;
  ledgers hold open items only; rationale is written once and *cited*, never
  restated; tickets name the exact spec sections to read, never "read the
  spec."
- **Big batched sessions backfired.** The theory was that batching amortizes
  the re-read; in practice 100k+-token sessions cost more per message as
  context grows and lose the most work when they die at a limit (three
  mid-session deaths in one milestone). The revised direction:
  fresh-agent-per-ticket with a thin orchestrator, plus commit-as-you-go so
  an interruption loses almost nothing.
- **Model-tier the roles.** Judgment-heavy roles (Strategist/Architect) on a
  strong model; execution roles (Developer/QA) on a mid-tier one. Set in one
  frontmatter line per role.
- **Constrain roles with tool permissions, not just prompt text.** The worst
  incident here (an agent delegating its own job, 150k tokens wasted) was
  instructable-against but should have been *impossible* — remove the
  spawn-subagent tool from role definitions.
- The record grows every milestone; archiving keeps live files small but
  nothing shrinks the permanent record. Schedule a compaction pass per
  milestone or the fixed read grows without bound.

## The human's job (deliberately small, deliberately kept)

The human owns the founding documents, relays handoffs between role sessions
(automatable later; keeping it manual at first is how you learn the system),
and holds exactly the gates that should never be automated: the irreversible
step (here, `git push`) and the experiential judgment no agent can make (does
the product actually feel right?). Everything else the pipeline does itself —
including catching its own mistakes, which is the entire point of the design.

## If you adopt this, in order

1. Write the charter + tenets yourself (the human-owned WHY). Everything
   routes through these; agents can't invent them for you.
2. Write the protocol before any real work — ownership table, the flow, the
   flag mechanism, upstream correction. One page is enough to start.
3. Define the roles as agent files with explicit boundaries and denials.
4. Run one small milestone end-to-end manually before optimizing anything.
   Measure spend, then tune batching/models/orchestration from data.
5. Build the audit criterion early: decide what your values *test as* before
   there's much to test. It's the difference between an agent that checks
   boxes and one that checks the thing you actually care about.
