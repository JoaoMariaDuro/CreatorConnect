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
9. [`rpc-mechanism-ac.sql`](./rpc-mechanism-ac.sql) — mechanisms A and C's RPC families
   (`submit_offer_as`/`accept_offer_as`/`accept_offer_as_advertiser` for A;
   `request_exclusivity_as`/`propose_exclusivity_terms_as`/`convert_exclusivity_as`/
   `convert_exclusivity_as_advertiser` for C), plus `expire_exclusivity`, scheduled by
   `cron-scheduling.sql`'s third job (see next). Phase 1-FastFollow, built on the pattern proven by
   `rpc-mechanism-d.sql`. **Must run before `cron-scheduling.sql`**, since that file's third cron job
   wraps `expire_exclusivity`, which this file defines.
10. [`cron-scheduling.sql`](./cron-scheduling.sql) — schedules `expire_reservation`,
    `release_delivery_balance`, and `expire_exclusivity` to run every 5 minutes via `pg_cron`.
    **Requires enabling the pg_cron extension first**: Database → Extensions → search "pg_cron" →
    Enable, in the Supabase dashboard, before running this file.
11. [`rpc-admin.sql`](./rpc-admin.sql) — `resolve_dispute_as_admin`, the founder/admin dispute
    resolution RPC gated by `schema.sql`'s `is_platform_admin()`. Depends on `deals` (`deals.sql`),
    `audit_log` (`delegation.sql`), and `is_platform_admin()` (`schema.sql`), so it runs last.

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
4. Auth → URL Configuration → add `http://localhost:5173/auth/confirm` (and your deployed origin,
   later) to the **Redirect URLs** allow-list — the magic link won't work without this.
5. Grant yourself founder/admin access, one time, by hand — there is deliberately no in-app or
   self-service way to do this (see `docs/ROLE_ACCESS_AND_UX_SPEC.md`). After you've signed up once:
   1. Find your own user id: Supabase dashboard → Authentication → Users (copy the UUID next to your
      email), or run `select id, email from auth.users;` in the SQL Editor and find your row.
   2. In the SQL Editor, run (with your real id in place of the placeholder):
      ```sql
      update public.profiles set is_platform_admin = true where id = '<your own user id>';
      ```
   3. That's it — no redeploy needed. `is_platform_admin()` (`schema.sql`) reads this column live, so
      the new admin RLS policies and `resolve_dispute_as_admin` (`rpc-admin.sql`) pick it up on your
      next request.

## Test/seed data (optional, for manual QA)

Want to click through the app (dashboards, negotiation flows, manager delegation, admin disputes,
staleness badges, reputation counts) against a populated app instead of an empty one? Two steps, run
once, in this order — **after** you've already run the 11 numbered files above:

1. **Create 6 confirmed test accounts** (3 creators, 2 advertisers, 1 manager) and get a sign-in link
   for each, with no real inbox needed:
   ```
   export PUBLIC_SUPABASE_URL=https://xxxx.supabase.co        # same value as in your .env
   export SUPABASE_SERVICE_ROLE_KEY=<paste from dashboard → Project Settings → API keys, this run only>
   node scripts/seed-test-users.mjs
   ```
   This uses the Supabase admin API (`auth.admin.createUser` + `auth.admin.generateLink`) to create
   6 accounts on the obviously-fake domain `@seed.creatorconnect.test`, and prints a magic-link
   sign-in URL for each one directly to your terminal — copy any of them into a browser to be signed
   in as that persona. `SUPABASE_SERVICE_ROLE_KEY` is a secret with full admin rights over your
   project: export it for this one run only, never commit it, never put it in `.env`. The script is
   safe to re-run later if a printed link goes stale (links are single-use and expire) — it detects
   already-existing test accounts and just prints a fresh link instead of creating duplicates.

2. **Populate listings, negotiations, deals, and delegation data** for those 6 accounts by running
   [`seed-data.sql`](./seed-data.sql) in the SQL Editor, same as any other file in this folder. It
   finds the 6 accounts from step 1 by email and covers every mechanism (A/C/D) in both a fresh
   "no negotiation yet" state and an in-progress negotiation state, a draft listing, every
   `performance_stats` staleness tier (fresh/soft-stale/hard-stale/never-entered), every `deals`
   status (active/delivered/completed/disputed — including a disputed deal flagged by the test
   manager account on a test creator's behalf, for the admin "acting as" audit trail), and manager
   delegation links exercising both the per-listing and creator-default price-band fallback paths.

Both of these only ever INSERT test rows (plus a couple of UPDATEs against the same test profiles) —
neither touches real data. `seed-data.sql` is NOT part of the numbered list above and is entirely
optional to run.

## What's NOT here yet

- **Stripe Connect integration** — the escrow tables exist but nothing writes to them yet. That's
  roadmap Phase 0 items 0.4/0.5, not done — deposits, offers, and deals all move through the real
  state machine, just no real money yet.
- **The sealed-bid tiebreaker's RPCs** — deliberately deferred to Phase 1.5 per the roadmap; the
  tables exist, `place_reservation` currently just rejects contention outright.
- **Disputed deals resolve via founder/admin action, not self-service** — `cron-scheduling.sql`'s
  auto-release only fires for non-disputed deals (`release_delivery_balance` already checks and skips
  disputed ones); resolving an actual dispute now goes through `rpc-admin.sql`'s
  `resolve_dispute_as_admin`, callable only by the founder (gated by `is_platform_admin()`), on
  purpose, per PRODUCT.md's "no self-service arbitration in v1."
