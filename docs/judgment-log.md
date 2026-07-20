# Judgment-Call Log

> **Live file = provisional (unratified) bodies only.** Every entry is a
> *latitude* call — how to build something the spec already decided *what* it is;
> anything touching a contract, feel, or tenet is a flag (`flags.md`), not an entry
> here. The Developer appends; the Architect ratifies/overturns each before that
> feature's audit.
>
> **Closed entries** (ratified · overturned · superseded) live verbatim in
> `judgment-log-archive.md`, each headed `### JC-NNN` — Grep it by id or keyword,
> never read it whole (`grep "^### JC" …` reconstructs the full log-order list on
> demand). Next id = the highest `### JC-NNN` in the archive, +1.
>
> **Maintenance split:** Developer appends a provisional body below; Architect
> flips its status in place on ruling; Strategist sweeps closed bodies to the
> archive on the per-session ledger sweep. Format/rationale: `protocol.md`.

---

## Provisional (awaiting ratification)

<!-- JC-100..115 ratified and swept to judgment-log-archive.md (Strategist, 2026-07-17/20).
     JC-116..117 (2026-07-20 loose-ends pass) await Architect ratification in the fresh session. -->
### JC-116 · 2026-07-20 · flag "re: instrument ergonomics — match reset" · `do_reset()` in match mode restarts the whole match (fresh `MatchState.new_match`), not a snapshot restore — provisional
**Decided:** `TrainingMode.do_reset()` — what `R`/`tm_do_reset` already binds to (`_unhandled_input`) — now, in match mode, calls a new private `_restart_match()`: build a fresh `MatchState.new_match(CharacterA.CHAR_ID, CharacterB.CHAR_ID)` (the SAME construction `_ready_match_mode()` used to build the match the first time) and hand it to `_match_tick_host` via its own pre-existing `set_match_state()`. `capture_reset()`/`has_reset_point()` — the situation-SNAPSHOT slot — are UNCHANGED, still the JC-098 no-op/false in match mode; this is a narrower, separate operation ("restart from the top"), not the missing MatchState-shaped `TrainingHarness` twin JC-098 declined to build.
**Why this doesn't reopen JC-098:** JC-098's scope trim was specifically about the snapshot/restore slot (`capture_reset`/`do_reset`-as-restore/`has_reset_point`), which needs a MatchState-shaped `TrainingHarness` twin (real, additive control-surface work JC-098 correctly held outside TKT-P2-08's scope). "Restart the match" needs neither a snapshot slot nor a harness twin — both pieces it needs (`MatchState.new_match`, `MatchTickHost.set_match_state`) already existed for other reasons before this change; this is wiring one existing call to another, not new match-layer semantics. Per the dispatch's own instruction, this is exactly the "clean wiring" branch, not the "stop and flag" branch.
**Deliberately untouched:** `_source_p1`/`_source_p2` (their recorded buffers / dummy record-playback mode are orthogonal to match state) and `MatchTickHost._frames_queried` (its own field doc already establishes it is a plain per-real-tick production counter into the sources' growing `_answers` array, decoupled from `state.sim.tick` BY DESIGN — a match restart resets the tick clock, not the sources' production history, so nothing here can desync).
**Alternative passed over:** build the full MatchState-shaped `TrainingHarness` twin JC-098 deferred, and route the match restart through a proper capture/restore slot. Rejected as materially larger than the flag asked for ("bind R to restart the match," not "add mid-match snapshotting to match mode") and exactly the kind of scope growth the dispatch instructed to stop and flag rather than build — this fix needed neither a snapshot nor new state-machine behavior, so it stayed wiring.
**New regression coverage:** `_test_match_mode_do_reset_restarts_the_match` (`test_training_mode_shell.gd`) drives a match past ROUND_START into ACTIVE with real tick progress, calls `do_reset()` through the shell's own public surface, and asserts the match is genuinely back at ROUND_START/full health/tick 0 (not merely that some field changed), then re-drives it through ACTIVE again to confirm the restarted match is still steppable, not half-wired.
Serving: `docs/flags.md` (2026-07-17, "re: instrument ergonomics — match reset"); JC-098.

### JC-117 · 2026-07-20 · flag "re: 6H's hitbox never reaches a crouching hurtbox" · hitbox height 20 -> 45 (same top, extended bottom), not a repositioned box — provisional
**Decided:** `6H`'s hitbox (`character_b.gd::_build_6h`) changes ONLY `h`: `Box.make(20, -85, 30, 20)` -> `Box.make(20, -85, 30, 45)`. `x`/`y`/`w` are UNCHANGED — the box still starts at the same top (`y=-85`, already above the standing hurtbox's own head, preserving the existing wind-up/overhead read) and the same horizontal reach QA already verified sufficient at the tested 40-unit gap (the flag's own finding: "confirmed the horizontal reach is sufficient; the failure is purely vertical").
**Why `h=45` specifically:** new bottom edge = `-85+45 = -40`. Against `_hurt_crouch()` (`y=-55, h=55` -> world `-55..0`), that overlaps `-55..-40` — **15 units of real margin** past the crouch hurtbox's top, not a bare graze (verified through the real engine, not by construction alone — see the new dynamic test below). Against B's own `2L` (the character's low poke, hitbox `y=-20, h=15` -> world `-20..-5`), the new bottom edge (`-40`) stays a clear **20 units above** that band — `6H` still never reaches anywhere near the leg/shin region a genuine low occupies, so it keeps reading as "an overhead over a low poke" rather than becoming a mid-body strike. Against `_hurt_stand()` (`-80..0`), the box now overlaps `-80..-40` (40 units) — comfortably inside the upper body, well short of the legs.
**Alternative passed over:** move `y` down instead of increasing `h` (e.g. `y=-70, h=20` -> `-70..-50`), keeping the box's original SIZE and just repositioning it. Rejected: that only closes the gap with ~5 units of margin (bottom `-50` vs crouch top `-55`) — thinner than the ORIGINAL 10-unit gap this flag is fixing, i.e. trading "never overlaps" for "barely grazes," the same class of fragile-margin defect in miniature. Extending `h` instead keeps the wind-up-clarifying top position untouched (JC-115, the same session's forward-creep tuning, is anchored to this exact state) while giving real margin on the bottom.
**Verified, not inferred:** re-baked `data/character-b.tres` (this project's convention: any `character_b.gd` content edit re-bakes the golden authoring artifact) and deliberately re-baselined `test_golden_regression.gd`'s `character_b_frame_data.golden.txt` — diffed the fresh dump against the prior golden first and confirmed the ONLY differing line is this exact hitbox's `h` field (`1310720` -> `2949120` fixed-point, i.e. 20 -> 45 world units), nothing else moved. Re-ran `test_character_b.gd::_test_6h_is_reachable_and_not_shadowed_by_5h` green (unaffected — it only checks input resolution and the authored `guard_height` field, not geometry).
**New regression** (QA's placeholder, `test_qa_p2_regate_overhead_enforcement.gd`, closed alongside this fix per its own header): `_test_6h_hits_crouching_wrong_stance` drives `6H` against a defender held in `STATE_CROUCH`, actively holding down-back throughout (mirrors the file's own H-divekick crouch test), and asserts the hit connects (`CONTACT_HIT`, `block_valid=false`) rather than whiffing — the exact defect the flag reported.
Serving: `docs/flags.md` (2026-07-17, "re: 6H's hitbox never reaches a crouching hurtbox"); `character-b.md` B-4; AD-045.
