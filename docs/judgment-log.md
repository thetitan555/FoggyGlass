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

### JC-068 · 2026-07-14 · TKT-P2-01 · Jump takeoff impulse + gravity tuning values — provisional
**Decision.** `character_a.gd`: `physics.gravity = FP.from_units(1.0)`; JUMP_N/F/B's
takeoff impulse (frame-1 keyframe `motion_vel_y`) = `FP.from_units(-22.0)`. Given the
engine's integration order (gravity applied the SAME tick as a `motion`-set impulse,
`combat-resolution.md` phase 3), this nets the discrete sum exactly back to `ground_y`
43 ticks after takeoff (`sum_{n=1..43}(-22+n) = 43*44/2 - 22*43 = 0`, verified by actual
headless replay, not hand-derivation). `JUMP_DURATION` (the state's authored `duration`,
now only a safety bound the continuous clamp is expected to land well inside of, not the
flight length itself — AD-043) set to 50.
**Alternatives considered.** Any other gravity/impulse pair nets a different flight
time/apex height — this is pure feel tuning with no structural difference; I targeted a
flight time close to the prior ~45-tick authored arc (continuity of feel) rather than
picking arbitrary round numbers that happened to net zero at a very different length.
**Why.** These are exactly the "gravity values" the ticket names as the Developer's to
pick (mechanism-first, same bar as JC-016/JC-039); numbers are slice-provisional pending
the P2 human-inspection gate (staging note: "frame numbers... provisional tuning").
**Scope.** `character_a.gd` only (`CharacterPhysics.gravity` + JUMP_N/F/B's takeoff
keyframe); no contract/format change. Log for ratification.

### JC-069 · 2026-07-14 · TKT-P2-01 · "Physically airborne" gate for gravity + the continuous clamp — provisional
**Decision.** Gravity accumulation AND the continuous ground clamp+landing (phase 3)
gate on GENUINE physical airborne-ness — `pos_y < ground_y OR vel_y != 0`, AND the
player's current state category is not `CATEGORY_GROUNDED` — not on engine-level
category alone. This is what lets a **launched** HITSTUN reaction (e.g. character A's
`STATE_HITSTUN_LAUNCH`, `vel_y` set by `HitBox.launch`) fall under gravity and land,
while an ordinary **standing** HITSTUN/BLOCKSTUN reaction (the SAME engine category,
`vel_y == 0` throughout) never accrues gravity or clamps.
**Alternatives considered.** Gating on `category != CATEGORY_GROUNDED` alone (simpler,
one condition) — rejected: it would make a standing hit/block reaction accrue gravity
every tick it's in that state (since HITSTUN/BLOCKSTUN aren't GROUNDED either), drifting
`pos_y` downward and eventually mis-firing the landing clamp mid-reaction — a genuine
regression an ordinary punish/combo would hit. Verified by a dedicated regression test
(`test_airborne_physics.gd`'s `_test_grounded_state_never_accrues_gravity` plus manual
trace replay before settling on the two-part gate).
**Why this reading.** AD-043's own text distinguishes "launched (airborne HITSTUN)" from
an ordinary HITSTUN state sharing the same category — category alone cannot express that
distinction (both are literally `CATEGORY_HITSTUN`); only the character's actual physical
state (off the ground, or carrying nonzero vertical velocity this tick) can.
**Scope.** `step_phases.gd`'s `phase3_movement` / `_apply_keyframe_motion` only — no
contract surface change (the movement invariants already state the intended WHAT; this
is the HOW). Log for ratification.

