<script lang="ts">
	import { CheckCircle2, Circle, Clock, Sparkles, ListFilter } from '@lucide/svelte';

	type Status = 'done' | 'inprogress' | 'later';
	type CategoryKey = 'marketplace' | 'teams' | 'trust' | 'creator' | 'advertiser' | 'payments';

	const categories: Record<CategoryKey, string> = {
		marketplace: 'Marketplace',
		teams: 'Teams & Orgs',
		trust: 'Trust & Safety',
		creator: 'Creator tools',
		advertiser: 'Advertiser tools',
		payments: 'Payments'
	};

	type Milestone = {
		status: Status;
		title: string;
		description: string;
		tags: CategoryKey[];
	};

	const milestones: Milestone[] = [
		{
			status: 'done',
			title: 'Browse, create, and manage listings',
			description:
				'All three pricing mechanisms (A/C/D) are listable, with a real mechanism picker and explainer copy at creation time.',
			tags: ['marketplace']
		},
		{
			status: 'done',
			title: 'Mechanism D — reserve-the-slot, end to end',
			description:
				'Concurrency-safe reservations, creator price confirmation, a generated contract, delivery sign-off, and dispute flagging.',
			tags: ['marketplace']
		},
		{
			status: 'done',
			title: 'Mechanisms A and C, fully live',
			description:
				'Fixed-price-and-counter and reserve-the-relationship both have real negotiation flows end to end, same as mechanism D.',
			tags: ['marketplace']
		},
		{
			status: 'done',
			title: 'Scheduled automation',
			description:
				'Stale reservations auto-expire, delivered deals auto-release after the hold window, and mechanism C exclusivity grants auto-expire — all via scheduled jobs.',
			tags: ['marketplace']
		},
		{
			status: 'done',
			title: 'Cancellation terms, baked into every deal',
			description:
				'Creators set cancellation terms once per listing; every confirmed deal, on any mechanism, carries them forward automatically.',
			tags: ['marketplace']
		},
		{
			status: 'done',
			title: 'Contracts: generated summary, print/PDF, and e-signature',
			description:
				'Every confirmed deal gets a real contract view with deliverables and disclosure/cancellation terms, printable as a PDF, with typed-name e-signature capture for both parties.',
			tags: ['marketplace', 'trust']
		},
		{
			status: 'done',
			title: 'In-app notifications',
			description: 'A live notification bell surfaces every state change that needs a party\'s attention — offers, invites, deliveries, disputes.',
			tags: ['marketplace']
		},
		{
			status: 'done',
			title: 'Manager delegation',
			description:
				'Creators can grant managers access, set a per-listing or default auto-accept price band, and revoke at any time.',
			tags: ['teams', 'creator']
		},
		{
			status: 'done',
			title: 'Manager commission ledger and roster directory',
			description: 'Managers see every delegated deal\'s commission in one ledger, plus a directory of everyone they represent.',
			tags: ['teams']
		},
		{
			status: 'done',
			title: 'Manager private notes',
			description: 'Working notes per represented creator — preferences, history, reminders — fully invisible to the creator, by design.',
			tags: ['teams']
		},
		{
			status: 'done',
			title: 'Public profile pages',
			description:
				'Creators get a media-kit page (rate card, niche tags, follower counts). Advertisers and managers get an individual profile page showing their org affiliation.',
			tags: ['creator', 'advertiser', 'teams']
		},
		{
			status: 'done',
			title: 'Org & team accounts',
			description:
				'Advertisers and managers can create a shared org, get a public org page, and manage a roster of owners/members — the account structure behind agencies and brand teams.',
			tags: ['teams']
		},
		{
			status: 'done',
			title: 'Every advertiser always has an org',
			description:
				'Solo advertisers automatically become the sole owner of their own org at signup — no separate "individual" account type to manage later if they grow a team.',
			tags: ['teams', 'advertiser']
		},
		{
			status: 'done',
			title: 'Invite links for org signup',
			description:
				'An org owner generates a link that lets a teammate join — or create a brand-new account and join in the same step — no manual account provisioning.',
			tags: ['teams']
		},
		{
			status: 'done',
			title: 'Dual-consent agency showcase',
			description:
				'A manager org can propose showcasing a represented creator on its public page — the creator must separately accept before anyone sees it. Neither side can grant consent alone.',
			tags: ['teams', 'creator']
		},
		{
			status: 'done',
			title: 'Advertiser org analytics',
			description:
				'Deal counts, total spend, and a "creators sponsored" breakdown, rolled up across an org\'s whole team — not just one person\'s own deals.',
			tags: ['teams', 'advertiser']
		},
		{
			status: 'done',
			title: 'Advertiser shortlist',
			description: 'Save listings to a private watchlist while comparing options, before committing to a reservation or offer.',
			tags: ['advertiser']
		},
		{
			status: 'done',
			title: 'Admin tools',
			description:
				'Dispute resolution, a feedback inbox, a platform-wide audit log, and an org browser/creation page — all gated to the founder\'s own account.',
			tags: ['trust']
		},
		{
			status: 'inprogress',
			title: 'Real payments',
			description:
				'Stripe Connect integration — deposits, split payouts, and escrow are currently simulated in the data model, not real money movement yet.',
			tags: ['payments']
		},
		{
			status: 'later',
			title: 'Sealed-bid tiebreaker',
			description:
				'For the rare case where two advertisers reserve the same slot at once — deliberately deferred until real contention data exists to design against.',
			tags: ['marketplace']
		},
		{
			status: 'later',
			title: 'Automated performance stats',
			description: 'Pulling follower counts and engagement directly from YouTube/Instagram/TikTok instead of manual entry.',
			tags: ['creator']
		},
		{
			status: 'later',
			title: 'Manager bulk tools',
			description: 'Bulk listing and rate-card edits across a whole roster, once roster size makes one-at-a-time editing real friction.',
			tags: ['teams']
		},
		{
			status: 'later',
			title: 'Secondary market, AI-assisted pricing, and beyond',
			description: 'Longer-horizon ideas that need real usage data first.',
			tags: ['marketplace']
		}
	];

	let activeFilter = $state<'all' | CategoryKey>('all');

	function matches(m: Milestone) {
		return activeFilter === 'all' || m.tags.includes(activeFilter);
	}

	const done = $derived(milestones.filter((m) => m.status === 'done' && matches(m)));
	const inProgress = $derived(milestones.filter((m) => m.status === 'inprogress' && matches(m)));
	const later = $derived(milestones.filter((m) => m.status === 'later' && matches(m)));

	const doneCount = $derived(milestones.filter((m) => m.status === 'done').length);
	const totalCount = milestones.length;
	const progressPct = $derived(Math.round((doneCount / totalCount) * 100));

	const filterOrder = Object.keys(categories) as CategoryKey[];

	const columns: { key: 'done' | 'inprogress' | 'later'; label: string; hint: string }[] = [
		{ key: 'done', label: 'Live now', hint: 'Shipped and in use today' },
		{ key: 'inprogress', label: 'In progress', hint: 'Being built right now' },
		{ key: 'later', label: 'Later', hint: 'Deliberately deferred' }
	];
	const columnItems = $derived({ done, inprogress: inProgress, later });
