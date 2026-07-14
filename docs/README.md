# Project Docs — FoggyGlass

This folder is the **artifact substrate** for a four-role build pipeline. The
roles run as memory-less sessions that coordinate through these files, not
through anyone's head: if it isn't saved here, it didn't happen. Design the
documents well and the pipeline works; let them drift and it doesn't.

## The roles

They run as **native Claude Code subagents** defined in `.claude/agents/`
(`architect.md`, `developer.md`, `qa.md`) plus the **Strategist**, who is the
top-level session you talk to (loaded via the `Strategist` output style, backed
by `.claude/agents/strategist.md`). The Strategist dispatches the other three as
subagents and relays between them; only the Strategist orchestrates.

- **Strategist** — direction, priority, roadmap, briefs, the audit criterion,
  the protocol, and the health of the process.
- **Architect** — spec, architecture decisions, the move/frame-data format,
  tickets; ratifies the Developer's judgment calls.
- **Developer** — builds from the spec; bounded implementation latitude; records
  every judgment call.
- **QA** — verifies, controls drift, audits; raises problems, never fixes them.

## What's here

**Foundational documents** — read first by every role, **owned by the user**:

- **charter.md** — the vision: comprehension-not-difficulty, and what veterans
  get. The standard everything is judged against.
- **principles.md** — how the charter shows up in the build: clarity-as-craft,
  depth-vs-clarity, no-knowledge-checks.
- **technical-tenets.md** — the inviolable architectural givens: deterministic
  simulation, the single input-source abstraction, build-for-extension.

**Coordination artifacts** — who owns and writes each is the authoritative table
in **protocol.md** ("Where things live"). In brief: the Strategist owns this
protocol, the roadmap, briefs, and the audit criterion; the Architect owns the
spec (`spec/`), architecture decisions, and tickets; the Developer owns the game
code (`/game`); QA owns the audits (`audits/`). The flag ledger (`flags.md`) and
judgment-call log (`judgment-log.md`) are the shared-write surfaces, kept small
by archiving closed entries.

## Structural enforcement

Three of the protocol's rules are enforced by PreToolUse hooks
(`.claude/hooks/`, documented in `.claude/hooks/README.md`), so a role *cannot*
violate them: **one-owner-per-artifact** (you can't edit what you don't own),
the **push gate** (`git push` is the user's manual step), and **Tenet 1
determinism** on writes into `game/sim/**`. A hook-block is the protocol working
— raise a flag, don't route around it.

## Reading discipline

Roles are memory-less, so cold-start reading is the dominant cost. Read the
tenets and the exact spec sections your ticket/brief names — not the whole tree.
Ledgers hold only live entries (closed ones live in their `*-archive.md`,
greppable on demand). See protocol.md → "Token economy."
