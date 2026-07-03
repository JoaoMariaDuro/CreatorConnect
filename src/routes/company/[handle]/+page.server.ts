import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

// Public, no-auth company page — reads through public_companies (a view, owner-privileged by
// Postgres default) rather than the base `companies` table, whose RLS only grants active-member
// self-reads. An anonymous request against the base table would silently return zero rows here, not
// an error — the same bug class already fixed once this session for profiles embeds (commit d0990b8).
//
// The roster is deliberately TWO separate queries, not one embedded query: public_company_roster
// (supabase/companies.sql) is a VIEW over company_members, not a base table, so it carries no real
// foreign-key constraint PostgREST could resolve a `!constraint_name` embed against. Every other
// public_*-view embed in this codebase (e.g. public_profiles) is sourced from a real table with a
// real FK — this is different, so it gets the guaranteed-correct two-round-trip treatment instead of
// an untested embed.
export const load: PageServerLoad = async ({ params, locals: { supabase } }) => {
	if (!supabase) error(503, 'Service unavailable');

	const { data: company } = await supabase
		.from('public_companies')
		.select('id, name, handle, avatar_url, bio, niche_tags, platform_handles, company_type, created_at')
		.eq('handle', params.handle)
		.maybeSingle();

	if (!company) error(404, 'Company not found');

	const { data: rosterRows } = await supabase
		.from('public_company_roster')
		.select('user_id, role, joined_at')
		.eq('company_id', company.id)
		.order('joined_at', { ascending: true });

	const userIds = (rosterRows ?? []).map((r) => r.user_id);
	let members: any[] = [];
	if (userIds.length) {
		const { data: profiles } = await supabase
			.from('public_profiles')
			.select('id, display_name, handle, avatar_url, niche_tags, follower_count')
			.in('id', userIds);
		const profileById = new Map((profiles ?? []).map((p) => [p.id, p]));
		members = (rosterRows ?? [])
			.map((r) => ({ ...r, profile: profileById.get(r.user_id) }))
			.filter((r) => r.profile);
	}

	// Represented creators (company-showcase.sql) — manager/agency companies only, and only rows
	// both sides consented to (public_company_showcase already filters to status = 'accepted'). Same
	// two-query pattern as the roster above, for the same reason: the view has no real FK to embed
	// against.
	let representedCreators: any[] = [];
	if (company.company_type === 'manager') {
		const { data: showcaseRows } = await supabase
			.from('public_company_showcase')
			.select('creator_id')
			.eq('company_id', company.id);
		const creatorIds = (showcaseRows ?? []).map((r) => r.creator_id);
		if (creatorIds.length) {
			const { data: creatorProfiles } = await supabase
				.from('public_profiles')
				.select('id, display_name, handle, avatar_url, niche_tags, follower_count, completed_deals_count')
				.in('id', creatorIds);
			representedCreators = creatorProfiles ?? [];
		}
	}

	return { company, members, representedCreators };
};
