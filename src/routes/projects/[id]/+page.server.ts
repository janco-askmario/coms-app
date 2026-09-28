import { error, fail, redirect } from '@sveltejs/kit';
import { loadPeople, saveProject } from '$lib/server/projects';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, params }) => {
	const [project, splits, log, people] = await Promise.all([
		locals.supabase.from('project_summary').select('*').eq('id', params.id).maybeSingle(),
		locals.supabase.from('project_members').select('user_id, split_pct').eq('project_id', params.id),
		locals.supabase
			.from('deadline_changes')
			.select('old_deadline, new_deadline, changed_at, profiles(full_name, email)')
			.eq('project_id', params.id)
			.order('changed_at', { ascending: false }),
		loadPeople(locals)
	]);
	if (!project.data) error(404, 'Project not found or you do not have access');
	const changes = (log.data ?? []).map((l) => {
		const by = (Array.isArray(l.profiles) ? l.profiles[0] : l.profiles) as { full_name: string | null; email: string } | null;
		return { ...l, by: by?.full_name ?? by?.email ?? 'unknown' };
	});
	return { project: project.data, splits: splits.data ?? [], log: changes, people };
};

export const actions: Actions = {
	save: (event) => saveProject(event, event.params.id),
	delete: async ({ locals, params }) => {
		const { error: e } = await locals.supabase.from('projects').delete().eq('id', params.id);
		if (e) return fail(400, { message: e.message });
		redirect(303, '/');
	}
};
