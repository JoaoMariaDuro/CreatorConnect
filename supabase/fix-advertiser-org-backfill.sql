-- CreatorConnect — one-time backfill: give every existing advertiser without an org a self-org.
-- Run once, after rpc-advertiser-auto-org.sql. Safe to re-run — ensure_advertiser_org() no-ops for
-- anyone who already has any org_members row, so a second run touches nothing.
--
-- Needed because handle_new_user()'s advertiser-auto-org call only fires for signups AFTER this
-- feature shipped — every advertiser profile created earlier this session predates it.

do $$
declare
  v_profile record;
begin
  for v_profile in
    select p.id, p.display_name
    from public.profiles p
    where p.role = 'advertiser'
      and not exists (select 1 from public.org_members m where m.user_id = p.id)
  loop
    perform public.ensure_advertiser_org(v_profile.id, v_profile.display_name);
  end loop;
end $$;
