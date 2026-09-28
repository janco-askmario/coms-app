import { redirect } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ url, locals }) => {
	const code = url.searchParams.get('code');
	const oauthError = url.searchParams.get('error_description');

	if (oauthError) {
		// Most commonly: the domain-check trigger rejected a non-askmario account.
		redirect(303, `/login?error=${encodeURIComponent('Only @askmario.co.za accounts can sign in.')}`);
	}
	if (code) {
		const { error } = await locals.supabase.auth.exchangeCodeForSession(code);
		if (error) redirect(303, `/login?error=${encodeURIComponent(error.message)}`);
	}
	redirect(303, '/');
};
