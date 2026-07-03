<script lang="ts">
	import Badges from '$lib/Badges.svelte';
	import { formatDate } from '$lib/format';

	let { data } = $props();
	const creator = $derived(data.creator);
	const listings = $derived(data.listings);
	const stats = $derived(data.stats);

	// Same staleness thresholds as the listing detail page (PRODUCT.md §7 Q3): soft warning at
	// 60-179 days since last update, hard flag at 180+.
	const statsDaysSinceUpdate = $derived(
		stats?.performance_stats_updated_at
			? Math.floor((Date.now() - new Date(stats.performance_stats_updated_at).getTime()) / (1000 * 60 * 60 * 24))
			: null
	);
	const statsStaleness = $derived(
		statsDaysSinceUpdate == null ? null : statsDaysSinceUpdate >= 180 ? 'hard' : statsDaysSinceUpdate >= 60 ? 'soft' : 'fresh'
	);
	const hasStatsToShow = $derived(
		!!stats?.performance_stats &&
			(stats.performance_stats.avg_views_per_post != null || stats.performance_stats.engagement_rate_pct != null)
	);
</script>

<svelte:head>
	<title>{creator.display_name} · CreatorConnect</title>
</svelte:head>

<div class="container media-kit">
	<div class="card profile-card">
		<div class="row" style="align-items:center; gap:16px;">
			<span class="avatar-lg">{creator.display_name?.[0]?.toUpperCase() ?? '?'}</span>
			<div>
				<h1 style="margin:0;">{creator.display_name}</h1>
				{#if creator.handle}<div class="muted">{creator.handle}</div>{/if}
			</div>
		</div>

		<div class="row" style="gap:8px; flex-wrap:wrap; margin-top:16px;">
			{#if creator.follower_count}
				<span class="badge badge-neutral">{creator.follower_count.toLocaleString()} followers</span>
			{/if}
			{#each creator.niche_tags ?? [] as tag (tag)}
				<span class="badge badge-neutral">{tag}</span>
			{/each}
		</div>

		<div class="muted" style="margin-top:14px; font-size:13px;">
			{#if creator.completed_deals_count > 0}
				{creator.completed_deals_count} completed deal{creator.completed_deals_count === 1 ? '' : 's'} on CreatorConnect
			{:else}
				New to CreatorConnect
			{/if}
		</div>
	</div>

	{#if hasStatsToShow && stats}
		<div class="section-title">Performance</div>
		<div class="card">
			<div class="grid">
				{#if stats.performance_stats.avg_views_per_post != null}
					<div class="kv"><span class="muted">Avg. views per post</span><strong>{Number(stats.performance_stats.avg_views_per_post).toLocaleString()}</strong></div>
				{/if}
				{#if stats.performance_stats.engagement_rate_pct != null}
					<div class="kv"><span class="muted">Engagement rate</span><strong>{stats.performance_stats.engagement_rate_pct}%</strong></div>
				{/if}
			</div>
			{#if statsStaleness === 'soft'}
				<span class="badge badge-stale-soft" style="margin-top:8px;">Stats last updated {formatDate(stats.performance_stats_updated_at)} — may be outdated</span>
			{:else if statsStaleness === 'hard'}
				<span class="badge badge-stale-hard" style="margin-top:8px;">Stats last updated {formatDate(stats.performance_stats_updated_at)} — likely outdated</span>
			{/if}
		</div>
	{/if}

	<div class="section-title">Currently open on CreatorConnect</div>
	{#if listings.length === 0}
		<div class="empty">No open listings right now — check back soon.</div>
	{:else}
		<div class="grid">
			{#each listings as l (l.id)}
				<a class="card listing-card" href={`/listings/${l.id}`}>
					<Badges mechanism={l.pricing_mechanism} />
					<strong style="display:block; margin-top:8px;">{l.content_type} on {l.platform}</strong>
					<div class="muted" style="font-size:13px; margin-top:4px;">{l.availability_window}</div>
				</a>
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
	.kv {
		display: flex;
		justify-content: space-between;
		font-size: 14px;
		padding: 6px 0;
		border-bottom: 1px solid var(--border);
	}
	.kv:last-child {
		border-bottom: none;
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
