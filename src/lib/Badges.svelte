<script lang="ts">
	import { mechanismLabel, type Mechanism } from '$lib/format';

	// Matches creator_listings.status's full check constraint (supabase/listings.sql) — the real
	// schema has more states than the old mock's simplified 'open'|'pending'|'deal'.
	type ListingStatus = 'draft' | 'open' | 'pending' | 'reserved' | 'confirmed' | 'deal' | 'expired' | 'cancelled';

	let { mechanism, status }: { mechanism?: Mechanism; status?: ListingStatus } = $props();
</script>

{#if mechanism}
	<span class="badge badge-{mechanism.toLowerCase()}">Mechanism {mechanism} — {mechanismLabel[mechanism]}</span>
{/if}
{#if status}
	<span class="badge badge-{status}">{status}</span>
{/if}
