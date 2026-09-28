<script lang="ts">
	import ProjectForm from '$lib/components/ProjectForm.svelte';
	let { data, form } = $props();
</script>

<h1>New project</h1>
<ProjectForm
	people={data.people}
	isAdmin={data.profile?.role === 'admin'}
	currentUserId={data.profile!.id}
	message={form?.message}
/>
