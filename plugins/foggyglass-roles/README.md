# FoggyGlass Roles

Packages the four FoggyGlass pipeline roles as Cowork/Claude Code subagents so
they can be invoked by name:

- `foggyglass-strategist` — direction, priority, roadmap, briefs
- `foggyglass-architect` — technical spec, architecture decisions, tickets
- `foggyglass-developer` — implementation against the spec
- `foggyglass-qa` — testing, drift control, audits

The agent definitions are the same files kept in the project repo at
`.claude/agents/`; this plugin is the delivery mechanism that makes them
callable inside Cowork (which does not read a project's `.claude/agents/`
directory the way Claude Code does).

## Install (Cowork)

Customize (left sidebar) → Browse plugins → upload the `foggyglass-roles.zip`
custom plugin file. Once installed, the roles appear namespaced as
`foggyglass-roles:foggyglass-strategist`, etc.

## Keeping in sync

The source of truth for each role's system prompt remains the repo's
`.claude/agents/*.md`. When one changes, recopy it into `agents/` here, bump the
`version` in `.claude-plugin/plugin.json`, re-zip, and re-upload.
