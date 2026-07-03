-- CreatorConnect — advertiser shortlist/watchlist. Run after listings.sql.
--
-- PRODUCT.md Flow 2 explicitly names this: "advertiser can shortlist/watch a listing with no
-- commitment... matches the research-backed prediction that advertisers browse ahead of committing."
-- This was designed but never built — confirmed absent via grep before writing this file. No
-- security-definer RPC needed: shortlisting is a no-commitment bookmark, not a state transition, so
-- a plain RLS-gated insert/delete is correct (same reasoning already used for org_members revocation
-- and feedback inserts elsewhere in this codebase).

create table if not exists public.shortlists (
  id            uuid        primary key default gen_random_uuid(),
  advertiser_id uuid        not null references public.profiles(id),
  listing_id    uuid        not null references public.creator_listings(id) on delete cascade,
  created_at    timestamptz not null default now(),
  unique (advertiser_id, listing_id)
);

alter table public.shortlists enable row level security;

-- Fully self-scoped, both directions — an advertiser's shortlist is private to them (not shown to
-- the creator, not public). Without this, a plain client insert/select with a mismatched
-- advertiser_id would let one advertiser read or tamper with another's shortlist.
drop policy if exists "advertiser manages own shortlist" on public.shortlists;
create policy "advertiser manages own shortlist" on public.shortlists
  for all
  using (advertiser_id = auth.uid())
  with check (advertiser_id = auth.uid());

create index if not exists shortlists_advertiser_idx on public.shortlists (advertiser_id);
