# Judgment-Call Log

> Owned by the **Developer** (appends entries); the **Architect** ratifies or
> overturns each at least once per feature, before audit (protocol cadence).
> Written for other roles to pick up: QA reads it for drift, the Architect to
> fold ratified calls into the spec, future work to inherit decisions instead of
> re-deriving them. Every entry is a *latitude* call — how to build something the
> spec already decided *what* it is. Anything touching a contract, feel, or tenet
> is a flag (`flags.md`), not an entry here.
>
> **This file is fronted by an index and holds only _provisional_ (unratified)
> bodies.** Closed entries — ratified, overturned, or superseded — live verbatim
> in `judgment-log-archive.md`; pull one by JC-id from the index below (Read by
> offset, or Grep the id). Do not read the archive whole. This keeps the
> cold-start read flat however long the decision history grows — the token-economy
> reason is in `protocol.md`.
>
> **Maintaining it (same shared-write split as the log itself):** the Developer,
> appending an entry, writes its body under "Provisional" **and** adds its index
> line (status `provisional`); the Architect, ruling, flips that entry's status to
> `ratified`/`overturned` in the body **and** on its index line; the Strategist
> moves closed bodies to `judgment-log-archive.md` on the per-session ledger sweep
> (the index line stays here, its status token now marking it archived). Status
> values: **provisional · ratified · overturned · superseded**.

---

## Index — every judgment call

> One line per entry, in log order. A `provisional` entry's body is under
> "Provisional" below; every other status means the body is in
> `judgment-log-archive.md` — pull it by id.

