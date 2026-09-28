<script lang="ts">
	import { statusLabel } from '$lib/format';
	let { project }: { project: { status: string; is_overdue: boolean; due_soon: boolean; overdue_waived: boolean } } = $props();
	const cls = $derived(project.status === 'paid' ? 'ok' : project.status === 'cancelled' ? 'bad' : '');
</script>

<span class="badge {cls}">{statusLabel(project.status)}</span>
{#if project.is_overdue}
	<span class="badge bad" title="Past deadline, so no commission is earned">Overdue · R0</span>
{:else if project.due_soon}
	<span class="badge warn" title="Deadline within 7 days. Commission is lost if it's missed">Due soon</span>
{/if}
{#if project.overdue_waived}<span class="badge" title="Admin waived the overdue rule">Waived</span>{/if}
