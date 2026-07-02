import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ params, locals: { safeGetSession, supabase } }) => {
	if (!supabase) return { listing: null, reservation: null, offers: [], grant: null, isDelegatedManager: false };

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

	let offers: any[] = [];
	if (listing?.pricing_mechanism === 'A') {
		const { data } = await supabase
			.from('listing_offers')
			.select('*')
			.eq('listing_id', params.id)
			.order('created_at', { ascending: true });
		offers = data ?? [];
	}

	let grant = null;
	if (listing?.pricing_mechanism === 'C') {
		const { data } = await supabase
			.from('listing_exclusivity_grants')
			.select('*, advertiser:profiles!listing_exclusivity_grants_advertiser_id_fkey (id, display_name)')
			.eq('listing_id', params.id)
			.order('created_at', { ascending: false })
			.limit(1)
			.maybeSingle();
		grant = data;
	}

	// Real manager-delegation check (not just direct ownership) — matches is_authorized_for_creator's
	// logic server-side, so the UI shows the confirm/manage actions to a legitimately linked manager,
	// not just the creator themselves. The RPCs enforce this independently regardless of what the UI
	// shows (this is a UI-gating convenience, not the actual security boundary).
	let isDelegatedManager = false;
	let ownerManagerBands: any[] = [];
	let myBand: { auto_accept_floor_cents: number | null; isDefault: boolean } | null = null;
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

			if (isDelegatedManager) {
				// Mirror check_price_band()'s exact fallback order (rpc-mechanism-d.sql lines 15-42):
				// 1) per-listing band (listing_price_bands, this manager + this listing)
				// 2) else the creator's per-manager default (manager_creator_links.default_auto_accept_floor_cents)
				// 3) else no band applies at all — fail closed, same as the RPC.
				const { data: ownBand } = await supabase
					.from('listing_price_bands')
					.select('auto_accept_floor_cents')
					.eq('listing_id', params.id)
					.eq('manager_id', user.id)
					.maybeSingle();

				if (ownBand?.auto_accept_floor_cents != null) {
					myBand = { auto_accept_floor_cents: ownBand.auto_accept_floor_cents, isDefault: false };
				} else {
					const { data: defaultLink } = await supabase
						.from('manager_creator_links')
						.select('default_auto_accept_floor_cents')
						.eq('manager_id', user.id)
						.eq('creator_id', listing.creator_id)
						.eq('status', 'active')
						.maybeSingle();

					myBand = defaultLink?.default_auto_accept_floor_cents != null
						? { auto_accept_floor_cents: defaultLink.default_auto_accept_floor_cents, isDefault: true }
						: null;
				}
			}
		} else if (user && user.id === listing.creator_id) {
			// Owner viewing their own listing: load active managers + any existing per-listing band,
			// so they can set "auto-accept ≥ $X for this listing" per manager (schema.sql's
			// listing_price_bands — confirm_deal_as fails closed with no band set, per rpc-mechanism-d.sql).
			const { data: links } = await supabase
				.from('manager_creator_links')
				.select('manager_id, manager:profiles!manager_creator_links_manager_id_fkey (id, display_name)')
				.eq('creator_id', user.id)
				.eq('status', 'active');
			const { data: bands } = await supabase
				.from('listing_price_bands')
				.select('manager_id, auto_accept_floor_cents')
				.eq('listing_id', params.id);
			const bandByManager = new Map((bands ?? []).map((b) => [b.manager_id, b.auto_accept_floor_cents]));
			ownerManagerBands = (links ?? []).map((l: any) => ({
				manager: l.manager,
				auto_accept_floor_cents: bandByManager.get(l.manager_id) ?? null
			}));
		}
	}

	return { listing, reservation, offers, grant, isDelegatedManager, ownerManagerBands, myBand };
};
