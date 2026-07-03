import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

// Real user-facing settings/profile page — previously this route was admin-only (just the
// test-role-switcher). Any signed-in user can edit their own profile here; the role-switcher card
// stays on the page but renders conditionally on profile.is_platform_admin (see +page.svelte).
export const load: PageServerLoad = async ({ parent }) => {
	const { user, profile } = await parent();

	if (!user) {
		redirect(303, '/login');
	}

	return { profile };
};
