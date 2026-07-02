// In-memory mock data store for the CreatorConnect click-through prototype.
// Everything here is FAKE DATA — no backend, no persistence beyond the browser session
// (a light localStorage mirror is used for the "viewing as" selection only, for convenience).

export type Role = 'creator' | 'advertiser' | 'manager';
export type Platform = 'YouTube' | 'Instagram' | 'TikTok';
export type ContentType = 'Dedicated Video' | 'Integration' | 'Feed Post' | 'Story Set' | 'Reel';
export type Mechanism = 'A' | 'C' | 'D';

export interface Creator {
	id: string;
	name: string;
	handle: string;
	platforms: Platform[];
	followers: number;
	niche: string;
	managerId?: string; // if represented by a manager
}

export interface Advertiser {
	id: string;
	company: string;
	contactName: string;
	industry: string;
}

export interface Manager {
	id: string;
	name: string;
	agency: string;
	creatorIds: string[];
}

export type ListingStatus = 'open' | 'pending' | 'deal';

// --- Mechanism A: fixed price + counter-offer ---
export interface OfferEvent {
	id: string;
	from: 'advertiser' | 'creator';
	amount: number;
	note?: string;
	createdAt: string;
	status: 'pending' | 'accepted' | 'rejected' | 'countered';
}

// --- Mechanism C: reserve-the-relationship / exclusivity ---
export interface ExclusivityGrant {
	advertiserId: string;
	grantedAt: string;
	exclusivityWindowDays: number;
	expiresAt: string;
	negotiation?: {
		proposedPrice: number;
		proposedTerms: string;
		status: 'proposed' | 'accepted' | 'countered';
		from: 'advertiser' | 'creator';
	};
}

// --- Mechanism D: reserve-the-slot / deposit ---
export interface Reservation {
	advertiserId: string;
	reservedAt: string;
	depositAmount: number;
	responseDeadline: string;
	status: 'awaiting_confirmation' | 'confirmed';
	confirmedPrice?: number;
}

export interface ConfirmedDeal {
	price: number;
	deliverySpec: string;
	deliveryDate: string;
	confirmedAt: string;
	mechanism: Mechanism;
	advertiserId: string;
}

export interface Listing {
	id: string;
	creatorId: string;
	platform: Platform;
	contentType: ContentType;
	availabilityWindow: string; // e.g. "Week of Aug 10-17, 2026"
	mechanism: Mechanism;
	status: ListingStatus;
	description: string;
	// mechanism-specific fields
	askingPrice?: number; // A
	exclusivityWindowDays?: number; // C (listing default, before a grant exists)
	rateCardRangeLow?: number; // C optional context
	rateCardRangeHigh?: number; // C optional context
	floorPrice?: number; // D
	reservationDeadline?: string; // D
	// mechanism-specific live state
	offers?: OfferEvent[]; // A
	exclusivity?: ExclusivityGrant; // C
	reservation?: Reservation; // D
	deal?: ConfirmedDeal;
	createdAt: string;
}

// ---------------- Seed data ----------------

export const creators: Creator[] = [
	{
		id: 'cr1',
		name: 'Mara Lindqvist',
		handle: '@maralindqvist',
		platforms: ['YouTube', 'Instagram'],
		followers: 312_000,
		niche: 'Outdoor gear & travel',
		managerId: 'mg1'
	},
	{
		id: 'cr2',
		name: 'Deshawn Okafor',
		handle: '@deshawncooks',
		platforms: ['TikTok', 'Instagram'],
		followers: 178_000,
		niche: 'Home cooking'
	},
	{
		id: 'cr3',
		name: 'Priya Natarajan',
		handle: '@priyabuilds',
		platforms: ['YouTube'],
		followers: 640_000,
		niche: 'Tech reviews & DIY electronics',
		managerId: 'mg1'
	},
	{
		id: 'cr4',
		name: 'Tomas Reyes',
		handle: '@tomasfit',
		platforms: ['Instagram', 'TikTok'],
		followers: 95_000,
		niche: 'Fitness & mobility'
	}
];

export const advertisers: Advertiser[] = [
	{ id: 'ad1', company: 'Wildpeak Outdoor Co.', contactName: 'Sasha Green', industry: 'Outdoor apparel' },
	{ id: 'ad2', company: 'Panbright Kitchenware', contactName: 'Luis Ferreira', industry: 'Home goods' },
	{ id: 'ad3', company: 'Voltframe Electronics', contactName: 'Ingrid Voss', industry: 'Consumer tech' }
];

export const managers: Manager[] = [
	{ id: 'mg1', name: 'Elena Cho', agency: 'Northstar Talent Group', creatorIds: ['cr1', 'cr3'] }
];

