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

1. **The shared working tree** — **every role mounts the same folder on the
   user's disk (`E:\FoggyGlass`).** This is a hard requirement, not a
   convenience: the role sandboxes are network-isolated and *cannot reach GitHub
   at all*, so they cannot sync through a remote. They share state only by
   sharing the same local working copy. A role "hands off" work simply by
   **saving the file**; because it's the same disk, the next role sees it
   immediately — no commit, no pull, no git in the handoff at all. Every artifact
   lives here.
2. **The user** — the only live connection between rooms. The user carries the
   signal "go look at X" from one role to the next, and carries flagged problems
   back to their owner.

**Git's role, and who runs it:** git is for history and off-machine backup —
*not* the inter-role transport (the shared working tree is). **Roles never run
git.** Committing and pushing both happen with native git on the user's Windows
machine, via the `commit.bat` and `push.bat` helpers at the repo root, because
git operations through the mounted folder are unreliable (see "Working
agreements"). A role that wants its work checkpointed writes its commit message
into `COMMIT_MSG.txt` at the repo root and tells the user "ready"; the user runs
a helper. Every git operation stays on a healthy filesystem, with the user —
already the relay — as the trigger.

Design consequence: if it isn't **saved to the shared working tree**, it didn't
happen. No role may rely on something another role "knows" — only on what's on
the shared disk. (Commits are checkpoints to history, not the handoff.)

## Where things live

All coordination artifacts live in `/docs`. Game code lives in the engine
project tree — **`/game`** at repo root (the Architect's call, recorded in
`/docs/spec/decisions.md` AD-013).

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
| Game code + dev tests | `/game` (engine project tree) | **Developer** | all |
| Judgment-call log | `/docs/judgment-log.md` | **Developer** writes; **Architect** ratifies | QA, Architect |
| Audit + drift reports | `/docs/audits/*.md` | **QA** | routed to owner |
| Flag ledger (open) | `/docs/flags.md` | **any role** appends; **owner** resolves | all |
| Flag archive (resolved + relayed) | `/docs/flags-archive.md` | **Strategist** moves entries in | on demand |

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
   trades against, open questions. **Not implementation.** Saved to
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

The raiser writes the flag and tells the user. The user relays it to the owner.
The owner resolves — edits their artifact if needed, writes the resolution line,
flips `[open]` to `[resolved]` — and the user relays back. (The change reaches
GitHub at the next checkpoint, when the user runs a helper.) Entries are never
edited after the fact; once a resolution has been relayed, the **Strategist moves
the entry to `/docs/flags-archive.md`** — the permanent record — so the live
ledger stays small and cheap to read. **Batch where possible:** flags for the
same owner should be raised and resolved together in one session; every separate
session re-pays that role's full reading cost.

**Consultant-originated flags.** The Consultant is outside the pipeline. At the
user's request and with the user's confirmation, it may *draft* a flag as a
paste-ready block for the user to append here — **raise-only, never resolve** —
by design, so the user's deliberate carry-in holds even though the Consultant
may run in Cowork. Such entries are tagged `raised-by: Consultant (via user)`
and carry a stale-context caveat, since the Consultant works only from what the
user pasted into its chat; the owner sanity-checks against live state first.

## Cadence

- **Per session (Strategist).** At the start of every session, before other
  work, check `flags.md` for entries the owner has flipped to `[resolved]` and
  relayed back. Move each to `flags-archive.md`. This is the only place this
  duty is enforced structurally rather than left to memory — see
  `roles/strategist.md`.
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

- **Roles don't run git — they save files and request checkpoints.** Edit files
  in place; the handoff is the saved file on the shared disk. When a unit of work
  is ready to checkpoint, write a one-line message to `COMMIT_MSG.txt` at the
  repo root and tell the user "ready." Do not run `git` from the sandbox.
- **Why git is Windows-only here.** The repo lives on a Windows folder mounted
  into the Linux sandboxes, and git's crash-safety assumes POSIX semantics the
  mount doesn't honor (atomic rename, unlink-of-open-files, read-after-write
  coherence). Sandbox-side git leaks undeletable lock files, can silently commit
  *stale* bytes, and has corrupted the index outright. So all git runs natively
  on Windows: **`commit.bat`** (checkpoint locally) and **`push.bat`** (commit +
  push to GitHub), both run by the user. Each reads `COMMIT_MSG.txt` for the
  message and clears it after.
- **Commit granularity (set by the message a role proposes):** one logical change
  per checkpoint where practical; the message references the brief, ticket, or
  flag it serves (e.g. `brief: debug-training-mode`).
- **Direction lives upstream.** A steer given in chat — by the user or anyone —
  is provisional until the *owning* artifact records it. If a role receives or
  infers direction that belongs to an upstream artifact (priorities, scope, a
  future feature's or character's identity), it asks the user to route it to the
  owner; it never records direction in its own artifacts. (Origin: character B's
  identity leaked into the Architect's spec exactly this way — the user steered
  A's tuning in chat, and the steer had nowhere owned to live.)
- **Rationale lives once.** An architecture decision's what-and-why lives in
  `decisions.md`; specs, tickets, and status notes cite the AD-ID rather than
  restating the reasoning. Restated rationale is re-read by every role in every
  session, forever — reference, don't repeat. The same goes for protocol rules:
  cite this document, don't paraphrase it in file headers.
- **Read what the task needs, not the tree.** Every role reads the tenets and its
  own inputs; beyond that, tickets name the specs/sections they serve and the
  executing role reads *that set*, not the whole `/docs` tree. Ledgers are kept
  cheap on purpose: `flags.md` holds open flags only, `decisions.md` is fronted
  by a one-line index — pull full entries on demand.
- **Batch per session.** Roles are memory-less; each session re-pays its fixed
  reading cost before any work. Group same-role work — several flags for one
  owner, adjacent tickets, a spec revision plus its ticket updates — into one
  session where practical.
- **Confirm paths on first run.** Each role confirms this layout with the user at
  the start of its first session; if a path here is wrong, that's a flag to the
  Strategist.
- **This protocol is revisable, not sacred.** It exists before real work so
  nothing is built into a vacuum, but reality outranks it. When it stops serving
  the work, flag it to the Strategist and it gets fixed.
