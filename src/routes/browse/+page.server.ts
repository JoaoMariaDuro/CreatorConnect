import type { PageServerLoad } from './$types';

// Public browse — RLS's "browse open listings" policy already allows anyone (signed in or not) to
// read non-draft listings, so this works signed-out too. Real Supabase query, no auth required.
export const load: PageServerLoad = async ({ locals: { safeGetSession, supabase } }) => {
	if (!supabase) return { listings: [], shortlistedIds: [] as string[] };

	const { data, error } = await supabase
		.from('creator_listings')
		.select(
			`id, platform, content_type, availability_window, pricing_mechanism, status,
			 floor_price_cents, exclusivity_window, rate_card_low_cents, rate_card_high_cents, created_at,
			 creator:public_profiles!creator_listings_creator_id_fkey (id, display_name, handle, follower_count, niche_tags, completed_deals_count)`
		)
		.neq('status', 'draft')
		.order('created_at', { ascending: false });

	if (error) {
		console.error('browse load error', error);
		return { listings: [] as any[], shortlistedIds: [] as string[] };
	}

	// Only advertisers shortlist (PRODUCT.md Flow 2) — cheap enough to just check "is there a
	// session" rather than also loading the full profile just to gate one extra query; a non-advertiser
	// signed-in user simply gets an empty shortlist (their `shortlists` RLS rows, if any, would be
	// none anyway since the UI never shows them the toggle).
	const { user } = await safeGetSession();
	let shortlistedIds: string[] = [];
	if (user) {
		const { data: shortlisted } = await supabase.from('shortlists').select('listing_id').eq('advertiser_id', user.id);
		shortlistedIds = (shortlisted ?? []).map((s) => s.listing_id);
	}

	// Cast: without generated Supabase DB types, postgrest-js infers embedded many-to-one relations
	// (creator:public_profiles!fkey) as arrays by default — this is a single row per listing in reality.
	return { listings: (data ?? []) as any[], shortlistedIds };
};
