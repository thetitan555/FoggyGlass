# Flag Ledger

> Any role appends; the **owner** of the flagged artifact resolves. Append-only —
> resolved entries stay as a record. Mechanism: raiser pushes + tells the user;
> user relays to the owner; owner writes the resolution line, flips `[open]` to
> `[resolved]`, pushes; user relays back. See `protocol.md` → "How a flag works."

---

### [resolved] 2026-06-27 · raised-by: Architect · owner: Strategist · re: /docs/protocol.md
Problem: the protocol says game code lives in the engine project tree, "path is
the Architect's call; recorded here once set." I've set it: **`/game`** at repo
root (recorded canonically in `/docs/spec/decisions.md`, AD-013). The protocol's
"Where things live" note should mirror this so the path is discoverable from the
protocol, not only the decision record. Low-stakes — a documentation mirror, not
a design change.
---
Resolution (Strategist): Agreed — fixed, not a design change. `/game` is the
Architect's call to make (the protocol explicitly leaves the engine path to
them). Mirrored `/game` into the protocol's "Where things live" prose and the
artifact table so the path is discoverable from the protocol, with AD-013 as the
canonical source. No further action.
---

### [resolved] 2026-06-27 · raised-by: Consultant (via user) · owner: Architect · re: combat-resolution.md (advantage, AD-008)
Problem: The canonical advantage (`defender_remaining_stun − attacker_remaining_recovery`) is computed per-tick but no reference frame is pinned, so there is no defined "the" on-hit/on-block number for content or UI to read; and `attacker_remaining_recovery` is taken from the current move-state's recovery, which is incorrect once cancels let the attacker become actionable early — making the surfaced advantage misleading in exactly the pressure/combo cases the legibility goal most depends on.
Context caveat: raised from chat; owner, confirm against live project state before acting.
---
Resolution (Architect): Confirmed against the spec and accepted — both gaps were
real. Fixed in `combat-resolution.md` (Advantage section) and AD-008: one formula
now surfaces two values — a **static** move frame-advantage pinned at first-active
contact, attacker uncancelled (the canonical number content/UI read), and a
**live** per-tick advantage where `attacker_remaining_recovery` = actual
frames-to-actionable *including committed cancels*, so the readout stays truthful
in pressure/combo cases. Acceptance criterion #3 updated to check both.
---