### JC-070 · 2026-07-14 · TKT-P2-01 · Knockdown reaction is the SAME launched-HITSTUN state, no new destination state — provisional
**Decision.** On landing, a player whose airborne state's category is NOT
`CATEGORY_AIRBORNE` (i.e. a launched HITSTUN reaction) is clamped to `ground_y` and has
velocity zeroed, but is **not** transitioned to a different `state_id` — it simply
continues in the reaction state it already entered on hit (e.g. character A's
`STATE_HITSTUN_LAUNCH` / `STATE_AIR_RESET`), which is already a non-actionable,
fixed-`duration` `HITSTUN`-category state. That is AD-043's "knockdown reaction": the
character's own authored stun/duration keeps counting down to wakeup exactly as before,
just now resting on the floor instead of frozen mid-air.
**Alternatives considered.** A dedicated generic `Character.knockdown_state_id` field
(mirroring `idle_state_id`) that every launched-HITSTUN landing redirects into — passed
over because it is a genuine `move-format.md`/`Character` **schema addition** (every
character would need to author one), which is Architect-owned contract territory, not
mine to add unilaterally from a ticket that names no such field. The "no new state"
reading satisfies AD-043's literal text ("No new engine category — knockdown is a
grounded reaction state") with zero schema change, and is verified end-to-end
(`test_airborne_physics.gd`'s `_test_launched_hitstun_lands_into_knockdown_not_idle`:
DP_L's launched defender genuinely goes airborne, returns to `ground_y` while STILL in
`STATE_HITSTUN_LAUNCH`, and only reaches `STATE_IDLE` once its own stun naturally expires).
**Flag-adjacent note.** If the Architect's actual intent was a genuinely distinct
destination state (e.g. so a landed knockdown can swap to a lying-down hurtbox, which
character A's current authoring does not do — `STATE_HITSTUN_LAUNCH`/`STATE_AIR_RESET`
keep the airborne hurtbox throughout), that is a schema addition to make, not one I
invented here. **Scope.** `step_phases.gd`'s `_land` only. Log for ratification.

