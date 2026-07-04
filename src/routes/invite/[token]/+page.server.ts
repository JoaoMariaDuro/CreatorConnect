import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

// Public, no-auth-required landing page for an org invite link (org-invites.sql /
// rpc-org-invites.sql). get_org_invite_info() is a security-definer RPC granted to anon — never a
// view — specifically so the raw `token` column of org_invite_tokens is never bulk-selectable
// (the enumeration risk a view would reopen).
//
// 404 only for a token that never existed at all. A real-but-expired/used/revoked token still
// renders — the page shows its own "this invite has expired" state — since the only fact leaked
// either way is the org's already-public name/handle, and a real 404 would be worse UX for someone
// who legitimately had a link that simply ran out.
export const load: PageServerLoad = async ({ params, locals: { safeGetSession, supabase } }) => {
	if (!supabase) error(503, 'Service unavailable');

	const { data: rows, error: rpcError } = await supabase.rpc('get_org_invite_info', {
		p_token: params.token
	});
	if (rpcError) error(500, rpcError.message);

	const invite = (rows ?? [])[0];
	if (!invite) error(404, 'Invite not found');

	const { user } = await safeGetSession();
	let profile: { role: string; display_name: string } | null = null;
	if (user) {
		const { data } = await supabase
			.from('profiles')
			.select('role, display_name')
			.eq('id', user.id)
			.maybeSingle();
		profile = data;
	}

	return { invite, token: params.token, userId: user?.id ?? null, profile };
};
