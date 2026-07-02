# CreatorConnect — Role Access & UI/UX Specification

*Companion to `PRODUCT.md` (personas, flows) and `ARCHITECTURE.md` (RLS/RPC design). This document exists to answer one question for engineering: for each role, exactly what can they do, and exactly what should the UI show them? Part 1 is the access matrix (verified against actual `supabase/*.sql`, not just docs). Part 2 is the UI/UX spec built on top of it (verified against the live app where possible, source-read where authentication made live testing impractical — noted inline). Part 3 is a prioritized punch list for engineering.*

*Produced July 2026 via a two-pass orchestrated review (access matrix, then UI/UX spec grounded in it) as a follow-on to Handoff #2's product/design/marketing review.*

**Revision log (Handoff #3 execution, July 2026):** All five Part 3 punch-list items were picked up and resolved — see each item below for its outcome and the shipping commit. Full execution record, including what diverged from this doc's assumptions and what's still outstanding, is in `../handoffs/3rd.md`'s Completion Log.

---

## Part 1 — Role × Feature-Area × Access-Level Matrix

**Verified against code, not just docs.** `profiles.role` check constraint (`schema.sql:22`) is confirmed exactly as documented: `check (role in ('creator', 'advertiser', 'manager'))`. There is no fourth Postgres-level role, no `is_admin`/`is_platform_admin` column anywhere in the schema today, and no `/admin` route in the codebase. The only privilege-escalation pattern that exists at all is the Stripe **service role**, used exclusively by the webhook handler to write `escrow_transactions`. The Founder/Admin persona is entirely undesigned in code as of this writing — every citation for that row below is to prose (`ARCHITECTURE.md` §8 risk 5, `ROADMAP.md` §2.5), not to a policy or RPC.

### 1. Listing management (`creator_listings`)

| Role | Can do | Cannot do | Enforced by |
|---|---|---|---|
| Creator | Create/edit/delete own listings while `status in ('draft','open')`, for any of A/C/D; choose `pricing_mechanism` at creation (immutable once it leaves `draft`) | Edit/cancel a listing once `reserved`/`pending`/`confirmed` via raw update; insert mismatched mechanism-specific fields | RLS "owner or manager can edit while editable" (`listings.sql:61-65`); `mechanism_fields_match` check (`listings.sql:42-46`) |
| Advertiser | View listings where `status <> 'draft'` (browse) | Create, edit, or delete any listing | RLS "browse open listings" (`listings.sql:51-54`) grants `select` only |
| Manager | Same create/edit/delete rights as creator, for creators with an `active` `manager_creator_links` row | Edit a listing for a creator with no active link; edit past `draft`/`open` | Same RLS as Creator — `is_authorized_for_creator()` returns true only when link `status = 'active'` |
| Founder/Admin | **Nothing today — not built.** | Everything | No admin bypass exists on `creator_listings`. Flagged in `ARCHITECTURE.md` §8 risk 5 |

### 2. Browse / discovery

| Role | Can do | Cannot do | Enforced by |
|---|---|---|---|
| Creator | See own draft+open+all-status listings; see `public_profiles` subset of others | See other users' full `profiles` row (stripe ids, bio) | `public_profiles` view excludes sensitive fields |
| Advertiser | Browse/filter/shortlist all `status <> 'draft'` listings, mechanism clearly labeled | See `draft` listings | RLS "browse open listings" |
| Manager | Same browse rights, plus full visibility into draft/all-status listings for `active`-linked creators via roster dashboard | See draft listings of creators they aren't linked to | Same `is_authorized_for_creator()` gate |
| Founder/Admin | Nothing beyond a plain advertiser-level browse | See all drafts platform-wide without direct SQL access | Not built |

### 3. Negotiation actions per mechanism

**Mechanism A (`listing_offers`):** Creator submits counters/accepts offers (`submit_offer_as`, `accept_offer_as`). Advertiser submits offers/accepts creator counters, sequential turn-based (`accept_offer_as_advertiser` rejects if not the advertiser's own thread). Manager can act on the creator's behalf, band-checked via `check_price_band()` on both submit and accept — below-band actions are rejected outright by the RPC, not partially allowed. Founder/Admin: nothing; cannot view or intervene.

**Mechanism C (`listing_exclusivity_grants`):** Creator/Advertiser negotiate bilateral terms then convert to a deal (`propose_exclusivity_terms_as`, `convert_exclusivity_as`/`_advertiser`). Manager can propose terms freely (not band-checked — proposing isn't a commitment) but **converting** (locking a price) is band-checked. Founder/Admin: nothing; cannot view/force-expire/revoke a grant.

**Mechanism D (`reservations` + `deal_tiebreaks`/`tiebreak_bids`):** Advertiser places a reservation via `place_reservation`, which row-locks the listing (`select ... for update`) to prevent double-booking — the concurrency-safety `ARCHITECTURE.md` risk 2 exists to protect. Creator confirms final price at/above floor (`confirm_deal_as`, floor-checked). Manager confirms on the creator's behalf, band-checked. Sealed tiebreak bids are visible only to the bidding advertiser — "sealed means sealed" is enforced at the RLS `select` level, not just app logic. Founder/Admin: nothing manual; only a pg_cron system job (`run_expire_stale_reservations`) touches expiry, with no human-callable admin path.

### 4. Deal/contract lifecycle (`deals`)

| Role | Can do | Cannot do | Enforced by |
|---|---|---|---|
| Creator | View own deals; flag a dispute (`flag_dispute_as`) while `status in ('active','delivered')` | Confirm delivery (advertiser-only) | RLS "parties see own deal"; `flag_dispute_as` checks `is_authorized_for_creator` |
| Advertiser | View own deals; confirm delivery (`confirm_delivery_as`, starts 5-day auto-release clock); flag a dispute | Confirm delivery on a non-`active` deal; dispute a `completed`/`cancelled` deal | `confirm_delivery_as` checks `auth.uid() = advertiser_id` |
| Manager | View deals for `active`-linked creators; flag a dispute on the creator's behalf | Confirm delivery — **no manager path exists in `confirm_delivery_as` at all**, by design | RLS includes `is_authorized_for_creator(creator_id)` |
| Founder/Admin | **Documented intent only** ("founder-mediated resolution"). Today this means direct SQL/Supabase-dashboard access or manual Stripe dashboard action — zero in-app capability. **This is the flagship gap this document exists to close.** | Resolve a dispute, view all disputed deals platform-wide, issue a refund — through any UI or RPC. None exists. | `ARCHITECTURE.md` §8 risk 5; `ROADMAP.md` §2.5 defers the fix until dispute volume justifies it |

### 5. Escrow / payments (`escrow_transactions`)

All three existing roles get **read-only** visibility into their own deals' transaction history once Stripe is wired (the table is currently empty — Stripe integration is stubbed per `supabase/README.md`). No role can insert/update/delete a row; the table's own header comment states writes happen "only ever via the service role." Founder/Admin: system-driven via the Stripe webhook, not a human role at all — no in-app admin visibility exists today (would require direct Supabase dashboard/SQL access, same as disputes).

### 6. Manager delegation controls (`manager_creator_links`, `listing_price_bands`)

| Role | Can do | Cannot do | Enforced by |
|---|---|---|---|
| Creator | Full sole control — invite/revoke a manager, set/adjust bands at any time (not retroactive to confirmed deals) | — | RLS "creator controls own links", "for all using (creator_id = auth.uid())" |
| Advertiser | Nothing | View, create, or influence any delegation link/band | No RLS policy grants advertiser access |
| Manager | Accept a pending invite (own only); read own links/bands | **Revoke or modify a link or band** — confirms "only the creator can revoke, never the reverse" exactly | RLS "manager reads own links/bands" is `select`-only |
| Founder/Admin | Nothing | View/force-revoke a link or override a band | Not built |

### 7. Platform administration (net-new for Founder/Admin)

Every existing role can flag a dispute on their own deal and read only their own `audit_log` rows (scoped to `actor_id`/`acting_as_id` = self). **Nothing else in this area is implemented for any role.** Dispute resolution, audit-log-wide visibility, moderation, and account suspension are all undesigned. `ARCHITECTURE.md` §8 risk 5 names dispute resolution specifically as the gap to close first; `ROADMAP.md` §2.5 confirms it's deferred to Phase 2.

### Founder/Admin schema recommendation

**Add `profiles.is_platform_admin boolean not null default false`.** Not a new `role` enum value, not a manager-style relational join table, not a repurposing of the Stripe service role for interactive use.

- **Not the manager pattern:** manager delegation is data-driven and *relational* — a manager's authority is partial, per-creator, revocable per-relationship. Admin authority is global, non-relational, and there's exactly one founder account. Modeling it as a join table would invent a fake relationship to reuse a shape that doesn't apply.
- **Not the service-role pattern:** the service role is right for the Stripe webhook because that caller isn't a human making judgment calls — there's no meaningful "who clicked" to audit. Dispute resolution is the opposite: an interactive, judgment-driven action by a specific human. Running the admin UI purely on the service role would reintroduce the exact audit-attribution failure `ARCHITECTURE.md` §3 already rejected impersonation tokens for elsewhere — Postgres would see "the backend," not the founder.
- **Concrete shape:** the founder authenticates normally (own `auth.uid()`), no impersonation. A helper `is_platform_admin() returns boolean` mirrors `is_authorized_for_creator()` and gates new RLS `select` policies plus new `_as_admin`-suffixed `security definer` RPCs (e.g. `resolve_dispute_as_admin(deal_id, resolution, refund_amount_cents)`), matching the existing `_as` RPC naming convention. Admin RPCs still perform the actual privileged Stripe/escrow mutation via the service role internally, but the authorization check and the `audit_log.actor_id` attribution happen at the `is_platform_admin`/`auth.uid()` layer first — so the audit trail correctly shows the founder, not an opaque backend identity.
- This is strictly additive: one boolean column, one helper function, a handful of new RPCs/RLS clauses. No retrofit of `manager_creator_links`, no change to the Stripe webhook's existing service-role pattern.

---

## Part 2 — UI/UX Specification

**Method note:** Sidebar auth-gating was live-observed against the dev server. Full role-differentiated views (dashboards, listing-detail negotiation panels) could not be live-tested for all three roles without seeded multi-role credentials — those sections are source-read from the relevant `+page.server.ts`/`+page.svelte` files, a reliable proxy since these are server-authoritative `load` functions, not client-only conditionals. Noted inline where it matters.

**Headline finding:** the current UI already role-differentiates more than expected going in. `/dashboard` has three genuinely distinct branches per `profile.role`. `/listings/[id]` already computes `isDelegatedManager` server-side and renders an **"Acting as {manager} on behalf of {creator}"** banner — the exact affordance the audit design implies is needed. What's actually missing is (a) a handful of consistency gaps within that existing differentiation, and (b) the entire Founder/Admin role, which is the real net-new work.

### Creator

**Navigation:** Browse, Dashboard, Create Listing, "Managers" (delegation settings), Roadmap. No admin/moderation links, no separate escrow ledger (escrow is embedded read-only inside `/deal/[id]`).

**Screens:** `/dashboard` (own listings + a "needs attention" queue), `/create` (self pre-filled, no roster picker), `/listings/[id]` (owner controls when `isOwner`), `/deal/[id]` (dispute-flag button, no delivery-confirm button), `/settings/managers` (invite/revoke UI, full control).

**Conditional UI:** `isOwner` unlocks the "Manager auto-accept bands" card (creator-only, not shown to a delegated manager). Per-mechanism negotiation state renders inline ("Respond as {creator}" / "Confirm final price" / etc.).

**Gap to fix:** the dashboard's "needs attention" queue is Mechanism-D-only — a stale code comment claims A/C "aren't wired to real negotiation RPCs yet," but they are (per `rpc-mechanism-ac.sql`). Extend the query to also flag open A-offers and C-negotiations awaiting the creator's response.

**Empty states:** "You haven't created any listings yet. Create one." / "No managers linked yet." — both reasonable; the "all caught up" case for an empty needs-attention queue has no explicit message (minor polish gap).

### Advertiser

**Navigation:** Browse, Dashboard, Roadmap. Create Listing and the roster/managers link are both correctly absent — this is the cleanest role boundary in the app today, driven by a single `role === 'creator' || 'manager'` check.

**Screens:** `/dashboard` (reservations list + "browse more" CTA), `/browse` (generic, filterable by platform/mechanism, mechanism clearly badged per listing), `/listings/[id]` (only role that can initiate an offer/reservation/exclusivity request), `/deal/[id]` (only role with the "Confirm delivery" button), `/create` (plain-text refusal, no form).

**Gap to fix:** `/dashboard`'s advertiser branch only queries `reservations` (Mechanism D) — an advertiser with an open Mechanism-A offer thread or Mechanism-C exclusivity grant has no dashboard visibility into it today and must remember the listing URL. Extend to a unified query across `reservations`, `listing_offers`, and `listing_exclusivity_grants` filtered by `advertiser_id = self`.

**Gap to fix:** `/create` visited by an advertiser still renders the full page shell/title before showing the refusal message — since the nav link is already hidden, the only way here is a stale bookmark or typed URL; a server-side redirect to `/browse` with a toast is cleaner than a dead-end page.

**Gap to fix:** the zero-listings empty state on `/browse` ("be the first to create one") assumes the viewer can create a listing — wrong copy for an advertiser. Branch the CTA on `profile?.role`.

### Manager

**Navigation:** Browse, Dashboard, Create Listing (roster-gated inside the page), "My Roster" (same route as creator's link, label swapped), Roadmap.

**Screens:** `/dashboard` (roster cards + all-roster-listings grid, unfiltered by status — matches the matrix's "full visibility into draft/all-status listings" grant), `/create` (roster picker required before any other field enables), `/listings/[id]` (`isDelegatedManager` computed via a real active-link join, not client trust), `/settings/managers` (pending invites with Accept button + read-only active roster, correctly no revoke button).

**Bug to fix (highest priority outside the admin build-out):** `/deal/[id]` has **no manager-delegation check at all** — `isParty`/`isAdvertiser` compare `user.id` directly to `deal.advertiser_id`/`deal.creator_id`, with no `is_authorized_for_creator`-equivalent branch. A manager acting for a linked creator sees the contract read-only but **cannot flag a dispute**, even though the access matrix explicitly grants this. This is an existing promised capability that's silently broken today, not a net-new feature — fix by threading the same `isDelegatedManager` pattern already used on `/listings/[id]` into `deal/[id]/+page.server.ts`.

**Gap to fix:** the "Acting as X" banner exists only on `/listings/[id]` today. Replicate it on `/deal/[id]` (once the bug above is fixed) so the delegation cue is consistent everywhere a manager touches a creator's data.

**Gap to fix:** on Mechanism D, a manager sees the same "Confirm final price" input as the owner, but the UI doesn't show their authorized band before submission — they only learn a price was rejected from a raw RPC error string. Show the manager's band inline (reusing the existing bands query, scoped to `manager_id = self`), and on a band-rejection error specifically, show "This is below your authorized floor — send to {creator} for confirmation instead" rather than a generic error.

### Founder/Admin (net-new)

**Authentication:** No separate login — same `/login` flow as everyone else. `+layout.server.ts`'s existing full `profiles` select already returns `is_platform_admin` once the column exists, at zero extra query cost.

**Route protection:** new `src/routes/admin/+layout.server.ts` redirects to `/dashboard` (not `/login` — they're already authenticated, just unauthorized) if `!is_platform_admin`.

**Nav:** one more `Sidebar.svelte` conditional, gated on `is_platform_admin`, styled distinctly (red-tinted or an "ADMIN" badge) so the founder never confuses which mode they're in, since it's the same account, not an impersonated session.

**Routes:**
- `/admin` → redirects to `/admin/disputes`
- `/admin/disputes` — disputed-deals queue, sorted oldest-first (SLA-style), columns for both parties, price, mechanism badge, time-since-disputed (computed from the `audit_log` row where `action = 'deal.disputed'`, since `deals` has no dedicated timestamp for that moment). Empty state: plain "No open disputes." A secondary filter for recently-resolved disputes can reuse the same route via a query param later.
- `/admin/disputes/[dealId]` — three data panels plus a resolution action:
  1. **Deal terms** — same shape already queried on `/deal/[id]`, just without the RLS restriction to the two/three parties.
  2. **Escrow state** — `escrow_transactions` rows for this deal; explicit "No escrow transactions recorded yet — Stripe integration not live" empty state rather than a blank table.
  3. **Audit trail** — chronological `audit_log` rows for this deal (and its origin `reservations`/`listing_offers`/`listing_exclusivity_grants` row), actor resolved to display name, "acting as {creator}" sub-line reusing the existing banner phrasing, collapsed before/after JSON diff per row.
  4. **Resolution panel** (only when `status = 'disputed'`) — radio choice (Release to creator / Refund to advertiser with an editable amount / Cancel deal), a required notes textarea, destructive-styled confirm with an are-you-sure step, calling `resolve_dispute_as_admin`.

**Data needed vs. new:** every panel reuses existing tables (`deals`, `escrow_transactions`, `audit_log`) — the only genuinely new piece is the `resolve_dispute_as_admin` RPC family. This confirms the "thin UI over existing data" framing from Part 1's schema recommendation.

**Explicitly out of scope for this first pass** (lower priority per `ARCHITECTURE.md` risk 5): a platform-wide audit-log browser independent of a specific deal, account suspension, general moderation.

**By design, no in-app way to grant `is_platform_admin`, including to yourself.** The founder sets their own flag via a one-time manual SQL statement. An in-app grant path would be its own privilege-escalation surface.

---

## Part 3 — Engineering punch list (prioritized)

These are concrete, scoped items surfaced by this review, ready to hand to engineering:

1. ~~**Fix `/deal/[id]`'s missing manager-delegation check.** A manager's matrix-granted right to flag a dispute on a linked creator's behalf is currently unusable in the UI. Small, high-value fix — an existing security boundary (RLS/RPC) is already correct; only the frontend needs the same `isDelegatedManager` pattern `/listings/[id]` already has.~~ **SHIPPED** (Handoff #3, commit `0629b10`) — same delegation check + acting-banner pattern added to `/deal/[id]`.
2. ~~**Extend both dashboards' "needs attention"/reservation queries beyond Mechanism D.** Creator and advertiser dashboards each only surface D-related activity today; A and C are fully wired at the RPC layer (a stale code comment claims otherwise) but invisible on the dashboard.~~ **SHIPPED** (Handoff #3, commit `8c60c39`).
3. ~~**Fix two minor role-mismatched empty/redirect states:** `/create` should redirect advertisers rather than render a dead-end refusal page; `/browse`'s zero-listings CTA shouldn't tell an advertiser to "create one."~~ **SHIPPED** (Handoff #3, commits `1ccfb6b`, `a92bf42`) — plus the intent-aware `/login` redirect for logged-out `/create` visitors, which Handoff #3's brief bundled into the same item.
4. ~~**Add inline band visibility for managers on Mechanism D confirmation**, plus a distinct "send to creator" affordance on band-rejection, instead of surfacing a raw RPC error string.~~ **SHIPPED** (Handoff #3, commit `6ea020a`).
5. ~~**Build the Founder/Admin surface** — `profiles.is_platform_admin` column, `is_platform_admin()` helper, `resolve_dispute_as_admin` RPC family, `/admin/disputes` + `/admin/disputes/[dealId]` routes, per Part 2. This is the single largest item here, but per the schema recommendation it's additive and doesn't touch existing tables/RLS beyond new `or public.is_platform_admin()` clauses. **DEFERRED** — asked the founder directly during Handoff #3 execution; he chose to wait for the first real dispute (matches `ROADMAP.md` §2.5's volume-trigger framing) rather than build it as insurance now. Still fully spec'd and ready to build the moment that trigger fires.~~ **SHIPPED** (post-Handoff #3 follow-on, July 2026, commits `31e903f`, `27626ff`) — the founder revisited the deferral and asked to build it as insurance rather than wait. Implemented exactly per this document's Part 1 schema recommendation and Part 2 route spec, with no deviation.

Items 1–5 are all now shipped. Items 1–4 were UI-completeness fixes to security boundaries that already worked correctly server-side; item 5 was genuinely net-new and is the one place a fresh privilege boundary (`is_platform_admin`) was actually introduced — see `../handoffs/3rd.md`'s Completion Log for the full build record and the one manual step still required (granting yourself the flag).
