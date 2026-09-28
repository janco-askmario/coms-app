<script lang="ts">
	import { page } from '$app/state';
	let { form } = $props();
	const error = $derived(form?.message ?? page.url.searchParams.get('error'));
</script>

<div class="center">
	<div class="card narrow">
		<h1>AskMario Commissions</h1>
		<p class="muted">Sign in with your @askmario.co.za Google account.</p>
		{#if error}<p class="error">{error}</p>{/if}
		<form method="POST" action="?/google">
			<button class="primary wide">Continue with Google</button>
		</form>
	</div>
</div>
