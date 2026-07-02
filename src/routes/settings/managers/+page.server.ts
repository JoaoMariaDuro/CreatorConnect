import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals: { safeGetSession, supabase } }) => {
	const { user } = await safeGetSession();
	if (!user || !supabase) redirect(303, '/login');

	const { data: profile } = await supabase.from('profiles').select('*').eq('id', user.id).maybeSingle();
	if (!profile || (profile.role !== 'creator' && profile.role !== 'manager')) {
		return { profile, links: [] as any[] };
	}

	if (profile.role === 'creator') {
		const { data } = await supabase
			.from('manager_creator_links')
			.select('id, status, granted_at, revoked_at, manager:profiles!manager_creator_links_manager_id_fkey (id, display_name, handle)')
			.eq('creator_id', user.id)
			.order('created_at', { ascending: false });
		return { profile, links: (data ?? []) as any[] };
	}

	// manager
	const { data } = await supabase
		.from('manager_creator_links')
		.select('id, status, granted_at, revoked_at, creator:profiles!manager_creator_links_creator_id_fkey (id, display_name, handle)')
		.eq('manager_id', user.id)
		.order('created_at', { ascending: false });
	return { profile, links: (data ?? []) as any[] };
};
