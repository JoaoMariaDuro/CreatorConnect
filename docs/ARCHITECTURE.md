# CreatorConnect — Technical Architecture

*Implements the product mechanism defined in `PRODUCT.md`. Written against the founder's proven stack: SvelteKit (Svelte 5) + Supabase + Stripe Connect, Hetzner only if actually needed. Assumes solo/small-team execution — every section optimizes for "fewest moving parts that are still correct," not maximal architecture.*

**Revision note (July 2026, following PRODUCT.md's Phase 0 revision):** PRODUCT.md's Phase 0 creator/manager interviews changed the pricing mechanism from a single imposed mechanic (mechanism D) to **creator choice of one of three mechanisms per listing** — A (fixed price + counter-offer), C (reserve-the-relationship / exclusivity window), or D (reserve-the-slot, unchanged from the original design). Mechanism B (open multi-bidder auction) remains out of scope; nothing about it changes here. This document has been revised to reflect that: Section 2's data model now supports all three mechanisms explicitly (new `pricing_mechanism` column, two new tables for A/C's lighter-weight negotiation records), Section 3 addresses whether delegation/band-checking is mechanism-aware, Section 5's job list is split by mechanism, and Section 8 gets a new risk for the tripled RPC/RLS surface area. Sections 4 (escrow), 6 (realtime), and 7 (Hetzner) are essentially unchanged, since all three mechanisms converge on the same `deals` + escrow flow — touched only where strictly necessary for consistency.

---

## 1. System overview

**Shape: SvelteKit as a thin, mostly-server-rendered app talking almost directly to Supabase; Supabase is the backend.** There is no separate custom API server in the request path. SvelteKit's job is UI, form handling, session-aware SSR, and a small set of `+server.ts` endpoints for the handful of operations that must not run as client-trusted RLS writes (Stripe webhook receivers, Stripe Connect account creation, tiebreaker resolution triggers). Supabase's job is everything stateful: Postgres (schema + RLS as the authorization layer), Auth (all three roles, one `auth.users` table), Storage (contract PDFs, listing media), Realtime (reservation/status pushes), and Edge Functions + pg_cron for the time-sensitive logic in Section 5.

Why this shape, not a custom Node/Express API layer: the founder's other project (Lota) already validated that SvelteKit + Supabase RLS can carry real authorization complexity without a bespoke API tier, and CreatorConnect's read-heavy surfaces (browse/filter/shortlist, dashboards) are exactly what RLS-gated `select` queries from SvelteKit load functions handle well. The places that genuinely need server-side trusted code — Stripe webhook verification, Stripe secret-key calls, and the tiebreaker/timeout jobs — are narrow and don't justify a whole parallel API layer; they live as SvelteKit server routes and Supabase Edge Functions respectively.

Hetzner's role is addressed head-on in Section 7 — short answer, it is not needed for v1.

**Does the three-mechanism scope change this shape? No — stated explicitly rather than left implicit.** The overall system shape (SvelteKit + Supabase, no custom API tier, no new infrastructure category) is unaffected by going from one pricing mechanism to three. What changes is entirely within Supabase's existing responsibilities: more tables (Section 2), more `security definer` RPCs (Section 3), and a wider but still purely SQL-scan-based pg_cron job list (Section 5) — all things the original architecture already anticipated as *patterns*, just not yet multiplied by three. Nothing about mechanisms A or C requires Realtime, Storage, or Auth to work differently in kind, only in the specific tables/events they cover.

---

## 2. Data model

Table sketch (Postgres, in the `public` schema unless noted). Not full DDL — columns are the ones that matter for relationships, RLS, and state machines.

### `profiles`
Extends `auth.users` (1:1, `id` = `auth.users.id`).
- `id uuid PK references auth.users`
- `role text check in ('creator','advertiser','manager')` — **a user's primary role**. Note: a manager account is *also* effectively acting through creator identities via delegation (Section 3), not via multiple rows here.
- `display_name`, `avatar_url`, `platform_handles jsonb` (YouTube/IG/TikTok handles)
- `stripe_connect_account_id text nullable` — set once onboarding completes (creators and managers who receive payouts; advertisers get a Stripe *Customer* id instead, stored separately or in `stripe_customer_id`)
- `stripe_customer_id text nullable`
- `follower_range`, `niche_tags` — creator discovery filters
- RLS: **enabled**. Everyone can `select` a public-safe subset of any profile (needed for browse — implement via a `public_profiles` view rather than loosening the base table). Row owner can `update` their own row. No cross-row updates.

### `creator_listings`
- `id uuid PK`
- `creator_id uuid references profiles(id)` — the creator who owns the inventory (always the creator, even if a manager created the row — see Section 3)
- `created_by uuid references profiles(id)` — who actually inserted/edited it (creator or delegated manager); used for audit, not authorization
- `platform text`, `content_type text`, `availability_window daterange`
- `pricing_mechanism text check in ('A','C','D')` — **new.** Chosen by the creator at listing creation (PRODUCT.md Section 4/5) and immutable after the listing leaves `draft` (changing the mechanism on a live listing would orphan any in-flight offer/exclusivity/reservation record — if a creator wants a different mechanism, they cancel and relist).
- `floor_price_cents int`, `currency text default 'usd'`
- `reservation_deadline timestamptz`
- `exclusivity_window interval` — **new**, mechanism-C only (see below).
- `performance_stats jsonb`, `audience_demographics jsonb` (manual entry, MVP)
- `constraints text` (e.g. "no competitor brands to X")
- `status text check in ('draft','open','reserved','confirmed','expired','cancelled')`
- RLS: **enabled**. Public `select` where `status = 'open'` (browse). Owner (`creator_id`) or an authorized manager (via `manager_creator_links`, checked by a helper function — Section 3) can `insert`/`update`/`delete` while `status in ('draft','open')`. Once `status` leaves `open`, only the escrow/reservation/negotiation workflow (via `security definer` functions, not raw `update`) can move it further — prevents a creator or manager editing a listing out from under an active offer/exclusivity grant/reservation, regardless of mechanism.

**Design decision: mechanism-specific fields as nullable columns on `creator_listings`, not a `jsonb` blob or per-mechanism child tables. Stated explicitly, not left open.**

