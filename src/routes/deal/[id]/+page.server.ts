import type { PageServerLoad } from './$types';

// Note: [id] here is the deals.id, not the listing id — the real deals table has its own id
// (the mock prototype kept the deal nested on the listing, real schema doesn't).
export const load: PageServerLoad = async ({ params, locals: { safeGetSession, supabase } }) => {
	if (!supabase) return { deal: null, isDelegatedManager: false };

	const { data: deal } = await supabase
		.from('deals')
		.select(
			`*, listing:creator_listings (platform, content_type, pricing_mechanism),
			 creator:public_profiles!deals_creator_id_fkey (display_name, handle, platform_handles),
			 advertiser:public_profiles!deals_advertiser_id_fkey (display_name)`
		)
		.eq('id', params.id)
		.maybeSingle();

	// Real manager-delegation check (not just direct ownership) — matches is_authorized_for_creator's
	// logic server-side (see listings/[id]/+page.server.ts for the reference implementation), so the
	// UI shows the "flag a dispute" action to a legitimately linked manager acting on the creator's
	// behalf, not just the creator themselves. flag_dispute_as (rpc-delivery.sql) already enforces this
	// independently server-side — this is a UI-gating convenience, not the actual security boundary.
	let isDelegatedManager = false;
	if (deal) {
		const { user } = await safeGetSession();
		if (user && user.id !== deal.creator_id) {
			const { data: link } = await supabase
				.from('manager_creator_links')
				.select('id')
				.eq('manager_id', user.id)
				.eq('creator_id', deal.creator_id)
				.eq('status', 'active')
				.maybeSingle();
			isDelegatedManager = !!link;
		}
	}

	return { deal, isDelegatedManager };
};
