import type { PageServerLoad } from './$types';

// Real admin landing page, replacing the previous pure redirect-to-disputes. Now that /admin/feedback
// and /admin/audit-log exist alongside /admin/disputes, a bare redirect buries two of the three
// surfaces one click below the default landing spot — this gives the founder a real overview with
// live counts to link out from.
//
// Role counts go through `public_profiles`, not the base `profiles` table: `profiles`' own RLS only
// grants a self-read policy (no is_platform_admin() bypass there — see supabase/schema.sql), so a
// direct count against `profiles` would silently return 0 for an admin. `deals` and `feedback` both
// already have an explicit `or public.is_platform_admin()` clause in their own RLS, so those count
// correctly against the base tables directly.
export const load: PageServerLoad = async ({ locals: { supabase } }) => {
	if (!supabase) return { counts: null };

	const [
		{ count: openDisputes },
		{ count: totalCreators },
		{ count: totalAdvertisers },
		{ count: totalManagers },
		{ count: openListings },
		{ count: activeDeals },
		{ count: completedDeals },
		{ count: feedbackCount },
		{ count: issueCount }
	] = await Promise.all([
		supabase.from('deals').select('id', { count: 'exact', head: true }).eq('status', 'disputed'),
		supabase.from('public_profiles').select('id', { count: 'exact', head: true }).eq('role', 'creator'),
		supabase.from('public_profiles').select('id', { count: 'exact', head: true }).eq('role', 'advertiser'),
		supabase.from('public_profiles').select('id', { count: 'exact', head: true }).eq('role', 'manager'),
		supabase.from('creator_listings').select('id', { count: 'exact', head: true }).eq('status', 'open'),
		supabase.from('deals').select('id', { count: 'exact', head: true }).in('status', ['active', 'delivered']),
		supabase.from('deals').select('id', { count: 'exact', head: true }).eq('status', 'completed'),
		supabase.from('feedback').select('id', { count: 'exact', head: true }),
		supabase.from('feedback').select('id', { count: 'exact', head: true }).eq('kind', 'issue')
	]);

	return {
		counts: {
			openDisputes: openDisputes ?? 0,
			totalCreators: totalCreators ?? 0,
			totalAdvertisers: totalAdvertisers ?? 0,
			totalManagers: totalManagers ?? 0,
			openListings: openListings ?? 0,
			activeDeals: activeDeals ?? 0,
			completedDeals: completedDeals ?? 0,
			feedbackCount: feedbackCount ?? 0,
			issueCount: issueCount ?? 0
		}
	};
};
