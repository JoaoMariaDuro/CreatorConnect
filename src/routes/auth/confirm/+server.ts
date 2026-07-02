import { redirect } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

// Where the magic link / signup confirmation lands. Supports both Supabase link shapes:
//   • code flow (default template, PKCE): ?code=…  → exchangeCodeForSession
//   • token-hash flow (custom template):  ?token_hash=…&type=…  → verifyOtp
// Pattern matches Lota's dashboard (../../../../lota/dashboard/src/routes/auth/confirm/+server.js).
export const GET: RequestHandler = async ({ url, locals: { supabase } }) => {
	const code = url.searchParams.get('code');
	const token_hash = url.searchParams.get('token_hash');
	const type = url.searchParams.get('type') as 'signup' | 'magiclink' | 'email' | null;
	const next = url.searchParams.get('next') ?? '/';

	if (supabase) {
		if (code) {
			const { error } = await supabase.auth.exchangeCodeForSession(code);
			if (!error) redirect(303, next);
		} else if (token_hash && type) {
			const { error } = await supabase.auth.verifyOtp({ type, token_hash });
			if (!error) redirect(303, next);
		}
	}
	redirect(303, '/login?error=expired');
};
