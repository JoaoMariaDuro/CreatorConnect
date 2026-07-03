-- CreatorConnect — org (organization) entity: multi-person advertiser/manager orgs.
-- Run after delegation.sql (needs audit_log, notifications) and schema.sql (needs profiles,
-- public_profiles). See docs/ARCHITECTURE.md Section 3's delegation design, which this mirrors.
--
-- Renamed from "company" to "org" terminology (founder's call). An earlier version of this file
-- tried an in-place ALTER TABLE RENAME to preserve data across the rename — that approach had a
-- real bug: it dropped the shared helper function is_active_company_member() before
-- org-showcase.sql (a separate file, run later) got a chance to drop ITS OWN policies (on
-- company_showcased_creators, a third table) that also depended on it, so Postgres correctly
-- refused with "cannot drop function ... other objects depend on it." Since this feature has zero
-- real data (confirmed empty all session — no real launch users yet), the fix is to stop trying to
-- be clever: drop every old company-named object outright (CASCADE handles any remaining
-- dependents automatically, including from other tables/files) and recreate everything fresh under
-- the org names. Simpler and more robust than a multi-file rename dance, and safe to re-run any
-- number of times, from any partial state a failed run might have left behind.
--
-- Org is an ADDITIVE identity layer, never a role change. profiles.role stays exactly what it was
-- at signup (creator/advertiser/manager, immutable per schema.sql's "update own profile" RLS).
-- Joining an org only ever inserts an org_members row — it never touches profiles.role. Only
-- advertisers and managers may belong to an org (creators are explicitly excluded — enforced at
-- invite time in rpc-orgs.sql, and belt-and-suspenders by org_type matching role there too).
--
-- No impersonation: an org member always authenticates as themselves. Nothing in deals,
-- creator_listings, reservations, listing_offers, listing_exclusivity_grants, or escrow_transactions
-- references org_id — this is a pure identity/roster layer, not a new delegation-of-authority tier
-- on top of manager_creator_links. Do not add org-level price bands or org-level "acting as" checks
-- here.

-- ===== clean slate: drop every old/partial company-or-org-named object =====
-- CASCADE on the table drops also removes any dependent policies, indexes, and the
-- org_showcased_creators/company_showcased_creators table (it has a foreign key to this one) —
-- org-showcase.sql's own drops further cover that table explicitly too, so this is safe whichever
-- file happens to run first.

drop table if exists public.org_showcased_creators cascade;
drop table if exists public.company_showcased_creators cascade;
drop table if exists public.org_members cascade;
drop table if exists public.company_members cascade;
drop table if exists public.orgs cascade;
drop table if exists public.companies cascade;
drop view if exists public.public_org_showcase;
drop view if exists public.public_company_showcase;
drop view if exists public.public_org_roster;
drop view if exists public.public_company_roster;
drop view if exists public.public_orgs;
drop view if exists public.public_companies;
drop function if exists public.is_active_org_owner(uuid) cascade;
drop function if exists public.is_active_org_member(uuid) cascade;
drop function if exists public.is_active_company_owner(uuid) cascade;
drop function if exists public.is_active_company_member(uuid) cascade;
drop function if exists public.enforce_org_has_owner() cascade;
drop function if exists public.enforce_company_has_owner() cascade;
drop function if exists public.create_org(text, text, text, text, text);
drop function if exists public.create_company(text, text, text, text, text);
drop function if exists public.invite_org_member_by_email(uuid, text);
drop function if exists public.invite_company_member_by_email(uuid, text);
drop function if exists public.accept_org_invite(uuid);
drop function if exists public.accept_company_invite(uuid);
drop function if exists public.propose_showcase_creator(uuid, uuid);
drop function if exists public.respond_showcase_creator(uuid, boolean);

-- ===== create fresh =====
-- Still `if not exists`/`or replace` throughout, matching this codebase's usual idempotent style,
-- even though the drops above should already guarantee a clean slate — defense in depth against a
-- partial/interrupted run.

create table if not exists public.orgs (
  id                uuid        primary key default gen_random_uuid(),
  name              text        not null,
  handle            text        not null,
  avatar_url        text,
  bio               text,
  niche_tags        text[]      not null default '{}',
  platform_handles  jsonb       not null default '{}'::jsonb,
  org_type          text        not null check (org_type in ('advertiser', 'manager')),
  created_by        uuid        not null references public.profiles(id),
  created_at        timestamptz not null default now()
);

-- Case-insensitive uniqueness, matching the /org/[handle] lookup pattern (a plain .eq('handle',
-- ...)). Note: profiles.handle has its own separate unique index (fix-profile-handle-unique.sql).
create unique index if not exists orgs_handle_unique_idx on public.orgs (lower(handle));

alter table public.orgs enable row level security;

create table if not exists public.org_members (
  id          uuid        primary key default gen_random_uuid(),
  org_id      uuid        not null references public.orgs(id) on delete cascade,
  user_id     uuid        not null references public.profiles(id),
  role        text        not null check (role in ('owner', 'member')),
  status      text        not null default 'pending' check (status in ('pending', 'active', 'revoked')),
  invited_at  timestamptz not null default now(),
  joined_at   timestamptz,
  revoked_at  timestamptz,
  created_at  timestamptz not null default now(),
  unique (org_id, user_id)
);

alter table public.org_members enable row level security;

-- Helper: is auth.uid() an active owner of this org? Reused by every RLS policy below and by
-- rpc-orgs.sql's invite checks — one source of truth for "who can manage this org's roster/settings,"
-- same reasoning as is_authorized_for_creator() in schema.sql/delegation.sql.
--
-- SECURITY DEFINER, unlike is_authorized_for_creator (which is a plain `language sql stable`
-- function): that function queries manager_creator_links to gate OTHER tables' RLS, never
-- manager_creator_links' own policies, so there's no cycle. This function is different — it's used
-- in org_members' OWN "active members read own roster" policy below, and its body also queries
-- org_members. Without SECURITY DEFINER, evaluating that policy calls this function, which queries
-- org_members, which re-evaluates the same policy, which calls this function again — infinite
-- recursion ("stack depth limit exceeded"), confirmed live once org_members had a real row to
-- evaluate against (empty-table selects never triggered it, which is why this wasn't caught
-- immediately). SECURITY DEFINER makes the internal query run as the function owner, bypassing RLS
-- instead of re-triggering it — auth.uid() still reflects the real caller throughout, so this
-- doesn't change who the check is actually checking, only how it reads the table internally.
create or replace function public.is_active_org_owner(p_org_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.org_members
    where org_id = p_org_id and user_id = auth.uid() and role = 'owner' and status = 'active'
  );
$$;

-- Helper: is auth.uid() an active member (owner or member) of this org? Used for read-scoping — any
-- active member can see the roster/settings, only owners can change them. SECURITY DEFINER for the
-- exact same recursion reason as is_active_org_owner above.
create or replace function public.is_active_org_member(p_org_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.org_members
    where org_id = p_org_id and user_id = auth.uid() and status = 'active'
  );
$$;

-- ===== orgs RLS =====

drop policy if exists "active members read own org" on public.orgs;
create policy "active members read own org" on public.orgs
  for select
  using (public.is_active_org_member(id));

-- No insert policy at all — only create_org() (security definer RPC, rpc-orgs.sql) inserts into
-- orgs. Without this restriction, an org could be created via a plain client insert with no
-- corresponding org_members owner row in the same transaction, orphaning it permanently (no one
-- would ever pass is_active_org_owner() for it). The RPC guarantees both rows land together.

-- Only an active owner can update org settings. org_type is locked immutable via the `with check`
-- clause: an owner flipping it after members joined would silently break the
-- role-must-match-org_type invariant enforced only at invite time (rpc-orgs.sql), same "immutable
-- after creation" posture as profiles.role.
drop policy if exists "owner updates own org" on public.orgs;
create policy "owner updates own org" on public.orgs
  for update
  using (public.is_active_org_owner(id))
  with check (
    public.is_active_org_owner(id)
    and org_type = (select o.org_type from public.orgs o where o.id = orgs.id)
  );

-- No delete policy — org deactivation/deletion is out of scope for this pass. If needed later, add
-- an explicit "archived" status rather than a hard delete, to preserve org_members history and any
-- audit_log rows referencing this org.

-- ===== org_members RLS =====

-- Active members can see their own org's full roster. `or user_id = auth.uid()` additionally lets an
-- invited-but-still-pending user see their OWN invite row — without it, is_active_org_member() is
-- false for a pending row, so the invite would be invisible to the one person who needs to accept it.
drop policy if exists "active members read own roster" on public.org_members;
create policy "active members read own roster" on public.org_members
  for select
  using (public.is_active_org_member(org_id) or user_id = auth.uid());

-- Only an active owner can insert rows directly — defense in depth, not the primary write path.
-- invite_org_member_by_email() (rpc-orgs.sql) is the real way invites get created, since resolving
-- an email to a user_id requires reading auth.users, which no client-side policy can do. Without this
-- policy AND without the RPC's own is_active_org_owner() check, there'd be no layer preventing any
-- authenticated user from adding themselves (or anyone) to any org's roster.
drop policy if exists "owner inserts members" on public.org_members;
create policy "owner inserts members" on public.org_members
  for insert
  with check (public.is_active_org_owner(org_id));

-- Only an active owner can update member rows (revoke, promote/demote role). Without the
-- owner-scoping, any authenticated user — not just an owner of THIS org — could revoke another org's
-- members. The one invariant this can't enforce alone ("never leave zero active owners") is handled
-- by the trigger below, since RLS only ever sees one row at a time, not the sibling count.
drop policy if exists "owner manages member rows" on public.org_members;
create policy "owner manages member rows" on public.org_members
  for update
  using (public.is_active_org_owner(org_id))
  with check (public.is_active_org_owner(org_id));

-- No delete policy — revocation is a status update ('revoked'), never a row delete, so the roster
-- keeps full history (same "revoked, not deleted" pattern as manager_creator_links). A re-invite
-- after revocation is an update-in-place (status back to 'pending'), not a fresh insert, avoiding the
-- unique(org_id, user_id) constraint blocking re-invites — mirrors invite_manager_by_email()'s
-- `on conflict ... do update` pattern.

-- Trigger: block any update that would leave an org with zero active owners. RLS's using/with check
-- clauses see one row at a time, not an aggregate across siblings — a trigger with an explicit count
-- query in the same transaction is the standard way to enforce this kind of invariant. Without it, an
-- owner revoking themselves (accident, or the sole owner acting alone) would permanently orphan the
-- org: no row would ever pass is_active_org_owner() again, no recovery path short of a manual SQL fix.
create or replace function public.enforce_org_has_owner()
returns trigger language plpgsql as $$
declare
  v_remaining_owners int;
begin
  if old.role = 'owner' and old.status = 'active'
     and (new.role <> 'owner' or new.status <> 'active') then
    select count(*) into v_remaining_owners
    from public.org_members
    where org_id = old.org_id and role = 'owner' and status = 'active' and id <> old.id;
    if v_remaining_owners = 0 then
      raise exception 'cannot remove the last active owner of an org';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists org_members_guard_last_owner on public.org_members;
create trigger org_members_guard_last_owner
  before update on public.org_members
  for each row execute function public.enforce_org_has_owner();

create index if not exists org_members_org_idx on public.org_members (org_id);
create index if not exists org_members_user_idx on public.org_members (user_id);

-- ===== public views =====
-- Same reasoning as public_profiles (schema.sql): a plain view runs with the view owner's privileges
-- by default (Postgres security_invoker = false), which is what lets an ANONYMOUS request (no
-- auth.uid() at all — e.g. the public /org/[handle] page) read through it even though the base
-- tables' RLS above only grants active-member self-reads. Without these views, /org/[handle] and
-- /u/[handle]'s org-affiliation lookup would silently get zero rows for any visitor who isn't an
-- active member — the exact bug class fixed in commit d0990b8 for profiles embeds, recurring here one
-- layer deeper.
create or replace view public.public_orgs as
  select id, name, handle, avatar_url, bio, niche_tags, platform_handles, org_type, created_at
  from public.orgs;

-- Active memberships only. This view has no real foreign-key constraint of its own (it's built over
-- org_members, not a base table), so it is deliberately NOT embedded via PostgREST's
-- `!constraint_name` syntax anywhere — routes query this view for (user_id/org_id, role, joined_at)
-- and separately query public_profiles/public_orgs for the other side, joining client-side in the
-- load function. See src/routes/org/[handle]/+page.server.ts and src/routes/u/[handle]/+page.server.ts.
create or replace view public.public_org_roster as
  select om.org_id, om.user_id, om.role, om.joined_at
  from public.org_members om
  where om.status = 'active';

-- NON-GOALS (confirmed with founder, not built here):
-- - No org_id column on deals / creator_listings / reservations / listing_offers /
--   listing_exclusivity_grants / escrow_transactions. Org is identity/roster only.
-- - No org-level price bands or org-level delegation authority over members' actions —
--   manager_creator_links remains the only delegation-of-authority mechanism.
-- - No org billing/commission rollups.
-- - No hard single-org-per-user constraint at the schema level (create_org() in rpc-orgs.sql blocks
--   creating a SECOND org while already an active owner/member elsewhere, but the schema itself
--   doesn't forbid multiple active memberships — v1 UI just assumes one and features the first
--   active row it finds).
