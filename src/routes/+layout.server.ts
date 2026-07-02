import type { LayoutServerLoad } from './$types';

// Resolves the signed-in user and loads their profile (role, display name) once here so every page
// can render role-aware UI without each one re-querying Supabase. Pattern matches Lota's dashboard.
export const load: LayoutServerLoad = async ({ locals: { safeGetSession, supabase }, cookies }) => {
	const { session, user } = await safeGetSession();

	let profile: { id: string; role: string; display_name: string; is_platform_admin?: boolean } | null = null;
	if (user && supabase) {
		const { data } = await supabase.from('profiles').select('*').eq('id', user.id).maybeSingle();
		profile = data ?? null;
	}

	return {
		session,
		user: user ? { id: user.id, email: user.email } : null,
		profile,
		// forwarded to the universal +layout.ts so the browser client shares the same auth cookies
		cookies: cookies.getAll()
	};
};
