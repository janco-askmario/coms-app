<script lang="ts">
	import favicon from '$lib/assets/favicon.svg';
	import '../app.css';
	let { data, children } = $props();
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
	<title>AskMario Commissions</title>
</svelte:head>

{#if data.profile?.approved}
	<header>
		<a href="/" class="brand">AskMario Commissions</a>
		<nav>
			<a href="/projects/new" class="button primary">+ New project</a>
			<span class="muted small">{data.profile.full_name ?? data.profile.email}{data.profile.role === 'admin' ? ' · admin' : ''}</span>
			<form method="POST" action="/logout"><button class="link">Sign out</button></form>
		</nav>
	</header>
{/if}

<main>{@render children()}</main>
