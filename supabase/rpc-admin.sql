-- CreatorConnect — founder/admin dispute resolution, plus a self-service test-role-switch RPC for the
-- founder's own account. Run after schema.sql, deals.sql, delegation.sql, and cron-scheduling.sql.
-- See ../docs/ROLE_ACCESS_AND_UX_SPEC.md.
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
--
-- set_own_test_role_as_admin() lets a platform admin flip their OWN `role` between
-- creator/advertiser/manager, so a solo founder can exercise all three role-differentiated UIs from
-- one account instead of juggling separate test logins. It only ever touches the caller's own row
-- (auth.uid()), only ever writes `role`, and never touches `is_platform_admin` — that flag stays
-- grantable only via the one-time manual SQL statement documented in ../supabase/README.md, on
-- purpose, per ROLE_ACCESS_AND_UX_SPEC.md's "no in-app way to grant is_platform_admin" rule. This RPC
-- is a security-definer escape hatch specifically for `role`, which schema.sql's updated "update own
-- profile" RLS policy otherwise locks against any self-update, admin or not.

create or replace function public.set_own_test_role_as_admin(p_role text)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare
  v_old_role text;
  v_profile public.profiles;
begin
  if not public.is_platform_admin() then
    raise exception 'not authorized — admin only';
  end if;
  -- Same three values as schema.sql's `profiles.role` check constraint
  -- (`check (role in ('creator', 'advertiser', 'manager'))`) — kept in sync by hand since Postgres
  -- doesn't expose the constraint's value list for a runtime lookup; if that constraint ever changes,
  -- this list must change with it.
  if p_role not in ('creator', 'advertiser', 'manager') then
    raise exception 'invalid role: %', p_role;
  end if;

  select role into v_old_role from public.profiles where id = auth.uid();

  update public.profiles set role = p_role where id = auth.uid() returning * into v_profile;

  insert into public.audit_log (actor_id, action, target_table, target_id, before, after)
  values (
    auth.uid(),
    'profile.admin_test_role_switch',
    'profiles',
    auth.uid(),
    jsonb_build_object('role', v_old_role),
    jsonb_build_object('role', p_role)
  );

  return v_profile;
end $$;

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
