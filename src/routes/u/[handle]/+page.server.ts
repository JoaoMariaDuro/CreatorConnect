import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

// Public, no-auth individual profile page for advertisers and managers. Creators keep /c/[handle]
// (untouched, unchanged) — this route explicitly excludes them, not a duplicate of that page.
// Same public_profiles-view reasoning as c/[handle]'s own header comment.
export const load: PageServerLoad = async ({ params, locals: { supabase } }) => {
	if (!supabase) error(503, 'Service unavailable');

	const { data: profile } = await supabase
		.from('public_profiles')
		.select('id, display_name, handle, avatar_url, bio, platform_handles, role')
		.eq('handle', params.handle)
		.in('role', ['advertiser', 'manager'])
		.maybeSingle();

	if (!profile) error(404, 'Profile not found');

	// Org affiliation, if any — same two-query pattern as /org/[handle] (public_org_roster is a view
	// with no real FK to embed against; see that route's header comment for the full reasoning),
	// scoped by user_id instead of org_id this time. `.limit(1)` rather than `.maybeSingle()`: the
	// schema doesn't hard-block a user having active rows in >1 org (see orgs.sql's non-goals note),
	// so a query expecting exactly 0-1 rows would throw instead of just featuring one, same "v1
	// features the first active row" simplification as /settings/org.
	const { data: membershipRows } = await supabase
		.from('public_org_roster')
		.select('org_id, role')
		.eq('user_id', profile.id)
		.limit(1);
	const membershipRow = membershipRows?.[0] ?? null;

	let org: any = null;
	if (membershipRow) {
		const { data } = await supabase
			.from('public_orgs')
			.select('id, name, handle, avatar_url')
			.eq('id', membershipRow.org_id)
			.maybeSingle();
		org = data ? { ...data, memberRole: membershipRow.role } : null;
	}

	return { profile, org };
};
