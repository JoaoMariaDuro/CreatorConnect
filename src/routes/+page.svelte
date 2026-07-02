<script lang="ts">
	import { page } from '$app/state';
	import { CalendarClock, Handshake, ShieldCheck, ArrowRight } from '@lucide/svelte';

	const user = $derived(page.data.user);
</script>

<svelte:head>
	<title>CreatorConnect — reserve tomorrow's sponsorship slots today</title>
</svelte:head>

<div class="landing">
	<section class="hero container">
		<span class="eyebrow">Booking marketplace for creator sponsorships</span>
		<h1>Reserve tomorrow's sponsorship slots today.</h1>
		<p class="lede">
			Creators publish upcoming content slots. Advertisers lock them in before they're gone.
			No cold outreach, no chasing invoices — just a booking marketplace built for how sponsorship
			deals actually happen.
		</p>
		<div class="row" style="margin-top: 24px;">
			<a class="btn btn-primary btn-lg" href="/browse">
				Browse the marketplace <ArrowRight size={16} />
			</a>
			{#if !user}
				<a class="btn btn-lg" href="/login">Sign in / Sign up</a>
			{:else}
				<a class="btn btn-lg" href="/dashboard">Go to dashboard</a>
			{/if}
		</div>
	</section>

	<section class="container">
		<div class="section-title" style="margin-top:0;">How it works</div>
		<div class="grid">
			<div class="card feature">
				<CalendarClock size={22} />
				<h3>Creators publish slots</h3>
				<p class="muted">
					List an upcoming content slot with your availability window, then pick how it gets priced —
					fixed price, exclusive early access, or a reserve-with-deposit hold.
				</p>
			</div>
			<div class="card feature">
				<Handshake size={22} />
				<h3>Advertisers lock them in</h3>
				<p class="muted">
					Browse open slots, see the pricing mechanism up front, and secure the ones you want before
					someone else does.
				</p>
			</div>
			<div class="card feature">
				<ShieldCheck size={22} />
				<h3>Confirm and deliver</h3>
				<p class="muted">
					Every mechanism converges on the same contract: clear deliverable spec, FTC disclosure
					terms baked in, and a straightforward delivery/dispute flow.
				</p>
			</div>
		</div>
	</section>

	<section class="container">
		<div class="section-title">Three ways to sell a slot</div>
		<div class="grid">
			<div class="card">
				<span class="badge badge-a">Mechanism A</span>
				<h3 style="margin: 10px 0 4px;">Fixed Price + Counter-Offer</h3>
				<p class="muted" style="font-size:14px;">Set an asking price. Advertisers accept it or counter — simple, familiar, classifieds-style.</p>
			</div>
			<div class="card">
				<span class="badge badge-c">Mechanism C</span>
				<h3 style="margin: 10px 0 4px;">Reserve-the-Relationship</h3>
				<p class="muted" style="font-size:14px;">Give one advertiser exclusive early access to negotiate — no deposit, no binding hold.</p>
			</div>
			<div class="card">
				<span class="badge badge-d">Mechanism D</span>
				<h3 style="margin: 10px 0 4px;">Reserve-the-Slot</h3>
				<p class="muted" style="font-size:14px;">A floor price and a deposit-backed hold. The advertiser locks the slot; you confirm the final price.</p>
			</div>
		</div>
	</section>

	<section class="container cta-band">
		<div class="card cta-card">
			<div>
				<h2 style="margin:0 0 6px;">Curious where this is headed?</h2>
				<p class="muted" style="margin:0;">See what's live today and what's next on the <a href="/roadmap">roadmap</a>.</p>
			</div>
			<a class="btn btn-primary" href="/roadmap">View roadmap</a>
		</div>
	</section>
</div>

<style>
	.landing {
		padding-bottom: 40px;
	}
	.hero {
		padding-top: 72px;
		padding-bottom: 40px;
		max-width: 720px;
	}
	.eyebrow {
		display: inline-block;
		font-size: 12px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: var(--accent-dark);
		background: var(--accent-bg);
		padding: 4px 10px;
		border-radius: 999px;
		margin-bottom: 16px;
	}
	.hero h1 {
		font-size: 42px;
		line-height: 1.15;
		margin: 0 0 16px;
		letter-spacing: -0.02em;
	}
	.lede {
		font-size: 17px;
		color: var(--text-muted);
		line-height: 1.6;
		max-width: 600px;
	}
	.btn-lg {
		padding: 11px 20px;
		font-size: 15px;
	}
	.feature {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}
	.feature :global(svg) {
		color: var(--accent-dark);
		margin-bottom: 4px;
	}
	.feature h3 {
		margin: 0;
		font-size: 16px;
	}
	.feature p {
		margin: 0;
		font-size: 14px;
	}
	.cta-band {
		margin-top: 8px;
	}
	.cta-card {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 16px;
		background: linear-gradient(135deg, var(--panel-raised), var(--panel));
	}
	@media (max-width: 640px) {
		.hero h1 {
			font-size: 30px;
		}
		.cta-card {
			flex-direction: column;
			align-items: flex-start;
		}
	}
</style>
