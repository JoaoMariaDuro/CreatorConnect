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
	A: 'Set an asking price. Advertisers can accept it or counter — you negotiate back and forth until you agree.',
	C: 'Give one advertiser exclusive early access to negotiate with you first, no deposit or binding hold. If they don’t close within the window, it opens back up.',
	D: 'Set a floor price and a reservation deadline. Advertisers pay a small deposit to lock the slot, then you confirm the final price shortly after.'
};
