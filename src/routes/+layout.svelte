<script lang="ts">
	import { page } from '$app/state';
	import favicon from '$lib/assets/favicon.svg';
	import '$lib/app.css';
	import Sidebar from '$lib/Sidebar.svelte';
	import CompleteProfile from '$lib/CompleteProfile.svelte';

	let { children } = $props();

	const user = $derived(page.data.user);
	const profile = $derived(page.data.profile);
	const needsProfile = $derived(!!user && !profile);
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
	<title>CreatorConnect</title>
</svelte:head>

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
