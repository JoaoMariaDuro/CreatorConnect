<script lang="ts">
	import {
		listings,
		getCreator,
		formatMoney,
		formatDate,
		type Platform,
		type Mechanism
	} from '$lib/store.svelte';
	import Badges from '$lib/Badges.svelte';

	let platformFilter = $state<'all' | Platform>('all');
	let mechanismFilter = $state<'all' | Mechanism>('all');

	const filtered = $derived(
		listings.filter((l) => {
			if (platformFilter !== 'all' && l.platform !== platformFilter) return false;
			if (mechanismFilter !== 'all' && l.mechanism !== mechanismFilter) return false;
			return true;
		})
	);

	function priceInfo(l: (typeof listings)[number]): string {
		if (l.mechanism === 'A') {
			return l.status === 'deal' && l.deal ? `Sold at ${formatMoney(l.deal.price)}` : `Asking ${formatMoney(l.askingPrice ?? 0)}`;
		}
		if (l.mechanism === 'C') {
			if (l.status === 'deal' && l.deal) return `Sold at ${formatMoney(l.deal.price)}`;
			if (l.rateCardRangeLow && l.rateCardRangeHigh) {
				return `~${formatMoney(l.rateCardRangeLow)}–${formatMoney(l.rateCardRangeHigh)}`;
			}
			return 'Rate negotiated bilaterally';
		}
		if (l.mechanism === 'D') {
			if (l.status === 'deal' && l.deal) return `Confirmed at ${formatMoney(l.deal.price)}`;
			return `Floor ${formatMoney(l.floorPrice ?? 0)}`;
		}
		return '';
	}
</script>

<div class="container">
	<h1>Browse Sponsorship Slots</h1>
	<p class="muted">Reserve tomorrow's sponsorship slots today. Every listing shows its pricing mechanism up front.</p>

	<div class="row" style="margin: 16px 0 24px;">
		<div class="field" style="margin-bottom:0;">
			<label for="platform-filter">Platform</label>
			<select id="platform-filter" bind:value={platformFilter}>
				<option value="all">All platforms</option>
				<option value="YouTube">YouTube</option>
				<option value="Instagram">Instagram</option>
				<option value="TikTok">TikTok</option>
			</select>
		</div>
		<div class="field" style="margin-bottom:0;">
			<label for="mechanism-filter">Mechanism</label>
			<select id="mechanism-filter" bind:value={mechanismFilter}>
				<option value="all">All mechanisms</option>
				<option value="A">A — Fixed Price + Counter-Offer</option>
				<option value="C">C — Reserve-the-Relationship</option>
				<option value="D">D — Reserve-the-Slot</option>
			</select>
		</div>
	</div>

	{#if filtered.length === 0}
		<div class="empty">No listings match those filters.</div>
	{:else}
		<div class="grid">
			{#each filtered as listing (listing.id)}
				{@const creator = getCreator(listing.creatorId)}
				<a class="card listing-card" href={`/listings/${listing.id}`}>
					<div class="row" style="justify-content: space-between; margin-bottom: 8px;">
						<Badges mechanism={listing.mechanism} />
						<Badges status={listing.status} />
					</div>
					<h3 style="margin: 4px 0 2px;">{creator?.name}</h3>
					<div class="muted" style="font-size:13px; margin-bottom:8px;">
						{creator?.handle} · {(creator?.followers ?? 0).toLocaleString()} followers · {creator?.niche}
					</div>
					<div class="row" style="font-size:13px; margin-bottom:6px;">
						<strong>{listing.platform}</strong>
						<span class="muted">·</span>
						<span>{listing.contentType}</span>
					</div>
					<div class="muted" style="font-size:13px; margin-bottom:10px;">{listing.availabilityWindow}</div>
					<hr class="sep" />
					<div class="row" style="justify-content: space-between;">
						<strong>{priceInfo(listing)}</strong>
						<span class="muted" style="font-size:12px;">{formatDate(listing.createdAt)}</span>
					</div>
				</a>
			{/each}
		</div>
	{/if}
</div>

<style>
	.listing-card {
		display: block;
		color: inherit;
		text-decoration: none;
		transition: box-shadow 0.15s, border-color 0.15s;
	}
	.listing-card:hover {
		border-color: var(--accent);
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
		text-decoration: none;
	}
</style>
