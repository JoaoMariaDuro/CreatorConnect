# CreatorConnect — Handoff Brief #4 (Product/Design/Marketing/Analytics Synthesis)

*Not an engineering brief written in advance of the work — this is the synthesis of a four-lens
review pass run after Handoff #3 fully closed. Unlike Handoff #2 (which asked "is the offer
itself right?") and Handoff #3 (which closed a concrete access/UI punch list), this pass asked a
forward-looking question: now that the core transaction flows, manager delegation, staleness
badges, a minimal reputation signal, and a full admin dispute-resolution surface are all shipped,
what should get built next? A fourth lens — analytics — was added at the founder's explicit
request, alongside the original product/design/marketing three.*

**Method:** four subagents, each acting as a named persona (senior product owner, UX/design lead,
marketing/growth lead, data/analytics lead), grounded in the current docs and — for design and
marketing — a live walkthrough of the running app, not just source-reading. Product, marketing,
and analytics ran isolated from each other in parallel; design ran after product and was
deliberately given product's output as input context, mirroring Handoff #2's own dependency
structure. This document is the orchestrator's own synthesis of all four — not a fifth subagent —
per the same "synthesis stays with the orchestrator" rule Handoff #2 established.

Full lens output lives in this session's transcript; this document extracts the actionable
outcome. If you want the original per-lens reasoning (not just the synthesized recommendation),
ask for it — it wasn't preserved verbatim in this file to keep it a usable brief rather than a
transcript dump, but the key findings that support each item below are cited inline.

---

## Convergence: three of four lenses independently proposed the same thing

Product (lens 1), analytics (lens 4), and — after seeing product's output — design (lens 2) all
landed on the same top priority from three different angles: **a founder-facing signals/analytics
surface**, tied directly to `ROADMAP.md` §6's kill-switch signals and several of `PRODUCT.md` §7's
open questions. Today the founder has zero visibility into any of this beyond raw SQL. This
independent convergence (product and analytics ran fully isolated from each other and reached the
same conclusion) is treated as strong signal, not redundant output — see task 1.

Design's contribution on top of the convergence was the UX shape: cards with plain-English
glosses, not a raw metrics table; no charts/time-series for v1 (pilot volume is too low for a
trend line to mean anything); an explicit small-sample caveat baked into the UI when n is below a
threshold, so the founder isn't misled by a falsely-precise-looking single-digit rate.

---

## Part C — Task list (priority-ordered)

### P0 — Fix now (factual accuracy, not new scope)

1. **Fix `/roadmap`'s two stale claims.** `src/routes/roadmap/+page.svelte` currently states, under
   "IN PROGRESS": *"Auto-expiring stale reservations and auto-releasing delivered deals after the
   hold window — the logic exists, the scheduler doesn't yet"* (line 55) — false since Handoff #3
   task P0-3 (commit `f80cdb6`) scheduled all three cron jobs. And under "NEXT UP": *"Fixed-price-
   and-counter and reserve-the-relationship are visible in listings today but not yet backed by
   real negotiation flows"* (line 66) — false since commit `baa42fe` wired mechanisms A and C to
   real RPCs, before Handoff #3 even started. *(Marketing lens, finding 2 — flagged this as more
   urgent than the original "trust vs. liability" question about exposing the page publicly at
   all: a stale roadmap that undersells shipped work is worse than either alternative, since it
   reads as the founder not watching his own public-facing docs.)* **Done when:** both items are
   moved into a "LIVE NOW" section (or equivalent) reflecting what's actually shipped, confirmed
   against a live re-read of the page.

### P1 — Scoped engineering, ready to hand to a fresh session