### JC-071 · 2026-07-14 · TKT-P2-01 · `SimState.FORMAT_VERSION` bump 1→2 + v1-legacy tolerant-field migration — provisional
**Decision.** Bumped `FORMAT_VERSION` 1→2 (AD-034's own stated rule: "a change to any
sub-shape bumps this number instead" — `PlayerState` gained `air_action_used`), and
implemented the migration AD-034 explicitly anticipated ("no migration branch yet —
added when a v2 actually exists," which it now does): `SimState.from_dict` accepts
`v == 1` in addition to `v == FORMAT_VERSION`; `PlayerState.from_dict` reads
`air_action_used` via `d.get("air_action_used", 0)` so a genuine v1 dict (missing the
key entirely) defaults to `false` — the correct value for a state that predates the
air-action economy (AD-046) — with no separate v1-shaped parsing branch needed for this
one default-safe field.
**Alternatives considered.** Not bumping the version at all (simpler, zero migration
code, since there is no real persisted v1 data in circulation pre-release) — rejected:
AD-034 is explicit and present-tense about the bump rule, and explicitly names this
exact trigger ("added when a v2 actually exists"); leaving the version field un-bumped
on a genuine sub-shape change would make the field's own stated purpose a dead letter
the first time it mattered. **Scope.** `sim_state.gd` (`FORMAT_VERSION` + `from_dict`'s
version gate) and `player_state.gd` (`.get`-tolerant read); `test_serialization_version.gd`
updated (hardcoded `FORMAT_VERSION` expectation, the "unrecognized version" probe value,
and a new test proving a genuinely-legacy v1 dict — `"v":1` AND missing the field, not
merely a v2 dict with `"v"` edited — restores with the correct default). No surprise to
AD-034's contract: sub-objects still carry no independent version, per its own rule.
Log for ratification.

### JC-072 · 2026-07-14 · TKT-P2-01 · A's movement goldens re-baselined against actual headless replay, not hand-derivation — provisional (test-only, JC-017/020/021-style)
**Decision.** `test_airborne_actions.gd`'s held/repeated-jump tick numbers and
`test_character_a.gd`'s `_test_jump_arc_integrates` were re-derived by literally
replaying the new (gravity-model) engine headless — a throwaway `TraceHarness` probe
dumping `state`/`py`/`vy` per tick, per this tree's own established methodology (see
this file's `test_airborne_actions.gd` header note) — not hand-computed from the tuning
constants. Landing now occurs 43 ticks after takeoff (not the old model's 45, which
coincided with the authored net-zero arc's own length by construction); a HELD jump
direction now settles into exactly ONE idle tick before re-entering `PREJUMP*` (ticks
45/90/135 = landing, 46/91/136 = re-entry), not the same tick as before — a genuine,
deliberate behavior change (JC-017-style), not a hand-guessed number, because "how long a
jump lasts" is now a physical outcome of gravity + the continuous clamp, not an authored
constant that can be made to coincide with the state's own `duration`-driven
actionability by construction. **Scope.** Test files only
(`test_airborne_actions.gd`, `test_character_a.gd`); no sim code beyond what
JC-068/JC-069/JC-070 already cover. Log for ratification.

### JC-073 · 2026-07-14 · TKT-P2-07 · Round length, transition-beat lengths, and the fresh-round-reset/hash-composition mechanics — provisional
**Decision (round length).** `MatchState.ROUND_LENGTH_TICKS = 5940` — the brief's and
`match-flow.md`'s OWN stated default ("~99 in-game seconds = ~5940 frames at 60 Hz"),
adopted verbatim rather than picking an independent number, since nothing in the ticket
motivates deviating from the spec's own suggested value.
**Decision (transition beats).** `ROUND_START_BEAT_TICKS = 60` (~1s "ready" beat),
`ROUND_END_BEAT_TICKS = 90` (~1.5s "result" beat) — short, plain, unproduced counters
(brief: "no produced intro"), long enough to read the round-end reason before the next
round starts, short enough not to feel like dead air. Pure feel tuning, no structural
weight; provisional pending the P2 human-inspection gate, same bar as JC-068/JC-039.
**Decision (fresh-round reset point + carried fields).** The round-start reset (fresh
symmetric positions + full health + cleared per-move/projectile/last-hit state) happens
ONCE, at the moment `ROUND_END`'s resolution transitions into `ROUND_START`
(`MatchState._enter_next_round`) — not re-applied every tick of the `ROUND_START` beat.
`tick` and `rng` are CARRIED forward across the reset (not reset to 0/reseeded) — they are
match-wide clock/seed state (Tenet 1), not per-round state; `stage` is likewise carried
(the arena doesn't change round to round). `character_id` per side is a parameter threaded
through from whatever the match was wired with (the AD-048 wiring constant lives at the
match-construction caller, e.g. `new_match`, not chosen inside the reset itself).
**Decision (hash composition).** `MatchState.hash_state()` folds its own fields then folds
`sim.hash_state()` as one value (composing with, not re-walking, `SimState`'s own canonical
hash) — per AD-048's own text ("composed with the SimState hash"). The wrapper carries its
own `FORMAT_VERSION` (AD-034 "extends to the wrapper"); `SimState`'s nested `v` inside the
`"sim"` sub-dict is untouched and independent, per AD-034's existing "no sub-object carries
its own version" rule read at the WRAPPER's new outer layer.
**Decision (repeat tie inside sudden death).** The scoring/threshold check
(`_step_round_end`) is generic and re-applied after EVERY round, not special-cased for the
first sudden-death trigger only: if a sudden-death round itself resolves in a tie
(`DOUBLE_KO` or equal-health `TIMEOUT`) and both players are again at/above the match
threshold, the SAME "both at threshold -> `sudden_death=true`, one more round" rule fires
again rather than being undefined or forcing an arbitrary winner. This is a literal
generalization of the stated rule (match-flow.md doesn't name a recursion case), not a new
invented one, but it is a genuine gap-fill with more than one defensible reading (e.g.
"sudden death can only ever run once, arbitrate a tie by X" is equally plausible) — flagged
here explicitly for Architect attention even though it's logged as latitude, since it's the
one call in this ticket closest to "design intent" rather than pure implementation.
**Alternatives considered.** Resetting `tick`/`rng` per round (a "fresh start" every round)
— rejected: `simulation.md` calls `tick` "the authoritative clock" match-wide and AD-048
explicitly keeps RNG a single match-wide seed ("RNG reuses SimState.rng... the seed lives in
serialized state per Tenet 1 regardless" — read as ONE seed for the whole match, not
reseeded per round). Re-deriving the reset every tick of `ROUND_START` (idempotent, simpler
mental model) — passed over as unnecessary churn once a single-application-at-transition
point is just as correct and cheaper to reason about/hash-compare (criterion 7).
**Scope.** `match_state.gd` only; no contract/format change beyond what AD-048 already
specifies. Log for ratification.
