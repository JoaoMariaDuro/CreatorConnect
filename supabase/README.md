# Supabase setup

Run these files **in this exact order**, once, in your Supabase project's SQL Editor
(left sidebar → SQL Editor → New query → paste → Run). Each is idempotent (`create table if not
exists`, `drop policy if exists` before `create policy`) so re-running one after a mistake is safe.

1. [`schema.sql`](./schema.sql) — profiles table + the trigger that creates a profile row on signup.
2. [`listings.sql`](./listings.sql) — `creator_listings`, the pricing-mechanism-aware listing table.
3. [`negotiations.sql`](./negotiations.sql) — the three mechanism-specific negotiation tables
   (`reservations` for D, `listing_offers` for A, `listing_exclusivity_grants` for C) plus D's
   (currently unused) tiebreak tables.
4. [`deals.sql`](./deals.sql) — `deals` (the convergence point all three mechanisms write into) and
   `escrow_transactions` (stays empty until Stripe Connect is wired up).
5. [`delegation.sql`](./delegation.sql) — manager/creator delegation (`manager_creator_links`,
   `listing_price_bands`), `audit_log`, `notifications`. Also replaces `schema.sql`'s forward-declared
   `is_authorized_for_creator()` with its real body now that the delegation table exists.
6. [`rpc-mechanism-d.sql`](./rpc-mechanism-d.sql) — `place_reservation` (the concurrency-safe,
   row-locked reservation RPC — see the file header for why this is the first real piece of business
   logic), `confirm_deal_as`, `expire_reservation`. Deliberately D-only — mechanisms A/C's RPCs land
   in a later file, matching `../docs/ROADMAP.md`'s "ship D first" sequencing call.
7. [`rpc-delivery.sql`](./rpc-delivery.sql) — `confirm_delivery_as` (advertiser sign-off),
   `flag_dispute_as` (either party freezes release), `release_delivery_balance` (called by
   `cron-scheduling.sql`, next). Mechanism-agnostic: works the same regardless of which mechanism
   produced the `deals` row, per the convergence-point design in `../docs/ARCHITECTURE.md` Section 2.
8. [`rpc-delegation.sql`](./rpc-delegation.sql) — `invite_manager_by_email`, `accept_manager_link`.
9. [`cron-scheduling.sql`](./cron-scheduling.sql) — schedules `expire_reservation` and
   `release_delivery_balance` to run every 5 minutes via `pg_cron`. **Requires enabling the pg_cron
   extension first**: Database → Extensions → search "pg_cron" → Enable, in the Supabase dashboard,
   before running this file.
10. [`rpc-mechanism-ac.sql`](./rpc-mechanism-ac.sql) — mechanisms A and C's RPC families
    (`submit_offer_as`/`accept_offer_as`/`accept_offer_as_advertiser` for A;
    `request_exclusivity_as`/`propose_exclusivity_terms_as`/`convert_exclusivity_as`/
    `convert_exclusivity_as_advertiser` for C), plus `expire_exclusivity` (not yet scheduled — see
    below). Phase 1-FastFollow, built on the pattern proven by `rpc-mechanism-d.sql`.

## Then: get the app talking to it

1. Project Settings → API Keys → copy the **Project URL** and the **Publishable key** (`sb_publishable_…`,
   or the legacy anon JWT if your project only shows that).
2. Copy `.env.example` to `.env` in the project root and paste them in:
   ```
   PUBLIC_SUPABASE_URL=https://xxxx.supabase.co
   PUBLIC_SUPABASE_KEY=sb_publishable_xxx
   ```
   `.env` is gitignored — keys never get committed.
3. Auth → Sign In / Providers → confirm **Email** is enabled (magic link, no password) and, if you
   want, disable Confirm email so the first-time signup lands the user straight into the app.
4. Auth → URL Configuration → add `http://localhost:5299/auth/confirm` (and your deployed origin,
   later) to the **Redirect URLs** allow-list — the magic link won't work without this.

## What's NOT here yet

- **Stripe Connect integration** — the escrow tables exist but nothing writes to them yet. That's
  roadmap Phase 0 items 0.4/0.5, not done — deposits, offers, and deals all move through the real
  state machine, just no real money yet.
- **The sealed-bid tiebreaker's RPCs** — deliberately deferred to Phase 1.5 per the roadmap; the
  tables exist, `place_reservation` currently just rejects contention outright.
- **Mechanism C's expiry job isn't scheduled** — `expire_exclusivity` (in `rpc-mechanism-ac.sql`)
  exists but `cron-scheduling.sql` only schedules D's two jobs. Add a third
  `cron.schedule('expire-stale-exclusivity', '*/5 * * * *', 'select public.run_expire_stale_exclusivity();')`
  (with a matching wrapper function, same per-row exception-handling pattern) when ready — low
  priority since C has no deposit at risk, an expired grant just reopens the listing.
- **Disputed deals still resolve manually** — `cron-scheduling.sql`'s auto-release only fires for
  non-disputed deals (`release_delivery_balance` already checks and skips disputed ones); resolving
  an actual dispute is founder-mediated via direct SQL/dashboard access, on purpose, per PRODUCT.md's
  "no self-service arbitration in v1."
