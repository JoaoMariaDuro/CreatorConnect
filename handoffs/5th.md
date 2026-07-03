# CreatorConnect — Handoff Brief #5 (Vision Expansion: Professional Tool + Vertical Network)

Read this whole document before doing anything. Unlike Handoffs #1-#4, this is **not an
execution-ready backlog**. The founder's own framing for this pass was "let's plan and design next
features" — this document is a synthesis of exploratory strategy work, meant to be scoped further
(and, for the biggest items, explicitly approved by the founder) before engineering starts. Some
items here are cheap and safe enough that a future session could reasonably just build them; others
are genuine product-direction forks that need a founder decision first. Each item below says which.

---

## Part A — Orchestrator instructions (Fable)

If you are picking this up as an orchestrator (the same role used throughout Handoffs #2-#4): you
are Fable, acting exclusively as an orchestrator. You never act as the primary agent that performs
tasks directly. Configure, direct, and evaluate subagents running on Sonnet or Haiku — not do the
work yourself.

1. **Set up a subagent for every task that requires execution**, explicitly choosing which model
   runs it and stating why, before dispatching.
2. **Define an explicit, checkable "done when" criterion** for every subagent — not a general task
   description.
3. **Explicitly decide and state the context-sharing policy** for each set of subagents (fully
   isolated vs. deliberate scoped sharing) before dispatching.
4. **Run a two-stage review after each subagent response** (spec compliance, then quality) —
   evaluate against the stated goal yourself; don't accept a first-pass result by default. If
   unsatisfactory, send back with a specific, cited reason.
5. **Cap review loops at 5 iterations per task**; escalate rather than loop indefinitely.
6. **Verify UI-affecting changes live** using this project's preview tooling (`.claude/launch.json`'s
   `creator-connect-dev` config, port 5173) — don't just trust a subagent's self-report; independently
   re-check its diff and, for anything visual, the live render. This project's own history has one
   concrete lesson here: a design review pass in an earlier handoff caught a real bug (inverted
   turn-taking logic in a dashboard query) specifically by diffing a subagent's output against an
   already-shipped reference pattern rather than trusting its self-report — do the same.
7. **This project's environment has a real, recurring constraint**: no live authenticated testing was
   possible for most of Handoffs #3-#4's work because no test credentials existed. That's now fixed —
   `scripts/seed-test-users.mjs` + `supabase/seed-data.sql` (see Part B) create 6 real test accounts
   with usable sign-in links. Use them for anything that needs a real authenticated session; don't
   assume the old "no credentials available" constraint still applies without checking first.

**Adaptation for this brief specifically:** several items below (marked "OPEN QUESTION" or "needs
founder decision") should not be scoped into engineering tasks without first asking the founder
directly — this mirrors how Handoff #3 handled the admin-dispute-surface timing question (asked via
an explicit multiple-choice question before building) and how Handoff #4 flagged, rather than
silently decided, the deferred admin-surface question. Don't default to building the ambitious
version of anything marked this way just because it's interesting — ask first.

---

## Part B — Project context (condensed; read the source docs for full depth)

### What this is, as of this document

CreatorConnect is a booking/reservation marketplace connecting brand advertisers with mid-tier
creators (50K-1M followers) for sponsorship slots, three pricing mechanisms per listing (A: fixed
price + counter-offer; C: reserve-the-relationship/exclusivity; D: reserve-the-slot/deposit).
Solo-founder, pre-launch, targeting a 5-8 warm creator pilot cohort (`docs/ROADMAP.md` §2.3).
Working directory: `/Users/joaoduro/Desktop/exploration/creator-connect`. Git repo, `main` branch.

**What's fully built and shipped as of this document** (don't re-propose any of this):
- The full transactional core: listing creation/browse/negotiation across all three mechanisms,
  manager delegation with band-based auto-accept authority, delivery/dispute flagging, mobile-
  responsive layout, a segmented mechanism filter on `/browse`.
- A minimal reputation signal (`profiles.completed_deals_count`), a manual performance-stats
  entry/display UI with a staleness badge (`performance_stats_updated_at`, soft warning at 60-179
  days, hard flag at 180+).
- A full Founder/Admin surface: `profiles.is_platform_admin`, `/admin/disputes` (queue +
  detail/resolution via `resolve_dispute_as_admin`), gated by real RLS (not just UI hiding).
