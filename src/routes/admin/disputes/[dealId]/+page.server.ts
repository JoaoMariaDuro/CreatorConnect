import type { PageServerLoad } from './$types';

// Admin-only deal detail + resolution view. No party-scoping needed here: the deals/escrow_transactions/
// audit_log select RLS policies all already include `or public.is_platform_admin()` (see rpc-admin.sql /
// deals.sql / delegation.sql), so a plain lookup by id is correct and sufficient — the RPC
// (resolve_dispute_as_admin) re-checks is_platform_admin() itself server-side as the real security boundary,
// this load function is not it.
export const load: PageServerLoad = async ({ params, locals: { supabase } }) => {
	if (!supabase) {
		return { deal: null, escrowTransactions: [], auditLog: [] };
	}

	const { data: deal } = await supabase
		.from('deals')
		.select(
			`*, listing:creator_listings (platform, content_type, pricing_mechanism),
			 creator:profiles!deals_creator_id_fkey (display_name, handle, platform_handles),
			 advertiser:profiles!deals_advertiser_id_fkey (display_name)`
		)
		.eq('id', params.dealId)
		.maybeSingle();

	if (!deal) {
		return { deal: null, escrowTransactions: [], auditLog: [] };
	}

	const { data: escrowTransactions } = await supabase
		.from('escrow_transactions')
		.select('*')
		.eq('deal_id', params.dealId)
		.order('created_at', { ascending: true });

	// Exactly one of these three is set per deals.sql's one_origin_only check constraint — figure out
	// which, so we can pull the audit trail for the deal's origin row too (e.g. the reservation that
	// preceded it), not just the deals-table rows themselves.
	let originTable: 'reservations' | 'listing_offers' | 'listing_exclusivity_grants' | null = null;
	let originId: string | null = null;
	if (deal.reservation_id) {
		originTable = 'reservations';
		originId = deal.reservation_id;
	} else if (deal.offer_id) {
		originTable = 'listing_offers';
		originId = deal.offer_id;
	} else if (deal.exclusivity_grant_id) {
		originTable = 'listing_exclusivity_grants';
		originId = deal.exclusivity_grant_id;
	}

	// audit_log has two FKs to profiles (actor_id who clicked, acting_as_id the creator if this was a
	// delegated manager action) — both inline `references public.profiles(id)` column constraints in
	// delegation.sql, so Postgres auto-names them `<table>_<column>_fkey`: audit_log_actor_id_fkey and
	// audit_log_acting_as_id_fkey. Confirmed against the same auto-naming convention already relied on
	// for deals_creator_id_fkey/deals_advertiser_id_fkey in deal/[id]/+page.server.ts. PostgREST embed
	// syntax supports disambiguating two FKs to the same target table in one select via two separate
	// aliased embeds, so a single query covers both joins.
	const auditSelect =
		`*, actor:profiles!audit_log_actor_id_fkey (display_name), acting_as:profiles!audit_log_acting_as_id_fkey (display_name)`;

	const dealAuditQuery = supabase
		.from('audit_log')
		.select(auditSelect)
		.eq('target_table', 'deals')
		.eq('target_id', params.dealId);

	const originAuditQuery = originTable && originId
		? supabase.from('audit_log').select(auditSelect).eq('target_table', originTable).eq('target_id', originId)
		: null;

	const [dealAuditResult, originAuditResult] = await Promise.all([
		dealAuditQuery,
		originAuditQuery ?? Promise.resolve({ data: [] as unknown[] })
	]);

	const auditLog = [...(dealAuditResult.data ?? []), ...((originAuditResult as { data: unknown[] | null }).data ?? [])].sort(
		(a: any, b: any) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
	);

	return {
		deal,
		escrowTransactions: escrowTransactions ?? [],
		auditLog
	};
};
