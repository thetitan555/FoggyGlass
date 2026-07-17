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

### JC-100 · 2026-07-16 · flag "~1 second of input lag" · fix MatchTickHost's own frame-query counter, not the driver — RATIFIED (Architect, 2026-07-16)
**Ratified, and the reasoning promoted to contract.** The call is right and right for the
stated reason: the driver polls devices, the match layer owns phases, and those two things
have no business knowing about each other. Making `training_mode.gd` (and by extension every
`InputSource` caller) phase-aware to keep a counter honest would have put match-layer state
in the input path to fix a bug the *host* introduced — Tenet 2's separation and input.md's
"sources are dumb/generic" posture both point the other way. Containing it in the host that
creates the discrepancy is correct, and leaving `TickHost`'s `state.tick`-as-index alone
(still provably correct there, since it advances 1:1) is the right restraint.
**Folded into the spec:** `input.md` → "Produce-before-query ordering" now pins the general
invariant — *the query index is the produced-frame count, not the sim tick*; any host with
non-advancing phases tracks its own count; never fix it by making the driver or sources
phase-aware. Your alternative is recorded there as explicitly forbidden, so nobody
re-proposes it. This generalizes past `MatchTickHost` to any future wrapping host.
Decided: fixed the input-frame desync (P2-gate flag 1: `MatchTickHost._advance`
was querying `get_input(state.sim.tick)`, which freezes during `ROUND_START`/
`ROUND_END`, while the real driver keeps calling `produce_next()` every real
tick) by giving `MatchTickHost` its own `_frames_queried` counter — incremented
once per `_advance()` call — and querying THAT instead of `state.sim.tick`. The
change is entirely self-contained inside `match_tick_host.gd`; no other file
(`training_mode.gd`, `MatchState`, any `InputSource`) changed.
Alternative passed over: make `training_mode.gd`'s `_physics_process` aware of
`match_phase` and skip calling `produce_next()` on the sources during non-
`ACTIVE` phases, so the sources' own produced-count would stay 1:1 with
`state.sim.tick` the way it already does for the plain `TickHost`/`SimState`
path. Rejected: it would make the DRIVER (and by extension every `InputSource`
caller) phase-aware, which cuts against input.md's "sources are dumb/generic"
posture and Tenet 2's source/sim separation — the driver would need to reach
into match-layer state just to decide whether to poll a device, coupling two
things (device polling cadence, match phase) that don't need to know about each
other. Keeping the fix inside `MatchTickHost` (a host that already introduces
the discrepancy by wrapping a state machine with non-advancing phases) leaves
`training_mode.gd`'s existing, already-tested per-tick pattern (mirrors
`main.gd`'s own) completely untouched, and leaves `TickHost`'s own — provably
correct — `state.tick`-as-query-index approach alone too, since that one still
holds for the plain sandbox path.
Serving: flag `docs/flags.md` (2026-07-16, "~1 second of input lag," resolved).

