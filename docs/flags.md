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

### [open] 2026-07-02 · raised-by: Developer · owner: Architect · re: /docs/spec/simulation.md (SimState shape), inspection-surface.md
**Problem (F-002): the inspection surface contract requires sim-state fields the
SimState table does not name.** inspection-surface.md's `PlayerView` and
`InspectionView` enumerate `character_id`, `stun_kind`, combo `damage_total`, and
`last_hit()` as required reads, and `AdvantageView.neutral_restored` requires a
per-tick "both became actionable this tick" flag (combat-resolution.md criterion 5,
"not before, not after"). But simulation.md's SimState / players[i] table lists
none of these. To make the required reads readable AND deterministic (survive
snapshot/restore, be covered by the canonical hash — AD-023 total coverage), I
added them to serialized state:
  - `players[i].character_id` (int) — which Character this player is; box/frame
    resolution and PlayerView.character_id need it.
  - `players[i].stun_kind` (int 0/1/2 none/hit/block) — backs PlayerView.stun_kind.
  - `players[i].combo_damage` (int) — backs PlayerView.combo.damage_total.
  - `last_hit` (HitRecord | null) — backs InspectionView.last_hit(); a plain
    serialized record, not the HitEvent view.
  - `neutral_restored_this_tick` (bool) — the phase-6 neutral-restored edge flag
    AdvantageView.neutral_restored reads.
All are serialized (to_dict/from_dict), deep-cloned, and folded into hash_state in
fixed order (a presence flag precedes the variable-length `last_hit` per AD-023).
This is a change to an owned contract (the SimState shape), so I am flagging rather
than treating it as latitude: the fields are a genuine gap the inspection contract
already implies, but their names/types/serialization belong in simulation.md's
table for QA and future work to build against. **Requested resolution:** ratify
these fields into the simulation.md SimState/players table (or correct their
shape), and note last_hit's canonical-hash treatment in AD-023's covered set.
---
Resolution (owner fills): …

### [open] 2026-07-02 · raised-by: Developer · owner: Architect · re: /docs/spec/simulation.md (how the pure `step` reaches authored move data)
**Problem (F-004): the pure `step(state, in1, in2)` must resolve authored move data
(box geometry, transitions, frame data), but the simulation.md `step` contract names
only `(state, in1, in2)` — it does not say how the sim reaches the character roster.**
This is a data-access model QA and future devs build against, and it is
determinism-relevant (the sim must read the SAME authored data every tick for
`step` to stay a pure function of its named inputs), so it is contract-adjacent
rather than pure latitude. Two reasonable models: (a) a process-wide immutable
static roster the sim reads (`MoveRegistry`, set once at match/scenario wiring,
never mutated mid-run — the same "authored content is a fixed input, not sim state"
reasoning that keeps input SOURCES external and out of SimState); (b) threading the
roster through `step` as an explicit parameter, so the data dependency is visible in
the signature. I implemented **(a)** — `MoveRegistry` is a static namespace over one
immutable roster, installed at wiring, read by `step`'s phase pipeline and by the
inspection surface. Rationale for (a): it keeps `step`'s signature exactly the
simulation.md contract (`state, in1, in2`), matches AD-001's "SimState is the
minimal MUTABLE graph — authored content is not sim state," and mirrors how input
sources live outside SimState; a snapshot/restore/replay reproduces identically
because the same immutable roster is present and carries no per-tick state to
serialize. The risk (a) carries: a process-wide static is global state, so a
mis-wired or mid-run-mutated roster is a determinism hazard the type system does not
prevent (mitigated: `install` is documented once-at-wiring, `clear` is test-only).
**Build-on-as-is note:** the prior session created `MoveRegistry` citing this flag
but did not record it here; I am recording it now and building 06/07/10 on model
(a). **Requested resolution:** ratify the roster-access model into simulation.md
(name it as the sim's authored-data source, or specify threading it through `step`
instead) so the data-access contract is owned, not an implementation accident. If
the Architect prefers (b), it is a localized change at `step`, the phase pipeline
entry, and the inspection surface — no phase logic changes.
---
Resolution (owner fills): …

### [open] 2026-07-02 · raised-by: Developer · owner: Architect · re: /docs/spec/combat-resolution.md, simulation.md (AD-012 AABB overlap)
**Problem (F-003): the AABB overlap convention (touching edges) is unpinned but is
determinism- and feel-relevant.** AD-012 / simulation.md fix that overlap is "our
own AABB test" on fixed-point integers, but do not state whether boxes that merely
TOUCH (share an edge: `a.x + a.w == b.x`) count as overlapping. This decides
whether a hit lands at exact adjacency — a hit/no-hit outcome content and QA
goldens depend on. I implemented STRICT overlap (touching edges do NOT overlap;
`ResolvedBox.overlaps` uses strict `<`/`>`), which is the common fighting-game
convention and keeps a box exactly adjacent to a hurtbox from registering. Raising
rather than logging as latitude because it is a resolution rule multiple roles
build against and could read materially differently. **Requested resolution:** pin
the touching-edge convention (strict vs. inclusive) in combat-resolution.md so it
is an owned rule, not an implementation accident. If strict is wrong for feel, that
is a one-line change in `ResolvedBox.overlaps`.
---
Resolution (owner fills): …

### [open] 2026-07-02 · raised-by: Developer · owner: Architect · re: /docs/spec/simulation.md (SimState shape), combat-resolution.md (single-hit)
**Problem (F-005): single-hit integrity ACROSS active frames needs per-attacker memory
of which id_groups have already connected, which is not a field the SimState table
names.** combat-resolution.md criterion 6 / move-format.md criterion 5 require a
multi-box attack in one `id_group` to register ONE hit, and AD-016 states "one hit per
group per contact" with `rehit_interval` unset ⇒ "one hit per contact." A hitbox is
active for its whole active window (the test move's 3 active frames); without memory of
"this id_group already hit this move," the SAME hitbox re-connects on every active
frame (and every frozen hitstop tick), registering 2–3 hits instead of one and
inflating the combo count — which breaks the done-bar's "one hit" assertion. To make
single-hit deterministic (survive snapshot/restore, be covered by the canonical hash),
I added a serialized field:
  - `players[i].active_hit_ids` (`PackedInt32Array`) — the hitbox `id_group`s that have
    already connected during this player's CURRENT move (as attacker). A hitbox whose
    id_group is present does not re-hit (rehit_interval == 0). Cleared on every state
    entry (a new move is a new contact). Cadenced re-hit (rehit_interval > 0) is
    TKT-P0-09 and will consult this same set with an interval.
It is serialized (to_dict/from_dict), deep-copied (clone), and folded into hash_state as
an order-committing variable-length run (size then each id, AD-023 total coverage).
This is a change to the owned SimState shape (like F-002), so I flag rather than treat
as latitude. **Requested resolution:** ratify `active_hit_ids` into the simulation.md
players table (name/type/serialization) and note its canonical-hash treatment, or
specify a different single-hit-tracking model (e.g. keyed on the last_hit record, or a
per-move-instance token). The single-hit MECHANISM is spec-required; only where the
tracking state lives is the contract question.
---
Resolution (owner fills): …