function daysFromNow(days: number): string {
	const d = new Date();
	d.setDate(d.getDate() + days);
	return d.toISOString();
}

export const listings: Listing[] = $state([
	// 1. Mechanism A, open, no offers yet
	{
		id: 'l1',
		creatorId: 'cr2',
		platform: 'TikTok',
		contentType: 'Integration',
		availabilityWindow: 'Week of Jul 14-21, 2026',
		mechanism: 'A',
		status: 'open',
		description: '60s recipe integration featuring your product as a key ingredient or tool.',
		askingPrice: 3200,
		offers: [],
		createdAt: daysFromNow(-5)
	},
	// 2. Mechanism A, open, active offer thread
	{
		id: 'l2',
		creatorId: 'cr4',
		platform: 'Instagram',
		contentType: 'Reel',
		availabilityWindow: 'Week of Jul 20-27, 2026',
		mechanism: 'A',
		status: 'pending',
		description: '30-45s mobility/fitness reel, product featured in a workout segment.',
		askingPrice: 1800,
		offers: [
			{
				id: 'o1',
				from: 'advertiser',
				amount: 1400,
				note: 'Love the content style — can we do $1,400 for a single reel?',
				createdAt: daysFromNow(-2),
				status: 'countered'
			},
			{
				id: 'o2',
				from: 'creator',
				amount: 1650,
				note: 'Appreciate it! I can do $1,650 including a story shoutout.',
				createdAt: daysFromNow(-1),
				status: 'pending'
			}
		],
		createdAt: daysFromNow(-6)
	},
	// 3. Mechanism A, already a confirmed deal
	{
		id: 'l3',
		creatorId: 'cr2',
		platform: 'Instagram',
		contentType: 'Feed Post',
		availabilityWindow: 'Week of Jul 7-14, 2026',
		mechanism: 'A',
		status: 'deal',
		description: 'Single feed post cooking with Panbright cookware, 3 photo carousel.',
		askingPrice: 2200,
		offers: [
			{ id: 'o3', from: 'advertiser', amount: 2200, createdAt: daysFromNow(-9), status: 'accepted' }
		],
		deal: {
			price: 2200,
			deliverySpec: 'Feed Post — 3-photo carousel cooking with Panbright cookware, #ad disclosure in caption',
			deliveryDate: daysFromNow(6),
			confirmedAt: daysFromNow(-8),
			mechanism: 'A',
			advertiserId: 'ad2'
		},
		createdAt: daysFromNow(-14)
	},
	// 4. Mechanism C, open, no exclusivity granted yet
	{
		id: 'l4',
		creatorId: 'cr1',
		platform: 'YouTube',
		contentType: 'Dedicated Video',
		availabilityWindow: 'Week of Aug 3-10, 2026',
		mechanism: 'C',
		status: 'open',
		description: 'Dedicated 8-10 min video, gear review/field test format on a multi-day trip.',
		exclusivityWindowDays: 10,
		rateCardRangeLow: 6000,
		rateCardRangeHigh: 9000,
		createdAt: daysFromNow(-4)
	},
	// 5. Mechanism C, exclusivity granted, negotiation in progress
	{
		id: 'l5',
		creatorId: 'cr1',
		platform: 'Instagram',
		contentType: 'Story Set',
		availabilityWindow: 'Week of Jul 27-Aug 3, 2026',
		mechanism: 'C',
		status: 'pending',
		description: '5-6 frame story set from a weekend trail trip, product woven into the narrative.',
		exclusivityWindowDays: 7,
		rateCardRangeLow: 1200,
		rateCardRangeHigh: 2000,
		exclusivity: {
			advertiserId: 'ad1',
			grantedAt: daysFromNow(-3),
			exclusivityWindowDays: 7,
			expiresAt: daysFromNow(4),
			negotiation: {
				proposedPrice: 1500,
				proposedTerms: '6-frame story set, product must appear in at least 3 frames, delivered within the availability window.',
				status: 'proposed',
				from: 'advertiser'
			}
		},
		createdAt: daysFromNow(-10)
	},
	// 6. Mechanism D, open
	{
		id: 'l6',
		creatorId: 'cr3',
		platform: 'YouTube',
		contentType: 'Integration',
		availabilityWindow: 'Week of Aug 10-17, 2026',
		mechanism: 'D',
		status: 'open',
		description: '3-5 min mid-roll integration in an upcoming teardown/review video.',
		floorPrice: 5000,
		reservationDeadline: daysFromNow(12),
		createdAt: daysFromNow(-3)
	},
	// 7. Mechanism D, reserved, awaiting creator confirmation
	{
		id: 'l7',
		creatorId: 'cr3',
		platform: 'YouTube',
		contentType: 'Dedicated Video',
		availabilityWindow: 'Week of Jul 21-28, 2026',
		mechanism: 'D',
		status: 'pending',
		description: 'Full dedicated video unboxing + review, 10-12 min.',
		floorPrice: 8000,
		reservationDeadline: daysFromNow(9),
		reservation: {
			advertiserId: 'ad3',
			reservedAt: daysFromNow(-1),
			depositAmount: 800,
			responseDeadline: daysFromNow(2),
			status: 'awaiting_confirmation'
		},
		createdAt: daysFromNow(-11)
	},
	// 8. Mechanism D, confirmed deal
	{
		id: 'l8',
		creatorId: 'cr4',
		platform: 'TikTok',
		contentType: 'Integration',
		availabilityWindow: 'Week of Jul 7-14, 2026',
		mechanism: 'D',
		status: 'deal',
		description: '45-60s workout integration, product used mid-set.',
		floorPrice: 1500,
		reservationDeadline: daysFromNow(-6),
		reservation: {
			advertiserId: 'ad1',
			reservedAt: daysFromNow(-13),
			depositAmount: 150,
			responseDeadline: daysFromNow(-11),
			status: 'confirmed',
			confirmedPrice: 1750
		},
		deal: {
			price: 1750,
			deliverySpec: '45-60s TikTok integration, product used mid-workout-set, #ad disclosure in first 3s',
			deliveryDate: daysFromNow(3),
			confirmedAt: daysFromNow(-12),
			mechanism: 'D',
			advertiserId: 'ad1'
		},
		createdAt: daysFromNow(-20)
	}
]);