### JC-101 · 2026-07-16 · flag "HUD text overlap" · training_mode.tscn right-column resize/restack — RATIFIED (Architect, 2026-07-16)
**Ratified; no spec change needed.** Squarely latitude: the spec owns *what the instrument
must show*, never the pixel geometry it shows it in, so box sizes and stacking are the
Developer's to solve. Both restraint calls are also right — declining to re-column
`controls_legend.gd`'s text builder (a flag about layout geometry doesn't license rewriting
text layout), and declining to widen into `InputHistoryPanel`. Verifying by loading the real
`.tscn` and reading back every `Control.rect` is the correct standard of proof for a claim
about overlap; the diagnosis that the box was undersized from TKT-P1.1-02 (not a P2-08
regression) is well-evidenced, and re-solving rather than preserving the user's gate-time
workaround was the right handling of `7c88462`.
One standing note, not a correction: the instrument is the surface we audit *through*
(`audit-criterion.md`), so its legibility is contract-adjacent even though its layout isn't.
If the right fix for the next overlap **is** the columnar text builder you passed over, that
remains latitude — take it then; it was correctly out of scope for a geometry flag.
Decided: re-solved the P2-gate HUD-overlap flag by (a) sizing `ControlsLegend`'s
box to its actual ~18-line content (444px tall, up from 244px) with
`autowrap_mode = 3` (WORD_SMART) added to its Label so its two long lines wrap
inside the box rather than overflowing past the window edge, and (b) restacking
`DummyModeIndicator`/`MatchPanel` below it in the same right column (x
750–1136) with real clearance, verified by loading the actual `.tscn` headlessly
and reading back every panel's `Control.rect` — no two overlap, and the whole
right column (max y=624) still fits the 1152×648 default viewport with margin.
Left column (`FrameDataPanel`/`LiveStatePanel`/`InputHistoryPanel`) untouched —
their content already fit.
Alternative passed over: keep `ControlsLegend` narrow and instead split its
`_ACTIONS` list into two side-by-side columns (halving the needed height).
Rejected as out of scope here: that changes `controls_legend.gd`'s own text-
layout logic (a second Label/columnar text builder), not just this scene's
box geometry — more surface than a flag about *layout* geometry calls for, and
this session's single-box-resize fix already clears the overlap with no code
change outside the `.tscn`. Also decided NOT to widen `ControlsLegend`
horizontally past its existing 386px — doing so would collide with
`InputHistoryPanel` (right edge x=700), which shares `ControlsLegend`'s new
vertical span (y 16–460) once enlarged; kept the existing right-column x-range
(750–1136) that `DummyModeIndicator`/`MatchPanel` already used instead.
Serving: flag `docs/flags.md` (2026-07-16, "HUD text overlap," resolved).

