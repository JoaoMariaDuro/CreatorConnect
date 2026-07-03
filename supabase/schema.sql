-- CreatorConnect — foundational schema: profiles + the auth trigger that populates them.
-- Run this FIRST, once, in the Supabase SQL editor. Everything else in this folder depends on it.
-- See ../docs/ARCHITECTURE.md Section 2/3 for the full design this implements.
--
-- One row per auth.users row. `role` is the user's primary role (creator/advertiser/manager) —
-- a manager's extra reach over specific creators comes from delegation.sql's manager_creator_links,
-- not from a different role tier here.
-- RLS: anyone can read the public-safe subset (via the public_profiles view below, used for browse);
-- a user can only write their own row.

create extension if not exists "pgcrypto"; -- gen_random_uuid()

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create table if not exists public.profiles (
  id                      uuid        primary key references auth.users on delete cascade,
  role                    text        not null check (role in ('creator', 'advertiser', 'manager')),
  display_name            text        not null,
  handle                  text,
  avatar_url              text,
  platform_handles        jsonb       not null default '{}'::jsonb,
  bio                     text,
  niche_tags              text[]      not null default '{}',
  follower_count          int,
  completed_deals_count   int         not null default 0,
  stripe_connect_account_id text,
  stripe_customer_id      text,
  is_platform_admin       boolean     not null default false,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

alter table public.profiles add column if not exists completed_deals_count int not null default 0;
alter table public.profiles add column if not exists is_platform_admin boolean not null default false;

alter table public.profiles enable row level security;

drop policy if exists "read own profile" on public.profiles;
create policy "read own profile" on public.profiles
  for select
  using (auth.uid() = id);

-- A user can edit their own row's normal profile fields (display_name, handle, bio, niche_tags,
-- follower_count, platform_handles, avatar_url, etc.) via a plain client-side `.update()` call, but
-- can never change `role` or `is_platform_admin` through this path — for anyone, including admins.
-- Without this, any signed-in user could call
-- `supabase.from('profiles').update({ is_platform_admin: true }).eq('id', user.id)` directly and
-- grant themselves founder/admin access, or silently swap `role` and break the role-based
-- `/create`/`/login` redirects that assume it's stable once set at signup. `role` stays changeable
-- only via `set_own_test_role_as_admin` (rpc-admin.sql, admin-only); `is_platform_admin` stays
-- grantable only via a one-time manual SQL statement (see docs/ROLE_ACCESS_AND_UX_SPEC.md) — never
-- through an in-app path, not even for admins themselves.
--
-- The `with check` subquery pattern below reads each column's value as of the start of the
-- statement (the pre-update row), which is what makes this work: for a plain profile edit, the new
-- row's `role`/`is_platform_admin` match what's already stored, so the check passes; for an attempted
-- `.update({ role: ... })` or `.update({ is_platform_admin: ... })`, the new row's value now differs
-- from the freshly-selected stored value, so the check fails and Postgres rejects the whole update.
drop policy if exists "update own profile" on public.profiles;
create policy "update own profile" on public.profiles
  for update
  using (auth.uid() = id)
  with check (
    auth.uid() = id
    and role = (select p.role from public.profiles p where p.id = auth.uid())
    and is_platform_admin = (select p.is_platform_admin from public.profiles p where p.id = auth.uid())
  );

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- Public-safe subset for browse/discovery — no stripe ids (deliberately narrow; widen later if a
-- real need shows up, per ARCHITECTURE.md's "everyone can select a public-safe subset" note).
-- `platform_handles` added because deal/[id] and the admin dispute detail page both need it to show
-- a creator's YouTube/IG/TikTok handles alongside their CreatorConnect handle. `bio` added because
-- /u/[handle] (advertiser/manager individual profile pages) is bio-centric in a way the creator
-- media-kit isn't — both are the "widen later if a real need shows up" case the original comment
-- anticipated, not scope creep. Still no stripe ids or is_platform_admin.
-- `bio` is appended LAST, not inserted alongside the other columns above it: Postgres's
-- `create or replace view` only allows appending new columns to the end of the list — inserting one
-- in the middle throws (this was a real bug in an earlier version of this file, caught by testing
-- live against the actual database rather than assuming the edit worked).
create or replace view public.public_profiles as
  select id, role, display_name, handle, avatar_url, niche_tags, follower_count, completed_deals_count, platform_handles, bio
  from public.profiles;

-- Auto-create a profiles row when someone signs up. Role and display_name come from signup metadata
-- (set by the client at signup: supabase.auth.signUp({ options: { data: { role, display_name } } })).
-- If role is missing/invalid the insert fails loudly rather than silently defaulting — signup UI must
-- always pass a role.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, role, display_name)
  values (
    new.id,
    new.raw_user_meta_data ->> 'role',
    coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1))
  );
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Shared helper, reused by every creator-scoped table's RLS policy from here on:
-- "is auth.uid() either this creator themselves, or a manager with an active delegation link to them?"
-- Defined here (ahead of manager_creator_links existing) as a forward declaration; delegation.sql
-- replaces it with the real body once that table exists. Until delegation.sql runs, this falls back
-- to owner-only access, which is the safe default.
create or replace function public.is_authorized_for_creator(creator_id uuid)
returns boolean language sql stable as $$
  select auth.uid() = creator_id;
$$;

-- Founder/admin check, mirroring is_authorized_for_creator() above. Gates new RLS select policies
-- plus the `_as_admin`-suffixed security definer RPCs — see rpc-admin.sql. No new role tier, no
-- impersonation: the founder authenticates as themselves, and this just reads a boolean off their
-- own profiles row.
create or replace function public.is_platform_admin()
returns boolean language sql stable as $$
  select coalesce((select is_platform_admin from public.profiles where id = auth.uid()), false);
$$;
