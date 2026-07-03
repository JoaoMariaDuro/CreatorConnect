# CreatorConnect — Handoff Brief #6 (Batch-1 Execution + Company/Org Entity + Vertical-Network Resolution)

*This handoff covers two things: **Part A** is a completion log for a large execution pass — everything
Handoff #5 proposed plus several new items the founder requested directly mid-session (a real
company/organization entity, individual profile pages, per-deal cancellation terms, printable
contracts, and a dual-consent agency showcase system). **Part B** is a decision brief resolving the
vertical-network/"social media for creators" question Handoff #5 deliberately left open — it answers
the three sub-questions that document posed, plus a fourth angle the founder introduced this session
("slowly capture and consolidate their work needs into this platform"), using what shipped in Part A
as real evidence rather than speculation.*

---

## Part A — Completion Log

Executed across four commits, in order:

### 1. `d0990b8` — Batch-1 groundwork + a real RLS bug fix

- **Manager dashboard**: real commission earned/pending card (`manager_creator_links.commission_bps
  × deal price` — the schema field existed since MVP with zero UI until now), roster-wide
  needs-attention queue, upcoming deliveries, per-creator activity counts.
- **Creator dashboard**: upcoming-deliveries section, closing a real correctness gap (a creator
  previously had no visibility into existing delivery obligations before confirming a new one).
- **Notification bell**: the `notifications` table (created in an earlier handoff, never written to)
  wired into all 17 state-transition RPCs across 5 SQL files, plus a bell UI in the top bar.
- **`/c/[handle]`**: the public creator media-kit page proposed in Handoff #4, finally built.
- **Real bug found and fixed**: every cross-user `profiles` embed in the app (`creator:profiles!fkey`
  syntax, used in browse/dashboard/listing/deal/admin pages) was silently returning `null` under RLS,
  since `profiles` only ever granted self-reads. Confirmed live via anon-key queries before and after
  the fix. Migrated all embeds to the existing (now-extended) `public_profiles` view.

### 2. `55ea7fa` — Handoff #5's "Batch 1: new tools & pages per role"

All nine items from that plan, all cheap (existing columns/tables, no new schema beyond noted):
real `/settings` profile editor (was previously admin-only), `/admin/feedback` inbox, `/admin/audit-log`
browser, a real `/admin` landing page (was a pure redirect), a "Listing extras" editor
(`constraints_text`/`audience_demographics`, both unused since MVP), a creator rate-card summary
tile, and three manager-side additions to `/settings/managers` (commission ledger, roster directory,
band hub).

### 3. `b4f9ab4` — Company/organization entity (founder-directed, mid-session)

The founder asked for real profile pages plus a hierarchy for advertisers/managers: a company/agency
that multiple individual workers can belong to, separate from solo accounts. Three confirmed
decisions before any code was written: (1) company is a **real multi-tenant org**, not a text field;
(2) only advertisers and managers get company affiliation, creators are unaffected; (3) solo
advertisers/managers get only their own individual page, no auto-created company page.

