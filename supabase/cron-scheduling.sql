-- CreatorConnect — pg_cron scheduling for expire_reservation and release_delivery_balance.
-- Run after rpc-delivery.sql. See ../docs/ARCHITECTURE.md Section 5.
--
-- REQUIRES the pg_cron extension. On Supabase: Database → Extensions → search "pg_cron" → Enable.
-- (Supabase-hosted projects have pg_cron available by default; it just needs enabling per-project.)

create extension if not exists pg_cron with schema extensions;

-- Wrapper functions, not bare "select fn(id) from rows" — a plain set-returning call aborts the
-- WHOLE batch's transaction if any single row raises (e.g. a race where another process already
-- resolved it between the scan and the call), silently rolling back rows that would have succeeded.
-- Each row gets its own exception handler so one bad row can't block the rest.

create or replace function public.run_expire_stale_reservations()
returns void language plpgsql as $$
declare
	r record;
begin
	for r in
		select id from public.reservations
		where status = 'held' and confirmation_deadline < now()
	loop
		begin
			perform public.expire_reservation(r.id);
		exception when others then
			raise warning 'expire_reservation failed for reservation %: %', r.id, sqlerrm;
		end;
	end loop;
end $$;

create or replace function public.run_release_delivered_balances()
returns void language plpgsql as $$
declare
	r record;
begin
	for r in
		select id from public.deals
		where status = 'delivered' and auto_release_at < now()
	loop
		begin
			perform public.release_delivery_balance(r.id);
		exception when others then
			raise warning 'release_delivery_balance failed for deal %: %', r.id, sqlerrm;
		end;
	end loop;
end $$;

select cron.schedule('expire-stale-reservations', '*/5 * * * *', 'select public.run_expire_stale_reservations();');
select cron.schedule('release-delivered-balances', '*/5 * * * *', 'select public.run_release_delivered_balances();');

-- To check job status/history later: select * from cron.job; select * from cron.job_run_details
-- order by start_time desc limit 20;
-- To remove a job: select cron.unschedule('expire-stale-reservations');
