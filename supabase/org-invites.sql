-- CreatorConnect — token-based org invites: create a link that lets someone WITHOUT an account yet
-- join an org at signup. Run after orgs.sql (needs orgs, org_members, is_active_org_owner).
--
-- Why a token table instead of extending invite_org_member_by_email(): that RPC requires the
-- invitee to already have a matching-role account (it resolves an email to an existing auth.users
-- row) — it can't be used for "create a new account under my org," which is the founder's actual
-- ask (OrgBoss/AdvertBoss inviting people who don't have an account yet). It stays defined, just
-- superseded in the UI (see rpc-orgs.sql).

create table if not exists public.org_invite_tokens (
  id            uuid        primary key default gen_random_uuid(),
  org_id        uuid        not null references public.orgs(id) on delete cascade,
  token         text        not null,
  role          text        not null default 'member' check (role in ('owner', 'member')),
  target_email  text,
  created_by    uuid        not null references public.profiles(id),
  max_uses      int         not null default 1,
  use_count     int         not null default 0,
  expires_at    timestamptz not null default (now() + interval '14 days'),
  revoked_at    timestamptz,
  created_at    timestamptz not null default now()
);

create unique index if not exists org_invite_tokens_token_unique_idx on public.org_invite_tokens (token);
create index if not exists org_invite_tokens_org_idx on public.org_invite_tokens (org_id);

alter table public.org_invite_tokens enable row level security;

-- Owner-only read — the roster/settings page lists an org's own invite links. No policy lets a
-- non-owner (or anon) select this table at all: the raw `token` column is a bearer secret, and
-- get_org_invite_info() (rpc-org-invites.sql) is the only sanctioned way to resolve a token to
-- display info, returning a narrow projection rather than the row itself.
drop policy if exists "owner reads own org invite tokens" on public.org_invite_tokens;
create policy "owner reads own org invite tokens" on public.org_invite_tokens
  for select
  using (public.is_active_org_owner(org_id));

-- No insert/update/delete policy at all — every write goes through create_org_invite_token() /
-- revoke_org_invite_token() / accept_org_invite_token() (all security definer, rpc-org-invites.sql).
-- Unlike org_members' RLS, none of these policies query org_invite_tokens itself, so there's no
-- recursion risk here even without SECURITY DEFINER on is_active_org_owner — it's already
-- SECURITY DEFINER anyway (orgs.sql), for org_members' own unrelated recursion reason.
