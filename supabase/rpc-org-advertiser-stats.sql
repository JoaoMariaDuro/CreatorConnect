-- CreatorConnect — advertiser-org analytics ("creators sponsored" + rollup stats). Run after
-- orgs.sql and deals.sql. Powers /settings/org's advertiser-owner-only "Analytics" section — the
-- founder's ask for the org admin's page to show "users, creator sponored, analytics."
--
-- Deliberately aggregate-only, never raw deal rows. orgs.sql's own header states a non-goal:
-- "No org-level delegation authority over members' actions" and "org is a pure identity/roster
-- layer" — a plain member-to-member deals RLS bypass (so any org member could browse every OTHER
-- member's individual deals) would cross that line into a real new authority tier. Aggregating here,
-- inside a security-definer function, gives the owner rollup visibility across the org's members
-- without opening deals' own RLS to a wider audience — the two RPCs below are the only place org
-- membership ever touches deals, and only ever return counts/sums/creator ids, never a full deal row.
--
-- Owner-only (not "any active member"): org financials are the more sensitive half of "users,
-- creators sponsored, analytics" — same posture as who can see the manager commission ledger today.

create or replace function public.get_org_advertiser_stats(p_org_id uuid)
returns table (
  total_deals int,
  active_deals int,
  completed_deals int,
  total_spend_cents bigint,
  unique_creators int
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_org public.orgs;
begin
  if not public.is_active_org_owner(p_org_id) then
    raise exception 'not authorized — only an active owner can view org analytics';
  end if;

  select * into v_org from public.orgs where id = p_org_id;
  if v_org is null then
    raise exception 'org not found';
  end if;
  if v_org.org_type <> 'advertiser' then
    raise exception 'analytics are only available for advertiser orgs';
  end if;

  return query
  select
    count(*)::int,
    count(*) filter (where d.status in ('active', 'delivered'))::int,
    count(*) filter (where d.status = 'completed')::int,
    coalesce(sum(d.final_price_cents), 0)::bigint,
    count(distinct d.creator_id)::int
  from public.deals d
  where d.advertiser_id in (
    select user_id from public.org_members where org_id = p_org_id and status = 'active'
  );
end $$;

-- Per-creator rollup across every active member's deals — "creators sponsored." creator_id only;
-- the caller joins against public_profiles client-side for display_name/handle, same two-query
-- pattern used everywhere a view has no real FK to embed against (see /org/[handle]'s header comment).
create or replace function public.get_org_sponsored_creators(p_org_id uuid)
returns table (
  creator_id uuid,
  deal_count int,
  total_spend_cents bigint,
  last_deal_at timestamptz
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_org public.orgs;
begin
  if not public.is_active_org_owner(p_org_id) then
    raise exception 'not authorized — only an active owner can view sponsored creators';
  end if;

  select * into v_org from public.orgs where id = p_org_id;
  if v_org is null then
    raise exception 'org not found';
  end if;
  if v_org.org_type <> 'advertiser' then
    raise exception 'sponsored-creator rollups are only available for advertiser orgs';
  end if;

  return query
  select d.creator_id, count(*)::int, coalesce(sum(d.final_price_cents), 0)::bigint, max(d.confirmed_at)
  from public.deals d
  where d.advertiser_id in (
    select user_id from public.org_members where org_id = p_org_id and status = 'active'
  )
  group by d.creator_id
  order by max(d.confirmed_at) desc;
end $$;
