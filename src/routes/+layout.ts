import { createBrowserClient, createServerClient, isBrowser } from '@supabase/ssr';
import { env } from '$env/dynamic/public';
import type { LayoutLoad } from './$types';

// Universal load: builds a Supabase client usable on both sides. The browser client keeps the
// session in sync (and lets the login page call signInWithOtp/signUp); on the server it reuses the
// request cookies. Guarded so the app still loads before the keys are configured.
export const load: LayoutLoad = async ({ data, depends, fetch }) => {
	depends('supabase:auth');

	const url = env.PUBLIC_SUPABASE_URL;
	const key = env.PUBLIC_SUPABASE_KEY;

	// `url && key` (not a separate `ready` boolean) is what lets TypeScript narrow both from
	// `string | undefined` to `string` in the branches below.
	const supabase =
		url && key
			? isBrowser()
				? createBrowserClient(url, key, { global: { fetch } })
				: createServerClient(url, key, {
						global: { fetch },
						cookies: { getAll: () => data?.cookies ?? [] }
					})
			: null;

	return {
		supabase,
		supabaseReady: Boolean(url && key),
		session: data?.session ?? null,
		user: data?.user ?? null,
		profile: data?.profile ?? null
	};
};
