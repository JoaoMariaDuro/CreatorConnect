import type { PageServerLoad } from './$types';

// Public browse — RLS's "browse open listings" policy already allows anyone (signed in or not) to
// read non-draft listings, so this works signed-out too. Real Supabase query, no auth required.
export const load: PageServerLoad = async ({ locals: { supabase } }) => {
	if (!supabase) return { listings: [] };

	const { data, error } = await supabase
		.from('creator_listings')
		.select(
			`id, platform, content_type, availability_window, pricing_mechanism, status,
			 floor_price_cents, exclusivity_window, rate_card_low_cents, rate_card_high_cents, created_at,
			 creator:profiles!creator_listings_creator_id_fkey (id, display_name, handle, follower_count, niche_tags)`
		)
		.neq('status', 'draft')
		.order('created_at', { ascending: false });

	if (error) {
		console.error('browse load error', error);
		return { listings: [] as any[] };
	}

	// Cast: without generated Supabase DB types, postgrest-js infers embedded many-to-one relations
	// (creator:profiles!fkey) as arrays by default — this is a single row per listing in reality.
	return { listings: (data ?? []) as any[] };
};
