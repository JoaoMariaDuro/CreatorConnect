-- CreatorConnect — the three mechanism-specific negotiation tables, plus D's tiebreak tables.
-- Run after listings.sql. See ../docs/ARCHITECTURE.md Section 2.
--
-- reservations is mechanism D only. listing_offers is mechanism A only. listing_exclusivity_grants
-- is mechanism C only — each listing only ever produces rows in ONE of these three, per its
-- pricing_mechanism, enforced at the RPC layer (not a DB constraint, since checking "does this
-- listing's mechanism match this table" requires a join, which check constraints can't do).
--
-- Direct client writes are NOT granted on any status/amount column below — all state transitions
-- happen through security definer RPC functions (a later file), so a client can never craft an
-- update that jumps straight to 'accepted'/'confirmed'. The insert policies here only allow the
-- narrow, safe initial-state inserts described in ARCHITECTURE.md Section 8 risk #1.

-- ---------- Mechanism D: reservations ----------

create table if not exists public.reservations (
  id                      uuid        primary key default gen_random_uuid(),
  listing_id              uuid        not null references public.creator_listings(id),
  advertiser_id           uuid        not null references public.profiles(id),
  deposit_amount_cents    int,
  deposit_payment_intent_id text,
  status  text  not null default 'pending_deposit'
    check (status in ('pending_deposit', 'held', 'tiebreak_pending', 'confirmed', 'expired', 'lost_tiebreak', 'cancelled')),
  confirmation_deadline   timestamptz,
  created_at              timestamptz not null default now()
);

alter table public.reservations enable row level security;

drop policy if exists "advertiser sees own reservations" on public.reservations;
create policy "advertiser sees own reservations" on public.reservations
  for select
  using (
    advertiser_id = auth.uid()
    or exists (select 1 from public.creator_listings l where l.id = listing_id and public.is_authorized_for_creator(l.creator_id))
  );

create index if not exists reservations_listing_idx on public.reservations (listing_id);
create index if not exists reservations_deadline_idx on public.reservations (confirmation_deadline) where status = 'held';

-- ---------- Mechanism A: listing_offers ----------

create table if not exists public.listing_offers (
  id              uuid        primary key default gen_random_uuid(),
  listing_id      uuid        not null references public.creator_listings(id),
  advertiser_id   uuid        not null references public.profiles(id),
  offer_amount_cents int      not null,
  proposed_by     text        not null check (proposed_by in ('advertiser', 'creator')),
  status          text        not null default 'open' check (status in ('open', 'accepted', 'rejected', 'withdrawn', 'expired')),
  note            text,
  parent_offer_id uuid        references public.listing_offers(id),
  created_at      timestamptz not null default now()
);

alter table public.listing_offers enable row level security;

drop policy if exists "parties see own offer thread" on public.listing_offers;
create policy "parties see own offer thread" on public.listing_offers
  for select
  using (
    advertiser_id = auth.uid()
    or exists (select 1 from public.creator_listings l where l.id = listing_id and public.is_authorized_for_creator(l.creator_id))
  );

create index if not exists listing_offers_listing_idx on public.listing_offers (listing_id);

-- ---------- Mechanism C: listing_exclusivity_grants ----------

create table if not exists public.listing_exclusivity_grants (
  id                  uuid        primary key default gen_random_uuid(),
  listing_id          uuid        not null references public.creator_listings(id),
  advertiser_id       uuid        not null references public.profiles(id),
  window_starts_at    timestamptz not null default now(),
  window_ends_at      timestamptz not null,
  status              text        not null default 'active' check (status in ('active', 'converted', 'expired', 'revoked')),
  negotiation         jsonb, -- { proposedPrice, proposedTerms, status: 'proposed'|'accepted', from: 'advertiser'|'creator' }
  created_at          timestamptz not null default now()
);

alter table public.listing_exclusivity_grants enable row level security;

drop policy if exists "parties see own exclusivity grant" on public.listing_exclusivity_grants;
create policy "parties see own exclusivity grant" on public.listing_exclusivity_grants
  for select
  using (
    advertiser_id = auth.uid()
    or exists (select 1 from public.creator_listings l where l.id = listing_id and public.is_authorized_for_creator(l.creator_id))
  );

create index if not exists exclusivity_grants_listing_idx on public.listing_exclusivity_grants (listing_id);
create index if not exists exclusivity_grants_expiry_idx on public.listing_exclusivity_grants (window_ends_at) where status = 'active';

-- ---------- Mechanism D: closed-set sealed-bid tiebreak (Phase 1.5 — table exists now, RPCs land later) ----------
-- Deferred per ../docs/ROADMAP.md's explicit judgment call: contention is expected to be rare, and the
-- tiebreaker needs real usage data before it's worth building the resolution logic. The tables exist
-- now so a later migration doesn't have to touch live reservations data; place_reservation's RPC
-- (next file) currently just rejects a second concurrent reservation outright rather than opening a
-- tiebreak — that's what makes this safe to leave unpopulated for now.

create table if not exists public.deal_tiebreaks (
  id                    uuid        primary key default gen_random_uuid(),
  listing_id            uuid        not null references public.creator_listings(id),
  opened_at             timestamptz not null default now(),
  closes_at             timestamptz not null,
  status                text        not null default 'open' check (status in ('open', 'resolved')),
  winning_reservation_id uuid       references public.reservations(id)
);

alter table public.deal_tiebreaks enable row level security;

drop policy if exists "parties see own listing's tiebreak" on public.deal_tiebreaks;
create policy "parties see own listing's tiebreak" on public.deal_tiebreaks
  for select
  using (exists (select 1 from public.creator_listings l where l.id = listing_id and public.is_authorized_for_creator(l.creator_id)));

create table if not exists public.tiebreak_bids (
  id              uuid        primary key default gen_random_uuid(),
  tiebreak_id     uuid        not null references public.deal_tiebreaks(id),
  reservation_id  uuid        not null references public.reservations(id),
  bid_amount_cents int        not null,
  submitted_at    timestamptz not null default now()
);

alter table public.tiebreak_bids enable row level security;

-- Sealed means sealed: an advertiser can see that THEY bid, never what others bid. Only the creator
-- (post-resolution, via a later RPC) and the platform see all bids — this is the one table where the
-- read-restriction matters as much as the write-restriction (ARCHITECTURE.md Section 2).
drop policy if exists "advertiser sees own bid only" on public.tiebreak_bids;
create policy "advertiser sees own bid only" on public.tiebreak_bids
  for select
  using (exists (select 1 from public.reservations r where r.id = reservation_id and r.advertiser_id = auth.uid()));
