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
	if (activeMembership) {
		const { data: rosterData } = await supabase
			.from('company_members')
			.select(
				'id, role, status, invited_at, joined_at, member:public_profiles!company_members_user_id_fkey (id, display_name, handle, avatar_url)'
			)
			.eq('company_id', activeMembership.company.id)
			.order('created_at', { ascending: false });
		roster = rosterData ?? [];
	}

	return { profile, memberships, roster };
};