- JC-001 · 2026-07-02 · TKT-P0-01 · `FP` as a static-function class — ratified
- JC-002 · 2026-07-02 · TKT-P0-01 · `to_int` truncates toward zero; `round_to_int` is the AD-014 rounding rule — ratified
- JC-003 · 2026-07-02 · TKT-P0-01 · 64-bit product overflow left unguarded, documented — ratified (behavior) + contract fixed in AD-014
- JC-004 · 2026-07-02 · TKT-P0-01 · Tick host advances against a minimal seam, not real `SimState`/`step` — ratified (01→03 ordering ruled intended)
- JC-005 · 2026-07-02 · TKT-P0-01 · Headless `SceneTree` test runners with exit-code gating — ratified
- JC-006 · 2026-07-02 · TKT-P0-02 · `InputFrame` value is a plain masked `int`, class is a namespace — ratified
- JC-007 · 2026-07-02 · TKT-P0-03 · Canonical state hash is FNV-1a over an ordered integer value stream — ratified into spec (AD-023)
- JC-008 · 2026-07-02 · TKT-P0-03 · `InputHistory` capacity CAP = 32 frames — ratified
- JC-009 · 2026-07-02 · TKT-P0-03 · Input sources sampled parent-before-child via tree order in the scaffold — ratified (ordering now an owned invariant via F-001)
- JC-010 · 2026-07-02 · TKT-P0-04/05 · Inspection views + serialized-state backing fields packaged as plain-data classes — ratified (packaging latitude; the SimState fields were F-002/AD-024)
- JC-011 · 2026-07-02 · TKT-P0-05 · "First actionable frame" for derived recovery = duration+1 (recovery = total − last_active) — ratified INTO the spec
- JC-012 · 2026-07-02 · TKT-P0-07(pre-wired at 05) · Live-advantage party identification reads defender = the player in stun — ratified INTO the spec
- JC-013 · 2026-07-02 · TKT-P0-06 · Phase pipeline packaged as a `StepPhases` static module; each AD-009 phase a named function — ratified
- JC-014 · 2026-07-02 · TKT-P0-06 · `_enter_state` puts a freshly-entered state ON frame 1 this tick; phase 2 skips the advance for a same-tick entry — ratified
- JC-015 · 2026-07-02 · TKT-P0-06 · SOCD default (LR→neutral, UD→up) + facing resolution as one `resolve_intent`; raw stays raw in history — ratified into spec
- JC-016 · 2026-07-02 · TKT-P0-07 · Damage scaling as a single `DamageScaling` definition (hit-count table); the done-bar's single hit is unscaled 100% — ratified
- JC-017 · 2026-07-02 · TKT-P0-06 · Pushbox mutual separation splits the overlap in half, odd remainder to player 1 (deterministic) — ratified
- JC-018 · 2026-07-02 · TKT-P0-07 · `neutral_restored_this_tick` is a RISING EDGE: both-actionable now AND not both-actionable at the start of this tick — ratified into spec (AD-025)
- JC-019 · 2026-07-02 · TKT-P0-06 · A looping state wraps `frame_in_state` modulo its duration — ratified
- JC-020 · 2026-07-03 · F-006 (test fix) · `test_inspection_view` reads hitstop_remaining against the sim's own post-step value, and pins the corrected constant (3→2) — ratified (test-only latitude)
- JC-021 · 2026-07-03 · F-007 (test fix) · `test_combat` phase-presence check uses `Callable(StepPhases, name).is_valid()` instead of instance `has_method` on the class — ratified (test-only latitude)
- JC-022 · 2026-07-03 · TKT-P0-08 · Motion recognition = greedy ordered-token scan over the 9-frame window; a motion-id→token-sequence table — ratified
- JC-023 · 2026-07-03 · TKT-P0-08 · A CancelRule's `input` command is resolved via the button_map entry whose target == the rule target (raw-button fallback); group targets deferred — ratified
- JC-024 · 2026-07-03 · TKT-P0-09 · Throw tech-window length authored via the throwbox's (otherwise-unused) `blockstun` field; tech = undo-damage-both-to-idle — overturned (folded into AD-029: dedicated `HitBox.tech_window`)
- JC-025 · 2026-07-03 · TKT-P0-09 · Rehit cadence via a parallel `active_hit_frames` run + produced-tick comparison; clash detected when both throwboxes connect the same tick — ratified
- JC-026 · 2026-07-03 · F-011 (test fix) · `_test_cancel_requires_tag` isolates the tag gate to LIGHT's COMMITTED window; adds a gate-liveness assertion — superseded by JC-027
- JC-027 · 2026-07-03 · F-011 recurrence (test fix) · `_test_cancel_requires_tag` gate isolation via committed-window CONTRAST + positive control — ratified (test-only latitude) — SUPERSEDES/CORRECTS JC-026
- JC-028 · 2026-07-03 · AD-024 / F-009 (simulation.md crit 11) · `MoveRegistry` install-generation token packaged as a static `int` counter with an `install_generation()` accessor — ratified
- JC-029 · 2026-07-03 · simulation.md crit 11 · The crit-11 install-generation assertion lives in `test_sim_state.gd` — ratified (test-only latitude)
- JC-030 · 2026-07-04 · TKT-P1-04 · `RecordPlaybackSource` production model: one `produce_next()` per tick feeding a uniform `_answers` reproducibility history, distinct from the mode-specific `_buffer` script — ratified
- JC-031 · 2026-07-04 · TKT-P1-03 · `TrainingHarness` (new class) owns snapshot/restore + the single reset slot, sits above `TickHost`, and is the "driver" that produces registered dummies before stepping — ratified
- JC-032 · 2026-07-04 · TKT-P1-0P · Authored projectile shell named `ProjectileData` (not `Projectile`), resolved through a new `ProjectileRegistry` by `data_id` — mirrors `Character`/`MoveRegistry` exactly — ratified INTO the spec (AD-030)
- JC-033 · 2026-07-04 · TKT-P1-0P · Spawn fires once on the exact tick a spawning keyframe's range is ENTERED (`frame_in_state == frame_start`), not once per covered frame — ratified INTO the spec (AD-030)
- JC-034 · 2026-07-04 · TKT-P1-0P · A projectile does not integrate (move) or age (lifetime decrement) on the same tick it spawns — mirrors the existing `was_frozen` hitstop convention — ratified INTO the spec (AD-030)
- JC-A-01 · 2026-07-04 · TKT-P1-10 · Jump arc authored as a hand-baked triangular vel_y profile (no gravity primitive) — ratified
- JC-A-02 · 2026-07-04 · TKT-P1-10 · Six concrete `CancelRule`s per cancellable normal, not one group-targeted rule — ratified
- JC-A-03 · 2026-07-04 · TKT-P1-10 · DP blockstun authored as a small placeholder value, not back-solved to the spec's approximate on-block number — ratified
- JC-A-04 · 2026-07-04 · TKT-P1-10 · Air-normal hitstun authored as one flat value, not height-dependent — ratified (mechanism scope raised as F-014)
- JC-A-05 · 2026-07-04 · TKT-P1-10 · `2L` authored to hitstun 15 (internally consistent), not back-solved to the spec's stated +3 on-hit — ratified (spec fixed to +6)
- JC-035 · 2026-07-04 · TKT-P1-11 · `HitBox.is_throw` reconciled to `hit_kind` as a computed property — ratified
- JC-036 · 2026-07-04 · TKT-P1-11 · dev-test scenarios state-inject a non-attacking invuln state to isolate the phase-4 gate — ratified
- JC-037 · 2026-07-04 · TKT-P1-12 · `CancelEval._input_buffered` honors `CancelRule.input == 0` as "no input gate" — ratified INTO the spec
- JC-038 · 2026-07-04 · TKT-P1-12 · PREJUMP's ALWAYS-cancel window moved to frame 3 (one frame before duration) — ratified with a spec note; off-by-one ruled intended
- JC-039 · 2026-07-04 · TKT-P1-13 · `AirHeightScaling`'s four provisional numbers — ratified
- JC-040 · 2026-07-04 · TKT-P1-05..09 · Recovering an interrupted Batch 3: verification approach + view/view-model split adopted as the batch's structure — ratified (view/view-model split adopted as a project-wide convention)
- JC-041 · 2026-07-04 · TKT-P1-05 · Missing `.tscn` scenes built; overlays auto-wired by duck-typed `set_source` convention — ratified
- JC-042 · 2026-07-04 · TKT-P1-06 · Projectile hitbox given its own draw color instead of a `hit_kind`-based BoxView split — ratified
- JC-043 · 2026-07-04 · TKT-P1-09 · Recognized-command projection reconstructs `InputHistory` from `PlayerView.input_history` to call the sim's own recognizer — ratified
- JC-044 · 2026-07-08 · TKT-P1.1-01 · AD-035 render framing implemented as a position/scale transform on `GeometryOverlay` itself (not a `Camera2D`); exact zoom/ground-line/margin constants and fixed placeholder stage bounds (not a live seam read) — ratified
- JC-045 · 2026-07-08 · TKT-P1.1-02 · Control-surface key bindings (P/N/C/R/M/J/K/L), a single cycling key for the dummy mode-switch (not three mode keys), frame-step bound as a direct passthrough with no auto-pause, and a static-InputMap-reading `ControlsLegend` node — ratified
- JC-046 · 2026-07-08 · P1.1 gate flag (arrow-key left/right) · Wired `STATE_WALK_F`/`STATE_WALK_B` into `character_a.gd`'s `button_map` as pure-direction commands (AD-032 pattern, mirroring jump) — these states/keyframes were already authored but unreachable from any input; button_index=-1 entries listed after the standing normals so a button always wins over a bare directional hold — ratified
- JC-047 · 2026-07-08 · P1.1 gate flag (player sinks below the floor) · Jump arc's 22-rise/23-fall frame split (equal magnitude both halves) nets +6 units of permanent downward drift every jump; fixed to 22 rise / 1 zero-velocity apex hang / 22 fall (nets exactly zero) rather than changing either tuned speed value — ratified
- JC-048 · 2026-07-08 · TKT-P1.1-03 · AD-034's fail-fast guard implemented as `push_error` + `from_dict` returning `null` on an unrecognized `"v"` (rather than raising/crashing or returning a still-parsed state); new dedicated test file `test_serialization_version.gd` (mirrors `test_sim_state.gd`'s SceneTree-runner shape) — ratified
- JC-049 · 2026-07-09 · TKT-P1.1R-01 · Trace-row exact field order/text encoding: `tick`, then `p0.*` over `{state,frame,cat,px,py,vx,vy,act,stun,sk,face}`, then `p1.*` (same order), then any requested optional fields; optional `boxes` renders as `KIND:x,y,w,h` entries `;`-joined per player — ratified (folded into trace-harness.md Contract 3)
- JC-050 · 2026-07-09 · TKT-P1.1R-01 · The inline-assert runner is a GDScript API (`TraceHarness.check`/`row_at`), not a parser for Contract 3's illustrated `P1:`/`assert tick=... field=...` text-DSL — ratified (GDScript API is the near-term assert host; text-DSL is illustrative-only + a deferred additive extension — folded into trace-harness.md)
- JC-051 · 2026-07-09 · TKT-P1.1R-01 · `InputScript` grammar edge cases: a repeated button letter in one token (e.g. `LL`) is accepted (idempotent OR); digit `0` and any character outside `1-9`/`L`/`M`/`H` is malformed; button letters are case-sensitive (no lowercase aliasing) — ratified (folded into trace-harness.md Contract 1)
- JC-052 · 2026-07-09 · TKT-P1.1R-01 · `InputScript.compile`'s hard-error boundary uses `assert(false, msg)` (mirrors `InputSource.validate`); added a non-asserting `InputScript.is_well_formed_token` as an additive testing hook, not part of Contract 1's `compile` signature — ratified (error-mechanism + additive-helper latitude)
- JC-053 · 2026-07-09 · TKT-P1.1R-01 · An empty/omitted P2 script defaults to neutral via `RecordPlaybackSource`'s existing empty-buffer-loops-neutral behavior, not an explicitly-compiled N-tick neutral buffer — ratified (observable P2 behavior matches Contract 2)
- JC-054 · 2026-07-10 · TKT-P1.1R-02 · A `Keyframe.spawn_offset_y` (fireball release point) reflected as a scalar-point negation (`new_y = -old_y`) rather than the box formula `-(y+h)` — ratified (point-form of AD-037's reflection; folded into AD-037)
- JC-055 · 2026-07-10 · TKT-P1.1R-02 · Orientation verified via direct `InspectionView`/`PlayerView` reads, not `TraceHarness`'s formatted `boxes` string; CROUCH exercised by direct state-injection, not scripted input — ratified (test-authoring latitude; same AD-011 surface)
- JC-056 · 2026-07-10 · TKT-P1.1R-03 · Crouch `button_map` entry placed immediately after the DOWN+button crouch normals (still before the walk entries) — ratified (authoring-order latitude; behaviorally identical)
- JC-057 · 2026-07-10 · TKT-P1.1R-03 · Crouch-block scenario verified via a direct `SimState.step` + `InspectionView` test, not `TraceHarness` (fixed 200-unit spawn gap has no position-override hook) — ratified (test-instrument latitude; reads AD-011 either way)
- JC-058 · 2026-07-10 · TKT-P1.1R-03 · `TestSupport` (P0 test character) gains a bare-RIGHT `button_map` entry -> `STATE_WALK` so `test_combat.gd`'s walk-integration test can hold AD-038's re-derivation — ratified (test-fixture latitude; holds under the AD-038 exit correction)
- JC-059 · 2026-07-10 · TKT-P1.1R-04 · Air-normal `CancelRule` window authored as `[1, JUMP_DURATION-1]` (frames 1..44 of the 45-frame arc), not `[1, JUMP_DURATION]` — ratified (true reachable window; folded into AD-039)
- JC-060 · 2026-07-10 · TKT-P1.1R-04 · `PREJUMP_F`/`PREJUMP_B` factored through a shared `_build_prejump(state_id, target)` builder; new state ids (160/161) placed outside the full 100-109 movement block rather than renumbering existing ids — ratified (data-structure/id-allocation latitude)
- JC-061 · 2026-07-10 · TKT-P1.1R-04 · `test_character_a.gd::_test_no_gatlings_no_jump_cancels` updated to exempt `JUMP_N/F/B` (source) and `PREJUMP_F/B` (source) from the pre-existing gatling/jump-cancel guards, since AD-039 makes a jump state's ALWAYS-cancel into `j.L/M/H` (and each prejump's into its jump) sanctioned content, not a violation the guard was meant to catch — ratified (test-guard latitude; JC-058 class)

