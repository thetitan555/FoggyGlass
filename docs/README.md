# Project Docs — Fighting Game (Godot)

This folder is the **document substrate** for a multi-role build pipeline. The
roles run as separate Cowork projects that don't share memory, so they don't
collaborate in a room — they coordinate through these artifacts and through you.
Design the documents well and the pipeline works; let them drift and it doesn't.

## What's here

**Foundational documents** — read first by every role, owned by the user:

- **charter.md** — the vision. Philosophy, north star (comprehension, not
  difficulty), and what veterans get. The standard everything is judged against.
- **principles.md** — the design principles. *How* the charter's belief shows up
  in the build: clarity-as-craft, depth-vs-clarity, no-knowledge-checks.
- **technical-tenets.md** — the inviolable architectural givens: deterministic
  simulation, the single input-source abstraction, build-for-extension.

**Role prompts** (`roles/`) — paste each into the corresponding Cowork role's
instructions (or, for the Consultant, a chat/Project outside Cowork):

- **roles/strategist.md** — pairs with you; owns direction, priority, the
  coordination protocol, the audit criterion, and the health of the process.
- **roles/architect.md** — owns the spec, architecture decisions, the
  move/frame-data format, ticketing, and ratifying the developer's judgment calls.
- **roles/developer.md** — builds from the spec; has bounded latitude over
  implementation and records every judgment call.
- **roles/qa.md** — verifies, controls drift, audits; raises problems, never
  fixes them; hard-verifies the objective, surfaces the subjective.
- **roles/consultant.md** — out-of-pipeline chat advisor for your ideation and
  tradeoff questions; no authority to write to or decide anything.

## What's *not* here yet (the roles create these at runtime)

These are referenced by the role prompts but don't exist until the roles produce
them. Most will land in this folder:

- **The coordination protocol** — the Strategist's first deliverable. Defines
  what artifacts exist, where they live, who reads/writes each, the flow
  (idea → brief → spec → code → audit), the **audit cadence**, and the home of
  the **judgment-call log**. It also carries the **upstream-correction rule**:
  any role may *raise* a problem with anything upstream (up to the charter), but
  only the upstream owner *resolves* it; downstream never patches around or
  redefines upstream work.
- **Briefs and the roadmap** — Strategist.
- **The spec, acceptance criteria, architecture decisions, tickets** — Architect.
- **Game code, tests, the judgment-call log** — Developer.
- **Audit reports and drift reports** — QA.

## How to start

1. Drop this folder into your repo.
2. Create the Cowork roles and paste each `roles/*.md` into the matching role.
3. Point every role at this `/docs` folder; confirm paths on first run.
4. The Strategist goes first: it reads the foundational docs, **sets up and
   clones the GitHub repo**, then produces the coordination protocol, the
   roadmap, and the first brief. Everything else follows from there.
