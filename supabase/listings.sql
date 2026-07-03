-- CreatorConnect — creator_listings. Run after schema.sql.
-- See ../docs/ARCHITECTURE.md Section 2 for the pricing_mechanism design rationale: mechanism-specific
-- fields live as nullable columns on this one table (not jsonb, not per-mechanism child tables) —
-- exactly one mechanism's columns are populated per row, enforced by the check constraint below.
--
-- floor_price_cents does double duty: for mechanism A it's the asking price, for mechanism D it's the
-- floor a reservation must meet or exceed. Not a bug — see ARCHITECTURE.md's naming note.

create table if not exists public.creator_listings (
  id                    uuid        primary key default gen_random_uuid(),
  creator_id            uuid        not null references public.profiles(id),
  created_by            uuid        not null references public.profiles(id), -- creator or delegated manager; audit only, not authorization
  platform              text        not null check (platform in ('YouTube', 'Instagram', 'TikTok')),
  content_type          text        not null,
  availability_window   text        not null, -- freeform for MVP, e.g. "Week of Aug 10-17, 2026"
  description           text        not null default '',
  constraints_text       text,
  cancellation_terms     text, -- creator-set, copied into deals.cancellation_terms at confirmation time (rpc-mechanism-d.sql / rpc-mechanism-ac.sql); null falls back to a platform default there

  pricing_mechanism     text        not null check (pricing_mechanism in ('A', 'C', 'D')),

  -- mechanism A: asking price. mechanism D: floor price. null for C.
  floor_price_cents     int,
  currency              text        not null default 'usd',

  -- mechanism D only
  reservation_deadline  timestamptz,

  -- mechanism C only
  exclusivity_window    interval,
  rate_card_low_cents   int,
  rate_card_high_cents  int,

  performance_stats      jsonb       not null default '{}'::jsonb, -- manual entry, MVP
  performance_stats_updated_at timestamptz, -- null until creator first enters stats; signals staleness vs. not-yet-entered
  audience_demographics  jsonb       not null default '{}'::jsonb,

  status  text  not null default 'draft'
    check (status in ('draft', 'open', 'pending', 'reserved', 'confirmed', 'deal', 'expired', 'cancelled')),

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint mechanism_fields_match check (
    (pricing_mechanism = 'A') or
    (pricing_mechanism = 'C' and exclusivity_window is not null) or
    (pricing_mechanism = 'D' and reservation_deadline is not null and floor_price_cents is not null)
  )
);

alter table public.creator_listings add column if not exists performance_stats_updated_at timestamptz;
alter table public.creator_listings add column if not exists cancellation_terms text;

alter table public.creator_listings enable row level security;

drop policy if exists "browse open listings" on public.creator_listings;
create policy "browse open listings" on public.creator_listings
  for select
  using (status <> 'draft' or public.is_authorized_for_creator(creator_id));

drop policy if exists "owner or manager can insert draft" on public.creator_listings;
create policy "owner or manager can insert draft" on public.creator_listings
  for insert
  with check (public.is_authorized_for_creator(creator_id) and status in ('draft', 'open'));

drop policy if exists "owner or manager can edit while editable" on public.creator_listings;
create policy "owner or manager can edit while editable" on public.creator_listings
  for update
  using (public.is_authorized_for_creator(creator_id) and status in ('draft', 'open'))
  with check (public.is_authorized_for_creator(creator_id));

drop policy if exists "owner or manager can delete draft" on public.creator_listings;
create policy "owner or manager can delete draft" on public.creator_listings
  for delete
  using (public.is_authorized_for_creator(creator_id) and status = 'draft');

drop trigger if exists creator_listings_touch on public.creator_listings;
create trigger creator_listings_touch
  before update on public.creator_listings
  for each row execute function public.touch_updated_at();

create index if not exists creator_listings_status_idx on public.creator_listings (status) where status = 'open';
create index if not exists creator_listings_creator_idx on public.creator_listings (creator_id);
