# CreatorConnect — Handoff Brief #2

Read this whole document before doing anything. It has three parts: (A) the orchestrator
instructions you must follow, (B) full project context, (C) the product/design/marketing
refinement mandate you're being handed. Part C is the actual work order — A and B exist so you
can execute it correctly without re-deriving decisions that have already been made.

**This brief's objective is different from Handoff #1.** #1 was an engineering backlog (close
MVP gaps, ship tests). This one is a step *back* from code: assemble a product-owner + design +
marketing review of CreatorConnect as it stands today, and come back with concrete, opinionated
refinements to the offer, the experience, and the story — with an eye specifically on making the
product feel trustworthy, easy to use, and worth choosing over the status quo (DMs/email) or
incumbent tools (Grin, Aspire, Collabstr, CreatorIQ, #paid). Don't touch application code under
this brief unless a task explicitly says to — the deliverable is analysis, design direction, and
doc/copy changes, not features.

---

## Part A — Orchestrator instructions (Fable)

You are Fable, acting exclusively as an *orchestrator*. You never act as the primary agent that
performs tasks directly. Your job is to configure, direct, and evaluate subagents running on
Sonnet or Haiku (whichever version is currently available) — not to do the work yourself.

1. **Set up a subagent for every task that requires execution**, and explicitly choose which
   model runs it — Sonnet or Haiku (the current available version) — based on the task's
   complexity and required capability. State which model you chose and why before dispatching.
   Do not perform substantive work yourself.
2. **Define a clear, final goal for each subagent** before dispatching it. A general task
   description is not sufficient — provide an explicit, checkable criterion that defines when
   the result counts as achieved.
3. **Explicitly decide the context-sharing policy for each set of subagents**, and state that
   decision before dispatching them:
   - Fully isolated subagents (no context leakage between them), or
   - Deliberate, scoped context-sharing between specific subagents.
   Never leave this undecided or implicit — always declare which mode you're using and why.
4. **Run a review loop after each subagent response:**
   - Evaluate the response against the final goal defined in step 2.
   - If the result is unsatisfactory, send it back to the same subagent with an explicit,
     specific reason for rejection — never a vague "try again." The subagent must know exactly
     what to fix.
   - Repeat until the result meets the goal. Do not accept a first-pass result by default.
5. **Cap review loops at 5 iterations per subagent task.**
   - If the goal is met within 5 iterations, accept the result and proceed.
   - If not met after 5 iterations, stop the loop and escalate — report the unresolved gap
     between your expectations and the subagent's output rather than continuing indefinitely.
6. **Follow the Superpowers methodology** ([obra/superpowers](https://github.com/obra/superpowers))
   for structuring agentic workflows. In particular, apply the `subagent-driven-development`
   skill: dispatch a fresh subagent per task, and review each result in two stages — first spec
   compliance, then quality — before accepting it.

**Constraints:**
- Never let a subagent operate as the primary decision-maker on whether its own output is
  acceptable — that authority always belongs to you, the orchestrator.
- Never dispatch a subagent without a stated final goal and a stated context-sharing decision.
- Never dispatch a subagent without explicitly stating which model it runs on and the reasoning.
- Never exceed 5 review iterations per task without escalating.

**Adaptation for this brief:** in Handoff #1 every subagent role is engineering. Here, most
subagents are dispatched *as a persona* — e.g. "acting as a senior product owner," "acting as a
UX/design lead," "acting as a growth/positioning marketer." State the persona explicitly in the
dispatch prompt, same as you'd state the model and the goal — a subagent told to "review the
product" without a persona and a lens will produce generic output. Give each persona subagent the
relevant parts of Part B as grounding context, not the whole codebase — these are strategy/design
tasks, not implementation tasks, so context-sharing should be scoped to docs and screenshots/UI
copy, not source files, unless a task specifically needs to inspect a component's markup.

**Success criteria:** a task is complete when the orchestrator has confirmed, against the
originally stated goal, that the subagent's output meets it — not merely when a subagent has
produced a response.

---

## Part B — Project context

### What this is

CreatorConnect is a booking/reservation marketplace connecting brand advertisers with mid-tier
creators (50K–1M followers) for sponsorship slots — positioned as "Booking.com for sponsorship
slots," not an auction. Solo-founder project. Currently pre-launch: no real users, no real money
moved yet (Stripe is stubbed/simulated throughout, deliberately deferred). The engineering side of
the MVP (three pricing mechanisms, manager delegation, delivery/dispute flow, dark-theme UI,
passkey auth) is largely built — see Handoff #1 for the engineering-side state in detail if
relevant, but this brief is not about closing engineering gaps.

Working directory: `/Users/joaoduro/Desktop/exploration/creator-connect`. Git repo, `main`
branch, 15 commits, 11 ahead of `origin/main` (never pushed).

### Foundational docs — read these first, in order

1. [`docs/RESEARCH_BRIEF.md`](../docs/RESEARCH_BRIEF.md) — the original market research:
   competitive landscape (Collabstr, Intellifluence, Grin, Aspire, Popular Pays, CreatorIQ/Fohr,
   #paid's Creator Calendar, Agentio), the CFTC/"NASDAQ of content" naming-risk finding, and the
   evidence base for why an open ascending-bid auction (mechanism B) doesn't work for creator
   content. This is the primary source a marketing/positioning subagent should be grounded in.
2. [`docs/PRODUCT.md`](../docs/PRODUCT.md) — product vision, personas (creator/advertiser/
   manager), the three pricing mechanisms (A/C/D), MVP scope, and — most relevant to this brief —
   **Section 7's open questions**, two resolved via real Phase 0 founder-conducted interviews,
   four still open. Read the revision log at the top; note how prior revisions were done (strike
   through superseded text, don't delete it, log why at the top) — preserve that pattern if a task
   in Part C asks you to revise this doc again.
3. [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) — mostly not relevant to this brief (it's
   schema/RLS/RPC design), but Section 8's numbered risks are worth a glance for a product
   subagent, since a few are product-shaped, not just technical (e.g. the delegation-surface risk
   has a real UX-explainer dimension per PRODUCT.md §7 Q5's finding).
4. [`docs/ROADMAP.md`](../docs/ROADMAP.md) — sequencing document, useful mainly for the
   kill-switch signals in §6 (what would indicate the mechanism isn't working) and the "tension
   flagged between the two source documents" section at the bottom, which is a good example of
   this project's habit of naming its own open risks explicitly rather than smoothing them over —
   match that tone in any new analysis you produce.

### The three pricing mechanisms (the product's central and riskiest bet)

Creators choose one of three mechanisms **per listing** at creation time:
- **Mechanism A** — fixed asking price + sequential counter-offer (classifieds-style, simplest).
- **Mechanism C** — reserve-the-relationship: advertiser gets an exclusivity window, no deposit,
  bilateral negotiation once a deal is in motion.
- **Mechanism D** — reserve-the-slot: non-refundable deposit locks the slot, creator confirms
  price within a response window; richest mechanism, closest to the original pitch.

**The single most important open product question, per `PRODUCT.md` §7 Q6, and the one this brief
should treat as a first-class design problem, not a footnote:** offering three mechanisms was
added because creators asked for choice, but the founder's own original analysis (before that
interview finding) warned that three different transaction models fragments advertiser discovery
— an advertiser browsing has to learn and compare three different commitment types listing-by-
listing. That tradeoff was *accepted*, not resolved. Nothing in the current build mitigates it
beyond a per-listing label. This is a real opening for a design/product subagent: can the browse
UI, the mechanism-selection copy, or the overall narrative reduce the cognitive cost of three
mechanisms without taking the choice away from creators?

### What exists today that a design/marketing review can actually look at

- **Landing page** (`src/routes/+page.svelte`) — the current pitch, above-the-fold framing, CTA.
- **Public roadmap page** (`src/routes/roadmap/+page.svelte`) — unusual choice to expose the
  roadmap publicly; worth a marketing opinion on whether that's a trust-building signal (radical
  transparency) or a liability (shows unfinished parts to prospective users).
- **The pricing-mechanism explainer copy at listing creation** (`PRODUCT.md` Flow 1 step 2 calls
  this out as necessary "since interviews showed the underlying concepts... aren't self-evident
  without explanation" — worth checking whether the shipped copy actually clears that bar).
- **`src/routes/create/`** — listing creation flow, including the mechanism picker.
- **`src/routes/listings/[id]/`** — the main transaction surface, all three mechanisms' UI live
  here.
- **`src/routes/browse/`** — discovery/filtering, currently platform + mechanism dropdowns only,
  no text search (an engineering gap tracked in Handoff #1, but also worth a UX opinion on whether
  filters alone are the right discovery model for a catalog this size).
- Dark theme design system (`src/lib/app.css`), inspired by the Supabase dashboard — a founder
  aesthetic choice made by direct request, not derived from user research; worth a design opinion
  on whether a developer-tool-coded aesthetic is right for creators/marketers (likely a different
  taste culture than Supabase's own developer audience).

A design/UX subagent should use the preview tool to actually load these pages and interact with
them — do not review copy/layout from source code alone when a live rendering is available and
cheap to check.

### Session conventions worth preserving

- The founder tests changes himself; don't commit speculatively — commit only when explicitly
  asked.
- `docs/*.md` revisions use strikethrough for superseded text plus a revision-log paragraph at the
  top, never silent deletion — preserve this if you revise PRODUCT.md/ROADMAP.md.
- Use `.claude/launch.json`'s `creator-connect-dev` config (port 5173) via the preview tool for
  any live UI review — don't start a second ad hoc dev server.

---

## Part C — Refinement mandate

This is not a numbered engineering backlog — it's four review lenses, each run by a differently-
postured subagent, followed by a synthesis pass. Run them in the order below; later lenses benefit
from earlier ones' output (see context-sharing note per lens).

### 1. Product ownership review — is the offer itself right?

Dispatch a subagent **acting as a senior product owner/PM** with a founder's-critical-friend
posture (not a cheerleader). Ground it in `PRODUCT.md` and `RESEARCH_BRIEF.md` in full. Ask it to:
- Stress-test the three-mechanism decision specifically — is offering creator choice (A/C/D) the
  right call, or does §7 Q6's fragmentation risk outweigh it? Give a real recommendation, not a
  "both sides have merit" hedge — pick a side and justify it against the research, or propose a
  concrete mitigation (e.g., default recommendation logic, a smarter browse grouping) rather than
  leaving it as an accepted tradeoff.
- Evaluate the fee structure (15% platform + 5% manager surcharge) and the 4-8 week booking
  horizon against what's now known from Phase 0 interviews and the competitive set in
  `RESEARCH_BRIEF.md` — still right, or is there a reason (from the research, not invented) to
  revisit either number pre-launch.
- Identify the single biggest unaddressed product risk to a successful pilot launch that isn't
  already named in `PRODUCT.md` §7 or `ROADMAP.md` §6 — must be grounded in something in the docs
  or the live product, not speculative.

**Context-sharing:** isolated from the design and marketing subagents below — this should be an
independent product read, not anchored to their framing. **Model: Sonnet** — this requires
synthesizing three docs and forming a defensible, specific recommendation, not a mechanical task.
**Done when:** the subagent returns a written product review with (a) an explicit position on the
Q6 fragmentation question, (b) a fee/horizon verdict, and (c) one newly-identified risk — each
with a one-paragraph justification tracing back to a specific finding in the docs or the product.

### 2. Design/UX review — is the product easy and trustworthy to use?

Dispatch a subagent **acting as a UX/design lead**, using the preview tool to actually walk the
live product end-to-end as a first-time creator (through listing creation) and as a first-time
advertiser (through browse → a mechanism's negotiation flow). Ground it in Section "What exists
today" above plus a live look at the pages listed there. Ask it to:
- Rate the mechanism-selection explainer copy in the create flow against the bar `PRODUCT.md`
  itself sets ("aren't self-evident without explanation") — does it actually explain, or just
  label?
- Assess whether the dark, developer-tool-inspired aesthetic serves this audience (creators,
  brand marketers, talent managers) or works against approachability — an honest opinion, not a
  validation of the founder's existing choice.
- Identify the top 3 friction points in the two walkthroughs above (creator listing creation;
  advertiser browse-to-negotiation) — must be things actually observed in the live preview, not
  guessed from reading source.
- Propose specific, scoped fixes for each friction point (copy change, layout change, or new
  affordance) — concrete enough that a follow-up engineering task could implement them directly.

**Context-sharing:** deliberately given the product-review subagent's output from lens 1 as input
context — the fragmentation-risk verdict from lens 1 should inform how this subagent evaluates
browse/discovery UX specifically. **Model: Sonnet** — requires live tool use (preview/screenshot)
plus qualitative judgment. **Done when:** the subagent returns a walkthrough writeup with
screenshots/observations from the live preview (not just code reading), the explainer-copy
verdict, the aesthetic opinion, and 3 friction points each with a scoped proposed fix.

### 3. Marketing/positioning review — is the story compelling and differentiated?

Dispatch a subagent **acting as a marketing/growth lead** for an early-stage B2B2C marketplace.
Ground it fully in `RESEARCH_BRIEF.md` (the competitive set and the naming-risk finding) and
`PRODUCT.md` Section 1 (the "Booking.com not NASDAQ" repositioning decision). Ask it to:
- Evaluate the current landing page copy/framing against the "Booking.com for sponsorship slots"
  positioning `PRODUCT.md` commits to — does the live landing page actually deliver that framing,
  or has it drifted (check the live page, don't assume from the doc)?
- Give an honest opinion on exposing the public roadmap page — trust signal or liability — with a
  recommendation, not just a list of pros/cons.
- Propose concrete messaging/positioning for the pilot-cohort launch specifically (5-8 warm
  creators + 1-2 managers per `ROADMAP.md` §2.3) — this is a recruiting/warm-outreach moment, not
  a mass-market launch, so generic marketing-funnel advice is out of scope; focus on what actually
  convinces a specific warm creator who already said yes in an interview to follow through and
  publish a real listing.
- Name the single most differentiated, defensible claim CreatorConnect can make against the
  competitive set in `RESEARCH_BRIEF.md` (Collabstr/Intellifluence/Grin/Aspire/CreatorIQ/#paid) —
  must be something the product actually does today, not aspirational.

**Context-sharing:** isolated from lenses 1 and 2 — positioning should be evaluated fresh against
the research, not pre-anchored by the product/design subagents' framing, so a genuinely
independent read surfaces disagreement if it exists (disagreement between lenses is useful
signal, not noise — surface it in synthesis, don't average it away). **Model: Sonnet.**
**Done when:** the subagent returns a positioning review with a landing-page verdict, a
roadmap-page recommendation, concrete pilot-launch messaging, and one named differentiated claim.

### 4. Research validation pass — what can actually be answered before more usage data exists?

Dispatch a subagent **acting as the same research analyst who wrote `RESEARCH_BRIEF.md`**, tasked
with revisiting `PRODUCT.md` §7's four still-open questions (Q2 deposit %/response window, Q3
manual-entry staleness tolerance, Q4 dispute volume/shape, Q6 fragmentation — Q6 also covered by
lens 1, so this subagent should focus on Q2-Q4). For each: confirm whether it genuinely requires
real usage data (as the doc currently claims) or whether there's now available competitive/market
evidence (pricing pages, published case studies, public docs from Collabstr/Grin/Aspire/etc.) that
narrows the placeholder numbers (10% deposit, 24-48h window, 5-day auto-release) before the pilot
launches, rather than guessing blind on day one.

**Context-sharing:** isolated — this is a research task, not a synthesis of the other three
lenses. **Model: Haiku** is acceptable here if the task is scoped to "check whether public
competitor pricing/docs narrow these three placeholder numbers" — it's closer to a lookup/summarize
task than a judgment call; escalate to Sonnet only if the subagent's first pass shows it's
struggling to find or interpret real evidence. **Done when:** the subagent returns, for each of
Q2/Q3/Q4, either (a) a narrowed recommendation with a cited source, or (b) an explicit confirmation
that no pre-launch evidence exists and real usage data is genuinely required — not a vague "hard to
say."

### 5. Synthesis — reconcile into one set of recommendations

After lenses 1-4 complete, **you (the orchestrator) synthesize directly — do not dispatch a fifth
subagent for this.** Produce a single prioritized recommendation set that:
- Resolves or explicitly flags any disagreement between the four lenses (e.g., if design likes the
  dark theme but marketing worries it hurts approachability, say so — don't silently pick one).
- Separates recommendations into "safe to act on now" (doc/copy changes, no engineering) vs.
  "needs a scoped engineering task" (hand off to a fresh Handoff-#1-style brief) vs. "needs real
  pilot usage data first, park it."
- Proposes specific edits to `PRODUCT.md`, the landing page copy, and the create-flow explainer
  copy where the lenses converge on a clear improvement — write these as ready-to-apply diffs or
  near-final copy, not vague direction, so the founder can approve/reject quickly rather than
  having to write the copy himself.

**Done when:** the founder has a single document (or chat response) that states, per
recommendation: what it is, which lens(es) support it, and which of the three buckets above it
falls into.

---

*Prepared by the orchestrating session on 2026-07-02, as a companion to Handoff #1 (engineering).
Run this brief's product/design/marketing review independently of #1's engineering work — they
don't block each other, but synthesis-stage recommendations here may generate new engineering
tasks that should become their own Handoff #3, not get silently folded into #1's existing backlog.*
