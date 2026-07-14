#!/usr/bin/env python3
"""
PreToolUse hook — enforces Technical Tenet 1 (deterministic simulation)
on writes into the simulation-facing side of the seam.

Contract (Claude Code):
  stdin  : JSON envelope {tool_name, tool_input, cwd, ...}
  stdout : exactly one JSON object, exit 0
  exit 0 + JSON  -> decision honored
  exit 2 + stderr -> hard block (JSON ignored)
  any other exit -> tool PROCEEDS (fail-open). Keep this script boring.

Decisions:
  deny -> unambiguous tenet violation. Escalate, don't work around.
  ask  -> gray zone. The user sees a permission prompt and rules on it.
"""

import json
import re
import sys

# ---------------------------------------------------------------------------
# CONFIG — adjust to your actual tree. Tenet 1 binds the SIM, not the UI.
# Everything outside these globs is the player-facing side of the seam and is
# free to use _process, delta, tweens, whatever.
# ---------------------------------------------------------------------------
SIM_GLOBS = (
    "game/sim/**",
    # NOTE: game/core/** was in the shipped default but no such dir exists in
    # this tree (verified 2026-07-14). Re-add it here if a game/core/ is created.
)

# Test code lives under the sim tree but is not the sim.
EXEMPT_GLOBS = (
    "game/**/tests/**",
    "game/**/test_*.gd",
    "game/**/*_test.gd",
)

# (regex, tenet clause, what to do instead)
DENY_PATTERNS = [
    (r"\b(RigidBody2D|RigidBody3D|CharacterBody2D|CharacterBody3D)\b",
     "Tenet 1: Godot's physics solver never owns gameplay state",
     "Use our own movement + AABB overlap inside the fixed step."),
    (r"\b(move_and_slide|move_and_collide|apply_impulse|apply_central_impulse|apply_force)\s*\(",
     "Tenet 1: Godot's physics solver never owns gameplay state",
     "Integrate motion ourselves inside physics_process."),
    (r"\bfunc\s+_process\s*\(",
     "Tenet 1: gameplay advances on a fixed timestep, never on render timing",
     "Put gameplay in _physics_process. If this is presentation, it belongs "
     "on the player-facing side of the seam, not in the sim tree."),
    (r"\b(get_process_delta_time|get_physics_process_delta_time)\s*\(",
     "Tenet 1: no dependence on frame delta",
     "Advance by whole frames. Frame count is the clock."),
    (r"\b(Time\.get_ticks_msec|Time\.get_ticks_usec|Time\.get_unix_time_from_system"
     r"|Time\.get_datetime_dict_from_system|OS\.get_ticks_msec|OS\.get_system_time_msecs)\s*\(",
     "Tenet 1: no dependence on wall-clock time",
     "The sim's only clock is its own frame counter, which is in serialized state."),
    (r"\b(Engine\.get_frames_drawn|Engine\.get_frames_per_second)\b",
     "Tenet 1: no dependence on render timing",
     "Render cadence must not be observable from the sim."),
    (r"(?<![\w.])(randomize|randi|randf|randi_range|randf_range|randfn|rand_range)\s*\(",
     "Tenet 1: no unseeded randomness",
     "Use an RNG seeded from, and stored in, serialized game state."),
    (r"\.(shuffle|pick_random)\s*\(",
     "Tenet 1: no unseeded randomness (these use Godot's global RNG)",
     "Shuffle/pick with the seeded RNG that lives in serialized state."),
]

ASK_PATTERNS = [
    (r"\bRandomNumberGenerator\.new\s*\(",
     "Tenet 1 permits RNG only if seeded and inside serialized state",
     "Confirm the seed comes from serialized state and round-trips."),
    (r"\bPhysicsServer2D\b|\bPhysicsDirectSpaceState2D\b",
     "Tenet 1 allows engine nodes only as deterministic geometry/overlap "
     "queries inside the fixed step",
     "Confirm this is a pure query, not solver integration."),
]

# `delta` in the sim is a smell. The one legal appearance is the
# _physics_process signature, which convention marks unused as `_delta`.
DELTA_RE = re.compile(r"(?<![\w_])delta(?![\w])")
PHYS_SIG_RE = re.compile(r"func\s+_physics_process\s*\(")


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


def matches_any(path: str, globs) -> bool:
    return any(glob_to_regex(g).match(path) for g in globs)


def new_text(tool_name: str, tool_input: dict) -> str:
    if tool_name == "Write":
        return tool_input.get("content", "") or ""
    if tool_name == "Edit":
        return tool_input.get("new_string", "") or ""
    if tool_name in ("MultiEdit", "NotebookEdit"):
        edits = tool_input.get("edits", []) or []
        return "\n".join(e.get("new_string", "") or "" for e in edits)
    return ""


def scan(text: str):
    """Return (deny_findings, ask_findings)."""
    deny, ask = [], []
    lines = text.splitlines()
    for i, line in enumerate(lines, 1):
        stripped = line.split("#", 1)[0]  # ignore comments
        for rx, clause, fix in DENY_PATTERNS:
            if re.search(rx, stripped):
                deny.append((i, line.strip()[:100], clause, fix))
        for rx, clause, fix in ASK_PATTERNS:
            if re.search(rx, stripped):
                ask.append((i, line.strip()[:100], clause, fix))
        if DELTA_RE.search(stripped) and not PHYS_SIG_RE.search(stripped):
            deny.append((
                i, line.strip()[:100],
                "Tenet 1: no dependence on frame delta",
                "Advance by frames. Mark the unused signature arg `_delta`.",
            ))
    return deny, ask


def emit(decision: str, reason: str):
    json.dump({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": reason,
    }}, sys.stdout)
    sys.exit(0)


def render(findings) -> str:
    out = []
    for line_no, snippet, clause, fix in findings:
        out.append(f"  line {line_no}: {snippet}\n"
                   f"    ! {clause}\n"
                   f"    > {fix}")
    return "\n".join(out)


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)  # never break the session on a malformed envelope

    tool_input = payload.get("tool_input", {}) or {}
    path = (tool_input.get("file_path") or "").replace("\\", "/")
    if not path:
        sys.exit(0)

    # Normalize to a repo-relative posix path if we can.
    cwd = (payload.get("cwd") or "").replace("\\", "/")
    if cwd and path.lower().startswith(cwd.lower()):
        path = path[len(cwd):].lstrip("/")

    if not matches_any(path, SIM_GLOBS) or matches_any(path, EXEMPT_GLOBS):
        sys.exit(0)

    text = new_text(payload.get("tool_name", ""), tool_input)
    if not text.strip():
        sys.exit(0)

    deny, ask = scan(text)

    if deny:
        emit("deny",
             f"BLOCKED by Technical Tenet 1 (deterministic simulation) in {path}:\n"
             + render(deny)
             + "\n\nThe tenets are not yours to relax. If you cannot see how to "
               "make this deterministic, that is an ESCALATION to the Architect "
               "(or, if the tenet itself is the problem, a flag to the user via "
               "docs/flags.md) — not a workaround.")

    if ask:
        emit("ask",
             f"Needs a human ruling — Tenet 1 gray zone in {path}:\n" + render(ask))

    sys.exit(0)


if __name__ == "__main__":
    main()
