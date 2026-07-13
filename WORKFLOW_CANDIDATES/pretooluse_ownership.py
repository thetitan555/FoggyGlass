#!/usr/bin/env python3
"""
PreToolUse hook — enforces one-owner-per-artifact and upstream correction
structurally, so a role literally cannot patch around an upstream artifact.

Two tiers:

  TIER 1 (no agent identity needed): the user-owned documents. Charter,
         principles, tenets. NO agent may write them, ever. This tier is
         always reliable.

  TIER 2 (needs agent identity): the per-role ownership table from
         docs/protocol.md. Depends on Claude Code passing agent identity in
         the hook envelope. Run _probe_hook_input.py once to confirm which
         field carries it in your version.

Fail behavior: with STRICT_UNKNOWN_AGENT = True, an unidentifiable agent gets
Strategist rights only. The top-level session IS the Strategist, so this is
correct for the main thread and fails LOUDLY (not silently) for a subagent
whose identity we cannot read.
"""

import json
import re
import sys

STRICT_UNKNOWN_AGENT = True

WRITE_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}

# ---------------------------------------------------------------------------
# TIER 1 — user-owned. Raise a flag; never edit.
# ---------------------------------------------------------------------------
USER_ONLY = (
    "docs/charter.md",
    "docs/principles.md",
    "docs/technical-tenets.md",
)

# ---------------------------------------------------------------------------
# TIER 2 — ownership table (mirrors docs/protocol.md "Where things live").
# glob -> set of role keys allowed to write.
# Order matters: first match wins.
# ---------------------------------------------------------------------------
OWNERSHIP = [
    ("docs/flags.md",                 {"strategist", "architect", "developer", "qa"}),
    ("docs/judgment-log.md",          {"developer", "architect"}),
    ("docs/judgment-log-archive.md",  {"strategist"}),
    ("docs/flags-archive.md",         {"strategist"}),
    ("docs/protocol.md",              {"strategist"}),
    ("docs/roadmap.md",               {"strategist"}),
    ("docs/audit-criterion.md",       {"strategist"}),
    ("docs/briefs/**",                {"strategist"}),
    ("docs/spec/**",                  {"architect"}),
    ("docs/tickets/**",               {"architect"}),
    ("docs/audits/**",                {"qa"}),
    # QA writes test code; the Developer writes everything else under game/.
    ("game/**/tests/**",              {"qa", "developer"}),
    ("game/**/test_*.gd",             {"qa", "developer"}),
    ("game/**/*_test.gd",             {"qa", "developer"}),
    ("game/**",                       {"developer"}),
]

ROUTE = {
    "docs/charter.md": "the user",
    "docs/principles.md": "the user",
    "docs/technical-tenets.md": "the user",
    "docs/protocol.md": "the Strategist",
    "docs/roadmap.md": "the Strategist",
    "docs/audit-criterion.md": "the Strategist",
    "docs/briefs": "the Strategist",
    "docs/spec": "the Architect",
    "docs/tickets": "the Architect",
    "game": "the Developer",
    "docs/audits": "QA",
}


def glob_to_regex(pattern: str) -> re.Pattern:
    """Translate a posix glob to a regex. `**` spans separators; `*` does not.

    pathlib's PurePath.match() collapses `**` to `*`, which silently breaks
    patterns like game/**/tests/**. Don't use it.
    """
    out, i, n = [], 0, len(pattern)
    while i < n:
        c = pattern[i]
        if pattern.startswith("**/", i):
            out.append("(?:.*/)?")
            i += 3
        elif pattern.startswith("**", i):
            out.append(".*")
            i += 2
        elif c == "*":
            out.append("[^/]*")
            i += 1
        elif c == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(c))
            i += 1
    return re.compile("^" + "".join(out) + "$")


def role_of(payload: dict) -> str:
    """Map the hook envelope to a role key, or '' if unknown."""
    raw = " ".join(str(payload.get(k, "")) for k in
                   ("agent_type", "agent_name", "subagent_type", "agent_id")).lower()
    for key in ("architect", "developer", "strategist"):
        if key in raw:
            return key
    if re.search(r"\bqa\b|foggyglass-qa", raw):
        return "qa"
    # The main thread is the Strategist. It reports as general-purpose or
    # carries no agent fields at all.
    if not raw.strip() or "general-purpose" in raw:
        return "strategist"
    return ""


def owner_hint(path: str) -> str:
    for prefix, who in ROUTE.items():
        if path == prefix or path.startswith(prefix.rstrip("/") + "/"):
            return who
    return "its owner (see docs/protocol.md)"


def emit(decision: str, reason: str):
    json.dump({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": reason,
    }}, sys.stdout)
    sys.exit(0)


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    if payload.get("tool_name") not in WRITE_TOOLS:
        sys.exit(0)

    tool_input = payload.get("tool_input", {}) or {}
    path = (tool_input.get("file_path") or "").replace("\\", "/")
    if not path:
        sys.exit(0)

    cwd = (payload.get("cwd") or "").replace("\\", "/")
    if cwd and path.lower().startswith(cwd.lower()):
        path = path[len(cwd):].lstrip("/")
    path = path.lstrip("./")

    # --- Tier 1 ---------------------------------------------------------
    if path in USER_ONLY:
        emit("deny",
             f"BLOCKED: {path} is owned by the user. No role edits it — not the "
             f"Strategist, not the Architect, not you.\n\n"
             f"If you believe it is wrong, that is exactly what the "
             f"upstream-correction rule is for: append a flag to docs/flags.md "
             f"with owner: User, and surface it. You raise; the owner resolves.")

    # --- Tier 2 ---------------------------------------------------------
    role = role_of(payload)

    for glob, allowed in OWNERSHIP:
        if glob_to_regex(glob).match(path):
            if not role:
                if STRICT_UNKNOWN_AGENT and "strategist" not in allowed:
                    emit("deny",
                         f"BLOCKED: could not determine which role is writing "
                         f"{path}, and this artifact is owned by "
                         f"{owner_hint(path)}.\n\n"
                         f"If you are the top-level Strategist session this is a "
                         f"hook misconfiguration — run "
                         f".claude/hooks/_probe_hook_input.py to see which field "
                         f"carries agent identity, then update role_of().")
                sys.exit(0)

            if role not in allowed:
                emit("deny",
                     f"BLOCKED: you are the {role.title()}. {path} is owned by "
                     f"{owner_hint(path)}.\n\n"
                     f"Upstream correction: you may RAISE a problem with this "
                     f"artifact, but only its owner RESOLVES it. Append a flag "
                     f"to docs/flags.md naming the owner, and surface it to the "
                     f"orchestrator. Never patch around it, never edit it, never "
                     f"decide on your own authority that it is a bug or fine.")
            sys.exit(0)

    sys.exit(0)  # unowned path (scratch, config, README) — not our business


if __name__ == "__main__":
    main()
