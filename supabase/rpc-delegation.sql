-- CreatorConnect — manager delegation lifecycle: invite by email, accept, revoke.
-- Run after rpc-delivery.sql. See ../docs/ARCHITECTURE.md Section 3, ../docs/PRODUCT.md Flow 3.
--
-- manager_creator_links' RLS (delegation.sql) already lets a creator insert/update/delete their own
-- links directly — but a creator can't look up a manager's profiles.id from their email via a plain
-- client query (email lives on auth.users, not exposed to the client, and profiles has no email
-- column by design — see schema.sql). invite_manager_by_email() is a security definer function
-- specifically to bridge that one gap: it queries auth.users (which only a security definer function
-- can do) to resolve email -> id, then does the same insert a creator could already do directly.
-- This does NOT bypass "only the creator can revoke" or any other delegation rule — it's a lookup
-- convenience, not a new authorization path.

create or replace function public.invite_manager_by_email(p_manager_email text)
returns public.manager_creator_links
language plpgsql security definer set search_path = public as $$
declare
  v_manager_id uuid;
  v_manager_role text;
  v_link public.manager_creator_links;
begin
  select id into v_manager_id from auth.users where email = lower(trim(p_manager_email));
  if v_manager_id is null then
    raise exception 'no account found for %', p_manager_email;
  end if;

  select role into v_manager_role from public.profiles where id = v_manager_id;
  if v_manager_role <> 'manager' then
    raise exception '% is not registered as a manager', p_manager_email;
  end if;

  insert into public.manager_creator_links (manager_id, creator_id, status)
  values (v_manager_id, auth.uid(), 'pending')
  on conflict (manager_id, creator_id) do update set status = 'pending', revoked_at = null
  returning * into v_link;

  insert into public.audit_log (actor_id, action, target_table, target_id, after)
  values (auth.uid(), 'manager_link.invite', 'manager_creator_links', v_link.id, to_jsonb(v_link));

  return v_link;
end $$;

-- Manager accepts a pending invite. Only the invited manager can accept their own invite — this is
-- the one write a manager needs on this table (everything else about the link stays creator-only,
-- per delegation.sql's "creator controls own links" policy).
create or replace function public.accept_manager_link(p_link_id uuid)
returns public.manager_creator_links
language plpgsql security definer set search_path = public as $$
declare
  v_link public.manager_creator_links;
begin
  select * into v_link from public.manager_creator_links where id = p_link_id for update;
  if v_link is null then
    raise exception 'invite not found';
  end if;
  if v_link.manager_id <> auth.uid() then
    raise exception 'not your invite';
  end if;
  if v_link.status <> 'pending' then
    raise exception 'invite is not pending';
  end if;

  update public.manager_creator_links
  set status = 'active', granted_at = now()
  where id = p_link_id
  returning * into v_link;

  insert into public.audit_log (actor_id, action, target_table, target_id, after)
  values (auth.uid(), 'manager_link.accept', 'manager_creator_links', p_link_id, to_jsonb(v_link));

  return v_link;
end $$;
