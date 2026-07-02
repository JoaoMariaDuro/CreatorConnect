import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

// Creators and managers only — advertisers are redirected server-side before /create ever renders.
export const load: PageServerLoad = async ({ locals: { safeGetSession, supabase } }) => {
	const { user } = await safeGetSession();
	if (!user) redirect(303, '/login?intent=creator');

	let roster: { id: string; display_name: string }[] = [];
	if (supabase) {
		const { data: profile } = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle();
		if (profile?.role === 'advertiser') redirect(303, '/browse?notice=advertiser-cannot-create');
		if (profile?.role === 'manager') {
			const { data } = await supabase
				.from('manager_creator_links')
				.select('creator:profiles!manager_creator_links_creator_id_fkey (id, display_name)')
				.eq('manager_id', user.id)
				.eq('status', 'active');
			roster = (data ?? []).map((r: any) => r.creator).filter(Boolean);
		}
	}

	return { roster };
};
