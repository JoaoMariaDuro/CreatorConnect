<script lang="ts">
	import { page } from '$app/state';
	import favicon from '$lib/assets/favicon.svg';
	import '$lib/app.css';
	import Sidebar from '$lib/Sidebar.svelte';
	import TopBar from '$lib/TopBar.svelte';
	import CompleteProfile from '$lib/CompleteProfile.svelte';

	let { children } = $props();

	const user = $derived(page.data.user);
	const profile = $derived(page.data.profile);
	const needsProfile = $derived(!!user && !profile);

	// The public marketing pages (homepage, roadmap) render their own lightweight header/footer
	// (see src/routes/(marketing)/+layout.svelte) instead of the app-shell chrome below — a fixed
	// icon-only sidebar reads as an unfinished internal tool next to marketing copy, especially for
	// a signed-out visitor who has almost nothing to put in that sidebar anyway. Route groups don't
	// appear in the URL, so this is a plain pathname check, not a group lookup. Every other route
	// (including the authenticated dashboard) is unaffected and keeps TopBar + Sidebar exactly as
	// before.
	const path = $derived(page.url.pathname);
	const isMarketing = $derived(path === '/' || path === '/roadmap');
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
	<title>CreatorConnect</title>
</svelte:head>

{#if isMarketing && !needsProfile}
	{@render children()}
{:else if isMarketing}
	<!-- Signed-in but not yet onboarded: still gate on CompleteProfile even on the marketing
	     pages, same as every other route, so a fresh sign-in can't wander the marketing site
	     half-provisioned. No sidebar/topbar here, so this deliberately skips .app-main — that
	     class's margin-left/padding-top exist only to offset the fixed chrome rendered below. -->
	<CompleteProfile />
{:else}
	<TopBar />
	<div class="app-shell">
		<Sidebar />
		<div class="app-main">
			{#if needsProfile}
				<CompleteProfile />
			{:else}
				{@render children()}
			{/if}
		</div>
	</div>
{/if}