Three options were considered:
1. **Nullable columns on the same table** (chosen). `floor_price_cents` doubles as mechanism A's asking price and mechanism D's floor price (see reuse note below); `reservation_deadline` is D-only; `exclusivity_window` is C-only. For any given row, exactly one mechanism's columns are populated and the rest are `null`, enforced by a `check` constraint keyed on `pricing_mechanism` (e.g. `check (pricing_mechanism != 'D' or reservation_deadline is not null)`).
2. **A `listing_pricing_details jsonb` column.** Rejected: it hides mechanism-specific fields from the schema (no `check` constraints, no foreign-key-style guarantees, harder to query/index for browse filters like "listings with floor price under $X"), and browse/filter is one of the two read-heavy surfaces this architecture is built around (Section 1). A jsonb blob would force every filter query to reach into jsonb operators instead of plain indexed columns.
3. **Per-mechanism child tables** (`listing_terms_a`, `listing_terms_c`, `listing_terms_d`, 1:1 with `creator_listings`). Rejected for MVP: with only 2-3 mechanism-specific fields per mechanism, three extra tables (plus the RLS policies and joins they each need) is more moving parts than the problem justifies — this would be the right call if a mechanism's field count grew substantially (e.g. D getting five more fields), but at current size it just multiplies the join surface for every listing read without a corresponding safety or query-clarity win.

Reasoning: options 2 and 3 both trade away something this architecture already leans on — option 2 loses queryability on the browse path, option 3 adds joins/RLS surface disproportionate to three small fields. Nullable columns with a `check` constraint keep the state machine legible in the schema itself (a reviewer can see which fields matter for which mechanism without cross-referencing a child table or unpacking jsonb) while costing nothing extra on the read path that matters most.

