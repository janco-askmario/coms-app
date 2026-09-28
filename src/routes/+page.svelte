<script lang="ts">
	import StatusBadge from '$lib/components/StatusBadge.svelte';
	import { date, money, personName, STATUSES } from '$lib/format';
	let { data } = $props();

	let filter = $state<string>('open');

	const visible = $derived(
		data.projects.filter((p) =>
			filter === 'all' ? true
			: filter === 'open' ? ['lead', 'active', 'on_hold'].includes(p.status)
			: filter === 'overdue' ? p.is_overdue
			: p.status === filter
		)
	);

	const payoutsByProject = $derived(
		Object.groupBy(data.payouts, (r) => r.project_id)
	);

	// Per-person totals: earned (completed + paid), paid out, and still in the pipeline.
	const people = $derived.by(() => {
		const map = new Map<string, { name: string; pipeline: number; earned: number; paid: number; lost: number }>();
		const byId = new Map(data.projects.map((p) => [p.id, p]));
		for (const r of data.payouts) {
			const p = byId.get(r.project_id);
			if (!p || p.status === 'cancelled') continue;
			const row = map.get(r.user_id) ?? { name: personName(r), pipeline: 0, earned: 0, paid: 0, lost: 0 };
			const payout = Number(r.payout);
			if (p.is_overdue) row.lost += Number(p.gross_commission) * Number(r.split_pct) / 100;
			else if (p.status === 'paid') { row.paid += payout; row.earned += payout; }
			else if (p.status === 'completed') row.earned += payout;
			else row.pipeline += payout;
			map.set(r.user_id, row);
		}
		return [...map.values()].sort((a, b) => a.name.localeCompare(b.name));
	});

	const sum = (k: 'pipeline' | 'earned' | 'paid' | 'lost') => people.reduce((t, p) => t + p[k], 0);
</script>

<div class="stats">
	<div class="stat"><div class="muted small">Open projects</div><div class="v">{data.projects.filter((p) => ['lead','active','on_hold'].includes(p.status)).length}</div></div>
	<div class="stat"><div class="muted small">Commission in pipeline</div><div class="v">{money(sum('pipeline'))}</div></div>
	<div class="stat"><div class="muted small">Earned (completed + paid)</div><div class="v">{money(sum('earned'))}</div></div>
	<div class="stat"><div class="muted small">Lost to overdue</div><div class="v" style="color:var(--bad)">{money(sum('lost'))}</div></div>
</div>

<section class="card">
	<h2>Projects</h2>
	<div class="tabs">
		{#each [{ value: 'open', label: 'Open' }, { value: 'overdue', label: 'Overdue' }, ...STATUSES, { value: 'all', label: 'All' }] as t}
			<button class:on={filter === t.value} onclick={() => (filter = t.value)}>{t.label}</button>
		{/each}
	</div>

	{#if visible.length === 0}
		<p class="muted">No projects here. <a href="/projects/new">Add one</a>.</p>
	{:else}
		<div class="table-wrap">
			<table>
				<thead>
					<tr>
						<th>Project</th><th>Status</th><th>Start</th><th>Deadline</th>
						<th class="num">Price</th><th class="num">Comm. %</th><th class="num">Commission</th>
						<th>Payout per person</th>
					</tr>
				</thead>
				<tbody>
					{#each visible as p (p.id)}
						<tr>
							<td><a href="/projects/{p.id}"><strong>{p.name}</strong></a>{#if p.client}<div class="muted small">{p.client}</div>{/if}</td>
							<td><StatusBadge project={p} /></td>
							<td>{date(p.start_date)}</td>
							<td>{date(p.deadline)}</td>
							<td class="num">{money(p.price)}</td>
							<td class="num">{Number(p.commission_pct)}%</td>
							<td class="num" class:strike={p.is_overdue || p.status === 'cancelled'}>{money(p.gross_commission)}</td>
							<td>
								{#each payoutsByProject[p.id] ?? [] as m}
									<div class="small">{personName(m)} <span class="muted">({Number(m.split_pct)}%)</span>: <strong>{money(m.payout)}</strong></div>
								{/each}
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
</section>

<section class="card">
	<h2>Total payout per person</h2>
	<div class="table-wrap">
		<table>
			<thead><tr><th>Person</th><th class="num">In pipeline</th><th class="num">Earned</th><th class="num">Paid out</th><th class="num">Lost to overdue</th></tr></thead>
			<tbody>
				{#each people as p}
					<tr><td>{p.name}</td><td class="num">{money(p.pipeline)}</td><td class="num"><strong>{money(p.earned)}</strong></td><td class="num">{money(p.paid)}</td><td class="num">{money(p.lost)}</td></tr>
				{:else}
					<tr><td colspan="5" class="muted">No commissions yet.</td></tr>
				{/each}
			</tbody>
		</table>
	</div>
</section>
