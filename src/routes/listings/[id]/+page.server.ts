import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ params, locals: { supabase } }) => {
	if (!supabase) return { listing: null, reservation: null };

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

	return { listing, reservation };
};
