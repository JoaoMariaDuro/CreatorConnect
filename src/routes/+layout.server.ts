import type { LayoutServerLoad } from './$types';

// Resolves the signed-in user and loads their profile (role, display name) once here so every page
// can render role-aware UI without each one re-querying Supabase. Pattern matches Lota's dashboard.
export const load: LayoutServerLoad = async ({ locals: { safeGetSession, supabase }, cookies }) => {
	const { session, user } = await safeGetSession();

	// Matches supabase/schema.sql's `profiles` columns — the query below already does `select('*')`,
	// this type just needs to keep up so pages (e.g. /settings) can read the full row without a cast.
	let profile: {
		id: string;
		role: string;
		display_name: string;
		handle: string | null;
		avatar_url: string | null;
		bio: string | null;
		niche_tags: string[];
		follower_count: number | null;
		platform_handles: Record<string, string>;
		completed_deals_count: number;
		is_platform_admin?: boolean;
	} | null = null;
	let notifications: any[] = [];
	if (user && supabase) {
		const { data } = await supabase.from('profiles').select('*').eq('id', user.id).maybeSingle();
		profile = data ?? null;

		// Loaded once here (same "shared across every page" reasoning as profile above) so the top bar's
		// notification bell doesn't need its own route-level fetch. `notifications` RLS already scopes
		// this to the caller's own rows.
		const { data: notifData } = await supabase
			.from('notifications')
			.select('id, type, payload, read_at, created_at')
			.eq('user_id', user.id)
			.order('created_at', { ascending: false })
			.limit(20);
		notifications = notifData ?? [];
	}

	return {
		session,
		user: user ? { id: user.id, email: user.email } : null,
		profile,
		notifications,
		// forwarded to the universal +layout.ts so the browser client shares the same auth cookies
		cookies: cookies.getAll()
	};
};
