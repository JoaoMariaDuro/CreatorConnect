# CreatorConnect — Handoff Brief #3

Read this whole document before touching code. It has three parts: (A) the orchestrator
instructions you must follow, (B) full project context, (C) the prioritized task backlog you're
being handed. Part C is the actual work order — A and B exist so you can execute it correctly
without re-deriving decisions that have already been made.

**This brief's objective is different from #1 and #2.** #1 was the original engineering backlog
(close MVP gaps, ship tests). #2 was a step back from code: a product/design/marketing review that
produced doc/copy changes and a set of concrete, scoped engineering findings it deliberately did
NOT implement (per its own instruction not to touch application code). A follow-on pass mapped
every role's feature access and UI/UX in full and found several more concrete gaps. **This brief
is the engineering backlog those two passes produced — build the code now.**

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

**Adaptation for this brief:** every task in Part C is an implementation task, same as Handoff #1
— dispatch engineering-focused subagents (not personas), give each one the specific files it
needs (not the whole codebase blind), and verify UI-affecting changes against the live preview
per this project's own session conventions, not just against passing type-checks.

---

## Part B — Project context

### What this is

CreatorConnect is a booking/reservation marketplace connecting brand advertisers with mid-tier
creators (50K–1M followers) for sponsorship slots. Solo-founder, pre-launch, no real users or
money moved yet (Stripe is stubbed/simulated). Working directory:
`/Users/joaoduro/Desktop/exploration/creator-connect`. Git repo, `main` branch, never pushed to
`origin/main`.

### Foundational docs — read in this order

