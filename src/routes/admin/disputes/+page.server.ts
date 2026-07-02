import type { PageServerLoad } from './$types';

// Disputed-deals queue for the founder. Sorted oldest-disputed-first (SLA style) — the longest-open
// dispute floats to the top. `deals` has no dedicated "disputed at" column, so the dispute timestamp
// comes from the audit_log row flag_dispute_as() writes (action = 'deal.disputed') — see
// supabase/rpc-delivery.sql. Batched into one follow-up query keyed by target_id rather than N
// per-deal queries — fine either way at this MVP's expected volume (a handful of disputes).
export const load: PageServerLoad = async ({ locals: { supabase } }) => {
	if (!supabase) return { disputes: [] };

	const { data: deals } = await supabase
		.from('deals')
		.select(
			`*, listing:creator_listings (pricing_mechanism),
			 creator:profiles!deals_creator_id_fkey (display_name),
			 advertiser:profiles!deals_advertiser_id_fkey (display_name)`
		)
		.eq('status', 'disputed');

	if (!deals || deals.length === 0) return { disputes: [] };

	const dealIds = deals.map((d) => d.id);
	const { data: auditRows } = await supabase
		.from('audit_log')
		.select('target_id, created_at')
		.eq('target_table', 'deals')
		.eq('action', 'deal.disputed')
		.in('target_id', dealIds);

	// If a deal was disputed more than once (e.g. re-flagged after a prior resolution attempt),
	// keep the most recent dispute event as the relevant "time since disputed" anchor.
	const disputedAtByDealId = new Map<string, string>();
	for (const row of auditRows ?? []) {
		const existing = disputedAtByDealId.get(row.target_id);
		if (!existing || row.created_at > existing) {
			disputedAtByDealId.set(row.target_id, row.created_at);
		}
	}

	const disputes = deals
		.map((deal) => ({ ...deal, disputed_at: disputedAtByDealId.get(deal.id) ?? deal.created_at }))
		.sort((a, b) => (a.disputed_at < b.disputed_at ? -1 : a.disputed_at > b.disputed_at ? 1 : 0));

	return { disputes };
};
