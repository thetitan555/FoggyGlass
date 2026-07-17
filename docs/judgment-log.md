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
