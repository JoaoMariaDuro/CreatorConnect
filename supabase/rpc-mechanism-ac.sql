-- CreatorConnect — mechanisms A and C's RPC functions (Phase 1-FastFollow). Run after cron-scheduling.sql.
-- See ../docs/ARCHITECTURE.md Section 3, ../docs/ROADMAP.md epic 9.
--
-- Mirrors rpc-mechanism-d.sql's pattern but for the two lighter-weight mechanisms: no deposit, no
-- concurrency lock needed (no shared resource being raced over — an offer thread or exclusivity grant
-- belongs to exactly one advertiser at a time by construction, not by a lock). Band-checks apply only
-- where a price actually gets locked in (accepting/converting), not on every negotiation step — matches
-- ARCHITECTURE.md Section 3's reasoning: granting exclusivity or sending a counter isn't itself a
-- commitment, only the terminal accept/convert is.

-- ==================== Mechanism A: listing_offers ====================

-- Advertiser's initial offer, or either party's counter. p_from must match who's actually calling
-- (advertiser calling submits as 'advertiser'; creator or their delegated manager submits as
-- 'creator' — manager counters are band-checked, per ARCHITECTURE.md's "a lowball counter is
-- functionally the same authorization risk as accepting a lowball offer directly").
create or replace function public.submit_offer_as(
	p_listing_id uuid, p_from text, p_amount_cents int, p_note text default null
)
returns public.listing_offers
language plpgsql security definer set search_path = public as $$
declare
	v_listing public.creator_listings;
	v_offer public.listing_offers;
	v_is_manager boolean;
begin
	select * into v_listing from public.creator_listings where id = p_listing_id;
	if v_listing is null or v_listing.pricing_mechanism <> 'A' then
		raise exception 'listing % is not mechanism A', p_listing_id;
	end if;
	if p_from not in ('advertiser', 'creator') then
		raise exception 'invalid p_from';
	end if;

	if p_from = 'advertiser' then
		-- must be the listing's current advertiser (the one with the open thread), or a fresh advertiser
		-- if no thread exists yet — enforced implicitly by advertiser_id being set to auth.uid() below.
		null;
	else
		if not public.is_authorized_for_creator(v_listing.creator_id) then
			raise exception 'not authorized for creator %', v_listing.creator_id;
		end if;
		v_is_manager := (auth.uid() <> v_listing.creator_id);
		if v_is_manager and not public.check_price_band(p_listing_id, p_amount_cents) then
			raise exception 'counter-offer % is outside the manager''s authorized band', p_amount_cents;
		end if;
	end if;

	-- mark any existing open offer on this listing as superseded (single active thread at a time,
	-- per ARCHITECTURE.md Section 8 risk #1's "one open thread per listing" note)
	update public.listing_offers set status = 'withdrawn' where listing_id = p_listing_id and status = 'open';

	insert into public.listing_offers (listing_id, advertiser_id, offer_amount_cents, proposed_by, status, parent_offer_id)
	select
		p_listing_id,
		case when p_from = 'advertiser' then auth.uid() else (select advertiser_id from public.listing_offers where listing_id = p_listing_id order by created_at desc limit 1) end,
		p_amount_cents, p_from, 'open',
		(select id from public.listing_offers where listing_id = p_listing_id order by created_at desc limit 1)
	returning * into v_offer;

	update public.creator_listings set status = 'pending' where id = p_listing_id;

	insert into public.audit_log (actor_id, acting_as_id, action, target_table, target_id, after)
	values (auth.uid(), case when p_from = 'creator' and v_is_manager then v_listing.creator_id else null end, 'offer.submit', 'listing_offers', v_offer.id, to_jsonb(v_offer));

	insert into public.notifications (user_id, type, payload)
	values (
		case when p_from = 'advertiser' then v_listing.creator_id else v_offer.advertiser_id end,
		'offer.new',
		jsonb_build_object('listing_id', p_listing_id, 'offer_id', v_offer.id,
			'message', case when p_from = 'advertiser' then 'New offer received on your listing.' else 'The creator sent a counter-offer.' end)
	);

	return v_offer;
end $$;

-- Creator (or delegated manager, band-checked) accepts the advertiser's current offer.
create or replace function public.accept_offer_as(p_creator_id uuid, p_offer_id uuid)
returns public.deals
language plpgsql security definer set search_path = public as $$
declare
	v_offer public.listing_offers;
	v_listing public.creator_listings;
	v_is_manager boolean;
	v_deal public.deals;
begin
	if not public.is_authorized_for_creator(p_creator_id) then
		raise exception 'not authorized for creator %', p_creator_id;
	end if;

	select * into v_offer from public.listing_offers where id = p_offer_id for update;
	if v_offer is null or v_offer.status <> 'open' or v_offer.proposed_by <> 'advertiser' then
		raise exception 'offer is not an open advertiser offer';
	end if;

	v_is_manager := (auth.uid() <> p_creator_id);
	if v_is_manager and not public.check_price_band(v_offer.listing_id, v_offer.offer_amount_cents) then
		raise exception 'offer amount % is outside the manager''s authorized band', v_offer.offer_amount_cents;
	end if;

	select * into v_listing from public.creator_listings where id = v_offer.listing_id;

	update public.listing_offers set status = 'accepted' where id = p_offer_id;
	update public.creator_listings set status = 'deal' where id = v_listing.id;

	insert into public.deals (offer_id, listing_id, creator_id, advertiser_id, manager_id, final_price_cents, deliverable_spec, disclosure_terms)
	values (
		p_offer_id, v_listing.id, p_creator_id, v_offer.advertiser_id,
		case when v_is_manager then auth.uid() else null end,
		v_offer.offer_amount_cents,
		jsonb_build_object('platform', v_listing.platform, 'contentType', v_listing.content_type, 'description', v_listing.description),
		'#ad — this content includes a paid partnership. Disclosure terms per FTC Endorsement Guides.'
	)
	returning * into v_deal;

	insert into public.audit_log (actor_id, acting_as_id, action, target_table, target_id, after)
	values (auth.uid(), case when v_is_manager then p_creator_id else null end, 'offer.accept', 'deals', v_deal.id, to_jsonb(v_deal));

	insert into public.notifications (user_id, type, payload)
	values (v_deal.advertiser_id, 'deal.confirmed',
		jsonb_build_object('deal_id', v_deal.id, 'listing_id', v_deal.listing_id,
			'message', 'Your deal is confirmed at $' || (v_deal.final_price_cents / 100.0) || '.'));

	return v_deal;
end $$;

-- Advertiser accepts the creator's current counter-offer. No delegation on the advertiser side, so
-- no band check — just an ownership check against the offer's advertiser_id.
create or replace function public.accept_offer_as_advertiser(p_offer_id uuid)
returns public.deals
language plpgsql security definer set search_path = public as $$
declare
	v_offer public.listing_offers;
	v_listing public.creator_listings;
	v_deal public.deals;
begin
	select * into v_offer from public.listing_offers where id = p_offer_id for update;
	if v_offer is null or v_offer.status <> 'open' or v_offer.proposed_by <> 'creator' then
		raise exception 'offer is not an open creator counter-offer';
	end if;
	if v_offer.advertiser_id <> auth.uid() then
		raise exception 'not your offer thread';
	end if;

	select * into v_listing from public.creator_listings where id = v_offer.listing_id;

	update public.listing_offers set status = 'accepted' where id = p_offer_id;
	update public.creator_listings set status = 'deal' where id = v_listing.id;

	insert into public.deals (offer_id, listing_id, creator_id, advertiser_id, final_price_cents, deliverable_spec, disclosure_terms)
	values (
		p_offer_id, v_listing.id, v_listing.creator_id, v_offer.advertiser_id, v_offer.offer_amount_cents,
		jsonb_build_object('platform', v_listing.platform, 'contentType', v_listing.content_type, 'description', v_listing.description),
		'#ad — this content includes a paid partnership. Disclosure terms per FTC Endorsement Guides.'
	)
	returning * into v_deal;

	insert into public.audit_log (actor_id, action, target_table, target_id, after)
	values (auth.uid(), 'offer.accept', 'deals', v_deal.id, to_jsonb(v_deal));

	insert into public.notifications (user_id, type, payload)
	values (v_deal.creator_id, 'deal.confirmed',
		jsonb_build_object('deal_id', v_deal.id, 'listing_id', v_deal.listing_id,
			'message', 'Your deal is confirmed at $' || (v_deal.final_price_cents / 100.0) || '.'));

	return v_deal;
end $$;

-- ==================== Mechanism C: listing_exclusivity_grants ====================

-- Advertiser requests exclusive early access. No band check — not a price commitment, per
-- ARCHITECTURE.md Section 3.
create or replace function public.request_exclusivity_as(p_listing_id uuid)
returns public.listing_exclusivity_grants
language plpgsql security definer set search_path = public as $$
declare
	v_listing public.creator_listings;
	v_grant public.listing_exclusivity_grants;
begin
	select * into v_listing from public.creator_listings where id = p_listing_id for update;
	if v_listing is null or v_listing.pricing_mechanism <> 'C' then
		raise exception 'listing % is not mechanism C', p_listing_id;
	end if;
	if v_listing.status <> 'open' then
		raise exception 'listing already has an active exclusivity grant or deal';
	end if;

	insert into public.listing_exclusivity_grants (listing_id, advertiser_id, window_starts_at, window_ends_at, status)
	values (p_listing_id, auth.uid(), now(), now() + coalesce(v_listing.exclusivity_window, interval '7 days'), 'active')
	returning * into v_grant;

	update public.creator_listings set status = 'pending' where id = p_listing_id;

	insert into public.audit_log (actor_id, action, target_table, target_id, after)
	values (auth.uid(), 'exclusivity.request', 'listing_exclusivity_grants', v_grant.id, to_jsonb(v_grant));

	insert into public.notifications (user_id, type, payload)
	values (v_listing.creator_id, 'exclusivity.requested',
		jsonb_build_object('listing_id', p_listing_id, 'grant_id', v_grant.id,
			'message', 'An advertiser requested exclusive early access to your listing.'));

	return v_grant;
end $$;

-- Either party proposes/counters terms within an active grant. Not band-checked — bilateral
-- negotiation itself isn't a price commitment (see file header); only convert_exclusivity_as is.
create or replace function public.propose_exclusivity_terms_as(
	p_grant_id uuid, p_from text, p_price_cents int, p_terms text
)
returns public.listing_exclusivity_grants
language plpgsql security definer set search_path = public as $$
declare
	v_grant public.listing_exclusivity_grants;
begin
	select * into v_grant from public.listing_exclusivity_grants where id = p_grant_id for update;
	if v_grant is null or v_grant.status <> 'active' then
		raise exception 'grant is not active';
	end if;
	if p_from not in ('advertiser', 'creator') then
		raise exception 'invalid p_from';
	end if;
	if p_from = 'advertiser' and v_grant.advertiser_id <> auth.uid() then
		raise exception 'not your exclusivity grant';
	end if;
	if p_from = 'creator' then
		declare v_creator_id uuid;
		begin
			select creator_id into v_creator_id from public.creator_listings where id = v_grant.listing_id;
			if not public.is_authorized_for_creator(v_creator_id) then
				raise exception 'not authorized for creator %', v_creator_id;
			end if;
		end;
	end if;

	update public.listing_exclusivity_grants
	set negotiation = jsonb_build_object('proposedPrice', p_price_cents, 'proposedTerms', p_terms, 'status', 'proposed', 'from', p_from)
	where id = p_grant_id
	returning * into v_grant;

	insert into public.audit_log (actor_id, action, target_table, target_id, after)
	values (auth.uid(), 'exclusivity.propose_terms', 'listing_exclusivity_grants', p_grant_id, to_jsonb(v_grant));

	insert into public.notifications (user_id, type, payload)
	select
		case when p_from = 'advertiser' then l.creator_id else v_grant.advertiser_id end,
		'exclusivity.terms_proposed',
		jsonb_build_object('grant_id', v_grant.id, 'listing_id', v_grant.listing_id,
			'message', case when p_from = 'advertiser' then 'An advertiser proposed terms for your exclusivity grant.' else 'The creator proposed terms for your exclusivity grant.' end)
	from public.creator_listings l where l.id = v_grant.listing_id;

	return v_grant;
end $$;

-- Creator (or delegated manager, band-checked against the current proposedPrice) converts the
-- negotiated terms into a real deal. This is where mechanism C actually locks in a price.
create or replace function public.convert_exclusivity_as(p_creator_id uuid, p_grant_id uuid)
returns public.deals
language plpgsql security definer set search_path = public as $$
declare
	v_grant public.listing_exclusivity_grants;
	v_listing public.creator_listings;
	v_is_manager boolean;
	v_price int;
	v_terms text;
	v_deal public.deals;
begin
	if not public.is_authorized_for_creator(p_creator_id) then
		raise exception 'not authorized for creator %', p_creator_id;
	end if;

	select * into v_grant from public.listing_exclusivity_grants where id = p_grant_id for update;
	if v_grant is null or v_grant.status <> 'active' or v_grant.negotiation is null then
		raise exception 'grant has no proposed terms to convert';
	end if;

	v_price := (v_grant.negotiation ->> 'proposedPrice')::int;
	v_terms := v_grant.negotiation ->> 'proposedTerms';

	v_is_manager := (auth.uid() <> p_creator_id);
	if v_is_manager and not public.check_price_band(v_grant.listing_id, v_price) then
		raise exception 'proposed price % is outside the manager''s authorized band', v_price;
	end if;

	select * into v_listing from public.creator_listings where id = v_grant.listing_id;

	update public.listing_exclusivity_grants set status = 'converted' where id = p_grant_id;
	update public.creator_listings set status = 'deal' where id = v_listing.id;

	insert into public.deals (exclusivity_grant_id, listing_id, creator_id, advertiser_id, manager_id, final_price_cents, deliverable_spec, disclosure_terms)
	values (
		p_grant_id, v_listing.id, p_creator_id, v_grant.advertiser_id,
		case when v_is_manager then auth.uid() else null end,
		v_price,
		jsonb_build_object('platform', v_listing.platform, 'contentType', v_listing.content_type, 'description', coalesce(v_terms, v_listing.description)),
		'#ad — this content includes a paid partnership. Disclosure terms per FTC Endorsement Guides.'
	)
	returning * into v_deal;

	insert into public.audit_log (actor_id, acting_as_id, action, target_table, target_id, after)
	values (auth.uid(), case when v_is_manager then p_creator_id else null end, 'exclusivity.convert', 'deals', v_deal.id, to_jsonb(v_deal));

	insert into public.notifications (user_id, type, payload)
	values (v_deal.advertiser_id, 'deal.confirmed',
		jsonb_build_object('deal_id', v_deal.id, 'listing_id', v_deal.listing_id,
			'message', 'Your deal is confirmed at $' || (v_deal.final_price_cents / 100.0) || '.'));

	return v_deal;
end $$;

-- Advertiser-side accept of the creator's current proposed terms — same convert, no band check.
create or replace function public.convert_exclusivity_as_advertiser(p_grant_id uuid)
returns public.deals
language plpgsql security definer set search_path = public as $$
declare
	v_grant public.listing_exclusivity_grants;
	v_listing public.creator_listings;
	v_price int;
	v_terms text;
	v_deal public.deals;
begin
	select * into v_grant from public.listing_exclusivity_grants where id = p_grant_id for update;
	if v_grant is null or v_grant.status <> 'active' or v_grant.negotiation is null then
		raise exception 'grant has no proposed terms to convert';
	end if;
	if v_grant.advertiser_id <> auth.uid() then
		raise exception 'not your exclusivity grant';
	end if;

	v_price := (v_grant.negotiation ->> 'proposedPrice')::int;
	v_terms := v_grant.negotiation ->> 'proposedTerms';

	select * into v_listing from public.creator_listings where id = v_grant.listing_id;

	update public.listing_exclusivity_grants set status = 'converted' where id = p_grant_id;
	update public.creator_listings set status = 'deal' where id = v_listing.id;

	insert into public.deals (exclusivity_grant_id, listing_id, creator_id, advertiser_id, final_price_cents, deliverable_spec, disclosure_terms)
	values (
		p_grant_id, v_listing.id, v_listing.creator_id, v_grant.advertiser_id, v_price,
		jsonb_build_object('platform', v_listing.platform, 'contentType', v_listing.content_type, 'description', coalesce(v_terms, v_listing.description)),
		'#ad — this content includes a paid partnership. Disclosure terms per FTC Endorsement Guides.'
	)
	returning * into v_deal;

	insert into public.audit_log (actor_id, action, target_table, target_id, after)
	values (auth.uid(), 'exclusivity.convert', 'deals', v_deal.id, to_jsonb(v_deal));

	insert into public.notifications (user_id, type, payload)
	values (v_deal.creator_id, 'deal.confirmed',
		jsonb_build_object('deal_id', v_deal.id, 'listing_id', v_deal.listing_id,
			'message', 'Your deal is confirmed at $' || (v_deal.final_price_cents / 100.0) || '.'));

	return v_deal;
end $$;

-- Called by the (not-yet-scheduled) expiry job for C, mirroring expire_reservation for D — see
-- ../docs/ARCHITECTURE.md Section 5. Not wired into cron-scheduling.sql yet in this pass; add a
-- third cron.schedule() call there when ready, same pattern as the other two jobs.
create or replace function public.expire_exclusivity(p_grant_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
	v_grant public.listing_exclusivity_grants;
begin
	select * into v_grant from public.listing_exclusivity_grants where id = p_grant_id for update;
	if v_grant is null or v_grant.status <> 'active' then
		return;
	end if;

	update public.listing_exclusivity_grants set status = 'expired' where id = p_grant_id;
	update public.creator_listings set status = 'open' where id = v_grant.listing_id and status = 'pending';

	insert into public.audit_log (actor_id, action, target_table, target_id, after)
	values (v_grant.advertiser_id, 'exclusivity.expire', 'listing_exclusivity_grants', p_grant_id, to_jsonb(v_grant));

	insert into public.notifications (user_id, type, payload)
	select creator_id, 'exclusivity.expired',
		jsonb_build_object('listing_id', id, 'grant_id', p_grant_id,
			'message', 'An exclusivity grant on your listing expired.')
	from public.creator_listings where id = v_grant.listing_id;
end $$;
