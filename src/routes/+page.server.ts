import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals }) => {
	const [projects, payouts] = await Promise.all([
		locals.supabase.from('project_summary').select('*').order('deadline', { ascending: true }),
		locals.supabase.from('project_payouts').select('*')
	]);
	return { projects: projects.data ?? [], payouts: payouts.data ?? [] };
};
