<script lang="ts">
	import { CheckCircle2, Circle, Clock } from '@lucide/svelte';
</script>

<svelte:head>
	<title>Roadmap — CreatorConnect</title>
</svelte:head>

<div class="container narrow">
	<h1>Roadmap</h1>
	<p class="muted">
		What's actually live today, and what's next. CreatorConnect ships one mechanism at a time —
		mechanism D (reserve-the-slot) came first because it's the richest and riskiest one to get
		right; the rest builds on a proven pattern rather than three at once.
	</p>

	<div class="section-title" style="margin-top:32px;">Live now</div>
	<div class="stack">
		<div class="milestone done">
			<CheckCircle2 size={18} />
			<div>
				<strong>Browse, create, and manage listings</strong>
				<p class="muted">All three pricing mechanisms (A/C/D) are listable, with a real mechanism picker and explainer copy at creation time.</p>
			</div>
		</div>
		<div class="milestone done">
			<CheckCircle2 size={18} />
			<div>
				<strong>Mechanism D — reserve-the-slot, end to end</strong>
				<p class="muted">Concurrency-safe reservations, creator price confirmation, a generated contract, delivery sign-off, and dispute flagging.</p>
			</div>
		</div>
		<div class="milestone done">
			<CheckCircle2 size={18} />
			<div>
				<strong>Manager delegation</strong>
				<p class="muted">Creators can grant managers access, set a per-listing auto-accept price band, and revoke at any time.</p>
			</div>
		</div>
		<div class="milestone done">
			<CheckCircle2 size={18} />
			<div>
				<strong>Mechanisms A and C, fully live</strong>
				<p class="muted">Fixed-price-and-counter and reserve-the-relationship both have real negotiation flows end to end, same as mechanism D.</p>
			</div>
		</div>
		<div class="milestone done">
			<CheckCircle2 size={18} />
			<div>
				<strong>Scheduled automation</strong>
				<p class="muted">Stale reservations auto-expire, delivered deals auto-release after the hold window, and mechanism C's exclusivity grants auto-expire — all via scheduled jobs.</p>
			</div>
		</div>
	</div>

	<div class="section-title">In progress</div>
	<div class="stack">
		<div class="milestone">
			<Clock size={18} />
			<div>
				<strong>Real payments</strong>
				<p class="muted">Stripe Connect integration — deposits, split payouts, and escrow are currently simulated in the data model, not real money movement yet.</p>
			</div>
		</div>
	</div>

	<div class="section-title">Later</div>
	<div class="stack">
		<div class="milestone">
			<Circle size={18} />
			<div>
				<strong>Sealed-bid tiebreaker</strong>
				<p class="muted">For the rare case where two advertisers reserve the same slot at once — deliberately deferred until real contention data exists to design against.</p>
			</div>
		</div>
		<div class="milestone">
			<Circle size={18} />
			<div>
				<strong>Automated performance stats</strong>
				<p class="muted">Pulling follower counts and engagement directly from YouTube/Instagram/TikTok instead of manual entry.</p>
			</div>
		</div>
		<div class="milestone">
			<Circle size={18} />
			<div>
				<strong>Secondary market, AI-assisted pricing, and beyond</strong>
				<p class="muted">Longer-horizon ideas that need real usage data first.</p>
			</div>
		</div>
	</div>
</div>

<style>
	.narrow {
		max-width: 640px;
	}
	.milestone {
		display: flex;
		gap: 12px;
		align-items: flex-start;
		padding: 12px 0;
		border-bottom: 1px solid var(--border);
	}
	.milestone:last-child {
		border-bottom: none;
	}
	.milestone :global(svg) {
		flex-shrink: 0;
		margin-top: 2px;
		color: var(--text-muted);
	}
	.milestone.done :global(svg) {
		color: var(--green);
	}
	.milestone strong {
		display: block;
		margin-bottom: 2px;
	}
	.milestone p {
		margin: 0;
		font-size: 13px;
	}
</style>
