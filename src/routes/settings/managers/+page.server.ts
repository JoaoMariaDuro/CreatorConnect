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
			.select('id, status, granted_at, revoked_at, manager:public_profiles!manager_creator_links_manager_id_fkey (id, display_name, handle)')
			.eq('creator_id', user.id)
			.order('created_at', { ascending: false });
		return { profile, links: (data ?? []) as any[] };
	}

	// manager
	const { data } = await supabase
		.from('manager_creator_links')
		.select(
			'id, status, granted_at, revoked_at, commission_bps, creator:public_profiles!manager_creator_links_creator_id_fkey (id, display_name, handle, niche_tags, follower_count, completed_deals_count)'
		)
		.eq('manager_id', user.id)
		.order('created_at', { ascending: false });
	const links = (data ?? []) as any[];

	const activeCreatorIds = links.filter((l) => l.status === 'active' && l.creator).map((l) => l.creator.id);
	const commissionBpsByCreator = new Map<string, number>(
		links.filter((l) => l.creator).map((l) => [l.creator.id, l.commission_bps])
	);

	// Commission ledger (item 6): same commission_bps x price computation already powering the
	// dashboard's aggregate card, exploded to per-deal line items.
	let commissionLedger: any[] = [];
	if (activeCreatorIds.length) {
		const { data: deals } = await supabase
			.from('deals')
			.select('id, creator_id, final_price_cents, status, confirmed_at, creator:public_profiles!deals_creator_id_fkey (display_name)')
			.in('creator_id', activeCreatorIds)
			.order('confirmed_at', { ascending: false });
		commissionLedger = (deals ?? []).map((d: any) => ({
			...d,
			commission_cents: Math.round((d.final_price_cents * (commissionBpsByCreator.get(d.creator_id) ?? 0)) / 10000)
		}));
	}

	// Band hub (item 8): every price band this manager has been granted, across their whole roster,
	// linking out to the existing per-listing editor on /listings/[id] rather than duplicating it —
	// stays a read/navigate hub, not a bulk-edit tool (PRODUCT.md §6's explicit v1 non-goal).
	const { data: bands } = await supabase
		.from('listing_price_bands')
		.select('id, listing_id, auto_accept_floor_cents, listing:creator_listings (platform, content_type, creator:public_profiles!creator_listings_creator_id_fkey (display_name))')
		.eq('manager_id', user.id);

	return { profile, links, commissionLedger, bands: (bands ?? []) as any[] };
};
