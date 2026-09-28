<script lang="ts">
	import { enhance } from '$app/forms';
	import { untrack } from 'svelte';
	import { money, personName, STATUSES } from '$lib/format';

	type Person = { id: string; email: string; full_name: string | null };
	type Split = { user_id: string; split_pct: number };

	let {
		project = null,
		initialSplits = [],
		people,
		isAdmin,
		currentUserId,
		message = null,
		action = undefined
	}: {
		project?: Record<string, any> | null;
		initialSplits?: Split[];
		people: Person[];
		isAdmin: boolean;
		currentUserId: string;
		message?: string | null;
		action?: string;
	} = $props();

	const today = new Date().toISOString().slice(0, 10);

	// Form starts from the saved values; the parent remounts it (via {#key}) after a save.
	let price = $state(untrack(() => Number(project?.price ?? 0)));
	let pct = $state(untrack(() => Number(project?.commission_pct ?? 10)));
	let splits = $state<Split[]>(
		untrack(() =>
			initialSplits.length
				? initialSplits.map((s) => ({ ...s, split_pct: Number(s.split_pct) }))
				: [{ user_id: currentUserId, split_pct: 100 }]
		)
	);
	let adding = $state('');
	let saving = $state(false);

	const pool = $derived((price * pct) / 100);
	const total = $derived(splits.reduce((t, s) => t + (Number(s.split_pct) || 0), 0));
	const valid = $derived(splits.length > 0 && Math.abs(total - 100) < 0.001);
	const available = $derived(people.filter((p) => !splits.some((s) => s.user_id === p.id)));
	const nameOf = (id: string) => {
		const p = people.find((x) => x.id === id);
		return p ? personName(p) : 'Unknown';
	};

	function add() {
		if (!adding) return;
		splits.push({ user_id: adding, split_pct: 0 });
		adding = '';
	}
	function evenSplit() {
		const n = splits.length;
		if (!n) return;
		const base = Math.floor((100 / n) * 100) / 100;
		splits.forEach((s, i) => (s.split_pct = i === n - 1 ? +(100 - base * (n - 1)).toFixed(2) : base));
	}
</script>

<form
	method="POST"
	{action}
	use:enhance={() => {
		saving = true;
		return async ({ update }) => {
			await update({ reset: false });
			saving = false;
		};
	}}
>
	{#if message}<p class="error card">{message}</p>{/if}

	<section class="card">
		<h2>Project details</h2>
		<div class="grid">
			<label>Project name<input name="name" required value={project?.name ?? ''} /></label>
			<label>Client<input name="client" value={project?.client ?? ''} /></label>
			<label>Status
				<select name="status" value={project?.status ?? 'lead'}>
					{#each STATUSES as s}<option value={s.value}>{s.label}</option>{/each}
				</select>
			</label>
		</div>
		<div class="grid" style="margin-top:14px">
			<label>Start date<input type="date" name="start_date" required value={project?.start_date ?? today} /></label>
			<label>Deadline<input type="date" name="deadline" required value={project?.deadline ?? ''} /></label>
			<label>Completed on <span class="small">(set automatically when marked Completed)</span>
				<input type="date" name="completed_date" value={project?.completed_date ?? ''} />
			</label>
		</div>
		<label style="margin-top:14px">Notes<textarea name="notes" rows="2">{project?.notes ?? ''}</textarea></label>
		{#if isAdmin}
			<label style="margin-top:14px; display:flex; gap:8px; align-items:center; color:var(--text)">
				<input type="checkbox" name="overdue_waived" checked={project?.overdue_waived ?? false} style="width:auto" />
				Waive overdue rule (admin): commission still counts even if the deadline was missed
			</label>
		{/if}
	</section>

	<section class="card">
		<h2>Commission</h2>
		<div class="grid">
			<label>Project price (ZAR)<input type="number" name="price" min="0" step="0.01" bind:value={price} /></label>
			<label>Our commission (%)<input type="number" name="commission_pct" min="0" max="100" step="0.01" bind:value={pct} /></label>
			<div class="stat"><div class="muted small">Commission pool</div><div class="v">{money(pool)}</div></div>
		</div>

		<h2 style="margin-top:20px">Split between people</h2>
		<div class="table-wrap">
			<table>
				<thead><tr><th>Person</th><th class="num">Share of commission</th><th class="num">Payout</th><th></th></tr></thead>
				<tbody>
					{#each splits as s, i (s.user_id)}
						<tr>
							<td>{nameOf(s.user_id)}</td>
							<td class="num"><input type="number" min="0" max="100" step="0.01" bind:value={s.split_pct} style="width:110px; text-align:right" /> %</td>
							<td class="num"><strong>{money((pool * (Number(s.split_pct) || 0)) / 100)}</strong></td>
							<td class="right"><button type="button" class="link danger" onclick={() => splits.splice(i, 1)}>Remove</button></td>
						</tr>
					{/each}
					<tr>
						<td><strong>Total</strong></td>
						<td class="num"><span class="badge {valid ? 'ok' : 'bad'}">{+total.toFixed(2)}%</span></td>
						<td class="num"><strong>{money((pool * total) / 100)}</strong></td>
						<td></td>
					</tr>
				</tbody>
			</table>
		</div>

		<div style="display:flex; gap:8px; margin-top:12px; flex-wrap:wrap">
			<select bind:value={adding} style="max-width:260px">
				<option value="">Add a person…</option>
				{#each available as p}<option value={p.id}>{personName(p)}</option>{/each}
			</select>
			<button type="button" onclick={add} disabled={!adding}>Add</button>
			<button type="button" onclick={evenSplit} disabled={!splits.length}>Split evenly</button>
		</div>
		{#if !valid}<p class="error small">Splits must add up to exactly 100% before you can save.</p>{/if}
		<p class="muted small">Projects completed after their deadline earn no commission.</p>

		<input type="hidden" name="splits" value={JSON.stringify(splits)} />
	</section>

	<div style="display:flex; gap:8px">
		<button class="primary" disabled={!valid || saving}>{saving ? 'Saving…' : 'Save project'}</button>
		<a class="button" href={project ? `/projects/${project.id}` : '/'}>Cancel</a>
	</div>
</form>