// ---------------- Reactive current-role state ----------------

export type Viewer =
	| { role: 'creator'; id: string }
	| { role: 'advertiser'; id: string }
	| { role: 'manager'; id: string; actingAsCreatorId?: string };

function loadInitialViewer(): Viewer {
	if (typeof localStorage !== 'undefined') {
		const raw = localStorage.getItem('cc-viewer');
		if (raw) {
			try {
				return JSON.parse(raw) as Viewer;
			} catch {
				// fall through
			}
		}
	}
	return { role: 'creator', id: creators[0].id };
}

export const viewerState = $state<{ current: Viewer }>({ current: loadInitialViewer() });

export function setViewer(v: Viewer) {
	viewerState.current = v;
	if (typeof localStorage !== 'undefined') {
		localStorage.setItem('cc-viewer', JSON.stringify(v));
	}
}

export function setActingAsCreator(creatorId: string | undefined) {
	if (viewerState.current.role === 'manager') {
		viewerState.current = { ...viewerState.current, actingAsCreatorId: creatorId };
		if (typeof localStorage !== 'undefined') {
			localStorage.setItem('cc-viewer', JSON.stringify(viewerState.current));
		}
	}
}

// ---------------- Lookup helpers ----------------

export function getCreator(id: string): Creator | undefined {
	return creators.find((c) => c.id === id);
}

export function getAdvertiser(id: string): Advertiser | undefined {
	return advertisers.find((a) => a.id === id);
}

export function getManager(id: string): Manager | undefined {
	return managers.find((m) => m.id === id);
}

export function getListing(id: string): Listing | undefined {
	return listings.find((l) => l.id === id);
}

// Returns the creator id the current viewer is acting on behalf of, if any:
// - creator role -> their own id
// - manager role with an "acting as" creator selected -> that creator's id
// - otherwise -> undefined (advertiser, or manager in roster view)
export function actingCreatorId(v: Viewer): string | undefined {
	if (v.role === 'creator') return v.id;
	if (v.role === 'manager' && v.actingAsCreatorId) return v.actingAsCreatorId;
	return undefined;
}

export function canManageCreator(v: Viewer, creatorId: string): boolean {
	if (v.role === 'creator') return v.id === creatorId;
	if (v.role === 'manager') {
		const mgr = getManager(v.id);
		return !!mgr && mgr.creatorIds.includes(creatorId);
	}
	return false;
}

export function formatMoney(n: number): string {
	return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(n);
}

