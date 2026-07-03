import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

// Public, no-auth org page — reads through public_orgs (a view, owner-privileged by Postgres
// default) rather than the base `orgs` table, whose RLS only grants active-member self-reads. An
// anonymous request against the base table would silently return zero rows here, not an error — the
// same bug class already fixed once this session for profiles embeds (commit d0990b8).
//
// The roster is deliberately TWO separate queries, not one embedded query: public_org_roster
// (supabase/orgs.sql) is a VIEW over org_members, not a base table, so it carries no real
// foreign-key constraint PostgREST could resolve a `!constraint_name` embed against. Every other
// public_*-view embed in this codebase (e.g. public_profiles) is sourced from a real table with a
// real FK — this is different, so it gets the guaranteed-correct two-round-trip treatment instead of
// an untested embed.
export const load: PageServerLoad = async ({ params, locals: { supabase } }) => {
	if (!supabase) error(503, 'Service unavailable');

	const { data: org } = await supabase
		.from('public_orgs')
		.select('id, name, handle, avatar_url, bio, niche_tags, platform_handles, org_type, created_at')
		.eq('handle', params.handle)
		.maybeSingle();

	if (!org) error(404, 'Org not found');

	const { data: rosterRows } = await supabase
		.from('public_org_roster')
		.select('user_id, role, joined_at')
		.eq('org_id', org.id)
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

	// Represented creators (org-showcase.sql) — manager/agency orgs only, and only rows both sides
	// consented to (public_org_showcase already filters to status = 'accepted'). Same two-query
	// pattern as the roster above, for the same reason: the view has no real FK to embed against.
	let representedCreators: any[] = [];
	if (org.org_type === 'manager') {
		const { data: showcaseRows } = await supabase
			.from('public_org_showcase')
			.select('creator_id')
			.eq('org_id', org.id);
		const creatorIds = (showcaseRows ?? []).map((r) => r.creator_id);
		if (creatorIds.length) {
			const { data: creatorProfiles } = await supabase
				.from('public_profiles')
				.select('id, display_name, handle, avatar_url, niche_tags, follower_count, completed_deals_count')
				.in('id', creatorIds);
			representedCreators = creatorProfiles ?? [];
		}
	}

	return { org, members, representedCreators };
};