### [resolved] 2026-06-27 · raised-by: Consultant (via user) · owner: Architect · re: combat-resolution.md (AD-009/AD-010) + move-format.md (cancels)
Problem: The phase order and hitstop rule don't state whether the state-machine/cancel phase (phase 2) processes cancels while a character is frozen in hitstop, nor whether the one-frame path from hit-confirm (cancel_tags granted in phase 5) to cancel-availability (consumed in phase 2 next tick) is intentional. Both are unstated, feel-defining decisions. Relatedly, `cancels` is a single field carrying gatling/special/whiff/rehit semantics with no model spelled out.
Context caveat: raised from chat; owner, confirm against live project state before acting.
---
Resolution (Architect): Accepted. (1) Cancels during hitstop — a frozen character
may *buffer* a cancel but executes it only on the first unfrozen tick (AD-017 +
Hitstop section). (2) The grant→consume path is intentional: `cancel_tags` granted
phase 5 of tick T are usable from tick T+1, a uniform one-tick latency that falls
out of the fixed phase order (AD-009), now stated. (3) `cancels` is no longer one
opaque field — it's a typed `CancelRule` list (target / condition / window / input
/ requires_tag) in `move-format.md` (AD-015), with gatling/special/whiff expressed
as rules, not special cases. Rehit is split out of cancels (AD-016). Acceptance
criteria added (combat #8, move-format #7).
---

### [resolved] 2026-06-27 · raised-by: Consultant (via user) · owner: Architect · re: decisions.md AD-004 (+ simulation.md)
Problem: AD-004 permits in-place mutation of SimState and rejects copy-per-step as "needless allocation pressure," but at slice scale (single machine, 60Hz, two characters) that pressure is likely negligible, while mutability makes the purity contract enforceable only by discipline and leaves purity bugs detectable only when a golden/determinism test happens to hit the offending path — trading away the verifiability the slice exists to prove. Worth re-justifying mutability against this scale and Tenet 3.
Context caveat: raised from chat; owner, confirm against live project state before acting.
---
Resolution (Architect): Agreed — overturned. The verifiability argument is correct
and aligns with Tenets 1 & 3 (the slice exists to *prove* determinism). AD-004
revised and `simulation.md` updated: `step` must not mutate its input; it writes a
distinct output state (buffer reuse of non-live states allowed, so no per-tick
allocation churn). Purity is now a cheap standing assertion — `hash(prev)`
unchanged after `step`. Acceptance criterion #9 added.
---

### [resolved] 2026-06-27 · raised-by: Consultant (via user) · owner: Architect · re: move-format.md + combat-resolution.md (phase 5)
Problem: Hit resolution defines single-hit integrity via `id_group` but specifies no rehit model for intended multi-hit moves (cadenced or sequential hits) and no resolution path for throws (blockstun bypass, tech window, throw-vs-throw, air throw) beyond `throwboxes`/`invuln` existing — so the contract has no answer for two common move classes. Needs either a model or an explicit "deferred."
Context caveat: raised from chat; owner, confirm against live project state before acting.
---
Resolution (Architect): Accepted — both classes now have models (AD-016).
Multi-hit: sequential (distinct `id_group`s across keyframes) or cadenced
(`HitBox.rehit_interval`). Throws: throwbox connect bypasses blockstun, with a tech
window (defender throw input → tech to neutral; simultaneous throws clash to a
tech). Air throws and formal throw-vs-throw priority are **explicitly deferred** —
out of the slice's two grounded movesets — with throwbox / `invuln` /
air-eligibility fields left in place so they're later additions, not rewrites
(Tenet 3). Specced in `move-format.md` + `combat-resolution.md` (Throws / Multi-hit
sections); acceptance criteria added (combat #9–10, move-format #8).
---

### [resolved] 2026-06-27 · raised-by: Architect · owner: Strategist · re: /docs/roadmap.md (P1) + missing character-A brief
Problem: The roadmap scopes P1 as "first character + debug/technical training
mode," built *together* — the debug mode needs something to observe. But the only
P1 brief handed down is `debug-training-mode.md`; there is no brief for character A.
I've specced the training mode against the P0 test character, so the Developer is
**not blocked** (TKT-P1-01…09 can proceed). However, the training mode's value —
and acceptance criteria 5–9 (geometry, real frame data, advantage on real moves,
combo accounting) — only become meaningfully verifiable against a real moveset.
Without a character-A brief, "P1 done" can be demonstrated only against a trivial
test character, which under-proves the feature.
Ask (Strategist's call, not mine): do you intend character A as part of this same
P1 push (then it needs a brief — its archetype/moveset is the roadmap's own open
question), or as a separate phase the training mode formally precedes? Either is
fine for sequencing; I just need to know which so the spec/tickets reference the
right "done" bar. Not urgent for the Developer to *start*; it is needed before P1
can be *audited as done*.
---
Resolution (Strategist): Accepted — the inconsistency was real and mine. Ruling:
**character A is part of the P1 push, not a separate later phase.** The training
mode is the charter's legibility instrument; auditing it against a trivial test
character would stamp "done" on an unproven instrument, which is the one place I
won't accept a soft audit. Delivered the missing brief at
`/docs/briefs/character-a.md` (a grounded, simplified shoto — L/M/H buttons,
cr.MK, fireball, shoryuken, throw + basics; archetype confirmed with the user).
So the **P1 done-bar is the training mode validated against character A.** Per
your note, this does not block the Developer from starting against the P0 test
character (TKT-P1-01…09); character A must land before P1 is *audited* as done.
Two items routed to you in the brief's open questions: (1) the L/M/H three-button
layout is slice-wide — please reflect it in the input contract, not as
character-A-local; (2) all of A's frame data/properties are yours to spec within
the stated identity. Roadmap's character-A open question is now closed.
---

### [open] 2026-06-27 · raised-by: Consultant (via user) · owner: Architect · re: inspection-surface.md
Problem: The inspection surface exposes view-only float fields (`position_px`, `rect_px`) on the same returns that QA golden-snapshots (criterion 4) through the same surface QA reads (criterion 11). Per Tenet 1, floats behave differently across platforms/compilers; a golden file that includes `_px` fields risks platform-dependent mismatches, defeating the golden harness. Need a decision: goldens snapshot fixed-point truth only, with `_px` treated as a render-only projection excluded from snapshots (or an equivalent split of the surface's QA vs. render subsets).
Context caveat: raised from chat; owner, confirm against live project state before acting.
---
Resolution (owner fills): …
---

### [open] 2026-06-27 · raised-by: Consultant (via user) · owner: Architect · re: training-mode.md
Problem: `do_reset()` restores `SimState` only, but the `RecordPlaybackSource` playback cursor lives outside `SimState` (Tenet 2: input sources are external to the sim). So resetting a situation does not re-sync the playback dummy to the reset point — a recorded sequence will not replay in sync with the rep, which breaks the core training-rep loop. The non-re-sync is forced by the seam, not chosen: the current structure cannot express a re-synced reset without explicit handling. No acceptance criterion covers reset+playback interaction (criteria 3 and 4 are tested independently). Define intended behavior (re-sync on reset as the default; independent/"metronome" playback as an explicit option only if wanted) and add coverage. May implicate Tenet 2 interpretation — re-route to the user if resolution needs a tenet change.
Context caveat: raised from chat; owner, confirm against live project state before acting.
---
Resolution (owner fills): …