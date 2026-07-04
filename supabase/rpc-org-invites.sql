-- CreatorConnect — token-based org invite lifecycle. Run after org-invites.sql.
-- See rpc-orgs.sql's invite_org_member_by_email() header for why this flow exists alongside it:
-- that RPC requires the invitee to already have a matching-role account; this one lets an OrgBoss/
-- AdvertBoss invite someone who doesn't have an account yet, riding the normal signInWithOtp +
-- handle_new_user() trigger path (the app has no service-role access anywhere, so there is no admin
-- API shortcut available here).

-- Owner creates a link. Mirrors invite_org_member_by_email()'s owner-check exactly. p_role defaults
-- to 'member' — inviting a new owner is rare enough not to warrant a different default, but is
-- still supported for the "hand off ownership" case.
create or replace function public.create_org_invite_token(
  p_org_id uuid,
  p_role text default 'member',
  p_target_email text default null,
  p_expires_in_days int default 14
)
returns public.org_invite_tokens
language plpgsql security definer set search_path = public as $$
declare
  v_token text;
  v_row public.org_invite_tokens;
begin
  if not public.is_active_org_owner(p_org_id) then
    raise exception 'not authorized — only an active owner can create invite links';
  end if;
  if p_role not in ('owner', 'member') then
    raise exception 'invalid role: %', p_role;
  end if;
  if p_expires_in_days is null or p_expires_in_days <= 0 then
    raise exception 'expires_in_days must be positive';
  end if;

  -- 24 random bytes -> 32-char base64url string (192 bits / 6 = 32 exactly, no padding to strip).
  -- Opaque and unguessable — this is a bearer secret, same trust model as a password-reset link.
  v_token := encode(gen_random_bytes(24), 'base64');
  v_token := replace(replace(v_token, '+', '-'), '/', '_');

  insert into public.org_invite_tokens (org_id, token, role, target_email, created_by, expires_at)
  values (
    p_org_id, v_token, p_role, nullif(trim(coalesce(p_target_email, '')), ''), auth.uid(),
    now() + make_interval(days => p_expires_in_days)
  )
  returning * into v_row;

  insert into public.audit_log (actor_id, action, target_table, target_id, after)
  values (auth.uid(), 'org_invite_token.create', 'org_invite_tokens', v_row.id,
    jsonb_build_object('org_id', p_org_id, 'role', p_role, 'target_email', v_row.target_email));

  return v_row;
end $$;

