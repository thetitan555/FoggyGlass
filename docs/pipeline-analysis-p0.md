# FoggyGlass pipeline — structure & health

*Assessed at the end of P0 (the architecture-backbone milestone: 11 tickets, 2 build batches, 13 flags F-001–F-013, ~29 judgment calls JC-001–029, 4 audits). Written for review alongside a peer running a similar role-based system.*

---

## Part 1 — Structure

### The one constraint everything follows from

The pipeline is five specialists — **Strategist, Architect, Developer, QA**, plus a **Consultant** who sits outside — that run as separate sessions and **do not share memory**. They cannot talk to each other. They coordinate through exactly two channels:

1. **A shared working tree** (`E:\FoggyGlass`) on disk. A "handoff" is nothing more than saving a file; the next role sees it because it's the same disk. There is no message bus.
2. **The user** — the only live connection between the rooms. The user carries "go look at X" from one role to the next, and carries flagged problems back to their owner. The user also runs git and runs the game engine.

Because nothing lives in a role's head across sessions, **the artifacts are the memory.** If it isn't written to the shared tree, it didn't happen.

### One owner per artifact

- **User** owns the charter, design principles, and technical tenets (the fixed ground).
- **Strategist** owns the protocol, roadmap, feature briefs, and the audit criterion (direction and coordination).
- **Architect** owns the spec, the architecture-decision record (ADs), and the tickets (the contract).
- **Developer** owns the game code and its tests (the build).
- **QA** owns the audits (the verdict).
- **Flags** are the one shared surface: any role may *append* a problem; only the artifact's owner *resolves* it. The judgment-call log is similar — the Developer appends, the Architect rules.

### The flow

`idea → brief → spec → code → audit → done.` Work is "done" only after it clears audit — never when the Developer thinks it's finished. An idea can enter from anyone (including a downstream flag or the outside Consultant); the Strategist decides whether it becomes a brief.

### Upstream correction — the load-bearing rule

Any role may raise a problem with anything it was handed *from upstream* — up to and including the charter. But **only the owner of that artifact resolves it**, either by fixing it or by ruling it intended. A downstream role never patches around a problem, never edits the upstream artifact itself, and never unilaterally decides something is a bug or is fine. It flags; the owner adjudicates. Problems get corrected where they originated.

### Cadences

- **Per session** — the Strategist archives resolved-and-relayed flags so the live ledger stays cheap to read.
- **Per feature** — QA audits against acceptance criteria before anything is "done"; the Architect ratifies the judgment log before that audit.
- **Per milestone** — QA runs a cumulative **drift sweep**: the behavior-vs-charter and spec-vs-implementation review that per-feature checks can't see.

### Git

Roles never run git (sandbox git on the mounted Windows filesystem corrupts). A role writes a message to `COMMIT_MSG.txt` and tells the user "ready"; the user runs `commit.bat` / `push.bat` natively. Git is history and backup — *not* the inter-role transport. The shared tree is.

---

## Part 2 — Health

Grounded in what P0 actually did, not in how the protocol reads on paper.

### What's working — and it's the hard part

**Upstream correction genuinely self-corrects.** The clearest evidence: the simulation's core state contract was *discovered field-by-field as systems were built*, not enumerated up front. Batch 1 surfaced five inspection-backing fields (F-002); single-hit memory added one (F-005); batch 2's cancels and throws added five more (F-010). Every single time, the Developer **flagged** the state addition to the Architect instead of silently expanding a contract it didn't own, and the Architect folded them into owned decisions (AD-024, AD-026, AD-028). The protocol even *grew a rule mid-flight* — an "extensible-as-systems-land" ruling that turned a recurring flag into defined process. The system improved itself under load.

**Latitude vs. contract stays separated.** JC-024 is the textbook case: the Developer reused an unrelated field (`blockstun`) as a stopgap for a throw tech-window, **flagged the schema question** rather than treating it as its own call, and the Architect overturned it into a dedicated field (AD-029) before the overload calcified. A contract-adjacent decision was caught and corrected at its owner.

**Spec never drifted from code.** QA's P0 drift sweep found *zero* spec-vs-implementation divergence across all 11 backbone tickets. The discipline of folding ratified calls back into the spec is what bought that.

