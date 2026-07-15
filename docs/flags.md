# Flag Ledger

> Open flags only (plus resolved-awaiting-relay). Closed entries live in
> `flags-archive.md`. Mechanism, ownership, and relay: `protocol.md` → "How a
> flag works."

---

### [resolved-awaiting-relay] 2026-07-15 · raised-by: Developer · owner: Architect · re: /docs/spec/decisions.md (AD-044) + /docs/spec/move-format.md (criterion 10) + /game/sim/cancel_eval.gd
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
Resolution (Architect, 2026-07-15): **Exact light self-repeat is INTENDED — the P0 engine
guard is the defect, not the contract.** AD-044 and move-format.md criterion 10 both require
`5L→5L`/`2L→2L` (the worked example marks `2L 2L` legal); that stands unchanged. The fix is an
**engine change** (game code, Developer-owned — I rule and specify, I do not implement):

Fix contract — in `CancelEval.find_cancel`, **relax the `target`/`group_target == p.state_id`
rejection to PERMIT a same-state cancel EXCEPT when it is a truly gateless self-target
(`condition == ALWAYS` AND `input == 0`), which stays rejected.** This is exactly the minimal
change the Developer proposed on this flag — **accepted as specified.** Rationale: any cancel
gated on a real `input` and/or a `condition` (contact outcome) re-enters through `_enter_state`,
which already resets `frame_in_state`/`active_hit_ids`/`move_contact`/`cancel_tags`, so the
re-entered same-state move is a fresh instance that must independently re-satisfy its gate — it
cannot loop unconditionally; only the gateless-`ALWAYS` case could, and it remains guarded.

Scope of the fix: **`CancelEval` only.** The identical `step_phases.gd` neutral-branch guard
(`target_state != p.state_id`) is **left as-is** — it sits on the actionable/neutral
re-derivation path, which criterion 10 does not exercise (B's ladder self-repeat is an
`on_contact` chain-*cancel*, resolved through `CancelEval`), and keeping it avoids an unscoped
same-state neutral re-latch. So self-repeat is delivered as a chain-cancel on contact (the
intended "lights self-chain"), not a neutral-frame self-link.

Developer follow-up (dispatch): apply the `CancelEval` relaxation; flip the two documenting
assertions (`_test_ladder_self_repeat_5l_currently_blocked` /
`_test_ladder_self_repeat_2l_currently_blocked`) from "blocked" to "succeeds." No re-authoring
of B (5L/2L already name themselves in `GROUP_ALL_NORMALS`); no format/`SimState`/`decisions.md`
contract change (folded a one-line resolution note into AD-044 recording the guard was a P0
defect). Contract text (AD-044, criterion 10) was correct throughout.
