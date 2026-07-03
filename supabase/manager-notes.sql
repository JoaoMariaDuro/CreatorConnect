-- CreatorConnect — a manager's private working notes on a represented creator (preferences,
-- history, reminders — the "non-transactional relationship context" the manager-delegation model
-- (manager_creator_links) never captured, since that table is purely authority/band-scoped).
-- Run after delegation.sql (needs manager_creator_links, is_authorized helpers).
--
-- Deliberately a NEW table, not a `notes` column bolted onto manager_creator_links: that table's
-- "creator controls own links" RLS policy is `for all using (creator_id = auth.uid())` — a creator
-- already has full read/write on every column of their own link rows. Adding a manager-private notes
-- column there would make it immediately readable (and writable) by the creator too, since RLS is
-- row-level, not column-level — the same class of gap the profiles.role immutability fix (schema.sql)
-- exists to prevent. A separate table with its own narrow RLS is the correct, low-risk shape.

create table if not exists public.manager_creator_notes (
  id          uuid        primary key default gen_random_uuid(),
  manager_id  uuid        not null references public.profiles(id),
  creator_id  uuid        not null references public.profiles(id),
  notes       text        not null default '',
  updated_at  timestamptz not null default now(),
  unique (manager_id, creator_id)
);

alter table public.manager_creator_notes enable row level security;

-- Fully private to the manager — the creator has NO read or write access at all, on any policy,
-- anywhere in this file. These are the manager's own working notes, not a shared record. Without
-- this restriction being the ONLY policy on this table, a creator could read what their manager
-- privately wrote about them, defeating the entire point of the feature.
drop policy if exists "manager manages own notes" on public.manager_creator_notes;
create policy "manager manages own notes" on public.manager_creator_notes
  for all
  using (manager_id = auth.uid())
  with check (
    manager_id = auth.uid()
    and exists (
      select 1 from public.manager_creator_links
      where manager_id = auth.uid() and creator_id = manager_creator_notes.creator_id and status = 'active'
    )
  );

-- The with-check's active-link requirement means a note can only be created/updated while the
-- manager currently actively represents that creator — prevents orphaned notes about a relationship
-- that was never real or has since been revoked. It's an integrity guard, not a security boundary
-- (the table is already fully private to the manager regardless).

drop trigger if exists manager_creator_notes_touch on public.manager_creator_notes;
create trigger manager_creator_notes_touch
  before update on public.manager_creator_notes
  for each row execute function public.touch_updated_at();

create index if not exists manager_creator_notes_manager_idx on public.manager_creator_notes (manager_id);
