-- CreatorConnect — admin-only org creation. Run after orgs.sql, rpc-orgs.sql, and schema.sql
-- (needs is_platform_admin()). Powers /admin/orgs's "create an org" form — the founder's own ask:
-- "only admins can see this page [and] create a page to create orgs."
--
-- Mirrors create_org() (rpc-orgs.sql) almost exactly, with two differences: (1) the caller doesn't
-- need to BE the owner — the owner is resolved from an email, same lookup invite_org_member_by_email
-- already uses for auth.users, since profiles has no email column by design; (2) authorization is
-- is_platform_admin(), not "caller's own role matches org_type" (an admin's own role is irrelevant
-- here — they're creating an org FOR someone else).
create or replace function public.create_org_as_admin(
  p_name text,
  p_handle text,
  p_org_type text,
  p_owner_email text,
  p_avatar_url text default null,
  p_bio text default null
)
returns public.orgs
language plpgsql security definer set search_path = public as $$
declare
  v_owner_id uuid;
  v_owner_role text;
  v_already_member boolean;
  v_org public.orgs;
begin
  if not public.is_platform_admin() then
    raise exception 'not authorized — admin only';
  end if;
  if p_org_type not in ('advertiser', 'manager') then
    raise exception 'invalid org_type: %', p_org_type;
  end if;
  if p_name is null or trim(p_name) = '' then
    raise exception 'name is required';
  end if;
  if p_handle is null or trim(p_handle) = '' then
    raise exception 'handle is required';
  end if;

  select id into v_owner_id from auth.users where email = lower(trim(p_owner_email));
  if v_owner_id is null then
    raise exception 'no account found for %', p_owner_email;
  end if;

  select role into v_owner_role from public.profiles where id = v_owner_id;
  if v_owner_role is distinct from p_org_type then
    raise exception '% is registered as % — org_type must match the owner''s role', p_owner_email, coalesce(v_owner_role, 'unknown');
  end if;

  select exists (
    select 1 from public.org_members where user_id = v_owner_id and status = 'active'
  ) into v_already_member;
  if v_already_member then
    raise exception '% already belongs to an active org', p_owner_email;
  end if;

  insert into public.orgs (name, handle, org_type, avatar_url, bio, created_by)
  values (trim(p_name), lower(trim(p_handle)), p_org_type, p_avatar_url, p_bio, v_owner_id)
  returning * into v_org;

  insert into public.org_members (org_id, user_id, role, status, joined_at)
  values (v_org.id, v_owner_id, 'owner', 'active', now());

  insert into public.audit_log (actor_id, action, target_table, target_id, after)
  values (auth.uid(), 'org.admin_create', 'orgs', v_org.id,
    jsonb_build_object('org', to_jsonb(v_org), 'owner_email', p_owner_email));

  insert into public.notifications (user_id, type, payload)
  values (v_owner_id, 'org.admin_created',
    jsonb_build_object('org_id', v_org.id, 'message', 'An admin created ' || v_org.name || ' with you as owner.'));

  return v_org;
exception
  when unique_violation then
    raise exception 'that org handle is already taken';
end $$;