**The milestone sweep caught what feature checks couldn't** — a vacuously-passing test (F-012): a green test asserting the absence of the wrong thing, which would have hidden future drift. A per-feature audit sees "green"; only the cumulative sweep asks "green for the right reason?"

### What strained

1. **Cold-start re-reading dominates cost.** Every role session re-pays its full binding read (charter, principles, tenets, protocol, plus task inputs) before producing anything. P0 ran roughly ten role sessions; each paid that tax. A two-line test fix costs the same cold-start as a whole feature. The protocol predicts this ("the dominant cost is cold-start reading, not output") — the run confirmed it starkly.

2. **Session fragmentation defeats batching.** The intent is large batches to amortize reads. But batch 1 hit a token limit mid-session — it landed two tickets, died, and a *fresh* session had to re-read everything to finish the rest. Because agent-resumption wasn't available, the interruption re-paid the entire cold-start: the exact waste batching exists to avoid. Batch size is squeezed between amortization (wants bigger) and blast-radius plus token ceilings (want smaller).

3. **The Godot execution gap is the sharpest failure mode.** Neither Developer nor QA can run the engine in-sandbox, so *nothing the pipeline produces is ever executed by the pipeline.* Every "pass" is static until the user runs it. This directly caused churn: two tests failed for the wrong reason — a stale constant (F-006) and an input buffered across a recovery boundary (F-011) — both from blind authoring against tick-precise behavior, and F-011 cost *two* Developer cycles because the first blind fix was itself unverifiable. **The pipeline cannot verify its own work.**

4. **Role-boundary blur under the execution gap.** When blind fixes failed, the Strategist did deep static code traces to pin the true cause before routing — effectively doing QA/Developer debugging from upstream. It was efficient (it broke the blind-iteration loop), but it's a smell: the clean one-owner model bends when the pipeline can't execute, and upstream roles get pulled downstream. It only works because the Strategist can read the code; it would not survive a domain where it can't.

5. **The user is a serialization bottleneck by design.** Every handoff, every checkpoint, every test run routes through the user. The protocol is explicit about this. It's fine for coordination — but it is the precise thing that blocks "walk away," because the human sits in the critical path for git and Godot on *every* cycle.

6. **Minor: checkpoint-message churn.** `COMMIT_MSG.txt` is a single file each role overwrites; sequential sessions clobber each other's messages, and the Strategist appends housekeeping lines. It works, but the granularity is fragile.

### Where it rubs against its own values

- **"As light as the work needs" vs. the growing record.** Archiving keeps the *live* ledgers cheap (good), but the *binding* read — specs plus the decision record — grows every batch, and that read is re-paid by every role every session. "Keep the fixed read small" is the right instinct and it's under constant upward pressure; it needs active pruning, not just archiving.
- **Batching preached, fragmentation delivered.** The token-economy reasoning is sound; the substrate (no resumption, token ceilings) undercuts it. The values are right; the tooling fights them.

### The three roadblocks you named

1. **Token costs — fundamental, but the biggest lever is unused.** The dominant cost is cold-start × session-count. The highest-leverage fix is **agent resumption**: a role that touches one feature several times (build → fix → re-fix) should *continue its session*, not respawn and re-read from zero. P0 burned multiple full cold-starts purely because interrupted or iterated work couldn't resume. Smaller binding docs help linearly; resumption helps structurally. Third lever, already working: right-size batches to real decision points (splitting at the done-bar was the good call).

2. **Git pushes — unsafe, least critical, but still a walk-away blocker.** The Windows-helper dance exists because sandbox git corrupts the mounted tree. It's not a token cost; it's a human checkpoint on every cycle and a latent safety worry. For walk-away it must become autonomous-but-safe — a git path proven safe on the mount, or a queued commit the user approves in one batch. Lowest urgency of the three, but it *is* on the walk-away critical path.

3. **Godot unit tests — the hard stop, and the real disqualifier.** Fix this first. Until a headless engine lives in the Developer/QA sandbox (or a CI the pipeline can trigger and read back), "done" is always provisional-on-your-run, and blind authoring will keep manufacturing wrong-for-the-right-reason failures. Every other strength is capped by this: coordination can be flawless and you still can't leave, because the only thing that knows the code *runs* is you.