- An admin test-role switcher (`/settings`, `set_own_test_role_as_admin` RPC) so one founder account
  can exercise all three role-differentiated UIs.
- A persistent top bar (logo, route breadcrumb, Help→`/roadmap`, a Feedback modal writing to a new
  `feedback` table) and a collapsed-by-default, hover-to-expand icon-rail sidebar (matching a
  Supabase-dashboard-style nav pattern), both verified working together and with the pre-existing
  mobile stacked-sidebar layout.
- Test-data infrastructure: `scripts/seed-test-users.mjs` (Node, run locally with the founder's own
  service-role key — never shared with any agent — creates 6 confirmed test accounts across all
  three roles and prints usable sign-in links) + `supabase/seed-data.sql` (populates a full coverage
  matrix: every mechanism in fresh/in-progress states, every staleness tier, every deal status
  including a disputed one, both manager band fallback paths).
- **A real RLS security fix**: `profiles`' "update own profile" policy previously only checked row
  ownership, not which columns changed — any signed-in user could have granted themselves
  `is_platform_admin` directly. Fixed; `role`/`is_platform_admin` can now only change via narrow,
  gated RPCs.

**Full detail and reasoning for all of the above**: `handoffs/3rd.md`'s Completion Log (the single
source of truth for what shipped and why, across the whole engineering arc from Handoff #3 onward).

**What's proposed but NOT yet built**: `handoffs/4th.md`'s full task list — a founder-facing
`/admin/signals` page (three lenses independently converged on this as the top priority: product,
analytics, and design all proposed it from different angles), an `/admin` landing page, a
reputation-signal zero-state fix, a first-run dashboard onboarding panel, a `dispute_cause` field,
a public creator media-kit page (`/c/[handle]`), a `fee_feedback` prompt, and a minor landing-page
copy nit. None of this is built yet — check `handoffs/4th.md` before re-proposing any of it.

### Foundational docs, read in this order for anything in this brief

1. `docs/PRODUCT.md` — vision, personas, the three mechanisms, Section 7's open questions (read the
   revision log at the top in full — narrowed/resolved questions are marked, don't re-litigate them).
2. `docs/ROLE_ACCESS_AND_UX_SPEC.md` — the verified-against-code access matrix and UI/UX spec per
   role, now fully reflecting the shipped Founder/Admin surface.
3. `docs/ARCHITECTURE.md` — schema/RLS/RPC design; Section 8's numbered risks.
4. `docs/ROADMAP.md` — sequencing, kill-switch signals (§6), pilot-cohort design (§2.3).
5. `handoffs/2nd.md`, `handoffs/3rd.md`, `handoffs/4th.md` — prior review/build history, in order.

### Session conventions worth preserving

- The founder tests changes himself; commit only when explicitly asked (though recent sessions have
  committed proactively after explicit "continue"/"fix it" instructions — read the room).
- `docs/*.md` revisions use strikethrough for superseded text plus a revision-log paragraph at the
  top, never silent deletion.
- Every shipped piece of work gets documented back into a handoff's Completion Log (or, for a new
  handoff, its own document) — this was itself a corrective finding in Handoff #3: a much earlier
  marketing-lens review's output was apparently never captured anywhere and had to be redone from
  scratch a full engineering cycle later. Don't let that happen to this brief's findings either.
- Verify UI changes live before marking anything done; this environment's viewport-resize presets
  have been observed to resolve narrower than their labels suggest (a "desktop" preset once resolved
  to 549px) — always confirm actual `window.innerWidth` via `preview_eval` rather than trusting a
  preset name, especially for anything breakpoint-sensitive.

---

## Part C — The vision expansion and its findings

### The founder's framing for this pass

Two explicit ideas, given directly by the founder, that should shape how the rest of this document
is read:

1. **"Not only a marketplace, but the tool used by professionals for everything of their work, and
   connection to their needs."** I.e., stop thinking of creators/advertisers/managers as parties to
   individual transactions, and start thinking of them as professionals running an ongoing business
   (content + sponsorship, for a creator; a creator-marketing program, for an advertiser; a
   multi-client roster, for a manager) that this platform could plausibly become the daily tool for
   — not by replacing every tool they use, but by owning the parts that only this platform has the
   data to do well, and integrating outward to other tools where that makes more sense than rebuilding
   them.

