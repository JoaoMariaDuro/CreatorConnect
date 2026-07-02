// Pure formatting helpers + static copy, shared across pages. Extracted from the old mock
// store.svelte.ts (which now only exists as reference — real data comes from Supabase).

export type Mechanism = 'A' | 'C' | 'D';

export function formatMoney(cents: number): string {
	return new Intl.NumberFormat('en-US', {
		style: 'currency',
		currency: 'USD',
		maximumFractionDigits: 0
	}).format(cents / 100);
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
	A: 'Set an asking price. Advertisers can accept it outright or counter — you negotiate back and forth by message until you agree on a final number.',
	C: 'Give one advertiser exclusive early access to negotiate with you first — no deposit, no binding hold. If they don’t close within the window, the slot opens back up to others.',
	D: 'Set a floor price and a reservation window. An advertiser pays a small, non-refundable deposit to lock the slot — you then confirm a final price at or above your floor (not stuck at the floor number). If you don’t respond in time, the reservation expires and the advertiser’s deposit is refunded automatically.'
};