Shipped: `companies` + `company_members` (owner/member roles, pending/active/revoked invites, a
trigger blocking removal of a company's last active owner), `create_company` /
`invite_company_member_by_email` / `accept_company_invite` RPCs mirroring the existing
manager-delegation pattern, `/settings/company`, the public `/company/[handle]` and `/u/[handle]`
(individual pages for advertisers/managers — `/c/[handle]` stayed creator-only, untouched).

Also shipped in this pass: `profiles.handle` uniqueness fix (a pre-existing gap since MVP — two
users could collide and break each other's `/c/`/`/u/` page; verified no existing duplicates before
adding the constraint) and the advertiser shortlist/watchlist (`PRODUCT.md` Flow 2 — designed at
MVP, never built until now).

**One real bug found via live testing, not assumption**: the `public_profiles` view edit that added
`bio` initially inserted it in the *middle* of the column list. Postgres's `CREATE OR REPLACE VIEW`
only allows appending columns to the end — it silently rejected the mid-list insert. Caught by
testing live against the database after the founder ran the migration, not by code review; fixed by
moving `bio` to the end.

### 4. `bb06d69` — Cancellation terms, printable contracts, agency showcase (founder-directed)

Three more founder-directed items, answered directly and built same-session:

- **Cancellation terms** ("add deal cancellation terms"): `creator_listings.cancellation_terms`,
  editable in the Listing Extras card, copied into `deals.cancellation_terms` at confirmation across
  all 5 deal-creation RPCs (mechanisms D, A×2, C×2) — previously always blank on every deal.
- **Contract, "both options"** (interpreted as: an in-app HTML view *and* a real downloadable PDF):
  the existing `/deal/[id]` "Sponsorship Agreement" card got a "Print / Save as PDF" button
  (`window.print()`, zero new dependencies) plus a global print stylesheet flipping the theme to
  print-legible light colors and hiding all interactive chrome.
- **Agency creator showcase, dual consent** — the founder's exact answer to the privacy question
  Handoff #5's manager-rollup idea raised: *"the agency can turn visible those it wants to and that
  the creator also has to accept."* New `company_showcased_creators` table: an agency member proposes
  showcasing a creator they personally represent (verified against their own active
  `manager_creator_links` row, not just company membership); the creator must separately accept on
  `/settings/managers`; a pending proposal is never public. RLS specifically prevents the agency side
  from ever self-granting consent — its own update policy can only move a row *to* `'declined'`,
  never `'accepted'`. Accepted showcases appear as "Represented creators" on `/company/[handle]`.

### Verification posture across all four commits

`npm run check` kept at 0 errors throughout. Every new anonymous-read view and cross-user embed was
checked live against the actual database via the anon key before being relied on — the same
technique that caught both real bugs above. Every new auth-gated route confirmed to redirect
correctly when signed out. What could **not** be verified solo: the full authenticated flows
(profile edits, company create/invite/accept, showcase propose/accept) — those need a real signed-in
session, which this session's agent doesn't hold credentials for. The founder ran every migration and
confirmed each via follow-up live checks in this session.

---

## Part B — Vertical-Network Question, Resolved (Handoff #5 → answered)

Handoff #5 posed three sub-questions and deliberately left them open, flagging that answering them
required either founder input or real evidence, not more speculation. This session shipped enough
(the individual/company profile pages, the dual-consent showcase system) that the questions could be
answered against actual evidence instead of guesswork. The founder also added a fourth framing
mid-session — *"this is the idea of social network between creators and contractors and slowly we
want to capture and consolidate their work needs into this platform"* — which this pass treats as a
fourth question, not a restatement of the first three.

### 1. "Social media, like Facebook" — literal feed mechanics, or a LinkedIn-shaped professional home base?

**Verdict: LinkedIn, not Facebook — and the codebase has already made that call unintentionally.**
`/c/[handle]`, `/u/[handle]`, and `/company/[handle]` are identity pages (who someone is, verified
facts — stats, bio, roster, a consented showcase relationship), not activity streams. The showcase
system's RLS ceremony (a `with check` clause specifically preventing the agency from self-granting
consent) is disproportionate effort for something as low-stakes as a Facebook friend request — it's
the kind of care you put into a *credential*, not a social gesture. Nothing in the schema has a
`posts`, `follows`, `likes`, or `activity_feed` table. If the founder means literal Facebook
mechanics, that's a real pivot from where the code has organically drifted, not an extension of it —
worth confirming explicitly rather than assuming the code's own momentum has settled the question.

### 2. Closed network vs. public-facing component

**Verdict: already both, split along a line that should stay.** The transactional core (browse,
offers, deals, delegation) is the closed three-role network — professionals already interact with
each other's real activity there, just not framed as "social." `/c/`, `/u/`, `/company/` are the
deliberate external-facing layer, public with no auth required, explicitly built as shareable
bio-link pages. What's *not* public, and shouldn't become so by default: any transactional activity
beyond the one relationship type (showcase) that's explicitly opt-in on both sides. Extending the
consent-gated-visibility pattern to more relationship types is plausible; making deals or offers
public by default cuts against the trust/privacy posture the rest of the schema (sealed audit logs,
RLS-scoped everything) has consistently taken.

### 3. Density thresholds — is there enough scale at 5-8 creators for social mechanics to mean anything?