### The end goal — "build a visual novel and walk away"

Honest read: the **coordination machinery** — the expensive, hard-to-get-right part — is genuinely robust. Across P0 it caught every contract gap, corrected each at its source, kept spec and code in lockstep, and even caught a test that passed for the wrong reason. A brand-new feature would exercise the same machinery, and I'd expect it to hold.

But *walk away until it's done* is blocked by three human-in-loop dependencies, in priority order:

1. **Execution (Godot)** — you are the test runner. The disqualifier; fix first.
2. **Redundant cold-starts (resumption)** — the biggest token lever; fix second.
3. **Checkpointing (git)** — de-human the commit path; fix third.

Close those three and the pipeline is genuinely walk-away for the *build-verify* loop, not just the design-and-contract loop. Today it is close to walk-away for design and contract, and **not yet** for build-verify.

One caution that isn't on your list: the **role-boundary blur** (strain #4). As long as an upstream role can silently absorb downstream debugging whenever execution is blind, the pipeline *looks* more autonomous than it is — an orchestrator is quietly doing QA. A build in a domain where the orchestrator can't read the artifacts would expose exactly how much of the current smoothness depends on that quiet absorption. Worth watching as the thing that most flatters the system's apparent readiness.

---

Hi! I'm the user. The above was written by the Strategist as an analysis. You can keep the topics in this doc in mind when thinking critically, but don't let them limit your imagination. 
This is my first time working with an agentic workflow to this level, so my own learning about this kind of process is valuable too. I have some coding experience but I'm a video game player, not a software engineer. 

Another point to add to all of the above is that as the repo grows, the load will become larger and larger. Will the repo become unworkable as soon as 500mb of sound files are introduced to game/? Mitigating it with more strict repo definitions has limitations spelled out by the Strategist in #4.

Some ideas I've heard of from elsewhere:
* https://github.com/JuliusBrussee/caveman . Apparently has large savings for basically free. I find the idea of subagents speaking differently hilarious in abstract. Reading caveman speak from the Strategist would probably piss me off, and it would make figuring out why subagents behaved a specific way more difficult, but it's hard to argue with savings values this high. Maybe too good to be true?
* https://github.com/0ldh/claude-code-agents-orchestra . This seems mostly webapp oriented, but a similar tool would be nice even if it means leaving the Claude app entirely. Surely a Developer session fixing a single flag doesn't need Opus High-effort, right?
* https://github.com/obra/superpowers . This seems exactly like what I just spent the last two weeks building... oof. Well, is it any good? Worth stealing ideas from, or migrating to it entirely?
* https://github.com/TencentCloud/CubeSandbox . Apparently a much more efficient way to spin up VMs. That would make this more efficient, but I have absolutely no experience in this area so I don't know if it's necessary, desireable, or if it'd even help at all.

Do some research. If you find other repos I'm interested in hearing about them too. I'm also open to migrating to a 3rd party app instead of just the Claude app. My budget is $50/month, of which I'm only currently spending $20/mo on Claude Pro. If something would certainly and substantially improve the workflow, I'm willing to increase the budget to an absolute maximum $100/mo.

The following was written by Fable in a generic chat as an analysis of this document, including this segment (except this sentence obviously).

---

I've read through all four repos plus dug into some adjacent territory. Before going repo-by-repo, I need to lead with the finding that reframes everything else, because it affects how you should weigh each of these tools.

## The big one: your three roadblocks are artifacts of the tool, not the design

Your pipeline runs in the Claude app's sandbox, and every one of the Strategist's three walk-away blockers — no Godot execution, corrupt sandbox git, no session resumption — is a property of that sandbox, not of your protocol. **Claude Code**, which is already included in your $20 Pro plan, runs natively on your Windows machine with direct access to `E:\FoggyGlass`. That dissolves all three at once:

