# Migrating FoggyGlass to Claude Code — morning action plan

*Strategist notes for Ryan. Read top to bottom. Part 1 is the do-this-now
checklist; Parts 2–4 explain the reasoning so you learn the process, not just
run it. I've already done the safe prep — see Part 5.*

---

## The one-sentence version

Your three walk-away blockers (Godot can't run, git corrupts, sessions can't
resume) are all properties of the **Cowork sandbox**, not your protocol. Claude
Code runs natively on your Windows box against `E:\FoggyGlass` and has the exact
primitives you're missing. The migration costs **$0**, and your coordination
protocol — the hard, valuable part — carries over. What follows is how to move,
plus two places I think Fable's write-up pointed you at more work than you need.

---

## Part 1 — The morning checklist (do these in order)

Everything here runs on your own machine. Anything needing your GitHub login is
called out — that's yours; I don't touch credentials.

**Step 0 — Install Claude Code (~10 min).**
It's included in your $20 Pro plan; no new spend. In PowerShell:

```powershell
npm install -g @anthropic-ai/claude-code
```

(If you don't have Node.js, install it first from nodejs.org — the LTS
installer. `npm` comes with it.) Then verify:

```powershell
claude --version
```

**Step 1 — Open the repo in Claude Code.**

```powershell
cd E:\FoggyGlass
claude
```

First launch will ask you to log in (browser) and to "trust" the folder — say
yes. That trust prompt is what lets it read `.claude/settings.json` and run
tools. This is the moment the substrate changes: from here, the tool sees your
real disk, your real git, and your real Godot.

**Step 2 — Confirm it loaded your project brain.** Inside the session, type:

```
/memory
```

You should see `.claude/CLAUDE.md` listed as loaded. That file is your binding
read (charter/principles/tenets pointers) and it now loads **automatically every
session** — the cold-start re-read you were paying by hand is now free. If it's
*not* listed, that's the one thing to fix first (it will be — see Part 5).

**Step 3 — Prove Godot runs from inside the loop.** This is your disqualifier,
so test it before anything else. Ask the session:

```
Run the headless tests: godot --headless --path game -s res://tests/test_fp.gd
and tell me the exit code.
```

