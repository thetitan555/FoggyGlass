#!/usr/bin/env python3
"""
Temporary diagnostic. Register this as a PreToolUse hook, dispatch one
subagent, then read .claude/hooks/_probe.log.

You are looking for whichever key carries the subagent's identity
(agent_type / agent_name / subagent_type / agent_id). Confirm it appears for
a dispatched subagent and what it contains for the main thread. Then update
role_of() in pretooluse_ownership.py and DELETE this hook.

Never leave a probe registered. It exits 0 always and blocks nothing.
"""

import datetime
import json
import pathlib
import sys

LOG = pathlib.Path(__file__).with_name("_probe.log")


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        payload = {"_error": "unparseable stdin"}

    payload.pop("tool_input", None)  # keep the log readable
    stamp = datetime.datetime.now().isoformat(timespec="seconds")
    with LOG.open("a", encoding="utf-8") as fh:
        fh.write(f"--- {stamp}\n{json.dumps(payload, indent=2, default=str)}\n")

    sys.exit(0)


if __name__ == "__main__":
    main()
