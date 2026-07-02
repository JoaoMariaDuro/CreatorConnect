<script lang="ts">
	import Badges from '$lib/Badges.svelte';

	let { data } = $props();
	const profile = $derived(data.profile);
</script>

<div class="container">
	<h1>Dashboard</h1>

	{#if !profile}
		<div class="empty">Setting up your profile…</div>
	{:else if profile.role === 'creator'}
		<p class="muted">Signed in as {profile.display_name}</p>

		{#if data.pendingListingIds?.length}
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
		{#if !data.reservations || data.reservations.length === 0}
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
			</div>
		{/if}

		<div class="section-title">Browse more</div>
		<a class="btn" href="/browse">Go to marketplace</a>
	{:else if profile.role === 'manager'}
		<p class="muted">Signed in as {profile.display_name} · representing {data.roster.length} creator{data.roster.length === 1 ? '' : 's'}</p>

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
						<div class="muted" style="font-size:13px;">{count} listing{count === 1 ? '' : 's'}</div>
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
