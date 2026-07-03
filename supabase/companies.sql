-- CreatorConnect — company (organization) entity: multi-person advertiser/manager orgs.
-- Run after delegation.sql (needs audit_log, notifications) and schema.sql (needs profiles,
-- public_profiles). See docs/ARCHITECTURE.md Section 3's delegation design, which this mirrors.
--
-- Company is an ADDITIVE identity layer, never a role change. profiles.role stays exactly what it
-- was at signup (creator/advertiser/manager, immutable per schema.sql's "update own profile" RLS).
-- Joining a company only ever inserts a company_members row — it never touches profiles.role. Only
-- advertisers and managers may belong to a company (creators are explicitly excluded — enforced at
-- invite time in rpc-companies.sql, and belt-and-suspenders by company_type matching role there too).
--
-- No impersonation: a company member always authenticates as themselves. Nothing in deals,
-- creator_listings, reservations, listing_offers, listing_exclusivity_grants, or escrow_transactions
-- references company_id — this is a pure identity/roster layer, not a new delegation-of-authority
-- tier on top of manager_creator_links. Do not add company-level price bands or company-level
-- "acting as" checks here.

create table if not exists public.companies (
  id                uuid        primary key default gen_random_uuid(),
  name              text        not null,
  handle            text        not null,
  avatar_url        text,
  bio               text,
  niche_tags        text[]      not null default '{}',
  platform_handles  jsonb       not null default '{}'::jsonb,
  company_type      text        not null check (company_type in ('advertiser', 'manager')),
  created_by        uuid        not null references public.profiles(id),
  created_at        timestamptz not null default now()
);

-- Case-insensitive uniqueness, matching the /company/[handle] lookup pattern (a plain .eq('handle',
-- ...)). Note: profiles.handle itself has NO unique constraint today (a separate, pre-existing gap,
-- out of scope to fix here) — but companies.handle gets one from day one since this is a brand new
-- namespace with no reason to allow self-collision.
create unique index if not exists companies_handle_unique_idx on public.companies (lower(handle));

alter table public.companies enable row level security;

create table if not exists public.company_members (
  id          uuid        primary key default gen_random_uuid(),
  company_id  uuid        not null references public.companies(id) on delete cascade,
  user_id     uuid        not null references public.profiles(id),
  role        text        not null check (role in ('owner', 'member')),
  status      text        not null default 'pending' check (status in ('pending', 'active', 'revoked')),
  invited_at  timestamptz not null default now(),
  joined_at   timestamptz,
  revoked_at  timestamptz,
  created_at  timestamptz not null default now(),
  unique (company_id, user_id)
);

alter table public.company_members enable row level security;

-- Helper: is auth.uid() an active owner of this company? Reused by every RLS policy below and by
-- rpc-companies.sql's invite checks — one source of truth for "who can manage this company's
-- roster/settings," same reasoning as is_authorized_for_creator() in schema.sql/delegation.sql.
create or replace function public.is_active_company_owner(p_company_id uuid)
returns boolean language sql stable as $$
  select exists (
    select 1 from public.company_members
    where company_id = p_company_id and user_id = auth.uid() and role = 'owner' and status = 'active'
  );
$$;

-- Helper: is auth.uid() an active member (owner or member) of this company? Used for read-scoping —
-- any active member can see the roster/settings, only owners can change them.
create or replace function public.is_active_company_member(p_company_id uuid)
returns boolean language sql stable as $$
  select exists (
    select 1 from public.company_members
    where company_id = p_company_id and user_id = auth.uid() and status = 'active'
  );
$$;

-- ===== companies RLS =====

drop policy if exists "active members read own company" on public.companies;
create policy "active members read own company" on public.companies
  for select
  using (public.is_active_company_member(id));

-- No insert policy at all — only create_company() (security definer RPC, rpc-companies.sql) inserts
-- into companies. Without this restriction, a company could be created via a plain client insert with
-- no corresponding company_members owner row in the same transaction, orphaning it permanently (no
-- one would ever pass is_active_company_owner() for it). The RPC guarantees both rows land together.

-- Only an active owner can update company settings. company_type is locked immutable via the `with
-- check` clause: an owner flipping it after members joined would silently break the
-- role-must-match-company_type invariant enforced only at invite time (rpc-companies.sql), same
-- "immutable after creation" posture as profiles.role.
drop policy if exists "owner updates own company" on public.companies;
create policy "owner updates own company" on public.companies
  for update
  using (public.is_active_company_owner(id))
  with check (
    public.is_active_company_owner(id)
    and company_type = (select c.company_type from public.companies c where c.id = companies.id)
  );

-- No delete policy — company deactivation/deletion is out of scope for this pass. If needed later,
-- add an explicit "archived" status rather than a hard delete, to preserve company_members history
-- and any audit_log rows referencing this company.

-- ===== company_members RLS =====

-- Active members can see their own company's full roster. `or user_id = auth.uid()` additionally
-- lets an invited-but-still-pending user see their OWN invite row — without it,
-- is_active_company_member() is false for a pending row, so the invite would be invisible to the one
-- person who needs to accept it.
drop policy if exists "active members read own roster" on public.company_members;
create policy "active members read own roster" on public.company_members
  for select
  using (public.is_active_company_member(company_id) or user_id = auth.uid());

-- Only an active owner can insert rows directly — defense in depth, not the primary write path.
-- invite_company_member_by_email() (rpc-companies.sql) is the real way invites get created, since
-- resolving an email to a user_id requires reading auth.users, which no client-side policy can do.
-- Without this policy AND without the RPC's own is_active_company_owner() check, there'd be no layer
-- preventing any authenticated user from adding themselves (or anyone) to any company's roster.
drop policy if exists "owner inserts members" on public.company_members;
create policy "owner inserts members" on public.company_members
  for insert
  with check (public.is_active_company_owner(company_id));

-- Only an active owner can update member rows (revoke, promote/demote role). Without the
-- owner-scoping, any authenticated user — not just an owner of THIS company — could revoke another
-- company's members. The one invariant this can't enforce alone ("never leave zero active owners")
-- is handled by the trigger below, since RLS only ever sees one row at a time, not the sibling count.
drop policy if exists "owner manages member rows" on public.company_members;
create policy "owner manages member rows" on public.company_members
  for update
  using (public.is_active_company_owner(company_id))
  with check (public.is_active_company_owner(company_id));

-- No delete policy — revocation is a status update ('revoked'), never a row delete, so the roster
-- keeps full history (same "revoked, not deleted" pattern as manager_creator_links). A re-invite
-- after revocation is an update-in-place (status back to 'pending'), not a fresh insert, avoiding the
-- unique(company_id, user_id) constraint blocking re-invites — mirrors invite_manager_by_email()'s
-- `on conflict ... do update` pattern.

-- Trigger: block any update that would leave a company with zero active owners. RLS's using/with
-- check clauses see one row at a time, not an aggregate across siblings — a trigger with an explicit
-- count query in the same transaction is the standard way to enforce this kind of invariant. Without
-- it, an owner revoking themselves (accident, or the sole owner acting alone) would permanently
-- orphan the company: no row would ever pass is_active_company_owner() again, no recovery path short
-- of a manual SQL fix.
create or replace function public.enforce_company_has_owner()
returns trigger language plpgsql as $$
declare
  v_remaining_owners int;
begin
  if old.role = 'owner' and old.status = 'active'
     and (new.role <> 'owner' or new.status <> 'active') then
    select count(*) into v_remaining_owners
    from public.company_members
    where company_id = old.company_id and role = 'owner' and status = 'active' and id <> old.id;
    if v_remaining_owners = 0 then
      raise exception 'cannot remove the last active owner of a company';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists company_members_guard_last_owner on public.company_members;
create trigger company_members_guard_last_owner
  before update on public.company_members
  for each row execute function public.enforce_company_has_owner();

create index if not exists company_members_company_idx on public.company_members (company_id);
create index if not exists company_members_user_idx on public.company_members (user_id);

-- ===== public views =====
-- Same reasoning as public_profiles (schema.sql): a plain view runs with the view owner's privileges
-- by default (Postgres security_invoker = false), which is what lets an ANONYMOUS request (no
-- auth.uid() at all — e.g. the public /company/[handle] page) read through it even though the base
-- tables' RLS above only grants active-member self-reads. Without these views, /company/[handle] and
-- /u/[handle]'s company-affiliation lookup would silently get zero rows for any visitor who isn't an
-- active member — the exact bug class fixed in commit d0990b8 for profiles embeds, recurring here one
-- layer deeper.
create or replace view public.public_companies as
  select id, name, handle, avatar_url, bio, niche_tags, platform_handles, company_type, created_at
  from public.companies;

-- Active memberships only. This view has no real foreign-key constraint of its own (it's built over
-- company_members, not a base table), so it is deliberately NOT embedded via PostgREST's
-- `!constraint_name` syntax anywhere — routes query this view for (user_id/company_id, role,
-- joined_at) and separately query public_profiles/public_companies for the other side, joining
-- client-side in the load function. See src/routes/company/[handle]/+page.server.ts and
-- src/routes/u/[handle]/+page.server.ts.
create or replace view public.public_company_roster as
  select cm.company_id, cm.user_id, cm.role, cm.joined_at
  from public.company_members cm
  where cm.status = 'active';

-- NON-GOALS (confirmed with founder, not built here):
-- - No company_id column on deals / creator_listings / reservations / listing_offers /
--   listing_exclusivity_grants / escrow_transactions. Company is identity/roster only.
-- - No company-level price bands or company-level delegation authority over members' actions —
--   manager_creator_links remains the only delegation-of-authority mechanism.
-- - No company billing/commission rollups.
-- - No hard single-company-per-user constraint at the schema level (create_company() in
--   rpc-companies.sql blocks creating a SECOND company while already an active owner/member
--   elsewhere, but the schema itself doesn't forbid multiple active memberships — v1 UI just assumes
--   one and features the first active row it finds).
