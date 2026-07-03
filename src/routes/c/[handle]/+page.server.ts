import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

// Public, no-auth media-kit page — a shareable "drop this in your bio" link (Handoff #4's proposal,
// still unbuilt until now). Deliberately reads through `public_profiles` (schema.sql), not the base
// `profiles` table: the base table's RLS only grants a "read own row" policy, so an anonymous request
// (no auth.uid() at all) would get zero rows from it. `public_profiles` is a plain view, which by
// Postgres default (security_invoker = false) runs with the view owner's privileges against the
// underlying table — that's what makes it safely selectable by anyone, not a workaround.
export const load: PageServerLoad = async ({ params, locals: { supabase } }) => {
	if (!supabase) error(503, 'Service unavailable');

	const { data: creator } = await supabase
		.from('public_profiles')
		.select('id, display_name, handle, avatar_url, niche_tags, follower_count, completed_deals_count, role')
		.eq('handle', params.handle)
		.eq('role', 'creator')
		.maybeSingle();

	if (!creator) error(404, 'Creator not found');

	// Currently bookable slots — same "status <> 'draft'" visibility any advertiser already gets on
	// /browse, just pre-filtered to this one creator and to 'open' specifically (a reserved/pending/deal
	// listing isn't something a new visitor can actually book).
	const { data: listings } = await supabase
		.from('creator_listings')
		.select('id, platform, content_type, availability_window, pricing_mechanism')
		.eq('creator_id', creator.id)
		.eq('status', 'open')
		.order('created_at', { ascending: false });

	// Most recently reported performance stats across any of this creator's non-draft listings — not
	// just open ones, since a creator mid-deal or between listings still has real stats worth showing.
	// performance_stats lives per-listing (supabase/listings.sql), not on profiles, so this is a
	// best-effort "freshest available" pick, same staleness thresholds as the listing detail page.
	const { data: statsSource } = await supabase
		.from('creator_listings')
		.select('performance_stats, performance_stats_updated_at')
		.eq('creator_id', creator.id)
		.neq('status', 'draft')
		.not('performance_stats_updated_at', 'is', null)
		.order('performance_stats_updated_at', { ascending: false })
		.limit(1)
		.maybeSingle();

	return {
		creator,
		listings: listings ?? [],
		stats: statsSource ?? null
	};
};
