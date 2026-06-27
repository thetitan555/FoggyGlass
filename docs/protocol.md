# Coordination Protocol

> Owned by the **Strategist**. This is the plumbing the whole pipeline runs on:
> what artifacts exist, where they live, who reads and writes each, how work
> flows from idea to audited code, and how problems get corrected at their
> source. Every role reads this alongside the charter and tenets.
>
> It is meant to be as light as the work needs. If it starts costing more than
> it saves — bottlenecks, dropped handoffs, roles talking past each other —
> that's a defect in *this* document, and fixing it is the Strategist's job.
> Raise it.

## The one fact everything else follows from

The five roles run as **separate Cowork projects (and one outside-Cowork chat)
that do not share memory.** They cannot talk to each other. They coordinate
through exactly two channels:

1. **The shared local repo** — **every role mounts the same folder on the user's
   disk (`E:\FoggyGlass`).** This is a hard requirement, not a convenience: the
   role sandboxes are network-isolated and *cannot reach GitHub at all*, so they
   cannot sync through the remote. They share state only by sharing the same
   local working copy. A role "hands off" work by **committing** it; the next
   role sees that commit on the same disk. Every artifact lives here.
2. **The user** — the only live connection between rooms. The user carries the
   signal "go look at X" from one role to the next, and carries flagged problems
   back to their owner.

**GitHub's role:** off-machine backup and history, *not* the inter-role
transport. The role sandboxes can't push (network-blocked). Pushing is an action
the **user** runs from their own machine, where real credentials live — a
periodic sync, not part of any handoff. See "Working agreements."

Design consequence: if it isn't committed to the shared repo, it didn't happen.
No role may rely on something another role "knows" — only on what's committed.

## Where things live

