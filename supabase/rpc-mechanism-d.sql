-- CreatorConnect — mechanism D's RPC functions: place_reservation, confirm_deal_as, expire_reservation.
-- Run after delegation.sql. See ../docs/ARCHITECTURE.md Section 2/3/4, and ../docs/ROADMAP.md Phase 1
-- epic 1 — this file is deliberately D-only, matching the roadmap's "ship D first, A/C as fast-follow"
-- sequencing call. Mechanism A/C's RPCs (accept_offer_as, request_exclusivity_as, etc.) land later.
--
-- IMPORTANT: these functions do NOT yet call Stripe. deposit_payment_intent_id stays null and no
-- money actually moves — that's roadmap Phase 0 items 0.4/0.5 (Stripe Connect setup, delayed-transfer
-- verification), not done yet. What these functions DO fully implement is the state machine and the
-- concurrency-safety property ARCHITECTURE.md risk #2 calls "the worst possible trust failure for a
-- deposit-taking marketplace" — that's worth getting right before Stripe is even wired up, since it's
-- a pure DB-layer correctness problem, testable independent of payments.

-- Shared band-check helper, reused by every mechanism's confirm/accept RPC (only D's is defined here;
-- A/C's call sites come with their own RPCs in the fast-follow file).
create or replace function public.check_price_band(p_listing_id uuid, p_price_cents int)
returns boolean language plpgsql stable as $$
declare
  v_creator_id uuid;
  v_band_floor int;
  v_default_floor int;
begin
  select creator_id into v_creator_id from public.creator_listings where id = p_listing_id;

  select auto_accept_floor_cents into v_band_floor
  from public.listing_price_bands
  where listing_id = p_listing_id and manager_id = auth.uid();

  if v_band_floor is not null then
    return p_price_cents >= v_band_floor;
  end if;

  select default_auto_accept_floor_cents into v_default_floor
  from public.manager_creator_links
  where manager_id = auth.uid() and creator_id = v_creator_id and status = 'active';

  if v_default_floor is not null then
    return p_price_cents >= v_default_floor;
  end if;

  -- no band set at all for this manager/creator/listing — fail closed, not open.
  return false;
end $$;

-- The epic-1 function. Row-locks the listing for the duration of the check-and-insert so two
-- concurrent reservation attempts against the same listing cannot both succeed — one gets 'held',
-- the other gets a clean rejection. This is the exact property ARCHITECTURE.md risk #2 flags as
-- needing to be proven under real concurrent load before anything else in the reservation flow is
-- built on top of it.
create or replace function public.place_reservation(p_listing_id uuid, p_response_window interval default '48 hours')
returns public.reservations
language plpgsql security definer set search_path = public as $$
declare
  v_listing public.creator_listings;
  v_reservation public.reservations;
  v_deposit_cents int;
begin
  -- SELECT ... FOR UPDATE: blocks any other transaction from reading this row until we commit or
  -- roll back, so two simultaneous calls against the same listing_id serialize here rather than
  -- both proceeding to see status = 'open'.
  select * into v_listing
  from public.creator_listings
  where id = p_listing_id
  for update;

  if v_listing is null then
    raise exception 'listing not found';
  end if;
  if v_listing.pricing_mechanism <> 'D' then
    raise exception 'listing % is not mechanism D', p_listing_id;
  end if;
  if v_listing.status <> 'open' then
    -- MVP behavior per ROADMAP.md's explicit judgment call: reject outright rather than opening a
    -- tiebreak. Correct and safe, just not fair-optimal — the sealed-bid tiebreaker is deferred to
    -- Phase 1.5, contention-triggered.
    raise exception 'slot no longer available' using errcode = 'P0001';
  end if;
  if v_listing.reservation_deadline is not null and v_listing.reservation_deadline < now() then
    raise exception 'reservation deadline has passed';
  end if;

  v_deposit_cents := round(coalesce(v_listing.floor_price_cents, 0) * 0.10);

  insert into public.reservations (listing_id, advertiser_id, deposit_amount_cents, status, confirmation_deadline)
  values (p_listing_id, auth.uid(), v_deposit_cents, 'held', now() + p_response_window)
  returning * into v_reservation;

  update public.creator_listings set status = 'reserved' where id = p_listing_id;

  insert into public.audit_log (actor_id, action, target_table, target_id, after)
  values (auth.uid(), 'reservation.place', 'reservations', v_reservation.id, to_jsonb(v_reservation));

  insert into public.notifications (user_id, type, payload)
  values (
    v_listing.creator_id, 'reservation.new',
    jsonb_build_object('listing_id', v_listing.id, 'reservation_id', v_reservation.id,
      'message', 'New reservation on your listing — confirm your price before the deadline.')
  );

  return v_reservation;