**Naming note on `floor_price_cents` for mechanism A:** rather than adding a separate `asking_price_cents` column, mechanism A reuses `floor_price_cents` as "the asking price" — semantically this is not really a floor (there's no reservation/tiebreaker mechanic in A for it to be a floor *for*), but adding a duplicate column with identical type/units for the sole purpose of a more accurate name isn't worth it at this field count. The column comment in the actual migration should say so explicitly (`-- for mechanism A, this is the asking price; for mechanism D, this is the floor price a reservation must meet or exceed`) so future readers don't have to infer it from `pricing_mechanism`.

### `reservations` (mechanism D only)
**Only ever populated for `pricing_mechanism = 'D'` listings.** Mechanisms A and C skip this table entirely — they use the lighter-weight `listing_offers` and `listing_exclusivity_grants` tables below instead of a deposit-and-reservation state machine, because neither has a deposit or a slot-locking hold to represent.
- `id uuid PK`
- `listing_id uuid references creator_listings(id)` — application-level invariant (enforced in the `place_reservation` RPC, not a `check` constraint, since `check` can't join): `creator_listings.pricing_mechanism = 'D'` for this `listing_id`.
- `advertiser_id uuid references profiles(id)`
- `deposit_amount_cents int`, `deposit_payment_intent_id text` (Stripe PaymentIntent id)
- `status text check in ('pending_deposit','held','tiebreak_pending','confirmed','expired','lost_tiebreak','cancelled')`
- `confirmation_deadline timestamptz` — set to `now() + response_window` when `status` becomes `held`
- `created_at timestamptz`
- RLS: **enabled**. Advertiser sees their own rows (`advertiser_id = auth.uid()`). Creator (or delegated manager) sees rows where `listing_id` resolves to a listing they own/manage. No one can directly `update status` — status transitions happen through `security definer` RPC functions (`place_reservation`, `confirm_deal`, `expire_reservation`) so the state machine can't be bypassed by a client crafting an `update`.

### `listing_offers` (mechanism A only — new)
The lighter-weight negotiation record for fixed-price + counter-offer. Sequential, single-advertiser-at-a-time per PRODUCT.md Flow 2 — no deposit, no concurrent-advertiser contention to resolve, so no tiebreaker analog is needed here.
- `id uuid PK`
- `listing_id uuid references creator_listings(id)` — application-level invariant: `pricing_mechanism = 'A'` for this listing, enforced in the RPC layer.
- `advertiser_id uuid references profiles(id)` — the single advertiser this negotiation thread is with (a listing can have sequential/historical threads with different advertisers over time, but only one `open` thread at a time per listing, enforced the same way D prevents double-holding a slot — see Section 8 risk 2 for why this pattern matters).
- `offer_amount_cents int` — the current amount on the table, whoever proposed it last.
- `proposed_by text check in ('advertiser','creator')` — whose turn it isn't (i.e. who needs to respond next is the *other* party).
- `status text check in ('open','accepted','rejected','withdrawn','expired')` — MVP has no hard timeout/expiry job for A (Section 5), so `expired` exists in the enum for future-proofing (e.g. if a stale-thread cleanup is added later) but nothing sets it yet.
- `parent_offer_id uuid nullable references listing_offers(id)` — chains a counter to what it's countering, so the full back-and-forth is reconstructable for the creator/advertiser UI and for `audit_log`.
- `created_at timestamptz`
- RLS: **enabled**. Advertiser sees their own rows (`advertiser_id = auth.uid()`). Creator (or delegated manager, band-checked — Section 3) sees rows where `listing_id` resolves to a listing they own/manage. All state transitions (`accept_offer_as`, `counter_offer_as`, `reject_offer_as`) go through `security definer` RPCs, same pattern as `reservations`, for the same reason: no client-crafted `update` should be able to jump straight to `accepted`.

### `listing_exclusivity_grants` (mechanism C only — new)
The lighter-weight negotiation record for reserve-the-relationship. No deposit, no binding hold on price — this table tracks *access*, not a financial commitment; the actual deal terms, once bilaterally agreed, are recorded directly in `deals` (same convergence point as A and D).
- `id uuid PK`
- `listing_id uuid references creator_listings(id)` — application-level invariant: `pricing_mechanism = 'C'` for this listing.
- `advertiser_id uuid references profiles(id)` — who holds (or held) the exclusivity.
- `window_starts_at timestamptz`, `window_ends_at timestamptz` — computed at grant time as `now()` / `now() + creator_listings.exclusivity_window`.
- `status text check in ('active','converted','expired','revoked')` — `converted` means a real deal was struck within the window (a `deals` row now exists referencing this grant); `expired` means the window lapsed with no conversion, at which point access opens to the next advertiser; `revoked` covers a creator manually ending the grant early (e.g. bad-faith advertiser), mirroring D's `cancelled`.
- `created_at timestamptz`
- RLS: **enabled**. Advertiser sees their own rows. Creator/manager sees rows for listings they own/manage. Transitions via `security definer` RPCs (`request_exclusivity_as`, `convert_exclusivity_as`, `expire_exclusivity` — the last one is the cron-driven system transition, Section 5). Unlike `reservations`, there is no deposit-refund step on expiry — expiry is a pure access-state change, which is exactly why this table is lighter-weight than `reservations` rather than a copy of it with nullable deposit fields.

### `deal_tiebreaks` (supports the closed-set sealed-bid mechanic — mechanism D only)
- `id uuid PK`
- `listing_id uuid references creator_listings(id)`
- `opened_at`, `closes_at timestamptz`
- `status text check in ('open','resolved')`
- `winning_reservation_id uuid nullable references reservations(id)`

### `tiebreak_bids`
- `id uuid PK`
- `tiebreak_id uuid references deal_tiebreaks(id)`
- `reservation_id uuid references reservations(id)` — only reservations already in `tiebreak_pending` for that listing may bid (enforced in the RPC, not just RLS)
- `bid_amount_cents int`, `submitted_at timestamptz`
- RLS: **enabled**, `insert`-only for the advertiser who owns `reservation_id`, **no `select` for other advertisers** — sealed means sealed; only the creator (post-resolution) and the platform see all bids. This is the one table where read-restriction is as important as write-restriction.

### `deals` (the confirmed contract — the mechanism-agnostic convergence point)
**Confirmed still holding, stated explicitly rather than silently assumed: this table was already designed as the point where all mechanisms converge, and that design does not need to change now that there are three mechanisms instead of one.** Whatever produced the agreement — D's `confirm_deal` (reservation-backed), A's `accept_offer` (offer-backed), or C's `convert_exclusivity` (bilaterally-negotiated, exclusivity-backed) — writes into the same `deals` row shape, and everything downstream of `deals` (escrow, Section 4; realtime/notifications, Section 6) is unchanged by which mechanism produced the row. The one schema change needed is loosening the source-of-truth foreign key from "always a reservation" to "one of three possible origins":
- `id uuid PK`
- `reservation_id uuid nullable references reservations(id)` — **now nullable**; populated only when the deal originated from mechanism D.
- `offer_id uuid nullable references listing_offers(id)` — **new**; populated only when the deal originated from mechanism A.
- `exclusivity_grant_id uuid nullable references listing_exclusivity_grants(id)` — **new**; populated only when the deal originated from mechanism C.
- `check` constraint: exactly one of `reservation_id`, `offer_id`, `exclusivity_grant_id` is non-null — the deal always has exactly one traceable origin, regardless of mechanism. This is the schema-level expression of "convergence point" — one `deals` row, one origin pointer, three possible shapes of what fills it.
- `listing_id`, `creator_id`, `advertiser_id`, `manager_id nullable`
- `final_price_cents int`, `confirmed_at timestamptz`
- `deliverable_spec jsonb` (from listing + any confirmed terms), `delivery_due_at timestamptz`
- `disclosure_terms text` (FTC boilerplate, generated not editable), `cancellation_terms text`
- `contract_pdf_path text` (Supabase Storage path)
- `status text check in ('active','delivered','disputed','completed','cancelled')`
- `delivery_confirmed_at timestamptz nullable`, `auto_release_at timestamptz` (delivery_confirmed_at/delivered-flag time + 5 days)
- RLS: **enabled**. Visible to `creator_id`, `advertiser_id`, linked manager, nobody else. Unchanged by mechanism — this policy never needed to know which mechanism produced the deal, which is itself evidence the convergence design holds.

### `escrow_transactions` (Stripe Connect state ledger — see Section 4 for why this shadow ledger exists)
- `id uuid PK`
- `deal_id uuid references deals(id)`
- `kind text check in ('deposit','booking_balance','payout_creator','payout_manager_commission','refund')`
- `amount_cents int`
- `stripe_object_type text` (`payment_intent` | `transfer` | `refund`), `stripe_object_id text`
- `status text check in ('pending','succeeded','failed','reversed')`
- `created_at timestamptz`
- RLS: **enabled**, read-only for the two/three parties on the linked deal; **all writes happen from the Stripe webhook handler using the service role**, never from client-side RLS-governed inserts. This is deliberate — escrow state must be a mirror of Stripe truth, not something a client can assert.

### `manager_creator_links` (POA relationship — full design in Section 3)
- `id uuid PK`
- `manager_id uuid references profiles(id)`
- `creator_id uuid references profiles(id)`
- `status text check in ('pending','active','revoked')` — creator-initiated approval required to go `active`
- `default_auto_accept_floor_cents int nullable` — global band, can be overridden per-listing
- `commission_bps int default 500` (5%, per PRODUCT.md)
- `granted_at`, `revoked_at timestamptz`
- unique constraint on `(manager_id, creator_id)`
- RLS: **enabled**. Creator can `insert`/`update`/`delete` (revoke) their own links. Manager can `select` their own links and `update` only non-authorization fields if any (in practice: manager has no write access to this table at all beyond accepting a pending invite — everything else is creator-controlled, matching PRODUCT.md's "only the creator can revoke, never the reverse").

### `listing_price_bands` (per-listing override of the manager's auto-accept authority)
- `id uuid PK`
- `listing_id uuid references creator_listings(id)`
- `manager_id uuid references profiles(id)`
- `auto_accept_floor_cents int` — "auto-accept any confirmed price ≥ X for this listing"
- RLS: creator-writable only; manager read-only (needs to see the band to know what they're authorized to do).

### `audit_log`
- `id uuid PK`
- `actor_id uuid references profiles(id)` — who actually clicked
- `acting_as_id uuid nullable references profiles(id)` — the creator, if this was a delegated manager action
- `action text` (e.g. `listing.update`, `reservation.confirm`, `manager_link.revoke`)
- `target_table text`, `target_id uuid`
- `before jsonb nullable`, `after jsonb nullable`
- `created_at timestamptz default now()`
- RLS: **insert-only via triggers/RPCs** (never direct client insert); `select` restricted to the creator whose data was touched (`acting_as_id = auth.uid() or actor_id = auth.uid()`) plus the platform (service role, for founder-mediated disputes).

### Relationship summary
`profiles (creator)` 1—N `creator_listings`, and `creator_listings.pricing_mechanism` determines which of three negotiation tables a given listing can produce rows in: `reservations` (D), `listing_offers` (A), or `listing_exclusivity_grants` (C) — each N—1 `profiles (advertiser)`. All three converge N—1 into `deals` via exactly one of `reservation_id` / `offer_id` / `exclusivity_grant_id`; `deals` 1—N `escrow_transactions`. `manager_creator_links` is the N:N join between manager and creator profiles that everything delegated hangs off of, across all three mechanisms; `audit_log` fans in from every mutating RPC, regardless of mechanism.

---

## 3. Auth & authorization design

**Mechanism: no impersonation tokens, no session-switching. A single Supabase Auth session per manager; all delegated authority is expressed as data (`manager_creator_links` + `listing_price_bands`) and enforced by RLS policies plus `security definer` RPC functions that check delegation at write time and always log to `audit_log` in the same transaction.**

### Why not impersonation tokens
The obvious alternative — issue the manager a short-lived JWT/session "as" the creator (Supabase supports minting custom sessions) — is tempting because it makes RLS trivially reuse the creator's own policies. Rejected for three concrete reasons specific to this product:
1. **Band enforcement doesn't fit an impersonation model cleanly.** A manager isn't "fully the creator" — they're the creator *except* for a specific dollar threshold and a specific set of forbidden actions (exclusivity clauses, relationship removal). An impersonated session has no natural place to carry "but only up to $X" — you'd end up re-deriving the same band-check logic outside the session anyway, so the impersonation buys nothing.
2. **Audit trail becomes fragile.** If the manager is holding a creator-identity session, every downstream log (`created_by`, Postgres `auth.uid()` in triggers) shows the creator, not the manager, unless you thread a second "true actor" field through everywhere by hand — which is exactly the `actor_id`/`acting_as_id` split this design uses anyway, just done worse (bolted onto impersonation instead of being the primary mechanism).
3. **Revocation timing.** PRODUCT.md requires "only the creator can revoke, and it should take effect immediately." With data-driven delegation, revocation is a single `update manager_creator_links set status = 'revoked'` and the next RPC call re-checks and fails closed. With impersonation sessions, you'd need to track and invalidate potentially-live tokens — more moving parts for the same guarantee.

### The mechanism, concretely
- Manager authenticates normally as themselves (`auth.uid()` = manager's own id, always).
- Every mutating action a manager takes "on behalf of" a creator goes through a `security definer` Postgres function (not a raw table `insert`/`update` from the client), e.g. `create_listing_as(creator_id, ...)`, `confirm_deal_as(creator_id, reservation_id, price_cents)`. These functions:
  1. Verify `auth.uid()` is either `creator_id` itself, or has an `active` row in `manager_creator_links` for that `creator_id`.
  2. If acting as manager and the action is price-confirmation, check `price_cents >= coalesce(listing_price_bands.auto_accept_floor_cents, manager_creator_links.default_auto_accept_floor_cents)`. If the price is below the band, the function raises — the UI routes this to a "request creator confirmation" flow instead (a notification to the creator; the manager cannot force it through).
  3. Perform the actual write.
  4. Insert into `audit_log` with `actor_id = auth.uid()`, `acting_as_id = creator_id` (null if acting as self), before/after snapshots — in the same transaction, so there is no path where the mutation succeeds but the audit row doesn't.
- Plain RLS `select` policies (not RPCs) handle reads, using a small helper function `is_authorized_for_creator(creator_id uuid) returns boolean` (`creator_id = auth.uid() OR exists (select 1 from manager_creator_links where manager_id = auth.uid() and creator_id = creator_id and status = 'active')`) reused across every creator-scoped table's policy. This keeps the "who can see this creator's stuff" rule defined once and consistently applied to `creator_listings`, `reservations`/`listing_offers`/`listing_exclusivity_grants` (via join), `deals`, `escrow_transactions` (read-only), etc.
- Irrevocable-by-manager actions (revoking the link itself, accepting outside-band price, exclusivity/usage-rights terms) simply have **no RPC path for the manager at all** — they're not band-gated, they're absent from the manager's callable surface. This is stronger than a runtime check: there's no function a compromised or buggy client could call to do it.

### Are the delegation RPCs mechanism-aware? Yes — addressed explicitly, not left implicit.

The band-check logic itself (`price_cents >= band_floor`) is identical in substance across all three mechanisms — "is the price a manager is about to lock in on the creator's behalf at or above what the creator pre-authorized" doesn't change meaning depending on how that price was arrived at. But **the RPC surface is not one set of functions with a mechanism parameter — it's three parallel families of RPCs, one per mechanism, each calling the same shared band-check helper.** Concretely:

- **Mechanism D:** `confirm_deal_as(creator_id, reservation_id, price_cents)` — band-checks `price_cents` against the listing's band before confirming. Unchanged from the original design.
- **Mechanism A:** `accept_offer_as(creator_id, offer_id)` and `counter_offer_as(creator_id, offer_id, new_amount_cents)` — band-check applies to *both*: accepting an advertiser's offer outright must check the offer's `offer_amount_cents` against the band before a manager can accept it, and countering must check the manager's own counter-amount isn't being used to sneak a sub-band acceptance through a "counter that the advertiser will obviously just accept" (a manager proposing a lowball counter is functionally the same authorization risk as accepting a lowball offer directly, so the same check applies to the counter's `new_amount_cents`, not just to terminal `accept`).
- **Mechanism C:** `request_exclusivity_as(creator_id, listing_id, advertiser_id)` and `convert_exclusivity_as(creator_id, grant_id, price_cents, deliverable_spec)` — granting exclusivity itself is not a price commitment (no band check needed, matches PRODUCT.md's framing of C as low-commitment), but **conversion** (turning the bilaterally-negotiated terms into a real deal) is exactly where a price gets locked in, so `convert_exclusivity_as` band-checks `price_cents` the same way `confirm_deal_as` and `accept_offer_as` do.

**Why this is a family of RPCs and not one polymorphic function:** each mechanism's write touches a different table (`reservations` vs. `listing_offers` vs. `listing_exclusivity_grants`) with different pre-conditions to verify (D checks reservation status and floor price; A checks offer thread status and whose turn it is; C checks grant window and status) before the shared band-check even runs. Collapsing these into one function with a `mechanism` parameter and branching logic inside would make the function harder to reason about and test in isolation, and would reintroduce exactly the kind of "one function doing three things" complexity the rest of this design avoids by keeping each RPC narrowly scoped. The shared piece — the band-check itself — is factored out into a single helper function (`check_price_band(listing_id, price_cents) returns boolean`) that all three families call, so the actual authorization *logic* is defined once even though the *call sites* are tripled. This is the concrete design answer to the question this section exists to resolve: band enforcement works the same way in substance across all three mechanisms, but the RPC surface area needed to enforce it triples, which is exactly what Section 8's new risk (risk 6) is about.

### The three roles in Supabase Auth
One `auth.users` table, `profiles.role` as the primary role. Advertiser and creator are straightforward RLS-by-ownership. Manager is not a fourth permission tier in Postgres roles — it's a regular authenticated user whose extra reach comes entirely from rows in `manager_creator_links`, checked by the helper function above. This means adding "manager can also do X" later is a policy/RPC change, not a schema migration on `profiles`.

---

## 4. Payments & escrow integration

**Account type: Stripe Connect Express**, not Standard or Custom. Reasoning: Custom would put KYC/compliance UI burden on CreatorConnect that a solo founder shouldn't own pre-PMF; Standard hands creators a full Stripe Dashboard and a more independent relationship with Stripe than the platform needs and makes it harder to enforce the platform's fee/hold logic cleanly; Express gives Stripe-hosted onboarding (creators/managers complete a Stripe-branded flow, not a custom KYC form CreatorConnect has to build and maintain) while still letting the platform control payouts, fees, and timing programmatically — the right point on the build-effort-vs-control curve for this stage. Managers who receive commission need their own Express account too (commission is a separate destination, not a manual invoice, per PRODUCT.md).

### Mapping the 10% deposit / 50-50 flow to Stripe Connect primitives
**Scope note: the deposit step (item 1 below) is mechanism-D-specific — A and C have no deposit, per Section 2/5.** The 50/50 booking-confirmation-to-delivery escrow split (items 2-4) is mechanism-agnostic and applies uniformly once *any* mechanism produces a confirmed `deals` row (Section 2's convergence point) — for A and C, item 2's "once the creator confirms `final_price_cents`" trigger is `accept_offer_as`/`convert_exclusivity_as` instead of `confirm_deal_as`, but the Stripe mechanics from that point forward are identical. This is **not** a single PaymentIntent per deal — it's a sequence, because the amounts and destinations aren't known in full at reservation/negotiation time (final price isn't set until confirmation, and the platform fee/manager commission are only computable once that price exists).

1. **Reservation deposit (10% of floor price):** a PaymentIntent on the *platform's* Stripe account (not a direct charge to the connected account yet), `capture_method: automatic`, amount = 10% of floor price, with the advertiser's saved payment method. This is intentionally *not* yet a `transfer` to the creator's connected account — the slot isn't confirmed, and if the tiebreaker or expiry loses this reservation, the deposit needs to be refunded (via Stripe `refunds`, not a transfer reversal) with no creator-side money movement to unwind. `escrow_transactions.kind = 'deposit'` mirrors this PaymentIntent's lifecycle via webhook.
2. **Booking confirmation (remaining amount up to 50% of final price):** once the creator confirms `final_price_cents`, a second PaymentIntent is created for `final_price_cents * 0.5 - deposit_already_paid` (the deposit counts toward the 50%). On success, the platform creates a **Transfer** to the creator's (and, if applicable, manager's) connected account for their net share, computed as `final_price_cents * 0.5 * (1 - platform_fee_bps/10000 - manager_commission_bps/10000)`, with the fee and commission amounts staying on the platform account. Using `transfer_data`/manual transfers rather than `on_behalf_of` destination charges at PaymentIntent-creation time, because the platform needs a moment between "advertiser paid" and "creator gets paid" to apply the fee split and to allow a dispute to freeze the *second* transfer window (Section escrow logic below) — manual transfers give explicit control over exactly when money moves to the connected account, whereas automatic destination charges move it (net of `application_fee_amount`) immediately on capture, which is too early for the delivery-gated half.
3. **Delivery balance (remaining 50%):** a third PaymentIntent for the second half, charged to the advertiser either at booking confirmation (charge everything up front, hold the *transfer* not the *charge*) or closer to delivery — **recommendation: charge the full 100% (deposit + both halves) at booking confirmation**, and use the *transfer timing* (not charge timing) as the escrow mechanism. This is simpler and more standard for marketplace escrow-via-Connect: the money sits on the platform's Stripe balance (this is exactly what "agent of payee" / Connect's holding pattern is for — the platform is legally handling funds as Stripe's sub-merchant flow, not as an unlicensed money transmitter, per the PRODUCT.md hard constraint) between charge and transfer. So: **charge 100% up front at booking confirmation** (matches advertiser certainty expectations from PRODUCT.md Flow 2), **transfer 50% immediately, transfer the remaining 50% only on delivery confirmation or auto-release**. This also sidesteps a second card-charge failure risk 5 days into the deal.
4. **Auto-release / dispute freeze:** the second Transfer (the delivery-gated 50%) is created either by the delivery-confirmation RPC (advertiser sign-off) or by the scheduled auto-release job (Section 5) — both call the *same* `release_delivery_balance(deal_id)` `security definer` function, which checks `deals.status != 'disputed'` before creating the Transfer. A dispute flag is simply `deals.status = 'disputed'`, set by either party via RPC before `auto_release_at`; this is checked inside the same function so there's no race where a dispute lands after the transfer already fired (the function does the check and the Stripe call inside one code path, and the scheduled job is the only non-interactive caller).
5. **Refunds (lost tiebreak, expired reservation, no-confirmation):** plain Stripe `refunds` against the original deposit PaymentIntent — no connected-account money was ever moved, so there's nothing to reverse on the creator side.

### Reliability: webhooks, not client callbacks, are the source of truth
Every `escrow_transactions` write happens from a Stripe webhook handler (`+server.ts` route, verifies `stripe-signature`, uses the service role key), listening for `payment_intent.succeeded`, `payment_intent.payment_failed`, `transfer.created`, `transfer.reversed`, `charge.refunded`, `account.updated` (Express onboarding completion). The client (SvelteKit UI) never marks a deposit/payment as succeeded directly — it polls/subscribes (Realtime, Section 6) for the `escrow_transactions` row the webhook writes. This avoids the classic marketplace bug where a client-side "payment succeeded" redirect is trusted before the webhook confirms it.

---

## 5. Time-sensitive/background job handling

**Recommendation: Supabase pg_cron + Edge Functions, no Hetzner involvement.** Concretely:

**Jobs are now scoped per mechanism, not uniform — stated explicitly below rather than left to be inferred from the table list.** Mechanism A has no deadline-driven jobs at all (sequential accept/reject/counter has no timeout in MVP — see the `listing_offers.status = 'expired'` note in Section 2, which exists in the enum for future-proofing but nothing sets it today). Mechanism C needs its own expiry-scan job, distinct from D's, because C's deadline (`exclusivity_window`) lives on a different table with different consequences (access reopens, nothing is refunded) than D's (`confirmation_deadline`/`reservation_deadline`, which trigger a deposit refund). Mechanism D's jobs are unchanged from the original design.

- **pg_cron** runs a scheduled job every 5 minutes (`select cron.schedule(...)`) that does the *detection* in plain SQL, entirely inside Postgres, no network hop needed for the common cases:
  - *Mechanism D (unchanged):* `reservations` where `status = 'held' and confirmation_deadline < now()` → call `expire_reservation(id)` (refunds deposit via a queued Stripe call, see below, sets listing back to `open`).
  - *Mechanism D (unchanged):* `creator_listings` where `pricing_mechanism = 'D' and status = 'open' and reservation_deadline < now()` → `status = 'expired'`.
  - *Mechanism D (unchanged):* `deal_tiebreaks` where `status = 'open' and closes_at < now()` → resolve (pick highest sealed bid among `tiebreak_bids`, mark winner/losers, trigger refunds for losers).
  - *Mechanism C (new):* `listing_exclusivity_grants` where `status = 'active' and window_ends_at < now()` → call `expire_exclusivity(id)` (sets grant to `expired`, reopens the listing to other advertisers — no Stripe call, no refund, since C never took a deposit; this is why it's a lighter job than D's, mirroring why `listing_exclusivity_grants` is a lighter table than `reservations`).
  - *Mechanism A (none):* no pg_cron scan targets `listing_offers` — there is no deadline field on that table to scan for, by design (PRODUCT.md's Flow 2 describes A as purely sequential accept/reject/counter with no response-window timeout). If a future revision adds a stale-offer cleanup, it would need a new deadline column first; nothing here today assumes one.
  - *Mechanism-agnostic (unchanged):* `deals` where `status = 'active' and delivery_confirmed_or_flagged = true` (or "delivered" state) `and auto_release_at < now() and status != 'disputed'` → call `release_delivery_balance(id)`. This job doesn't need to know which mechanism produced the deal — another instance of `deals` being the convergence point (Section 2).
- **Why pg_cron for detection, not just Edge Function cron:** the state-transition logic (find rows past deadline) is naturally SQL, needs no external API call, and pg_cron running *inside* the same database avoids an extra hop and extra failure mode (Edge Function cold start, network) for logic that's fundamentally "scan a table for expired timestamps." This is the same pattern Lota already uses successfully for its own scheduled jobs.
- **Why Edge Functions still matter here, not pg_cron alone:** the Stripe-calling side (`refund`, `transfer`) needs the Stripe secret key and needs to be idempotent/retryable against a third-party API — that's not something to do as a `pg_net` HTTP call fired directly from a cron job with no retry/backoff handling. Pattern: pg_cron detects and flips state to an intermediate `*_pending` status (e.g. `reservations.status = 'expiring'`) and inserts a row into a lightweight `outbox` table (`kind`, `payload jsonb`, `status`, `attempts`); a Supabase Edge Function, also on a pg_cron-driven schedule (every 1-2 minutes) or triggered by a Database Webhook on `outbox` insert, drains that table, makes the Stripe call, and on success flips the row to its terminal status. This gives at-least-once delivery with retry counting without needing a queue product — a few hundred deals/month of MVP volume doesn't justify anything heavier.
- **Database Webhooks** are used narrowly: on `escrow_transactions` insert/update (from the Stripe webhook handler) to push a Realtime-visible status change, and optionally on `deals` status change to trigger notification emails (Section 6) — not as the primary scheduling mechanism, since Database Webhooks fire on data changes, not on time elapsing, and most of what this section needs is "nothing happened by a deadline," which only a poll (cron) can detect.
- **Explicitly not on Hetzner:** there's no reason to run a cron daemon or job queue on a VPS for this. pg_cron + Edge Functions cover "scan for expired state" and "make an idempotent external API call reliably" without operating a server. The founder already knows this pattern works for time-driven jobs from Lota's alerting system (`box-runlog-key`/`alerts-c1-a4` in Lota used a cron-driven approach too, just on the box because Lota's job needed a long-running scraper process — CreatorConnect's jobs are all short SQL scans + single API calls, which is squarely inside Edge Functions' execution model).

---

## 6. Realtime & notifications

**Realtime-necessary events** (Supabase Realtime, Postgres change subscriptions, scoped by the same RLS the tables already have — no separate authorization layer needed for Realtime). **Note on the three-mechanism scope change: the set of tables to subscribe to grows from one negotiation table to three, but the mechanism itself (RLS-scoped Postgres change subscriptions) doesn't change in kind** — this is a matter of adding subscriptions on `listing_offers` and `listing_exclusivity_grants` alongside the existing `reservations` one, not a new realtime pattern:
- Creator dashboard: new reservation on a D listing (`reservations` insert), new/countered offer on an A listing (`listing_offers` insert/update), new exclusivity request on a C listing (`listing_exclusivity_grants` insert) — each is the highest-value realtime moment for its mechanism, since each starts a clock the creator (or advertiser, for A's counters) needs to act within.
- Advertiser: reservation status change (`held → confirmed`, `→ lost_tiebreak`, `→ expired`) for D; offer status change (`open → accepted/rejected`, or a counter arriving) for A; exclusivity grant status change (`active → converted/expired/revoked`) for C; and `escrow_transactions` updates (deposit succeeded/failed) for D specifically, since A and C have no deposit step.
- Manager dashboard: roster-wide feed of the above, across all three mechanisms and all `active`-linked creators (same subscription pattern, filtered via the `is_authorized_for_creator` relationship — Realtime respects RLS so this is still a `select`-policy problem, not a new mechanism, even with three source tables instead of one).
- Confirmation-window countdown ("closing in 3h") is a client-side timer against `confirmation_deadline` (D) or `window_ends_at` (C), not a server push — no need to push every tick. Mechanism A has no countdown to render, matching Section 5's "no deadline-driven jobs for A."

**Notifications (email, not just in-app)** — because confirmation windows and auto-release are exactly the kind of deadline a user misses if the only signal is an in-app badge:
- Provider: **Resend**, matching the founder's existing choice on Lota (`alerts-c1-a4`) — same account/domain infra reusable, no new vendor evaluation needed.
- Trigger point: the same Edge Function outbox pattern from Section 5 — when a reservation is placed, when the confirmation window is at ~75% elapsed (a second pg_cron check, "send reminder if `confirmation_deadline - now() < 6h` and reminder not yet sent"), when a deal is confirmed/disputed/auto-released. Each is an outbox row of `kind = 'email'` with a template id + payload, drained by an Edge Function calling Resend.
- In-app notifications table (`notifications`: `user_id`, `type`, `payload`, `read_at`) populated by the same triggers, RLS'd to the owning user, surfaced via Realtime subscription for a live notification bell — cheap to add given the outbox/Realtime infra already exists for the email path.

---

## 7. What the Hetzner box is actually for, if anything

**Not needed for v1. Ship on Supabase + a simple Node host for SvelteKit (Vercel, or Hetzner-as-plain-static-host if the founder wants to avoid a second vendor — but not as a custom server with any of *this* app's logic running on it).** This is a clear recommendation, not a hedge.

Reasoning: every piece of this architecture that sounds like it needs "a server" — scheduled deadline enforcement, Stripe webhook handling, reliable retryable external calls, contract PDF generation, realtime push — has a first-class Supabase primitive (pg_cron, Edge Functions + outbox pattern, Storage, Realtime) that covers it at MVP volume (a few hundred listings/deals a month, not the scraping-scale throughput Lota's Hetzner box exists for). The Lota box earns its keep because it runs long-lived Playwright scraping sessions and GraphQL capture jobs that don't fit serverless execution limits — CreatorConnect's MVP has explicitly deferred exactly the kind of workload (automated multi-platform metrics ingestion) that would eventually create that need. If/when Phase 2 adds automated YouTube/IG/TikTok API polling for performance stats, *that* is the moment to revisit — and even then, scheduled API polling within rate limits is plausibly still an Edge Function + pg_cron job, not a dedicated box, unless it turns into scraping (ToS-violating access, headless browser sessions) the way Lota's did.

One thing to watch, not a reason to provision now: contract PDF generation (Section 2/4) needs *some* rendering step. If a pure-JS/WASM PDF library running inside an Edge Function proves too constrained (font handling, complex layout), the fallback is a small serverless function on the SvelteKit host itself (Node has mature PDF libraries), not a Hetzner box — still doesn't justify a VPS.

**Concrete recommendation:** deploy SvelteKit to Vercel (or equivalent Node-friendly host) for v1. Do not provision a CreatorConnect-specific Hetzner box. Revisit only if/when Phase 2's metrics-ingestion work requires actual scraping/long-lived headless sessions, at which point the existing Lota box pattern is a known-good template to copy, not a new design problem.

---

## 8. Key architectural risks / open questions

1. **RLS + RPC delegation model complexity is the single biggest build risk.** The `manager_creator_links` + `listing_price_bands` + `security definer` RPC pattern in Section 3 is correct in principle but has a lot of surface area (every mutating action needs its own RPC with its own band-check), and a missed case (a raw table grant left open, or a new mutating feature added later as a plain `update` instead of going through an RPC) silently reopens the exact authorization hole the whole design exists to prevent. **De-risk:** write the delegation RPCs and their RLS-bypass tests *before* building any UI on top of them; treat "can a manager, via any code path, exceed their band or touch a creator they're not linked to" as a test suite that runs on every migration, not a one-time manual check. Consider a lint/convention rule: no client-writable `update`/`insert` grants on `creator_listings`, `reservations`, `listing_offers`, `listing_exclusivity_grants`, `deals` beyond `insert ... where status='draft'` (or the equivalent initial-state insert for each negotiation table) — everything else must be RPC-only, enforced by revoking direct table privileges from the `authenticated` role on those tables' sensitive columns. (See risk #6 below for how this risk specifically grows now that three mechanisms means three negotiation tables instead of one.)

2. **The sealed-bid tiebreaker is a genuine concurrency hazard, and it's rare enough in production that a race condition could go unnoticed until it matters.** Two advertisers reserving the "same" slot within the response window, transitioning a listing from `open`→`reserved`→`tiebreak_pending`, needs to be atomic (row-level lock on `creator_listings` during `place_reservation`, or a unique-partial-index trick to prevent two `held` reservations against one listing outside the tiebreak window) or you risk double-booking a slot two advertisers both believe they've secured — the worst possible trust failure for a deposit-taking marketplace. **De-risk:** write the `place_reservation` RPC with an explicit `select ... for update` on the listing row (or a Postgres advisory lock keyed on `listing_id`) as the very first thing built and load-test it with concurrent requests before anything else in the reservation flow, since PRODUCT.md itself flags this as rare-but-real and it's exactly the kind of bug that won't show up until real contention happens live.

3. **Stripe Connect Express onboarding friction may stall creator activation** — mid-tier creators (the target segment) may not complete Express KYC promptly, and PRODUCT.md's flow implies a creator needs a completed Connect account *before* they can receive any transfer, but listing creation doesn't strictly require it. **Decision to make explicitly, not silently:** does the platform let a creator publish a listing before Connect onboarding is complete (and block only at reservation/payout time), or gate listing creation on onboarding completion? Recommend the former (lower friction to first listing) but block `place_reservation` if the creator's `stripe_connect_account_id` is null or `account.updated` shows `payouts_enabled = false` — surfaces the requirement at the point it actually matters rather than up front. This should be pressure-tested with the same pilot creators PRODUCT.md's Section 7 already flags for interviews.

4. **The escrow "charge 100% up front, transfer in two tranches" design (Section 4) is a reasonable read of the Stripe Connect agent-of-payee pattern but has not been verified against Stripe's current Connect documentation/ToS for this specific product shape (deposit-then-balance, delayed transfer, dispute-freezable second tranche).** This is exactly the kind of single fact worth confirming directly with Stripe's docs before writing the PaymentIntent/Transfer code, rather than assuming. **De-risk:** before implementation, do a narrow, targeted check (not open research) against current Stripe Connect docs for: (a) maximum allowable delay between charge and transfer under Express accounts, (b) whether `application_fee_amount` vs. manual `transfers` is still the recommended pattern for delayed/split marketplace payouts, (c) Express account payout-hold behavior for new accounts (Stripe sometimes imposes its own rolling reserve on new connected accounts, which could collide with the platform's own 5-day hold logic).

5. **Manual dispute resolution (Section 6 of PRODUCT.md) has no architectural bottleneck today but will become one if volume grows** — the current design is "creator or advertiser flips `deals.status = 'disputed'`, founder resolves manually, someone (the founder, via a service-role action) eventually calls `release_delivery_balance` or issues a partial refund." There's no admin UI in this architecture yet, meaning the founder would resolve disputes via direct SQL/Stripe dashboard access initially. **De-risk:** fine to launch this way given PRODUCT.md's explicit "no automated arbitration in v1," but budget for a minimal internal-only admin route (`/admin/disputes`, gated by a service-role check on the founder's own account) as soon as dispute volume exceeds "a few, handled by hand" — this is cheap to add later precisely because `deals`/`escrow_transactions` already carry all the state a dispute resolution UI would need to display.

6. **The three-mechanism scope change (PRODUCT.md's Phase 0 revision) triples the RLS/RPC surface area that risk #1 already flags as the single biggest build risk — this is a new, distinct risk, not a restatement of #1, because it's specifically about what gets *harder to keep correct* when the same delegation guarantee has to be re-implemented three times instead of once.** Concretely, what's riskier now:
   - **Three parallel RPC families instead of one.** Section 3 established that mechanism-awareness means three separate families of `security definer` functions (`confirm_deal_as`/`accept_offer_as`+`counter_offer_as`/`convert_exclusivity_as`), each with its own pre-condition checks, each calling a shared band-check helper. The shared helper reduces duplicated *logic*, but does nothing to reduce duplicated *call sites* — each family is a fresh opportunity to forget the band-check, forget the `audit_log` insert, or forget the `is_authorized_for_creator` verification that risk #1 already warns is easy to silently omit. Three mechanisms means three chances per authorization guarantee, not one.
   - **Three negotiation tables with different state machines widen the "raw update left open" hole from risk #1.** Risk #1's core warning — a missed `revoke`/lint case reopening a hole — now applies independently to `reservations`, `listing_offers`, and `listing_exclusivity_grants`. A convention enforced on `reservations` (no client-writable `update` beyond `insert ... where status='draft'`-equivalent) has to be independently re-applied and re-tested on the two new tables; there's no guarantee a developer adding `listing_offers` six months from now remembers the reasoning that produced the pattern on `reservations`, especially since `listing_offers`' state machine (sequential accept/reject/counter, no deposit) looks superficially simpler and might tempt a shortcut ("it's just a status field, a plain RLS update policy is probably fine here") that reintroduces exactly the bypass risk #1 exists to prevent.
   - **The convergence point (`deals`) now has three possible origins to get right, not one.** Section 2's `deals` table added a three-way-exclusive-nullable-FK `check` constraint (`reservation_id` / `offer_id` / `exclusivity_grant_id`) to keep "exactly one origin" enforced at the schema level. This is the right design, but it's also a new invariant that every deal-creation RPC (all three families) must satisfy correctly — a bug that lets two origin pointers get set (or none) wouldn't necessarily fail loudly, and would quietly corrupt the audit trail/dispute-resolution story for that deal.
   - **De-risk, matching the depth of risk #1's mitigation:** extend risk #1's proposed test-suite approach to explicitly enumerate per-mechanism cases rather than treating "the delegation model" as one thing to test — the RLS-bypass test suite should have a section per mechanism (can a manager exceed the band via `accept_offer_as`? via `counter_offer_as`? via `convert_exclusivity_as`? in addition to the existing `confirm_deal_as` coverage), not just one shared test that happens to exercise D. Additionally, treat the shared `check_price_band` helper (Section 3) as the one piece of authorization logic that's genuinely reused, and write its test coverage once, thoroughly, separately from the three RPC families that call it — this is the concrete way to get the benefit of "the logic is defined once" (fewer places for the *substance* of the check to be wrong) while still respecting that the *call sites* are tripled (more places for the check to be *missing entirely*, which is a different failure mode the shared-helper design doesn't protect against on its own). Build and test mechanism D's RPC family first (already partially de-risked by risk #1 and #2's existing mitigations), then treat A and C's RPC families as requiring the same test rigor from scratch rather than assuming "D worked, so the pattern is proven" — the pattern is proven, but each new call site is a fresh chance to misapply it.

---

*Architecture owner: founder. Companion to `PRODUCT.md`; revisit Section 4 (Stripe Connect mechanics) and Section 3 (delegation RLS model) first if Stripe API specifics or early pilot usage contradict assumptions here — those are the two areas with the least first-party verification in this document.*
