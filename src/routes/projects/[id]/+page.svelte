<script lang="ts">
	import ProjectForm from '$lib/components/ProjectForm.svelte';
	import StatusBadge from '$lib/components/StatusBadge.svelte';
	import { date } from '$lib/format';
	let { data, form } = $props();
	const isAdmin = $derived(data.profile?.role === 'admin');
</script>

<p><a href="/">← All projects</a></p>
<div style="display:flex; justify-content:space-between; align-items:center; gap:12px; flex-wrap:wrap">
	<h1>{data.project.name} <StatusBadge project={data.project} /></h1>
	{#if isAdmin}
		<form method="POST" action="?/delete" onsubmit={(e) => { if (!confirm('Delete this project permanently?')) e.preventDefault(); }}>
			<button class="danger">Delete project</button>
		</form>
	{/if}
</div>

{#if data.project.is_overdue}
	<p class="card" style="border-color:var(--bad); color:var(--bad)">
		This project missed its deadline ({date(data.project.deadline)}), so it earns no commission.
		{isAdmin ? 'You can waive this below if the delay was out of our control.' : 'Ask an admin if the delay was out of our control.'}
	</p>
{/if}

{#key data.project.updated_at}
	<ProjectForm
		project={data.project}
		initialSplits={data.splits}
		people={data.people}
		{isAdmin}
		currentUserId={data.profile!.id}
		message={form?.message}
		action="?/save"
	/>
{/key}

{#if data.log.length}
	<section class="card" style="margin-top:20px">
		<h2>Deadline changes</h2>
		{#each data.log as l}
			<div class="small">
				{date(l.old_deadline)} → <strong>{date(l.new_deadline)}</strong>
				<span class="muted">by {l.by} on {new Date(l.changed_at).toLocaleString('en-ZA')}</span>
			</div>
		{/each}
	</section>
{/if}