### JC-102 · 2026-07-16 · TKT-P2-09 (AD-049) · B's `STATE_AIR_RESET` framing — RATIFIED (Architect, 2026-07-17)
**Ratified as latitude; no contract surface moves.** The right call for the stated reason: B's
receive-side air-reset is authored as a structural mirror of A's (CATEGORY_HITSTUN, B's own airborne
hurtbox, flat duration) and converges into B's own `reaction_map[REACTION_KNOCKDOWN]` on landing via
the **existing** `_land` mechanism — no invented engine special-case, exactly the AD-043/AD-049
convergence. The `duration = 20` is slice-provisional tuning derived from A's own verified `gravity`
and A's `2H` launch magnitude (the "physics determines the number" bar, JC-039/072-style), not a
contract number — QA goldens the convergence, not the value. The distinctness-while-airborne
constraint that is mine to honor is a pose/animation concern this headless build can't resolve either
way, and it was not traded against anything — correctly **not** a flag. The CATEGORY_HITSTUN choice is
also correct and unrelated to the headline readout-labelling defect (Developer-owned): the mechanics
are right; only the instrument's category-name collapse is the bug.
**Decided:** character B's new `STATE_AIR_RESET` (the reaction it never inflicts but must
author to RECEIVE character A's `2H`) is authored as an exact structural mirror of character
A's own `STATE_AIR_RESET`: `CATEGORY_HITSTUN`, B's existing airborne hurtbox (`_hurt_air()`),
and a flat `duration = 20`. It converges into B's own `reaction_map[REACTION_KNOCKDOWN]` on
landing via the SAME existing engine mechanism (`StepPhases._land`'s "any non-AIRBORNE-
category state reaching here redirects to the knockdown reaction") that already applies to
A's own air-reset — no new engine behavior, no bespoke "air-reset lands to idle instead of
knockdown" carve-out invented for B.
**Why 20, not a B-specific derivation:** B reuses A's own verified `gravity` constant
(TKT-P2-05's own judgment call) and the inflicting hitbox is literally A's `2H` (same launch
magnitude, since B is only ever the defender here) — so the physical airborne flight time is
the same order as A's own air-reset under the same physics. This is the same "physics
determines the number, not a guess" standard `AirHeightScaling`/A's jump-arc re-baselining
used (JC-039/072-style).
**Alternative passed over:** author a genuinely NEW landing behavior for B's air-reset (e.g.
recover directly to idle/neutral fall rather than converging into knockdown), reasoning that
the brief's "AIR_RESET ... nothing follows" language implies a softer landing than LAUNCH.
Rejected as an invented engine special-case, not a reading of the brief: the brief's hard
constraint is that the three airborne reactions be **tellable apart on sight while airborne**
(a pose/animation concern this headless builder cannot resolve either way) — it says nothing
about the GROUND landing behavior, and AD-043's whole point is that every physically-airborne
hard reaction converges on ONE learnable wakeup. Diverging B's landing from that established
convergence would be a bigger, uninvited change than the ticket asked for.
**Not a flag:** legibility and B's feel do not conflict here — the constraint that's mine to
honor (distinctness while airborne) is a pose/duration/momentum question explicitly named as
latitude, and I did not have to trade it against anything to keep the landing mechanism
consistent with A's.
Serving: `TKT-P2-09` (`docs/tickets/p2-char-b-match.md`); `docs/briefs/character-b.md` "What
B looks like when it receives"; AD-043's knockdown convergence.

### JC-103 · 2026-07-16 · TKT-P2-09 (AD-049) · `ReactionMapEntry` as a typed Resource array — RATIFIED (Architect, 2026-07-17)
**Ratified as latitude; no contract surface moves.** Storing `Character.reaction_map` as
`Array[ReactionMapEntry]` (typed Resource) behind the `reaction_state(kind)` accessor is exactly the
internal-packaging call latitude covers — AD-049/move-format.md own the *accessor* and the required
*mapping*, never the storage shape. The choice is also the consistent one: it mirrors the project's
established `.tres`-diffable/golden-able authored-collection convention (`ButtonMapEntry`, `CancelGroup`
per JC-079's identical reasoning), and Godot 4.3 has no typed-`Dictionary` export anyway, so a bare
Dictionary would have been both the first such `.tres` export and a loss of `kind`/`state_id` type
safety. Nothing else reads `reaction_map` directly, so the single scan path is clean.
**Decided:** `Character.reaction_map` is `Array[ReactionMapEntry]` (a small typed Resource
with `kind`/`state_id` fields, plus a `make()` convenience constructor), not a bare
`Dictionary`. `Character.reaction_state(kind)` is the one resolution path (linear scan over
the array); nothing else reads `reaction_map` directly.
**Why:** mirrors the project's own established convention for authored collections that need
to stay `.tres`-diffable/golden-able — `ButtonMapEntry`, `CancelGroup` (JC-079's identical
reasoning) — rather than introducing the first bare-`Dictionary` `.tres` export in the
schema. Godot 4.3 (this project's pinned version) has no typed-`Dictionary` export anyway, so
a `Dictionary` here would also lose the `kind`/`state_id` type safety a Resource gives for
free.
**Alternative passed over:** a plain `Dictionary` (`ReactionKind int -> state_id int`).
Rejected: less consistent with every other authored-collection field in the schema, no
compile-time field typing, and a `.tres` dictionary literal is less readable/diffable than a
list of named sub-resources.
**No contract surface moves:** AD-049/move-format.md name `Character.reaction_map` as a
required mapping and `Character.reaction_state(kind)` as its resolution — the storage shape
behind that accessor is exactly the kind of internal packaging call latitude covers.
Serving: `TKT-P2-09`; `move-format.md` → `Character.reaction_map`.

### JC-104 · 2026-07-16 · TKT-P2-09 (AD-049) · test-only reaction_map reuse for unexercised kinds — RATIFIED (Architect, 2026-07-17)
**Ratified as test-only latitude; no production content affected.** The test doubles author a
**complete** `reaction_map` (all six kinds — satisfying criterion 15's completeness shape) and map the
kinds their scenarios never inflict onto an existing state (TestSupport's KNOCKDOWN → its existing
`STATE_THROWN`, the closest grounded non-actionable analogue) rather than authoring dead states or
leaning on the resolution floor. That is the correct reading of AD-049: the floor is a guardrail against
a content hole, *not* an authoring license — reusing an existing state keeps the mapping honest and
complete at zero content bloat, which is right for minimal hand-computable fixtures. Real roster (A, B)
still maps every kind to a dedicated purpose-built state, so the content-seam proof is untouched. Correct
restraint.
**Decided:** the small test-only characters that predate AD-049 (`TestSupport`'s P0 test
character, and `test_guard_height.gd`/`test_cancel_groups.gd`'s local minimal characters) are
given a COMPLETE `reaction_map` (all six kinds, satisfying criterion 15's completeness shape),
but the kinds none of their scenarios ever inflict (`LAUNCH`, `AIR_RESET`, and — for
`TestSupport` — `CROUCH_BLOCKSTUN`) are mapped onto the character's EXISTING
`HITSTUN`/`BLOCKSTUN` state rather than authoring new dedicated reaction states nobody
exercises. `TestSupport`'s `REACTION_KNOCKDOWN` reuses its existing `STATE_THROWN` (already a
grounded, non-actionable hard-reaction state — the closest existing analogue), and its own
`hit_reaction`/`block_reaction` on the throw hitbox move from the old raw `STATE_THROWN` id to
the `REACTION_KNOCKDOWN` kind.
**Why:** these are P0/P2-03-era test doubles whose whole point is to be minimal and
hand-computable; adding real new states to them for kinds their own tests never drive would
be test-content bloat serving no scenario, while leaving a kind genuinely unmapped would fail
their own `reaction_state`'s floor silently (reusing an existing state keeps the mapping
honest without inventing unused content).
**Alternative passed over:** leave these test characters' unexercised kinds unmapped,
relying on `reaction_state`'s `kind -> HITSTUN -> idle_state_id` floor. Rejected: that floor
exists as a guardrail against exactly this kind of content hole, not a license to lean on it
where authoring the (cheap, reused) mapping costs nothing — using the floor here would be
authoring against it, which move-format.md explicitly says not to do.
**No production content affected** — character A and B (the real roster) map every kind onto
a dedicated, purpose-built state; only test-only fixtures reuse.
Serving: `TKT-P2-09`; move-format.md criterion 15 (test-fixture side).

### JC-105 · 2026-07-16 · TKT-P2-10 (AD-049) · `ProjectileRegistry.install` accepts a Dictionary OR an Array of Dictionaries — RATIFIED (Architect, 2026-07-17)
**Ratified as latitude; no new contract surface.** AD-049 Decision 3 already owns the contract
(projectile `data_id` is a declared global namespace, uniqueness enforced at install time); this call
is the *how* of that enforcement, which is latitude. The reasoning is right and load-bearing: duplicate
detection **must** happen inside the merge, because a plain Dictionary literal has already resolved any
collision (silently, last-write-wins) before `install` could ever see it — so the merge itself has to
go through the registry. Accepting Dictionary-or-Array (rather than migrating ~15 single-roster call
sites to `Array[Dictionary]`) is the additive, churn-free way to get that guarantee at the one site
that merges, and the `void`→`bool` return is source-compatible (bare-statement call sites ignore it;
`training_mode.gd` checks it, `push_error` on false per JC-048's fail-fast convention). Correctly scoped.
**Decided:** `ProjectileRegistry.install` takes an untyped `roster` parameter: a single
`data_id -> ProjectileData` `Dictionary` (every existing single-source call site, unchanged
behavior) is installed as-is; an `Array` of such Dictionaries is MERGED internally with
duplicate-`data_id` rejection (`push_error` + the roster left untouched, returns `false`).
`training_mode.gd`'s A+B merge is the one caller that now passes the Array form.
**Why:** a plain `Dictionary` literal (`{**reg_a, **reg_b}`-style, or a manual `for k in
reg_b: merged[k] = reg_b[k]` loop) has ALREADY resolved any key collision — silently,
last-write-wins — by the time it would ever reach `install`. Detecting a duplicate `data_id`
therefore requires the MERGE itself to go through the registry, not a post-hoc check on an
already-flattened dict. Accepting both shapes (rather than changing the signature to
`Array[Dictionary]` outright) keeps every one of the ~15 existing single-roster call sites
(tests, `trace_harness.gd`, the sandbox single-character path) completely unchanged, so the
fix is additive at the one call site that actually merges more than one character's
projectiles.
**Alternative passed over:** change `install`'s signature to `Array[Dictionary]` unconditionally,
migrating every call site to wrap its single dict in a one-element array. Rejected: pure
churn across ~15 unrelated call sites for no behavior change there, when the untyped
Dictionary-or-Array acceptance gets the same duplicate-detection guarantee at the one site
that needs it.
**Return value:** `install` now returns `bool` (was `void`). Every existing call site ignores
the return value as a bare statement (GDScript permits this), so this is source-compatible;
`training_mode.gd` is the one caller that now checks it (`push_error` + a wiring-time warning
on `false`, per JC-048's push_error-is-the-reliable-fail-fast convention — GDScript has no
exceptions).
Serving: `TKT-P2-10`; move-format.md criterion 18; AD-049 Decision 3.

### JC-106 · 2026-07-17 · TKT-P2-11 (AD-050) · divekick landing-recovery authored per-strength, not shared — provisional
**Decided:** each of B's three divekicks (L/M/H) gets its OWN landing-recovery `MoveState`
(`STATE_DIVEKICK_L_LANDING` / `_M_LANDING` / `_H_LANDING`), rather than one shared recovery
state. AD-050 explicitly leaves this call open ("author separate recovery states, or share
where they coincide").
**Why:** L/M/H's currently-authored `HitBox.blockstun` values (9/11/13 — JC-095's own tuning)
are all pairwise distinct, so the AD-050 pinned equality (`recovery.duration ==
that divekick's own blockstun`) requires three different `duration`s — sharing one state
would force one of the three numbers to be wrong. To keep the equality holding **by
construction** rather than by three call sites happening to agree, `_build_divekicks()` and
`_build_divekick_landing_states()` both read the SAME named constant
(`DIVEKICK_{L,M,H}_BLOCKSTUN`) for a given strength, instead of duplicating the blockstun
value as an inline literal in two places.
**Alternative passed over:** one shared `STATE_DIVEKICK_LANDING` state whose `duration` is
authored to the largest of the three blockstun values (13, H's). Rejected: it would make L's
and M's recovery LONGER than their own blockstun, silently breaking the pinned equality for
two of the three divekicks and flattening the height-dependent-advantage shape further behind
a constant offset — the ticket's `combat-resolution.md` criterion 18 language ("recovery ==
blockstun") reads as a per-move invariant, not a character-wide one.
**If JC-095's tuning pass later makes two strengths' blockstun coincide,** the two divekicks
MAY share a landing-recovery state at that point (nothing here blocks it) — not forced now.
Serving: `TKT-P2-11`; `AD-050`; `combat-resolution.md` criterion 18.

### JC-107 · 2026-07-17 · TKT-P2-11 (AD-050) · B-7 regression test drives contact height via direct `PlayerState` injection, not scripted jump timing — provisional
**Decided:** `_test_divekick_height_dependent_block_advantage_b7` (test_character_b_air.gd)
forces B directly into the M divekick's active window at a chosen `pos_y` (mirrors this
file's own established hand-driven-state convention, e.g. the knockdown-landing test), rather
than discovering two jump-altitude/spacing combinations that happen to produce a low vs. high
contact (the technique B-1's own slide test uses for spacing).
**Why:** the divekick's contact height is a function of WHEN during a long, mostly-uniform
descent the hitbox happens to overlap a grounded defender's fixed-height hurtbox — spacing
alone doesn't cleanly select a height the way it selects an active *frame* for the slide
(a single moving hitbox against a stationary defender on the same ground plane). Direct
`pos_y`/`vel_y` injection isolates the CONTACT-HEIGHT variable precisely and deterministically,
without an empirical search over jump-altitude/spacing pairs. A short headless probe (see the
divekick's own trajectory-model header comment for the established practice of discovering
frame numbers this way) found the geometrically valid contact-height band for a standing
defender's hurtbox against this hitbox's box geometry runs roughly `pos_y ∈ (-80, 0)`
(friendly units); heights very close to either edge either land the SAME tick as contact
(pos_y ≈ 0, no room to observe a landing-time difference) or land past the reachable band a
tick or two after the injected position (pos_y ≈ -80, the actual contact height ends up lower
than injected). `-15` (low) and `-60` (high) were chosen from that probe as comfortably inside
the reliable band while maximizing the resulting gap difference (empirically ~5 ticks).
**Also decided:** the test measures relative advantage as `attacker_actionable_tick -
defender_actionable_tick`, driven to BOTH sides actually reaching `Actionability.
is_actionable`, rather than reading `Advantage.live`'s value at the contact tick. AD-050's own
"Observability / `frames_to_actionable`" scope note explains why: read at the exact contact
tick, `frames_to_actionable` uses the divekick's still-generous safety-tail `duration` (not a
fall-time prediction), so a single live-advantage snapshot taken while B is still airborne
would not honestly reflect the eventual outcome — the height-dependent minus is a property of
the interaction RESOLVING, not of the contact-tick instant.
Serving: `TKT-P2-11`; `AD-050`; `character-b.md` criterion B-7.

### JC-108 · 2026-07-17 · flag "re: reaction legibility" (P2-gate headline) · `PlayerView.reaction_kind` — a new DERIVED field resolving state identity, reverse through the character's own `reaction_map` — provisional
**Decided:** the fix for `category_name()` collapsing `STATE_KNOCKDOWN` /
`STATE_HITSTUN_LAUNCH` / `STATE_AIR_RESET` / ordinary hitstun into one word ("hitstun",
since all four share `CATEGORY_HITSTUN`) is a new `PlayerView.reaction_kind: int` field
(default `-1`), computed at `_init` by reverse-scanning the roster character's own
`reaction_map` (`Array[ReactionMapEntry]`) for the entry whose `state_id` equals the
player's current `state_id`. `-1` when no entry matches (an ordinary move/idle/walk
state — ​not a reaction). `LiveStatePanelModel.identity_name()` reads it and leads the
row with the specific word ("knockdown"/"launch"/"air reset"/"hitstun"/"blockstun"/
"crouch blockstun"); `category_name()` is kept and shown ALONGSIDE it in `format_row`
(`cat:%s`), never dropped — per the flag's explicit "category is real information and
may stay alongside; it is not a substitute for identity."
**Why a new PlayerView field, not a panel-local lookup:** the panel model only holds an
`InspectionView`/`PlayerView`, never the character roster (`InspectionView._roster` is
private, with no accessor) — so the identity lookup has to happen wherever the roster is
already in scope, which is `PlayerView._init` (the same place `state_category`/`invuln`/
`boxes` are already resolved off the SAME `character`/`move` lookup, `move-format.md`
"the state-machine reads that need move data"). This mirrors `invuln`'s own documented
shape exactly: "a DERIVED projection (like box geometry) — not a serialized `SimState`
field." No new `SimState` field, no new engine primitive — purely a reverse read of data
`Character.reaction_map` already carries (AD-049's own forward accessor,
`reaction_state(kind)`, is the SAME map read the other direction).
**Ambiguity note, and why it's not a correctness risk for the real roster:** a
`reaction_map` COULD in principle alias two kinds onto the same `state_id` (first match
wins), but JC-104 already established real roster characters (A, B) map every kind to a
DEDICATED state — only pre-AD-049 test-only fixtures alias, and this field is a training-
mode readout concern, not a resolution-path concern (nothing in the sim reads it back).
**Alternative passed over:** add a `display_name`/`state_name` string field authored
directly on `MoveState` (one label per state, set by content). Rejected: broader surface
change (every character's every `MoveState` would need authoring, including non-reaction
states like every normal/idle/walk — a much bigger authoring lift for a defect that's
specifically about the four REACTION states colliding), and it would duplicate
information `Character.reaction_map` already carries for exactly the states in question
— the flag names `ReactionKind` specifically ("surface the ReactionKind / the state's own
identity"), and reusing the existing authored mapping is the minimal, DRY fix.
**Spec note (routing, not asking):** `inspection-surface.md`'s `PlayerView` field table
does not yet list `reaction_kind` — flagging this in the entry so the Architect can fold
it in on ratification (the established pattern for prior additive derived fields, e.g.
AD-046/`air_action_used`), not asking permission to proceed; the fix ships now per the
flag's own "the requirement is mine, stated so it isn't re-litigated."
**Also audited (same flag, "fix the class, not just the instance"):** `FrameDataPanelModel`
(names `guard_height`/`block_valid`/advantage distinctly, no collapse), `InputHistoryPanelModel`
(decodes raw direction/button bits individually, no collapse), `MatchPanelModel` (phase/
reason each have their own name table, no collapse), `DummyModeIndicator` (each of the
three dummy modes already has its own label). A repo-wide grep for `category_name`/
`CATEGORY_HITSTUN`/`state_category` usage outside `live_state_panel_model.gd` returns
nothing — the collapse was isolated to this one panel, not a repeated pattern.
Serving: `docs/flags.md` (2026-07-17, "re: reaction legibility"); `inspection-surface.md`
`PlayerView`; `training-mode.md` "Live-state panel."
