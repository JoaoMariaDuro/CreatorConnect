-- CreatorConnect — delivery sign-off, dispute flagging, and release. Run after rpc-mechanism-d.sql.
-- See ../docs/ARCHITECTURE.md Section 4 and ../docs/ROADMAP.md Phase 1 epic 7.
--
-- IMPORTANT: same caveat as rpc-mechanism-d.sql — no Stripe integration yet (roadmap Phase 0 items
-- 0.4/0.5 aren't done). release_delivery_balance() flips deals.status to 'completed' and is the
-- correct place a future Stripe Transfer call would go (per ARCHITECTURE.md Section 4's
-- release_delivery_balance design), but it doesn't move any money yet — the state machine and the
-- dispute-freezes-release guarantee are real and testable now, independent of payments.

create or replace function public.confirm_delivery_as(p_deal_id uuid)
returns public.deals
language plpgsql security definer set search_path = public as $$
declare
  v_deal public.deals;
begin
  select * into v_deal from public.deals where id = p_deal_id for update;
  if v_deal is null then
    raise exception 'deal not found';
  end if;
  if auth.uid() <> v_deal.advertiser_id then
    raise exception 'only the advertiser can confirm delivery';
  end if;
  if v_deal.status <> 'active' then
    raise exception 'deal is not active';
  end if;

  update public.deals
  set status = 'delivered', delivery_confirmed_at = now(), auto_release_at = now() + interval '5 days'
  where id = p_deal_id
  returning * into v_deal;

  insert into public.audit_log (actor_id, action, target_table, target_id, after)
  values (auth.uid(), 'deal.delivery_confirmed', 'deals', p_deal_id, to_jsonb(v_deal));

  insert into public.notifications (user_id, type, payload)
  values (v_deal.creator_id, 'delivery.confirmed',
    jsonb_build_object('deal_id', v_deal.id,
      'message', 'Delivery confirmed — payment releases automatically in 5 days unless disputed.'));

  return v_deal;
end $$;

-- Either party (or a delegated manager) can flag a dispute before auto-release fires. This freezes
-- release_delivery_balance() below — checked in the same function/transaction as the release, so
-- there's no race where a dispute lands after release already happened (ARCHITECTURE.md Section 4).
create or replace function public.flag_dispute_as(p_deal_id uuid, p_reason text default null)
returns public.deals
language plpgsql security definer set search_path = public as $$
declare
  v_deal public.deals;
begin
  select * into v_deal from public.deals where id = p_deal_id for update;
  if v_deal is null then
    raise exception 'deal not found';
  end if;
  if auth.uid() <> v_deal.advertiser_id and not public.is_authorized_for_creator(v_deal.creator_id) then
    raise exception 'not a party to this deal';
  end if;
  if v_deal.status not in ('active', 'delivered') then
    raise exception 'deal is not in a disputable state';
  end if;

  update public.deals set status = 'disputed' where id = p_deal_id returning * into v_deal;

  insert into public.audit_log (actor_id, action, target_table, target_id, after)
  values (auth.uid(), 'deal.disputed', 'deals', p_deal_id, jsonb_build_object('deal', to_jsonb(v_deal), 'reason', p_reason));

  insert into public.notifications (user_id, type, payload)
  values (
    case when auth.uid() = v_deal.advertiser_id then v_deal.creator_id else v_deal.advertiser_id end,
    'deal.disputed',
    jsonb_build_object('deal_id', v_deal.id, 'message', 'A deal was flagged as disputed and is now frozen pending review.')
  );

  return v_deal;
end $$;

-- Called by advertiser sign-off (immediately) or the future pg_cron auto-release job (after the
-- 5-day window). Checks status != 'disputed' inside this same function so a dispute flagged a moment
-- before this runs reliably blocks release — no Stripe Transfer call exists yet (see file header),
-- this is the state-machine half of what ARCHITECTURE.md Section 4 describes.
create or replace function public.release_delivery_balance(p_deal_id uuid)
returns public.deals
language plpgsql security definer set search_path = public as $$
declare
  v_deal public.deals;
begin
  select * into v_deal from public.deals where id = p_deal_id for update;
  if v_deal is null then
    raise exception 'deal not found';
  end if;
  if v_deal.status = 'disputed' then
    raise exception 'deal is disputed — release is frozen';
  end if;
  if v_deal.status <> 'delivered' then
    raise exception 'deal is not awaiting release';
  end if;

  update public.deals set status = 'completed' where id = p_deal_id returning * into v_deal;

  update public.profiles set completed_deals_count = completed_deals_count + 1 where id = v_deal.creator_id;

  insert into public.audit_log (actor_id, action, target_table, target_id, after)
  values (v_deal.advertiser_id, 'deal.completed', 'deals', p_deal_id, to_jsonb(v_deal));

  insert into public.notifications (user_id, type, payload)
  values (v_deal.creator_id, 'deal.completed',
    jsonb_build_object('deal_id', v_deal.id, 'message', 'A deal completed and payment released.'));

  return v_deal;
end $$;
