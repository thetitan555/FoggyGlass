# Work-Order — Character A movement reconciliation + geometry Y-fix (P1.1 close-out)

> Authored by the **Strategist**. This is a **reconciliation work-order**, not new
> intent — the intent is the existing `briefs/character-a.md` (unchanged). This
> documents the gap between that intent and what was actually built, the confirmed
> scope to close it, and how a **fresh session** should pick it up and run it to the
> P1.1 human re-gate. Self-contained on purpose: a cold-start session should be able
> to execute from this doc + the reads it names, without this conversation.
>
> **Scope decision (user, 2026-07-08):** the **full reconciliation** — audit *all*
> of character A's specced movement against the brief and fix every gap, not just the
> reported symptoms. Rationale in `pipeline-analysis-completeness-gap.md`: two
> re-gates have peeled the character back one layer at a time; symptom-fixing just
> surfaces the next gap at the next gate.

## Status snapshot — what is done, what remains

**P1.1 delivered and audited this session (all committed locally; push is the user's gate):**
- Geometry overlay made visible (TKT-P1.1-01: player-init fix + AD-035 render framing).
- Human control surface bound (TKT-P1.1-02: controls + attack buttons + legend).
- Serialization format-version field (TKT-P1.1-03: AD-034).
- Two first-gate defect fixes: walk **entry** wiring (JC-046) and the jump-arc net-zero
  floor-sink fix (JC-047).
- Bookkeeping: `run_tests.bat` current (27 tests); stale `2H` comment removed.
- All P1.1 judgment calls (JC-044..048) ratified; AD-034/035/036 recorded.
- QA objective audit passed (`audits/audit-p1.1-instrument.md`): 27/27 green.
- Incidental: `flags-archive.md` NUL-corruption stripped.

**Remaining before P1.1 is done (this work-order):**
1. The geometry Y-inversion render fix.
2. The character-A movement reconciliation (below).
3. A single P1.1 human **re-gate** against a genuinely playable A.
4. Two deferred *feel* calls the user parked (frame-step auto-pause; jump apex-hang) —
   confirm at the re-gate, not before. Non-blocking.

P1.1 is **not done** until 1–3 clear. Do not mark it done on headless green — that is
the exact failure this whole episode is about (`pipeline-analysis-completeness-gap.md`).

## Intent source — what character A's movement is *supposed* to be

From `briefs/character-a.md` ("The defining toolkit", line ~71): character A's basics are
*"walking (forward/back), jumping (neutral/forward/back) with jump-in normals, standing and
crouching blocking, and an L/M/H normal set on stand/crouch/air."* Plus a **discretionary**
call in that brief: *"a simple grounded forward/back dash ... and no air dash"* (the user
may veto; confirm whether it was ever specced/built, and whether it's in slice scope).

Everything below is measured against that list. All of it is in-scope; none is a stretch goal.

## Findings from the two human gates (the gap to close)

### Render — one likely root cause behind the whole visual cluster
**Geometry boxes are drawn with an inverted Y axis.** User (gate 2): *"collision boxes are
drawn along the top edge of the hurtboxes and not the bottom edges ... hit/hurt/collision
boxes might be being drawn with incorrect Y direction."* And the hurtbox "shrinks up" under
2L/2M/2H instead of down.

**Synthesis — this likely explains gate-1's observation too.** The gate-1 note that "2L/2M
attack at head-level while the hurtbox shrinks up" (recorded as the non-blocking
crouching-normal-height flag) is almost certainly the *same* Y-inversion, not a separate
content-design issue: a low crouching attack rendered under an inverted Y appears high, and a
downward crouch-shrink appears upward. **Expect the render Y-fix to resolve the box-appearance
cluster across both gates.** Re-evaluate the crouching-normal-height question only *after* the
Y-fix, against a correctly-oriented display — it may simply vanish.

Owner/routing: the render lives in `geometry_overlay.gd` (Developer), but the **coordinate
convention** (does sim +Y mean up or down; how AD-035 / AD-019 map world→screen; where the
ground line seats) is contract-level and may be **unspecced** — if so it is the Architect's to
state before the Developer fixes the sign. Treat "what is the canonical vertical convention"
as the first question.

### Sim / movement — character A is materially incomplete
Read against the intent list above. Confirmed broken/missing by the gates (state values read
from the Live State panel, which reads sim state directly — these are genuine sim defects, not
render artifacts):

- **Walk has no exit.** Holding 4/6 enters walk (state 101/102) but **releasing does not
  return to idle** — the state stays until some other input interrupts it. JC-046 wired walk
  *entry* during a gate-fix but not the release→idle transition. A walk you can't stop is not
  a walk.
- **No crouch stance.** Holding 2 produces **no state change and no hurtbox change** — yet the
  *crouching attacks* (2L/2M/2H) work and are reachable. So the crouch *attack* states exist
  but the crouch *stance* (and, per the brief, crouch **block**) is unwired/missing.
- **No forward/back jump.** Cannot jump forward or back — the brief promises
  "jumping (neutral/**forward/back**)".
- **No diagonal jumps.** 7-jump and 9-jump (up-back / up-forward) do nothing.
- **Jump vertical anomaly.** User: *"I don't descend anymore when jumping, but I rise instead
  of falling by about the same amount ... when I hold down 8."* Diagnose against the Y-fix:
  determine whether this is a sim arc issue or the same render inversion (read sim `pos_y`
  through a neutral jump vs. what's drawn). JC-047 verified the neutral arc nets zero
  headlessly, so suspect render first — but confirm, don't assume.

## The reconciliation task — verify EVERY specced element, then fix

Do not fix only the five findings above. Walk the brief's full movement list and, for each,
confirm it is **built, reachable by human input, correct, and correctly rendered** — fixing
every gap found. Minimum checklist (extend if the spec names more):

- [ ] **Walk forward** — enters on held 6, **exits to idle on release**.
- [ ] **Walk back** — enters on held 4, **exits to idle on release**.
- [ ] **Crouch stance** — enters on held 2 (hurtbox changes *correctly*, i.e. shrinks
      *downward* once Y is fixed), returns to stand on release.
- [ ] **Crouch block** and **stand block** — the brief names "standing and crouching blocking."
- [ ] **Jump neutral / forward / back** — all three, with correct arcs (land flush, JC-047).
- [ ] **Diagonal jumps** (7 / 9) — up-back, up-forward.
- [ ] **Jump-in normals** — the brief names them; confirm reachable in the air.
- [ ] **Stand / crouch / air L/M/H normals** — confirm each is reachable by human input (some
      are known-working; verify the set, don't assume).
- [ ] **Dash (forward/back)** — the brief's *discretionary* call: check whether it was specced
      and built. If neither, this is a **Strategist/user scope decision**, not a Developer
      default — flag it, don't silently add or omit.
- [ ] **Geometry** — all box kinds (hit / hurt / collision-pushbox) render with **correct Y
      orientation** for every state above.

## Companion capability — scripted-input behavioral-trace harness (folded in; user 2026-07-09)

**Why it's here.** This reconciliation exists because the pipeline verifies the *presence* of
what was built but never *drives the assembled character as a human against its brief*
(`pipeline-analysis-completeness-gap.md`, element 1). The user's proposal closes most of that
gap mechanically: author an input string, replay it **headless** (Godot `--headless -s`, exactly
how the 27 suites already run) through the existing `RecordPlaybackSource` (a Tenet-2 input
source, JC-030), dump a per-tick trace of chosen `InspectionView` fields, and assert against
expected. It becomes this work-order's **own verification instrument** — the checklist items
above ("hold 6, release → returns to idle by frame X") are exactly the assertions it expresses.

**Near-term intent (this work-order):** a *minimal* harness — compile an authored input string
to the buffer, replay N ticks headless, dump/assert chosen state fields. **Not** a general TAS
framework. It gives the reconciliation executable, brief-derived behavioral coverage so the
sim-behavior gaps can't silently reopen at a later gate.

**What it does and does NOT cover — hold this line.** It reads sim state, the same values the
headless suite reads — so it catches the *sim-behavior* half (walk-won't-stop, wrong
state/position, unreachable crouch, jump arcs) but is **blind to render bugs by the same logic
that hid the Y-inversion from all 27 tests.** It shrinks the human re-gate to genuinely-visual
concerns (is anything drawn, right-side-up, legible); it does **not** remove it. Do **not** mark
P1.1 done on this harness's green — that is the P1 mistake in a new costume.

**Build for extension (Tenet 3) — the user's explicit steer.** Design the input-string format
and the replay seam so they are **not test-only.** The same "load an input string, replay
deterministically" mechanism is, one step out, a player sharing a setup — a pasteable input
string that loads a situation to *practice against* in training mode. Do not build that feature
now, but do not foreclose it: the format should be human-authorable and shareable, and the replay
path should be the general input-source seam, not a test-harness backdoor. (This is also **P3's
scripted-input source arriving early** — the tutorial is the same Tenet-2 mechanism.)

**Discipline (so it stays honest):**
- **Inline, human-readable assertions** derived from the brief beat blind golden-diffs for this
  purpose — they encode *intended* behavior, not "whatever the sim does today." A pure
  record-and-lock golden would enshrine current bugs (the JC-047 trap: a test that "tolerated the
  drift" thereby documented it).
- Any golden trace must be **born from a human-confirmed run**, then locked.

**Ownership/routing.** The **format is a contract** (input-string syntax → `InputFrame` buffer;
the trace field-set and file shape) → the **Architect** specs it, in the same entry as the
coordinate convention and state-machine model below. The **replay-through-a-seam** honors Tenet 2
(the user's ground) — flag it if any of it strains the tenet rather than working around it. **QA
owns authoring the trace-scripts** long-term (it is "how the audit is performed"), derived from
the brief. Keep the near-term build minimal; the extension trajectory is recorded intent, not
this work-order's build scope.

## Recommended routing (how a fresh session should run it)

Mirror the pipeline's own flow; do not let one role invent another's artifact.

1. **Architect first** — this has genuine contract questions the Developer must not guess:
   (a) the **vertical coordinate convention** and how AD-035/AD-019 render it (state it if
   unspecced); (b) the **movement state-machine model** for release→idle exits, crouch-stance
   entry/exit, and directional/diagonal jump-input mapping — reconcile `spec/character-a.md`
   and the move-format/state-machine spec against the brief, rule what's a spec gap vs. unwired
   content, and decompose into **tickets**; (c) the **scripted-input trace-harness format** —
   the input-string→`InputFrame`-buffer syntax and the trace field-set/file shape, designed for
   extension per the companion-capability section (human-authorable/shareable, replay via the
   general Tenet-2 input-source seam, not test-only), specced in this same entry. This is the
   "reconcile built-vs-intended" step the pipeline lacked (see the analysis doc).
2. **Developer** — implement the tickets: build the **minimal trace harness** per the Architect's
   format, then use it to verify the movement fixes as you make them; fix the geometry
   Y-orientation and wire/author the missing movement against the ratified spec. Record
   contract-adjacent calls in the judgment-log ("Provisional" section + index line — the log is
   index-fronted now; closed bodies are in `judgment-log-archive.md`).
3. **Architect ratifies** the new judgment calls; **QA** runs the objective audit (criteria +
   determinism; note the jump/movement changes will move sim behavior — goldens change
   deliberately, JC-017 style).
4. **User re-gate** — the experiential close-out. **Drive the checklist above** (see the
   analysis doc's proposal: a brief-derived gate checklist is exactly this). QA cannot mark
   P1.1 done while the gate is open; only the user closes it.

## Acceptance — P1.1 is done when

Every checklist item above passes at the human re-gate: A walks and stops both ways, crouches
(stance + block), jumps in all directions and lands flush, its normals are reachable, and all
boxes render right-side-up. Then the two deferred feel calls (frame-step auto-pause; jump
apex-hang) are confirmed or ticketed. Only then does P1.1 — and, finally, P1's character A —
count as actually done.

## Deferred / parked (do not lose)

- **Feel calls (user parked, gate 2):** frame-step auto-pause (JC-045); jump apex-hang feel
  (JC-047). "Can remain as they are for now." Confirm at the re-gate. Flags open to Strategist.
- **Crouching-normal attack heights (gate 1):** open flag — but likely a *symptom* of the
  Y-inversion (see synthesis above). Re-evaluate after the render fix; close it if the display
  now reads correctly.

## Pickup instructions for the new session

- **Read:** this doc; `pipeline-analysis-completeness-gap.md` (the why); `briefs/character-a.md`
  (the intent); `spec/character-a.md` + the move-format/state-machine spec (built state);
  `spec/decisions.md` AD-035/AD-019/AD-032/AD-018 via its index; `flags.md` (the consolidated
  reconciliation flag + the parked feel flags). Do **not** read the judgment-log archive whole —
  it's index-fronted; pull JC-044..048 by id only if needed.
- **Repo state:** working tree clean; the P1.1 work above is committed locally and may be
  unpushed (push is the user's gate). Do **not** redo delivered work (geometry-visible,
  controls, serialization, jump-arc-net-zero, bookkeeping) — this work-order is *additive*.
- **Start with the Architect** per the routing above. The first concrete question is the
  vertical coordinate convention — settling it unblocks both the render fix and the movement
  diagnosis.
