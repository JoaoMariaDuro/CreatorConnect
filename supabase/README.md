# Supabase setup

Run these files **in this exact order**, once, in your Supabase project's SQL Editor
(left sidebar → SQL Editor → New query → paste → Run). Each is idempotent (`create table if not
exists`, `drop policy if exists` before `create policy`) so re-running one after a mistake is safe.

**Update note (this pass):** `rpc-mechanism-d.sql`, `rpc-mechanism-ac.sql`, `rpc-delivery.sql`,
`rpc-delegation.sql`, and `rpc-admin.sql` each got a small addition — every state-transition RPC now
also writes a row into `notifications` (the table `delegation.sql` already created but nothing wrote
to) for whoever needs to know something happened, feeding the new bell icon in the top bar. Every
function uses `create or replace function`, so if your project already ran the original versions,
just re-run these 5 files again (in the same relative order as the numbered list below) to pick up
the notification writes — no data is lost, nothing else changes.

**Update note (cancellation terms):** `listings.sql` now has a `creator_listings.cancellation_terms`
column (editable on `/listings/[id]`'s "Listing extras" card), and `rpc-mechanism-d.sql` /
`rpc-mechanism-ac.sql` copy it into `deals.cancellation_terms` at confirmation time (falling back to
a new `default_cancellation_terms()` helper when a creator hasn't set one). If your project already
ran these files, re-run `listings.sql`, then `rpc-mechanism-d.sql`, then `rpc-mechanism-ac.sql` (in
that order — the helper function is defined in the first file and used by the second).

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
    resolution RPC, plus `set_own_test_role_as_admin`, which lets an admin flip their own `role`
    between creator/advertiser/manager to test all three role-differentiated UIs from one account
    (see `/settings` in the app). Both gated by `schema.sql`'s `is_platform_admin()`. Depends on
    `deals` (`deals.sql`), `audit_log` (`delegation.sql`), and `is_platform_admin()` (`schema.sql`),
    so it runs last.
12. [`feedback.sql`](./feedback.sql) — `feedback` table backing the top bar's "Report an issue" /
    "Suggest an idea" flow. Plain client-side insert with RLS, not a security-definer RPC — this is
    low-stakes user-submitted content, not an audit trail. Only depends on `schema.sql` (`profiles`,
    `is_platform_admin()`), so it can run any time after that.
13. [`companies.sql`](./companies.sql) — `companies` + `company_members` (advertiser/manager
    multi-person orgs — owner/member roles, pending/active/revoked invite lifecycle), the
    `public_companies` / `public_company_roster` views their public pages read through, and a
    trigger blocking the last active owner of a company from being removed. Only depends on
    `schema.sql` (`profiles`, `public_profiles`) and `delegation.sql` (`audit_log`, `notifications`)
    — listed here as step 13 to avoid renumbering the rest of this list, but it can run any time
    after step 5.
14. [`rpc-companies.sql`](./rpc-companies.sql) — `create_company`, `invite_company_member_by_email`,
    `accept_company_invite`. Must run after `companies.sql` (step 13).
15. [`fix-profile-handle-unique.sql`](./fix-profile-handle-unique.sql) — a unique index on
    `profiles.handle`, closing a gap that existed since MVP (two users could pick the same handle
    and break each other's `/c/[handle]`/`/u/[handle]` page). Only depends on `schema.sql`
    (`profiles`), so it can run any time after step 1 — listed last only to avoid renumbering.
16. [`shortlists.sql`](./shortlists.sql) — advertiser shortlist/watchlist (`PRODUCT.md` Flow 2,
    designed but never built until now). Plain RLS, no RPC — self-scoped both directions, an
    advertiser's shortlist is private. Only depends on `schema.sql` (`profiles`) and `listings.sql`
    (`creator_listings`), so it can run any time after step 2.
17. [`company-showcase.sql`](./company-showcase.sql) — `company_showcased_creators`: lets a
    manager/agency company publicly display which creators it represents on `/company/[handle]`,
    with dual consent (the agency proposes, the creator must separately accept — neither side can
    grant consent alone, enforced by RLS, not just app logic). Depends on `companies.sql` (step 13)
    and `delegation.sql` (`manager_creator_links`, step 5).
18. [`rpc-company-showcase.sql`](./rpc-company-showcase.sql) — `propose_showcase_creator`,
    `respond_showcase_creator`. Must run after `company-showcase.sql` (step 17).
19. [`manager-notes.sql`](./manager-notes.sql) — `manager_creator_notes`: a manager's private working
    notes per represented creator (preferences, history, reminders) — fully invisible to the creator,
    on purpose (a new table, not a column on `manager_creator_links`, specifically so the creator's
    existing full-access RLS on that table can't leak it). Depends on `schema.sql` (`profiles`,
    `touch_updated_at()`) and `delegation.sql` (`manager_creator_links`, step 5).
20. [`deal-signatures.sql`](./deal-signatures.sql) — `deal_signatures`: typed-name e-signature capture
    per deal/party, immutable once signed. Depends on `deals.sql` and `delegation.sql`
    (`is_authorized_for_creator`, `audit_log`, `notifications`).
21. [`rpc-deal-signatures.sql`](./rpc-deal-signatures.sql) — `sign_deal_as`. Must run after
    `deal-signatures.sql` (step 20).

**Note on `schema.sql`'s `public_profiles` view**: this session widened it to also expose `bio`
(needed by `/u/[handle]`, the new advertiser/manager individual profile page — see the view's own
comment). If your project already ran `schema.sql` once, re-run it — `create or replace view` is
safe, no data is lost. **If you ran this before the `bio` column landed**: an earlier version of this
edit inserted `bio` in the middle of the view's column list, which Postgres's `create or replace
view` silently rejects (it only allows appending columns at the end) — that's fixed now, but if your
first attempt at re-running `schema.sql` errored or the view still doesn't have `bio`, re-run it once
more with the current file.

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