2. **OPEN QUESTION, not yet scoped — needs founder input before any engineering starts on it:**
   *"This is kind of a social media, like Facebook, but specific for entertainers and professionals
   of this world, where they can perform as much of their job as possible here, and integrate with
   outside tools when needed and possible."* This is a genuine product-direction fork, not a feature
   request, and this document deliberately does NOT resolve it — it's flagged here so the next
   session treats it as a real strategic question, not background color. Before anyone scopes
   engineering work against this framing, the founder should clarify (a future session should ask
   directly, the way Handoff #3 asked about the admin-surface timing decision):
   - Does "social media, like Facebook" mean literal social-network mechanics (a feed of activity,
     posts, connections/follows between professionals, public profiles beyond the existing
     creator-media-kit-page proposal in Handoff #4), or is it a looser metaphor for "a professional
     home base with real identity and presence," closer to what LinkedIn is to white-collar
     professionals than what Facebook is to consumers?
   - Is the goal a closed professional network scoped to CreatorConnect's own three roles (creators,
     advertisers, managers see and interact with each other's real activity/presence on the
     platform), or something with any public/external-facing component?
   - Given this pilot is 5-8 creators total, is there enough density for network effects (feeds,
     connections, discovery) to mean anything yet, or is this explicitly a post-pilot bet the platform
     should architect toward without building the social layer itself now?
   None of the three persona-lens reviews below were asked this question directly (they ran before
   the founder introduced this framing) — treat their findings as the "professional tool" half of the
   vision, fully explored, and treat the "vertical network" half as genuinely open and requiring a
   dedicated follow-up scoping pass once the founder has answered the questions above.

### Method for this pass

Three subagents, each acting as a working professional in one role (Creator, Advertiser, Manager),
run **fully isolated from each other** (deliberately — the goal was to see whether each role's real
needs converge or diverge on their own, not to have one lens anchor the others), each grounded in
`docs/PRODUCT.md`, `docs/ROLE_ACCESS_AND_UX_SPEC.md`, `handoffs/4th.md`, and the live schema, asked
to think expansively about calendar integration, own-business analytics, and workflow tools each
persona would need to run their actual job through this platform — not just transact on it. Model:
Sonnet for all three (open-ended product judgment, not a lookup task). Synthesis below is the
orchestrator's own work, not a fourth subagent, matching the established pattern from Handoff #4.

### Convergent findings — all three lenses independently agreed on these

**1. Build an internal-only calendar/pipeline view per role; explicitly do NOT build real two-way
external calendar sync (Google/Outlook) in this phase, for any role.** All three lenses landed on
this independently, for the same underlying reason: every "event" this platform would show on a
calendar (a listing's availability window, a reservation's confirmation deadline, a deal's delivery
due date, an exclusivity grant's expiry) already exists as a timestamp/window on a table the schema
already has — `creator_listings.availability_window`, `reservations.confirmation_deadline`,
`deals.delivery_due_at`/`delivery_date`, `listing_exclusivity_grants.window_ends_at`. Building the
internal view is a **read-only rendering problem over existing data**, not a new capture problem —
cheap, safe, no new schema. External two-way sync, by contrast, is real integration infrastructure
(OAuth, webhook/token refresh, conflict resolution when an external edit disagrees with the
platform's own state) disproportionate to this pilot's scale (5-8 creators, correspondingly few
advertisers, 1-2 real managers), and — more importantly, per the creator lens's specific argument —
possibly not the right shape even later: these are contract milestones the platform is the source of
truth for, not freely-reschedulable appointments, which is a different problem than what calendar
sync tools are built to solve. **The manager lens specifically argues its persona has the strongest
calendar case of the three** (a manager's native problem is literally "many people's commitments
overlaid in one time-based view," which a list serves far less naturally than it does for a creator
or advertiser) — if calendar gets built for only one role first, build it there.

**2. Each role's single biggest missing capability is a read-only aggregation/rollup dashboard over
data that already exists — not a new capture mechanism.** Independently, for all three:
- **Creator**: a unified "what's on my plate" view — every open response-clock (D reservation, A
  counter-thread, C exclusivity window) plus every confirmed delivery obligation, sorted by urgency,
  in one place, instead of scattered across per-deal pages. Prevents a real, named correctness risk
  today: a creator can confirm a new deal's delivery date with zero visibility into whether it
  collides with an already-confirmed delivery elsewhere.
- **Advertiser**: the same "biggest gap" analysis lands on a genuinely new concept — a `campaigns`
  object grouping multiple deals across multiple creators under one time-boxed, named effort — but
  the lens explicitly recommends **holding that specific piece** until real usage shows an advertiser
  actually juggling a multi-creator slate; ship the cheap, ungrouped rollups (pipeline calendar,
  spend report, repeat-booking history) first, since none of them require the grouping concept to be
  valuable standalone.
- **Manager**: a roster-wide pipeline/CRM dashboard — the same cross-mechanism "needs attention"
  query pattern the creator/advertiser dashboards already have, fanned out across every linked
  creator instead of scoped to one, plus per-creator activity rollups and (see below) commission
  visibility. Flagged as the single cheapest-relative-to-value item across all three lenses' entire
  output, because every piece of it reuses an already-shipped query pattern with zero new schema.

**3. Own-business analytics, not reputation/trust analytics — and the same "stat cards, not charts,
small-sample caveats" discipline from Handoff #4 applies identically here.** All three lenses
proposed metrics scoped to "how is MY business doing" (income booked vs. pipeline, what actually
clears vs. what was asked, per-mechanism personal conversion, repeat-relationship rate, response
time) rather than the trust-signal metrics already built (`completed_deals_count`,
`performance_stats`). All three explicitly warned against building anything that presents a
confident-looking verdict on a tiny sample — the advertiser lens named this most sharply, explicitly
recommending against a "mechanism performance comparison" feature because it would repeat, one level
up the stack, the exact mistake Handoff #4's design lens already caught and corrected once (the
reputation-signal percentage-vs-raw-count decision).

**4. All three lenses practiced real scope discipline — each named something to explicitly NOT
build yet, unprompted beyond the review's own instructions to do so:**
- Creator: no task/subtask decomposition or reminders — that requires new creator-authored input
  (not aggregation of data that already exists), and nothing in any prior interview/review pass has
  signaled creators want it.
- Advertiser: hold the `campaigns` object until real usage justifies the grouping concept; explicitly
  cut ROI/mechanism-comparison analytics as premature given small-sample risk.
- Manager: no bulk/batch tooling across the roster (`PRODUCT.md` §6 already deferred this explicitly
  as v1 non-goal) and no two-way calendar sync.

### The one concrete, verified, cite-a-line-number finding

**`manager_creator_links.commission_bps` (`supabase/delegation.sql:19`, default 500 = 5%) exists in
the schema, is populated in seed data, and is never selected, read, or rendered anywhere in
`src/`** — independently confirmed via `grep -rn "commission" src/` returning zero hits, both by the
manager-lens subagent and re-verified directly by the orchestrator before writing this document.
`escrow_transactions.kind` (`supabase/deals.sql:70`) even has a `'payout_manager_commission'` enum
value with no code path that ever inserts it — real design intent (`PRODUCT.md` §3 explicitly
promises "commission is calculated and split automatically... the manager never needs to invoice or
chase the creator for it"), zero implementation. This is the single most concrete, lowest-ambiguity
finding in this whole document: a manager's core business incentive currently has no visibility
anywhere in the product, despite the schema already supporting it.

**This splits into two pieces with very different costs — don't conflate them:**
1. **Display-only commission surfacing** (cheap, buildable now, zero Stripe dependency): for
   confirmed/completed deals, `commission_bps × deal price` is pure arithmetic against data that
   already exists. A "Commission earned/pending" card, reusing the exact read-only aggregation
   pattern already validated for `handoffs/4th.md`'s proposed `/admin/signals` page.
2. **Actual automated payout splitting** (the full `PRODUCT.md` §3 promise) is real work gated
   entirely behind Stripe Connect going live (currently stubbed per `supabase/README.md`) — naturally
   sequenced after that infrastructure exists, not a separate priority decision to make now.

---

## Part D — Prioritized backlog for a future engineering session

Bucketed by the same three-way split Handoff #4 used: safe to scope/build directly, needs a founder
decision first, and hold until real usage justifies it.

### Ready to scope directly (cheap, no new schema beyond what's noted, no founder decision needed)

1. **Manager roster-wide pipeline dashboard** (Part C's manager finding) — extend
   `src/routes/dashboard/+page.server.ts`'s manager branch with the same cross-mechanism "needs
   attention" query the creator/advertiser branches already have, fanned out across `creatorIds`;
   add per-creator activity rollup cards. Cheapest-relative-to-value item in this whole document.
2. **Commission display card** (Part C's verified finding) — a read-only `commission_bps × deal
   price` rollup on the manager dashboard. No schema change, no Stripe dependency. Pair with task 1
   — same page, same session.
3. **Per-role internal calendar/pipeline view** — start with the manager's roster-wide version (the
   strongest case per the convergent finding above), reusing existing timestamp/window columns
   across `creator_listings`, `reservations`, `deals`, `listing_exclusivity_grants`. Creator and
   advertiser versions of the same pattern (scoped to `creator_id`/`advertiser_id` instead of a
   roster) are natural, cheap follow-ons once the query shape is proven once.
4. **Creator "what's on my plate" unified dashboard view** (Part C's creator finding) — same query
   pattern as tasks 1/3, scoped to the creator's own `creator_id`.
5. **Own-business analytics cards, per role** (Part C, convergent finding 3) — income booked vs.
   pipeline, per-mechanism personal conversion/clearing rate, repeat-relationship rate, response
   time. Build using the stat-card/small-sample-caveat pattern already established in
   `handoffs/4th.md`; do not build charts or trend lines at this data volume.
6. **Advertiser ungrouped rollups**: internal pipeline calendar (folds into task 3's pattern), spend
   report for internal reporting, repeat-booking/creator-history view. All read-only, no new schema.

### Needs a founder decision before scoping (genuine forks, ask directly, don't default)

7. **The vertical-network / "social media for this industry" framing** (Part C's open question) —
   needs the founder's answers to the three bullet questions listed there before any engineering
   scoping starts. Treat as its own dedicated exploration pass once answered, not folded into the
   items above.
8. **The advertiser `campaigns` object** (multi-creator, multi-deal grouping) — the lens that
   proposed it also recommended holding it until a real advertiser is visibly improvising their own
   tracking for a multi-creator slate. Don't build ahead of that signal; check for it directly (ask
   the founder, or look for the pattern in real pilot usage once seed/test data is replaced by real
   usage) before scoping.
9. **Automated commission payout splitting** (the full Stripe-dependent half of the commission
   finding) — sequenced after Stripe Connect integration goes live (`docs/ROADMAP.md` Phase 0 items
   0.4/0.5), not an independent priority decision.
10. **A light ICS export/subscribe feed** (one-way, read-only calendar subscription URL, no OAuth,
    no two-way sync) — the creator lens proposed this as a plausible lighter alternative to full
    external sync, explicitly as a "maybe later, not now" rather than a near-term item. Worth a
    founder gut-check on whether it's worth the (still real, if much smaller) engineering cost before
    scoping, given the same "contract milestones aren't reschedulable appointments" argument that
    killed full two-way sync also somewhat applies here, just less severely.

### Hold — explicitly not ready, don't build without a direct founder ask overriding this

- Real two-way external calendar sync, any role (all three lenses independently rejected this).
- Creator task/subtask decomposition, reminders, or any creator-authored planning input beyond what
  already exists.
- Manager bulk/batch tooling across the roster (`PRODUCT.md` §6's existing explicit deferral stands).
- Advertiser ROI / cost-per-mechanism comparative analytics (small-sample risk, explicitly argued
  against).
- Everything already listed as out-of-scope in `handoffs/3rd.md`/`handoffs/4th.md`: Stripe Connect
  itself, the sealed-bid tiebreaker, `ROADMAP.md` Phase 3, defaulting Mechanism D, a full
  review/rating system.

---

*Prepared by the orchestrating session on 2026-07-03, synthesizing three isolated persona-lens
reviews (Creator, Advertiser, Manager) commissioned after the founder proposed expanding the
product's scope from "marketplace" to "the tool professionals use for their whole job," plus a
verified schema-vs-code finding (manager commission has zero UI visibility despite existing schema
support). Explicitly NOT an execution-ready backlog in the way Handoffs #1/#3 were — Part D's first
bucket is scopable directly, but the founder should read Part C's open question before anyone builds
toward it, and should confirm intent on Part D's second bucket before those items become tasks.*