---

## Provisional (awaiting ratification)

> Full bodies of not-yet-ruled calls live here until the Architect ratifies or
> overturns them; then the status flips and the Strategist sweeps the body to the
> archive. New entries append to this section.

### JC-049 · 2026-07-09 · TKT-P1.1R-01 · Trace-row exact field order/text encoding — ratified
**Serves:** `docs/spec/trace-harness.md` Contract 3 ("Row = one dumped tick... fixed
field order") and acceptance criterion 4 (round-trip identically).
**Decision.** `TraceHarness.format_row` emits, in order: `tick=<n>`, then for
player 0 the fields `state, frame, cat, px, py, vx, vy, act, stun, sk, face` (each
`p0.<field>=<value>`), then the identical set for player 1 (`p1.*`), then any
requested optional fields in the order `boxes` (per player, immediately after
that player's default block), `advantage` (`adv.value`, `adv.plus_player`,
`adv.neutral_restored`), `last_hit` (`hit.attacker`, `hit.defender`,
`hit.damage_dealt`, `hit.was_block`, `hit.contact_depth`,
`hit.air_height_hitstun_delta`). Optional `boxes` renders as
`KIND:x,y,w,h` box entries `;`-joined within one `p{i}.boxes=` field (KIND one of
`HURT/HIT/THROW/PUSH`, `BoxView`'s own kind names).
**Alternative considered.** Interleaving p0/p1 per-field (`p0.state p1.state
p0.frame p1.frame ...`) instead of a full block per player. Passed over: a
per-player block reads as one coherent "this player's row" at a glance (the way
a fighting-game frame-data tool typically groups a combatant's stats), and
matches the table's own presentation (one Field column, `p{i}.` prefix implying
"repeat this whole list per player").
**Why latitude, not escalation.** Contract 3 fixes the field SET and that the
order is fixed; it does not fix the literal token sequence. One reasonable
reading, cheaply reversible (a caller reads named `key=value` pairs by name, not
position), invisible across the seam.
**Ruling (Architect, 2026-07-10).** Ratified and **folded into the spec**: the emitted
row encoding is now pinned in `trace-harness.md` Contract 3 ("Emitted row encoding")
verbatim — `tick`, then each player's full default block (`p{i}.` over `state, frame,
cat, px, py, vx, vy, act, stun, sk, face`) p0-before-p1, then opt-in fields (`boxes`
after that player's block; `advantage`/`last_hit` after both), with `boxes` as
`;`-joined `KIND:x,y,w,h`. Pinning it makes a `.trace` a stable, diffable golden format
(the spec's own long-term intent), so QA's later golden-lock has a fixed contract.

### JC-050 · 2026-07-09 · TKT-P1.1R-01 · Inline-assert runner is a GDScript API, not a text-DSL parser — ratified
**Serves:** `docs/spec/trace-harness.md` Contract 3 "Assert" mode; acceptance
criterion 5.
**Decision.** Built the inline-assert runner as a GDScript API —
`TraceHarness.check(rows, tick, field, expected) -> bool` (fails loudly, prints
tick/field/expected/actual, mirrors every existing test file's `_eq`/`_true`
convention) plus `TraceHarness.row_at` — rather than a parser for the spec's
worked illustration (a `.script`-style text file with `P1:`/`P2:` input lines and
`assert tick=<n> <field>=<expected>` lines, using symbolic state names like
`p0.state=WALK_F`).
**Alternative considered.** A literal text-file parser matching the illustration
verbatim. Passed over: resolving a symbolic name like `WALK_F` against a raw
`state_id` in a CHARACTER-AGNOSTIC harness (inspection-surface.md criterion 5 —
no character-specific code in the seam) needs a per-character symbol table
(name -> id) that no contract defines yet — inventing one would be a new,
un-spec'd resolution mechanism (contract-adjacent), not an implementation detail.
The GDScript-API form delivers the identical semantics Contract 3 actually
specifies as the contract — "(tick, field, expected)" checked against the trace,
failing loudly by name — while staying inside this codebase's existing,
already-audited test-authoring convention.
**Why latitude, not escalation (with a caveat).** The (tick,field,expected) +
loud-failure CONTRACT is fully preserved; only the host mechanism (GDScript call
vs. parsed text file) differs from the spec's illustrative shorthand. Flagged
here rather than silently decided because it has real drift-risk for QA's
long-term authoring plan (`trace-harness.md`: "QA (long-term): authors the
brief-derived trace-scripts") — if the Architect intends literal `.script` text
files (with a symbol-table contract to match), that is a small, additive
follow-up ticket, not a rewrite of what's built here.
**Ruling (Architect, 2026-07-10) — the caveat resolved, not rubber-stamped.** Ratified:
**the GDScript `TraceHarness.check`/`row_at` API is the ratified assert host for this
build and for QA's near-term authoring surface.** Trace-harness.md's illustrated
`P1:`/`assert tick=… field=…` block with symbolic names (`WALK_F`) is **illustrative of
the assertion *semantics* — `(tick, field, expected)` checked against the trace, failing
loudly by name — not a pinned file grammar** the build must match. The Developer's core
reasoning is sound and is the deciding factor: a literal text-DSL resolving a symbolic
state name against a raw `state_id` needs a per-character symbol table (name→id) that
**no contract defines**, and inventing one in a **character-agnostic** seam
(inspection-surface.md criterion 5) would be a new, un-spec'd, contract-adjacent
mechanism — correctly escalated, not silently built. A literal text `.script` DSL (with
a symbol-table contract to match) is an **explicitly-deferred, additive extension**, not
a defect in this build and **not** part of the P1.1 bar; it becomes a spec item only if/
when QA's authoring plan calls for pasteable text files (the same build-for-extension
horizon as the "share a setup" / P3-tutorial hooks the spec already parks). Folded both
clarifications into `trace-harness.md` (Contract 3 Assert mode + Ownership) so QA reads
the correct authoring surface going into the audit. **Reported to the Strategist: QA's
current authoring surface is the GDScript API; the text-DSL is not built and not owed.**

### JC-051 · 2026-07-09 · TKT-P1.1R-01 · InputScript grammar edge cases — ratified
**Serves:** `docs/spec/trace-harness.md` Contract 1 grammar + acceptance criteria
1/2.
**Decision.** (a) A repeated button letter within one token (e.g. `LL`) compiles
without error — the grammar's `button...` literally permits repetition, and OR-ing
the same bit twice is a no-op, so it is harmless rather than a typo class. (b)
Digit `0`, and any character outside `1..9`/`L`/`M`/`H`, is a malformed token
(hard error). (c) Button letters are case-sensitive — only uppercase `L`/`M`/`H`
match; no lowercase convenience-aliasing was added.
**Alternative considered.** Rejecting a repeated button letter as malformed (extra
typo-catching strictness); accepting lowercase `l`/`m`/`h` as aliases (authoring
convenience). Passed over both: the spec's literal grammar already answers (a)
by definition and doesn't ask for (c), and adding either invents behavior beyond
the letter of Contract 1 for no stated need.
**Why latitude.** Pure grammar-boundary detail with one reasonable reading per
the spec's own literal production rules; no design/feel consequence.
**Ruling (Architect, 2026-07-10).** Ratified and **folded into the spec**: a "Grammar
edge cases" note added to `trace-harness.md` Contract 1 pins all three — repeated button
letters are idempotent-accepted, button letters are case-sensitive (uppercase only), and
`0`/any character outside `1-9`/`L`/`M`/`H` is a malformed hard error — so the shared-
artifact grammar has one durable reading (a typo cannot silently re-mean a shared setup).

### JC-052 · 2026-07-09 · TKT-P1.1R-01 · Hard-error mechanism + testing hook — ratified
**Serves:** `docs/spec/trace-harness.md` Contract 1 "Validation"; acceptance
criterion 1 ("a malformed token or reserved bit is a hard error, not a
dropped/altered frame").
**Decision.** `InputScript.compile`'s hard-error boundary is `assert(false, msg)`
on a malformed token/count, mirroring the codebase's EXISTING hard-error-at-the-
boundary convention (`InputSource.validate` / `InputFrame.is_valid`,
`input_source.gd`) rather than inventing a new error-signaling shape — Contract 1
fixes `compile`'s signature as the single pure `(text) -> PackedInt32Array`, which
leaves no room for an error-tuple return without changing that contract. Because
a tripped GDScript `assert` isn't reliably catchable/introspectable from a
headless test (this codebase's own established precedent —
`test_record_playback.gd`'s `_test_reproducibility_and_future_read_contract`
note on the same class of boundary), added a non-asserting
`InputScript.is_well_formed_token(token) -> bool` exposing the IDENTICAL grammar
check as a plain bool, so malformed-input detection is testable without tripping
the crash path. This helper is additive — not part of Contract 1's `compile`
signature.
**Alternative considered.** Changing `compile` to return an error-carrying
Dictionary/tuple instead of a bare `PackedInt32Array`. Passed over: Contract 1
fixes the signature; changing it would be a contract edit, not an implementation
choice.
**Why latitude.** The error-signaling MECHANISM (assert vs. a different return
shape) is implementation detail once the contract's signature is held fixed; the
codebase already has one established convention for this exact class of boundary,
and this reuses it rather than inventing a second one.
**Ruling (Architect, 2026-07-10).** Ratified as mechanism latitude — Contract 1's pure
`compile(text) -> PackedInt32Array` signature is held fixed, the assert boundary reuses
the codebase's one established hard-error convention (`InputSource.validate`), and
`is_well_formed_token` is a clearly-additive, non-contract testing hook. No spec change
(the contract signature is unchanged; the helper is outside it).

### JC-053 · 2026-07-09 · TKT-P1.1R-01 · P2 default-neutral via an empty buffer — ratified
**Serves:** `docs/spec/trace-harness.md` Contract 2 ("The P2 source defaults to a
neutral (idle) script when only P1 is driven").
**Decision.** `TraceHarness.run`'s `p2_text` default (`""`) compiles to an empty
`PackedInt32Array`, loaded into P2's `RecordPlaybackSource` as-is; that source's
OWN already-documented empty-buffer behavior (`_read_playback_and_advance`:
"An empty buffer plays back as NEUTRAL forever") supplies the neutral stream —
no explicit N-tick neutral buffer is compiled for P2.
**Alternative considered.** Compiling an explicit `"5*<ticks>"` P2 script sized to
the run length. Passed over: it would require threading `ticks` into the default-
script construction and produces byte-for-byte the same observable stream as the
simpler empty-buffer path, which is already a first-class, tested behavior of
`RecordPlaybackSource` (`test_record_playback.gd`) — reusing it is the smaller
surface.
**Why latitude.** Internal driver plumbing with one reasonable reading; the
observable P2 behavior (neutral forever) is exactly what Contract 2 specifies
either way.
**Ruling (Architect, 2026-07-10).** Ratified — the observable P2 stream (neutral
forever) is exactly Contract 2, and reusing `RecordPlaybackSource`'s already-tested
empty-buffer behavior is the smaller surface. No spec change.

### JC-054 · 2026-07-10 · TKT-P1.1R-02 · Spawn-offset vertical reflection as scalar-point negation — ratified
**Serves:** AD-037's consequence note ("record any box whose 'correct' reflected
height is a judgment call, e.g. a spawn offset"); `character_a.gd`'s
`STATE_FIREBALL_*` spawn keyframes and `TestSupport._build_fireball`'s mirror.
**Decision.** `Keyframe.spawn_offset_y` (the fireball's vertical release point,
consumed as `spawn_y = p.pos_y + kf.spawn_offset_y`, `step_phases.gd
_try_spawn_projectile` — the identical `pos_y + local_y` shape `MoveData.
resolve_box` uses for a box) is reflected as a bare scalar negation:
`new_offset_y = -old_offset_y` (character A: `45 -> -45`; TestSupport: `40 ->
-40`). Not run through the box formula `new_y = -(y+h)` with some inferred `h`.
**Alternative considered.** Treating the offset as a box with an authored-but-
implicit height (e.g. some notional "hand width") and reflecting via the full
box formula. Passed over: a spawn offset is a POINT (no `w`/`h` fields exist on
it at all — `move-format.md`'s `Keyframe` has no such fields), and the box
formula's `-(y+h)` is exactly `-y` in the degenerate `h=0` case — a point is a
zero-height box reflected about its own single edge, so the two readings
coincide; there is no second box-shaped alternative that produces a different
number, only a question of which formula-instance to cite.
**Why latitude.** The reflected VALUE is unambiguous (both framings agree); the
only judgment is characterizing it as "the point form of AD-037's formula" for
a future reader who might otherwise wonder why no `+h` term appears. Logged per
AD-037's explicit instruction to record spawn-offset reflections, not because
another value was plausible.
**Ruling (Architect, 2026-07-10).** Ratified and **folded into AD-037**: an authored
`Keyframe.spawn_offset_y` (a spawn *point*, no `h`) reflects as `new_y = -old_y` — the
degenerate `h=0` case of AD-037's `-(y+h)` box formula. Pinned in AD-037's Consequence
note so a future character authoring a spawn point inherits the rule instead of re-deriving
it.

### JC-055 · 2026-07-10 · TKT-P1.1R-02 · Orientation verified via direct InspectionView reads; CROUCH exercised by state-injection — ratified
**Serves:** AD-037 acceptance ("a harness/test asserts the sim-truth
orientation... right-side-up"); `training-mode.md` criteria 5/14.
**Decision.** The new `game/tests/test_geometry_reflection.gd` asserts box
orientation by reading `InspectionView.new(state, roster).player(0).boxes`
directly (typed `BoxView.rect` ints) rather than driving `TraceHarness.run` and
parsing its formatted `"KIND:x,y,w,h"` `boxes` string field, and exercises
`STATE_CROUCH` by setting `s.players[0].state_id` directly (mirrors the
existing state-injection pattern in `test_character_a.gd`/
`test_geometry_overlay.gd`) rather than through a scripted held-`2` input.
**Alternative considered.** Driving everything through `TraceHarness.run` +
`TraceHarness.check`/`row_at` (the ticket's named verification instrument) for
uniformity. Passed over for CROUCH specifically: held-`DOWN` -> `STATE_CROUCH`
command recognition is AD-038/TKT-P1.1R-03's engine change (the bare-`DOWN`
`button_map` entry does not exist yet this ticket), so no scripted input
reaches CROUCH at all pre-TKT-03 — direct injection is the only way to assert
its geometry now, and using the same direct-read approach for the standing/
pushbox/hitbox assertions keeps one consistent test shape rather than splitting
the file across two verification styles for no reason. Passed over for the
STRING-matching alternative specifically (even where scripted input does
reach, e.g. standing IDLE): matching `TraceHarness`'s exact formatted string
requires hand-computing scaled fixed-point values (`FP.SCALE = 65536`) inline,
which is exactly the "elaborate assertion scaffolding" JC-050 says not to
over-invest in for this provisional surface; reading the same underlying
`BoxView` ints directly is the smaller, more robust surface (AD-011 still
respected — `InspectionView` is `TraceHarness`'s own read path).
**Why latitude.** Internal test-authoring choice with no observable consequence
outside the test file; the sim-truth surface read (`InspectionView`) is
identical either way, and the acceptance bar ("a harness/test asserts...") is
satisfied by a test using the same AD-011 surface the harness is built on, not
necessarily `TraceHarness`'s own row-string API.
**Ruling (Architect, 2026-07-10).** Ratified as test-authoring latitude — the acceptance
bar ("a harness/test asserts the sim-truth orientation") is met by a test reading the same
AD-011 `InspectionView` surface the harness itself reads; using `TraceHarness`'s own
row-string is not required, and direct `BoxView` int reads avoid hand-scaling fixed-point
in-line (the over-investment JC-050 warns off for this provisional surface). No spec change.

### JC-056 · 2026-07-10 · TKT-P1.1R-03 · Crouch `button_map` entry placed immediately after the DOWN+button crouch normals — ratified
**Serves:** TKT-P1.1R-03's ordering instruction ("after the DOWN+button crouching
normals... and before the walk entries"); AD-032's first-match-wins shadowing
rule; `character_a.gd` `_build_button_map`.
**Decision.** `_map(-1, InputFrame.DOWN, 0, STATE_CROUCH)` is appended
immediately after the three `2L/2M/2H` entries (before the jump entry, the
standing normals, and the walk entries) rather than, say, immediately before
the walk entries at the bottom of the list.
**Alternative considered.** Placing the bare-`DOWN` entry directly above the
walk entries (still satisfying "before the walk entries," the ticket's literal
floor) instead of directly below the crouching normals. Passed over: nothing in
the recognizer requires it further down (`button_index == -1` pure-direction
entries never compete with the `button_index >= 0` jump/standing-normal entries
above them — different `button_index`, so first-match-wins never has to choose
between them), so placement anywhere in `[after 2L/2M/2H, before WALK_F/WALK_B]`
is behaviorally identical; adjacency to the crouching normals it is ordered
against (readability — the "DOWN routes low, with or without a button" cluster
stays together) was the only real consideration, not a reachability difference.
**Why latitude.** Any placement satisfying the ticket's two named constraints
produces the identical recognizer result (verified: `2L/2M/2H` still win over
bare `2` when a button is held; `3` — DOWN+FORWARD — still crouches, not walks,
regardless of where in that span CROUCH sits). Purely a readability/authoring-
order call with no behavioral difference among the reasonable alternatives.
**Ruling (Architect, 2026-07-10).** Ratified as authoring-order latitude — both named
ticket constraints (after `2L/2M/2H`, before the walk entries) are satisfied and the
recognizer result is identical for every placement in that span; adjacency to the
crouching normals is a readability choice with no behavioral consequence. No spec change.

### JC-057 · 2026-07-10 · TKT-P1.1R-03 · Crouch-block scenario verified via a direct `SimState.step` + `InspectionView` test, not `TraceHarness` — ratified
**Serves:** TKT-P1.1R-03 acceptance ("a crouching held-back defender blocks a
hit — enters a blockstun category"); `trace-harness.md` (the named instrument).
**Decision.** `game/tests/test_held_input_stances.gd`'s walk-exit and crouch-
enter/exit assertions run through `TraceHarness`/`InputScript` (the ticket's
named instrument, a clean fit — pure scripted-input movement). The crouch-BLOCK
scenario instead builds a `SimState` directly (attacker/defender positioned at
a proximity gap that puts 5L's hitbox in reach of the defender's crouching
hurtbox — mirrors `test_character_a.gd`'s `_two_char_state`/`_test_5h_5m_link_
window` gap pattern) and steps it directly, reading the result through
`InspectionView` (still AD-011).
**Alternative considered.** Driving the block scenario through `TraceHarness.
run` too, for one consistent instrument across the whole file. Passed over:
`TraceHarness.run` fixes both players at `SimState.new_initial()`'s spawn gap
(200 units) with no position-override parameter (`trace-harness.md` names no
such contract) — closing that gap by scripted walking alone (character A's
walk speed is ~2.2 units/tick) would need ~70+ scripted ticks of pure
choreography with no bearing on what the assertion is actually about (block
resolution on contact), obscuring the scenario's point for no verification
gain over the direct-`SimState` proximity pattern the rest of the combat suite
(`test_character_a.gd`, `test_invuln.gd`) already uses for exactly this shape
of test. `trace-harness.md`'s own header calls out that it is "not a TAS
framework" for elaborate choreography — this is that case.
**Why latitude.** Test-instrument choice per scenario, not a contract or feel
call; both paths read sim truth exclusively through `InspectionView`/
`PlayerView` (AD-011), so the thing being verified (a crouching held-back
defender's hit resolves to a blockstun category) is identical either way.
**Ruling (Architect, 2026-07-10).** Ratified as test-instrument latitude — `TraceHarness.run`
fixes both players at the 200-unit initial spawn gap with no position-override contract, so a
contact scenario is legitimately built by the direct-`SimState` proximity pattern the combat
suite already uses; both paths read sim truth through `InspectionView` (AD-011). (A harness
position-override hook is a plausible future build-for-extension convenience, not owed now.)
No spec change.

### JC-058 · 2026-07-10 · TKT-P1.1R-03 · `TestSupport` (P0 test character) gains a bare-RIGHT `button_map` entry -> `STATE_WALK`, and `test_combat.gd`'s walk-integration test now holds that input — ratified
**Serves:** keeping the full suite green under AD-038's deliberate, spec'd
behavior change ("movement goldens change deliberately — walk now terminates");
`test_combat.gd::_test_movement_integration` (pre-existing, not part of this
ticket's named read-set).
**Decision.** AD-038 makes every ACTIONABLE LOOP state (idle/walk/crouch)
re-derive from input every tick, for every character generically (the engine
change is character-agnostic by design). `TestSupport` (the P0 test character,
`game/tests/test_support.gd`), unlike `character_a.gd`, had `STATE_WALK`
authored as data but no `button_map` entry ever targeting it — walking was only
ever reached by test code poking `p.state_id` directly, a path AD-038 now
immediately re-derives away from on the very same actionable tick (no held
input recognizes it, so `target` resolves to idle before phase 3 can integrate
its motion). This broke `test_combat.gd::_test_movement_integration` ("walk
integrates +2 units/tick"), a pre-existing engine-level (not character-A)
regression test. Fix: add `_map(-1, InputFrame.RIGHT, 0, STATE_WALK)` (the same
AD-032 pure-direction pattern character A's own walk entries use) as the LAST
`button_map` entry, and change the test to feed `InputFrame.RIGHT` (P0 faces
+1) instead of `InputFrame.NEUTRAL` so the re-derivation re-selects WALK
(`target == current`, a no-op) instead of collapsing to idle.
**Alternative considered.** Leaving `test_combat.gd` red as a known, documented
"movement golden that changed" and letting QA/the Architect decide. Passed
over: the ticket's own acceptance bar is "run the full suite and confirm
green," and this is squarely the class of change the ticket already
anticipates and blesses ("movement goldens change deliberately"), not a new
design question — the fix is mechanical (bring the shared test fixture's
`button_map` in line with the same pattern already used for the shipped
character) and carries no risk (test-only content, no engine or character-A
change). Also considered: making P0 non-actionable that tick via some other
means (e.g. injecting stun) to dodge AD-038's re-derivation entirely without
adding a `button_map` entry. Passed over: stun's absence of a real input-driven
walk command was the actual gap this exposed (mirrors the exact class of gap
AD-032 fixed for character A); routing around it with an artificial non-
actionable state would leave `TestSupport` permanently unable to express a real
walk command, a worse and less honest fixture than character A's own.
**Why latitude.** Test-fixture-only content change (no engine, no shipped
character, no contract) needed to keep a pre-existing, in-scope-suite test
green under this ticket's own engine change; the pattern added is not new
(copies AD-032's established pure-direction shape) and record-worthy only
because it touches a shared fixture other tests also depend on.
**Ruling (Architect, 2026-07-10).** Ratified as test-fixture latitude — bringing
`TestSupport`'s `button_map` in line with the same AD-032 pure-direction pattern the
shipped character uses is the honest fix (not routing around AD-038 with an artificial
non-actionable state), and the held-RIGHT integration test still holds under the AD-038
exit correction ruled in this pass (a continuously-held direction re-selects walk under
current-direction re-derivation just as it did under the buffered path). No spec change.

### JC-059 · 2026-07-10 · TKT-P1.1R-04 · Air-normal `CancelRule` window authored as `[1, JUMP_DURATION-1]` — ratified
**Serves:** AD-039 ("air normals via jump-state cancels" — "window = the
airborne frames"); the ticket's own worked example (`[1, JUMP_DURATION - 1]`).
**Decision.** Each of `JUMP_N/F/B`'s three air-normal `CancelRule`s
(`_air_normal_cancels`, `content/character_a.gd`) is windowed `[1,
JUMP_DURATION-1]` = `[1, 44]` — open from the first airborne frame through the
frame BEFORE the jump's own 45-frame duration elapses, not `[1, 45]` (the full
duration).
**Alternative considered.** `[1, JUMP_DURATION]` (the full arc, frame 45
included). Passed over: `Actionability.is_actionable` treats a committed
once-through move as actionable once `frame_in_state >= duration` (the same
"recovery has ended" reading `PREJUMP`'s own window-3 authoring already
relies on, JC-038) — on frame 45 itself, phase 2's fixed priority order
(`phase2_state_machine`) takes the ACTIONABLE/buffered-command branch INSTEAD
of the cancel branch, so a `CancelRule` window that included frame 45 would
never actually be evaluated there; the cancel is legal-on-paper but
dead-on-that-frame either way. `JUMP_DURATION-1` states the TRUE reachable
window instead of an window whose top edge is silently unreachable.
**Why latitude.** The ticket's own worked example already writes `[1,
JUMP_DURATION - 1]` verbatim — this is confirming/authoring exactly that
bound, not inventing a new one; recorded because AD-039 says "e.g." (leaves
the precise bound to the Developer) and the off-by-one reasoning is the same
class of authoring subtlety JC-038 already established for the prejump
lead-ins, worth citing for a future reader/character.
**Ruling (Architect, 2026-07-10).** Ratified and **folded into AD-039**: an air-normal (and
prejump) `CancelRule` window ends at `duration - 1`, since on the duration frame itself the
committed move is already actionable and phase 2's fixed priority takes the actionable/
buffered branch over the cancel branch (the JC-038 off-by-one), making a frame-`duration`
window edge silently unreachable. Pinned in AD-039 so future air normals inherit the true
reachable bound.

### JC-060 · 2026-07-10 · TKT-P1.1R-04 · `PREJUMP_F`/`PREJUMP_B` factored through a shared builder; new state ids placed outside the movement block — ratified
**Serves:** AD-039 ("author `PREJUMP_F`/`PREJUMP_B` mirroring the existing
`PREJUMP`"); `content/character_a.gd`'s state-id allocation.
**Decision.** (a) `PREJUMP`/`PREJUMP_F`/`PREJUMP_B` are all built by one new
`_build_prejump(state_id, target) -> MoveState` (same 4f duration, same
window-3 ALWAYS cancel, differing only in id and cancel target) rather than
three hand-copied blocks. (b) `STATE_PREJUMP_F = 160` / `STATE_PREJUMP_B =
161` — placed outside the contiguous `100-109` "Movement states" id block
(already fully allocated) rather than renumbering any existing state id.
**Alternative considered.** (a) Three separate hand-authored `MoveState`
blocks (mirrors the ORIGINAL `PREJUMP` code's own shape most literally).
Passed over: the three states are identical apart from id/target, and the
existing code's own comment already flagged the eventual F/B lead-ins as
"authored the same way" — a shared builder is the smaller, more obviously-
correct diff and removes two copies of the window-3 rationale comment that
would otherwise need to stay in lockstep. (b) Renumbering the movement block
to make room for contiguous ids. Passed over: would touch `STATE_CROUCH`/
`STATE_JUMP_*`'s existing values for no behavioral gain — ids are opaque
integers to the engine, and gratuitously renumbering shipped, already-baked
ids is pure churn/risk for a cosmetic grouping preference.
**Why latitude.** Both are internal data-structure/id-allocation choices with
no design consequence and one reasonable reading each; invisible across the
seam (nothing outside this builder reads a `MoveState`'s numeric id as
meaningful beyond equality).
**Ruling (Architect, 2026-07-10).** Ratified as data-structure/id-allocation latitude — a
shared `_build_prejump` builder and non-contiguous ids (160/161) are invisible across the
seam (engine treats a state id as an opaque equality token); renumbering shipped ids would
be pure churn. No spec change.

### JC-061 · 2026-07-10 · TKT-P1.1R-04 · `_test_no_gatlings_no_jump_cancels` updated to exempt the new AD-039-sanctioned jump-state cancels — ratified
**Serves:** keeping the full suite green under AD-039's deliberate, spec'd
content (air normals reachable via a jump-state cancel); `test_character_a.gd`
criterion-9 test (pre-existing, not part of this ticket's named read-set).
**Decision.** `_test_no_gatlings_no_jump_cancels` (character-a.md criterion 9:
"no gatlings... no jump cancels") had two blanket guards written before any
jump state carried a `CancelRule`: (1) no state's `CancelRule` targets a
"normal" (`5L/5M/5H/2L/2M/2H/j.L/j.M/j.H`) — the anti-gatling check; (2) no
state's `CancelRule` targets a jump state, except `PREJUMP` itself (its own
lead-in). AD-039 legitimately adds `CancelRule`s FROM `JUMP_N/F/B` INTO
`j.L/M/H`, which trips guard (1) as written (the air normals are in its
`normal_state_ids` list), and adds `PREJUMP_F`/`PREJUMP_B`'s own lead-ins into
`JUMP_F`/`JUMP_B`, which trips guard (2)'s single-exception (`PREJUMP` only).
Fixed: guard (1) now skips `JUMP_N/F/B` as SOURCE states (a jump state
cancelling into its own air normal is the airborne-action model, not a
grounded normal-to-normal gatling chain); guard (2)'s exception list now
includes all three prejump states.
**Alternative considered.** Splitting `normal_state_ids` into a grounded-only
list for guard (1) instead of skipping the jump states as sources. Passed
over: equivalent in effect, but skipping the jump states as sources reads
more directly as "this guard is about a NORMAL cancelling into another
normal" (matching the criterion's own "no gatlings" framing) — the target
list stays the single complete "these are the normals" list used elsewhere in
the file, and only the source-side loop changes.
**Why latitude.** Test-only content change (no engine, no shipped character
behavior, no contract) required to keep a pre-existing, in-scope-suite test
green under this ticket's own AD-039-sanctioned content — the same class of
call JC-058 already made one ticket ago for an analogous pre-existing-test
collision.
**Ruling (Architect, 2026-07-10).** Ratified as test-guard latitude (JC-058 class) —
exempting `JUMP_N/F/B` and the three prejumps as *source* states aligns the criterion-9
guard with what AD-039 now sanctions (a jump state cancelling into its own air normal is
the airborne-action model, not a grounded gatling); the guard's target list stays the
single complete "these are the normals" list. No engine or shipped-character change. No
spec change.
