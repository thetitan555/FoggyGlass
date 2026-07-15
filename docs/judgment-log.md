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

### JC-087 · 2026-07-15 · AD-043 elaboration (JC-070 ratified) · Character A's `STATE_THROWN` renamed/reused as `STATE_KNOCKDOWN`, not a second authored state — provisional
**Decision.** Implementing `knockdown_state_id`, character A needed SOME `state_id` to point
it at. Rather than authoring a brand-new, near-duplicate grounded-HITSTUN state alongside the
existing `STATE_THROWN` (id 123; duration 30; `CATEGORY_HITSTUN`; standing hurtbox) — which
was already exactly "a grounded, non-actionable hard-knockdown reaction with a fixed wakeup
duration," just throw-specific by name — I renamed it in place to `STATE_KNOCKDOWN` (same id,
same duration/category/hurtbox) and pointed BOTH the throw's `hit_reaction` (direct, grounded
hard-KD) and `Character.knockdown_state_id` (the launched-landing target) at it. This is the
literal convergence AD-043's elaboration asks for ("ground-KD and launch-into-KD converge on
one learnable wakeup") realized as ONE state rather than two states that happen to behave
identically.
**Alternatives considered.** Authoring a genuinely NEW `STATE_KNOCKDOWN` (a fresh id) and
leaving `STATE_THROWN` in place, unused — rejected: it would leave dead, unreferenced content
in the character definition (nothing sets `hit_reaction`/`knockdown_state_id` to it anymore),
and two states with byte-identical authoring is exactly the kind of drift-prone duplication the
format's "one authored definition" discipline (move-format.md criterion 1 in spirit) argues
against. Renaming costs nothing structurally (the id is internal, resolved through
`Character.get_state`) and required updating the handful of tests that named
`CharacterA.STATE_THROWN` directly (`test_character_a.gd`, `test_invuln.gd`) to
`CharacterA.STATE_KNOCKDOWN` — mechanical, no behavior change to those tests.
**Scope.** `character_a.gd` (constant rename + `Character.knockdown_state_id` assignment +
throw's `hit_reaction`/`block_reaction`); `test_character_a.gd` / `test_invuln.gd` (reference
updates only). `data/character-a.tres` re-baked from the builder (`tools/bake_character_a.gd`)
so the shipped artifact reflects the rename — no drift between authored source and baked file.
No `SimState`/`PlayerState` shape change (AD-034): `knockdown_state_id` is `Character` content,
resolved through `MoveRegistry` exactly like `idle_state_id`, not serialized runtime state — no
`FORMAT_VERSION` bump. Log for ratification.

### JC-088 · 2026-07-15 · AD-043 elaboration (JC-070 ratified) · `_land`'s knockdown transition re-arms `p.stun` to the knockdown state's own `duration`; the natural same-tick decrement is accepted, not specially frozen — provisional
**Decision.** The AD's contract ("fixed wakeup `duration` counted from entry/landing,
independent of air-time") is NOT satisfied merely by transitioning `state_id` on landing:
`p.stun` — the actual engine countdown that gates the "become actionable" transition
(`step_phases.gd` phase 2, `p.stun == 0`) — is set ONCE, at the original hit (phase 5), and
decrements every unfrozen tick (phase 7) regardless of any later `state_id` change; a bare
state transition would leave wakeup governed by whatever stun happened to remain after the
flight, which is exactly the air-time-dependent behavior AD-043 exists to eliminate. So
`StepPhases._land`'s knockdown branch explicitly re-arms `p.stun = knockdown_move.duration` (and
`stun_kind = STUN_HIT`) on the landing tick itself, making the wakeup countdown restart fresh at
that instant. One accepted consequence, verified by headless replay rather than assumed: unlike
an ordinary hit-connect (which ALSO sets `hitstop` the same tick, freezing `stun` via phase 7's
`was_frozen` gate until hitstop elapses — AD-010), this transition sets no hitstop, so phase 7's
plain decrement runs on the SAME tick `p.stun` is re-armed — the value observed immediately after
the landing tick's full `step()` is `duration - 1`, not `duration`. The wakeup still lands exactly
`duration` ticks after (and including) the landing tick, so time-to-wakeup-from-landing is fixed
regardless of air-time — the actual contract — this is a one-tick bookkeeping artifact of reusing
the existing phase-7 decrement path, not a shortfall of the contract itself.
**Alternatives considered.** Adding a hitstop-style "was just re-armed this tick" freeze flag so
`p.stun` reads exactly `duration` immediately after landing (parity with the hit-connect case) —
rejected as unnecessary complexity (a new per-player flag plus a phase-7 branch) to fix a
one-tick cosmetic difference nothing observable actually depends on (the wakeup TICK is identical
either way; only the intermediate `stun` READOUT differs by one for a single frame). Leaving
`p.stun` untouched on the landing transition (JC-070's original, since-overturned reading in
spirit) — rejected outright: this is precisely the air-time-dependent wakeup AD-043's elaboration
was written to eliminate.
**Scope.** `step_phases.gd`'s `_land` only (the `elif character.knockdown_state_id != 0` branch);
test-covered by a new regression, `test_airborne_physics.gd`'s
`_test_knockdown_wakeup_counts_from_landing_not_from_the_original_hit`, which asserts the
empirically-verified `duration - 1` readout and that it derives from `knockdown_move.duration`,
not from whatever remained of the original hit's stun. Log for ratification.

### JC-089 · 2026-07-15 · AD-043 elaboration (JC-070 ratified) · `STATE_KNOCKDOWN` keeps the standing hurtbox inherited from `STATE_THROWN`; no distinct downed-hurtbox geometry authored — provisional (deferred, not rejected)
**Decision.** AD-043's elaboration says the knockdown state "MAY author a downed hurtbox
distinct from the airborne launch hurtbox" — permissive, not required. `STATE_KNOCKDOWN`
(renamed from `STATE_THROWN`, JC-087) keeps its existing `_hurt_stand()` geometry unchanged;
no new lying-down hurtbox shape was authored. This is genuinely optional content-authoring
scope (box geometry is exactly the kind of thing `character-a.gd`'s own header note calls
"slice-provisional tuning"), not a contract gap — the engine mechanism (a real, distinct
`state_id` with its own resolvable hurtbox list) already supports adding one later with zero
structural change, only a data edit.
**Alternatives considered.** Authoring a genuinely shorter/prone hurtbox now — passed over as
unnecessary scope beyond what these two fixes need (neither fix's acceptance bar mentions
hurtbox shape) and easy to add later without touching any of the logic these two fixes changed.
**Scope.** None (no code change) — recorded so the deferral is visible rather than silently
assumed. Log for ratification (or explicit deferral confirmation).
