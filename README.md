# FoggyGlass

A deterministic fighting-game vertical slice, built by a small **memory-less agent
pipeline**. This README documents that pipeline architecture, using the P1 milestone
(the first character + the debug/technical training mode) as a worked case study.

GitHub: `https://github.com/thetitan555/FoggyGlass.git`

---

## The four roles

Delivered as native Claude Code subagents (`.claude/agents/`). **One owner per artifact.**

| Role | Owns |
|---|---|
| **Strategist** | Direction, priority, roadmap, briefs, the audit criterion, coordination |
| **Architect** | Spec, architecture decisions (ADs), the contracts code is built against, tickets, batch plans |
| **Developer** | Implementation against tickets; records latitude in the judgment-call log |
| **QA** | Audits against acceptance criteria, the tenets, and the audit criterion |

Binding context for every role: the **charter** (the *why*), the **design principles**
(legibility; no knowledge checks), and the **Technical Tenets** (determinism; a single
input-source abstraction; build-for-extension). These route every decision and are not
any role's to relax — a conflict is *raised*, not worked around.

## How they coordinate

Roles carry **no memory across sessions**, so state lives in **artifacts, not heads**:

- **The shared working tree is the handoff.** A role hands off by *saving the file*; the
  next role reads it from disk. If it isn't on disk, it didn't happen.
- **The flow:** `idea → brief → spec → code → audit`. Work is **done only when it clears
  audit** — not when the Developer thinks it's finished.
- **Upstream correction:** any role may *raise* a problem with anything it inherited (up to
  the charter); only the **owner** of that artifact *resolves* it — by fixing it or ruling
  it intended. A downstream role never patches around or silently redefines an upstream
  artifact.
- **Ledgers, kept cheap:** `flags.md` (open cross-role issues; resolved ones archived),
  `judgment-log.md` (Developer latitude → Architect ratifies before audit), `decisions.md`
  (ADs, index-fronted). Rationale lives once and is cited, never restated.
- **Token economy:** the dominant cost is cold-start *re-reading*, so same-owner work is
  batched into as few sessions as possible, each right-sized to a real checkpoint.
- **Git:** roles commit natively; **the user is the sole push gate** (`push.bat` is a thin
  push wrapper). The human owns the one irreversible step.

## Case study — how P1 actually flowed

1. **Strategist** ruled scope, split the work into batches, and dispatched the roles.
2. **Batch 1 (Developer)** built the sim-facing interfaces (inspection surface, frame
   control, save/reset, record/playback dummy) + the projectile system.
3. **Character A authored as data** — and authoring a *real* kit exposed gaps the format
   didn't yet cover: invulnerability was never *consumed*, and jump/throw commands couldn't
   be *expressed*. The Developer **flagged rather than hacked**.
4. **Upstream correction in action:** those flags went to the **Architect** (owner), who
   designed `AD-031` (invuln consumption) and `AD-032` (command schema) and wrote the engine
   tickets. Ratification then surfaced a *scope* question — height-dependent air advantage —
   which routed back to the **Strategist**, who ruled it in-P1 → `AD-033`.
5. **Engine batch (Developer)** built the three, completing character A to spec.
6. **Batch 3 (Developer)** built the training-mode shell + overlays, reading the *one*
   inspection surface (seam discipline).
7. **Pre-audit (Architect)** ratified every judgment call and swept the log clean of stale
   provisional entries.
8. **Audit (QA)** verified the whole feature directly — 1131 checks green; determinism,
   serialization, the single-input-source abstraction, seam discipline, and observability
   all confirmed. **P1 PASSES** (`docs/audits/audit-p1-feature.md`).

## What the run demonstrated

- **Content pulls the engine forward.** Authoring a real character found the format's real
  gaps — exactly what a vertical slice is *for*. The gaps became owned rules (ADs), not ad-hoc
  patches.
- **The machinery held under interruption.** Several sessions hit limits mid-work, but because
  handoffs are files on disk and decisions live in artifacts, each was recovered without loss.
- **Legibility is a first-class acceptance criterion.** "Why is this deep jump-in so plus?"
  and "why did that hit whiff?" are both answerable live in the training mode — audited, not
  assumed.

### User's observations 

(you can tell I wrote it because this markdown is probably not formatted properly)

- Big asterisk on that last QA step. It tried to spawn its own subagent, which is absolutely not what it's supposed to do.
Strategist had to correct it and say "do the audit, don't delegate". This burned 150k tokens before I could catch it, and I had to be the one to catch it. 
This is the biggest one.
- The Claude app UI prompted me to update stale comments due to slight semantic wrongness in godot terminology.
That process spawned a new worktree which never properly committed and was unable to be deleted until I killed the Claude app.
- Holy SHIT it spent a lot of tokens. This stage blasted through most of my $30 buffer!
That was supposed to last the whole month, and it barely lasted a session!
- I spent $42 for the progress made so far. 
Would I have been willing to commission someone for this much well-documented well-architected self-correcting work?
...Maybe? Unclear. It's hard to argue with the volume of results. At the same time, I don't have anything I can really look at or read.
It's done so much so fast that truly catching up to it would take me until the next token refresh at Wednesday 7am.
So I guess I'm waiting on a playable vertical slice, which will probably come around P3-P4. I can wait that long.
However, the amount I've learned about this has been priceless. Thanks for continuing to elbow me about this until I did it dad <3

## Status & open threads

**P1 is done (audited).** Character A and the instrumentation the whole team now uses exist
and pass 1131 checks. Open items live in `docs/flags.md`: in-mode *visual* confirmation of
the overlays (human eyes), a stale `run_tests.bat`, a stale code comment, and a
Strategist-owned protocol refinement on commit cadence. Next milestone: **P2** — a second,
contrasting character and the 1v1 match loop (proves the format wasn't secretly A-shaped).

*See `docs/` for the charter, principles, tenets, protocol, roadmap, spec, and audits.*