-- Anonymous-safe lookup — the ONE function in this file that must work pre-login, since
-- /invite/[token] renders before the visitor has an account. Granted to anon explicitly below.
-- Returns only what the invite landing page needs to render (org identity + required role +
-- validity), never the token row's id/created_by/use_count — a view would still let anon bulk-select
-- the raw `token` column (the actual enumeration risk), so this has to be a parameterized RPC, same
-- reasoning invite_org_member_by_email() already applies to not exposing auth.users directly.
--
-- Returns a row with valid = false (plus a reason) for expired/used/revoked tokens rather than
-- raising or returning no rows — /invite/[token] uses this to distinguish a real expired-invite page
-- from a true 404 for a token that never existed at all.
create or replace function public.get_org_invite_info(p_token text)
returns table (
  org_id uuid,
  org_name text,
  org_handle text,
  org_type text,
  avatar_url text,
  role text,
  valid boolean,
  reason text
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_invite public.org_invite_tokens;
  v_org public.orgs;
begin
  select * into v_invite from public.org_invite_tokens where token = p_token;
  if v_invite is null then
    return; -- zero rows: caller treats this as a true 404
  end if;

  select * into v_org from public.orgs where id = v_invite.org_id;

  org_id := v_invite.org_id;
  org_name := v_org.name;
  org_handle := v_org.handle;
  org_type := v_org.org_type;
  avatar_url := v_org.avatar_url;
  role := v_invite.role;

  if v_invite.revoked_at is not null then
    valid := false; reason := 'revoked';
  elsif v_invite.expires_at < now() then
    valid := false; reason := 'expired';
  elsif v_invite.use_count >= v_invite.max_uses then
    valid := false; reason := 'used';
  else
    valid := true; reason := null;
  end if;

  return next;
end $$;

grant execute on function public.get_org_invite_info(text) to anon, authenticated;

-- Caller (already authenticated — either a fresh post-signup landing or an already-signed-in user
-- clicking the link) accepts the invite. Handles both cases identically since both reduce to the
-- same postcondition: an authenticated caller whose role matches org_type gets an active org_members
-- row. Blocks if the caller already belongs to a DIFFERENT active org — same "one org at a time"
-- invariant create_org() already enforces — with a clear error, not a silent no-op, since the caller
-- genuinely needs to know their click didn't do what they expected.
create or replace function public.accept_org_invite_token(p_token text)
returns public.org_members
language plpgsql security definer set search_path = public as $$
declare
  v_invite public.org_invite_tokens;
  v_org public.orgs;
  v_caller_role text;
  v_already_elsewhere boolean;
  v_member public.org_members;
begin
  select * into v_invite from public.org_invite_tokens where token = p_token for update;
  if v_invite is null then
    raise exception 'invite not found';
  end if;
  if v_invite.revoked_at is not null then
    raise exception 'this invite has been revoked';
  end if;
  if v_invite.expires_at < now() then
    raise exception 'this invite has expired';
  end if;
  if v_invite.use_count >= v_invite.max_uses then
    raise exception 'this invite has already been used';
  end if;

  select * into v_org from public.orgs where id = v_invite.org_id;
  select role into v_caller_role from public.profiles where id = auth.uid();
  if v_caller_role is null then
    raise exception 'no profile found for caller';
  end if;
  if v_caller_role <> v_org.org_type then
    raise exception 'you are registered as % — this org only accepts % members', v_caller_role, v_org.org_type;
  end if;

  select exists (
    select 1 from public.org_members
    where user_id = auth.uid() and status = 'active' and org_id <> v_invite.org_id
  ) into v_already_elsewhere;
  if v_already_elsewhere then
    raise exception 'you already belong to a different org — leave it before accepting this invite';
  end if;

  insert into public.org_members (org_id, user_id, role, status, invited_at, joined_at)
  values (v_invite.org_id, auth.uid(), v_invite.role, 'active', now(), now())
  on conflict (org_id, user_id) do update
    set status = 'active', joined_at = now(), revoked_at = null
  returning * into v_member;

  update public.org_invite_tokens set use_count = use_count + 1 where id = v_invite.id;

  insert into public.audit_log (actor_id, action, target_table, target_id, after)
  values (auth.uid(), 'org_invite_token.accept', 'org_members', v_member.id, to_jsonb(v_member));

  insert into public.notifications (user_id, type, payload)
  select om.user_id, 'org_member.accepted',
    jsonb_build_object('org_id', v_invite.org_id, 'member_id', v_member.id,
      'message', 'A new member joined ' || v_org.name || ' via invite link.')
  from public.org_members om
  where om.org_id = v_invite.org_id and om.role = 'owner' and om.status = 'active';

  return v_member;
end $$;

-- Owner revokes an unused link. Idempotent — revoking an already-revoked/used/expired link is a
-- harmless no-op rather than an error, since the end state ("this link no longer works") is already
-- true either way.
create or replace function public.revoke_org_invite_token(p_token_id uuid)
returns public.org_invite_tokens
language plpgsql security definer set search_path = public as $$
declare
  v_invite public.org_invite_tokens;
begin
  select * into v_invite from public.org_invite_tokens where id = p_token_id;
  if v_invite is null then
    raise exception 'invite not found';
  end if;
  if not public.is_active_org_owner(v_invite.org_id) then
    raise exception 'not authorized — only an active owner can revoke invite links';
  end if;

  update public.org_invite_tokens
  set revoked_at = coalesce(revoked_at, now())
  where id = p_token_id
  returning * into v_invite;

  return v_invite;
end $$;
