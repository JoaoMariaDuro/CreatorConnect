-- CreatorConnect — fix infinite recursion in org RLS helper functions. Run any time after orgs.sql.
--
-- is_active_org_owner()/is_active_org_member() query org_members, but are ALSO used inside
-- org_members' own "active members read own roster" / "owner inserts members" / "owner manages
-- member rows" RLS policies. Without SECURITY DEFINER, evaluating those policies calls the
-- function, which queries org_members, which re-evaluates the same policy, which calls the
-- function again — infinite recursion, confirmed live as "stack depth limit exceeded" once
-- org_members had a real row to evaluate against (an empty-table select never triggers it, which is
-- why this wasn't caught until real data existed). SECURITY DEFINER makes the internal query run as
-- the function owner, bypassing RLS instead of re-triggering it — auth.uid() still reflects the
-- real caller throughout, so this doesn't change who the check is actually checking, only how it
-- reads the table internally.
--
-- This is a `create or replace function` on the SAME name/signature — safe to run without touching
-- any table, any existing row, or any policy. Does NOT drop or recreate orgs/org_members, unlike
-- orgs.sql itself — deliberately, so this can be applied without disturbing any org already created.

create or replace function public.is_active_org_owner(p_org_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.org_members
    where org_id = p_org_id and user_id = auth.uid() and role = 'owner' and status = 'active'
  );
$$;

create or replace function public.is_active_org_member(p_org_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.org_members
    where org_id = p_org_id and user_id = auth.uid() and status = 'active'
  );
$$;
