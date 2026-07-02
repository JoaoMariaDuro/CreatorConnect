<script lang="ts">
	import { formatMoney, formatDate, type Mechanism } from '$lib/format';
	import Badges from '$lib/Badges.svelte';

	let { data } = $props();

	let platformFilter = $state<'all' | string>('all');
	let mechanismFilter = $state<'all' | Mechanism>('all');

	const filtered = $derived(
		data.listings.filter((l: any) => {
			if (platformFilter !== 'all' && l.platform !== platformFilter) return false;
			if (mechanismFilter !== 'all' && l.pricing_mechanism !== mechanismFilter) return false;
			return true;
		})
	);

	function priceInfo(l: any): string {
		if (l.pricing_mechanism === 'A') {
			return l.status === 'deal' ? 'Deal confirmed' : `Asking ${formatMoney(l.floor_price_cents ?? 0)}`;
		}
		if (l.pricing_mechanism === 'C') {
			if (l.status === 'deal') return 'Deal confirmed';
			if (l.rate_card_low_cents && l.rate_card_high_cents) {
				return `~${formatMoney(l.rate_card_low_cents)}–${formatMoney(l.rate_card_high_cents)}`;
			}
			return 'Rate negotiated bilaterally';
		}
		if (l.pricing_mechanism === 'D') {
			return l.status === 'deal' ? 'Deal confirmed' : `Floor ${formatMoney(l.floor_price_cents ?? 0)}`;
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
		<div class="empty">
			{#if data.listings.length === 0}
				No listings yet — be the first to <a href="/create">create one</a>.
			{:else}
				No listings match those filters.
			{/if}
		</div>
	{:else}
		<div class="grid">
			{#each filtered as listing (listing.id)}
				<a class="card listing-card" href={`/listings/${listing.id}`}>
					<div class="row" style="justify-content: space-between; margin-bottom: 8px;">
						<Badges mechanism={listing.pricing_mechanism} />
						<Badges status={listing.status} />
					</div>
					<h3 style="margin: 4px 0 2px;">{listing.creator?.display_name}</h3>
					<div class="muted" style="font-size:13px; margin-bottom:8px;">
						{listing.creator?.handle ?? ''} · {(listing.creator?.follower_count ?? 0).toLocaleString()} followers
						{#if listing.creator?.niche_tags?.length}
							· {listing.creator.niche_tags.join(', ')}
						{/if}
					</div>
					<div class="row" style="font-size:13px; margin-bottom:6px;">
						<strong>{listing.platform}</strong>
						<span class="muted">·</span>
						<span>{listing.content_type}</span>
					</div>
					<div class="muted" style="font-size:13px; margin-bottom:10px;">{listing.availability_window}</div>
					<hr class="sep" />
					<div class="row" style="justify-content: space-between;">
						<strong>{priceInfo(listing)}</strong>
						<span class="muted" style="font-size:12px;">{formatDate(listing.created_at)}</span>
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