**Godot execution (your disqualifier):** Claude Code can just run the engine. Godot has first-class headless testing — gdUnit4 ships a command line tool for running tests outside the editor, with JUnit XML output for CI integration, and GUT works the same way (a headless import pass followed by a headless GUT run with `-gexit` so a single failing test fails the job). Your Developer writes a test, runs `godot --headless ... --run-tests`, reads the result, and fixes it in the same session. F-006 and F-011 — blind-authoring failures that cost you multiple full cold-start cycles — simply stop being a failure class. This also fixes strain #4: the Strategist stops absorbing QA work, because QA can actually execute. There are even ready-made pieces here: Randroids-Dojo's Godot-Claude-Skills is a Claude Code plugin with GdUnit4 integration and PlayGodot E2E automation, installable via the plugin marketplace.

**Git:** native git on your real filesystem. The `COMMIT_MSG.txt` / `commit.bat` dance and its clobbering problem disappear entirely. You can keep a human approval gate on *push* if you want the safety valve, but commits stop being your job.

**Cold starts and fragmentation:** Claude Code has the exact primitives your protocol is missing. Sessions resume (`--resume`/`--continue`), so an interrupted batch doesn't re-pay the binding read. `CLAUDE.md` is your binding read loaded automatically. And your roles map directly onto subagents: subagents are Markdown files with YAML frontmatter — each with its own system prompt, tool restrictions, and context window, so a Developer subagent returns only its summary to the orchestrating session instead of the whole conversation dying at a token ceiling.

Cost of this migration: $0. Usage across claude.ai, Claude Code, and Claude Desktop counts toward the same limit, so you're spending the same subscription either way — just far more efficiently, because resumption and subagent isolation attack cold-start × session-count structurally, which your Strategist correctly identified as the biggest unused lever.

Now the repos, evaluated against that backdrop.

## caveman — right instinct, wrong cost center (mostly)

It's real and the benchmarks are unusually honest — they compare against "Answer concisely" rather than verbose defaults, and the README explicitly admits "Caveman only affects output tokens — thinking/reasoning tokens untouched". So no, not a scam. But hold that admission against your own analysis: your Strategist's finding is that **cold-start reading (input) dominates cost, not output**. The headline 65–75% savings applies to the thing that was never your bottleneck.

The one piece that *does* target your bottleneck is the compress sub-skill: `caveman-compress` rewrites memory files like CLAUDE.md into compressed form, cutting ~46% of input tokens every session, with code/URLs/paths byte-preserved. Compressing your binding read (charter, tenets, protocol) would pay on every single role session. But I'd be cautious about applying it to your *artifacts*: in your system, the artifacts are the memory and the contract. A spec or AD written in telegraphic caveman-speak is a contract that's harder for you to audit and harder to adjudicate flags against — and your instinct that it would make subagent behavior harder to debug is correct, since ambiguity in a compressed contract becomes a new source of judgment calls. Verdict: steal `caveman-compress` for the fixed binding docs if you can tolerate reading them that way; skip output compression (wrong cost) and don't compress the specs/ADs/flags themselves.

## claude-code-agents-orchestra — skip the repo, steal the mechanism

The repo itself is thin — 68 stars, 14 commits, and 47 agents heavily skewed toward web apps, crypto, and CMS work you'll never touch. Your role definitions, honed over two weeks and validated across 29 judgment calls, are strictly better than its generic ones. But you spotted the genuinely valuable idea inside it: per-role model assignment. Its framework assigns Opus to strategic roles and Sonnet to implementation roles, and that's not a feature of this repo — it's a native Claude Code capability. The `model` field in subagent frontmatter accepts sonnet, opus, haiku, or a full model ID, and picking the right one is where most cost optimization happens. So yes: a Developer session fixing a single flag absolutely does not need the top model. Strategist/Architect on a strong model, Developer on Sonnet, and quick mechanical fixes or file-searching on Haiku. This is a second structural token lever on top of resumption, and it requires migrating to Claude Code — which you should do anyway.

## superpowers — your "oof" is only half-warranted

It's the heavyweight here: 243k stars, actively maintained, available through Anthropic's official Claude plugin marketplace. And yes, the overlap is real — brainstorming refines ideas into a saved design document, writing-plans breaks work into small tasks, then subagent-driven-development dispatches a fresh subagent per task with two-stage review (spec compliance, then code quality), often running autonomously for a couple of hours. That's your brief → spec → tickets → build → audit flow.

