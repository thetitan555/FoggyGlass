# FoggyGlass Roles

Packages the four FoggyGlass pipeline roles as Cowork/Claude Code subagents so
they can be invoked by name:

- `foggyglass-strategist` — direction, priority, roadmap, briefs
- `foggyglass-architect` — technical spec, architecture decisions, tickets
- `foggyglass-developer` — implementation against the spec
- `foggyglass-qa` — testing, drift control, audits

This directory (`plugins/foggyglass-roles/`) is the **authoritative, editable
source** for the four role prompts. The plugin is the delivery mechanism that
makes them callable inside Cowork, which does not read a project's
`.claude/agents/` directory the way Claude Code does.

## Install (Cowork)

Customize (left sidebar) → Browse plugins → upload the `foggyglass-roles.zip`
custom plugin file. Once installed, the roles appear namespaced as
`foggyglass-roles:foggyglass-strategist`, etc.

## Keeping in sync

To change a role: edit the file under `agents/` here (the source of truth), bump
the `version` in `.claude-plugin/plugin.json`, re-zip the plugin, and re-upload
it via Cowork's Customize → Browse plugins.
