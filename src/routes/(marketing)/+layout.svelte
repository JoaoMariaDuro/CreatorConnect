<script lang="ts">
	import { page } from '$app/state';
	import { Sparkles, ArrowRight } from '@lucide/svelte';

	let { children } = $props();

	const user = $derived(page.data.user);

	let scrolled = $state(false);
	function onScroll() {
		scrolled = window.scrollY > 8;
	}
</script>

<svelte:window onscroll={onScroll} />

<div class="marketing">
	<header class="marketing-header" class:scrolled>
		<div class="marketing-header-inner">
			<a class="brand" href="/">
				<Sparkles size={19} />
				<span>CreatorConnect</span>
			</a>
			<nav class="marketing-nav" aria-label="Primary">
				<a href="/browse">Browse</a>
				<a href="/roadmap">Roadmap</a>
			</nav>
			<div class="marketing-actions">
				{#if user}
					<a class="btn btn-primary btn-sm" href="/dashboard">
						Dashboard <ArrowRight size={14} />
					</a>
				{:else}
					<a class="marketing-link" href="/login">Sign in</a>
					<a class="btn btn-primary btn-sm" href="/login">Get started</a>
				{/if}
			</div>
		</div>
	</header>

	<main class="marketing-main">
		{@render children()}
	</main>

	<footer class="marketing-footer">
		<div class="marketing-footer-inner">
			<a class="brand" href="/">
				<Sparkles size={16} />
				<span>CreatorConnect</span>
			</a>
			<nav class="marketing-footer-nav" aria-label="Footer">
				<a href="/browse">Browse listings</a>
				<a href="/roadmap">Roadmap</a>
				<a href="/login">Sign in</a>
			</nav>
			<span class="marketing-footer-copy muted">Booking marketplace for creator sponsorships.</span>
		</div>
	</footer>
</div>

<style>
	.marketing {
		display: flex;
		flex-direction: column;
		min-height: 100vh;
	}

	.marketing-header {
		position: sticky;
		top: 0;
		z-index: 60;
		background: rgba(14, 14, 16, 0.7);
		backdrop-filter: blur(10px);
		-webkit-backdrop-filter: blur(10px);
		border-bottom: 1px solid transparent;
		transition: border-color 0.2s, background 0.2s;
	}
	.marketing-header.scrolled {
		border-bottom-color: var(--border);
		background: rgba(14, 14, 16, 0.92);
	}
	.marketing-header-inner {
		max-width: 1180px;
		margin: 0 auto;
		padding: 14px 24px;
		display: flex;
		align-items: center;
		gap: 32px;
	}
	.brand {
		display: flex;
		align-items: center;
		gap: 8px;
		font-weight: 800;
		font-size: 15px;
		color: var(--text);
		flex-shrink: 0;
	}
	.brand:hover {
		text-decoration: none;
	}
	.marketing-nav {
		display: flex;
		align-items: center;
		gap: 24px;
		flex: 1;
	}
	.marketing-nav a {
		font-size: 14px;
		font-weight: 500;
		color: var(--text-muted);
	}
	.marketing-nav a:hover {
		color: var(--text);
		text-decoration: none;
	}
	.marketing-actions {
		display: flex;
		align-items: center;
		gap: 16px;
		flex-shrink: 0;
	}
	.marketing-link {
		font-size: 14px;
		font-weight: 500;
		color: var(--text-muted);
	}
	.marketing-link:hover {
		color: var(--text);
		text-decoration: none;
	}

	.marketing-main {
		flex: 1;
	}

	.marketing-footer {
		border-top: 1px solid var(--border);
		margin-top: 64px;
	}
	.marketing-footer-inner {
		max-width: 1180px;
		margin: 0 auto;
		padding: 28px 24px;
		display: flex;
		align-items: center;
		gap: 24px;
		flex-wrap: wrap;
	}
	.marketing-footer-nav {
		display: flex;
		gap: 20px;
		flex: 1;
	}
	.marketing-footer-nav a {
		font-size: 13px;
		color: var(--text-muted);
	}
	.marketing-footer-nav a:hover {
		color: var(--text);
	}
	.marketing-footer-copy {
		font-size: 13px;
	}

	@media (max-width: 640px) {
		.marketing-header-inner {
			padding: 12px 16px;
			gap: 16px;
		}
		.marketing-nav {
			display: none;
		}
		.marketing-footer-inner {
			flex-direction: column;
			align-items: flex-start;
			gap: 14px;
		}
	}
</style>
