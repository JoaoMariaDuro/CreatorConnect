-- CreatorConnect — manager/creator delegation (POA), audit log, and notifications.
-- Run after deals.sql. See ../docs/ARCHITECTURE.md Section 3.
--
-- No impersonation tokens, no session-switching: a manager always authenticates as themselves
-- (auth.uid() = manager's own id). Delegated authority is expressed as data in the two tables below,
-- enforced by RLS policies and — for actual mutating actions — security definer RPC functions (a
-- later file) that check delegation at write time and log to audit_log in the same transaction.
--
-- This file REPLACES schema.sql's forward-declared is_authorized_for_creator() with the real body
-- now that manager_creator_links exists. Every earlier RLS policy that calls this function picks up
-- the new behavior automatically — nothing else needs to change.

create table if not exists public.manager_creator_links (
  id                          uuid        primary key default gen_random_uuid(),
  manager_id                  uuid        not null references public.profiles(id),
  creator_id                  uuid        not null references public.profiles(id),
  status                      text        not null default 'pending' check (status in ('pending', 'active', 'revoked')),
  default_auto_accept_floor_cents int,
  commission_bps              int         not null default 500, -- 5%, per PRODUCT.md
  granted_at                  timestamptz,
  revoked_at                  timestamptz,
  created_at                  timestamptz not null default now(),
  unique (manager_id, creator_id)
);

alter table public.manager_creator_links enable row level security;

-- Only the creator can insert/update/delete (i.e. grant, adjust, or revoke) — "only the creator can
-- revoke, never the reverse" per PRODUCT.md's Flow 3. A manager can accept a pending invite via a
-- narrow RPC (later file), not a direct table write.
drop policy if exists "creator controls own links" on public.manager_creator_links;
create policy "creator controls own links" on public.manager_creator_links
  for all
  using (creator_id = auth.uid())
  with check (creator_id = auth.uid());

drop policy if exists "manager reads own links" on public.manager_creator_links;
create policy "manager reads own links" on public.manager_creator_links
  for select
  using (manager_id = auth.uid());

create table if not exists public.listing_price_bands (
  id                      uuid        primary key default gen_random_uuid(),
  listing_id              uuid        not null references public.creator_listings(id),
  manager_id              uuid        not null references public.profiles(id),
  auto_accept_floor_cents int         not null,
  created_at              timestamptz not null default now(),
  unique (listing_id, manager_id)
);

alter table public.listing_price_bands enable row level security;

drop policy if exists "creator writes bands on own listings" on public.listing_price_bands;
create policy "creator writes bands on own listings" on public.listing_price_bands
  for all
  using (exists (select 1 from public.creator_listings l where l.id = listing_id and l.creator_id = auth.uid()))
  with check (exists (select 1 from public.creator_listings l where l.id = listing_id and l.creator_id = auth.uid()));

drop policy if exists "manager reads own bands" on public.listing_price_bands;
create policy "manager reads own bands" on public.listing_price_bands
  for select
  using (manager_id = auth.uid());

-- The real is_authorized_for_creator — replaces schema.sql's owner-only forward declaration.
create or replace function public.is_authorized_for_creator(creator_id uuid)
returns boolean language sql stable as $$
  select
    creator_id = auth.uid()
    or exists (
      select 1 from public.manager_creator_links
      where manager_id = auth.uid() and manager_creator_links.creator_id = is_authorized_for_creator.creator_id and status = 'active'
    );
$$;

create table if not exists public.audit_log (
  id            uuid        primary key default gen_random_uuid(),
  actor_id      uuid        not null references public.profiles(id), -- who actually clicked
  acting_as_id  uuid        references public.profiles(id),          -- the creator, if this was a delegated manager action
  action        text        not null,                                -- e.g. 'listing.update', 'reservation.confirm'
  target_table  text        not null,
  target_id     uuid        not null,
  before        jsonb,
  after         jsonb,
  created_at    timestamptz not null default now()
);

alter table public.audit_log enable row level security;

-- Insert-only via RPCs/triggers (never a direct client insert) — no insert policy granted to
-- `authenticated` here at all; only security definer functions (which run as the function owner,
-- bypassing RLS) can write. Read is scoped to the creator whose data was touched, plus the platform.
drop policy if exists "creator reads own audit trail" on public.audit_log;
create policy "creator reads own audit trail" on public.audit_log
  for select
  using (acting_as_id = auth.uid() or actor_id = auth.uid());

create table if not exists public.notifications (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references public.profiles(id),
  type        text        not null,
  payload     jsonb       not null default '{}'::jsonb,
  read_at     timestamptz,
  created_at  timestamptz not null default now()
);

alter table public.notifications enable row level security;

drop policy if exists "own notifications" on public.notifications;
create policy "own notifications" on public.notifications
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create index if not exists notifications_user_unread_idx on public.notifications (user_id) where read_at is null;
