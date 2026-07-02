-- CreatorConnect — deals (the mechanism-agnostic convergence point) + escrow_transactions.
-- Run after negotiations.sql. See ../docs/ARCHITECTURE.md Section 2/4.
--
-- Whatever produced the agreement — D's confirm_deal_as, A's accept_offer_as, or C's
-- convert_exclusivity_as — writes into this same table shape. Exactly one of reservation_id /
-- offer_id / exclusivity_grant_id is set, enforced by the check constraint: the deal always has
-- exactly one traceable origin, regardless of mechanism.
--
-- escrow_transactions is a shadow ledger of Stripe state — all writes to it happen from the Stripe
-- webhook handler using the service role key (once Stripe is wired up), never from client-side RLS
-- writes. Escrow state must mirror Stripe truth, not something a client can assert. It's declared
-- now so the schema is complete; it stays empty until Stripe Connect setup (roadmap Phase 0 items
-- 0.4/0.5) is done.

create table if not exists public.deals (
  id                      uuid        primary key default gen_random_uuid(),

  reservation_id          uuid        references public.reservations(id),
  offer_id                uuid        references public.listing_offers(id),
  exclusivity_grant_id    uuid        references public.listing_exclusivity_grants(id),

  listing_id              uuid        not null references public.creator_listings(id),
  creator_id              uuid        not null references public.profiles(id),
  advertiser_id           uuid        not null references public.profiles(id),
  manager_id              uuid        references public.profiles(id),

  final_price_cents       int         not null,
  confirmed_at            timestamptz not null default now(),
  deliverable_spec        jsonb       not null default '{}'::jsonb,
  delivery_due_at         timestamptz,
  disclosure_terms        text        not null default '',
  cancellation_terms      text        not null default '',
  contract_pdf_path       text,

  status  text  not null default 'active'
    check (status in ('active', 'delivered', 'disputed', 'completed', 'cancelled')),

  delivery_confirmed_at   timestamptz,
  auto_release_at         timestamptz,

  created_at              timestamptz not null default now(),

  constraint one_origin_only check (
    (case when reservation_id is not null then 1 else 0 end
     + case when offer_id is not null then 1 else 0 end
     + case when exclusivity_grant_id is not null then 1 else 0 end) = 1
  )
);

alter table public.deals enable row level security;

drop policy if exists "parties see own deal" on public.deals;
create policy "parties see own deal" on public.deals
  for select
  using (
    creator_id = auth.uid()
    or advertiser_id = auth.uid()
    or manager_id = auth.uid()
    or public.is_authorized_for_creator(creator_id)
    or public.is_platform_admin()
  );

create index if not exists deals_creator_idx on public.deals (creator_id);
create index if not exists deals_advertiser_idx on public.deals (advertiser_id);
create index if not exists deals_auto_release_idx on public.deals (auto_release_at) where status = 'active';

create table if not exists public.escrow_transactions (
  id                  uuid        primary key default gen_random_uuid(),
  deal_id             uuid        not null references public.deals(id),
  kind                text        not null check (kind in ('deposit', 'booking_balance', 'payout_creator', 'payout_manager_commission', 'refund')),
  amount_cents        int         not null,
  stripe_object_type  text        check (stripe_object_type in ('payment_intent', 'transfer', 'refund')),
  stripe_object_id    text,
  status              text        not null default 'pending' check (status in ('pending', 'succeeded', 'failed', 'reversed')),
  created_at          timestamptz not null default now()
);

alter table public.escrow_transactions enable row level security;

drop policy if exists "parties read own escrow state" on public.escrow_transactions;
create policy "parties read own escrow state" on public.escrow_transactions
  for select
  using (exists (
    select 1 from public.deals d
    where d.id = deal_id
      and (d.creator_id = auth.uid() or d.advertiser_id = auth.uid() or d.manager_id = auth.uid())
  ) or public.is_platform_admin());
-- Deliberately NO insert/update/delete policy for the authenticated role — writes only ever happen
-- via the service role from the Stripe webhook handler, which bypasses RLS entirely.
