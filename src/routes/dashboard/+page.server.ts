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

		// "Needs attention": across all three mechanisms, anything on one of this creator's listings
		// that's awaiting the creator's response right now.
		// D: a reservation held at 'held' awaiting the creator's price confirmation (rpc-mechanism-d.sql).
		// A: an 'open' listing_offers row most recently proposed_by the advertiser — i.e. the ball's in
		//    the creator's court to accept/counter (see rpc-mechanism-ac.sql's submit_offer_as /
		//    accept_offer_as, and listings/[id]/+page.svelte's latestOffer.proposed_by === 'advertiser' gate).
		// C: an 'active' listing_exclusivity_grants row where terms HAVE been proposed and the current
		//    negotiation was proposed by the advertiser — i.e. awaiting the creator's counter/accept
		//    (see propose_exclusivity_terms_as / convert_exclusivity_as and the +page.svelte
		//    grant.negotiation.from === 'advertiser' gate). A grant with NO negotiation yet is NOT the
		//    creator's turn — it's waiting on the advertiser to propose first (see +page.svelte's
		//    "Waiting on {advertiser} to propose terms" branch for !grant.negotiation), so it's excluded.
		const listingIds = (listings ?? []).map((l) => l.id);
		let pendingReservations: any[] = [];
		let pendingOffers: any[] = [];
		let pendingGrants: any[] = [];
		if (listingIds.length) {
			const [{ data: reservationData }, { data: offerData }, { data: grantData }] = await Promise.all([
				supabase
					.from('reservations')
					.select('id, listing_id, status')
					.in('listing_id', listingIds)
					.eq('status', 'held'),
				supabase
					.from('listing_offers')
					.select('id, listing_id, status, proposed_by')
					.in('listing_id', listingIds)
					.eq('status', 'open')
					.eq('proposed_by', 'advertiser'),
				supabase
					.from('listing_exclusivity_grants')
					.select('id, listing_id, status, negotiation')
					.in('listing_id', listingIds)
					.eq('status', 'active')
			]);
			pendingReservations = reservationData ?? [];
			pendingOffers = offerData ?? [];
			pendingGrants = (grantData ?? []).filter((g: any) => g.negotiation?.from === 'advertiser');
		}

		return {
			profile,
			listings: (listings ?? []) as any[],
			pendingListingIds: pendingReservations.map((r) => r.listing_id),
			pendingOfferListingIds: pendingOffers.map((o) => o.listing_id),
			pendingGrantListingIds: pendingGrants.map((g) => g.listing_id),
			roster: [] as any[]
		};
	}

	if (profile.role === 'advertiser') {
		const [{ data: reservations }, { data: offers }, { data: grants }] = await Promise.all([
			supabase
				.from('reservations')
				.select('id, status, listing:creator_listings (id, platform, content_type, availability_window, pricing_mechanism, status, creator:profiles!creator_listings_creator_id_fkey (display_name))')
				.eq('advertiser_id', user.id)
				.order('created_at', { ascending: false }),
			// Mechanism A: this advertiser's own offer threads still open (not accepted/rejected/withdrawn/expired).
			supabase
				.from('listing_offers')
				.select('id, status, proposed_by, listing:creator_listings (id, platform, content_type, availability_window, pricing_mechanism, status, creator:profiles!creator_listings_creator_id_fkey (display_name))')
				.eq('advertiser_id', user.id)
				.eq('status', 'open')
				.order('created_at', { ascending: false }),
			// Mechanism C: this advertiser's own exclusivity grants still active (not converted/expired/revoked).
			supabase
				.from('listing_exclusivity_grants')
				.select('id, status, negotiation, listing:creator_listings (id, platform, content_type, availability_window, pricing_mechanism, status, creator:profiles!creator_listings_creator_id_fkey (display_name))')
				.eq('advertiser_id', user.id)
				.eq('status', 'active')
				.order('created_at', { ascending: false })
		]);

		return {
			profile,
			listings: [] as any[],
			reservations: (reservations ?? []) as any[],
			offers: (offers ?? []) as any[],
			grants: (grants ?? []) as any[],
			roster: [] as any[]
		};
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
