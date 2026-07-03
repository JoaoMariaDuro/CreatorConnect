<script lang="ts">
	import { page } from '$app/state';
	import { Sparkles, CircleQuestionMark, MessageSquare } from '@lucide/svelte';
	import FeedbackModal from '$lib/FeedbackModal.svelte';

	const user = $derived(page.data.user);
	const profile = $derived(page.data.profile);
	const path = $derived(page.url.pathname);

	// v1-simple route-based breadcrumb: a static lookup from known path
	// segments to friendly labels. Dynamic/unknown segments (ids etc.) don't
	// get resolved to real entity names (no data-fetching here) — they're
	// either dropped (when the static parent segment already says enough,
	// e.g. /deal/xyz -> just "Deal") or shown as a small generic trailing
	// label keyed off the parent segment (e.g. /admin/disputes/xyz -> "...
	// / Deal", /listings/xyz -> "... / Detail").
	const segmentLabels: Record<string, string> = {
		browse: 'Browse',
		dashboard: 'Dashboard',
		create: 'Create Listing',
		listings: 'Listings',
		deal: 'Deal',
		admin: 'Admin',
		disputes: 'Disputes',
		settings: 'Settings',
		managers: 'Managers',
		roadmap: 'Roadmap',
		login: 'Sign in'
	};

	// For an unrecognized (dynamic id) segment, what generic label to show
	// given the preceding known segment. `null` means: drop it, the parent
	// label already tells the story.
	const dynamicChildLabel: Record<string, string | null> = {
		deal: null,
		disputes: 'Deal',
		listings: 'Detail'
	};

	const breadcrumb = $derived.by(() => {
		const segments = path.split('/').filter(Boolean);
		const crumbs: string[] = [];
		let prevRaw = '';
		for (const seg of segments) {
			const known = segmentLabels[seg];
			if (known) {
				crumbs.push(known);
			} else {
				const label = prevRaw in dynamicChildLabel ? dynamicChildLabel[prevRaw] : 'Detail';
				if (label) crumbs.push(label);
			}
			prevRaw = seg;
		}
		return crumbs;
	});

	let feedbackOpen = $state(false);
</script>

<header class="topbar">
	<div class="topbar-left">
		<a class="logo" href="/">
			<Sparkles size={20} />
			<span>CreatorConnect</span>
		</a>
		{#if breadcrumb.length > 0}
			<nav class="breadcrumb" aria-label="Breadcrumb">
				{#each breadcrumb as crumb, i (i)}
					<span class="crumb">{crumb}</span>
					{#if i < breadcrumb.length - 1}<span class="sep">/</span>{/if}
				{/each}
			</nav>
		{/if}
	</div>

	<div class="topbar-right">
		<a class="icon-link" href="/roadmap" title="Help">
			<CircleQuestionMark size={16} />
			<span>Help</span>
		</a>

		{#if user}
			<button class="icon-link" onclick={() => (feedbackOpen = true)}>
				<MessageSquare size={16} />
				<span>Feedback</span>
			</button>
		{/if}

		{#if user && profile}
			<div class="identity" title={profile.display_name}>
				<span class="avatar">{profile.display_name?.[0]?.toUpperCase() ?? '?'}</span>
				<span class="identity-name">{profile.display_name}</span>
			</div>
		{:else if !user}
			<a class="icon-link" href="/login">Sign in</a>
		{/if}
	</div>
</header>

{#if feedbackOpen}
	<FeedbackModal onClose={() => (feedbackOpen = false)} />
{/if}

<style>
	.topbar {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		height: var(--topbar-h);
		z-index: 70;
		background: var(--panel);
		border-bottom: 1px solid var(--border);
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0 16px;
		gap: 16px;
	}
	.topbar-left {
		display: flex;
		align-items: center;
		gap: 14px;
		min-width: 0;
		overflow: hidden;
	}
	.logo {
		display: flex;
		align-items: center;
		gap: 8px;
		font-weight: 800;
		font-size: 15px;
		color: var(--text);
		white-space: nowrap;
		flex-shrink: 0;
	}
	.logo:hover {
		text-decoration: none;
	}
	.breadcrumb {
		display: flex;
		align-items: center;
		gap: 6px;
		font-size: 13px;
		color: var(--text-muted);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		border-left: 1px solid var(--border);
		padding-left: 14px;
	}
	.crumb {
		white-space: nowrap;
	}
	.sep {
		color: var(--border-strong);
	}
	.topbar-right {
		display: flex;
		align-items: center;
		gap: 6px;
		flex-shrink: 0;
	}
	.icon-link {
		display: flex;
		align-items: center;
		gap: 6px;
		background: none;
		border: none;
		color: var(--text-muted);
		font-size: 13px;
		font-weight: 500;
		padding: 6px 10px;
		border-radius: 8px;
	}
	.icon-link:hover {
		background: var(--panel-raised);
		color: var(--text);
		text-decoration: none;
	}
	.identity {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 4px 10px 4px 4px;
		border-radius: 999px;
		background: var(--panel-raised);
		border: 1px solid var(--border);
		margin-left: 4px;
	}
	.avatar {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 24px;
		height: 24px;
		border-radius: 50%;
		background: var(--accent-bg);
		color: var(--accent-dark);
		font-size: 12px;
		font-weight: 700;
		flex-shrink: 0;
	}
	.identity-name {
		font-size: 13px;
		font-weight: 600;
		color: var(--text);
		white-space: nowrap;
		max-width: 140px;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	@media (max-width: 640px) {
		.identity-name,
		.icon-link span {
			display: none;
		}
		.breadcrumb {
			display: none;
		}
	}
</style>
