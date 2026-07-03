<script lang="ts">
	let { data } = $props();
	const profile = $derived(data.profile);
	const org = $derived(data.org);
</script>

<svelte:head>
	<title>{profile.display_name} · CreatorConnect</title>
</svelte:head>

<div class="container media-kit">
	<div class="card profile-card">
		<div class="row" style="align-items:center; gap:16px;">
			<span class="avatar-lg">{profile.display_name?.[0]?.toUpperCase() ?? '?'}</span>
			<div>
				<h1 style="margin:0;">{profile.display_name}</h1>
				{#if profile.handle}<div class="muted">{profile.handle}</div>{/if}
			</div>
		</div>

		<div class="row" style="gap:8px; flex-wrap:wrap; margin-top:16px;">
			<span class="badge badge-neutral">{profile.role === 'advertiser' ? 'Advertiser' : 'Manager / Agency'}</span>
		</div>

		{#if profile.bio}
			<p class="muted" style="margin-top:14px;">{profile.bio}</p>
		{/if}

		{#if profile.platform_handles && Object.keys(profile.platform_handles).length}
			<div class="row" style="gap:8px; flex-wrap:wrap; margin-top:12px;">
				{#each Object.entries(profile.platform_handles) as [platform, handle] (platform)}
					<span class="badge badge-neutral">{platform}: {handle}</span>
				{/each}
			</div>
		{/if}
	</div>

	{#if org}
		<a class="card listing-card" href={`/org/${org.handle}`}>
			<div class="muted" style="font-size:13px;">Part of</div>
			<strong>{org.name}</strong>
			<div class="muted" style="font-size:13px; margin-top:4px;">{org.memberRole === 'owner' ? 'Owner' : 'Member'}</div>
		</a>
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