2. **Build `/admin/signals`** (or `/admin/analytics` — same idea, pick one name). Reuses the
   `is_platform_admin()` gate and `/admin/disputes`-pattern load functions already shipped; no new
   tables, no new RPCs (read-only aggregation). Per the convergent findings:
   - **Numbers to show**, each tied to a specific open question or kill-switch signal (analytics
     lens, section 1, has the full list with citations): listing funnel by status + time-in-draft;
     time-to-first-reservation; reservation confirm/expire rate (this one is named *twice*,
     independently, in `ROADMAP.md` §6 and `PRODUCT.md` §7 Q2 — treat as highest-value single
     number); listing edit/abandon rate pre-commitment; mechanism split at creation vs. at
     confirmed-deal (directly answers §7 Q6 with real data instead of a guess); dispute rate;
     performance-stats staleness distribution (answers §7 Q3's still-open abandonment-rate half).
   - **UX shape** (design lens, section 1): stat cards with a one-line plain-English gloss each,
     not a table; no charts/sparklines for v1; a visible "as of" timestamp; a small-sample caveat
     shown automatically below some n-threshold.
   - **Concrete route sketch** (analytics lens, section 3): `src/routes/admin/signals/+page.server.ts`
     with ~6-7 independent Supabase queries merged in JS (same merge pattern already used in
     `/admin/disputes/[dealId]/+page.server.ts` for its two audit_log queries), `+page.svelte`
     reusing `formatMoney`/`formatDateTime`/`Badges` and the existing `.card` grid pattern.
   - **Done when:** the page renders all six-plus numbers against real seeded data (use
     `supabase/seed-data.sql`), each traceable to the open question it answers, with no chart
     library added and no new schema.

3. **Build a minimal `/admin` landing page**, replacing the current bare redirect-to-disputes.
   *(Design lens, gap B/fix B — landing on a page whose entire content is "No open disputes." is a
   disorienting non-event for a founder checking in periodically, and gets worse once Signals
   ships as a sibling route buried one click below the default landing spot.)* Two cards ("Disputes"
   with live open-count, "Signals" once task 2 ships), reusing the `.card` grid pattern already
   used on `/dashboard`'s manager-roster view. **Sequence after task 2** — no point building an
   index page with only one real entry. **Done when:** `/admin` shows both cards with live counts
   instead of redirecting straight into disputes.

4. **Give `completed_deals_count` an explicit zero-state and a one-word qualifier.** Two
   independent lenses flagged this: design (gap A/fix A — hiding the count entirely below 1 makes
   "no data" and "bad track record" the same invisible state, which they aren't) and marketing
   (finding 3 — the raw count is a real differentiator but only past ~3, and is essentially useless
   for week-one pilot messaging since every pilot creator starts at zero). Files:
   `src/routes/browse/+page.svelte` (~line 107), `src/routes/listings/[id]/+page.svelte` (~line
   243). Change the `{#if count > 0}` guard to always render: **0 deals** → `"New to
   CreatorConnect"` instead of nothing (reframes absence as a neutral, honestly-labeled state, not
   a silent gap); **>0 deals** → keep the existing count text, optionally append `"· no disputes"`
   when true (a simple filter on the creator's own `deals`, no new schema) — do NOT add a
   percentage/ratio, which would repeat the exact small-sample mistake `PRODUCT.md` §7 Q8 already
   correctly avoided. **Done when:** a 0-deal creator shows "New to CreatorConnect" and a >0-deal,
   zero-dispute creator shows the qualifier, confirmed against seeded data.

5. **Add a first-run "how this works" panel to the creator dashboard's empty state.** *(Design
   lens, gap C/fix C — a brand-new creator with zero listings currently sees one bare link
   ("Create one.") with no restatement of what a listing is or why they'd pick a mechanism; the
   explainer copy that would help already exists — `mechanismShortExplainer` in `src/lib/format.ts`
   — but is gated behind already being on a specific listing's detail page.)* File:
   `src/routes/dashboard/+page.svelte`, creator branch, zero-listings case. Show a 3-card row (one
   per mechanism, reusing the existing explainer text verbatim, same visual weight as the landing
   page's "How it works" cards) above the "Create your first listing" CTA, replacing the single
   line. No new copy to write. **Done when:** a zero-listing creator sees the row; it disappears
   once they have ≥1 listing.

6. **Add a `dispute_cause` field to the resolution panel.** *(Product lens, finding 3 — the
   existing free-text notes field on `resolve_dispute_as_admin`'s resolution panel won't produce
   the cause-clustering pattern `PRODUCT.md` §7 Q4 and `ROADMAP.md` §6 both name as a distinct
   signal from raw dispute rate, without the founder manually re-reading every note later.)* A
   small enumerated field (`deliverable_ambiguity` / `non_delivery` / `quality_dispute` /
   `payment_timing` / `other`) captured at resolution time on
   `src/routes/admin/disputes/[dealId]/+page.svelte`'s existing resolution form, stored in
   `resolve_dispute_as_admin`'s `after` jsonb (no new column needed — it already accepts
   arbitrary structured data via `p_notes`-adjacent fields, or add one `p_cause text` param to the
   RPC if a queryable column is preferred for task 2's signals aggregation). **Done when:** the
   resolution panel captures cause, and it's visible in the audit trail / queryable for task 2's
   dispute-rate-by-cause breakdown.

7. **Build the public creator media-kit page (`/c/[handle]`).** *(Marketing lens, section 4 — the
   single highest-leverage tool proposed: reuses data already in `profiles`/`creator_listings`
   entirely — `display_name`, `handle`, `follower_count`, `niche_tags`, `completed_deals_count`,
   `performance_stats` + its staleness badge — no new schema. Justification: gives the founder a
   concrete, low-effort payoff to offer a warm-recruited creator immediately — "I'll build you a
   page you can drop in your Instagram bio right now" — independent of whether the marketplace
   mechanism itself has produced a deal yet, which is exactly the gap between "creator said yes in
   an interview" and "creator actually publishes a listing" that `ROADMAP.md` §2.3's cohort design
   depends on closing.)* **Done when:** a real creator's `/c/[handle]` page renders their stats and
   staleness-aware badge, publicly accessible with no auth required (matches the existing public
   `/browse` RLS pattern).

### P2 — Smaller, sequence after the above

8. **`fee_feedback` one-question prompt after a creator/manager's first completed deal.** *(Product
   lens, finding 3 — `PRODUCT.md` §7 Q7's fee tolerance is explicitly "untested" and says the
   question "should be asked now, not discovered post-launch," but doesn't ask for a billing UI.)*
   One dismissible prompt ("Was the platform fee in line with what you expected? Yes / No /
   Concern"), shown once, written to a new lightweight `fee_feedback(profile_id, deal_id, response,
   created_at)` table — deliberately not survey infrastructure. **Done when:** the prompt fires
   once per profile after their first `deals.status = 'completed'` transition and writes a row.

9. **"Your listing is live" shareable link nudge.** *(Marketing lens, section 4, second/smaller
   tool — lower priority than task 7 by the marketing lens's own sequencing, since it only helps
   *after* a creator has already published, whereas task 7 helps *before*, which is where the
   actual follow-through risk sits.)* A one-line addition to the create-listing success state
   surfacing the listing's own shareable URL, formatted for the founder to forward immediately.
   **Done when:** the create-success screen shows a copy-ready link.

10. **Minor landing-page copy nit.** *(Marketing lens, section 1 — low priority.)* "secure the ones
    you want before someone else does" on the advertiser card echoes a scarcity/competition frame
    `PRODUCT.md` §1 explicitly wants to avoid, even though it never says "bid" or "auction" — a
    mild inconsistency with the anti-auction framing promised to creators in interviews, not a
    positioning failure. Reword to remove the implied-competition cue if touching this copy for
    any other reason; not worth a dedicated pass on its own.

### Explicitly not recommended by any lens

- **A BI/charting tool for analytics** — analytics lens argued against this explicitly and at
  length: at pilot volume (a handful of deals a month), a chart of "3 vs. 2" tells you nothing a
  sentence doesn't, and it would add a new dependency/deploy surface for no real benefit. Revisit
  only at "dozens to low hundreds" of deals/month, the same threshold `PRODUCT.md` §6 names for
  even considering algorithmic pricing.
- **A percentage/ratio version of the reputation signal** — both design and the original Q8
  resolution agree a raw qualifier beats a computed ratio at this sample size.
- **Undoing or re-scoping the admin dispute-resolution surface** — the product lens's "overbuilt"
  finding is about *sequencing* (it shipped before the cheaper, more broadly-useful signals view),
  not quality. Design's independent read of the same code found it genuinely well-built — correct
  empty states, correct two-step-confirm friction for an irreversible solo-admin action, consistent
  reuse of the "acting as" pattern. Nothing here should be torn out; the lesson is about what to
  prioritize next, not a defect in what already shipped.

---

## One process note worth acting on regardless of which tasks get picked up

The marketing lens found that Handoff #2's own marketing-lens deliverables (landing-page verdict,
roadmap recommendation, pilot messaging, one differentiated claim) were never captured anywhere in
this codebase — not in `PRODUCT.md`'s revision log, not in the landing page's git history, not in
`handoffs/3rd.md`'s completion log. Either that subagent's output was never synthesized into a
doc, or it was and got lost. This document (and this session's practice of writing a Completion
Log into the brief that generated the work) is meant to prevent exactly that recurrence — if any
task above gets picked up in a future session, its outcome should get written back into this file
or a dedicated completion log, the same way Handoff #3's was, not left to live only in a chat
transcript that eventually closes.

---

*Prepared by the orchestrating session on 2026-07-03, synthesizing four parallel/sequenced review
lenses (product, design, marketing, analytics) run after Handoff #3's full backlog — including two
post-completion follow-ons (performance-stats UI, admin dispute surface) and test-data seeding —
closed. Unlike Handoffs #1-#3, no task above has been executed yet; this is a proposal awaiting the
founder's prioritization, not a backlog already in flight.*
