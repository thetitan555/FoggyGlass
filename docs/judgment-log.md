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
**Decision (same-tick KO-vs-timeout priority).** If a KO (or double-KO) and the timer
reaching 0 both become true on the SAME tick, `_step_active` resolves it as a KO/
double-KO, never `TIMEOUT` — the health outcome that actually happened this tick is
the more specific, more legible truth ("why did the round end" reads as "someone got
KO'd," not "oh, and also the clock happened to hit zero"). `match-flow.md` doesn't
name this exact coincidence; read as the obvious tie-break rather than a genuine
open question, but recorded since it does shape `last_round_end_reason` — the
serialized, legibility-load-bearing field the brief cares most about getting right.
**Alternatives considered.** Resetting `tick`/`rng` per round (a "fresh start" every round)
— rejected: `simulation.md` calls `tick` "the authoritative clock" match-wide and AD-048
explicitly keeps RNG a single match-wide seed ("RNG reuses SimState.rng... the seed lives in
serialized state per Tenet 1 regardless" — read as ONE seed for the whole match, not
reseeded per round). Re-deriving the reset every tick of `ROUND_START` (idempotent, simpler
mental model) — passed over as unnecessary churn once a single-application-at-transition
point is just as correct and cheaper to reason about/hash-compare (criterion 7).
**Scope.** `match_state.gd` only; no contract/format change beyond what AD-048 already
specifies. Log for ratification.

### JC-074 · 2026-07-15 · TKT-P2-02 · Double-tap window value + recognition shape — provisional
**Decision.** `InputBuffer.DOUBLE_TAP_WINDOW = 12` — adopted verbatim from AD-046's own
placeholder text ("~12f"), rather than picking an independent number. Recognition
(`double_tap_recognized`) scans the window oldest→newest through a 3-state machine (await
first press → await release → await second press), mirroring `motion_recognized`'s existing
scan shape but over press/release EDGES of one direction rather than an ordered token
sequence — a continuous hold never advances past "await release," so an ordinary walk/dash-
hold never spuriously satisfies a double-tap. `ButtonMapEntry.double_tap` is checked FIRST
and exclusively in `entry_satisfied` (never falls through to the plain-direction path it
otherwise shares button_index/motion shape with) — a double-tap entry and an ordinary
pure-direction entry (AD-032) are genuinely distinct recognition paths, never merged.
**Alternatives considered.** Folding double-tap into `_motion_tokens` as a new "motion" (e.g.
a 2-token same-direction sequence) — rejected per AD-046's own text ("a re-press is not a
direction sequence; conflates two recognizer concepts"), and mechanically wrong besides:
`_frame_satisfies`/`motion_recognized` model an ORDERED sequence of DIFFERENT tokens
completing once, not a press/release/press edge pattern of the SAME token.
**Scope.** `input_buffer.gd`, `button_map_entry.gd`. No contract shape change beyond what
`move-format.md`'s own `ButtonMapEntry.double_tap` entry already names. Log for ratification.

### JC-075 · 2026-07-15 · TKT-P2-02 · Air-action mechanism shape: engine-generic, phase-3, velocity-only (no state transition) — provisional
**Decision.** Air dash / double jump are NOT authored via `CancelRule`/`ButtonMapEntry` at
all (unlike the ground dash, which explicitly is one) — they are a generic engine check
(`StepPhases._apply_air_action`) run in phase 3 for every physically-airborne player every
tick, gated only by `air_action_used` and two new per-character `CharacterPhysics` fields
(`air_dash_speed`, `double_jump_velocity`; both default 0 — a character with no such kit
simply authors nothing, mirroring `gravity`/`jump_velocity`'s own 0-disables convention).
Neither action transitions state — both are pure velocity SETS on whatever airborne state
the player is already in, run immediately BEFORE gravity is added the same tick (mirroring
the takeoff impulse's own documented "gravity accrues the same tick as the set" contract).
This reads AD-046's own text literally: it describes both as "set horizontal velocity, zero
vertical" / "re-impulse" — never "routes to a state," which is language AD-046 reserves
explicitly for the ground dash's double-tap entries ("routing to a dash state"). Divekick
not spending the air action falls out for free: it is authored later as its own
CancelRule/state, entirely outside this mechanism — there is nothing here to un-couple.
**Alternatives considered.** Authoring air actions as CancelRules on the jump states
(consistent with the air-normal-cancel pattern, AD-039) — rejected: a CancelRule names a
destination STATE, but neither action has one (both keep the player in whatever airborne
state it's already in); forcing a state-machine shape onto a pure velocity effect would be
the less honest reading of AD-046's own wording, and would need a "self-cancel" (target ==
current state) with no engine precedent.
**Priority order (double jump checked before air-dash-forward before air-dash-back)** in
`_apply_air_action` — arbitrary among three mutually-exclusive-in-practice input axes (UP vs.
forward/back), recorded for completeness; no observed scenario makes the order matter.
**Scope.** `step_phases.gd`, `character_physics.gd`. No contract/format change (`air_action_
used`'s shape is unchanged from TKT-P2-01; these are new CharacterPhysics authoring fields,
same latitude precedent as JC-068's gravity/jump_velocity addition). Log for ratification.

### JC-076 · 2026-07-15 · TKT-P2-02 · Double jump requires a STRICT this-tick edge, not a buffered one — provisional
**Decision.** `InputBuffer.direction_pressed_edge` checks ONLY "held now (age 0) AND not
held the tick immediately before (age 1)" — no `COMMAND_BUFFER` lookback window, unlike
every other direction/button recognizer in this file. Discovered via an actual regression
(`test_airborne_actions.gd`'s held-jump tests started failing — the jump's OWN initiating
UP-press was still "inside" a 6-frame buffered edge-scan several ticks into the SAME flight,
so `direction_pressed_edge` falsely fired the instant the character became airborne,
zeroing/overwriting the takeoff impulse's `vel_y` with a same-tick double-jump re-impulse of
magnitude 0 for character A, corrupting the whole arc). A strict, zero-leniency edge check
is the only reading that lets a player hold UP continuously from the initial jump takeoff
without instantly (and silently) spending the double jump, while still correctly firing on a
genuine release-then-re-press once truly airborne.
**Alternatives considered.** A buffered edge scan over `COMMAND_BUFFER` (my first attempt,
reverted after the regression); requiring a full double-tap of UP instead of a single fresh
press (would satisfy AD-046's spirit too, but AD-046's own text says "up while airborne," not
"double-tap up" — reserving double-tap language specifically for the dash/air-dash case, so a
plain single-press reading is the more literal one, made safe by the strict-edge fix rather
than by adding double-tap semantics UP doesn't ask for).
**Verification.** `test_dash_air_action.gd`'s `_test_held_up_from_takeoff_does_not_spend_
double_jump` pins this exact regression as a standing test, in addition to the full existing
suite (`test_airborne_actions.gd` et al.) passing green again after the fix.
**Scope.** `input_buffer.gd` (`direction_pressed_edge`) only. No contract change. Log for
ratification.

### JC-077 · 2026-07-15 · TKT-P2-02 · Air-dash speed / double-jump velocity test-only tuning values — provisional (test-only)
**Decision.** `test_dash_air_action.gd` exercises the air-action mechanism against character
A's builder with `physics.air_dash_speed = FP.from_units(6.0)` and `physics.double_jump_
velocity = FP.from_units(18.0)` MUTATED ONTO A TEST-LOCAL COPY of `CharacterA.build_
character()` — character A's shipped, baked `.tres` kit is untouched (A does not carry these
values; A's `66`/`44` dash is the only air/dash-adjacent content this ticket adds to A's
actual authored kit). These two numbers are arbitrary, chosen only to be nonzero and mutually
distinguishable from character A's other movement speeds in test assertions — real per-
character tuning for whichever character actually ships an air dash / double jump (character
B, TKT-P2-05/06) is that ticket's call, not this one's.
**Scope.** Test file only. No production content change. Log for ratification.

### JC-078 · 2026-07-15 · TKT-P2-03 · `MoveState.is_crouch` — the stance signal AD-045's block-height check reads — provisional
**Decision.** AD-045 / `combat-resolution.md` say directional-block validity reads "whether the
defender is in a crouch-category state (already tracked, AD-038 crouch stance)" — but no engine
signal for "is this state a crouching one" actually existed: `MoveState.category` is the small
fixed engine set (`GROUNDED`/`AIRBORNE`/`HITSTUN`/`BLOCKSTUN`/`HITSTOP`) and does not distinguish
stand from crouch at any of those categories (character A's `STATE_CROUCH` and `STATE_IDLE` are
both plain `CATEGORY_GROUNDED`; `STATE_BLOCKSTUN` and `STATE_CROUCH_BLOCKSTUN` are both plain
`CATEGORY_BLOCKSTUN`). Added `MoveState.is_crouch: bool = false` (default false, authored content,
mirrors `loop`) so phase 5 can read the DEFENDER's current-state flag to derive stance, with no
`SimState`/`PlayerState` shape change (state_id — already serialized — is what resolves to this
flag through `MoveRegistry`, exactly like `category`/`pushbox` resolve today).
**Alternative considered.** A `Character`-level named group (`crouch_state_ids`, mirroring
AD-044's `cancel_groups` pattern) instead of a per-`MoveState` flag — also data-only, also no
`SimState` change. Rejected only for locality: a state's own stance is a property of that state,
readable at the state itself rather than cross-referenced through a second authored table; the
two are behaviorally identical (same defender-stance answer, same seam surface), so this is a
"how," not a "what," call.
**Scope.** `move-format.md`'s `MoveState` schema table does not currently list this field —
flagging the gap so the Architect can fold it into the schema table on ratification (or overturn
in favor of the group-table alternative); either reading satisfies AD-045 identically. Character
A's `STATE_CROUCH` and `STATE_CROUCH_BLOCKSTUN` are authored `is_crouch = true`; every other A
state defaults false (unaffected).

### JC-079 · 2026-07-15 · TKT-P2-03 · `CancelGroup` packaged as its own Resource, not a `Dictionary`/inline field — provisional
**Decision.** AD-044 specifies group-target resolution's BEHAVIOR precisely (a buffered command
whose destination is a group member satisfies the cancel) but not the group's own STORAGE shape.
Added `game/sim/data/cancel_group.gd` (`CancelGroup`: `id: int`, `members: Array[int]`) and
`Character.cancel_groups: Array[CancelGroup]`, mirroring the existing `button_map: Array[
ButtonMapEntry]` convention — a typed Resource list keeps the `.tres` diffable/golden-able
(move-format.md's own "authoring stays data, never engine code" bar) exactly like every other
authored collection on `Character`.
**Alternative considered.** A `Dictionary[int, Array[int]]` field directly on `Character` (fewer
lines, no new file) — rejected only for stylistic consistency: every other `Character` collection
in the format is a typed `Resource` list, and a bare `Dictionary` doesn't serialize to the same
diffable `.tres` shape QA goldens the rest of the format against (move-format.md criterion 3).
Behaviorally identical either way — this is a "how," not a "what," call.
**Scope.** Internal data shape only; `CancelRule.target`/`target_is_group` (the actual contract
surface AD-044 touches) are unchanged.

### JC-080 · 2026-07-15 · TKT-P2-04 · Ground-contact despawn scoped to `gravity != 0` (an "arc" projectile), not every projectile — provisional
**Decision.** AD-047's text names the despawn rule specifically as "an ARC projectile whose
`pos_y >= ground_y` despawns" — read literally, this scopes the new despawn check to a projectile
with nonzero `gravity`, not to every live projectile regardless of authored gravity. Implemented
the ground-contact despawn (`step_phases.gd` phase 3) gated on `gravity != 0`, so a hypothetical
future 0-gravity projectile authored at/below `ground_y` (e.g. a ground-level slide/zoning shot —
AD-047 explicitly reserves "ground zoning" as *not* this mechanism's role) is never affected by it.
Character A's fireball (gravity 0) is unaffected either way since it never reaches `ground_y` in
its authored flight; the distinction is only observable for a projectile deliberately spawned at
floor height.
**Alternative considered.** Applying the `pos_y >= ground_y` despawn unconditionally to every live
projectile (arc or not) — also satisfies every acceptance criterion the ticket names (A's fireball
never reaches `ground_y` regardless), and is one line simpler (no `gravity != 0` guard). Rejected
because it would silently foreclose a legitimate future 0-gravity ground-level projectile the AD's
own "not ground zoning" framing anticipates as out-of-scope for THIS despawn rule specifically, not
for projectiles in general — Tenet 3 (build for extension) favors the narrower, literal reading.
**Scope.** `step_phases.gd`'s projectile-integration loop only; `ProjectileData.gravity`'s own
meaning (0 = straight line) is unchanged either way. Test-covered (`test_arc_projectile.gd`'s
`_test_non_arc_projectile_does_not_ground_despawn`).
