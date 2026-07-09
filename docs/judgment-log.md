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
- JC-049 · 2026-07-09 · TKT-P1.1R-01 · Trace-row exact field order/text encoding: `tick`, then `p0.*` over `{state,frame,cat,px,py,vx,vy,act,stun,sk,face}`, then `p1.*` (same order), then any requested optional fields; optional `boxes` renders as `KIND:x,y,w,h` entries `;`-joined per player — provisional
- JC-050 · 2026-07-09 · TKT-P1.1R-01 · The inline-assert runner is a GDScript API (`TraceHarness.check`/`row_at`), not a parser for Contract 3's illustrated `P1:`/`assert tick=... field=...` text-DSL — provisional
- JC-051 · 2026-07-09 · TKT-P1.1R-01 · `InputScript` grammar edge cases: a repeated button letter in one token (e.g. `LL`) is accepted (idempotent OR); digit `0` and any character outside `1-9`/`L`/`M`/`H` is malformed; button letters are case-sensitive (no lowercase aliasing) — provisional
- JC-052 · 2026-07-09 · TKT-P1.1R-01 · `InputScript.compile`'s hard-error boundary uses `assert(false, msg)` (mirrors `InputSource.validate`); added a non-asserting `InputScript.is_well_formed_token` as an additive testing hook, not part of Contract 1's `compile` signature — provisional
- JC-053 · 2026-07-09 · TKT-P1.1R-01 · An empty/omitted P2 script defaults to neutral via `RecordPlaybackSource`'s existing empty-buffer-loops-neutral behavior, not an explicitly-compiled N-tick neutral buffer — provisional

---

## Provisional (awaiting ratification)

> Full bodies of not-yet-ruled calls live here until the Architect ratifies or
> overturns them; then the status flips and the Strategist sweeps the body to the
> archive. New entries append to this section.

### JC-049 · 2026-07-09 · TKT-P1.1R-01 · Trace-row exact field order/text encoding — provisional
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

### JC-050 · 2026-07-09 · TKT-P1.1R-01 · Inline-assert runner is a GDScript API, not a text-DSL parser — provisional
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

### JC-051 · 2026-07-09 · TKT-P1.1R-01 · InputScript grammar edge cases — provisional
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

### JC-052 · 2026-07-09 · TKT-P1.1R-01 · Hard-error mechanism + testing hook — provisional
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

### JC-053 · 2026-07-09 · TKT-P1.1R-01 · P2 default-neutral via an empty buffer — provisional
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