export function formatDate(iso: string): string {
	return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

export function formatDateTime(iso: string): string {
	return new Date(iso).toLocaleString('en-US', {
		month: 'short',
		day: 'numeric',
		hour: 'numeric',
		minute: '2-digit'
	});
}

export const mechanismLabel: Record<Mechanism, string> = {
	A: 'Fixed Price + Counter-Offer',
	C: 'Reserve-the-Relationship',
	D: 'Reserve-the-Slot'
};

export const mechanismShortExplainer: Record<Mechanism, string> = {
	A: 'Set an asking price. Advertisers can accept it or counter — you negotiate back and forth until you agree.',
	C: 'Give one advertiser exclusive early access to negotiate with you first, no deposit or binding hold. If they don’t close within the window, it opens back up.',
	D: 'Set a floor price and a reservation deadline. Advertisers pay a small deposit to lock the slot, then you confirm the final price shortly after.'
};

// ---------------- Mutating actions (mock "backend") ----------------

let offerIdCounter = 100;
let idCounter = 100;

export function nextId(prefix: string): string {
	idCounter += 1;
	return `${prefix}${idCounter}`;
}

function maybeConvertToDeal(listing: Listing, advertiserId: string, price: number, deliverySpec: string) {
	listing.status = 'deal';
	listing.deal = {
		price,
		deliverySpec,
		deliveryDate: listing.availabilityWindow ? daysFromNow(10) : daysFromNow(10),
		confirmedAt: new Date().toISOString(),
		mechanism: listing.mechanism,
		advertiserId
	};
}

// --- Mechanism A actions ---

export function submitOffer(listing: Listing, from: 'advertiser' | 'creator', amount: number, note: string, advertiserId?: string) {
	if (!listing.offers) listing.offers = [];
	// mark previous pending/countered offers as countered/resolved
	listing.offers.forEach((o) => {
		if (o.status === 'pending') o.status = 'countered';
	});
	offerIdCounter += 1;
	listing.offers.push({
		id: `o${offerIdCounter}`,
		from,
		amount,
		note,
		createdAt: new Date().toISOString(),
		status: 'pending'
	});
	listing.status = 'pending';
	if (advertiserId) (listing as any)._advertiserId = advertiserId;
}

export function acceptOffer(listing: Listing, offer: OfferEvent, advertiserId: string) {
	offer.status = 'accepted';
	maybeConvertToDeal(
		listing,
		advertiserId,
		offer.amount,
		`${listing.contentType} on ${listing.platform} — ${listing.description}`
	);
}

// --- Mechanism C actions ---

export function requestExclusivity(listing: Listing, advertiserId: string) {
	listing.exclusivity = {
		advertiserId,
		grantedAt: new Date().toISOString(),
		exclusivityWindowDays: listing.exclusivityWindowDays ?? 7,
		expiresAt: daysFromNow(listing.exclusivityWindowDays ?? 7)
	};
	listing.status = 'pending';
}

export function proposeTerms(
	listing: Listing,
	from: 'advertiser' | 'creator',
	proposedPrice: number,
	proposedTerms: string
) {
	if (!listing.exclusivity) return;
	listing.exclusivity.negotiation = {
		proposedPrice,
		proposedTerms,
		status: 'proposed',
		from
	};
}

export function acceptNegotiation(listing: Listing) {
	if (!listing.exclusivity?.negotiation) return;
	listing.exclusivity.negotiation.status = 'accepted';
	maybeConvertToDeal(
		listing,
		listing.exclusivity.advertiserId,
		listing.exclusivity.negotiation.proposedPrice,
		listing.exclusivity.negotiation.proposedTerms
	);
}

// --- Mechanism D actions ---

export function reserveSlot(listing: Listing, advertiserId: string) {
	const deposit = Math.round((listing.floorPrice ?? 0) * 0.1);
	listing.reservation = {
		advertiserId,
		reservedAt: new Date().toISOString(),
		depositAmount: deposit,
		responseDeadline: daysFromNow(2),
		status: 'awaiting_confirmation'
	};
	listing.status = 'pending';
}

export function confirmFinalPrice(listing: Listing, price: number) {
	if (!listing.reservation) return;
	listing.reservation.status = 'confirmed';
	listing.reservation.confirmedPrice = price;
	maybeConvertToDeal(
		listing,
		listing.reservation.advertiserId,
		price,
		`${listing.contentType} on ${listing.platform} — ${listing.description}`
	);
}

export function createListing(input: {
	creatorId: string;
	platform: Platform;
	contentType: ContentType;
	availabilityWindow: string;
	description: string;
	mechanism: Mechanism;
	askingPrice?: number;
	exclusivityWindowDays?: number;
	rateCardRangeLow?: number;
	rateCardRangeHigh?: number;
	floorPrice?: number;
	reservationDeadline?: string;
}): Listing {
	const listing: Listing = {
		id: nextId('l'),
		creatorId: input.creatorId,
		platform: input.platform,
		contentType: input.contentType,
		availabilityWindow: input.availabilityWindow,
		mechanism: input.mechanism,
		status: 'open',
		description: input.description,
		askingPrice: input.askingPrice,
		exclusivityWindowDays: input.exclusivityWindowDays,
		rateCardRangeLow: input.rateCardRangeLow,
		rateCardRangeHigh: input.rateCardRangeHigh,
		floorPrice: input.floorPrice,
		reservationDeadline: input.reservationDeadline,
		offers: input.mechanism === 'A' ? [] : undefined,
		createdAt: new Date().toISOString()
	};
	listings.unshift(listing);
	return listing;
}
