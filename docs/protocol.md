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

The four roles run as **native Claude Code subagents** (defined in
`.claude/agents/`) against the real working tree at `E:\FoggyGlass`. Each role
session is **memory-less** — no role carries state across sessions — so they
coordinate through two channels:

1. **The shared working tree** — every role reads and writes the same repo on the
   user's disk (`E:\FoggyGlass`). A role "hands off" work by **saving the file**;
   the next role reads it directly from disk — no commit, no pull required in the
   handoff itself. Every artifact lives here. (`CLAUDE.md` auto-loads each
   session and `claude --resume` can pick a prior session back up, so the
   cold-start re-read is cheaper than it was under the old chat substrate — but
   the *coordination* premise below is unchanged: roles still share state through
   the tree, not through memory.)
2. **The user** — the live connection between role sessions. The user carries the
   signal "go look at X" from one role to the next, and carries flagged problems
   back to their owner.

**Why the user is the bus (for now):** the roles run as separate sessions that do
not message each other, so the user relays handoffs and flags between them. This
is the **chosen protocol for the first milestone on the new substrate**, not a
technical constraint — the old network-isolation reason (Cowork sandboxes that
couldn't reach a remote) is gone. Claude Code offers direct role-to-role
messaging (agent-teams), but adopting it changes this load-bearing premise, so
it is **deliberately deferred until one milestone has run on the new substrate**
and the migration's roadblocks are confirmed dead (see `docs/migration-plan.md`,
Part 6). Revisit then; don't change the platform and the coordination model at
once.

**Git's role, and who runs it:** git runs **natively on the user's Windows
machine** and is for history and off-machine backup — *not* the inter-role
transport (the shared working tree is). A role may run `git status`, stage, and
`git commit` directly when a unit of work reaches a checkpoint. **`push` stays
the user's manual gate:** roles commit freely to local history, but pushing to
`origin` is the user's call (run or approve it yourself) — a human checkpoint on
the one irreversible step, and nowhere it isn't needed. The old `commit.bat` /
`push.bat` / `COMMIT_MSG.txt` apparatus was a workaround for sandbox git
corruption and is **retired**; don't write `COMMIT_MSG.txt` or invoke the
helpers.

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
`origin` at the next checkpoint the user chooses to push.) Entries are never
edited after the fact; once a resolution has been relayed, the **Strategist moves
the entry to `/docs/flags-archive.md`** — the permanent record — so the live
ledger stays small and cheap to read. **Batch where possible:** flags for the
same owner should be raised and resolved together in one session; every separate
session re-pays that role's full reading cost.

**Consultant-originated flags.** The Consultant is outside the pipeline. At the
user's request and with the user's confirmation, it may *draft* a flag as a
paste-ready block for the user to append here — **raise-only, never resolve** —
by design, so the user's deliberate carry-in holds even though the Consultant
runs outside this repo's substrate. Such entries are tagged `raised-by: Consultant (via user)`
and carry a stale-context caveat, since the Consultant works only from what the
user pasted into its chat; the owner sanity-checks against live state first.

## Cadence

- **Per session (Strategist).** At the start of every session, before other
  work, check `flags.md` for entries the owner has flipped to `[resolved]` and
  relayed back. Move each to `flags-archive.md`. This is the only place this
  duty is enforced structurally rather than left to memory — see
  `.claude/agents/strategist.md`.
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

## Token economy — spend the fixed cost well

> Added because the roles are memory-less: the expensive thing here is not the
> work, it's the re-reading. This is the Strategist's guidance on where the tokens
> actually go and how to spend them. Revisable like everything else — flag it if
> it stops fitting.

**The dominant cost is cold-start reading, not output.** Every role session —
every subagent — re-pays the cost of reading its binding inputs (charter,
principles, tenets, this protocol) plus its task-specific inputs, because no role
carries memory across sessions. Producing the work is cheap next to that fixed
re-read. (`.claude/CLAUDE.md` now auto-loads each session, so the binding-read
*pointer* is free rather than re-pasted by hand; the artifacts it points to are
still read fresh every session, so the logic below holds.) The consequence that matters: **a feature's cost scales with the number
of separate sessions it is split across**, not just the work in it. Four thin
sessions pay four full re-reads; one session that carries the same work to a
decision point pays one.

