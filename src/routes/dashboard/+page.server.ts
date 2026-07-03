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

		// Delivery obligations don't show up in the "needs attention" queue above (nothing's awaiting a
		// response — the deal is already confirmed), but they're exactly the kind of commitment a creator
		// needs visibility into before confirming a *new* delivery date that might collide with one they
		// already agreed to. Surfaced separately, sorted by urgency.
		const { data: dealsData } = await supabase
			.from('deals')
			.select(
				'id, advertiser_id, final_price_cents, status, delivery_due_at, advertiser:public_profiles!deals_advertiser_id_fkey (display_name)'
			)
			.eq('creator_id', user.id)
			.in('status', ['active', 'delivered'])
			.order('delivery_due_at', { ascending: true });

		return {
			profile,
			listings: (listings ?? []) as any[],
			pendingListingIds: pendingReservations.map((r) => r.listing_id),
			pendingOfferListingIds: pendingOffers.map((o) => o.listing_id),
			pendingGrantListingIds: pendingGrants.map((g) => g.listing_id),
			upcomingDeliveries: (dealsData ?? []) as any[],
			roster: [] as any[]
		};
	}

	if (profile.role === 'advertiser') {
		const [{ data: reservations }, { data: offers }, { data: grants }] = await Promise.all([
			supabase
				.from('reservations')
				.select('id, status, listing:creator_listings (id, platform, content_type, availability_window, pricing_mechanism, status, creator:public_profiles!creator_listings_creator_id_fkey (display_name))')
				.eq('advertiser_id', user.id)
				.order('created_at', { ascending: false }),
			// Mechanism A: this advertiser's own offer threads still open (not accepted/rejected/withdrawn/expired).
			supabase
				.from('listing_offers')
				.select('id, status, proposed_by, listing:creator_listings (id, platform, content_type, availability_window, pricing_mechanism, status, creator:public_profiles!creator_listings_creator_id_fkey (display_name))')
				.eq('advertiser_id', user.id)
				.eq('status', 'open')
				.order('created_at', { ascending: false }),
			// Mechanism C: this advertiser's own exclusivity grants still active (not converted/expired/revoked).
			supabase
				.from('listing_exclusivity_grants')
				.select('id, status, negotiation, listing:creator_listings (id, platform, content_type, availability_window, pricing_mechanism, status, creator:public_profiles!creator_listings_creator_id_fkey (display_name))')
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
			.select(
				'commission_bps, creator:public_profiles!manager_creator_links_creator_id_fkey (id, display_name, handle, follower_count)'
			)
			.eq('manager_id', user.id)
			.eq('status', 'active');
		const roster = (links ?? []).map((l: any) => l.creator).filter(Boolean);
		const commissionBpsByCreator = new Map<string, number>(
			(links ?? []).filter((l: any) => l.creator).map((l: any) => [l.creator.id, l.commission_bps])
		);

		const creatorIds = roster.map((c: any) => c.id);
		let rosterListings: any[] = [];
		let pendingListingIds: string[] = [];
		let pendingOfferListingIds: string[] = [];
		let pendingGrantListingIds: string[] = [];
		let rosterDeals: any[] = [];

		if (creatorIds.length) {
			const { data } = await supabase
				.from('creator_listings')
				.select('id, platform, content_type, availability_window, pricing_mechanism, status, creator_id, creator:public_profiles!creator_listings_creator_id_fkey (display_name)')
				.in('creator_id', creatorIds)
				.order('created_at', { ascending: false });
			rosterListings = data ?? [];

			// Same "needs attention" pattern as the creator dashboard (see that branch above for the
			// per-mechanism reasoning), fanned across every roster listing instead of one creator's own.
			const listingIds = rosterListings.map((l) => l.id);
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
				pendingListingIds = (reservationData ?? []).map((r: any) => r.listing_id);
				pendingOfferListingIds = (offerData ?? []).map((o: any) => o.listing_id);
				pendingGrantListingIds = (grantData ?? [])
					.filter((g: any) => g.negotiation?.from === 'advertiser')
					.map((g: any) => g.listing_id);
			}

			const { data: dealsData } = await supabase
				.from('deals')
				.select(
					'id, creator_id, advertiser_id, final_price_cents, status, delivery_due_at, advertiser:public_profiles!deals_advertiser_id_fkey (display_name)'
				)
				.in('creator_id', creatorIds);
			rosterDeals = dealsData ?? [];
		}

		// Display-only estimate: commission_bps lives on manager_creator_links (the relationship, not a
		// specific deal), so this sums every roster deal's price at that creator's rate — not just deals
		// this manager personally confirmed. No Stripe payout is wired to this number (see PRODUCT.md §3's
		// "5% additional on manager-run transactions" promise — that automation is gated behind Stripe
		// Connect going live; this card only closes the "zero visibility" gap in the meantime).
		const commissionCentsFor = (statuses: string[]) =>
			rosterDeals
				.filter((d) => statuses.includes(d.status))
				.reduce(
					(sum, d) =>
						sum + Math.round((d.final_price_cents * (commissionBpsByCreator.get(d.creator_id) ?? 0)) / 10000),
					0
				);

		const upcomingDeliveries = rosterDeals
			.filter((d) => (d.status === 'active' || d.status === 'delivered') && d.delivery_due_at)
			.sort((a, b) => new Date(a.delivery_due_at).getTime() - new Date(b.delivery_due_at).getTime())
			.slice(0, 5)
			.map((d) => ({ ...d, creator: roster.find((c: any) => c.id === d.creator_id) }));

		const rosterWithActivity = roster.map((c: any) => ({
			...c,
			activeDealsCount: rosterDeals.filter((d) => d.creator_id === c.id && (d.status === 'active' || d.status === 'delivered')).length,
			completedDealsCount: rosterDeals.filter((d) => d.creator_id === c.id && d.status === 'completed').length
		}));

		return {
			profile,
			listings: rosterListings as any[],
			roster: rosterWithActivity as any[],
			pendingListingIds,
			pendingOfferListingIds,
			pendingGrantListingIds,
			commissionEarnedCents: commissionCentsFor(['completed']),
			commissionPendingCents: commissionCentsFor(['active', 'delivered']),
			upcomingDeliveries
		};
	}

	return { profile, listings: [], roster: [] };
};
