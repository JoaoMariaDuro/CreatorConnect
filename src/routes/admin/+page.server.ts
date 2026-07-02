import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

// /admin has no page of its own — it exists purely to send the founder to the disputes queue.
export const load: PageServerLoad = async () => {
	redirect(303, '/admin/disputes');
};
