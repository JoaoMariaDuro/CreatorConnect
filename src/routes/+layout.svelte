<script lang="ts">
	import favicon from '$lib/assets/favicon.svg';
	import '$lib/app.css';
	import Sidebar from '$lib/Sidebar.svelte';

	let { children } = $props();
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
	<title>CreatorConnect</title>
</svelte:head>

<div class="app-shell">
	<Sidebar />
	<div class="app-main">
		{@render children()}
	</div>
</div>
