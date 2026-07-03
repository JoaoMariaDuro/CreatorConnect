import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

// Company roster management — advertisers and managers only (creators have no company affiliation
// per the founder's decision). Mirrors settings/managers/+page.server.ts's role gate and shape.
export const load: PageServerLoad = async ({ locals: { safeGetSession, supabase } }) => {
	const { user } = await safeGetSession();
	if (!user || !supabase) redirect(303, '/login');

	const { data: profile } = await supabase.from('profiles').select('*').eq('id', user.id).maybeSingle();
	if (!profile || (profile.role !== 'advertiser' && profile.role !== 'manager')) {
		return { profile, memberships: [] as any[], roster: [] as any[] };
	}

	// Self-read on company_members (RLS's "user_id = auth.uid()" clause covers this regardless of
	// status), embedding public_companies via the real company_members_company_id_fkey constraint —
	// same proven-safe pattern already used throughout this codebase (source is a real table with a
	// real FK; only embeds sourced from a VIEW are unsafe, see the roster query below).
	const { data } = await supabase
		.from('company_members')
		.select(
			'id, role, status, invited_at, joined_at, revoked_at, company:public_companies!company_members_company_id_fkey (id, name, handle, avatar_url, bio, company_type)'
		)
		.eq('user_id', user.id)
		.order('created_at', { ascending: false });

	const memberships = (data ?? []) as any[];

	// For the currently-featured active company (first active membership, if any — v1 assumes one),
	// also load its full roster. This is an authenticated read of the caller's OWN active company, so
	// it's allowed to embed public_profiles directly off the base company_members table (RLS's
	// is_active_company_member(company_id) clause permits it) — no need for the anonymous-safe
	// two-query pattern the public pages use.
	const activeMembership = memberships.find((m) => m.status === 'active');
	let roster: any[] = [];
	let myRepresentedCreators: any[] = [];
	let showcased: any[] = [];
	if (activeMembership) {
		const { data: rosterData } = await supabase
			.from('company_members')
			.select(
				'id, role, status, invited_at, joined_at, member:public_profiles!company_members_user_id_fkey (id, display_name, handle, avatar_url)'
			)
			.eq('company_id', activeMembership.company.id)
			.order('created_at', { ascending: false });
		roster = rosterData ?? [];

		// Showcase (dual-consent public roster of represented creators) — manager/agency companies
		// only. "My represented creators" is scoped to the CALLER's own manager_creator_links, not the
		// whole company's, because propose_showcase_creator() only lets a member propose a creator
		// they personally have the real delegated relationship with (company-showcase.sql's design).
		if (activeMembership.company.company_type === 'manager') {
			const { data: linked } = await supabase
				.from('manager_creator_links')
				.select('creator:public_profiles!manager_creator_links_creator_id_fkey (id, display_name, handle)')
				.eq('manager_id', user.id)
				.eq('status', 'active');
			myRepresentedCreators = (linked ?? []).map((l: any) => l.creator).filter(Boolean);

			const { data: showcaseData } = await supabase
				.from('company_showcased_creators')
				.select('id, creator_id, status, proposed_at, responded_at, creator:public_profiles!company_showcased_creators_creator_id_fkey (id, display_name, handle)')
				.eq('company_id', activeMembership.company.id)
				.order('proposed_at', { ascending: false });
			showcased = showcaseData ?? [];
		}
	}

	return { profile, memberships, roster, myRepresentedCreators, showcased };
};
