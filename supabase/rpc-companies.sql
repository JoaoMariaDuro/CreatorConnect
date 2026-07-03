-- CreatorConnect — company creation, invite, and accept lifecycle.
-- Run after companies.sql. See supabase/rpc-delegation.sql for the manager-delegation pattern this
-- mirrors for company membership instead of creator delegation.

-- Atomically creates a company AND inserts the caller as its first (active) owner, in one
-- transaction. This is why this is an RPC and not two client-side inserts: companies.sql's RLS
-- deliberately grants no insert policy on companies at all, specifically so a company can never exist
-- with zero owners even transiently — two separate client calls would leave a window where the
-- company exists with no owner if the second call failed (network error, client crash) partway
-- through.
--
-- Only advertisers and managers may create a company (creators are excluded per the founder's
-- decision) — checked against the caller's own profiles.role, which is immutable, so this can't be
-- bypassed by a role-switch after the fact. Also blocks creating a second company while the caller
-- already has an active membership elsewhere — without this, a user could end up owning two
-- companies with no UI path to manage the second, a confusing dead end rather than a real feature.
create or replace function public.create_company(
  p_name text,
  p_handle text,
  p_company_type text,
  p_avatar_url text default null,
  p_bio text default null
)
returns public.companies
language plpgsql security definer set search_path = public as $$
declare
  v_caller_role text;
  v_already_member boolean;
  v_company public.companies;
begin
  select role into v_caller_role from public.profiles where id = auth.uid();
  if v_caller_role is null then
    raise exception 'no profile found for caller';
  end if;
  if v_caller_role not in ('advertiser', 'manager') then
    raise exception 'only advertisers and managers can create a company';
  end if;
  if p_company_type not in ('advertiser', 'manager') then
    raise exception 'invalid company_type: %', p_company_type;
  end if;
  if p_company_type <> v_caller_role then
    raise exception 'company_type (%) must match your own role (%)', p_company_type, v_caller_role;
  end if;
  if p_name is null or trim(p_name) = '' then
    raise exception 'name is required';
  end if;
  if p_handle is null or trim(p_handle) = '' then
    raise exception 'handle is required';
  end if;

  select exists (
    select 1 from public.company_members where user_id = auth.uid() and status = 'active'
  ) into v_already_member;
  if v_already_member then
    raise exception 'you already belong to a company — leave it before creating a new one';
  end if;

  insert into public.companies (name, handle, company_type, avatar_url, bio, created_by)
  values (trim(p_name), lower(trim(p_handle)), p_company_type, p_avatar_url, p_bio, auth.uid())
  returning * into v_company;

  insert into public.company_members (company_id, user_id, role, status, joined_at)
  values (v_company.id, auth.uid(), 'owner', 'active', now());

  insert into public.audit_log (actor_id, action, target_table, target_id, after)
  values (auth.uid(), 'company.create', 'companies', v_company.id, to_jsonb(v_company));

  return v_company;
exception
  when unique_violation then
    raise exception 'that company handle is already taken';
end $$;

-- Invite an advertiser or manager to join an existing company by email. Security definer for the
-- same reason invite_manager_by_email() is: email lives on auth.users, which no client-side policy
-- can read, and profiles has no email column by design. This performs exactly the insert an active
-- owner's own "owner inserts members" RLS policy (companies.sql) would already allow them to do
-- directly, IF they could resolve the email to a user_id themselves — this is a lookup convenience,
-- not a new authorization path.
--
-- Two checks required by the founder's decisions:
-- 1. Caller must be an ACTIVE OWNER of p_company_id — there is no RLS fallback once inside a
--    security-definer function, so this check is the only thing preventing any authenticated user
--    from inserting an invite into a company they have no relationship to.
-- 2. The invitee's profiles.role must match the company's company_type — an advertiser company
--    cannot invite a manager (or a creator), and vice versa, keeping "only advertisers and managers
--    get company affiliation" true and company_type meaningful.
create or replace function public.invite_company_member_by_email(p_company_id uuid, p_email text)
returns public.company_members
language plpgsql security definer set search_path = public as $$
declare
  v_invitee_id uuid;
  v_invitee_role text;
  v_company public.companies;
  v_member public.company_members;
