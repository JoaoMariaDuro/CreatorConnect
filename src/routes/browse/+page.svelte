<script lang="ts">
	import { page } from '$app/state';
	import { invalidateAll } from '$app/navigation';
	import { Bookmark } from '@lucide/svelte';
	import { formatMoney, formatDate, type Mechanism } from '$lib/format';
	import Badges from '$lib/Badges.svelte';

	let { data } = $props();
	const user = $derived(page.data.user);
	const profile = $derived(page.data.profile);
	const supabase = $derived(page.data.supabase);
	const isAdvertiser = $derived(profile?.role === 'advertiser');

	let shortlisted = $state<Set<string>>(new Set());
	$effect(() => {
		shortlisted = new Set(data.shortlistedIds ?? []);
	});
	let togglingId = $state<string | null>(null);

	async function toggleShortlist(e: MouseEvent, listingId: string) {
		e.preventDefault();
		e.stopPropagation();
		if (!supabase || !user || togglingId) return;
		togglingId = listingId;
		if (shortlisted.has(listingId)) {
			shortlisted.delete(listingId);
			shortlisted = new Set(shortlisted);
			await supabase.from('shortlists').delete().eq('advertiser_id', user.id).eq('listing_id', listingId);
		} else {
			shortlisted.add(listingId);
			shortlisted = new Set(shortlisted);
			await supabase.from('shortlists').insert({ advertiser_id: user.id, listing_id: listingId });
		}
		togglingId = null;
		await invalidateAll();
	}

	let platformFilter = $state<'all' | string>('all');
	let mechanismFilter = $state<'all' | Mechanism>('all');

	const filtered = $derived(
		data.listings.filter((l: any) => {
			if (platformFilter !== 'all' && l.platform !== platformFilter) return false;
			if (mechanismFilter !== 'all' && l.pricing_mechanism !== mechanismFilter) return false;
			return true;
		})
	);

	const mechanismTabs: { value: 'all' | Mechanism; label: string }[] = [
		{ value: 'all', label: 'All' },
		{ value: 'D', label: 'Reserve Now (D)' },
		{ value: 'A', label: 'Negotiate (A)' },
		{ value: 'C', label: 'Early Access (C)' }
	];

	function priceInfo(l: any): { text: string; isPrice: boolean } {
		if (l.pricing_mechanism === 'A') {
			return l.status === 'deal'
				? { text: 'Deal confirmed', isPrice: false }
				: { text: `Asking ${formatMoney(l.floor_price_cents ?? 0)}`, isPrice: true };
		}
		if (l.pricing_mechanism === 'C') {
			if (l.status === 'deal') return { text: 'Deal confirmed', isPrice: false };
			if (l.rate_card_low_cents && l.rate_card_high_cents) {
				return {
					text: `~${formatMoney(l.rate_card_low_cents)}–${formatMoney(l.rate_card_high_cents)}`,
					isPrice: true
				};
			}
			return { text: 'Rate negotiated bilaterally', isPrice: false };
		}
		if (l.pricing_mechanism === 'D') {
			return l.status === 'deal'
				? { text: 'Deal confirmed', isPrice: false }
				: { text: `Floor ${formatMoney(l.floor_price_cents ?? 0)}`, isPrice: true };
		}
		return { text: '', isPrice: false };
	}
</script>

<div class="container">
	<h1>Browse Sponsorship Slots</h1>
	{#if page.url.searchParams.get('notice') === 'advertiser-cannot-create'}
		<p class="muted">Only creators and managers can create listings — browse what's live instead.</p>
	{/if}
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
			<span class="mechanism-tabs-label">Mechanism</span>
			<div class="mechanism-tabs" role="tablist" aria-label="Filter by mechanism">
				{#each mechanismTabs as tab (tab.value)}
					<button
						type="button"
						class="mechanism-tab"
						class:active={mechanismFilter === tab.value}
						role="tab"
						aria-selected={mechanismFilter === tab.value}
						onclick={() => (mechanismFilter = tab.value)}
					>
						{tab.label}
					</button>
				{/each}
			</div>
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
				{@const price = priceInfo(listing)}
				<a class="card listing-card" href={`/listings/${listing.id}`}>
					<div class="row" style="justify-content: space-between; margin-bottom: 8px;">
						<Badges mechanism={listing.pricing_mechanism} />
						<div class="row" style="gap:8px;">
							<Badges status={listing.status} />
							{#if isAdvertiser}
								<button
									class="shortlist-btn"
									class:active={shortlisted.has(listing.id)}
									onclick={(e) => toggleShortlist(e, listing.id)}
									disabled={togglingId === listing.id}
									aria-label={shortlisted.has(listing.id) ? 'Remove from shortlist' : 'Add to shortlist'}
									title={shortlisted.has(listing.id) ? 'Shortlisted' : 'Shortlist'}
								>
									<Bookmark size={15} fill={shortlisted.has(listing.id) ? 'currentColor' : 'none'} />
								</button>
							{/if}
						</div>
					</div>
					<h3 style="margin: 4px 0 2px;">{listing.creator?.display_name}</h3>
					<div class="muted" style="font-size:13px; margin-bottom:8px;">
						{listing.creator?.handle ?? ''} · {(listing.creator?.follower_count ?? 0).toLocaleString()} followers
						{#if listing.creator?.completed_deals_count > 0}
							· {listing.creator.completed_deals_count} completed deal{listing.creator.completed_deals_count === 1 ? '' : 's'}
						{/if}
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
						{#if price.isPrice}
							<strong>{price.text}</strong>
						{:else}
							<span class="price-info-muted">{price.text}</span>
						{/if}
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
	.mechanism-tabs-label {
		display: block;
		font-size: 13px;
		font-weight: 500;
		color: var(--text-muted);
		margin-bottom: 6px;
	}
	.mechanism-tabs {
		display: inline-flex;
		gap: 4px;
		padding: 4px;
		background: var(--panel-raised);
		border: 1px solid var(--border);
		border-radius: var(--radius);
	}
	.mechanism-tab {
		background: none;
		border: none;
		border-radius: calc(var(--radius) - 2px);
		padding: 6px 12px;
		font-size: 13px;
		font-weight: 500;
		color: var(--text-muted);
		cursor: pointer;
		white-space: nowrap;
		transition: background 0.15s, color 0.15s;
	}
	.mechanism-tab:hover {
		color: var(--text);
	}
	.mechanism-tab.active {
		background: var(--accent-bg);
		color: var(--accent-dark);
	}
	.price-info-muted {
		font-size: 12px;
		font-weight: 400;
		color: var(--text-muted);
	}
	.shortlist-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		background: none;
		border: none;
		padding: 2px;
		color: var(--text-muted);
		border-radius: 6px;
	}
	.shortlist-btn:hover {
		color: var(--text);
		background: var(--panel-raised);
	}
	.shortlist-btn.active {
		color: var(--accent-dark);
	}
</style>
