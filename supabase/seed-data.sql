-- CreatorConnect — TEST / SEED DATA ONLY. Not part of the numbered "run these in order" list in
-- README.md — this is optional, for manual QA, and safe to skip entirely in a real deployment.
--
-- PREREQUISITE: run `node scripts/seed-test-users.mjs` FIRST (locally, with your own service role
-- key — see that script's header). It creates 6 confirmed auth.users accounts on the fake domain
-- `@seed.creatorconnect.test` and prints a sign-in link for each. This file finds those accounts by
-- email (via auth.users, which is only readable with full Postgres privileges — exactly what the SQL
-- Editor runs with, no RLS restriction here) and populates listings/negotiations/deals/delegation rows
-- for them.
--
-- This file only ever INSERTs (and a couple of targeted UPDATEs against rows it just inserted, or
-- against the 6 seed profiles only). It never touches any other row, never touches Stripe (not wired
-- up yet — see deals.sql/escrow_transactions), and is meant to be run once against a project that
-- already has the 6 seed auth accounts. It is NOT idempotent — re-running it will create a second copy
-- of every listing/deal (the auth.users/profiles rows themselves are unaffected since it never inserts
-- into those). If you want a clean slate, manually delete the seeded rows first (e.g. by creator_id
-- for the 3 seed creators, or advertiser_id for the 2 seed advertisers) before re-running.
--
-- Coverage this file provides (see supabase/README.md's "Test/seed data" section and the handoff notes
-- for the full matrix): one open listing per mechanism (A/C/D) with no negotiation yet; an in-progress
-- mechanism A offer thread; an in-progress mechanism C exclusivity negotiation; a held mechanism D
-- reservation; a draft listing; performance_stats at every staleness tier (fresh/soft/hard/empty); deals
-- in every status (active/delivered/completed/disputed) with matching origin rows and audit_log
-- entries; and manager delegation links exercising both the per-listing band and the creator-default
-- band fallback paths.

do $$
declare
  v_jordan_id   uuid; -- creator, YouTube ~120k, tech/gadget reviews
  v_maya_id     uuid; -- creator, Instagram ~85k, beauty/lifestyle
  v_devon_id    uuid; -- creator, TikTok ~250k, comedy/skits
  v_northwind_id uuid; -- advertiser, outdoor gear brand
  v_lumen_id    uuid; -- advertiser, skincare brand
  v_priya_id    uuid; -- manager, represents Jordan + Devon

  v_j1 uuid; v_j2 uuid; v_j3 uuid; v_j4 uuid; -- Jordan's listings
  v_m1 uuid; v_m2 uuid; v_m3 uuid;            -- Maya's listings
  v_d1 uuid; v_d2 uuid; v_d3 uuid; v_d4 uuid; -- Devon's listings

  v_j2_offer1 uuid; v_j2_offer2 uuid; v_j2_offer3 uuid;
  v_j3_reservation uuid;
  v_j4_offer uuid;
  v_m2_grant uuid;
  v_d1_reservation uuid;
  v_d3_grant uuid;
  v_d4_offer uuid;

  v_deal_active uuid;    -- J4 — mechanism A, active, awaiting delivery
  v_deal_delivered uuid; -- D4 — mechanism A, delivered, awaiting auto-release
  v_deal_completed uuid; -- J3 — mechanism D, completed
  v_deal_disputed uuid;  -- D3 — mechanism C, disputed (flagged by manager Priya acting as Devon)
begin
  -- ---------- 1. Resolve the 6 seed accounts (created by scripts/seed-test-users.mjs) ----------

  select id into v_jordan_id    from auth.users where email = 'creator.jordan@seed.creatorconnect.test';
  select id into v_maya_id      from auth.users where email = 'creator.maya@seed.creatorconnect.test';
  select id into v_devon_id     from auth.users where email = 'creator.devon@seed.creatorconnect.test';
  select id into v_northwind_id from auth.users where email = 'advertiser.northwind@seed.creatorconnect.test';
  select id into v_lumen_id     from auth.users where email = 'advertiser.lumen@seed.creatorconnect.test';
  select id into v_priya_id     from auth.users where email = 'manager.priya@seed.creatorconnect.test';

  if v_jordan_id is null or v_maya_id is null or v_devon_id is null
     or v_northwind_id is null or v_lumen_id is null or v_priya_id is null then
    raise exception 'One or more seed accounts not found. Run scripts/seed-test-users.mjs first — see supabase/README.md.';
  end if;

  -- ---------- 2. Flesh out the 3 creators' public profile fields ----------
  -- handle_new_user() (schema.sql) already set role + display_name from signup metadata; fill in the
  -- rest here (follower_count, niche_tags, platform_handles) since that's plain table data, not auth
  -- metadata the Node script has any business setting.

  update public.profiles
  set follower_count = 120000,
      niche_tags = array['tech', 'gadget-reviews'],
      handle = '@jordanreyes',
      platform_handles = '{"youtube": "@jordanreyes"}'::jsonb,
      bio = 'Tech reviews and unboxings. Honest takes, no fluff.'
  where id = v_jordan_id;

  update public.profiles
  set follower_count = 85000,
      niche_tags = array['beauty', 'lifestyle'],
      handle = '@mayalin',
      platform_handles = '{"instagram": "@mayalin"}'::jsonb,
      bio = 'Beauty + lifestyle content, skincare-obsessed.'
  where id = v_maya_id;

  update public.profiles
  set follower_count = 250000,
      niche_tags = array['comedy', 'skits'],
      handle = '@devonbrooks',
      platform_handles = '{"tiktok": "@devonbrooks"}'::jsonb,
      bio = 'Sketches and skits. Brand-safe, high-energy.'
  where id = v_devon_id;

  update public.profiles
  set handle = '@northwindoutdoor',
      bio = 'Outdoor gear and apparel.'
  where id = v_northwind_id;

  update public.profiles
  set handle = '@lumenskincare',
      bio = 'Clean, dermatologist-tested skincare.'
  where id = v_lumen_id;

  update public.profiles
  set handle = '@priyashah',
      bio = 'Talent manager representing creators across YouTube, TikTok, and Instagram.'
  where id = v_priya_id;

  -- ---------- 3. Listings ----------
  -- mechanism_fields_match reminder: A needs nothing extra; C needs exclusivity_window; D needs
  -- reservation_deadline AND floor_price_cents.

  -- J1 — Jordan, mechanism D, open, no reservation yet. FRESH stats (5 days old).
  insert into public.creator_listings (
    id, creator_id, created_by, platform, content_type, availability_window, description,
    pricing_mechanism, floor_price_cents, reservation_deadline, status,
    performance_stats, performance_stats_updated_at
  ) values (
    gen_random_uuid(), v_jordan_id, v_jordan_id, 'YouTube', 'Dedicated review video (8-12 min)',
    'Week of Aug 10-17, 2026', 'Full dedicated review of your product, filmed and edited by me.',
    'D', 150000, now() + interval '14 days', 'open',
    '{"avg_views": 118000, "avg_engagement_rate": 0.041}'::jsonb, now() - interval '5 days'
  ) returning id into v_j1;

  -- J2 — Jordan, mechanism A, pending (in-progress offer thread). SOFT-STALE stats (75 days old).
  insert into public.creator_listings (
    id, creator_id, created_by, platform, content_type, availability_window, description,
    pricing_mechanism, floor_price_cents, status,
    performance_stats, performance_stats_updated_at
  ) values (
    gen_random_uuid(), v_jordan_id, v_jordan_id, 'YouTube', '60-second mid-roll integration',
    'Week of Aug 24-31, 2026', 'Mid-roll integration in an upcoming gadget roundup video.',
    'A', 100000, 'pending',
    '{"avg_views": 95000, "avg_engagement_rate": 0.035}'::jsonb, now() - interval '75 days'
  ) returning id into v_j2;

  -- J3 — Jordan, mechanism D, deal (already converted, see reservation + deal below). HARD-STALE
  -- stats (200 days old) — this listing itself is "done", staleness here reflects the creator having
  -- neglected to refresh stats since.
  insert into public.creator_listings (
    id, creator_id, created_by, platform, content_type, availability_window, description,
    pricing_mechanism, floor_price_cents, reservation_deadline, status,
    performance_stats, performance_stats_updated_at
  ) values (
    gen_random_uuid(), v_jordan_id, v_jordan_id, 'YouTube', 'Sponsored short (60s)',
    'Week of Jun 1-7, 2026', 'Vertical short-form sponsored spot.',
    'D', 50000, now() + interval '30 days', 'deal',
    '{"avg_views": 140000, "avg_engagement_rate": 0.052}'::jsonb, now() - interval '200 days'
  ) returning id into v_j3;

  -- J4 — Jordan, mechanism A, deal (accepted offer, active deal below). FRESH stats.
  insert into public.creator_listings (
    id, creator_id, created_by, platform, content_type, availability_window, description,
    pricing_mechanism, floor_price_cents, status,
    performance_stats, performance_stats_updated_at
  ) values (
    gen_random_uuid(), v_jordan_id, v_jordan_id, 'YouTube', 'Instagram Reel cross-post + YouTube Short',
    'Week of Jul 6-12, 2026', 'Cross-platform bundle: one Reel, one Short.',
    'A', 80000, 'deal',
    '{"avg_views": 121000, "avg_engagement_rate": 0.039}'::jsonb, now() - interval '10 days'
  ) returning id into v_j4;

  -- M1 — Maya, mechanism C, open, no exclusivity grant yet. EMPTY stats (never entered).
  insert into public.creator_listings (
    id, creator_id, created_by, platform, content_type, availability_window, description,
    pricing_mechanism, exclusivity_window, rate_card_low_cents, rate_card_high_cents, status,
    performance_stats, performance_stats_updated_at
  ) values (
    gen_random_uuid(), v_maya_id, v_maya_id, 'Instagram', 'Grid post + 3 Stories',
    'Week of Aug 3-10, 2026', 'Exclusive early access to negotiate a grid post + Stories bundle.',
    'C', interval '7 days', 60000, 120000, 'open',
    '{}'::jsonb, null
  ) returning id into v_m1;

  -- M2 — Maya, mechanism C, pending (active exclusivity grant with negotiation in progress, latest
  -- move made BY THE ADVERTISER — so this also lands in Maya's "needs attention" dashboard queue, per
  -- src/routes/dashboard/+page.server.ts's `negotiation->>'from' = 'advertiser'` filter). FRESH stats.
  -- This is also the listing carrying Priya's per-listing price band override (see delegation section).
  insert into public.creator_listings (
    id, creator_id, created_by, platform, content_type, availability_window, description,
    pricing_mechanism, exclusivity_window, rate_card_low_cents, rate_card_high_cents, status,
    performance_stats, performance_stats_updated_at
  ) values (
    gen_random_uuid(), v_maya_id, v_maya_id, 'Instagram', 'Reel + swipe-up link',
    'Week of Jul 20-27, 2026', 'Exclusive early access for a Reel + swipe-up link placement.',
    'C', interval '10 days', 70000, 150000, 'pending',
    '{"avg_views": 61000, "avg_engagement_rate": 0.058}'::jsonb, now() - interval '3 days'
  ) returning id into v_m2;

  -- M3 — Maya, mechanism A, draft. Must be invisible on public browse, visible to owner only.
  insert into public.creator_listings (
    id, creator_id, created_by, platform, content_type, availability_window, description,
    pricing_mechanism, floor_price_cents, status,
    performance_stats, performance_stats_updated_at
  ) values (
    gen_random_uuid(), v_maya_id, v_maya_id, 'Instagram', 'Story series (5 frames)',
    'Week of Sep 1-7, 2026', 'Still drafting terms for this one.',
    'A', 40000, 'draft',
    '{}'::jsonb, null
  ) returning id into v_m3;

  -- D1 — Devon, mechanism D, reserved (held reservation awaiting Devon's price confirmation).
  -- SOFT-STALE stats.
  insert into public.creator_listings (
    id, creator_id, created_by, platform, content_type, availability_window, description,
    pricing_mechanism, floor_price_cents, reservation_deadline, status,
    performance_stats, performance_stats_updated_at
  ) values (
    gen_random_uuid(), v_devon_id, v_devon_id, 'TikTok', 'Branded skit (30-45s)',
    'Week of Jul 13-20, 2026', 'Branded comedy skit featuring your product.',
    'D', 200000, now() + interval '2 days', 'reserved',
    '{"avg_views": 310000, "avg_engagement_rate": 0.071}'::jsonb, now() - interval '70 days'
  ) returning id into v_d1;

  -- D2 — Devon, mechanism A, open, no offers yet. FRESH stats.
  insert into public.creator_listings (
    id, creator_id, created_by, platform, content_type, availability_window, description,
    pricing_mechanism, floor_price_cents, status,
    performance_stats, performance_stats_updated_at
  ) values (
    gen_random_uuid(), v_devon_id, v_devon_id, 'TikTok', 'Duet / stitch response video',
    'Week of Aug 17-24, 2026', 'Duet-style response video featuring your product.',
    'A', 90000, 'open',
    '{"avg_views": 275000, "avg_engagement_rate": 0.065}'::jsonb, now() - interval '2 days'
  ) returning id into v_d2;

  -- D3 — Devon, mechanism C, deal (converted exclusivity, disputed deal below). HARD-STALE stats.
  insert into public.creator_listings (
    id, creator_id, created_by, platform, content_type, availability_window, description,
    pricing_mechanism, exclusivity_window, rate_card_low_cents, rate_card_high_cents, status,
    performance_stats, performance_stats_updated_at
  ) values (
    gen_random_uuid(), v_devon_id, v_devon_id, 'TikTok', 'Full sponsored video (60-90s)',
    'Week of May 4-11, 2026', 'Full sponsored TikTok, exclusivity negotiated first.',
    'C', interval '7 days', 250000, 400000, 'deal',
    '{"avg_views": 290000, "avg_engagement_rate": 0.069}'::jsonb, now() - interval '210 days'
  ) returning id into v_d3;

  -- D4 — Devon, mechanism A, deal (accepted offer, delivered deal below). FRESH stats.
  insert into public.creator_listings (
    id, creator_id, created_by, platform, content_type, availability_window, description,
    pricing_mechanism, floor_price_cents, status,
    performance_stats, performance_stats_updated_at
  ) values (
    gen_random_uuid(), v_devon_id, v_devon_id, 'TikTok', 'In-feed sponsored post',
    'Week of Jun 22-29, 2026', 'Standard in-feed sponsored TikTok.',
    'A', 180000, 'deal',
    '{"avg_views": 260000, "avg_engagement_rate": 0.063}'::jsonb, now() - interval '8 days'
  ) returning id into v_d4;

  -- ---------- 4. Mechanism A — in-progress offer thread on J2 (3 rows, alternating, latest open) ----------
  -- Advertiser (Northwind) opens at $700; Jordan counters at $950; Northwind counters back at $850,
  -- leaving the thread open awaiting JORDAN's response — so this is also the one Mechanism-A listing
  -- that lands in the CREATOR's dashboard "needs attention" queue (pendingOfferListingIds, per
  -- src/routes/dashboard/+page.server.ts's `.eq('status','open').eq('proposed_by','advertiser')`
  -- filter) — without this third row, no seeded creator has an open A-offer awaiting their own
  -- response, leaving that queue path untested. Mirrors submit_offer_as()'s parent_offer_id chaining
  -- and its "only one open row per listing" invariant (each new offer withdraws the prior open one).

  -- Explicit, distinct created_at per row: all three would otherwise share the same now() value
  -- (constant within one transaction), making their relative order — and therefore `offers[offers.length
  -- - 1]` / latestOffer on the listing detail page — technically non-deterministic on a tie.
  insert into public.listing_offers (
    id, listing_id, advertiser_id, offer_amount_cents, proposed_by, status, note, parent_offer_id, created_at
  ) values (
    gen_random_uuid(), v_j2, v_northwind_id, 70000, 'advertiser', 'withdrawn',
    'Would love to feature our new trail pack in an integration.', null, now() - interval '3 days'
  ) returning id into v_j2_offer1;

  insert into public.listing_offers (
    id, listing_id, advertiser_id, offer_amount_cents, proposed_by, status, note, parent_offer_id, created_at
  ) values (
    gen_random_uuid(), v_j2, v_northwind_id, 95000, 'creator', 'withdrawn',
    'Appreciate it — my mid-rolls usually run higher, countering at $950.', v_j2_offer1, now() - interval '2 days'
  ) returning id into v_j2_offer2;

  insert into public.listing_offers (
    id, listing_id, advertiser_id, offer_amount_cents, proposed_by, status, note, parent_offer_id, created_at
  ) values (
    gen_random_uuid(), v_j2, v_northwind_id, 85000, 'advertiser', 'open',
    'Can do $850 — that''s our ceiling for a mid-roll on this campaign.', v_j2_offer2, now() - interval '1 day'
  ) returning id into v_j2_offer3;

  -- ---------- 5. Mechanism C — in-progress exclusivity negotiation on M2 ----------
  -- Lumen requested exclusivity (grant already 'active'), then proposed terms — negotiation.from =
  -- 'advertiser', so this is the one that should surface in Maya's dashboard "needs attention" queue.

  insert into public.listing_exclusivity_grants (
    id, listing_id, advertiser_id, window_starts_at, window_ends_at, status, negotiation
  ) values (
    gen_random_uuid(), v_m2, v_lumen_id, now() - interval '2 days', now() + interval '8 days', 'active',
    jsonb_build_object('proposedPrice', 110000, 'proposedTerms', '1 Reel + 3 Stories, 60-day usage rights', 'status', 'proposed', 'from', 'advertiser')
  ) returning id into v_m2_grant;

  -- ---------- 6. Mechanism D — held reservation on D1, awaiting Devon's price confirmation ----------

  insert into public.reservations (
    id, listing_id, advertiser_id, deposit_amount_cents, status, confirmation_deadline
  ) values (
    gen_random_uuid(), v_d1, v_northwind_id, 20000, 'held', now() + interval '36 hours'
  ) returning id into v_d1_reservation;

  -- ---------- 7. Deals — one per status, each with a matching, correctly-resolved origin row ----------

  -- 7a. J3 — mechanism D — COMPLETED. Origin reservation must be 'confirmed' (confirm_deal_as' end
  -- state), listing status 'deal' (already set above). completed_deals_count incremented manually
  -- below to mirror release_delivery_balance()'s exact logic (rpc-delivery.sql lines 87-89).
  insert into public.reservations (
    id, listing_id, advertiser_id, deposit_amount_cents, status, confirmation_deadline, created_at
  ) values (
    gen_random_uuid(), v_j3, v_lumen_id, 5000, 'confirmed', now() - interval '195 days', now() - interval '200 days'
  ) returning id into v_j3_reservation;

  insert into public.deals (
    id, reservation_id, listing_id, creator_id, advertiser_id, manager_id,
    final_price_cents, deliverable_spec, disclosure_terms, status,
    confirmed_at, delivery_confirmed_at, created_at
  ) values (
    gen_random_uuid(), v_j3_reservation, v_j3, v_jordan_id, v_lumen_id, null,
    55000, jsonb_build_object('platform', 'YouTube', 'contentType', 'Sponsored short (60s)', 'description', 'Vertical short-form sponsored spot.'),
    '#ad — this content includes a paid partnership. Disclosure terms per FTC Endorsement Guides.', 'completed',
    now() - interval '195 days', now() - interval '190 days', now() - interval '195 days'
  ) returning id into v_deal_completed;

  update public.profiles set completed_deals_count = completed_deals_count + 1 where id = v_jordan_id;

  insert into public.audit_log (actor_id, action, target_table, target_id, after, created_at)
  values (v_lumen_id, 'deal.completed', 'deals', v_deal_completed, jsonb_build_object('id', v_deal_completed, 'status', 'completed'), now() - interval '190 days');

  -- 7b. J4 — mechanism A — ACTIVE (just confirmed, awaiting delivery). Origin offer must be
  -- 'accepted' (accept_offer_as' end state), listing status 'deal' (already set above).
  insert into public.listing_offers (
    id, listing_id, advertiser_id, offer_amount_cents, proposed_by, status, created_at
  ) values (
    gen_random_uuid(), v_j4, v_northwind_id, 80000, 'advertiser', 'accepted', now() - interval '4 days'
  ) returning id into v_j4_offer;

  insert into public.deals (
    id, offer_id, listing_id, creator_id, advertiser_id, manager_id,
    final_price_cents, deliverable_spec, disclosure_terms, status, confirmed_at, created_at
  ) values (
    gen_random_uuid(), v_j4_offer, v_j4, v_jordan_id, v_northwind_id, null,
    80000, jsonb_build_object('platform', 'YouTube', 'contentType', 'Instagram Reel cross-post + YouTube Short', 'description', 'Cross-platform bundle: one Reel, one Short.'),
    '#ad — this content includes a paid partnership. Disclosure terms per FTC Endorsement Guides.', 'active',
    now() - interval '3 days', now() - interval '3 days'
  ) returning id into v_deal_active;

  -- 7c. D4 — mechanism A — DELIVERED (advertiser confirmed, awaiting auto-release in ~3 days).
  -- Origin offer 'accepted', listing 'deal' (already set above).
  insert into public.listing_offers (
    id, listing_id, advertiser_id, offer_amount_cents, proposed_by, status, created_at
  ) values (
    gen_random_uuid(), v_d4, v_lumen_id, 180000, 'advertiser', 'accepted', now() - interval '9 days'
  ) returning id into v_d4_offer;

  insert into public.deals (
    id, offer_id, listing_id, creator_id, advertiser_id, manager_id,
    final_price_cents, deliverable_spec, disclosure_terms, status,
    confirmed_at, delivery_confirmed_at, auto_release_at, created_at
  ) values (
    gen_random_uuid(), v_d4_offer, v_d4, v_devon_id, v_lumen_id, null,
    180000, jsonb_build_object('platform', 'TikTok', 'contentType', 'In-feed sponsored post', 'description', 'Standard in-feed sponsored TikTok.'),
    '#ad — this content includes a paid partnership. Disclosure terms per FTC Endorsement Guides.', 'delivered',
    now() - interval '8 days', now() - interval '2 days', now() + interval '3 days', now() - interval '8 days'
  ) returning id into v_deal_delivered;

  insert into public.audit_log (actor_id, action, target_table, target_id, after, created_at)
  values (v_lumen_id, 'deal.delivery_confirmed', 'deals', v_deal_delivered, jsonb_build_object('id', v_deal_delivered, 'status', 'delivered'), now() - interval '2 days');

  -- 7d. D3 — mechanism C — DISPUTED. Origin grant must be 'converted' (convert_exclusivity_as' end
  -- state), listing status 'deal' (already set above). The disputing audit_log row is the one the
  -- admin disputes queue relies on (src/routes/admin/disputes/+page.server.ts reads
  -- action = 'deal.disputed', target_table = 'deals') and it carries acting_as_id = Devon with
  -- actor_id = Priya (the manager), simulating Priya having flagged this on Devon's behalf — so the
  -- admin dispute-detail page's "Acting as {actor} on behalf of {acting_as}" sub-line is exercisable.
  insert into public.listing_exclusivity_grants (
    id, listing_id, advertiser_id, window_starts_at, window_ends_at, status, negotiation, created_at
  ) values (
    gen_random_uuid(), v_d3, v_northwind_id, now() - interval '215 days', now() - interval '208 days', 'converted',
    jsonb_build_object('proposedPrice', 320000, 'proposedTerms', 'Full sponsored video, 90-day usage rights', 'status', 'accepted', 'from', 'creator'),
    now() - interval '216 days'
  ) returning id into v_d3_grant;

  insert into public.deals (
    id, exclusivity_grant_id, listing_id, creator_id, advertiser_id, manager_id,
    final_price_cents, deliverable_spec, disclosure_terms, status, confirmed_at, created_at
  ) values (
    gen_random_uuid(), v_d3_grant, v_d3, v_devon_id, v_northwind_id, v_priya_id,
    320000, jsonb_build_object('platform', 'TikTok', 'contentType', 'Full sponsored video (60-90s)', 'description', 'Full sponsored TikTok, exclusivity negotiated first.'),
    '#ad — this content includes a paid partnership. Disclosure terms per FTC Endorsement Guides.', 'disputed',
    now() - interval '208 days', now() - interval '208 days'
  ) returning id into v_deal_disputed;

  insert into public.audit_log (actor_id, acting_as_id, action, target_table, target_id, after, created_at)
  values (
    v_priya_id, v_devon_id, 'deal.disputed', 'deals', v_deal_disputed,
    jsonb_build_object(
      'deal', jsonb_build_object('id', v_deal_disputed, 'status', 'disputed'),
      'reason', 'Delivered video did not include the agreed-upon product callout — flagging on behalf of Devon while he is traveling.'
    ),
    now() - interval '206 days'
  );

  -- Also seed the reservation.place-style audit trail for D1's held reservation, and exclusivity.request
  -- for M2's grant, so the admin dispute detail page's "origin row audit trail" join has real rows to
  -- show elsewhere too (not required for any single UI feature, just realism/coverage).
  insert into public.audit_log (actor_id, action, target_table, target_id, after, created_at)
  values (v_northwind_id, 'reservation.place', 'reservations', v_d1_reservation, jsonb_build_object('id', v_d1_reservation, 'status', 'held'), now() - interval '1 day');

  insert into public.audit_log (actor_id, action, target_table, target_id, after, created_at)
  values (v_lumen_id, 'exclusivity.propose_terms', 'listing_exclusivity_grants', v_m2_grant, jsonb_build_object('id', v_m2_grant, 'status', 'active'), now() - interval '2 days');

  -- ---------- 8. Manager delegation: Priya <-> Jordan, Priya <-> Devon (both 'active') ----------
  -- Maya is deliberately NOT linked to Priya, so browse/dashboard behavior for a creator with no
  -- manager is also exercisable.

  -- Jordan's link carries a creator-level default_auto_accept_floor_cents (the fallback path in
  -- check_price_band() when no per-listing band exists).
  insert into public.manager_creator_links (
    id, manager_id, creator_id, status, default_auto_accept_floor_cents, commission_bps, granted_at
  ) values (
    gen_random_uuid(), v_priya_id, v_jordan_id, 'active', 60000, 500, now() - interval '30 days'
  );

  -- Devon's link has no creator-level default — his per-listing band (below, on D3... but D3 is
  -- already a converted deal) should instead live on an OPEN/negotiable listing. Use D1 (the held
  -- reservation Devon is actively deciding on) so both fallback paths are independently exercisable:
  -- Jordan's flows fall back to the link-level default (no per-listing band anywhere in his listings),
  -- Devon's flows use the per-listing override on D1.
  insert into public.manager_creator_links (
    id, manager_id, creator_id, status, default_auto_accept_floor_cents, commission_bps, granted_at
  ) values (
    gen_random_uuid(), v_priya_id, v_devon_id, 'active', null, 750, now() - interval '20 days'
  );

  insert into public.listing_price_bands (id, listing_id, manager_id, auto_accept_floor_cents)
  values (gen_random_uuid(), v_d1, v_priya_id, 180000);

end $$;
