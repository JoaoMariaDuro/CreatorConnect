-- CreatorConnect — grant platform admins full read/manage access to every org. Run any time after
-- orgs.sql. Powers /admin/orgs (founder page to view every org and step in for support requests).
--
-- Same reasoning as fix-org-rls-recursion.sql / fix-org-member-self-leave.sql for being a standalone
-- file: orgs.sql's own `drop table ... cascade` at the top would destroy any org you've already
-- created just to pick up these policy changes. This file only replaces policies, touching no table
-- or existing row.
--
-- Mirrors the `or public.is_platform_admin()` bypass convention already used on deals/audit_log/
-- feedback (schema.sql, deals.sql, delegation.sql, feedback.sql) — read/support access only, not a
-- new authority tier: admin still can't change org_type (the with-check subquery in "owner updates
-- own org" locks it regardless of caller), and creating an org as admin goes through the separate
-- create_org_as_admin() security-definer RPC (rpc-admin-orgs.sql), not a new insert policy here.

drop policy if exists "active members read own org" on public.orgs;
create policy "active members read own org" on public.orgs
  for select
  using (public.is_active_org_member(id) or public.is_platform_admin());

drop policy if exists "owner updates own org" on public.orgs;
create policy "owner updates own org" on public.orgs
  for update
  using (public.is_active_org_owner(id) or public.is_platform_admin())
  with check (
    (public.is_active_org_owner(id) or public.is_platform_admin())
    and org_type = (select o.org_type from public.orgs o where o.id = orgs.id)
  );

drop policy if exists "active members read own roster" on public.org_members;
create policy "active members read own roster" on public.org_members
  for select
  using (public.is_active_org_member(org_id) or user_id = auth.uid() or public.is_platform_admin());

drop policy if exists "owner manages member rows" on public.org_members;
create policy "owner manages member rows" on public.org_members
  for update
  using (public.is_active_org_owner(org_id) or public.is_platform_admin())
  with check (public.is_active_org_owner(org_id) or public.is_platform_admin());
