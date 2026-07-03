import type { PageServerLoad } from './$types';

// Admin-only general audit_log browser — generalizes the same query shape already used per-deal in
// /admin/disputes/[dealId]/+page.server.ts (same FK-embed pattern, same auto-named constraints:
// audit_log_actor_id_fkey / audit_log_acting_as_id_fkey), but across the whole platform instead of
// scoped to one deal. Most useful once there's more than one manager account — this is the
// founder's own visibility into the delegation/POA system working as designed, not just a
// dispute-specific tool. RLS on audit_log already grants is_platform_admin() a full read.
export const load: PageServerLoad = async ({ url, locals: { supabase } }) => {
	if (!supabase) return { auditLog: [], targetTable: 'all' };

	const targetTable = url.searchParams.get('target_table') ?? 'all';

	let query = supabase
		.from('audit_log')
		.select(
			`*, actor:public_profiles!audit_log_actor_id_fkey (display_name), acting_as:public_profiles!audit_log_acting_as_id_fkey (display_name)`
		)
		.order('created_at', { ascending: false })
		.limit(200);

	if (targetTable !== 'all') {
		query = query.eq('target_table', targetTable);
	}

	const { data } = await query;

	return { auditLog: (data ?? []) as any[], targetTable };
};
