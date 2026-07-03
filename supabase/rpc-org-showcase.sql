-- CreatorConnect — agency showcase propose/respond lifecycle. Run after org-showcase.sql.
-- See that file's header for the dual-consent design this implements.
--
-- Renamed from "company" to "org" terminology (founder's call). Drops the old function names first —
-- `create or replace function` doesn't rename an existing function under a different name, it just
-- creates/replaces the one it's told to, so the old propose_showcase_creator/respond_showcase_creator
-- names (which already had these exact signatures) are dropped explicitly rather than left as stale
-- duplicates. (Their signatures are unchanged by this rename, so create-or-replace under the SAME
-- name would have been enough if we were only changing the body — we're not: the body now
-- references orgs/org_members/org_showcased_creators, which only exist after orgs.sql/org-showcase.sql
-- have run, so this file must run after those regardless.)

drop function if exists public.propose_showcase_creator(uuid, uuid);
drop function if exists public.respond_showcase_creator(uuid, boolean);

-- An active org member proposes showcasing a creator THEY personally represent. Security definer
-- only because it's convenient to centralize the cross-table check here (the same shape could
-- theoretically be an RLS insert policy with a subquery, but every other "does the caller really have
-- the relationship they're claiming" check in this codebase lives in an RPC, and this one is no
-- different: check_price_band, invite_manager_by_email, invite_org_member_by_email).
create or replace function public.propose_showcase_creator(p_org_id uuid, p_creator_id uuid)
returns public.org_showcased_creators
language plpgsql security definer set search_path = public as $$
declare
  v_org public.orgs;
  v_creator_name text;
  v_has_link boolean;
  v_row public.org_showcased_creators;
begin
  if not public.is_active_org_member(p_org_id) then
    raise exception 'not authorized — you must be an active member of this org';
  end if;

  select * into v_org from public.orgs where id = p_org_id;
  if v_org is null then
    raise exception 'org not found';
  end if;
  if v_org.org_type <> 'manager' then
    raise exception 'only manager/agency orgs can showcase creators';
  end if;

  -- The proposer specifically must be the manager with the real delegated relationship — not just
  -- any member of the org. Without this, an org member with no actual connection to a creator could
  -- propose showcasing them.
  select exists (
    select 1 from public.manager_creator_links
    where manager_id = auth.uid() and creator_id = p_creator_id and status = 'active'
  ) into v_has_link;
  if not v_has_link then
    raise exception 'you must have an active manager relationship with this creator to showcase them';
  end if;

  select display_name into v_creator_name from public.profiles where id = p_creator_id;

  insert into public.org_showcased_creators (org_id, creator_id, proposed_by, status, proposed_at)
  values (p_org_id, p_creator_id, auth.uid(), 'pending', now())
  on conflict (org_id, creator_id) do update
    set status = 'pending', proposed_by = auth.uid(), proposed_at = now(), responded_at = null
  returning * into v_row;

  insert into public.audit_log (actor_id, action, target_table, target_id, after)
  values (auth.uid(), 'org_showcase.propose', 'org_showcased_creators', v_row.id, to_jsonb(v_row));

  insert into public.notifications (user_id, type, payload)
  values (p_creator_id, 'org_showcase.proposed',
    jsonb_build_object('org_id', p_org_id, 'showcase_id', v_row.id,
      'message', v_org.name || ' wants to feature you on their public org page — you choose whether to appear.'));

  return v_row;
end $$;

-- Creator accepts or declines their own pending proposal. Chosen as an RPC (not a plain client
-- update, even though the "creator manages own showcase consent" RLS policy in org-showcase.sql
-- would technically allow the update directly) so responded_at is set atomically with the status
-- change and every active owner gets notified in the same transaction — same reasoning as
-- accept_org_invite.
create or replace function public.respond_showcase_creator(p_showcase_id uuid, p_accept boolean)
returns public.org_showcased_creators
language plpgsql security definer set search_path = public as $$
declare
  v_row public.org_showcased_creators;
  v_org public.orgs;
  v_creator_name text;
begin
  select * into v_row from public.org_showcased_creators where id = p_showcase_id for update;
  if v_row is null then
    raise exception 'showcase proposal not found';
  end if;
  if v_row.creator_id <> auth.uid() then
    raise exception 'not your proposal to respond to';
  end if;
  if v_row.status <> 'pending' then
    raise exception 'this proposal has already been responded to';
  end if;

  update public.org_showcased_creators
  set status = case when p_accept then 'accepted' else 'declined' end, responded_at = now()
  where id = p_showcase_id
  returning * into v_row;

  select * into v_org from public.orgs where id = v_row.org_id;
  select display_name into v_creator_name from public.profiles where id = auth.uid();

  insert into public.audit_log (actor_id, action, target_table, target_id, after)
  values (auth.uid(), 'org_showcase.respond', 'org_showcased_creators', p_showcase_id, to_jsonb(v_row));

  insert into public.notifications (user_id, type, payload)
  select om.user_id, 'org_showcase.responded',
    jsonb_build_object('org_id', v_row.org_id, 'showcase_id', v_row.id,
      'message', v_creator_name || (case when p_accept then ' accepted' else ' declined' end) || ' being featured on ' || v_org.name || '''s page.')
  from public.org_members om
  where om.org_id = v_row.org_id and om.role = 'owner' and om.status = 'active';

  return v_row;
end $$;

-- Withdrawing/retracting a showcase (either side) needs no RPC — both RLS policies in
-- org-showcase.sql already cover it directly: the creator can update their own row to 'declined' at
-- any time, and an active org member can do the same via "org member retracts a showcase" (which can
-- only ever move status to 'declined', never 'accepted' — see that policy's own comment for why).
