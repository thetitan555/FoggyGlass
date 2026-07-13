# Installing the hooks

## 1. Copy files

Into `E:\FoggyGlass\`:

```
CLAUDE.md                                  (replaces existing)
.claude/settings.json                      (merge if you already have one)
.claude/hooks/pretooluse_determinism.py
.claude/hooks/pretooluse_ownership.py
.claude/hooks/pretooluse_push_gate.py
.claude/hooks/_probe_hook_input.py         (temporary — delete after step 4)
.claude/agents/foggyglass-architect.md     (replaces existing)
.claude/agents/foggyglass-developer.md     (replaces existing)
.claude/agents/foggyglass-qa.md            (replaces existing)
```

Then **delete `.claude/agents/foggyglass-strategist.md`.** See the note at the
bottom of this file.

## 2. Check the interpreter and path expansion

Hooks are a shell command. Two things vary on Windows.

```powershell
python --version      # if this fails, use `py` in settings.json
```

`$CLAUDE_PROJECT_DIR` is documented but may not expand under `cmd`. If a hook
never fires, hardcode the path:

```json
"command": "python \"E:/FoggyGlass/.claude/hooks/pretooluse_push_gate.py\""
```

Forward slashes. They work fine on Windows and dodge JSON escaping.

## 3. Confirm registration

Start Claude Code in the repo and run `/hooks`. All three should appear under
PreToolUse. Matchers are case-sensitive.

Test one directly:

```powershell
echo '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}' | python .claude/hooks/pretooluse_push_gate.py
```

Expect a JSON object with `"permissionDecision": "deny"`.

## 4. Probe for agent identity, then arm the ownership hook

The ownership hook's Tier 1 (nobody edits charter / principles / tenets) works
unconditionally. **Tier 2 — the per-role table — needs Claude Code to tell the
hook which subagent is running.** Confirm that it does.

Temporarily add to `.claude/settings.json` under the `Write|Edit|...` matcher:

```json
{ "type": "command", "command": "python \"$CLAUDE_PROJECT_DIR/.claude/hooks/_probe_hook_input.py\"" }
```

Dispatch `foggyglass-developer` on any trivial write. Then read
`.claude/hooks/_probe.log`. You are looking for `agent_type`, `agent_name`,
`subagent_type`, or `agent_id`, and what the main thread reports.

- **If a field carries the subagent name:** confirm `role_of()` in
  `pretooluse_ownership.py` matches on it. Remove the probe.
- **If no field carries it:** Tier 2 cannot work in your version. Set
  `STRICT_UNKNOWN_AGENT = False`, keep Tier 1, and rely on the `tools:`
  allowlist plus prompt instructions for the rest. Tell me and I'll rework it
  around per-role settings files instead.

Delete the probe hook either way. Never leave one registered.

## 5. Set your sim globs

`pretooluse_determinism.py` has `SIM_GLOBS` at the top, currently
`game/sim/**` and `game/core/**`. Tenet 1 binds the simulation, not the UI —
the player-facing side of the seam legitimately uses `_process` and `delta`.
Point these at your actual sim tree before the first Developer dispatch, or the
hook will either fire constantly on UI code or never fire at all.

## Things worth knowing before you rely on these

- **Exit code 1 blocks nothing.** Only exit 2 blocks. These scripts use the
  other supported path: exit 0 with a JSON `permissionDecision`. Don't mix —
  JSON is ignored when you exit 2.
- **Any unhandled exception fails open.** The tool proceeds. Every script
  swallows a malformed envelope and exits 0 on purpose; that's the right
  tradeoff for a guardrail, but it means a hook you've broken is a hook that
  isn't protecting you. Re-run the `echo | python` test after any edit.
- **When several PreToolUse hooks disagree, `deny` wins.** Precedence is
  deny > defer > ask > allow. A hook can tighten policy, never loosen it.
- **A hook returning `allow` does not bypass deny rules in settings.**
- **`deny` on the Edit tool has been reported as ignored** in at least one
  version (claude-code issue #37210). Verify the block actually blocks with a
  deliberate violation before you trust it.
- **The determinism hook is a regex.** It cannot see through indirection. It
  raises the cost of a violation from zero to "you must argue with the hook,"
  which is the entire point — it is not a proof of determinism. QA's harness is
  the proof.

## Why `foggyglass-strategist.md` is deleted

A subagent's markdown body becomes its own system prompt, loaded into a fresh
context window when it is dispatched. The **top-level session never loads a
subagent file.** It loads `CLAUDE.md`.

So `.claude/agents/foggyglass-strategist.md` was only ever read if you
dispatched the Strategist *as a subagent* — at which point it sits in an
isolated context window whose intermediate work the main thread never sees,
which breaks the protocol's own requirement that the human keep a sightline on
every handoff. And if you never dispatched it, the Strategist prompt was never
loaded at all: you have been talking to a generic Claude Code session that read
`CLAUDE.md` and happened to have three subagents available.

The orchestrator seat is the top-level session. The Strategist *is* the
orchestrator. Therefore the Strategist's prompt is `CLAUDE.md`. That's what the
rewrite does.

**One thing to verify:** dispatch `foggyglass-developer` and ask it, as its
whole task, to report whether it can see the contents of `CLAUDE.md` in its
context. If yes, the Strategist prompt is riding along in every subagent's
context and you'll want to trim the persona sections down. If no — which is what
I'd expect — you're clean.
