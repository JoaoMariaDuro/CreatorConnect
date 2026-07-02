import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

// Creators and managers only — advertisers get bounced with a message from the page itself
// (still allowed to view /create, just told to switch roles, matching the original prototype UX).
export const load: PageServerLoad = async ({ locals: { safeGetSession, supabase } }) => {
	const { user } = await safeGetSession();
	if (!user) redirect(303, '/login');

	let roster: { id: string; display_name: string }[] = [];
	if (supabase) {
		const { data: profile } = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle();
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
