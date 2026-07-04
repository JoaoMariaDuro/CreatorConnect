-- CreatorConnect — add "member can leave their own org" RLS policy. Run any time after orgs.sql.
--
-- Same reasoning as fix-org-rls-recursion.sql for being a standalone file rather than folded into
-- orgs.sql itself: orgs.sql's own `drop table ... cascade` at the top would destroy any org you've
-- already created just to pick up this one new policy. This file only adds a policy — it doesn't
-- touch any table, row, or existing policy.
--
-- Without this, only an org owner could remove a member, leaving no self-service way to leave. This
-- matters more now that accept_org_invite_token() (rpc-org-invites.sql) blocks accepting an invite
-- while already active in a DIFFERENT org — a member who wants to switch orgs needs a way to remove
-- themselves first. Mirrors org_showcased_creators' "member retracts a showcase, can never grant
-- 'accepted'" pattern: the with-check pins the target status to exactly 'revoked', so this can never
-- be (ab)used to self-promote to owner or reactivate a revoked row. No new recursion risk — still
-- gated by `user_id = auth.uid()` directly, not a function that queries org_members again.

drop policy if exists "member leaves own org" on public.org_members;
create policy "member leaves own org" on public.org_members
  for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and status = 'revoked');
