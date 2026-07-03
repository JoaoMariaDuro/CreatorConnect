<script lang="ts">
	let { data } = $props();
	const company = $derived(data.company);
	const members = $derived(data.members);
	const representedCreators = $derived(data.representedCreators);
</script>

<svelte:head>
	<title>{company.name} · CreatorConnect</title>
</svelte:head>

<div class="container media-kit">
	<div class="card profile-card">
		<div class="row" style="align-items:center; gap:16px;">
			<span class="avatar-lg">{company.name?.[0]?.toUpperCase() ?? '?'}</span>
			<div>
				<h1 style="margin:0;">{company.name}</h1>
				{#if company.handle}<div class="muted">{company.handle}</div>{/if}
			</div>
		</div>

		<div class="row" style="gap:8px; flex-wrap:wrap; margin-top:16px;">
			<span class="badge badge-neutral">{company.company_type === 'advertiser' ? 'Advertiser' : 'Manager / Agency'}</span>
			{#each company.niche_tags ?? [] as tag (tag)}
				<span class="badge badge-neutral">{tag}</span>
			{/each}
		</div>

		{#if company.bio}
			<p class="muted" style="margin-top:14px;">{company.bio}</p>
		{/if}
	</div>

	<div class="section-title">Team ({members.length})</div>
	{#if members.length === 0}
		<div class="empty">No active members yet.</div>
	{:else}
		<div class="grid">
			{#each members as m (m.user_id)}
				{#if m.profile.handle}
					<a class="card listing-card" href={`/u/${m.profile.handle}`}>
						<strong>{m.profile.display_name}</strong>
						<div class="muted" style="font-size:13px; margin-top:4px;">
							{m.role === 'owner' ? 'Owner' : 'Member'}
							{#if m.profile.follower_count}· {m.profile.follower_count.toLocaleString()} followers{/if}
						</div>
					</a>
				{:else}
					<div class="card">
						<strong>{m.profile.display_name}</strong>
						<div class="muted" style="font-size:13px; margin-top:4px;">{m.role === 'owner' ? 'Owner' : 'Member'}</div>
					</div>
				{/if}
			{/each}
		</div>
	{/if}

	{#if company.company_type === 'manager' && representedCreators.length > 0}
		<div class="section-title">Represented creators ({representedCreators.length})</div>
		<div class="grid">
			{#each representedCreators as c (c.id)}
				{#if c.handle}
					<a class="card listing-card" href={`/c/${c.handle}`}>
						<strong>{c.display_name}</strong>
						<div class="muted" style="font-size:13px; margin-top:4px;">
							{#if c.follower_count}{c.follower_count.toLocaleString()} followers{/if}
							{#if c.completed_deals_count > 0}· {c.completed_deals_count} completed deal{c.completed_deals_count === 1 ? '' : 's'}{/if}
						</div>
						{#if c.niche_tags?.length}
							<div class="muted" style="font-size:13px; margin-top:2px;">{c.niche_tags.join(', ')}</div>
						{/if}
					</a>
				{/if}
			{/each}
		</div>
	{/if}
</div>

<style>
	.media-kit {
		max-width: 640px;
	}
	.profile-card {
		margin-bottom: 4px;
	}
	.avatar-lg {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 56px;
		height: 56px;
		border-radius: 50%;
		background: var(--accent-bg);
		color: var(--accent-dark);
		font-size: 22px;
		font-weight: 700;
		flex-shrink: 0;
	}
	.badge-neutral {
		background: var(--panel-raised);
		color: var(--text-muted);
	}
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
