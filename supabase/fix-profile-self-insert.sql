-- CreatorConnect — lets a signed-in user create their OWN missing profile row.
-- Run after rpc-mechanism-ac.sql.
--
-- Belt-and-suspenders fix: handle_new_user() (schema.sql) is supposed to create a profiles row on
-- signup, but it depends on role/display_name arriving correctly in auth.users.raw_user_meta_data —
-- true for the magic-link flow (signInWithOtp's options.data), but NOT guaranteed for other auth
-- methods (e.g. passkey registration doesn't carry the same metadata shape). Rather than debug every
-- auth method's metadata plumbing, this adds a client-driven fallback: if a signed-in user has no
-- profiles row, the app shows a small "complete your profile" form that inserts it directly — safe
-- because RLS only ever lets a user insert a row with their OWN id.

drop policy if exists "insert own profile" on public.profiles;
create policy "insert own profile" on public.profiles
	for insert
	with check (auth.uid() = id);
