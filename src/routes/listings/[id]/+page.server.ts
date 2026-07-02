import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ params, locals: { safeGetSession, supabase } }) => {
	if (!supabase) return { listing: null, reservation: null, isDelegatedManager: false };

	const { data: listing } = await supabase
		.from('creator_listings')
		.select(
			`*, creator:profiles!creator_listings_creator_id_fkey (id, display_name, handle, follower_count, niche_tags)`
		)
		.eq('id', params.id)
		.maybeSingle();

	let reservation = null;
	if (listing?.pricing_mechanism === 'D') {
		const { data } = await supabase
			.from('reservations')
			.select('*, advertiser:profiles!reservations_advertiser_id_fkey (id, display_name)')
			.eq('listing_id', params.id)
			.order('created_at', { ascending: false })
			.limit(1)
			.maybeSingle();
		reservation = data;
	}

	// Real manager-delegation check (not just direct ownership) — matches is_authorized_for_creator's
	// logic server-side, so the UI shows the confirm/manage actions to a legitimately linked manager,
	// not just the creator themselves. The RPCs enforce this independently regardless of what the UI
	// shows (this is a UI-gating convenience, not the actual security boundary).
	let isDelegatedManager = false;
	if (listing) {
		const { user } = await safeGetSession();
		if (user && user.id !== listing.creator_id) {
			const { data: link } = await supabase
				.from('manager_creator_links')
				.select('id')
				.eq('manager_id', user.id)
				.eq('creator_id', listing.creator_id)
				.eq('status', 'active')
				.maybeSingle();
			isDelegatedManager = !!link;
		}
	}

	return { listing, reservation, isDelegatedManager };
};