**So batch to amortize, and minimize session count.** Prefer one session that runs
a unit of work to its natural stopping point over several thin ones. Group
same-owner work — adjacent tickets, every open flag for one owner, a spec change
and the ticket updates it forces — into a single session. Every handoff that
spawns a fresh session re-pays the fixed read, so collapse handoffs wherever the
ownership model allows.

**The batching tradeoff, named.** A bigger batch amortizes reading but costs two
things: fewer checkpoints for the user to catch a wrong turn, and more lost work
if a session dies mid-flight (a limit, a crash) — interrupted work that wasn't
checkpointed or logged has to be reconstructed. So batch size trades tokens
against steerability and blast-radius. Right-size it to **as much as can run
before a genuine decision point or a natural checkpoint** — and commit and write
judgment-log / flag entries *as you go*, not at the end, so an interruption loses
as little as possible. (`claude --resume` softens the blast radius further — an
interrupted batch can resume rather than respawn from a cold start — but that is
insurance, not a license to skip the as-you-go checkpoints.)

**Prioritize spend by drift-cost.** Put scrutiny where divergence is expensive —
determinism, the contracts multiple roles build against, the charter's legibility
surfaces — and economize where a wrong call is cheap and reversible (packaging,
cosmetics, internal factoring). This is the audit criterion's cherished-vs-tax
logic turned on the team's own effort: a reading pass that protects the
architecture earns its tokens; a pass that re-checks the trivially-correct is tax.
When budget is tight, the *last* things cut are determinism/serialization
verification, contract ratification, and the charter audit; the *first* things cut
are rubber-stamp passes and re-reads of unchanged artifacts.

**Keep the fixed read small — it multiplies across every session.** This is the
highest-leverage lever, because shaving a role's mandatory read pays off in every
future session that role ever runs. Reinforce what's already here: tickets and
briefs name the exact spec sections a role must read (not "read the spec");
`flags.md` holds open flags only; `decisions.md` is fronted by its index;
rationale lives once and is cited, never restated. Every line a role does *not*
have to re-read is a line saved in perpetuity.

**Consolidate ownership passes where the model allows.** A single feature can
touch several cold-start sessions — build, ratify, audit — each re-reading
overlapping artifacts. Where two passes read the same artifact for compatible
purposes, look for a way to collapse them *without* breaking one-owner-per-artifact
or the upstream-correction rule. (The judgment-call review path is the first
candidate — considered and **deferred**, not adopted on P0 evidence: P0 is
foundational/contract-dense, so its impl:contract ratio is not the steady-state
signal. Adoption gate: measure the [impl]:[contract] ratio on a *completed
non-foundational (P1) feature* first. See flags-archive.md, 2026-07-02.)

## Working agreements

- **Roles commit; the user pushes.** The handoff is still the saved file on the
  shared disk, but git now runs **natively on Windows**, so a role may run
  `git status`, stage, and `git commit` directly when a unit of work reaches a
  checkpoint — no `COMMIT_MSG.txt`, no `.bat` helper, no "ready" relay for the
  commit itself. **`git push` stays the user's manual gate:** commit freely to
  local history; leave pushing to `origin` to the user (who runs or approves it).
  This is the "autonomous-but-safe" shape — automate the reversible checkpoint,
  keep a human on the one irreversible step. (The old `commit.bat` / `push.bat` /
  `COMMIT_MSG.txt` apparatus was a workaround for git corruption under the retired
  Linux-sandbox mount; that failure mode is gone and the apparatus is retired.)
- **Commit granularity:** one logical change per commit where practical; the
  message references the brief, ticket, or flag it serves (e.g.
  `brief: debug-training-mode`).
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
