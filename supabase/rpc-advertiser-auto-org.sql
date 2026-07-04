-- CreatorConnect — auto-org-creation for advertisers. Run after rpc-orgs.sql.
--
-- Founder's requirement: unlike managers (who can be a "free agent" with no org, fully valid), every
-- advertiser always has an org context — a solo advertiser automatically becomes the sole owner of
-- their own org at signup, invisibly. This file is the shared logic both entry points below call:
-- schema.sql's handle_new_user() trigger (the normal magic-link signup path) and
-- ensure_advertiser_org_self() (the passkey-signup-with-no-metadata fallback, called from
-- CompleteProfile.svelte after it inserts the profile row directly).

-- Takes p_user_id/p_display_name as explicit parameters rather than reading auth.uid() itself,
-- because the trigger context (handle_new_user, on auth.users insert) has NO auth.uid() at all —
-- there's no authenticated request yet, just a row being inserted. This is why it's a separate
-- function from create_org() (rpc-orgs.sql), which reads auth.uid() directly and is only ever called
-- by an already-authenticated client.
create or replace function public.ensure_advertiser_org(p_user_id uuid, p_display_name text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_role text;
  v_already_member boolean;
  v_base_handle text;
  v_handle text;
  v_org_id uuid;
  v_suffix int := 0;
begin
  -- No-op for non-advertisers — lets both call sites below call this unconditionally rather than
  -- duplicating the role check at each one.
  select role into v_role from public.profiles where id = p_user_id;
  if v_role is distinct from 'advertiser' then
    return;
  end if;

  -- No-op if this user already has ANY org_members row, pending or active — not just active. This
  -- is what makes handle_new_user()'s invite-token skip interlock correct: without checking
  -- "pending" too, calling this twice (once from the trigger, once defensively from
  -- CompleteProfile.svelte, or a retry after a network blip) could double-create orgs.
  select exists (select 1 from public.org_members where user_id = p_user_id) into v_already_member;
  if v_already_member then
    return;
  end if;

  -- Slugify display_name into a handle base; fall back to a generic base if the name slugifies to
  -- nothing (e.g. all emoji/punctuation), so we never attempt an empty handle.
  v_base_handle := lower(trim(both '-' from regexp_replace(coalesce(p_display_name, ''), '[^a-zA-Z0-9]+', '-', 'g')));
  if v_base_handle = '' or v_base_handle is null then
    v_base_handle := 'advertiser';
  end if;

  -- Retry-with-suffix on handle collision — same unique_violation-catching shape create_org()
  -- already uses for a human-driven retry, just looped since there's no human here to pick a new
  -- name. Capped at 50 attempts as a sanity bound, not an expected real case.
  loop
    v_handle := v_base_handle || case when v_suffix = 0 then '' else '-' || v_suffix::text end;
    begin
      insert into public.orgs (name, handle, org_type, created_by)
      values (
        coalesce(nullif(trim(p_display_name), ''), 'Advertiser') || '''s org',
        v_handle,
        'advertiser',
        p_user_id
      )
      returning id into v_org_id;
      exit;
    exception
      when unique_violation then
        v_suffix := v_suffix + 1;
        if v_suffix > 50 then
          raise exception 'could not generate a unique org handle for %', p_display_name;
        end if;
    end;
  end loop;

  insert into public.org_members (org_id, user_id, role, status, joined_at)
  values (v_org_id, p_user_id, 'owner', 'active', now());

  insert into public.audit_log (actor_id, action, target_table, target_id, after)
  values (p_user_id, 'org.auto_create', 'orgs', v_org_id,
    jsonb_build_object('org_id', v_org_id, 'handle', v_handle, 'reason', 'advertiser_signup'));
end $$;

-- Client-callable wrapper for CompleteProfile.svelte's passkey-signup fallback path — that path runs
-- as an authenticated client call (unlike the trigger), so it can read auth.uid() itself. Deliberately
-- a separate thin wrapper rather than exposing ensure_advertiser_org(uuid, text) directly to
-- PostgREST: a client-callable function taking an arbitrary p_user_id would let any authenticated
-- caller attempt to act "for" someone else's id — harmless here since the function no-ops for
-- non-advertisers and non-empty-membership users, but it's needless attack surface and breaks the
-- "RPC parameters never let the caller act as someone else" convention every other RPC in this
-- codebase follows (e.g. accept_org_invite always reads auth.uid(), never takes a p_user_id).
create or replace function public.ensure_advertiser_org_self()
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.ensure_advertiser_org(
    auth.uid(),
    (select display_name from public.profiles where id = auth.uid())
  );
end $$;
