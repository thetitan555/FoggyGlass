# Flag Ledger

> Any role appends; the **owner** of the flagged artifact resolves. This ledger
> holds **open flags** (plus recently-resolved ones awaiting relay); once a
> resolution has been relayed, the entry moves to `flags-archive.md` — the
> permanent record — so this file stays a cheap read. Mechanism: raiser appends +
> tells the user; user relays to the owner; owner writes the resolution line,
> flips `[open]` to `[resolved]`, saves (git checkpoints happen via the user's
> helpers, per the protocol); user relays back. See `protocol.md` → "How a flag
> works."

---

### [open] 2026-07-03 · raised-by: QA · owner: Architect · re: /docs/spec/simulation.md (AD-024)
Problem: AD-024 states the immutable-roster / install-once determinism precondition
(MoveRegistry), but no acceptance criterion gives QA something to *assert* it
against — it rests on wiring discipline (the code is compliant) plus a QA harness
watch item. The type system does not prevent a mid-run `install()`/`clear()`, which
would be a silent determinism break. Ask: should install-once / immutable-across-a-
run be a stated, checkable invariant (as F-001 did for produce-before-query ordering
→ input.md crit 7), so the precondition is verifiable rather than only conventional?
Spec-observability question, not an implementation bug; non-blocking (F-009).
---
Resolution (owner fills): …

### [open] 2026-07-03 · raised-by: Developer · owner: Architect · re: /docs/spec/simulation.md (SimState table — TKT-P0-08/09 fields)
Problem (raise-only — a SimState *shape* addition, so a contract change I flag, not
latitude — per AD-024 "extensible-as-systems-land … added here under an AD at the
ratification pass" and the F-002/F-005 precedent). TKT-P0-08 (input buffer + cancels)
and TKT-P0-09 (throws + multi-hit/rehit) each need new MUTABLE, per-tick sim truth
that must survive snapshot/restore and be canonically hashed (AD-023). All are
serialized (`to_dict`/`from_dict`), deep-cloned (`clone`), and covered by the hash in
fixed field order; variable-length runs fold a count separator first (AD-023). Five
new `players[i]` fields, grouped by the ticket that introduces each:

TKT-P0-08 (cancels; AD-015/017/022):
  - `cancel_tags: PackedInt32Array` — cancel tags granted to THIS player (as attacker)
    by a connecting hitbox in phase 5 of tick T, consumable by the cancel phase (phase 2)
    starting T+1 (AD-017 grant→consume latency — because phase 2 precedes phase 5, a tag
    set in phase 5 of T is first visible to phase 2 of T+1 for free). Cleared on every
    state entry (a new move's tags are its own). Hashed as a variable-length run
    (count-then-tags, order-committing).
  - `move_contact: int` — the outcome of this player's CURRENT move for CancelRule
    `condition` evaluation: 0 none / 1 hit / 2 block / 3 whiff-resolved. Set on the
    ATTACKER in phase 5 on connect (hit/block); set to whiff once the move's last active
    frame passes with no connect (so `on_whiff` cancels can fire). Cleared on state entry.
    Plain int. (An `on_contact` cancel matches contact == hit OR block.)

TKT-P0-09 (throws + rehit; AD-016):
  - `active_hit_frames: PackedInt32Array` — PARALLEL to `active_hit_ids` (AD-026): index
    i holds the tick `active_hit_ids[i]` last connected, so a `rehit_interval` hitbox can
    cadence (re-hit only once `rehit_interval` frames have elapsed since the last connect
    of that id_group). Same variable-length-run hash treatment as `active_hit_ids`;
    cleared on state entry alongside it (they stay length-synced).
  - `throw_tech_window: int` — frames remaining in which the thrown DEFENDER may tech
    (input a throw to escape to neutral, no damage — AD-016). Set on throw connect,
    decremented in phase 7 (not frozen by hitstop — a throw connect sets no mutual
    hitstop at P0). 0 = not in a tech window. Plain int.
  - `thrown_by: int` — the attacker index that threw this player (for tech resolution /
    combo attribution), or -1 if not thrown. Set on throw connect, cleared when the tech
    window closes or the throw resolves. Plain int.

Ask: ratify these five into the simulation.md SimState per-player table under an AD
(as AD-024 folded F-002 and AD-026 folded F-005), or prefer a different shape (e.g.
throw state on a nested record, or deriving `move_contact` from `last_hit` rather than
a per-attacker field — I chose a per-attacker field because `last_hit` is a single
global record and cannot express two attackers' independent contact outcomes, mirroring
why AD-026 rejected keying single-hit on `last_hit`). Implemented now so 08/09 land and
tests run; provisional until ratified. Non-blocking to the batch; a shape change is a
localized edit to PlayerState + the hash.
---
Resolution (owner fills): …
