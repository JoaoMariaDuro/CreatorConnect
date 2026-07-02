<script lang="ts">
	import Badges from '$lib/Badges.svelte';
	import { formatMoney, formatDateTime } from '$lib/format';

	let { data } = $props();
</script>

<div class="container">
	<h1>Disputes</h1>

	{#if data.disputes.length === 0}
		<div class="empty">No open disputes.</div>
	{:else}
		<div class="stack">
			{#each data.disputes as d (d.id)}
				<a class="card dispute-card" href={`/admin/disputes/${d.id}`}>
					<div class="row" style="justify-content: space-between; margin-bottom:8px;">
						<Badges mechanism={d.listing?.pricing_mechanism} />
						<span class="muted" style="font-size:13px;">Disputed {formatDateTime(d.disputed_at)}</span>
					</div>
					<strong>{d.creator?.display_name} &harr; {d.advertiser?.display_name}</strong>
					<div class="muted" style="font-size:13px; margin-top:4px;">{formatMoney(d.final_price_cents)}</div>
				</a>
			{/each}
		</div>
	{/if}
</div>

<style>
	.dispute-card {
		display: block;
		color: inherit;
		text-decoration: none;
	}
	.dispute-card:hover {
		border-color: var(--red);
		text-decoration: none;
	}
</style>
