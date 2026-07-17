# Flag Ledger

> Open flags only (plus resolved-awaiting-relay). Closed entries live in
> `flags-archive.md`. Mechanism, ownership, and relay: `protocol.md` → "How a
> flag works."

---

### [resolved] 2026-07-16 · raised-by: User (P2 human gate) · owner: Developer · re: input path → sim (`game/`)
Problem: **~1 second of input lag on both characters.** Play/pause (`P`/`N`) respond
immediately; character commands do not. Reported at the P2 human-inspection gate.
This is tax under `audit-criterion.md` ("dropped/eaten inputs" / clunky UX are tax,
always) and it makes the gate's whole legibility question unanswerable — you cannot
judge whether a mixup is readable *as it happens* through a second of lag.
Diagnosis lead (a hypothesis to test, not a finding — the Developer owns the call):
that `P`/`N` are unaffected suggests the defect is below the Godot input layer and in
the sim-driver path — e.g. the sim not advancing at the intended fixed rate, or
stepping only on input events rather than on the clock. Note this may be the common
root of the two flags below; diagnose before fixing all three separately.
Headless tests are structurally blind to this: the sim is stepped directly by the
harness, so the driver that feeds it in the real app is untested.
---
Resolution: **Root cause confirmed by direct reproduction (not the Strategist's
"sim not advancing" hypothesis — that was ruled out; the sim advances every real
tick just fine).** `MatchTickHost._advance` queried input sources with
`get_input(state.sim.tick)`. `state.sim.tick` is FROZEN through the non-`ACTIVE`
`ROUND_START`/`ROUND_END` `phase_timer` beats (match-flow.md: "Combat is not
advanced outside `ACTIVE`"), but the real driver (`training_mode.gd
_physics_process`) keeps calling `produce_next()` on both sources every real
physics tick regardless of `match_phase` (correctly so — sources are dumb/generic,
Tenet 2, and have no notion of match phase). Every non-`ACTIVE` tick therefore
produced a frame nobody ever consumed at that index, so once `ACTIVE` began the
query index was permanently `ROUND_START_BEAT_TICKS` (60 = exactly 1s @ 60Hz)
frames stale — every subsequent input read back what the player had done ~1s
ago, for the entire round (and the gap widens further after every
`ROUND_END`+next-`ROUND_START`). `P`/`N` were unaffected because pause/step are
host-level controls via `_unhandled_input`, entirely outside the `InputSource`
path — exactly the clue the flag itself named. Fix: `MatchTickHost` now tracks
its own `_frames_queried` counter (incremented once per `_advance()` call, 1:1
with how many times `produce_next()` has actually run) instead of trusting
`state.sim.tick` to equal that count — restores input.md's produce-before-query
invariant without touching `state.sim.tick`, the match phase machine, or any
contract. `game/sim/match_tick_host.gd`. Regression test added
(`game/tests/test_match_tick_host.gd`) that drives the real per-tick driver
pattern through a full `ROUND_START` beat and asserts the first `ACTIVE` tick
already reflects same-tick input — verified failing on the prior code, passing
on the fix. This is also the confirmed root cause of the divekick flag below
(re-tested, see that entry) — NOT of the box-vanish flag, which is a distinct,
independent defect (see that entry).

### [resolved] 2026-07-16 · raised-by: User (P2 human gate) · owner: Developer · re: sim state / geometry overlay
Problem: **when a character is hit, their collision and hurtbox disappear** and stay
gone until that character receives another input. Reported at the P2 human gate.
Two very different severities and the diagnosis decides which: if the boxes are
*absent from sim state*, this is a combat-resolution defect (a character with no
hurtbox during hitstun is unhittable — a correctness hole the golden net did not
catch); if the boxes are present in state but the **overlay stops drawing them**,
it's a render defect against the charter's centerpiece legibility surface. Either
way it fails `audit-criterion.md` half 1 (the player cannot find out what happened).
Possibly the same root cause as the input-lag flag above (a sim that only advances
on input would freeze geometry exactly like this) — diagnose the two together.
---
Resolution: **Diagnosed by direct reproduction — the MORE SEVERE reading. Boxes are
genuinely ABSENT FROM SIM STATE (a combat-resolution defect, not a render defect),
and it is a DISTINCT, INDEPENDENT root cause from the input-lag flag above (ruled
out sharing a cause — reproduced with the lag fix already applied and it still
happens identically).** The defect: `StepPhases._resolve_one_hit` enters the
DEFENDER into `hb.hit_reaction` / `hb.block_reaction` — a plain `state_id` int
authored on the ATTACKER's `HitBox` — via `character_def.get_state(reaction_state)`,
i.e. it looks that id up in the DEFENDER's OWN state list. Every prior test/gate
(P0/P1, and P2's own headless pass) only ever exercised a character against
ITSELF (a mirror matchup, or vs. the generic P0 test character), where attacker and
defender share one id namespace — so `hb.hit_reaction` always coincidentally
resolved. AD-048's real, asymmetric A-vs-B match is the FIRST case where attacker
and defender are different characters authored with disjoint, non-overlapping
state-id ranges (A: 100s–160s; B: 300s+) — reproduced directly: when A hits B, B is
entered into state_id 120 (A's own `STATE_HITSTUN`, meaningless in B's roster),
`character.get_state(120)` returns null for B, and every subsequent tick B's `move`
resolves to null: `PlayerView.boxes` goes empty (both hurtbox AND pushbox — matches
"collision and hurtbox disappear"), AND — because phase 2's `move != null` guards
gate literally every transition including the stun-expiry exit — B is PERMANENTLY
stuck in that unresolvable state (also unhittable, also un-actionable) until an
external event rebuilds `SimState` from scratch (`_enter_next_round`'s fresh-round
reset), which is presumably what read as "recovers on input" at the gate — a full
round reset, not anything the hit player pressed.
**This is a contract gap in `move-format.md`'s `HitBox.hit_reaction`/
`block_reaction` definition (a single attacker-authored `state_id`, meaningful only
when attacker and defender share an id namespace), not a patchable implementation
bug — I have NOT patched around it. Flagged up to the Architect below**
(`raised-by: Developer · owner: Architect`), per protocol's upstream-correction
rule. No code change for this entry.

### [open] 2026-07-16 · raised-by: Developer · owner: Architect · re: `docs/spec/move-format.md` (`HitBox.hit_reaction`/`block_reaction`)
Problem: **`HitBox.hit_reaction`/`block_reaction` is authored as a single `state_id`
int on the ATTACKER's move data, but `StepPhases._resolve_one_hit` applies it by
calling `character_def.get_state(reaction_state)` — i.e. it is resolved against the
DEFENDER's own state list.** State ids are character-local (move-format.md never
says otherwise; character A's own ids run 100s–160s, character B's run 300s+, by
each character's own authoring convention). This silently worked throughout P0/P1
and P2's own headless pass because every test/gate before now only ever matched a
character against itself (a mirror matchup, or the shared generic P0 test
character) — attacker and defender happened to share one id namespace, so the
lookup always coincidentally resolved. AD-048's real A-vs-B match is the first case
where it doesn't: reproduced directly (Developer, this session) — when character A
hits character B, B is entered into `state_id 120` (A's own `STATE_HITSTUN`, which
does not exist in B's roster), `get_state` returns null, and B is left with an
unresolvable `state_id` — no boxes (unhittable, invisible pushbox/hurtbox — the
"boxes vanish when hit" flag above), and permanently non-actionable (every phase-2
transition, including the ordinary stun-expiry return to idle, is gated on
`move != null`), recoverable only by an external full-state rebuild (a round
reset). Any cross-character hit in the real match currently breaks the defender
this way — this is not a one-off, it is every A-vs-B contact.
I have **not** picked a fix — this touches the `HitBox` schema (move-format.md) and
both characters' already-authored content (`game/content/character_{a,b}.gd`), a
contract multiple things depend on, and there are several materially different
ways to resolve it (e.g. (a) `hit_reaction`/`block_reaction` become a small
CATEGORY enum — generic HITSTUN/BLOCKSTUN/KNOCKDOWN — resolved through each
character's OWN authored mapping, mirroring how `idle_state_id`/
`knockdown_state_id` are already per-character fields rather than raw cross-
character ids; (b) some other resolution scheme entirely). That decision affects
feel/format and is squarely yours to make, not mine to invent or patch around
(protocol.md upstream-correction). Flagging up rather than guessing.
---
Resolution (owner fills): …

### [resolved] 2026-07-16 · raised-by: User (P2 human gate) · owner: Developer · re: `spec/character-b.md` (divekick) / input path
Problem: **the user could not perform a divekick at all** at the P2 gate. B's three
divekicks are the legibility-critical centerpiece of TKT-P2-06 and carry their own
gate item (B-3, the three must be visually distinguishable) — which cannot be judged
while the move cannot be executed. QA's headless pass proved the trajectory/timing
half, so the moves resolve correctly *in the sim*; the failure is in reaching them
from a human hand. Likely downstream of the input-lag flag (an air command has only
the jump's airborne window to land in, and a second of lag exceeds it) — **diagnose
after the lag is fixed and re-test before treating this as a separate defect.**
If it survives the lag fix and the cause is the spec's command/window definition
rather than the implementation, flag it up to the Architect — do not retune the
window on your own authority.
---
Resolution: **Confirmed downstream of the input-lag flag above — same root cause,
no separate defect, no spec/window change needed.** With the pre-fix code, a
scripted realistic press sequence (tap `UP` to jump, then hold `DOWN`+button for
the divekick shortly after) against B's actual jump (`JUMP_DURATION` = 50 ticks)
and divekick cancel window showed the jump itself didn't even visibly take effect
until ~60 ticks after the press (the same fixed offset as the lag flag) — i.e. the
player's very reference point (what they see on screen) was already stale by more
than the whole airborne window's length, making the timing unrecoverable in live
play even though a scripted replay (which doesn't need live visual feedback) could
still eventually land it. Re-tested against the flag-1 fix (`game/sim/
match_tick_host.gd`, same commit): the identical press sequence now reaches
`STATE_DIVEKICK_L` cleanly and promptly (tick 8 of a 50-tick jump, plenty of
margin). No change to `character-b.md`'s command/window definition, no
retuning — the divekick was always reachable in-sim (QA's headless pass already
proved this); only the driver's input timing blocked a human hand from reaching
it. No code change beyond the flag-1 fix.

### [open] 2026-07-16 · raised-by: User (P2 human gate) · owner: Developer · re: `game/scenes/training_mode.tscn` (HUD layout)
Problem: **the on-screen text overlays overlap and are becoming hard to read.** The
match result (KO / TIMEOUT / DOUBLE_KO) is a P2 gate item that must be "legible on
its face"; timeout text does appear, but readability is degrading as readouts
accumulate (TKT-P2-08 added several). Opacity introduced by our own instrument is
tax, not polish deferred to P4 — the instrument is the surface we audit *through*.
Note for the owner: the user hand-edited `ControlsLegend`'s offsets at the gate to
read the screen (commit `7c88462`, "moving text overlays around so i can read them").
That edit is a **workaround, not intended layout** — treat it as evidence of the
defect and re-solve the layout properly; don't preserve it and don't silently revert
it without saying so.
---
Resolution (owner fills): …
