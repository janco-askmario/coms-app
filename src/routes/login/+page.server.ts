import { fail, redirect } from '@sveltejs/kit';
import type { Actions } from './$types';

export const actions: Actions = {
	google: async ({ locals, url }) => {
		const { data, error } = await locals.supabase.auth.signInWithOAuth({
			provider: 'google',
			options: {
				redirectTo: `${url.origin}/auth/callback`,
				// Hint Google to only show askmario.co.za accounts (the DB trigger enforces it).
				queryParams: { hd: 'askmario.co.za', prompt: 'select_account' }
			}
		});
		if (error || !data.url) return fail(500, { message: error?.message ?? 'Could not start sign-in' });
		redirect(303, data.url);
	}
};
