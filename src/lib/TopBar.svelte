<script lang="ts">
	import { page } from '$app/state';
	import { Sparkles, CircleQuestionMark, MessageSquare, Bell } from '@lucide/svelte';
	import FeedbackModal from '$lib/FeedbackModal.svelte';
	import { formatDateTime } from '$lib/format';

	const user = $derived(page.data.user);
	const profile = $derived(page.data.profile);
	const supabase = $derived(page.data.supabase);
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
		feedback: 'Feedback',
		'audit-log': 'Audit Log',
		settings: 'Settings',
		managers: 'Managers',
		org: 'Org',
		roadmap: 'Roadmap',
		login: 'Sign in',
		c: 'Creator Profile',
		u: 'Profile'
	};

	// For an unrecognized (dynamic id) segment, what generic label to show
	// given the preceding known segment. `null` means: drop it, the parent
	// label already tells the story.
	const dynamicChildLabel: Record<string, string | null> = {
		deal: null,
		disputes: 'Deal',
		listings: 'Detail',
		c: null,
		u: null,
		org: null
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

	// Synced from page.data on every load (nav, or a full reload after an RPC call writes a fresh
	// row) — see +layout.server.ts. Kept as local state, not a $derived alias, so mark-as-read can
	// update it optimistically without waiting on a full page.data refresh.
	let notifications = $state<any[]>([]);
	$effect(() => {
		notifications = page.data.notifications ?? [];
	});
	const unreadCount = $derived(notifications.filter((n) => !n.read_at).length);

	function notificationHref(n: any): string {
		if (n.payload?.deal_id) return `/deal/${n.payload.deal_id}`;
		if (n.payload?.listing_id) return `/listings/${n.payload.listing_id}`;
		// A showcase proposal notifies the CREATOR, who has no /settings/org page (org affiliation is
		// advertiser/manager-only) — their response lives on /settings/managers instead. Every other
		// org_id-carrying type is org-member-facing.
		if (n.type === 'org_showcase.proposed') return '/settings/managers';
		if (n.payload?.org_id) return '/settings/org';
		return '#';
	}

	async function markRead(n: any) {
		if (n.read_at || !supabase) return;
		const now = new Date().toISOString();
		notifications = notifications.map((x) => (x.id === n.id ? { ...x, read_at: now } : x));
		await supabase.from('notifications').update({ read_at: now }).eq('id', n.id);
	}

	async function markAllRead() {
		if (!supabase) return;
		const unreadIds = notifications.filter((n) => !n.read_at).map((n) => n.id);
		if (!unreadIds.length) return;
		const now = new Date().toISOString();
		notifications = notifications.map((n) => (n.read_at ? n : { ...n, read_at: now }));
		await supabase.from('notifications').update({ read_at: now }).in('id', unreadIds);
	}
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
			<details class="notif-dropdown">
				<summary class="icon-link notif-summary" aria-label="Notifications">
					<Bell size={16} />
					{#if unreadCount > 0}<span class="notif-badge">{unreadCount}</span>{/if}
				</summary>
				<div class="notif-panel">
					<div class="notif-panel-header">
						<strong>Notifications</strong>
						{#if unreadCount > 0}
							<button class="notif-mark-all" onclick={markAllRead}>Mark all read</button>
						{/if}
					</div>
					{#if notifications.length === 0}
						<div class="notif-empty muted">Nothing yet — you'll see updates here as they happen.</div>
					{:else}
						<div class="notif-list">
							{#each notifications as n (n.id)}
								<a
									class="notif-item"
									class:unread={!n.read_at}
									href={notificationHref(n)}
									onclick={() => markRead(n)}
								>
									<div class="notif-message">{n.payload?.message ?? n.type}</div>
									<div class="notif-time muted">{formatDateTime(n.created_at)}</div>
								</a>
							{/each}
						</div>
					{/if}
				</div>
			</details>

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

	.notif-dropdown {
		position: relative;
	}
	.notif-summary {
		position: relative;
		cursor: pointer;
		list-style: none;
	}
	.notif-summary::-webkit-details-marker {
		display: none;
	}
	.notif-badge {
		position: absolute;
		top: 2px;
		right: 2px;
		min-width: 15px;
		height: 15px;
		padding: 0 3px;
		border-radius: 999px;
		background: var(--red);
		color: #fff;
		font-size: 10px;
		font-weight: 700;
		line-height: 15px;
		text-align: center;
	}
	.notif-panel {
		position: absolute;
		top: calc(100% + 8px);
		right: 0;
		width: 320px;
		max-height: 400px;
		overflow-y: auto;
		background: var(--panel);
		border: 1px solid var(--border);
		border-radius: var(--radius);
		box-shadow: 0 12px 40px rgba(0, 0, 0, 0.4);
		z-index: 80;
	}
	.notif-panel-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 12px 14px;
		border-bottom: 1px solid var(--border);
	}
	.notif-mark-all {
		background: none;
		border: none;
		color: var(--accent);
		font-size: 12px;
		font-weight: 600;
		padding: 0;
	}
	.notif-empty {
		padding: 20px 14px;
		font-size: 13px;
	}
	.notif-list {
		display: flex;
		flex-direction: column;
	}
	.notif-item {
		display: block;
		padding: 10px 14px;
		border-bottom: 1px solid var(--border);
		color: inherit;
	}
	.notif-item:last-child {
		border-bottom: none;
	}
	.notif-item:hover {
		background: var(--panel-raised);
		text-decoration: none;
	}
	.notif-item.unread {
		background: var(--accent-bg);
	}
	.notif-message {
		font-size: 13px;
		line-height: 1.4;
	}
	.notif-time {
		font-size: 11px;
		margin-top: 3px;
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
