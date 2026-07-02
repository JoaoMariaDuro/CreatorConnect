import { redirect } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';

// Gate the whole /admin subtree on profiles.is_platform_admin. The founder is already
// authenticated by the time they'd hit this route, so an unauthorized visit (including no
// session at all) bounces to /dashboard rather than /login — /dashboard's own +page.server.ts
// already redirects unauthenticated users to /login, so we don't duplicate that logic here.
export const load: LayoutServerLoad = async ({ parent }) => {
	const { profile } = await parent();

	if (!profile?.is_platform_admin) {
		redirect(303, '/dashboard');
	}

	return {};
};
