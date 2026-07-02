<script lang="ts">
	import {
		viewerState,
		listings,
		getCreator,
		getAdvertiser,
		getManager,
		formatMoney,
		formatDate,
		setActingAsCreator
	} from '$lib/store.svelte';
	import Badges from '$lib/Badges.svelte';

	const viewer = $derived(viewerState.current);

	// ---- Creator view ----
	const creatorId = $derived(viewer.role === 'creator' ? viewer.id : undefined);
	const creatorListings = $derived(creatorId ? listings.filter((l) => l.creatorId === creatorId) : []);
	const creatorNeedsAttention = $derived(
		creatorListings.filter((l) => {
			if (l.mechanism === 'A') return l.offers?.some((o) => o.status === 'pending' && o.from === 'advertiser');
			if (l.mechanism === 'C') return l.exclusivity?.negotiation?.status === 'proposed' && l.exclusivity.negotiation.from === 'advertiser';
			if (l.mechanism === 'D') return l.reservation?.status === 'awaiting_confirmation';
			return false;
		})
	);

	// ---- Advertiser view ----
	const advertiserId = $derived(viewer.role === 'advertiser' ? viewer.id : undefined);
	const advertiserActive = $derived(
		advertiserId
			? listings.filter((l) => {
					if (l.mechanism === 'A') return l.offers?.some((o) => (o as any)); // any offer thread touched -- simplistic demo match
					if (l.mechanism === 'C') return l.exclusivity?.advertiserId === advertiserId;
					if (l.mechanism === 'D') return l.reservation?.advertiserId === advertiserId;
					return false;
				})
			: []
	);

	// ---- Manager view ----
	const manager = $derived(viewer.role === 'manager' ? getManager(viewer.id) : undefined);
	const rosterListings = $derived(
		manager ? listings.filter((l) => manager.creatorIds.includes(l.creatorId)) : []
	);
</script>

<div class="container">
	<h1>Dashboard</h1>

	{#if viewer.role === 'creator'}
		{@const creator = getCreator(viewer.id)}
		<p class="muted">Signed in as {creator?.name} ({creator?.handle})</p>

		<div class="section-title">Needs your attention</div>
		{#if creatorNeedsAttention.length === 0}
			<div class="empty">Nothing pending — you're all caught up.</div>
		{:else}
			<div class="grid">
				{#each creatorNeedsAttention as l (l.id)}
					<a class="card listing-card" href={`/listings/${l.id}`}>
						<div class="row" style="justify-content: space-between; margin-bottom:8px;">
							<Badges mechanism={l.mechanism} />
							<Badges status={l.status} />
						</div>
						<strong>{l.contentType} on {l.platform}</strong>
						<div class="muted" style="font-size:13px; margin-top:4px;">{l.availabilityWindow}</div>
						<div class="muted" style="font-size:13px; margin-top:6px;">
							{#if l.mechanism === 'A'}Pending offer awaiting your response
							{:else if l.mechanism === 'C'}Proposal awaiting your response
							{:else if l.mechanism === 'D'}Reservation awaiting your price confirmation{/if}
						</div>
					</a>
				{/each}
			</div>
		{/if}

		<div class="section-title">All your listings</div>
		{#if creatorListings.length === 0}
			<div class="empty">You haven't created any listings yet. <a href="/create">Create one</a>.</div>
		{:else}
			<div class="grid">
				{#each creatorListings as l (l.id)}
					<a class="card listing-card" href={`/listings/${l.id}`}>
						<div class="row" style="justify-content: space-between; margin-bottom:8px;">
							<Badges mechanism={l.mechanism} />
							<Badges status={l.status} />
						</div>
						<strong>{l.contentType} on {l.platform}</strong>
						<div class="muted" style="font-size:13px; margin-top:4px;">{l.availabilityWindow}</div>
					</a>
				{/each}
			</div>
		{/if}

	{:else if viewer.role === 'advertiser'}
		{@const advertiser = getAdvertiser(viewer.id)}
		<p class="muted">Signed in as {advertiser?.contactName} ({advertiser?.company})</p>

		<div class="section-title">Your active offers, exclusivity holds &amp; reservations</div>
		{#if advertiserActive.length === 0}
			<div class="empty">No active engagement yet. <a href="/">Browse listings</a> to get started.</div>
		{:else}
			<div class="grid">
				{#each advertiserActive as l (l.id)}
					{@const creator = getCreator(l.creatorId)}
					<a class="card listing-card" href={`/listings/${l.id}`}>
						<div class="row" style="justify-content: space-between; margin-bottom:8px;">
							<Badges mechanism={l.mechanism} />
							<Badges status={l.status} />
						</div>
						<strong>{creator?.name} — {l.contentType} on {l.platform}</strong>
						<div class="muted" style="font-size:13px; margin-top:4px;">{l.availabilityWindow}</div>
					</a>
				{/each}
			</div>
		{/if}

		<div class="section-title">Browse more</div>
		<a class="btn" href="/">Go to marketplace</a>

	{:else if viewer.role === 'manager' && manager}
		<p class="muted">Signed in as {manager.name} ({manager.agency}) · representing {manager.creatorIds.length} creators</p>

		<div class="section-title">Your roster</div>
		<div class="grid">
			{#each manager.creatorIds as cid}
				{@const c = getCreator(cid)}
				{#if c}
					{@const count = listings.filter((l) => l.creatorId === cid).length}
					{@const pendingCount = listings.filter((l) => {
						if (l.creatorId !== cid) return false;
						if (l.mechanism === 'A') return l.offers?.some((o) => o.status === 'pending' && o.from === 'advertiser');
						if (l.mechanism === 'C') return l.exclusivity?.negotiation?.status === 'proposed' && l.exclusivity.negotiation.from === 'advertiser';
						if (l.mechanism === 'D') return l.reservation?.status === 'awaiting_confirmation';
						return false;
					}).length}
					<div class="card">
						<strong>{c.name}</strong>
						<div class="muted" style="font-size:13px; margin: 2px 0 10px;">{c.handle} · {c.followers.toLocaleString()} followers</div>
						<div class="muted" style="font-size:13px;">{count} listing{count === 1 ? '' : 's'} · {pendingCount} needing attention</div>
						<button class="btn btn-sm" style="margin-top:10px;" onclick={() => setActingAsCreator(cid)}>
							Act as {c.name}
						</button>
					</div>
				{/if}
			{/each}
		</div>

		<div class="section-title">All roster listings</div>
		{#if rosterListings.length === 0}
			<div class="empty">No listings across your roster yet.</div>
		{:else}
			<div class="grid">
				{#each rosterListings as l (l.id)}
					{@const c = getCreator(l.creatorId)}
					<a class="card listing-card" href={`/listings/${l.id}`}>
						<div class="row" style="justify-content: space-between; margin-bottom:8px;">
							<Badges mechanism={l.mechanism} />
							<Badges status={l.status} />
						</div>
						<strong>{c?.name} — {l.contentType} on {l.platform}</strong>
						<div class="muted" style="font-size:13px; margin-top:4px;">{l.availabilityWindow}</div>
					</a>
				{/each}
			</div>
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
