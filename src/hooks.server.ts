import { createServerClient } from '@supabase/ssr';
import { redirect, type Handle } from '@sveltejs/kit';
import { PUBLIC_SUPABASE_ANON_KEY, PUBLIC_SUPABASE_URL } from '$env/static/public';

const PUBLIC_PATHS = ['/login', '/auth/callback'];

export const handle: Handle = async ({ event, resolve }) => {
	event.locals.supabase = createServerClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY, {
		cookies: {
			getAll: () => event.cookies.getAll(),
			setAll: (cookies) =>
				cookies.forEach(({ name, value, options }) =>
					event.cookies.set(name, value, { ...options, path: '/' })
				)
		}
	});

	// getUser() validates the JWT with Supabase instead of trusting the cookie.
	event.locals.safeGetSession = async () => {
		const {
			data: { user },
			error
		} = await event.locals.supabase.auth.getUser();
		if (error || !user) return { session: null, user: null };
		const {
			data: { session }
		} = await event.locals.supabase.auth.getSession();
		return { session, user };
	};

	const { user } = await event.locals.safeGetSession();
	event.locals.user = user;
	event.locals.profile = null;

	if (user) {
		const { data } = await event.locals.supabase
			.from('profiles')
			.select('id, email, full_name, role, approved')
			.eq('id', user.id)
			.single();
		event.locals.profile = data;
	}

	const path = event.url.pathname;
	const isPublic = PUBLIC_PATHS.some((p) => path.startsWith(p));

	if (!user && !isPublic) redirect(303, '/login');
	if (user && !event.locals.profile?.approved && !isPublic && path !== '/pending' && path !== '/logout') {
		redirect(303, '/pending');
	}
	if (user && event.locals.profile?.approved && (path === '/login' || path === '/pending')) {
		redirect(303, '/');
	}

	return resolve(event, {
		filterSerializedResponseHeaders: (name) => name === 'content-range' || name === 'x-supabase-api-version'
	});
};
