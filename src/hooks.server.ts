import { createServerClient } from '@supabase/ssr';
import { env } from '$env/dynamic/public';
import type { Handle } from '@sveltejs/kit';

// Per-request Supabase client bound to the request's cookies, plus a safe session getter.
// The whole app talks to Supabase AS THE LOGGED-IN USER (publishable key + the user's JWT in
// cookies), so Row-Level Security does the access control — no service-role key is ever used from
// the app itself. Pattern matches Lota's dashboard (../../lota/dashboard/src/hooks.server.js).
export const handle: Handle = async ({ event, resolve }) => {
	const url = env.PUBLIC_SUPABASE_URL;
	const key = env.PUBLIC_SUPABASE_KEY;

	// Until the keys are set, the app still runs — just signed-out. Keeps local dev/prototype work
	// going before Supabase is fully wired up. The `url && key` check (not the separate `ready`
	// boolean) is what lets TypeScript narrow both from `string | undefined` to `string` below.
	event.locals.supabaseReady = Boolean(url && key);
	event.locals.supabase =
		url && key
			? createServerClient(url, key, {
					cookies: {
						getAll: () => event.cookies.getAll(),
						setAll: (cookiesToSet: { name: string; value: string; options: any }[]) =>
							cookiesToSet.forEach(({ name, value, options }) =>
								event.cookies.set(name, value, { ...options, path: '/' })
							)
					}
				})
			: null;

	// getSession() alone can't be trusted server-side (doesn't revalidate the JWT); getUser() does.
	// Memoised per request so layout load and any route guards share one getUser() call.
	let cached: { session: any; user: any } | undefined;
	event.locals.safeGetSession = async () => {
		if (cached) return cached;
		if (!event.locals.supabase) return (cached = { session: null, user: null });
		const {
			data: { session }
		} = await event.locals.supabase.auth.getSession();
		if (!session) return (cached = { session: null, user: null });
		const {
			data: { user },
			error
		} = await event.locals.supabase.auth.getUser();
		cached = error ? { session: null, user: null } : { session, user };
		return cached;
	};

	return resolve(event, {
		filterSerializedResponseHeaders: (name) =>
			name === 'content-range' || name === 'x-supabase-api-version'
	});
};
