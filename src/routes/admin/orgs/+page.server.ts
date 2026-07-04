import type { PageServerLoad } from './$types';

// Admin-only org browser — the founder's own ask for "a page to manage orgs if needed." Reads
// through the base `orgs`/`org_members` tables directly (not the public_* views), since
// fix-org-admin-access.sql grants is_platform_admin() a full bypass on their RLS — an admin gets
// pending/revoked rows too, not just active ones, which the public views deliberately hide.
//
// Embedding public_profiles off orgs.created_by / org_members.user_id via their real FK constraints
// (orgs_created_by_fkey, org_members_user_id_fkey) is the same proven-safe pattern used throughout
// this codebase — the source of each query is a real table with a real FK, so PostgREST resolves the
// embed correctly even though the target alias is a view.
export const load: PageServerLoad = async ({ locals: { supabase } }) => {
	if (!supabase) return { orgs: [] as any[] };

	const { data: orgs } = await supabase
		.from('orgs')
		.select(
			'id, name, handle, org_type, bio, created_at, owner:public_profiles!orgs_created_by_fkey (display_name, handle)'
		)
		.order('created_at', { ascending: false });

	const orgIds = (orgs ?? []).map((o) => o.id);
	const membersByOrg = new Map<string, any[]>();
	if (orgIds.length) {
		const { data: members } = await supabase
			.from('org_members')
			.select(
				'id, org_id, role, status, member:public_profiles!org_members_user_id_fkey (id, display_name, handle)'
			)
			.in('org_id', orgIds)
			.order('created_at', { ascending: false });
		for (const m of members ?? []) {
			const list = membersByOrg.get(m.org_id) ?? [];
			list.push(m);
			membersByOrg.set(m.org_id, list);
		}
	}

	const orgsWithMembers = (orgs ?? []).map((o) => ({
		...o,
		members: membersByOrg.get(o.id) ?? []
	}));

	return { orgs: orgsWithMembers };
};
