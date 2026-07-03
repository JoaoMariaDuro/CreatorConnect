import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

// This page currently has one purpose: let a platform admin switch their own `role` to test all
// three role-differentiated experiences from a single account (see set_own_test_role_as_admin,
// rpc-admin.sql). There's nothing here for a non-admin yet, so bounce to /dashboard rather than
// building a stub — same "already authenticated, just unauthorized" redirect target used by
// src/routes/admin/+layout.server.ts.
export const load: PageServerLoad = async ({ parent }) => {
	const { profile } = await parent();

	if (!profile?.is_platform_admin) {
		redirect(303, '/dashboard');
	}

	return { profile };
};
