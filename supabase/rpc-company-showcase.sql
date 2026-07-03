-- CreatorConnect — agency showcase propose/respond lifecycle. Run after company-showcase.sql.
-- See that file's header for the dual-consent design this implements.

-- An active company member proposes showcasing a creator THEY personally represent. Security
-- definer only because it's convenient to centralize the cross-table check here (the same shape
-- could theoretically be an RLS insert policy with a subquery, but every other "does the caller
-- really have the relationship they're claiming" check in this codebase lives in an RPC, and this
-- one is no different: check_price_band, invite_manager_by_email, invite_company_member_by_email).
create or replace function public.propose_showcase_creator(p_company_id uuid, p_creator_id uuid)
returns public.company_showcased_creators
language plpgsql security definer set search_path = public as $$
declare
  v_company public.companies;
  v_creator_name text;
  v_has_link boolean;
  v_row public.company_showcased_creators;
begin
  if not public.is_active_company_member(p_company_id) then
    raise exception 'not authorized — you must be an active member of this company';
  end if;

  select * into v_company from public.companies where id = p_company_id;
  if v_company is null then
    raise exception 'company not found';
  end if;
  if v_company.company_type <> 'manager' then
    raise exception 'only manager/agency companies can showcase creators';
  end if;

  -- The proposer specifically must be the manager with the real delegated relationship — not just
  -- any member of the company. Without this, a company member with no actual connection to a
  -- creator could propose showcasing them.
  select exists (
    select 1 from public.manager_creator_links
    where manager_id = auth.uid() and creator_id = p_creator_id and status = 'active'
  ) into v_has_link;
  if not v_has_link then
    raise exception 'you must have an active manager relationship with this creator to showcase them';
  end if;

  select display_name into v_creator_name from public.profiles where id = p_creator_id;

  insert into public.company_showcased_creators (company_id, creator_id, proposed_by, status, proposed_at)
  values (p_company_id, p_creator_id, auth.uid(), 'pending', now())
  on conflict (company_id, creator_id) do update
    set status = 'pending', proposed_by = auth.uid(), proposed_at = now(), responded_at = null
  returning * into v_row;

  insert into public.audit_log (actor_id, action, target_table, target_id, after)
  values (auth.uid(), 'company_showcase.propose', 'company_showcased_creators', v_row.id, to_jsonb(v_row));

  insert into public.notifications (user_id, type, payload)
  values (p_creator_id, 'company_showcase.proposed',
    jsonb_build_object('company_id', p_company_id, 'showcase_id', v_row.id,
      'message', v_company.name || ' wants to feature you on their public company page — you choose whether to appear.'));

  return v_row;
end $$;

-- Creator accepts or declines their own pending proposal. Chosen as an RPC (not a plain client
-- update, even though the "creator manages own showcase consent" RLS policy in company-showcase.sql
-- would technically allow the update directly) so responded_at is set atomically with the status
-- change and every active owner gets notified in the same transaction — same reasoning as
-- accept_company_invite.
create or replace function public.respond_showcase_creator(p_showcase_id uuid, p_accept boolean)
returns public.company_showcased_creators
language plpgsql security definer set search_path = public as $$
declare
  v_row public.company_showcased_creators;
  v_company public.companies;
  v_creator_name text;
begin
  select * into v_row from public.company_showcased_creators where id = p_showcase_id for update;
  if v_row is null then
    raise exception 'showcase proposal not found';
  end if;
  if v_row.creator_id <> auth.uid() then
    raise exception 'not your proposal to respond to';
  end if;
  if v_row.status <> 'pending' then
    raise exception 'this proposal has already been responded to';
  end if;

  update public.company_showcased_creators
  set status = case when p_accept then 'accepted' else 'declined' end, responded_at = now()
  where id = p_showcase_id
  returning * into v_row;

  select * into v_company from public.companies where id = v_row.company_id;
  select display_name into v_creator_name from public.profiles where id = auth.uid();

  insert into public.audit_log (actor_id, action, target_table, target_id, after)
  values (auth.uid(), 'company_showcase.respond', 'company_showcased_creators', p_showcase_id, to_jsonb(v_row));

  insert into public.notifications (user_id, type, payload)
  select cm.user_id, 'company_showcase.responded',
    jsonb_build_object('company_id', v_row.company_id, 'showcase_id', v_row.id,
      'message', v_creator_name || (case when p_accept then ' accepted' else ' declined' end) || ' being featured on ' || v_company.name || '''s page.')
  from public.company_members cm
  where cm.company_id = v_row.company_id and cm.role = 'owner' and cm.status = 'active';

  return v_row;
end $$;

-- Withdrawing/retracting a showcase (either side) needs no RPC — both RLS policies in
-- company-showcase.sql already cover it directly: the creator can update their own row to
-- 'declined' at any time, and an active company member can do the same via
-- "company member retracts a showcase" (which can only ever move status to 'declined', never
-- 'accepted' — see that policy's own comment for why).
