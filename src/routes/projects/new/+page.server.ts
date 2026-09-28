import { loadPeople, saveProject } from '$lib/server/projects';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals }) => ({ people: await loadPeople(locals) });

export const actions: Actions = { default: (event) => saveProject(event, null) };
