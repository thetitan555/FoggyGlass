#!/usr/bin/env python3
"""
PreToolUse hook — `git push` is the user's manual gate.

Roles commit freely to local history. Pushing to origin is irreversible and
belongs to the user. This makes that a fact rather than a paragraph repeated
in three documents.

Also blocks push.bat, which is the user's thin manual push-gate and must be
run by the user against a clean tree (its `git add -A` would otherwise sweep
a subagent's mid-write WIP into one catch-all commit).
"""

import json
import re
import sys

SHELL_TOOLS = {"Bash", "PowerShell"}

BLOCKED = [
    (re.compile(r"\bgit\b[^\n;|&]*\bpush\b", re.I), "git push"),
    (re.compile(r"\bpush\.bat\b", re.I), "push.bat"),
    (re.compile(r"\bgit\b[^\n;|&]*\bremote\b[^\n;|&]*\b(add|set-url)\b", re.I),
     "git remote add/set-url"),
]

REASON = (
    "BLOCKED: `{what}` is the user's manual gate.\n\n"
    "Per docs/protocol.md: roles commit; the user pushes. Commit freely to "
    "local history — `git status`, stage, `git commit` are all yours. Pushing "
    "to origin is the one irreversible step and it stays with the user.\n\n"
    "Finish your unit of work, commit it, and tell the user the branch is "
    "ready to push. Do not attempt to push, and do not ask the user to grant "
    "a one-off exception."
)


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    if payload.get("tool_name") not in SHELL_TOOLS:
        sys.exit(0)

    tool_input = payload.get("tool_input", {}) or {}
    cmd = tool_input.get("command") or tool_input.get("script") or ""
    if not cmd:
        sys.exit(0)

    for rx, what in BLOCKED:
        if rx.search(cmd):
            json.dump({"hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": REASON.format(what=what),
            }}, sys.stdout)
            sys.exit(0)

    sys.exit(0)


if __name__ == "__main__":
    main()
