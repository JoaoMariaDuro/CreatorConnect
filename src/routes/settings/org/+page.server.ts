import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

// Org roster management — advertisers and managers only (creators have no org affiliation per the
// founder's decision). Mirrors settings/managers/+page.server.ts's role gate and shape.
export const load: PageServerLoad = async ({ locals: { safeGetSession, supabase } }) => {
	const { user } = await safeGetSession();
	if (!user || !supabase) redirect(303, '/login');

	const { data: profile } = await supabase.from('profiles').select('*').eq('id', user.id).maybeSingle();
	if (!profile || (profile.role !== 'advertiser' && profile.role !== 'manager')) {
		return { profile, memberships: [] as any[], roster: [] as any[] };
	}

	// Self-read on org_members (RLS's "user_id = auth.uid()" clause covers this regardless of
	// status), embedding public_orgs via the real org_members_org_id_fkey constraint — same
	// proven-safe pattern already used throughout this codebase (source is a real table with a real
	// FK; only embeds sourced from a VIEW are unsafe, see the roster query below).
	const { data } = await supabase
		.from('org_members')
		.select(
			'id, role, status, invited_at, joined_at, revoked_at, org:public_orgs!org_members_org_id_fkey (id, name, handle, avatar_url, bio, org_type)'
		)
		.eq('user_id', user.id)
		.order('created_at', { ascending: false });

	const memberships = (data ?? []) as any[];

	// For the currently-featured active org (first active membership, if any — v1 assumes one), also
	// load its full roster. This is an authenticated read of the caller's OWN active org, so it's
	// allowed to embed public_profiles directly off the base org_members table (RLS's
	// is_active_org_member(org_id) clause permits it) — no need for the anonymous-safe two-query
	// pattern the public pages use.
	const activeMembership = memberships.find((m) => m.status === 'active');
	let roster: any[] = [];
	let myRepresentedCreators: any[] = [];
	let showcased: any[] = [];
	if (activeMembership) {
		const { data: rosterData } = await supabase
			.from('org_members')
			.select(
				'id, role, status, invited_at, joined_at, member:public_profiles!org_members_user_id_fkey (id, display_name, handle, avatar_url)'
			)
			.eq('org_id', activeMembership.org.id)
			.order('created_at', { ascending: false });
		roster = rosterData ?? [];

		// Showcase (dual-consent public roster of represented creators) — manager/agency orgs only.
		// "My represented creators" is scoped to the CALLER's own manager_creator_links, not the whole
		// org's, because propose_showcase_creator() only lets a member propose a creator they
		// personally have the real delegated relationship with (org-showcase.sql's design).
		if (activeMembership.org.org_type === 'manager') {
			const { data: linked } = await supabase
				.from('manager_creator_links')
				.select('creator:public_profiles!manager_creator_links_creator_id_fkey (id, display_name, handle)')
				.eq('manager_id', user.id)
				.eq('status', 'active');
			myRepresentedCreators = (linked ?? []).map((l: any) => l.creator).filter(Boolean);

			const { data: showcaseData } = await supabase
				.from('org_showcased_creators')
				.select('id, creator_id, status, proposed_at, responded_at, creator:public_profiles!org_showcased_creators_creator_id_fkey (id, display_name, handle)')
				.eq('org_id', activeMembership.org.id)
				.order('proposed_at', { ascending: false });
			showcased = showcaseData ?? [];
		}
	}

	return { profile, memberships, roster, myRepresentedCreators, showcased };
};
