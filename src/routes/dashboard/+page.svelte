<script lang="ts">
	import Badges from '$lib/Badges.svelte';
	import { formatMoney, formatDate } from '$lib/format';

	let { data } = $props();
	const profile = $derived(data.profile);

	// Read-only rollup of the creator's own current pricing posture across all open listings, per
	// mechanism — ties together fields that already exist (floor/rate-card cents) but were only ever
	// shown per-listing, not as a single "here's where my prices stand right now" glance.
	function priceRange(cents: number[]): string {
		if (cents.length === 0) return '—';
		const min = Math.min(...cents);
		const max = Math.max(...cents);
		return min === max ? formatMoney(min) : `${formatMoney(min)}–${formatMoney(max)}`;
	}
	const rateCard = $derived.by(() => {
		if (profile?.role !== 'creator') return null;
		const open = (data.listings ?? []).filter((l: any) => l.status === 'open');
		const adPrices = open.filter((l: any) => l.pricing_mechanism === 'A' || l.pricing_mechanism === 'D')
			.map((l: any) => l.floor_price_cents).filter((c: any) => c != null);
		const cPrices = open.filter((l: any) => l.pricing_mechanism === 'C' && l.rate_card_low_cents != null)
			.flatMap((l: any) => [l.rate_card_low_cents, l.rate_card_high_cents]).filter((c: any) => c != null);
		if (adPrices.length === 0 && cPrices.length === 0) return null;
		return { adRange: priceRange(adPrices), cRange: priceRange(cPrices) };
	});
</script>

