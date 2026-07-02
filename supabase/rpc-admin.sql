-- CreatorConnect — founder/admin dispute resolution. Run after schema.sql, deals.sql, delegation.sql,
-- and cron-scheduling.sql. See ../docs/ROLE_ACCESS_AND_UX_SPEC.md.
--
-- IMPORTANT: same caveat as rpc-delivery.sql — no Stripe integration yet (roadmap Phase 0 items
-- 0.4/0.5 aren't done). resolve_dispute_as_admin() only moves deals.status through the state
-- machine; it deliberately does NOT insert into escrow_transactions, which is service-role-write-only
-- per deals.sql's own schema comment. A future Stripe Transfer/refund call would go where this
-- function currently just flips status, once Stripe Connect is wired up.
--
-- The authorization check (is_platform_admin()) and the audit_log.actor_id attribution both happen
-- at the auth.uid() layer, first thing in the function body — so the audit trail always shows the
-- founder who made the call, never an opaque backend identity.

create or replace function public.resolve_dispute_as_admin(
  p_deal_id uuid,
  p_resolution text,
  p_refund_amount_cents int default null,
  p_notes text default null
)
returns public.deals
language plpgsql security definer set search_path = public as $$
declare
  v_deal public.deals;
  v_deal_before public.deals;
begin
  if not public.is_platform_admin() then
    raise exception 'not authorized — admin only';
  end if;

  select * into v_deal from public.deals where id = p_deal_id for update;
  if v_deal is null then
    raise exception 'deal not found';
  end if;
  if v_deal.status <> 'disputed' then
    raise exception 'deal is not disputed — nothing to resolve';
  end if;
  if p_resolution not in ('release', 'refund', 'cancel') then
    raise exception 'invalid resolution: %', p_resolution;
  end if;

  v_deal_before := v_deal;

  if p_resolution = 'release' then
    update public.deals set status = 'completed' where id = p_deal_id returning * into v_deal;
  else
    -- 'refund' and 'cancel' both end the deal without completion — no real Stripe/escrow writes
    -- happen here (see file header).
    update public.deals set status = 'cancelled' where id = p_deal_id returning * into v_deal;
  end if;

  insert into public.audit_log (actor_id, action, target_table, target_id, before, after)
  values (
    auth.uid(),
    'deal.resolved_by_admin',
    'deals',
    p_deal_id,
    to_jsonb(v_deal_before),
    jsonb_build_object(
      'deal', to_jsonb(v_deal),
      'resolution', p_resolution,
      'refund_amount_cents', p_refund_amount_cents,
      'notes', p_notes
    )
  );

  return v_deal;
end $$;
