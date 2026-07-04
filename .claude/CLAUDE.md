# FoggyGlass

FoggyGlass is a fighting-game project built around a deterministic simulation
core, a small vertical-slice scope, and a strong legibility/clarity standard
for how the game communicates state to the player.

## Read first, every session

Before doing any work on this project, read:

- **`docs/charter.md`** — the charter: the project's *why*, its philosophy, and
  its north star. Every design and spec decision routes through this.
- **`docs/principles.md`** — the design principles, including the clarity
  standard (the game must be observable — advantage state, what hit, what
  whiffed) and *no knowledge checks* (counterplay must be readable in the
  moment, not gated behind hidden information).
- **`docs/technical-tenets.md`** — the Technical Tenets: the fixed architectural
  ground (deterministic simulation, the single input-source abstraction,
  build-for-extension). These are not optional and not yours to relax —
  raise a conflict rather than working around one.

These three documents are binding context for every role in this project.
Treat them as inputs, not suggestions.

## Roles

This project runs a small pipeline of four roles, delivered as native Claude
Code subagents defined in **`.claude/agents/`**:

- **`foggyglass-strategist`** — direction, priority, roadmap, briefs.
- **`foggyglass-architect`** — technical spec, architecture decisions, tickets.
- **`foggyglass-developer`** — implementation against the spec.
- **`foggyglass-qa`** — testing, drift control, audits.

Invoke a role by its subagent type (e.g. `foggyglass-architect`). The
authoritative, editable source for each role prompt lives in
`.claude/agents/`; edit the file there directly to change a role — no re-zip or
re-upload step. (This project previously ran these roles as a Cowork plugin,
`foggyglass-roles`; that plugin has been retired in favor of this single
native source of truth — see `docs/migration-plan.md` for why.)

Each role has its own read-first list and ownership boundaries defined in its
agent file — see the individual files for specifics. Other pipeline artifacts
(coordination protocol, briefs, spec, judgment-call log, flags) live under
`docs/` as well; confirm exact paths against the coordination protocol rather
than assuming.

## Working conventions

- Roles don't share memory across sessions — decisions live in artifacts
  (spec, briefs, protocol, judgment-call log), not in anyone's head.
- **Upstream correction:** any role may *raise* a problem with something it
  inherited from upstream, but only the owner of that artifact *resolves* it.
  Never patch around an upstream artifact or silently redefine it.