begin
  if not public.is_active_company_owner(p_company_id) then
    raise exception 'not authorized — only an active owner can invite members';
  end if;

  select * into v_company from public.companies where id = p_company_id;
  if v_company is null then
    raise exception 'company not found';
  end if;

  select id into v_invitee_id from auth.users where email = lower(trim(p_email));
  if v_invitee_id is null then
    raise exception 'no account found for %', p_email;
  end if;

  select role into v_invitee_role from public.profiles where id = v_invitee_id;
  if v_invitee_role is null then
    raise exception 'no profile found for %', p_email;
  end if;
  if v_invitee_role <> v_company.company_type then
    raise exception '% is registered as % — this company only accepts % members', p_email, v_invitee_role, v_company.company_type;
  end if;

  if v_invitee_id = auth.uid() then
    raise exception 'you are already a member of this company';
  end if;

  insert into public.company_members (company_id, user_id, role, status, invited_at)
  values (p_company_id, v_invitee_id, 'member', 'pending', now())
  on conflict (company_id, user_id) do update
    set status = 'pending', invited_at = now(), revoked_at = null
  returning * into v_member;

  insert into public.audit_log (actor_id, action, target_table, target_id, after)
  values (auth.uid(), 'company_member.invite', 'company_members', v_member.id, to_jsonb(v_member));

  insert into public.notifications (user_id, type, payload)
  values (v_invitee_id, 'company_member.invited',
    jsonb_build_object('company_id', p_company_id, 'member_id', v_member.id,
      'message', 'You''ve been invited to join ' || v_company.name || ' on CreatorConnect.'));

  return v_member;
end $$;

-- Invitee accepts their own pending invite. Only the invited user can accept their own row — same
-- shape as accept_manager_link(). Chosen as an RPC (not a plain client `.update()`) because it needs
-- to set joined_at atomically with the status flip and write audit_log + notifications in the same
-- transaction. The "owner manages member rows" RLS policy (companies.sql) doesn't permit a
-- non-owner to update their own row at all, so without this RPC an invitee would have no path to
-- accept — unlike revoke, this one is genuinely required, not a style choice.
create or replace function public.accept_company_invite(p_member_id uuid)
returns public.company_members
language plpgsql security definer set search_path = public as $$
declare
  v_member public.company_members;
  v_company public.companies;
begin
  select * into v_member from public.company_members where id = p_member_id for update;
  if v_member is null then
    raise exception 'invite not found';
  end if;
  if v_member.user_id <> auth.uid() then
    raise exception 'not your invite';
  end if;
  if v_member.status <> 'pending' then
    raise exception 'invite is not pending';
  end if;

  update public.company_members
  set status = 'active', joined_at = now()
  where id = p_member_id
  returning * into v_member;

  select * into v_company from public.companies where id = v_member.company_id;

  insert into public.audit_log (actor_id, action, target_table, target_id, after)
  values (auth.uid(), 'company_member.accept', 'company_members', p_member_id, to_jsonb(v_member));

  -- Notify every active owner (there may be more than one) — not just created_by, since ownership
  -- can change over time and "who currently manages this roster" is whoever holds an active owner
  -- row right now.
  insert into public.notifications (user_id, type, payload)
  select cm.user_id, 'company_member.accepted',
    jsonb_build_object('company_id', v_member.company_id, 'member_id', v_member.id,
      'message', 'A new member joined ' || v_company.name || '.')
  from public.company_members cm
  where cm.company_id = v_member.company_id and cm.role = 'owner' and cm.status = 'active';

  return v_member;
end $$;

-- Revoke deliberately has NO RPC — a plain
-- supabase.from('company_members').update({ status: 'revoked', revoked_at: ... }).eq('id', memberId)
-- is already correctly scoped by companies.sql's "owner manages member rows" RLS policy, exactly how
-- manager_creator_links revocation works today (settings/managers/+page.svelte's revoke()). The
-- enforce_company_has_owner trigger protects the one real invariant regardless of which path the
-- update comes from, so an RPC here would be indirection with no behavioral benefit.