**Verdict: no, and this should stay an architectural bet, not a built feature, until real usage
signals otherwise.** Honestly caveated: exact thresholds are empirical facts about this specific user
base, not something derivable from first principles or comparable-platform benchmarks. Directional
reasoning, not measurement: identity pages and consented-relationship visibility already pay off at
n=1 (correctly buildable now, and already built); internal activity rollups need dozens of same-role
peers before browsing-by-hand becomes real friction; connection graphs and activity feeds need enough
repeat cross-role relationships and event volume that a stream beats point-checking — likely the same
order of magnitude as `ROADMAP.md`'s existing "dozens to low hundreds of deals/month" trigger for
AI-assisted pricing, arguably higher. **What would resolve this**: the same usage-triggered signal
`ROADMAP.md` §6 already tracks for other deferred features — watch, unprompted, whether pilot users
ask to see or contact people they're not currently transacting with. Cheap to start watching for now;
not worth building ahead of that signal.

### 4. "Slowly capture and consolidate their work needs" — what's genuinely outside the platform today

Assessed persona-by-persona against `PRODUCT.md` §3's actual stated needs, filtered by a sharper test
than "is this workflow-adjacent": **does the platform already hold or generate the data this need
requires?** Candidates that pass:

- **Manager roster-wide CRM** — near-verbatim `PRODUCT.md` §3's stated pain (rates/availability/deal
  flow scattered across spreadsheets/DMs/email today). Already scoped in Handoff #5 Part D item 1,
  cheap, unbuilt. **Strongest candidate on the whole list.**
- **Manager commission visibility** — `commission_bps` exists in schema since MVP, populated in seed
  data, rendered nowhere until this session's dashboard card (Part A, commit `d0990b8`). A verified,
  named gap now partially closed; automated *payout* remains gated behind Stripe.
- **Creator contract e-signature** — the platform already generates contract content with FTC
  disclosure language; it doesn't yet capture a signature. Completing a document the platform already
  owns, not importing an external workflow.

Candidates that fail the test and should be resisted: full bookkeeping/invoicing (different job,
tools like QuickBooks exist specifically for it), ingesting pre-listing DM negotiation (structurally
invisible to the platform by definition), advertiser ROI/campaign reporting (Handoff #5 already
argued against this at current sample size, unchanged here). Advertiser **campaign planning across
multiple creators** is a real, named gap (`PRODUCT.md` §3 again) but was already correctly deferred
pending a real advertiser visibly improvising their own tracking — that call stands.

### The one question only the founder can answer

Every consolidation candidate eventually forks on this, and no further analysis resolves it — it's a
stated-intent question: **does CreatorConnect aim to *replace* general-purpose tools (Notion,
Airtable, DocuSign, a bookkeeping app) for these three personas, or stay the marketplace-of-record and
*integrate outward* to those tools?** The founder's own two framings from Handoff #5 point different
directions in the same breath — "the tool for everything of their work" (replace) vs. "integrate with
outside tools when needed and possible" (integrate-outward) — and they carry very different
engineering-cost profiles (owning e-signature and bookkeeping is a materially larger, more regulated
build than exporting an ICS feed or a webhook). Flagged here rather than silently decided, same as
Handoff #3's admin-surface-timing question and Handoff #5's original framing of this exact question.

### If the founder wants to move on this next, three cheap tests (not the whole vision)

1. **Ship the manager roster CRM + commission line-item display** (Handoff #5 Part D items 1-2) — the
   strongest-evidenced gap on the list, cheap (read-only rollups over existing schema), and a real,
   low-cost signal for whether "professional home base" resonates before betting bigger.
2. **Add e-signature capture to the existing contract-generation flow** — closes a loop the platform
   already owns most of, and is a small, bounded test of the replace-vs-integrate question for one
   specific external tool (DocuSign).
3. **Don't build feed/follow/connections yet.** Instead: get the founder's answer on both open
   questions above (Facebook-literal vs. LinkedIn-shaped; replace vs. integrate) before the next
   session touches this area, and start watching pilot conversations for the one cheap density
   signal named in §3 — whether users ask to see or contact people they're not currently transacting
   with.

---

*Part A prepared by the orchestrating session executing Handoff #5's Batch 1 plus founder-directed
mid-session additions (company/org entity, cancellation terms, contract printing, agency showcase),
2026-07-03. Part B prepared by a dedicated research pass grounded in `docs/PRODUCT.md`,
`docs/ROLE_ACCESS_AND_UX_SPEC.md`, `handoffs/5th.md`, and the shipped codebase as of commit `bb06d69`,
same session. Both parts verified against the live database via direct anon-key queries before being
written up — not just code review — following this project's own established practice of testing
claims rather than assuming an edit worked.*