But here's the unbiased read: superpowers is a generic SDLC methodology. What it does *not* have is the part of your system that P0 proved actually works — the one-owner-per-artifact model, the flag ledger with owner-only resolution, the judgment-call log with Architect ratification, the milestone drift sweep that caught the vacuously-green test. Those are governance mechanisms, and they're your system's genuine contribution. Superpowers' equivalent (two-stage review per task) is per-task; it has nothing like your cumulative behavior-vs-charter sweep.

So: don't migrate wholesale, and don't feel bad about the two weeks — you built the layer superpowers lacks, and you now understand *why* each piece exists, which someone who installed a plugin never learns. The right move is to run your protocol on Claude Code and cherry-pick: their fresh-subagent-per-task dispatch is precisely the fix for your batch-fragmentation strain (each ticket gets a clean context, the orchestrator keeps the thread, no whole-batch death at a token ceiling), and their two-stage review pattern is worth comparing against your QA audit criteria. Install it, watch how it dispatches, and port the mechanics into your roles.

## CubeSandbox — wrong layer, skip it

This one I'll be blunt about, per your standing preference: it solves a problem you don't have. It's a KVM/RustVMM microVM service that creates hardware-isolated sandboxes in under 60ms with under 5MB memory overhead, targeting thousands of agents per machine, E2B-compatible, aimed at people *hosting fleets* of agent sandboxes — RL training runs, SaaS products running untrusted LLM code. Your costs are token costs (model inference), and VM spin-up speed has zero effect on those. Worse, it requires an x86_64 Linux environment with KVM support, so you'd be standing up WSL2 infrastructure to solve a sandbox problem that migrating to Claude Code eliminates outright — Claude Code doesn't sandbox you away from your machine; that's the whole point. Not necessary, not desirable, wouldn't help.

## The 500MB question: repo size ≠ context cost

Good instinct to worry about scaling, but the mechanics are more forgiving than you fear. Agents pay tokens for what they *read into context*, not for what exists on disk. 500MB of `.ogg` files will never enter a context window — no role has a reason to read them, and binary files can't be read as text anyway. The real (and much smaller) issues are:

1. **Git performance and backup bloat.** Solve with Git LFS for the asset directories, or simply `.gitignore` `game/assets/` and back assets up separately — they don't need code-style version history.
2. **Search noise.** Make sure roles' file searches exclude asset directories so a grep doesn't waste time trawling them. Claude Code respects ignore configuration for this.
3. **The actual scaling threat your Strategist already named:** the growing *binding read* (specs + decision record). That grows with tokens-read-per-session, which is the number that matters. The fix is active pruning plus moving reference material out of the always-loaded set — Claude Code's skills load on demand rather than every session, which is exactly the "keep the fixed read small" mechanism your protocol wants but the chat app can't give you.

## Budget

Don't spend anything yet. The migration is free, and it attacks all three roadblocks plus the model-tiering lever. The honest caveat: Pro's limits are a five-hour session limit plus a weekly cap across all models, shared across surfaces, and an autonomous build-verify loop burns tokens faster than chat sessions do — Anthropic pitches Pro as suited to "short coding sprints in small codebases". So after migrating, run a milestone and check Settings > Usage. If you're consistently hitting walls, your two options both fit your stated ceiling: usage credits let you continue past your plan's limits at pay-as-you-go rates (good if overruns are occasional — a $30/mo credit budget keeps you at $50 total), or Max 5x at $100/mo for 5× Pro's per-session usage if you're walled daily. Measure first; my guess is Pro + Sonnet-tier Developer subagents + resumption gets you further than Pro + your current architecture ever could, because you're currently paying the cold-start tax roughly ten times per milestone for nothing.

**Priority order, mapped to your Strategist's list:** migrate to Claude Code (fixes #2 git and enables everything), wire up GUT or gdUnit4 headless (fixes #3 Godot, the disqualifier), rebuild roles as subagents with per-role models and port `CLAUDE.md` from your binding docs (fixes #1 tokens). Your coordination protocol — the hard part — transfers intact; only the substrate changes.