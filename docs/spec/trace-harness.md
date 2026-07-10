# Spec — Scripted-Input Behavioral-Trace Harness (P1.1)

> Owned by the **Architect**. The **format is a contract**; the Developer builds the
> minimal harness against it and *raises* problems, and **QA owns authoring the
> trace-scripts** long-term (it is "how the audit is performed"). Folded into the
> character-A movement reconciliation work-order
> (`briefs/character-a-movement-reconciliation.md` → "Companion capability"). This
> spec covers three contracts: the **input-string → `InputFrame`-buffer syntax**, the
> **replay seam** (Tenet 2), and the **trace field-set / file shape**.

## What it is, and what it is NOT

An authored input string is compiled to a raw `InputFrame` buffer, replayed **headless**
(Godot `--headless -s`, exactly how the 27 suites already run) through a real Tenet-2
input source, and a per-tick **trace** of chosen `InspectionView` fields is dumped and/or
asserted against expected. It gives the reconciliation an **executable, brief-derived
behavioral coverage** — the checklist items ("hold 6, release → returns to idle by frame
X") become assertions it expresses.

- **It reads sim state — the same values the headless suite reads.** So it catches the
  **sim-behavior** half of the reconciliation (walk-won't-stop, wrong state/position,
  unreachable crouch, jump arcs, reachable normals). It is **blind to render bugs** by the
  same logic that hid the Y-inversion from all 27 tests (it does not snapshot pixels). It
  **shrinks** the human re-gate to genuinely-visual concerns; it does **not remove** it.
  **Do not mark P1.1 done on this harness's green** — that is the P1 mistake in a new
  costume (`pipeline-analysis-completeness-gap.md`).
- **It is minimal, not a TAS framework.** Near-term scope: compile a string → buffer,
  replay N ticks headless, dump/assert chosen fields. Nothing more.

## Build for extension (Tenet 3) — not test-only

The same "load an input string, replay deterministically" mechanism is, one step out, a
**player sharing a setup** — a pasteable input string that loads a situation to *practice
against* in training mode — and **P3's scripted-input tutorial source arriving early**.
So the format is designed **shareable and human-authorable**, and the replay path is the
**general Tenet-2 input-source seam**, never a test-harness backdoor. This spec builds
none of those features; it only refuses to foreclose them.

**Tenet-2 check (the work-order asked me to flag any strain — there is none).** A scripted
input is a first-class producer in the tenet itself ("scripted tutorial sequences … all
emit the identical per-frame stream") and in `input.md`'s producers table ("Scripted
(tutorial/CPU) — yields frames from an authored sequence"). The harness replays through
the existing **`RecordPlaybackSource`** in `PLAYBACK` mode (`set_recorded_buffer` +
`Mode.PLAYBACK`, JC-030), which **already** implements `InputSource`. The sim consumes it
identically to a device or a replay — nothing in the sim knows the frames were authored.
No tenet strain; no new source type.

## Contract 1 — the input-string syntax (`InputScript`)

A compiler from a human-readable string to a `PackedInt32Array` of raw `InputFrame`
values, one entry per tick. Specified as a **pure function** (`compile(text) -> PackedInt32Array`)
in an `InputScript` namespace (a `class_name` of static helpers, sibling to `InputFrame`;
mirrors the `FP`/`InputFrame` packaging). Pure so the *shareable artifact* is the string
and the *replay* is deterministic.

**Grammar.** Whitespace/newline-separated **tokens**; each token is one held frame
(optionally repeated). `#` begins a line comment.

```
token   := frame [ '*' count ]
frame   := [ dir ] [ button... ] | '5'          # '5' or a bare button = neutral direction
dir     := '1'..'9'                              # numpad, RAW/screen-relative (see below)
button  := 'L' | 'M' | 'H'                       # BUTTON_0 / BUTTON_1 / BUTTON_2 (AD-018)
count   := integer >= 1                          # repeat this exact frame `count` ticks (default 1)
```

- **Numpad directions are RAW (screen-relative):** `6`=RIGHT, `4`=LEFT, `2`=DOWN, `8`=UP,
  `9`=UP+RIGHT, `7`=UP+LEFT, `3`=DOWN+RIGHT, `1`=DOWN+LEFT, `5`=neutral. The value produced
  is a raw `InputFrame` (bits per `input.md`); the sim applies SOCD + facing itself
  (AD-003). Because **P1 (the character under test) starts facing right**, raw numpad reads
  as facing-relative for P1 — `6` *is* forward, `236` *is* a fireball motion — the intuitive
  case. Authoring for a left-facing P2 is mirrored; a `mirror` option on the compiler is a
  build-for-extension hook, **not built now** (the reconciliation drives P1).
- **Motions are authored per-tick, honestly:** a fireball is three tokens `2 3 6H`, a DP is
  `6 2 3H` — matching the sim's per-tick reality and the 9-frame motion window (AD-022). No
  motion shorthand; the harness is per-tick, like the sim.
- **Buttons combine with a direction on one frame:** `6H` = forward+Heavy this tick;
  `2M` = down+Medium; `H` = neutral+Heavy. Multiple buttons concatenate (`LH` = L+H chord,
  e.g. throw).
- **Repeat:** `6*30` = hold forward 30 ticks; `5*10` = neutral 10 ticks; `2*3` = crouch 3
  ticks. This is what makes brief-checklist authoring compact ("hold 6 for 30, release for
  10, assert idle").

**Validation.** Every compiled frame passes the input boundary (`InputFrame.is_valid` /
`InputSource.validate`, `input.md` criterion 6) — a malformed token or a reserved bit is a
hard compile error, never a silently-dropped frame. An unknown character is an error, not
ignored (so a typo cannot quietly change the meaning of a shared setup).

**Grammar edge cases (pinned — ratified from JC-051).** So a shared-artifact string has one
durable reading:
- A **repeated button letter** within one token (e.g. `LL`) compiles without error — it is
  the same bit OR-ed twice, a no-op, not a typo class the grammar rejects.
- **Button letters are case-sensitive:** only uppercase `L`/`M`/`H` are buttons; lowercase
  is not aliased and is a malformed character.
- Digit `0`, and any character outside `1`..`9` / `L` / `M` / `H` / `*` / `#` / whitespace,
  is a **malformed token** (hard error), never ignored.

**Debug rendering is the inverse.** `InputFrame.to_debug_string` already renders a frame as
`U/D/L/R/B0..B7` — the trace's input column reuses it (or a numpad rendering) so a dumped
trace is self-describing. The numpad string and the debug string are two views of the same
raw frame.

## Contract 2 — the replay seam (Tenet 2)

The harness is a thin **headless driver** above the sim, reusing the existing produce-before-
query wiring (the same ownership `TrainingHarness`/`TickHost` already have — `input.md`
"owned invariant"):

1. Compile the P1 (and optionally P2) input string → buffer(s).
2. Load each buffer into a `RecordPlaybackSource` via `set_recorded_buffer`, set
   `Mode.PLAYBACK`.
3. Install the roster (`MoveRegistry` / `ProjectileRegistry`), build the initial `SimState`
   with both players as the character under test in idle (the same wiring TKT-P1.1-01 fixed).
4. For N ticks: `produce_next()` each source (produce-before-query), `step`, and record the
   trace row for this tick from the `InspectionView` over the new state.

No path reaches into `SimState` internals — the trace is read **only** through
`InspectionView`, exactly like the geometry overlay and the QA golden harness (the seam,
AD-011). The P2 source defaults to a neutral (idle) script when only P1 is driven.

## Contract 3 — the trace field-set and file shape

A trace row is **plain text, fixed field order, integer/enum truth only — no floats** —
reusing the AD-019 discipline that keeps the QA golden net float-free (so a trace can be
born from a human-confirmed run and then **locked as a golden** later, the work-order's
discipline). Pixel projections are never in a trace.

**Row = one dumped tick.** Fields are `key=value`, space-separated, in this fixed order.
The default field-set (the movement-reconciliation set) is:

| Field | Source (`InspectionView`) | Why |
|---|---|---|
| `tick` | `tick()` | the clock |
| `p{i}.state` | `player(i).state_id` | walk/crouch/jump/idle reachability + exit |
| `p{i}.frame` | `player(i).frame_in_state` | frame-within-state |
| `p{i}.cat` | `player(i).state_category` | GROUNDED/AIRBORNE (jump takeoff/landing) |
| `p{i}.px`,`p{i}.py` | `player(i).position` (fixed-point) | jump arc (net-zero, lands flush), walk distance |
| `p{i}.vx`,`p{i}.vy` | `player(i).velocity` (fixed-point) | arc rise/fall, walk speed |
| `p{i}.act` | `player(i).actionable` | recovered / committed |
| `p{i}.stun`,`p{i}.sk` | `player(i).stun_remaining`, `stun_kind` | hit/block windows |
| `p{i}.face` | `player(i).facing` | facing-relative sanity |

**Optional field-sets** (opt-in per script, to keep rows terse): `boxes` (each
`player(i).boxes` as fixed-point world rects `kind:x,y,w,h` — for geometry assertions the
*sim* can make, e.g. "the crouch hurtbox's top edge is above the stand box's"; note this is
**sim geometry truth**, still blind to the *render* Y-flip which only a human sees);
`advantage` (`value`/`plus_player`/`neutral_restored`); `last_hit` (`attacker`/`defender`/
`damage_dealt`/`was_block`/`contact_depth`/`air_height_hitstun_delta`).

**Emitted row encoding (pinned — ratified from JC-049).** The literal token sequence a row
emits is fixed (so a `.trace` is a stable, diffable, golden-able artifact): `tick=<n>`, then
**player 0's full default block** as `p0.<field>=<value>` in the table's order
(`state, frame, cat, px, py, vx, vy, act, stun, sk, face`), then **player 1's identical
block** (`p1.*`) — a whole player per block, not interleaved per-field. Opt-in fields follow:
`boxes` renders immediately after that player's default block as `p{i}.boxes=` with each box
`KIND:x,y,w,h` (`KIND` ∈ `HURT/HIT/THROW/PUSH`), entries `;`-joined; `advantage` and
`last_hit` render after both players' blocks.

**Two output modes.**
- **Dump** — write the trace rows (all ticks, or a chosen subset) to stdout / a `.trace`
  file. A `.trace` is plain text, diffable, golden-able.
- **Assert** — the primary near-term mode. The script carries **inline, human-readable
  assertions derived from the brief**, each `(tick, field, expected)`, checked against the
  trace; a mismatch fails loudly with the tick, field, expected, and actual. This encodes
  *intended* behavior, not "whatever the sim does today." Illustration, expressing the
  walk-and-stop checklist item:

  ```
  # walk forward then release → returns to idle
  P1: 6*30 5*10
  assert tick=30 p0.state=WALK_F
  assert tick=41 p0.state=IDLE        # released at 31; idle by the next actionable tick
  ```

  **Assert host (ratified from JC-050).** The block above illustrates the assertion
  *semantics* — `(tick, field, expected)` checked against the trace, failing loudly by name
  — **it is not a pinned text-file grammar.** The **ratified near-term assert host** (and
  QA's near-term authoring surface) is the GDScript API — `TraceHarness.check(rows, tick,
  field, expected)` plus `TraceHarness.row_at` — which delivers exactly those semantics
  inside the codebase's existing test-authoring convention. It reads a raw `state_id`
  directly; the illustration's **symbolic names** (`WALK_F`, `IDLE`) are shorthand for a
  reader, not a built resolution step — resolving them would need a per-character
  symbol-table (name→id) contract that **does not exist** and would break the harness's
  **character-agnostic** seam property (inspection-surface.md criterion 5). A literal text
  `.script` DSL (with such a symbol-table contract) is an **explicitly-deferred, additive
  extension** — on the same build-for-extension horizon as the "share a setup" / P3-tutorial
  hooks below — **not** part of this build's scope and not owed by it. It becomes a spec item
  only if/when QA's authoring plan calls for pasteable text files.

**Discipline (so the harness stays honest).** Inline brief-derived assertions **beat blind
golden-diffs** for this purpose — a pure record-and-lock golden would enshrine current bugs
(the JC-047 trap: a test that "tolerated the drift" thereby documented it). A golden `.trace`
is legitimate **only after** it is born from a human-confirmed run and then locked; that
golden-lock is a QA long-term concern, not this build.

## Ownership & near-term build scope

- **Architect (this spec):** the three contracts above.
- **Developer (minimal build):** the `InputScript` compiler; the headless driver over
  `RecordPlaybackSource` + `InspectionView`; the trace row dump; the inline-assert runner.
  Nothing else — no mirroring, no `.trace` golden tooling, no P2 AI. Sequences early (the
  ticket file) so the Developer can verify movement fixes **through it** as they land.
- **QA (long-term):** authors the brief-derived trace-scripts (the coverage oracle) and,
  once a run is human-confirmed, may lock golden `.trace` files. **Authoring surface
  (ratified JC-050):** near-term, trace-scripts are authored against the GDScript assert API
  (`TraceHarness.check`/`row_at`), not a text `.script` DSL — the text DSL is a deferred,
  additive extension gated on a character symbol-table contract (see Contract 3 "Assert
  host"). If QA's authoring plan later wants pasteable text scripts, that is a new
  Architect-owned spec item, raised then — not a gap in this build.

## Acceptance criteria (QA-checkable)

1. **Compile is pure and total.** `InputScript.compile(text)` returns the same buffer for
   the same text every call; every emitted frame is valid (`InputFrame.is_valid`); a
   malformed token or reserved bit is a hard error, not a dropped/altered frame.
2. **Numpad → raw mapping.** Each numpad digit compiles to the specified raw direction bits
   and each of `L/M/H` to `BUTTON_0/1/2`; `*count` repeats the exact frame; `#` comments and
   whitespace/newlines are ignored.
3. **Replays through the real seam.** The harness drives the sim through a
   `RecordPlaybackSource` in `PLAYBACK` (not a bespoke sim caller); the resulting run is
   **bit-identical** to feeding the same buffer through any other `InputSource` of the same
   frames (source equivalence, `input.md` criterion 3) and deterministic across repeats
   (identical final state hash).
4. **Trace reads only the seam, float-free.** Every trace field comes from `InspectionView`;
   no `SimState`-internal type is named; no float appears in a trace row (AD-019). A trace
   over a fixed run round-trips identically.
5. **Assertions encode intent.** An inline `(tick, field, expected)` assertion passes when
   the trace matches and fails loudly (naming tick/field/expected/actual) when it does not; a
   script asserting a brief behavior the sim does **not** yet satisfy **fails** (the harness
   catches the omission — its whole purpose).
6. **Blind to render, honest about it.** The harness snapshots no pixels and makes no claim
   about on-screen orientation; a trace is green while a render bug (e.g. the Y-inversion)
   is live — which is exactly why the human re-gate is not removed (documented, not a defect).