end $$;

-- Creator (or delegated manager, band-checked) confirms the final price. price_cents must be at or
-- above the listing's floor. If called by a manager acting on the creator's behalf, the price is
-- checked against check_price_band() above; if it fails, the function raises rather than silently
-- letting the manager force a below-band price through — the UI should route that case to a
-- "request creator confirmation" flow instead (per ARCHITECTURE.md Section 3).
create or replace function public.confirm_deal_as(p_creator_id uuid, p_reservation_id uuid, p_price_cents int)
returns public.deals
language plpgsql security definer set search_path = public as $$
declare
  v_reservation public.reservations;
  v_listing public.creator_listings;
  v_is_manager boolean;
  v_deal public.deals;
begin
  if not public.is_authorized_for_creator(p_creator_id) then
    raise exception 'not authorized for creator %', p_creator_id;
  end if;

  v_is_manager := (auth.uid() <> p_creator_id);
  if v_is_manager and not public.check_price_band(
    (select listing_id from public.reservations where id = p_reservation_id), p_price_cents
  ) then
    raise exception 'price % is outside the manager''s authorized band — needs creator confirmation', p_price_cents;
  end if;

  select * into v_reservation from public.reservations where id = p_reservation_id for update;
  if v_reservation is null or v_reservation.status <> 'held' then
    raise exception 'reservation is not awaiting confirmation';
  end if;

  select * into v_listing from public.creator_listings where id = v_reservation.listing_id;
  if p_price_cents < coalesce(v_listing.floor_price_cents, 0) then
    raise exception 'price % is below the listing floor %', p_price_cents, v_listing.floor_price_cents;
  end if;

  update public.reservations set status = 'confirmed' where id = p_reservation_id;
  update public.creator_listings set status = 'deal' where id = v_reservation.listing_id;

  insert into public.deals (
    reservation_id, listing_id, creator_id, advertiser_id, manager_id,
    final_price_cents, deliverable_spec, delivery_due_at, disclosure_terms
  )
  values (
    p_reservation_id, v_listing.id, p_creator_id, v_reservation.advertiser_id,
    case when v_is_manager then auth.uid() else null end,
    p_price_cents,
    jsonb_build_object('platform', v_listing.platform, 'contentType', v_listing.content_type, 'description', v_listing.description),
    null,
    '#ad — this content includes a paid partnership. Disclosure terms per FTC Endorsement Guides.'
  )
  returning * into v_deal;

  insert into public.audit_log (actor_id, acting_as_id, action, target_table, target_id, after)
  values (auth.uid(), case when v_is_manager then p_creator_id else null end, 'reservation.confirm', 'deals', v_deal.id, to_jsonb(v_deal));

  insert into public.notifications (user_id, type, payload)
  values (
    v_deal.advertiser_id, 'deal.confirmed',
    jsonb_build_object('deal_id', v_deal.id, 'listing_id', v_deal.listing_id,
      'message', 'Your deal is confirmed at $' || (v_deal.final_price_cents / 100.0) || '.')
  );

  return v_deal;
end $$;

-- Called by the pg_cron job (set up once Phase 0's Supabase scheduling is wired up) for reservations
-- whose confirmation_deadline has passed with no confirmation. Refund logic is a no-op for now since
-- no Stripe deposit was actually charged yet (see file header) — this just resets the state machine.
create or replace function public.expire_reservation(p_reservation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_reservation public.reservations;
begin
  select * into v_reservation from public.reservations where id = p_reservation_id for update;
  if v_reservation is null or v_reservation.status <> 'held' then
    return; -- already resolved, nothing to do
  end if;

  update public.reservations set status = 'expired' where id = p_reservation_id;
  update public.creator_listings set status = 'open' where id = v_reservation.listing_id and status = 'reserved';

  insert into public.audit_log (actor_id, action, target_table, target_id, after)
  values (v_reservation.advertiser_id, 'reservation.expire', 'reservations', p_reservation_id, to_jsonb(v_reservation));

  insert into public.notifications (user_id, type, payload)
  select creator_id, 'reservation.expired',
    jsonb_build_object('listing_id', id, 'reservation_id', p_reservation_id,
      'message', 'A reservation on your listing expired without confirmation — it''s back on the market.')
  from public.creator_listings where id = v_reservation.listing_id;
end $$;
