import { fail, redirect, type RequestEvent } from '@sveltejs/kit';

export async function loadPeople(locals: App.Locals) {
	const { data } = await locals.supabase
		.from('profiles')
		.select('id, email, full_name')
		.eq('approved', true)
		.order('full_name');
	return data ?? [];
}

export async function saveProject({ request, locals }: RequestEvent, id: string | null) {
	const f = await request.formData();
	const get = (k: string) => String(f.get(k) ?? '').trim();

	const project = {
		name: get('name'),
		client: get('client'),
		price: Number(get('price') || 0),
		commission_pct: Number(get('commission_pct') || 0),
		start_date: get('start_date'),
		deadline: get('deadline'),
		completed_date: get('completed_date'),
		status: get('status') || 'lead',
		notes: get('notes'),
		// Only sent for admins; the DB rejects it for anyone else.
		...(locals.profile?.role === 'admin' ? { overdue_waived: f.get('overdue_waived') === 'on' } : {})
	};

	let splits: { user_id: string; split_pct: number }[] = [];
	try {
		splits = JSON.parse(get('splits') || '[]');
	} catch {
		return fail(400, { message: 'Invalid splits' });
	}

	if (!project.name) return fail(400, { message: 'Project name is required' });
	if (!project.start_date || !project.deadline) return fail(400, { message: 'Start date and deadline are required' });
	if (project.deadline < project.start_date) return fail(400, { message: 'Deadline must be on or after the start date' });
	const total = splits.reduce((t, s) => t + Number(s.split_pct), 0);
	if (Math.abs(total - 100) > 0.001) return fail(400, { message: `Splits must add up to 100% (currently ${total}%)` });

	const { data, error } = await locals.supabase.rpc('save_project', {
		p_id: id,
		p_project: project,
		p_splits: splits
	});
	if (error) return fail(400, { message: error.message });
	redirect(303, `/projects/${data}`);
}
