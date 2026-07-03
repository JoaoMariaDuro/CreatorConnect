import type { PageServerLoad } from './$types';

// Admin-only read of the `feedback` table (supabase/feedback.sql) — FeedbackModal.svelte has been
// writing issue/idea reports here since it shipped, but there was never a route to read them back
// short of raw SQL. RLS already grants is_platform_admin() read access; this is a pure UI addition,
// same "admin-gated list over an existing table" shape as /admin/disputes.
export const load: PageServerLoad = async ({ locals: { supabase } }) => {
	if (!supabase) return { feedback: [] };

	const { data } = await supabase
		.from('feedback')
		.select('id, kind, message, page_path, created_at, submitter:public_profiles!feedback_user_id_fkey (display_name, role)')
		.order('created_at', { ascending: false });

	return { feedback: (data ?? []) as any[] };
};
