import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals: { safeGetSession, supabase } }) => {
	const { user } = await safeGetSession();
	if (!user || !supabase) redirect(303, '/login');

	const { data: profile } = await supabase.from('profiles').select('*').eq('id', user.id).maybeSingle();
	if (!profile) return { profile: null, listings: [], reservations: [], roster: [] };

	if (profile.role === 'creator') {
		const { data: listings } = await supabase
			.from('creator_listings')
			.select('id, platform, content_type, availability_window, pricing_mechanism, status')
			.eq('creator_id', user.id)
			.order('created_at', { ascending: false });

		// "Needs attention" for D: any reservation on one of this creator's listings still awaiting
		// their confirmation. A/C aren't wired to real negotiation RPCs yet (see listing detail page).
		const listingIds = (listings ?? []).map((l) => l.id);
		let pendingReservations: any[] = [];
		if (listingIds.length) {
			const { data } = await supabase
				.from('reservations')
				.select('id, listing_id, status')
				.in('listing_id', listingIds)
				.eq('status', 'held');
			pendingReservations = data ?? [];
		}

		return { profile, listings: (listings ?? []) as any[], pendingListingIds: pendingReservations.map((r) => r.listing_id), roster: [] as any[] };
	}

	if (profile.role === 'advertiser') {
		const { data: reservations } = await supabase
			.from('reservations')
			.select('id, status, listing:creator_listings (id, platform, content_type, availability_window, pricing_mechanism, status, creator:profiles!creator_listings_creator_id_fkey (display_name))')
			.eq('advertiser_id', user.id)
			.order('created_at', { ascending: false });

		return { profile, listings: [] as any[], reservations: (reservations ?? []) as any[], roster: [] as any[] };
	}

	if (profile.role === 'manager') {
		const { data: links } = await supabase
			.from('manager_creator_links')
			.select('creator:profiles!manager_creator_links_creator_id_fkey (id, display_name, handle, follower_count)')
			.eq('manager_id', user.id)
			.eq('status', 'active');
		const roster = (links ?? []).map((l: any) => l.creator).filter(Boolean);

		const creatorIds = roster.map((c: any) => c.id);
		let rosterListings: any[] = [];
		if (creatorIds.length) {
			const { data } = await supabase
				.from('creator_listings')
				.select('id, platform, content_type, availability_window, pricing_mechanism, status, creator_id, creator:profiles!creator_listings_creator_id_fkey (display_name)')
				.in('creator_id', creatorIds)
				.order('created_at', { ascending: false });
			rosterListings = data ?? [];
		}

		return { profile, listings: rosterListings as any[], roster: roster as any[] };
	}

	return { profile, listings: [], roster: [] };
};