<div class="container">
	<h1>Dashboard</h1>

	{#if !profile}
		<div class="empty">Setting up your profile…</div>
	{:else if profile.role === 'creator'}
		<p class="muted">Signed in as {profile.display_name}</p>

		{#if rateCard}
			<div class="card" style="margin-bottom:16px;">
				<div class="muted" style="font-size:13px;">Your current pricing (open listings)</div>
				<div class="row" style="gap:24px; margin-top:8px; flex-wrap:wrap;">
					<div>
						<div class="muted" style="font-size:12px;">Fixed price / floor (A · D)</div>
						<strong>{rateCard.adRange}</strong>
					</div>
					<div>
						<div class="muted" style="font-size:12px;">Rate-card range (C)</div>
						<strong>{rateCard.cRange}</strong>
					</div>
					<div>
						<div class="muted" style="font-size:12px;">Completed deals</div>
						<strong>{profile.completed_deals_count ?? 0}</strong>
					</div>
				</div>
			</div>
		{/if}

		{#if data.pendingListingIds?.length || data.pendingOfferListingIds?.length || data.pendingGrantListingIds?.length}
			<div class="section-title">Needs your attention</div>
			<div class="grid">
				{#each data.listings.filter((l: any) => data.pendingListingIds.includes(l.id)) as l (l.id)}
					<a class="card listing-card" href={`/listings/${l.id}`}>
						<div class="row" style="justify-content: space-between; margin-bottom:8px;">
							<Badges mechanism={l.pricing_mechanism} />
							<Badges status={l.status} />
						</div>
						<strong>{l.content_type} on {l.platform}</strong>
						<div class="muted" style="font-size:13px; margin-top:4px;">{l.availability_window}</div>
						<div class="muted" style="font-size:13px; margin-top:6px;">Reservation awaiting your price confirmation</div>
					</a>
				{/each}
				{#each data.listings.filter((l: any) => data.pendingOfferListingIds.includes(l.id)) as l (l.id)}
					<a class="card listing-card" href={`/listings/${l.id}`}>
						<div class="row" style="justify-content: space-between; margin-bottom:8px;">
							<Badges mechanism={l.pricing_mechanism} />
							<Badges status={l.status} />
						</div>
						<strong>{l.content_type} on {l.platform}</strong>
						<div class="muted" style="font-size:13px; margin-top:4px;">{l.availability_window}</div>
						<div class="muted" style="font-size:13px; margin-top:6px;">Offer awaiting your response</div>
					</a>
				{/each}
				{#each data.listings.filter((l: any) => data.pendingGrantListingIds.includes(l.id)) as l (l.id)}
					<a class="card listing-card" href={`/listings/${l.id}`}>
						<div class="row" style="justify-content: space-between; margin-bottom:8px;">
							<Badges mechanism={l.pricing_mechanism} />
							<Badges status={l.status} />
						</div>
						<strong>{l.content_type} on {l.platform}</strong>
						<div class="muted" style="font-size:13px; margin-top:4px;">{l.availability_window}</div>
						<div class="muted" style="font-size:13px; margin-top:6px;">Exclusivity grant awaiting your response</div>
					</a>
				{/each}
			</div>
		{/if}

		{#if data.upcomingDeliveries?.length}
			<div class="section-title">Upcoming deliveries</div>
			<div class="grid">
				{#each data.upcomingDeliveries as d (d.id)}
					<a class="card listing-card" href={`/deal/${d.id}`}>
						<strong>{d.advertiser?.display_name}</strong>
						<div class="muted" style="font-size:13px; margin-top:4px;">{formatMoney(d.final_price_cents)} · due {formatDate(d.delivery_due_at)}</div>
						<div class="muted" style="font-size:13px; margin-top:4px;">Status: {d.status}</div>
					</a>
				{/each}
			</div>
		{/if}

		<div class="section-title">All your listings</div>
		{#if data.listings.length === 0}
			<div class="empty">You haven't created any listings yet. <a href="/create">Create one</a>.</div>
		{:else}
			<div class="grid">
				{#each data.listings as l (l.id)}
					<a class="card listing-card" href={`/listings/${l.id}`}>
						<div class="row" style="justify-content: space-between; margin-bottom:8px;">
							<Badges mechanism={l.pricing_mechanism} />
							<Badges status={l.status} />
						</div>
						<strong>{l.content_type} on {l.platform}</strong>
						<div class="muted" style="font-size:13px; margin-top:4px;">{l.availability_window}</div>
					</a>
				{/each}
			</div>
		{/if}
	{:else if profile.role === 'advertiser'}
		<p class="muted">Signed in as {profile.display_name}</p>

		<div class="section-title">Your active reservations</div>
		{#if (!data.reservations || data.reservations.length === 0) && (!data.offers || data.offers.length === 0) && (!data.grants || data.grants.length === 0)}
			<div class="empty">No active engagement yet. <a href="/browse">Browse listings</a> to get started.</div>
		{:else}
			<div class="grid">
				{#each data.reservations as r (r.id)}
					<a class="card listing-card" href={`/listings/${r.listing.id}`}>
						<div class="row" style="justify-content: space-between; margin-bottom:8px;">
							<Badges mechanism={r.listing.pricing_mechanism} />
							<Badges status={r.listing.status} />
						</div>
						<strong>{r.listing.creator?.display_name} — {r.listing.content_type} on {r.listing.platform}</strong>
						<div class="muted" style="font-size:13px; margin-top:4px;">{r.listing.availability_window}</div>
						<div class="muted" style="font-size:13px; margin-top:6px;">Reservation: {r.status}</div>
					</a>
				{/each}
				{#each data.offers ?? [] as o (o.id)}
					<a class="card listing-card" href={`/listings/${o.listing.id}`}>
						<div class="row" style="justify-content: space-between; margin-bottom:8px;">
							<Badges mechanism={o.listing.pricing_mechanism} />
							<Badges status={o.listing.status} />
						</div>
						<strong>{o.listing.creator?.display_name} — {o.listing.content_type} on {o.listing.platform}</strong>
						<div class="muted" style="font-size:13px; margin-top:4px;">{o.listing.availability_window}</div>
						<div class="muted" style="font-size:13px; margin-top:6px;">
							{o.proposed_by === 'advertiser' ? 'Offer sent — awaiting creator response' : 'Creator countered — awaiting your response'}
						</div>
					</a>
				{/each}
				{#each data.grants ?? [] as g (g.id)}
					<a class="card listing-card" href={`/listings/${g.listing.id}`}>
						<div class="row" style="justify-content: space-between; margin-bottom:8px;">
							<Badges mechanism={g.listing.pricing_mechanism} />
							<Badges status={g.listing.status} />
						</div>
						<strong>{g.listing.creator?.display_name} — {g.listing.content_type} on {g.listing.platform}</strong>
						<div class="muted" style="font-size:13px; margin-top:4px;">{g.listing.availability_window}</div>
						<div class="muted" style="font-size:13px; margin-top:6px;">
							{#if !g.negotiation}
								Propose terms to move forward
							{:else if g.negotiation.from === 'advertiser'}
								Awaiting creator response
							{:else}
								Creator proposed terms — awaiting your response
							{/if}
						</div>
					</a>
				{/each}
			</div>
		{/if}

		<div class="section-title">Browse more</div>
		<a class="btn" href="/browse">Go to marketplace</a>
	{:else if profile.role === 'manager'}
		<p class="muted">Signed in as {profile.display_name} · representing {data.roster.length} creator{data.roster.length === 1 ? '' : 's'}</p>

		<div class="grid">
			<div class="card">
				<div class="muted" style="font-size:13px;">Commission earned</div>
				<div style="font-size:28px; font-weight:600; margin-top:4px;">{formatMoney(data.commissionEarnedCents ?? 0)}</div>
				<div class="muted" style="font-size:12px; margin-top:6px;">From completed deals across your roster</div>
			</div>
			<div class="card">
				<div class="muted" style="font-size:13px;">Commission pending</div>
				<div style="font-size:28px; font-weight:600; margin-top:4px;">{formatMoney(data.commissionPendingCents ?? 0)}</div>
				<div class="muted" style="font-size:12px; margin-top:6px;">From deals in progress, not yet completed</div>
			</div>
		</div>
		<div class="muted" style="font-size:12px; margin: 8px 0 4px;">Estimate based on your per-creator commission rate — not yet tied to an automated payout.</div>

		{#if data.pendingListingIds?.length || data.pendingOfferListingIds?.length || data.pendingGrantListingIds?.length}
			<div class="section-title">Needs attention across your roster</div>
			<div class="grid">
				{#each data.listings.filter((l: any) => data.pendingListingIds.includes(l.id)) as l (l.id)}
					<a class="card listing-card" href={`/listings/${l.id}`}>
						<div class="row" style="justify-content: space-between; margin-bottom:8px;">
							<Badges mechanism={l.pricing_mechanism} />
							<Badges status={l.status} />
						</div>
						<strong>{l.creator?.display_name} — {l.content_type} on {l.platform}</strong>
						<div class="muted" style="font-size:13px; margin-top:6px;">Reservation awaiting creator's price confirmation</div>
					</a>
				{/each}
				{#each data.listings.filter((l: any) => data.pendingOfferListingIds.includes(l.id)) as l (l.id)}
					<a class="card listing-card" href={`/listings/${l.id}`}>
						<div class="row" style="justify-content: space-between; margin-bottom:8px;">
							<Badges mechanism={l.pricing_mechanism} />
							<Badges status={l.status} />
						</div>
						<strong>{l.creator?.display_name} — {l.content_type} on {l.platform}</strong>
						<div class="muted" style="font-size:13px; margin-top:6px;">Offer awaiting response</div>
					</a>
				{/each}
				{#each data.listings.filter((l: any) => data.pendingGrantListingIds.includes(l.id)) as l (l.id)}
					<a class="card listing-card" href={`/listings/${l.id}`}>
						<div class="row" style="justify-content: space-between; margin-bottom:8px;">
							<Badges mechanism={l.pricing_mechanism} />
							<Badges status={l.status} />
						</div>
						<strong>{l.creator?.display_name} — {l.content_type} on {l.platform}</strong>
						<div class="muted" style="font-size:13px; margin-top:6px;">Exclusivity grant awaiting response</div>
					</a>
				{/each}
			</div>
		{/if}

		{#if data.upcomingDeliveries?.length}
			<div class="section-title">Upcoming deliveries</div>
			<div class="grid">
				{#each data.upcomingDeliveries as d (d.id)}
					<a class="card listing-card" href={`/deal/${d.id}`}>
						<strong>{d.creator?.display_name} → {d.advertiser?.display_name}</strong>
						<div class="muted" style="font-size:13px; margin-top:4px;">{formatMoney(d.final_price_cents)} · due {formatDate(d.delivery_due_at)}</div>
						<div class="muted" style="font-size:13px; margin-top:4px;">Status: {d.status}</div>
					</a>
				{/each}
			</div>
		{/if}

		<div class="section-title">Your roster</div>
		{#if data.roster.length === 0}
			<div class="empty">No linked creators yet — a creator needs to grant you access before you can manage listings on their behalf.</div>
		{:else}
			<div class="grid">
				{#each data.roster as c (c.id)}
					{@const count = data.listings.filter((l: any) => l.creator_id === c.id).length}
					<div class="card">
						<strong>{c.display_name}</strong>
						<div class="muted" style="font-size:13px; margin: 2px 0 10px;">{c.handle ?? ''} · {(c.follower_count ?? 0).toLocaleString()} followers</div>
						<div class="muted" style="font-size:13px;">{count} listing{count === 1 ? '' : 's'} · {c.activeDealsCount ?? 0} in progress · {c.completedDealsCount ?? 0} completed</div>
					</div>
				{/each}
			</div>

			<div class="section-title">All roster listings</div>
			{#if data.listings.length === 0}
				<div class="empty">No listings across your roster yet.</div>
			{:else}
				<div class="grid">
					{#each data.listings as l (l.id)}
						<a class="card listing-card" href={`/listings/${l.id}`}>
							<div class="row" style="justify-content: space-between; margin-bottom:8px;">
								<Badges mechanism={l.pricing_mechanism} />
								<Badges status={l.status} />
							</div>
							<strong>{l.creator?.display_name} — {l.content_type} on {l.platform}</strong>
							<div class="muted" style="font-size:13px; margin-top:4px;">{l.availability_window}</div>
						</a>
					{/each}
				</div>
			{/if}
		{/if}
	{/if}
</div>

<style>
	.listing-card {
		display: block;
		color: inherit;
		text-decoration: none;
	}
	.listing-card:hover {
		border-color: var(--accent);
		text-decoration: none;
	}
</style>
