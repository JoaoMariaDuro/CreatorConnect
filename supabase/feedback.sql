-- CreatorConnect — user-submitted feedback (top bar's "Report an issue" / "Suggest an idea").
-- Run after schema.sql. See docs/ROLE_ACCESS_AND_UX_SPEC.md's Handoff #4 synthesis, task list item
-- covering the top bar build.
--
-- Deliberately simple: a plain client-side insert with RLS enforcement, not a security-definer RPC
-- like audit_log's write path — this is low-stakes, user-submitted content (a bug report or an
-- idea), not a security-sensitive audit trail, so the extra RPC indirection isn't warranted here.

create table if not exists public.feedback (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references public.profiles(id),
  kind        text        not null check (kind in ('issue', 'idea')),
  message     text        not null,
  page_path   text, -- which page they were on when they submitted, for context when reviewing later
  created_at  timestamptz not null default now()
);

alter table public.feedback enable row level security;

drop policy if exists "insert own feedback" on public.feedback;
create policy "insert own feedback" on public.feedback
  for insert
  with check (auth.uid() = user_id);

-- A user can see their own submissions (e.g. to confirm one went through); the founder can see all
-- of them via the same is_platform_admin() gate used everywhere else in the admin surface.
drop policy if exists "read own or admin feedback" on public.feedback;
create policy "read own or admin feedback" on public.feedback
  for select
  using (auth.uid() = user_id or public.is_platform_admin());
