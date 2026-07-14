# PreToolUse hooks — structural enforcement of the protocol

Three hooks turn three prose rules in `docs/protocol.md` into facts a role
literally cannot violate. Registered in `.claude/settings.json` under
`PreToolUse`. Each reads the tool envelope on stdin, emits one JSON decision, and
exits 0.

| Hook | Fires on | Enforces |
|---|---|---|
| `pretooluse_push_gate.py` | Bash, PowerShell | `git push` / `push.bat` / `git remote add\|set-url` are the user's manual gate — denied for every role |
| `pretooluse_ownership.py` | Write, Edit, MultiEdit, NotebookEdit | one-owner-per-artifact (`protocol.md` "Where things live") + upstream correction. Tier 1 = user-only docs (charter/principles/tenets); Tier 2 = the per-role table |
| `pretooluse_determinism.py` | Write, Edit, MultiEdit, NotebookEdit | Technical Tenet 1 on writes into `game/sim/**` — no physics solver, `_process`, wall-clock, frame `delta`, or unseeded RNG |

## Two things that must stay in sync

- **The ownership table.** `pretooluse_ownership.py`'s `OWNERSHIP` list is the
  machine-readable mirror of `protocol.md`'s "Where things live" table. **Edit one,
  edit the other** — a divergence silently mis-enforces ownership.
- **Agent identity → role.** Tier 2 maps the subagent's `agent_type`
  (e.g. `foggyglass-developer`) to a role via `role_of()`. The main thread carries
  no agent fields and maps to `strategist`. If the agent names change, update
  `role_of()`.

## Operational caveats (read before editing a hook)

- **Only a JSON `permissionDecision` of `deny` blocks; exit 0 is required.** These
  scripts never use exit-2 blocking — if you `exit 2`, the JSON is ignored. Keep
  them exit-0.
- **Any unhandled exception fails OPEN** — the tool proceeds. Every script
  swallows a malformed envelope and exits 0 on purpose (a guardrail must not brick
  the session), but it means a *broken* hook is a hook that isn't protecting you.
  Re-run the tests below after any edit.
- **`deny` wins across hooks** (deny > ask > allow). A hook can tighten, never
  loosen. An `allow` does not bypass `settings.json` deny rules.
- **`SIM_GLOBS`** in the determinism hook is `game/sim/**` only. `game/core/**`
  was in the shipped default but no such dir exists here (verified 2026-07-14).
  Re-add if a `game/core/` is created.

## Verification (all passed 2026-07-14, on this Claude Code version)

- Subagent envelopes carry `agent_type` + `agent_id`; the main thread carries
  neither — so Tier 2 works and `STRICT_UNKNOWN_AGENT = True` is safe (an
  unidentifiable agent would be denied, but every real role is identified).
- Deny-on-Write **is honored** in this version, main-thread and subagent alike
  (the reported claude-code #37210 "deny ignored on Edit" does **not** apply here).
- Determinism dry-run over all 92 `game/` files: 0 false positives; positive
  control (a real violation on a sim path) denies; UI paths (`game/scenes/**`) are
  correctly out of scope.

Re-test after any edit:

```bash
# push gate (expect deny)
echo '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}' | python .claude/hooks/pretooluse_push_gate.py
# ownership: developer writing the spec (expect deny)
echo '{"tool_name":"Write","cwd":"/e/FoggyGlass","agent_type":"foggyglass-developer","tool_input":{"file_path":"docs/spec/x.md","content":"x"}}' | python .claude/hooks/pretooluse_ownership.py
# determinism: a violation on a sim path (expect deny)
echo '{"tool_name":"Write","cwd":"/e/FoggyGlass","tool_input":{"file_path":"game/sim/x.gd","content":"func _process(delta):\n\trandi()"}}' | python .claude/hooks/pretooluse_determinism.py
```