1. [`docs/PRODUCT.md`](../docs/PRODUCT.md) — product vision, personas, the three pricing
   mechanisms (A/C/D). **Read the revision log at the top and Section 7 in full** — it now has two
   revision-log entries (Phase 0 interviews, then a Handoff #2 review pass) and 8 numbered
   questions, several updated with cited external findings since Handoff #1.
2. [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) — schema, RLS, RPC design. Section 8's
   numbered risks are still the best map of where the delegation/RLS surface is fragile.
3. [`docs/ROLE_ACCESS_AND_UX_SPEC.md`](../docs/ROLE_ACCESS_AND_UX_SPEC.md) — **new since Handoff
   #2.** Part 1 is a verified-against-code Role × Feature × Access matrix for all four roles
   (Creator, Advertiser, Manager, and a newly-designed Founder/Admin role that doesn't exist in
   code yet). Part 2 is a full UI/UX spec per role, including a structural spec for the net-new
   admin dispute-resolution surface. Part 3 is the punch list this brief's Part C is built from —
   read Part 3 alongside each task below for the full reasoning, not just the one-line summary
   here.
4. [`docs/ROADMAP.md`](../docs/ROADMAP.md) — sequencing, kill-switch signals (§6), and the
   volume-triggered framing for the admin dispute UI (§2.5) referenced in task 10 below.
5. [`handoffs/2nd.md`](2nd.md) — the product/design/marketing review that generated most of this
   brief's P1/P2 items. Its Part C Section 5 synthesis has the full reasoning behind each item if
   you need more context than the one-line summary here provides.

### What changed since Handoff #1 (so you don't re-derive it)

- Passkey auth, listing edit/pause, browse text search, and mechanism A/C RPC wiring were in
  Handoff #1's scope — check `git log` to see what actually landed before assuming any of it is
  still open.
- **Mechanism C's `expire_exclusivity` cron job is still NOT scheduled** — verified directly this
  session (`grep cron.schedule supabase/cron-scheduling.sql` shows exactly two jobs,
  `expire-stale-reservations` and `release-delivered-balances`; no third entry for C). This was
  flagged in Handoff #1 as P0 item 4 and evidently never shipped — it's task 3 below, carried
  forward, not a new finding.
- `PRODUCT.md` §7 Q2 (deposit/response-window) and Q3 (staleness tolerance) were narrowed with
  cited competitive research and the doc was updated accordingly — tasks 8-9 below are the
  engineering follow-through on those doc changes, not new product decisions to make.
- `src/lib/format.ts`'s `mechanismShortExplainer` copy was already rewritten to close explainer
  gaps design review found — no action needed here, just don't revert it.

### Session conventions worth preserving

- The founder tests changes himself; don't commit speculatively — commit only when explicitly
  asked.
- `docs/*.md` revisions use strikethrough for superseded text plus a revision-log paragraph at the
  top, never silent deletion.
- Use `.claude/launch.json`'s `creator-connect-dev` config (port 5173) via the preview tool for
  any live UI verification — don't start a second ad hoc dev server.
- Verify UI changes live (preview tool: navigate, screenshot, resize for mobile-affecting changes)
  before marking a task done — several tasks below were only caught because a prior review
  actually drove the live app instead of reading source alone.

---

## Part C — Task backlog (priority-ordered)

Work top to bottom. Each item states its "done when" criterion per the orchestrator's own rule
(§A.2) — use it verbatim as the subagent's final goal, don't loosen it. Source citations point to
`docs/ROLE_ACCESS_AND_UX_SPEC.md` ("Spec") and `handoffs/2nd.md` ("H2") for full reasoning.

### P0 — Bugs that break the app or silently violate the access model (ship before any pilot creator/advertiser touches it)

1. **Fix the mobile layout — every route is unusable below ~860px, not a minor responsive gap.**
   `src/lib/app.css` has zero `@media` rules touching `--sidebar-w`; the 220px fixed sidebar stays
   pinned at any viewport width, compressing content into a ~155px column, clipping headings and
   filter labels. Brand marketers/managers are a plausible mobile-first-touch audience (Slack
   links, email, Instagram bio links). *(H2 design review, friction point #2)* Done when: the app
   shell is usable at 375×812 — sidebar collapses or becomes a drawer below 860px, no clipped text,
   confirmed via the preview tool's mobile resize on at least `/browse` and `/dashboard`.

2. **Fix `/deal/[id]`'s missing manager-delegation check.** A manager acting for a linked creator
   can view the contract but cannot flag a dispute, even though the access matrix explicitly
   grants this (`ARCHITECTURE.md`'s "parties see own deal" RLS includes
   `is_authorized_for_creator`, but `src/routes/deal/[id]/+page.svelte`'s `isParty`/`isAdvertiser`
   only compare `user.id` directly to `deal.advertiser_id`/`deal.creator_id`). *(Spec Part 2,
   Manager section — "highest-priority outside the admin build-out")* Done when: a delegated
   manager viewing a linked creator's `/deal/[id]` can successfully call `flag_dispute_as` and see
   the same "Acting as {creator}" banner already used on `/listings/[id]`, verified against a real
   `manager_creator_links` row in an `active` state.

3. **Schedule Mechanism C's `expire_exclusivity` cron job.** Confirmed still missing (see Part B
   above). `expire_exclusivity` exists in `rpc-mechanism-ac.sql` but has no `cron.schedule` entry.
   Done when: a third `cron.schedule` entry runs `expire_exclusivity` on the same per-row
   exception-handling wrapper pattern already used for D's two jobs in `cron-scheduling.sql`, and
   `supabase/README.md`'s "What's NOT here yet" section is updated to remove this item.

4. **Extend both dashboards past Mechanism-D-only.** Creator dashboard's "needs attention" queue
   and advertiser dashboard's engagement list both only query `reservations` (D) — a stale code
   comment claims A/C "aren't wired to real negotiation RPCs yet," but they are
   (`rpc-mechanism-ac.sql` is fully live). Real, active A-offers and C-grants are currently
   invisible on both dashboards. *(Spec Part 2, Creator §1.3 and Advertiser §2.2)* Done when: the
   creator dashboard's needs-attention queue also surfaces open A-offers and C-negotiations
   awaiting the creator's response, and the advertiser dashboard surfaces the advertiser's own
   open `listing_offers` and `listing_exclusivity_grants` rows alongside existing `reservations`,
   confirmed via the preview tool with at least one seeded listing per mechanism.

### P1 — UX fixes from the design/product review (browse fragmentation mitigation, role-mismatch cleanup)

5. **Replace browse's mechanism filter with a segmented control, and normalize price-info string
   formatting.** This is the reconciled fix from H2's product-vs-design disagreement over Q6
   fragmentation (see `PRODUCT.md` §7 Q6's Handoff #2 synthesis note) — do NOT default listings
   toward Mechanism D or restructure the grid into featured rails; that decision stays parked for
   real usage data. Ship only: (a) turn the hidden `<select>` mechanism filter on `/browse` into a
   persistent segmented control/tab bar (`All / Reserve Now (D) / Negotiate (A) / Early Access
   (C)`), same underlying filter logic, just always visible; (b) normalize the four inconsistent
   price-info string shapes ("Asking $X" / "Floor $X" / "Rate negotiated bilaterally" / "Deal
   confirmed") so Mechanism C's no-rate-card case renders as a muted secondary line, not a full
   sentence competing in the same bold slot as a real dollar figure. *(H2 design review, friction
   point #3 + fix)* Done when: both changes are live on `/browse`, confirmed via preview
   screenshot showing the segmented control and consistent price-slot formatting across a
   multi-mechanism seeded listing set.

6. **Fix two role-mismatched `/create` and `/browse` states.** (a) `/create` visited by an
   authenticated advertiser still renders the full page shell/title before showing a refusal
   message — redirect server-side to `/browse` with a toast instead. (b) `/create` visited by an
   unauthenticated visitor dead-ends into a generic `/login` with no context — add
   `?intent=creator` to the redirect and a one-line banner on `/login` ("Sign in to create your
   first listing"), pre-selecting the role default from the query param. (c) `/browse`'s
   zero-listings empty state says "be the first to create one" regardless of viewer role — wrong
   copy for an advertiser; branch on `profile?.role`. *(Spec Part 2, Advertiser §2.2/2.4; H2
   design review friction point #1)* Done when: all three are fixed and confirmed via preview —
   an advertiser hitting `/create` never sees the create form or its refusal state, an
   unauthenticated visitor from `/create` sees the intent-aware login banner, and the empty-browse
   CTA is role-appropriate.

7. **Add inline manager band visibility on Mechanism D confirmation, plus distinct
   band-rejection messaging.** A manager confirming a deal sees the same "Confirm final price"
   input as the listing owner, with no visibility into their own authorized band beforehand — they
   only learn a price was rejected from a raw RPC error string. *(Spec Part 2, Manager §3.3)* Done
   when: the confirmation UI shows the manager's band for that listing inline (reuse the existing
   `listing_price_bands` query, scoped to `manager_id = self`), and a band-rejection error
   specifically renders "This is below your authorized floor — send to {creator} for confirmation
   instead" rather than the generic error string.

### P2 — Mechanical follow-through on already-approved `PRODUCT.md` changes

8. **Widen Mechanism D's response window to 48h flat.** `PRODUCT.md` §7 Q2 was narrowed (cited:
   Collabstr's matching 48h delivery-review window) from the "24-48h" placeholder to a flat 48h.
   Done when: `rpc-mechanism-d.sql`'s reservation confirmation-window logic uses a flat 48h
   constant instead of the prior 24-48h range, and any UI copy stating the window is updated to
   match.

9. **Add a manual-entry staleness warning.** `PRODUCT.md` §7 Q3 now recommends a soft warning
   badge at 60-90 days since a listing's performance stats were last updated, and a hard
   flag/deprioritization at 6 months. Done when: a listing's stats display shows the appropriate
   badge state based on `performance_stats`'s last-updated timestamp (add the timestamp column if
   one doesn't already exist), confirmed against a seeded stale listing in the preview tool.

### P3 — Larger builds; scope down further before dispatching a subagent, don't just hand over the bullet

10. **Design and build a minimal reputation/trust signal.** Flagged convergently by three
    independent Handoff #2 review lenses (product, design, marketing) as the single biggest
    unaddressed risk to surviving past the initial warm, founder-vouched pilot cohort — today an
    advertiser's only signal about a creator is self-reported, staleness-prone stats. `PRODUCT.md`
    §7 Q8 names the gap but deliberately doesn't prescribe a solution. **Do not build a full
    review/rating system for a 5-8-creator pilot** — that's disproportionate. Recommend scoping
    this down to something minimal first (e.g., a `completed_deals_count` surfaced on
    `public_profiles`, or a simple delivery-reliability indicator derived from `deals.status`
    history) before writing a "done when" criterion and dispatching a subagent — this task needs a
    scoping pass, not direct execution, as the first step.

11. **Build the Founder/Admin dispute-resolution surface.** Fully spec'd already — see
    `docs/ROLE_ACCESS_AND_UX_SPEC.md` Part 1 (schema recommendation: `profiles.is_platform_admin
    boolean`, not a manager-style join table, not raw service-role reuse) and Part 2 (routes
    `/admin`, `/admin/disputes`, `/admin/disputes/[dealId]`; three data panels — deal terms, escrow
    state, audit trail — plus a resolution action calling a new `resolve_dispute_as_admin` RPC).
    `ROADMAP.md` §2.5 frames this as volume-triggered — defer until the pilot's first real dispute
    happens, unless the founder would rather have it built as insurance before any dispute occurs
    (his call, not a default to assume either way — ask before dispatching). Done when (if
    greenlit): `profiles.is_platform_admin` exists, `/admin/disputes` and
    `/admin/disputes/[dealId]` render live with real deal/escrow/audit data for a seeded disputed
    deal, and `resolve_dispute_as_admin` successfully transitions a disputed deal to
    `completed`/`cancelled` with a correctly-attributed `audit_log` row (`actor_id` = the
    founder's own id, not a service-role identity).

### Explicitly out of scope for this handoff — do not build without a direct founder ask

- Real Stripe Connect integration (deferred by explicit instruction, still true).
- The sealed-bid tiebreaker RPCs (Phase 1.5, contention-triggered — no real users yet).
- Anything in `docs/ROADMAP.md` Section 5 ("Phase 3 — Post-MVP expansion") — all of it is
  explicitly usage-triggered and none of the triggers have fired (there is no usage yet).
- Defaulting Mechanism D or restructuring browse into featured rails (see task 5) — `PRODUCT.md`
  §7 Q6 explicitly reserves this for post-launch usage data; don't preempt it.
- A full creator review/rating system (see task 10) — scope down to a minimal signal first.

---

*Prepared by the orchestrating session on 2026-07-02, synthesizing `handoffs/2nd.md`'s engineering
findings and `docs/ROLE_ACCESS_AND_UX_SPEC.md`'s Part 3 punch list. If you (the next Fable
instance) find that reality has diverged from this brief by the time you start — a task already
done, a new bug found, a file moved — trust the filesystem and `git log` over this document, and
note the divergence before proceeding.*

---

## Completion Log — execution record (2026-07-02)

*This section documents what actually happened when this brief was executed, so nothing gets
lost. Written by the orchestrating session immediately after finishing, in the same sitting —
not reconstructed later from commits alone. Trust this over your own re-derivation from `git log`
if the two ever seem to disagree on intent (though they shouldn't; every commit message here was
written to stand alone too).*

### Method

Followed Part A as specified: every task dispatched to a fresh subagent (never done inline by the
orchestrator), each with an explicit stated final goal, an explicit stated model choice + reason,
and an explicit stated context-sharing policy before dispatch. Two-stage review on every result
(spec compliance, then quality) via direct diff inspection — not by trusting the subagent's own
self-report. One task (dashboard Mechanism A/C surfacing, item 4 below) was sent back once with a
specific, cited defect before being accepted; every other task passed first-pass review or needed
only a trivial orchestrator-applied fix (a stale comment, one word). No task came close to the
5-iteration escalation cap.

**Model allocation:** Sonnet for every task touching real logic — access control, RLS-adjacent
delegation, RPC error semantics, price formatting/copy judgment. Haiku for exactly one task (the
`performance_stats_updated_at` schema column) once the investigative/scoping work was already done
by the orchestrator and the remaining work was mechanical execution of a fully-specified plan.

**Context-sharing:** fully isolated subagents throughout — every batch was chosen specifically
because the tasks in it touched disjoint files, except one deliberate exception: the P1 batch's
`/create`+`/login` agent was explicitly warned in its brief that a concurrent agent was also
editing `browse/+page.svelte`, and told to keep its edit to that file minimal and additive. Both
landed cleanly with no lost work, confirmed by re-reading the merged diff before commit.

### Outcome by task

| # | Task | Outcome | Commit(s) |
|---|---|---|---|
| P0-1 | Mobile layout | Shipped — sidebar stacks above content below 860px | `992748f` |
| P0-2 | `/deal/[id]` manager delegation | Shipped | `0629b10` |
| P0-3 | Schedule `expire_exclusivity` cron | Shipped — also fixed a real setup-order bug in `README.md` found during verification | `f80cdb6` |
| P0-4 | Dashboards past Mechanism D | Shipped — one real bug caught and fixed in review (see below) | `8c60c39` |
| P1-5 | Browse segmented control + price normalization | Shipped | `a92bf42` |
| P1-6 | `/create`+`/login` role-mismatch | Shipped | `1ccfb6b`, `a92bf42` |
| P1-7 | Manager band visibility on D confirmation | Shipped | `6ea020a` |
| P2-8 | 48h response window | **No code change — brief's premise was stale.** `place_reservation`'s `p_response_window` has defaulted to `'48 hours'` since the RPC's original commit (`081afed`); the "24-48h" figure only ever existed as placeholder prose in `PRODUCT.md`, already narrowed by Handoff #2. | — |
| P2-9 | Staleness badge | **Scope gap found and flagged to the founder before proceeding**: `performance_stats` has zero UI usage anywhere (no entry form, no display) — there was nothing to attach a badge to. Founder chose schema-only. | `eafe550` |
| P3-10 | Reputation signal | Scoped by the orchestrator per the brief's own instruction (not executed blind), presented to the founder, approved, built. | `4e7a4fa` |
| P3-11 | Admin dispute UI | Asked the founder directly per the brief's own instruction — deferred until first real dispute (`ROADMAP.md` §2.5 volume trigger). Not built. | — |

Full diff across all shipped work: `git log --oneline bc13dcd..4e7a4fa` (9 commits). `docs/PRODUCT.md`
§7 and `docs/ROLE_ACCESS_AND_UX_SPEC.md` Part 3 both carry their own inline revision notes tying
each finding/question back to the specific commit that addressed it — check those directly rather
than re-deriving from this table if you need the reasoning, not just the outcome.

### The one real bug caught in review

P0-4's dashboard extension initially flagged fresh, unanswered Mechanism C exclusivity grants
(`negotiation IS NULL`) as "awaiting the creator's response." Tracing the actual UI gate in
`listings/[id]/+page.svelte` showed the opposite: a null negotiation means the *advertiser* hasn't
proposed terms yet, so it's their turn, not the creator's. Caught by diffing the subagent's filter
logic against the already-shipped reference pattern rather than trusting its self-report; sent back
with the exact file/line and the correct condition; fixed in one iteration. This is the kind of bug
that would only have surfaced as a confusing, wrong "needs your attention" queue for real creators —
worth remembering as a class of error (turn-taking logic inferred from schema shape rather than
traced against the actual gating code) when reviewing similar work in the future.

### Divergences from this brief's own assumptions (both flagged before proceeding, not silently patched)

1. **P2-8** assumed a 24-48h range existed in code needing narrowing to 48h flat. It didn't — the
   code was already correct, and had been since the feature's first commit. No subagent was
   dispatched; dispatching one would have been busywork against a already-true premise.
2. **P2-9** assumed a listing's performance-stats display already existed and just needed a
   staleness badge added to it. It doesn't exist — `performance_stats` is a schema column with zero
   UI reads or writes anywhere in the app. Flagged to the founder via `AskUserQuestion` before any
   code was touched; he chose the minimal option (schema-only, defer the UI+badge as their own
   future task) rather than have the orchestrator unilaterally expand scope to build a stats-entry
   UI that wasn't asked for.

### Verification caveats — read before trusting any of this without your own pass

Live browser verification was inconsistently available throughout this session: a second,
concurrent Claude Code session held the shared dev server's port for parts of the session, the
Chrome extension was disconnected when tried, and several flows (manager delegation, dashboard
A/C surfacing, D-confirmation band display) need real authenticated sessions that don't exist in
this environment — the backend is a remote, non-empty Supabase project, auth is magic-link/passkey
only, and no service-role key is available to seed test data. Where live verification wasn't
possible, subagents fell back to: diffing against already-shipped, already-verified reference
patterns (`listings/[id]`'s delegation/band/negotiation logic came up as the reference for three
separate tasks), tracing the actual RPC/RLS logic line-by-line rather than assuming, and a clean
`svelte-check`. That caught the one real bug above, but it is not the same evidentiary bar as a
screenshot. **Before any pilot creator or advertiser touches this app, manually verify:**

- Manager-delegation flows end-to-end (dispute flagging on `/deal/[id]`, band visibility and
  rejection messaging on a D confirmation) with a real linked manager account.
- Dashboard A/C surfacing with at least one real open offer and one real exclusivity grant.
- Mobile layout on an actual phone, not just a resized desktop browser viewport.
- The browse segmented control and price-info formatting against a real Mechanism-C listing with
  no rate-card range set (none existed in seed data during this session).

### ~~Outstanding action: SQL changes need to be applied to the live Supabase project~~ DONE

~~This repo's convention (`supabase/README.md`) is that `.sql` files are run manually via the
Supabase SQL Editor — there is no auto-migration. Four files changed this session and need
re-running against your live project (each is idempotent, safe to re-run in full): `schema.sql`,
`listings.sql`, `rpc-delivery.sql`, `cron-scheduling.sql`. See `supabase/README.md`'s own
top-of-file note for the exact reasoning per file. Nothing in the app will reflect this session's
schema/RPC changes until this is done.~~ Founder confirmed all four files were re-run against the
live project shortly after this log was first written. `supabase/README.md`'s temporary
top-of-file notice has been removed now that it's no longer actionable.

### Post-completion follow-on (same session, after this brief's own scope closed)

The founder picked up one deferred item as a direct follow-on once this brief's backlog was fully
closed and its SQL applied: **the manual performance-stats entry + display UI + staleness badge**
(commit `c6299f0`). Scoped as an inline editor on the listing detail page (there's no listing-edit
route anywhere in this app, so this deliberately did not become "build a general edit page" — it's
gated the same way the existing manager-band editor on that same page already is, reusing the RLS
window that restricts `creator_listings` edits to `draft`/`open` status). `performance_stats` had no
defined field shape anywhere in any doc, so a minimal 2-field shape (`avg_views_per_post`,
`engagement_rate_pct`) was chosen and documented inline — not a rediscovery of a prior spec, a new
one. Badges only, matching PRODUCT.md §7 Q3's 60/180-day thresholds — no browse-listing reordering
or deprioritization, which stays a separate, bigger decision for later.

The founder then revisited task 11 itself — the Founder/Admin dispute-resolution surface,
originally deferred earlier in this same session pending real dispute volume — and asked to build
it as insurance now instead of waiting. Built in a three-stage pipeline (backend first, since the
two frontend pieces both depend on its exact interface; then the disputes-list/nav/layout and the
dispute-detail/resolution page in parallel once the backend was reviewed and locked):

- **Backend** (commit `31e903f`): `profiles.is_platform_admin` (additive, no new role tier, no
  impersonation), `is_platform_admin()` helper mirroring `is_authorized_for_creator()`, three
  existing RLS select policies (`deals`, `escrow_transactions`, `audit_log`) widened with an
  `or is_platform_admin()` clause — verified pure OR-widening, nothing narrowed — and
  `resolve_dispute_as_admin`, which transitions a disputed deal to `completed` (release) or
  `cancelled` (refund/cancel) and attributes the audit_log row to the founder's own `auth.uid()`,
  never a service-role identity. No `escrow_transactions` writes, matching this codebase's existing
  no-real-Stripe-wiring pattern throughout.
- **Frontend** (commit `27626ff`): `/admin` (route-protected, redirects to `/dashboard` not
  `/login` since the visitor is already authenticated), a red-tinted sidebar nav entry,
  `/admin/disputes` (queue sorted oldest-first, timestamp sourced from `flag_dispute_as`'s own
  `audit_log` row since `deals` has no dedicated column for it), and
  `/admin/disputes/[dealId]` (deal terms, escrow state, a merged chronological audit trail from
  both the deal and its origin reservation/offer/grant row — the trickiest part was disambiguating
  `audit_log`'s two FKs to `profiles` in one PostgREST embed, resolved via the same auto-generated
  `<table>_<column>_fkey` naming convention already relied on elsewhere in this codebase — and a
  two-step-confirm resolution panel). Every load function relies on the RLS/RPC layer as the real
  security boundary rather than re-checking admin status itself.

~~**One manual step still required, same pattern as the SQL re-run**: `supabase/rpc-admin.sql` needs
to be run against the live project (README's setup order updated to reflect it), and — by design,
per the access spec — there is no in-app way to grant yourself `is_platform_admin`. `supabase/README.md`
now documents the exact one-time SQL statement.~~ **DONE.** One snag along the way worth recording:
the founder initially ran the `is_platform_admin = true` grant statement before re-running
`schema.sql` (which is what actually adds the column) — `update ... set is_platform_admin`
predictably failed with `column "is_platform_admin" of relation "profiles" does not exist`. Fixed by
re-running `schema.sql` → `deals.sql` → `delegation.sql` → `rpc-admin.sql` in that order, then the
grant statement succeeded. The founder confirmed admin access is live.

### What's still genuinely open

- Everything this brief's own "explicitly out of scope" section named, unchanged: Stripe Connect,
  the sealed-bid tiebreaker, `ROADMAP.md` Phase 3, defaulting Mechanism D / featured rails, a full
  review/rating system beyond the minimal count shipped this session.
- Escrow/Stripe writes on dispute resolution — `resolve_dispute_as_admin` only moves `deals.status`;
  it deliberately does not touch `escrow_transactions` or issue a real refund, matching every other
  RPC in this codebase pre-Stripe-wiring. Revisit once roadmap Phase 0 items 0.4/0.5 land.
