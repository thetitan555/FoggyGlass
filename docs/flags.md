# Flag Ledger

> Open flags only (plus resolved-awaiting-relay). Closed entries live in
> `flags-archive.md`. Mechanism, ownership, and relay: `protocol.md` → "How a
> flag works."

---

### [open] 2026-07-15 · raised-by: Developer · owner: Architect · re: /docs/spec/decisions.md (AD-044) + /docs/spec/move-format.md (criterion 10) + /game/sim/cancel_eval.gd
Problem: AD-044 / move-format.md both explicitly require that character B's lights
self-chain "including exact repeat" (5L→5L, 2L→2L legal — `decisions.md`'s own worked
example marks `2L 2L` as a light self-repeat). Empirically verified (a throwaway scratch
trace, and now locked in as a documented, currently-failing-as-expected assertion in
`game/tests/test_character_b.gd`) that this never fires: `CancelEval.find_cancel` rejects
ANY cancel — concrete OR group-resolved — whose destination equals the player's CURRENT
`state_id` (`cancel_eval.gd`, `target == p.state_id` / `group_target == p.state_id` →
`continue`), and `step_phases.gd`'s own ordinary actionable/buffered-command branch
carries an identical guard (`target_state != p.state_id`) on the move's exact last frame.
So a literal same-state re-entry is unreachable ANYWHERE in the current engine, for any
character, not just via `CancelEval`. This code predates AD-044 (P0, written before any
character needed self-repeat — character A has none) and was never exercised by a test
until this ticket surfaced it via character B's ladder.

Every OTHER ladder transition (light→different-light, light→medium/heavy, medium/heavy
opposite-stance toggling, e.g. `2H→5H`) is unaffected and verified working end-to-end.
Only the literal self-repeat step is blocked. B's `5L`/`2L` are authored exactly per
AD-044's stated rule (each names itself as a legal member of its own ladder group,
`GROUP_ALL_NORMALS`), so no re-authoring will be needed once this is resolved — only the
two currently-documenting-the-gap test assertions
(`_test_ladder_self_repeat_5l_currently_blocked` /
`_test_ladder_self_repeat_2l_currently_blocked`) need their expectation flipped.

This is a "cannot author what the existing engine capability supports" situation per
TKT-P2-05's own explicit instruction ("no engine change... that is a flag to the
Strategist/Architect, not a reason to add engine code in this ticket") — raised rather
than patched. A plausible minimal fix: in `CancelEval.find_cancel`, allow a same-state
target when the rule's `condition` is NOT `ALWAYS`-with-`input==0` (i.e., when the
transition is genuinely gated on a real player input/contact outcome, re-entering the
same state is a meaningful "fresh instance of the same move" — `_enter_state` already
resets `frame_in_state`/`active_hit_ids`/`move_contact`/`cancel_tags` correctly for this);
the `target == p.state_id` guard would still protect against a truly gateless
(`ALWAYS`+`input==0`) self-target looping forever in one tick. This is the Architect's
call to make (or reject in favor of a different fix), not mine to implement here.
---
Resolution (owner fills): …