All coordination artifacts live in `/docs`. Game code lives in the engine
project tree (path is the Architect's call; recorded here once set).

| Artifact | Path | Owner (writes) | Readers |
|---|---|---|---|
| Charter | `/docs/charter.md` | **User** | all |
| Design principles | `/docs/principles.md` | **User** | all |
| Technical Tenets | `/docs/technical-tenets.md` | **User** | all |
| This protocol | `/docs/protocol.md` | **Strategist** | all |
| Roadmap | `/docs/roadmap.md` | **Strategist** | all |
| Feature briefs | `/docs/briefs/*.md` | **Strategist** | Architect (+ all) |
| Audit criterion | `/docs/audit-criterion.md` | **Strategist** | QA (+ all) |
| Spec + acceptance criteria | `/docs/spec/*.md` | **Architect** | Developer, QA |
| Architecture decisions | `/docs/spec/decisions.md` | **Architect** | all |
| Tickets | `/docs/tickets/*.md` | **Architect** | Developer, QA |
| Game code + dev tests | engine project tree | **Developer** | all |
| Judgment-call log | `/docs/judgment-log.md` | **Developer** writes; **Architect** ratifies | QA, Architect |
| Audit + drift reports | `/docs/audits/*.md` | **QA** | routed to owner |
| Flag ledger | `/docs/flags.md` | **any role** appends; **owner** resolves | all |

One owner per artifact. If you don't own it, you read it and you may *flag* it
(see below) — you never edit it. The judgment-call log is the single shared-write
exception, and even there the write is structured: the Developer appends entries,
the Architect appends rulings.

## The flow: idea → brief → spec → code → audit

```
  idea ──▶ BRIEF ──▶ SPEC ──▶ CODE ──▶ AUDIT ──▶ done
       Strategist  Architect Developer   QA
```

1. **Idea.** Anyone may have one (user, Strategist, a flag from downstream, the
   Consultant via the user). It lands with the Strategist, who evaluates it
   against the charter — does it make the play space more worth exploring while
   keeping the game legible? — and decides whether it becomes a brief.
2. **Brief** *(Strategist).* States intent and constraints — the problem it
   solves *for the charter*, who it's for, what success feels like, what it
   trades against, open questions. **Not implementation.** Pushed to
   `/docs/briefs/`. Handoff signal to the Architect via the user.
3. **Spec** *(Architect).* Turns the brief into a precise, buildable spec with
   **acceptance criteria** (checkable statements of "done and correct"), records
   architecture decisions, and decomposes into **tickets**. Handoff to the
   Developer (tickets) and QA (acceptance criteria).
4. **Code** *(Developer).* Builds from tickets against the Architect's contracts,
   obeying the tenets. Writes tests. Records every latitude call in the
   judgment-call log. Handoff to QA.
5. **Audit** *(QA).* Verifies against acceptance criteria, the tenets, and the
   audit criterion; reads the judgment-call log for drift. Objective failures are
   pass/fail and QA owns the call; subjective questions QA *surfaces* and routes.
   Findings go out as flags to their owners. When a change passes, it's **done**.

The loop closes back on itself: a QA finding, an Architect ratification, or a new
idea re-enters at the appropriate stage. Work is "done" only after it clears
audit — not when the Developer thinks it's finished.

## Upstream correction — the rule that keeps the pipeline honest

**Problems get corrected where they originated. A role flags; only the upstream
owner resolves.**

- **Any role may raise a problem with anything it was handed from upstream** —
  up to and including the charter. A faulty brief, an ambiguous spec, a contract
  that doesn't fit, a tenet that seems wrong: all fair to flag.
- **Only the owner of that artifact resolves it** — by *fixing* it, or by
  *ruling it intended* (not a defect, with a one-line why). Until the owner acts,
  the issue is open.
- **A downstream role never** patches around the problem, edits the upstream
  artifact itself, or unilaterally decides on its own authority that something is
  a bug or is fine. You flag; the owner adjudicates.

Routing by owner: charter/tenets/principles → **User**; direction, priority,
brief, audit-criterion → **Strategist**; spec, contracts, tickets,
move/frame-data format → **Architect**; implementation bugs → **Developer**.

### How a flag works (the mechanism)

Because rooms can't talk, a flag is a repo artifact plus a relay. Append to
`/docs/flags.md`:

```
### [open] 2026-06-27 · raised-by: QA · owner: Architect · re: /docs/spec/combat.md
Problem: acceptance criteria for hitstop don't say what advantage reads during
freeze, so "advantage is observable" can't be verified.
---
Resolution (owner fills): …
```

The raiser pushes the flag and tells the user. The user relays it to the owner.
The owner resolves — edits their artifact if needed, writes the resolution line,
flips `[open]` to `[resolved]`, pushes — and the user relays back. Keep the
ledger append-only; resolved entries stay as a record.

## Cadence

- **Per feature.** QA audits each feature against its acceptance criteria, the
  tenets (determinism + serialization especially), and the audit criterion before
  it is "done." This gates the loop — nothing is done un-audited.
- **Per milestone.** At each roadmap milestone, QA runs a **drift sweep**: the
  cumulative-behavior-vs-charter review and spec-vs-implementation divergence that
  per-feature checks can't see. Drift is the central failure mode of a
  memory-less pipeline; the sweep exists to catch what individual green checks
  miss.
- **Judgment-call ratification.** The Architect reads the judgment-call log and
  resolves each open entry — *ratify* (fold into the spec) or *overturn* (flag it
  back) — at least once per feature, before that feature is audited. Recorded
  calls are provisional until ratified; don't let them pile up unresolved, or the
  spec drifts out from under everyone.

## Working agreements

- **Commit granularity:** one logical change per commit; reference the brief,
  ticket, or flag it serves in the message (e.g. `brief: debug-training-mode`).
- **Commit when you stop; read the latest commits when you start.** All roles
  share one local working copy, so a committed change is immediately visible to
  the next role — no pull needed. Uncommitted local edits are invisible to
  everyone else: commit before you hand off.
- **Pushing to GitHub is the user's action, from their own machine.** The role
  sandboxes are network-isolated and cannot reach GitHub. The user pushes
  periodically (one command / the `push` helper at repo root) to keep an
  off-machine backup; nothing in the inter-role flow waits on a push.
- **Confirm paths on first run.** Each role confirms this layout with the user at
  the start of its first session; if a path here is wrong, that's a flag to the
  Strategist.
- **This protocol is revisable, not sacred.** It exists before real work so
  nothing is built into a vacuum, but reality outranks it. When it stops serving
  the work, flag it to the Strategist and it gets fixed.
