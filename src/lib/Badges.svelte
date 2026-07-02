<script lang="ts">
	import { mechanismLabel, type Mechanism, type ListingStatus } from '$lib/store.svelte';

	let { mechanism, status }: { mechanism?: Mechanism; status?: ListingStatus } = $props();
</script>

{#if mechanism}
	<span class="badge badge-{mechanism.toLowerCase()}">Mechanism {mechanism} — {mechanismLabel[mechanism]}</span>
{/if}
{#if status}
	<span class="badge badge-{status}">{status}</span>
{/if}
