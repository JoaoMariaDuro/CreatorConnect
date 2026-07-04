import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

// Old URL, from before the company->org rename. Kept as a redirect stub, not deleted outright, so
// any stale bookmark/tab/link from before the rename still lands somewhere real instead of a 404.
export const load: PageServerLoad = async () => {
	redirect(301, '/settings/org');
};