</script>

<svelte:head>
	<title>Roadmap — CreatorConnect</title>
</svelte:head>

<div class="roadmap-page">
	<div class="hero-glow" aria-hidden="true"></div>

	<section class="container hero">
		<span class="eyebrow"><Sparkles size={12} /> Building in the open</span>
		<h1>Roadmap</h1>
		<p class="lede">
			What's actually live today, and what's next. CreatorConnect ships one mechanism — and one
			role's worth of tooling — at a time, then builds the next layer on a proven pattern rather
			than guessing everything up front.
		</p>

		<div class="progress-block">
			<div class="progress-track">
				<div class="progress-fill" style="width: {progressPct}%"></div>
			</div>
			<div class="progress-label">
				<strong>{doneCount}</strong> of {totalCount} milestones shipped
				<span class="progress-pct">{progressPct}%</span>
			</div>
		</div>
	</section>

	<section class="container filters-section">
		<div class="filters-heading">
			<ListFilter size={14} />
			<span>Filter by area</span>
		</div>
		<div class="filters" role="group" aria-label="Filter roadmap by area">
			<button type="button" class="chip" class:active={activeFilter === 'all'} onclick={() => (activeFilter = 'all')}>
				All
			</button>
			{#each filterOrder as key (key)}
				<button
					type="button"
					class="chip"
					class:active={activeFilter === key}
					onclick={() => (activeFilter = key)}
				>
					{categories[key]}
				</button>
			{/each}
		</div>
	</section>

	<section class="container board">
		{#each columns as col (col.key)}
			{@const items = columnItems[col.key]}
			<div class="board-col">
				<div class="board-col-header">
					<div class="board-col-title status-{col.key}">
						{#if col.key === 'done'}
							<CheckCircle2 size={16} />
						{:else if col.key === 'inprogress'}
							<Clock size={16} />
						{:else}
							<Circle size={16} />
						{/if}
						{col.label}
						<span class="board-col-count">{items.length}</span>
					</div>
					<p class="board-col-hint muted">{col.hint}</p>
				</div>

				<div class="stack milestone-stack">
					{#each items as m (m.title)}
						<div class="milestone milestone-{col.key}">
							<strong>{m.title}</strong>
							<p class="muted">{m.description}</p>
							<div class="milestone-tags">
								{#each m.tags as tag (tag)}
									<span class="tag-pill">{categories[tag]}</span>
								{/each}
							</div>
						</div>
					{/each}
					{#if items.length === 0}
						<p class="empty-note muted">Nothing here for this filter yet.</p>
					{/if}
				</div>
			</div>
		{/each}
	</section>
</div>

<style>
	.roadmap-page {
		position: relative;
		padding-bottom: 60px;
		overflow-x: clip;
	}

	.hero-glow {
		position: absolute;
		top: -140px;
		left: 20%;
		width: 700px;
		height: 460px;
		background: radial-gradient(ellipse at center, var(--accent-bg) 0%, transparent 70%);
		pointer-events: none;
		z-index: 0;
	}

	.hero {
		position: relative;
		z-index: 1;
		padding-top: 72px;
		padding-bottom: 32px;
		max-width: 680px;
	}
	.eyebrow {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		font-size: 12px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: var(--accent-dark);
		background: var(--accent-bg);
		padding: 6px 12px;
		border-radius: 999px;
		margin-bottom: 18px;
		border: 1px solid rgba(99, 102, 241, 0.25);
	}
	.hero h1 {
		font-size: 44px;
		font-weight: 800;
		letter-spacing: -0.03em;
		margin: 0 0 14px;
	}
	.lede {
		font-size: 16px;
		color: var(--text-muted);
		line-height: 1.65;
		margin: 0 0 32px;
	}

	.progress-block {
		display: flex;
		flex-direction: column;
		gap: 10px;
		max-width: 420px;
	}
	.progress-track {
		height: 8px;
		border-radius: 999px;
		background: var(--panel-raised);
		border: 1px solid var(--border);
		overflow: hidden;
	}
	.progress-fill {
		height: 100%;
		background: linear-gradient(90deg, var(--accent-dark), var(--accent));
		border-radius: 999px;
		transition: width 0.4s ease;
	}
	.progress-label {
		font-size: 13px;
		color: var(--text-muted);
		display: flex;
		align-items: center;
		gap: 6px;
	}
	.progress-label strong {
		color: var(--text);
		font-size: 14px;
	}
	.progress-pct {
		margin-left: auto;
		font-weight: 700;
		color: var(--accent-dark);
	}

	.filters-section {
		position: relative;
		z-index: 1;
		padding-top: 8px;
		padding-bottom: 8px;
	}
	.filters-heading {
		display: flex;
		align-items: center;
		gap: 6px;
		font-size: 12px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: var(--text-muted);
		margin-bottom: 12px;
	}
	.filters {
		display: flex;
		flex-wrap: wrap;
		gap: 8px;
	}
	.chip {
		padding: 7px 15px;
		border-radius: 999px;
		border: 1px solid var(--border-strong);
		background: var(--panel);
		color: var(--text-muted);
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		transition: background 0.15s, color 0.15s, border-color 0.15s, transform 0.15s;
	}
	.chip:hover {
		border-color: var(--accent);
		color: var(--text);
		transform: translateY(-1px);
	}
	.chip.active {
		background: var(--accent);
		border-color: var(--accent);
		color: #fff;
	}

	.board {
		position: relative;
		z-index: 1;
		padding-top: 24px;
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 24px;
		align-items: start;
	}
	.board-col {
		display: flex;
		flex-direction: column;
		gap: 16px;
		min-width: 0;
	}
	.board-col-header {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}
	.board-col-title {
		display: flex;
		align-items: center;
		gap: 8px;
		font-size: 14px;
		font-weight: 700;
	}
	.board-col-title.status-done {
		color: var(--green);
	}
	.board-col-title.status-inprogress {
		color: var(--amber);
	}
	.board-col-title.status-later {
		color: var(--text-muted);
	}
	.board-col-count {
		font-size: 11px;
		font-weight: 700;
		background: var(--panel-raised);
		color: var(--text-muted);
		padding: 1px 8px;
		border-radius: 999px;
		margin-left: 2px;
	}
	.board-col-hint {
		font-size: 12px;
		margin: 0;
	}

	.milestone-stack {
		gap: 12px;
	}
	.milestone {
		display: flex;
		flex-direction: column;
		gap: 6px;
		padding: 16px;
		border-radius: 12px;
		background: var(--panel);
		border: 1px solid var(--border);
		border-left: 3px solid var(--border-strong);
		transition: transform 0.15s, border-color 0.15s;
		animation: fade-in 0.25s ease both;
	}
	.milestone:hover {
		transform: translateX(2px);
		border-color: var(--border-strong);
	}
	.milestone-done {
		border-left-color: var(--green);
	}
	.milestone-inprogress {
		border-left-color: var(--amber);
	}
	.milestone-later {
		border-left-color: var(--border-strong);
		opacity: 0.85;
	}
	.milestone strong {
		font-size: 14px;
		line-height: 1.4;
	}
	.milestone p {
		margin: 0;
		font-size: 13px;
		line-height: 1.55;
	}
	.milestone-tags {
		display: flex;
		flex-wrap: wrap;
		gap: 6px;
		margin-top: 4px;
	}
	.tag-pill {
		font-size: 10px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.03em;
		color: var(--text-muted);
		background: var(--panel-raised);
		border: 1px solid var(--border);
		padding: 2px 7px;
		border-radius: 999px;
	}
	.empty-note {
		font-size: 13px;
		padding: 16px;
		text-align: center;
		border: 1px dashed var(--border-strong);
		border-radius: 12px;
	}

	@keyframes fade-in {
		from {
			opacity: 0;
			transform: translateY(4px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	@media (max-width: 860px) {
		.board {
			grid-template-columns: 1fr;
			gap: 32px;
		}
	}

	@media (max-width: 640px) {
		.hero {
			padding-top: 48px;
		}
		.hero h1 {
			font-size: 32px;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.milestone {
			animation: none;
		}
	}
</style>