It'll ask permission to run the command the first time — approve it. If your
Godot binary isn't on `PATH`, point it at the full path you already use in
`run_tests.bat` (`C:\Users\ryans\Downloads\Godot_v4.3-stable_win64.exe`). When a
test prints `OK` and exits 0, or `FAIL` and exits 1, **the pipeline can now
verify its own work** — the single biggest change in this whole migration. (Why
this already works: your tests are `SceneTree` scripts that call `quit(0)` /
`quit(1)`, and that becomes the process exit code. You built a real headless
harness by hand; the sandbox just couldn't run it. Now it can.)

**Step 4 — Let it run native git.** Ask:

```
git status, then stage and commit the current changes with a sensible message.
```

No more `COMMIT_MSG.txt` / `commit.bat` dance, no clobbering. It runs real git
on the real filesystem. **Keep `push` as your manual gate** for now — let it
commit freely, but you run `git push` yourself (or approve it each time) until
you trust the loop. That preserves a human checkpoint exactly where safety
matters and nowhere it doesn't.

**Step 5 — Try a role.** Your four roles are now native subagents (I created
them — Part 5). Ask:

```
Use the foggyglass-developer subagent to pick up the next open flag.
```

It spins up in its own context window on its own model, does the work, and
returns just a summary to your main session — so an interrupted or verbose task
no longer kills the whole conversation at a token ceiling.

**Step 6 — Run one full milestone the new way, then stop and measure.** Don't
re-architect anything yet. Do a normal batch of work, then open Settings →
Usage on claude.ai. That number decides your budget question (Part 4) — not a
guess today.

That's the migration. Everything below is *why*, and the two judgment calls I'd
make differently from Fable's note.

---

## Part 2 — Itemized by your three roadblocks

### Issue #3 — Godot execution (the disqualifier — fixed first)

**What fixes it:** Claude Code runs Godot headless natively. Steps 3 above.
That's the whole fix.

**Where I'd push back on Fable:** the note says "wire up GUT or gdUnit4
headless." I don't think you should — not now. **You already have a working
headless test harness**: `run_tests.bat` loops 13 `SceneTree` tests, each
reporting pass/fail via exit code and readable stdout. gdUnit4/GUT would give you
an assertion library, test discovery, and JUnit-XML output — but you already have
discovery (the batch loop), you already have pass/fail an agent can read (exit
codes + `OK`/`FAIL` text), and JUnit XML only matters once you're feeding a CI
*dashboard*, which you aren't. Adopting gdUnit4 means **rewriting 13 passing
test files** for marginal gain. That's churn against a working system, and your
own charter ethos is "friction that stands between you and the play space is tax
to remove" — this would be self-inflicted tax.

**The lesson to actually steal** from those frameworks (Randroids-Dojo's
Godot-Claude-Skills included) is the discipline you *already embody*:
machine-readable pass/fail + a non-zero exit on failure so one bad test fails the
run. You're there. Revisit gdUnit4 only if you later hit a concrete wall —
wanting rich assertion diffs, or a real CI server. Don't adopt a framework to
solve a problem you already solved by hand.

*One small hardening worth doing:* your `run_tests.bat` summary line hardcodes
"All 9 passed" but the list has 13 tests. Cosmetic, but since the agent will
read that output, have the Developer fix the count so a summary never lies to the
role reading it. (Flag it through the protocol — it's Developer-owned code.)

### Issue #2 — Git (least urgent, still a walk-away blocker — fixed by moving)

**What fixes it:** native git. The sandbox-corruption reason for the whole
`.bat` apparatus disappears. Retire `commit.bat`, `push.bat`,
`sync-consultant-context.bat`, and `COMMIT_MSG.txt` once you've confirmed native
commits work.

**Walk-away version:** if you later want unattended commits, use Claude Code's
permission allowlist to auto-approve `git commit` and the Godot command while
still prompting (or blocking) on `git push`. That's the "autonomous-but-safe"
shape your Strategist analysis asked for: automate the reversible checkpoint,
keep a human gate on the one irreversible push to `origin`.

### Issue #1 — Token cost (the structural win)

Three levers, in order of leverage:

1. **Session resumption** — `claude --resume` (pick a past session) or
   `claude --continue` (most recent). Your biggest documented waste was
   interrupted batches re-paying the full cold-start. This is the direct cure:
   an interrupted build resumes instead of respawning from zero.
2. **Per-role models** — done in prep. Strategist/Architect on `opus` (judgment,
   contracts — expensive to get wrong), Developer/QA on `sonnet`. A Developer
   fixing one flag does *not* need the top model, exactly as you suspected. Tune
   freely; it's a one-word change per file.
3. **Auto-loaded CLAUDE.md** — your binding read now loads once, automatically,
   instead of being manually re-pasted each session.

**The scaling threat that actually matters** (you named it, and it's real): the
*binding read grows every milestone* as specs + the decision record accumulate.
Resumption and model-tiering don't fix that; only **active pruning** does. Two
concrete moves: keep `.claude/CLAUDE.md` under ~200 lines (Claude Code's own
guidance — adherence drops past that), and move reference material that isn't
needed *every* session out of the always-loaded set and into **skills** or
**`.claude/rules/`** (path-scoped rules load only when a matching file is
touched). That's the "keep the fixed read small" mechanism your protocol wanted
but the chat app couldn't give you.

---

## Part 3 — Itemized by repo (steal the lesson, not the repo)

You said you don't want to adopt these wholesale — good instinct. Here's the
lesson from each and my keep/skip call.

**caveman** — *steal one sub-skill, skip the rest.* Its headline 65–75% savings
are on *output* tokens; your bottleneck is *input* (cold-start reads), so the
headline doesn't apply to you. The one piece that hits your actual cost is
`caveman-compress`, which shrinks memory files like CLAUDE.md. **Verdict:**
optional, low priority. If you try it, compress *only* the fixed binding docs —
never the specs, ADs, or flags. In your system the artifacts *are* the contract;
a spec written in telegraphic shorthand becomes a new source of ambiguity you
then have to adjudicate. Your instinct that it'd make debugging role behavior
harder is correct. Skip until pruning alone stops being enough.

**claude-code-agents-orchestra** — *steal the mechanism, skip the repo.* The one
good idea (per-role model assignment) isn't even the repo's — it's native Claude
Code, and it's already applied in your role files. The repo's 47 web/crypto/CMS
agents are worse than the roles you validated across 29 judgment calls.
**Verdict:** skip the repo entirely; you already have the mechanism.

**superpowers** — *your "oof" is half-warranted; don't feel bad, and don't
migrate.* It has the SDLC flow (brief → plan → dispatch subagent per task →
two-stage review), which overlaps your pipeline. What it **lacks** is the part P0
proved actually works: one-owner-per-artifact, the flag ledger with owner-only
resolution, the judgment-call log with Architect ratification, and the
**cumulative milestone drift sweep** (the thing that caught your vacuously-green
test). Superpowers' review is per-task; it has no equivalent of your
behavior-vs-charter sweep. **Verdict:** don't migrate. Install it *only* to watch
one mechanic — its **fresh-subagent-per-task dispatch**, which is a clean fix for
your batch-fragmentation strain (each ticket gets a clean context; the
orchestrator holds the thread; no whole-batch death at a token ceiling). Port
that pattern into your roles; leave the rest. You built the governance layer it
doesn't have, and you understand *why* each piece exists — which someone who
`npm install`s a methodology never learns.

**CubeSandbox** — *skip, no caveat.* It's microVM infrastructure for people
*hosting fleets* of agent sandboxes. Your costs are token/inference costs; VM
spin-up speed has zero effect on them. Worse, it'd have you stand up WSL2/KVM to
solve a sandbox problem that migrating to Claude Code **eliminates** — Claude
Code doesn't sandbox you away from your machine; that's the entire point.
Wrong layer. Don't.

**The 500MB question** — repo size ≠ context cost. Agents pay tokens for what
they *read into context*, and no role ever reads a `.ogg`; binaries can't be read
as text anyway. The real (smaller) issues: (a) git bloat — use **Git LFS** for
asset dirs, or `.gitignore game/assets/` and back them up separately; assets
don't need code-style history; (b) search noise — make sure role file-searches
exclude asset dirs. Neither is the scaling threat; the growing *binding read*
(Part 2) is.

---

## Part 4 — Budget

**Don't spend anything yet.** The migration is free and attacks all three
roadblocks plus model-tiering. The honest caveat: Pro is a 5-hour session cap
plus a weekly cross-surface cap, and an autonomous build-verify loop burns faster
than chat. So do Step 6 — run a milestone, check Settings → Usage. Then:

- Walled only occasionally → **usage credits** (pay-as-you-go past the cap). A
  ~$30/mo credit ceiling keeps you at ~$50 total — inside your normal budget.
- Walled daily → **Max 5×** at $100/mo (your stated absolute ceiling).

My expectation: Pro + Sonnet-tier Developer + resumption gets you meaningfully
further than Pro + your current architecture ever could, because today you pay
the cold-start tax ~10× per milestone for nothing. Measure before you commit
money.

---

## Part 5 — What I already did (safe, reversible, no git/credentials touched)

1. **Created `.claude/agents/strategist.md`, `architect.md`, `developer.md`,
   `qa.md`** — your exact validated role prompts (copied byte-for-byte from the
   plugin) with one addition: a `model:` line (opus for Strategist/Architect,
   sonnet for Developer/QA). Claude Code reads `.claude/agents/` directly, so
   these are live the moment you open the repo — no zip, no re-upload.

2. **That's it for changes.** I didn't delete the plugin, touch git, or edit your
   binding docs.

### Your `.claude/` audit (you asked: is it correctly constructed?)

**Mostly yes.** Specifics:

- **`.claude/CLAUDE.md` — correct, leave it.** A common worry is that CLAUDE.md
  must sit at the repo root. It doesn't; Claude Code loads *either* `./CLAUDE.md`
  *or* `./.claude/CLAUDE.md`. Yours is fine where it is. (Keep it under ~200
  lines.)

- **Role definitions were plugin-only — now you have a better home.** Your
  CLAUDE.md notes "Cowork does not read `.claude/agents/`." True for Cowork —
  but **Claude Code does**. That's why I put the roles there. It removes the
  edit → re-zip → re-upload cycle entirely, and unlocks the `permissionMode`
  field (which plugin agents *ignore*) — the field you'll want for
  auto-approving Godot/git on unattended runs. **Action for you:** once you've
  confirmed the native roles work, **retire the `foggyglass-roles` plugin** so
  there's a single source of truth for each role. Two copies of a role prompt is
  exactly the drift vector your whole protocol exists to prevent — don't run both
  long-term.

- **`.claude/settings.json` — leave it for now.** It sets
  `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and allows `SendMessage(*)`. That's
  the experimental **agent-teams** feature (roles that message *each other*
  directly). That's a real architectural change to your protocol — see the
  decision below. Until you decide, it's harmless but unused.

---

## Part 6 — The one strategic decision I won't make for you

Fable said "your coordination protocol transfers intact; only the substrate
changes." That's ~90% true, and the 10% is worth naming before you trip over it.

Your protocol's load-bearing premise is *roles don't share memory; the user is
the only bus.* That was a **workaround** for the chat app having no way for
agents to talk. Claude Code offers two new shapes:

- **(A) Keep separate sessions.** Each role is still its own session; you still
  carry handoffs. Minimal conceptual change. Everything in Parts 1–5 works today
  with zero protocol edits. **This is what I recommend for the first milestone.**
- **(B) Adopt orchestration / agent-teams.** A main session dispatches role
  subagents and they can message each other. Bigger token wins, but it
  *changes the premise* — "the user is the only bus" stops being true, and your
  upstream-correction and one-owner rules need re-examining against a world where
  roles talk directly.

**My call: don't change two things at once.** Migrate the substrate (A), run one
milestone, confirm the three roadblocks are actually dead, *then* decide whether
(B) earns its complexity. Changing the protocol and the platform simultaneously
means that when something breaks you won't know which move broke it. A dead end
named early is cheap. This one's named.

---

## TL;DR priority order

1. Install Claude Code, open the repo, confirm CLAUDE.md loads. (free)
2. Prove `godot --headless … -s res://tests/…` runs from inside a session — your
   disqualifier dies here. **Don't** rewrite tests into gdUnit4.
3. Let it run native git; keep `push` as your manual gate.
4. Use the native subagents (already set up); use `--resume` for iterated work.
5. Run one milestone, check Usage, *then* talk budget and orchestration.

Your coordination machinery is the hard part and it's genuinely good. This whole
plan is just moving it onto a floor that can run your tests.
