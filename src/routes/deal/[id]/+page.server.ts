import type { PageServerLoad } from './$types';

// Note: [id] here is the deals.id, not the listing id — the real deals table has its own id
// (the mock prototype kept the deal nested on the listing, real schema doesn't).
export const load: PageServerLoad = async ({ params, locals: { supabase } }) => {
	if (!supabase) return { deal: null };

	const { data: deal } = await supabase
		.from('deals')
		.select(
			`*, listing:creator_listings (platform, content_type, pricing_mechanism),
			 creator:profiles!deals_creator_id_fkey (display_name, handle, platform_handles),
			 advertiser:profiles!deals_advertiser_id_fkey (display_name)`
		)
		.eq('id', params.id)
		.maybeSingle();

	return { deal };
};
