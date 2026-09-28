<script lang="ts">
	let { data } = $props();
</script>

<div class="center">
	<div class="card narrow">
		<h1>Awaiting approval</h1>
		<p>
			You're signed in as <strong>{data.profile?.email}</strong>, but an admin still needs to approve
			your account. Check back once you've been approved.
		</p>
		<form method="POST" action="/logout"><button>Sign out</button></form>
	</div>
</div>
