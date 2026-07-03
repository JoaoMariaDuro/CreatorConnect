-- CreatorConnect — agency showcase: lets a manager-type company publicly display which creators it
-- represents on /company/[handle], with DUAL consent. Run after companies.sql and delegation.sql
-- (needs manager_creator_links, audit_log, notifications).
--
-- Founder's explicit answer to the privacy question this raised: "the agency can turn visible those
-- it wants to and that the creator also has to accept." Two-sided, neither party unilaterally
-- publishes the relationship:
-- - The agency (any active member who personally has the real manager_creator_links relationship
--   with that creator — not just any member of the company) proposes.
-- - The creator must separately accept before anything becomes public. A pending proposal is never
--   shown on /company/[handle] — only 'accepted' rows are.
-- - Either side can later remove it: the creator can always withdraw consent; an active company
--   member can always retract a proposal/showcase, but can never grant consent on the creator's
--   behalf (enforced by RLS's with-check below, not just app logic).

create table if not exists public.company_showcased_creators (
  id            uuid        primary key default gen_random_uuid(),
  company_id    uuid        not null references public.companies(id) on delete cascade,
  creator_id    uuid        not null references public.profiles(id),
  proposed_by   uuid        not null references public.profiles(id),
  status        text        not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  proposed_at   timestamptz not null default now(),
  responded_at  timestamptz,
  unique (company_id, creator_id)
);

alter table public.company_showcased_creators enable row level security;

-- Both sides of the relationship can read it: the creator (to see/respond to proposals) and any
-- active member of the company (to see their own company's showcase state).
drop policy if exists "creator or company member reads own showcase rows" on public.company_showcased_creators;
create policy "creator or company member reads own showcase rows" on public.company_showcased_creators
  for select
  using (creator_id = auth.uid() or public.is_active_company_member(company_id));

-- No insert policy — propose_showcase_creator() (rpc-company-showcase.sql) is the only path in, since it
-- needs to verify the proposer actually has an active manager_creator_links row with this specific
-- creator (a cross-table check that belongs in an RPC, not an RLS insert policy referencing a second
-- table). Without that check, any company member could propose showcasing a creator they have no
-- real relationship with.

-- The creator has full control over their own row — they can accept, decline, or later withdraw
-- consent at any time. This is safe because it's entirely self-scoped (creator_id = auth.uid() both
-- sides), so a creator can never affect anyone else's row this way.
drop policy if exists "creator manages own showcase consent" on public.company_showcased_creators;
create policy "creator manages own showcase consent" on public.company_showcased_creators
  for update
  using (creator_id = auth.uid())
  with check (creator_id = auth.uid());

-- An active company member can only move a row to 'declined' — i.e. retract a pending proposal or
-- remove an already-accepted showcase. They can NEVER set status to 'accepted': the with-check below
-- is what makes this a real dual-consent system rather than a company being able to grant itself
-- permission on the creator's behalf by just flipping the status directly.
drop policy if exists "company member retracts a showcase" on public.company_showcased_creators;
create policy "company member retracts a showcase" on public.company_showcased_creators
  for update
  using (public.is_active_company_member(company_id))
  with check (public.is_active_company_member(company_id) and status = 'declined');

-- No delete policy — same "status change, not a row delete" posture as manager_creator_links and
-- company_members, so a re-proposal after decline is an update-in-place (on conflict do update in
-- the RPC), not blocked by the unique(company_id, creator_id) constraint.

create index if not exists company_showcased_creators_creator_idx on public.company_showcased_creators (creator_id);
create index if not exists company_showcased_creators_company_idx on public.company_showcased_creators (company_id);

-- Public view: only 'accepted' rows, for /company/[handle]'s "Represented creators" section. Same
-- "view bypasses the base table's member-only RLS for anonymous reads" reasoning as public_companies
-- and public_company_roster (companies.sql) — without this, an anonymous visitor's query against the
-- base table would silently return zero rows (RLS grants no anon-read policy on it at all, by
-- design, since a pending/declined proposal must never leak).
create or replace view public.public_company_showcase as
  select company_id, creator_id, proposed_at
  from public.company_showcased_creators
  where status = 'accepted';
