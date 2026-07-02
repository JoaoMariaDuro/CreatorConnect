<script lang="ts">
	import { page } from '$app/state';
</script>

<svelte:head>
	<title>{page.status} — CreatorConnect</title>
</svelte:head>

<div class="container error-page">
	<span class="code">{page.status}</span>
	<h1>{page.error?.message ?? 'Something went wrong'}</h1>
	<p class="muted">
		{#if page.status === 404}
			The page you're looking for doesn't exist, or the listing may have been removed.
		{:else}
			An unexpected error occurred. If this keeps happening, it's worth a bug report.
		{/if}
	</p>
	<div class="row">
		<a class="btn btn-primary" href="/">Go home</a>
		<a class="btn" href="/browse">Browse listings</a>
	</div>
</div>

<style>
	.error-page {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		justify-content: center;
		min-height: 70vh;
		max-width: 480px;
	}
	.code {
		font-size: 14px;
		font-weight: 700;
		letter-spacing: 0.05em;
		color: var(--accent-dark);
		background: var(--accent-bg);
		padding: 4px 10px;
		border-radius: 999px;
		margin-bottom: 16px;
	}
	h1 {
		font-size: 28px;
		margin: 0 0 10px;
	}
</style>
