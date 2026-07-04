<script lang="ts">
	import { page } from '$app/state';
	import {
		CalendarClock,
		Handshake,
		ShieldCheck,
		ArrowRight,
		Clapperboard,
		Megaphone,
		Users,
		Check,
		Sparkles
	} from '@lucide/svelte';

	const user = $derived(page.data.user);

	type RoleKey = 'creator' | 'advertiser' | 'manager';

	const roles: Record<
		RoleKey,
		{
			label: string;
			icon: typeof Clapperboard;
			tagline: string;
			pitch: string;
			features: string[];
			cta: string;
		}
	> = {
		creator: {
			label: 'Creators',
			icon: Clapperboard,
			tagline: 'Turn your calendar into revenue.',
			pitch:
				"Publish upcoming content slots the way you already plan your calendar. Set your price and your terms — advertisers come to you instead of the other way around.",
			features: [
				'Pick how you sell each slot: fixed price, exclusive first-look, or a deposit-backed reserve',
				'A public media kit visitors can browse — rate card, niche tags, follower counts',
				'Set your disclosure and cancellation terms once, reuse them on every deal',
				"Hand off the busywork to a manager without losing control — set price bands, revoke access anytime"
			],
			cta: 'Sign up as a creator'
		},
		advertiser: {
			label: 'Advertisers',
			icon: Megaphone,
			tagline: "Book real slots, not maybes.",
			pitch:
				'Browse open inventory with pricing terms up front. Lock in the slot before a competitor does, and never wonder who to invoice.',
			features: [
				'Browse and filter live listings by niche, price, and pricing mechanism',
				'Reserve a slot instantly, or negotiate — your call',
				'Every deal converges on one contract: deliverables, disclosure, cancellation terms',
				'Bring your team: create an org, invite teammates, see spend and creators sponsored in one place'
			],
			cta: 'Sign up as an advertiser'
		},
		manager: {
			label: 'Managers / Agencies',
			icon: Users,
			tagline: 'Represent more creators without more chaos.',
			pitch:
				'Manage delegated access across your whole roster from one login — price bands, private notes, and a public showcase that only goes live when both sides agree.',
			features: [
				'Get delegated access from creators, with per-listing or default price bands',
				'Keep private working notes per creator — fully invisible to them',
				'Track commission across every deal in one ledger',
				'Build a team: invite agents or managers under your org with a single link'
			],
			cta: 'Sign up as a manager'
		}
	};

	let activeRole = $state<RoleKey>('creator');
	const active = $derived(roles[activeRole]);
	const roleOrder = Object.keys(roles) as RoleKey[];
</script>

<svelte:head>
	<title>CreatorConnect — reserve tomorrow's sponsorship slots today</title>
</svelte:head>

<div class="landing">
	<div class="hero-glow" aria-hidden="true"></div>

	<section class="hero container">
		<span class="eyebrow"><Sparkles size={12} /> Booking marketplace for creator sponsorships</span>
		<h1>Reserve tomorrow's<br /><span class="accent-text">sponsorship slots</span> today.</h1>
		<p class="lede">
			Creators publish upcoming content slots. Advertisers lock them in before they're gone.
			No cold outreach, no chasing invoices — just a booking marketplace built for how sponsorship
			deals actually happen.
		</p>
		<div class="row hero-actions">
			<a class="btn btn-primary btn-lg" href="/browse">
				Browse the marketplace <ArrowRight size={16} />
			</a>
			{#if !user}
				<a class="btn btn-lg" href="/login">Sign in / Sign up</a>
			{:else}
				<a class="btn btn-lg" href="/dashboard">Go to dashboard</a>
			{/if}
		</div>

		<div class="hero-stats" role="list">
			<div class="hero-stat" role="listitem">
				<strong>3</strong>
				<span>pricing mechanisms live</span>
			</div>
			<div class="hero-stat" role="listitem">
				<strong>0</strong>
				<span>cold DMs required</span>
			</div>
			<div class="hero-stat" role="listitem">
				<strong>1</strong>
				<span>contract per deal, every time</span>
			</div>
		</div>
	</section>

	<section class="container role-explainer">
		<div class="eyebrow-label">Built for every side of the deal</div>
		<h2 class="section-h2">One marketplace, three very different jobs to do.</h2>

		<div class="role-layout">
			<div class="role-tabs" role="tablist" aria-label="Choose a role">
				{#each roleOrder as key (key)}
					{@const role = roles[key]}
					<button
						type="button"
						role="tab"
						aria-selected={activeRole === key}
						class="role-tab"
						class:active={activeRole === key}
						onclick={() => (activeRole = key)}
					>
						<span class="role-tab-icon"><role.icon size={18} /></span>
						<span class="role-tab-label">{role.label}</span>
					</button>
				{/each}
			</div>

			{#key activeRole}
				<div class="card role-panel">
					<div class="role-panel-icon"><active.icon size={24} /></div>
					<h3>{active.tagline}</h3>
					<p class="muted role-pitch">{active.pitch}</p>
					<ul class="role-features">
						{#each active.features as feature (feature)}
							<li><Check size={15} /><span>{feature}</span></li>
						{/each}
					</ul>
					<a class="btn btn-primary" href="/login">{active.cta} <ArrowRight size={16} /></a>
				</div>
			{/key}
		</div>
	</section>

	<section class="container how-it-works">
		<div class="eyebrow-label">How it works</div>
		<h2 class="section-h2">From open slot to signed contract.</h2>
		<div class="steps">
			<div class="step">
				<div class="step-number">01</div>
				<div class="step-icon"><CalendarClock size={22} /></div>
				<h3>Creators publish slots</h3>
				<p class="muted">
					List an upcoming content slot with your availability window, then pick how it gets priced —
					fixed price, exclusive early access, or a reserve-with-deposit hold.
				</p>
			</div>
			<div class="step-connector" aria-hidden="true"></div>
			<div class="step">
				<div class="step-number">02</div>
				<div class="step-icon"><Handshake size={22} /></div>
				<h3>Advertisers lock them in</h3>
				<p class="muted">
					Browse open slots, see the pricing mechanism up front, and secure the ones you want before
					someone else does.
				</p>
			</div>
			<div class="step-connector" aria-hidden="true"></div>
			<div class="step">
				<div class="step-number">03</div>
				<div class="step-icon"><ShieldCheck size={22} /></div>
				<h3>Confirm and deliver</h3>
				<p class="muted">
					Every mechanism converges on the same contract: clear deliverable spec, FTC disclosure
					terms baked in, and a straightforward delivery/dispute flow.
				</p>
			</div>
		</div>
	</section>

	<section class="container mechanisms">
		<div class="eyebrow-label">Three ways to sell a slot</div>
		<h2 class="section-h2">Pick the mechanism that fits the deal.</h2>
		<div class="grid mechanism-grid">
			<div class="card mechanism-card">
				<span class="badge badge-a">Mechanism A</span>
				<h3>Fixed Price + Counter-Offer</h3>
				<p class="muted">Set an asking price. Advertisers accept it or counter — simple, familiar, classifieds-style.</p>
			</div>
			<div class="card mechanism-card">
				<span class="badge badge-c">Mechanism C</span>
				<h3>Reserve-the-Relationship</h3>
				<p class="muted">Give one advertiser exclusive early access to negotiate — no deposit, no binding hold.</p>
			</div>
			<div class="card mechanism-card">
				<span class="badge badge-d">Mechanism D</span>
				<h3>Reserve-the-Slot</h3>
				<p class="muted">A floor price and a deposit-backed hold. The advertiser locks the slot; you confirm the final price.</p>
			</div>
		</div>
	</section>

	<section class="container cta-band">
		<div class="card cta-card">
			<div class="cta-card-glow" aria-hidden="true"></div>
			<div class="cta-card-content">
				<h2>Curious where this is headed?</h2>
				<p class="muted">See what's live today and what's next on the <a href="/roadmap">roadmap</a>.</p>
			</div>
			<a class="btn btn-primary btn-lg" href="/roadmap">
				View roadmap <ArrowRight size={16} />
			</a>
		</div>
	</section>
</div>

<style>
	.landing {
		position: relative;
		padding-bottom: 40px;
		overflow-x: clip;
	}

	.hero-glow {
		position: absolute;
		top: -120px;
		left: 50%;
		transform: translateX(-50%);
		width: min(900px, 150vw);
		height: 500px;
		background: radial-gradient(ellipse at center, var(--accent-bg) 0%, transparent 70%);
		pointer-events: none;
		z-index: 0;
	}

	.hero {
		position: relative;
		z-index: 1;
		padding-top: 96px;
		padding-bottom: var(--mkt-space-section-sm);
		max-width: 760px;
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
		margin-bottom: 22px;
		border: 1px solid rgba(99, 102, 241, 0.25);
		animation: fade-up 0.5s ease both;
	}
	.hero h1 {
		font-size: 56px;
		line-height: 1.08;
		margin: 0 0 20px;
		letter-spacing: -0.03em;
		font-weight: 800;
		animation: fade-up 0.6s ease 0.05s both;
	}
	.accent-text {
		background: linear-gradient(135deg, var(--accent-dark), var(--accent));
		-webkit-background-clip: text;
		background-clip: text;
		color: transparent;
	}
	.lede {
		font-size: 18px;
		color: var(--text-muted);
		line-height: 1.65;
		max-width: 600px;
		animation: fade-up 0.6s ease 0.1s both;
	}
	.hero-actions {
		margin-top: 32px;
		animation: fade-up 0.6s ease 0.15s both;
	}
	.btn-lg {
		padding: 12px 22px;
		font-size: 15px;
	}
	.btn-primary {
		box-shadow: 0 6px 24px -6px rgba(99, 102, 241, 0.55);
		transition: transform 0.15s, box-shadow 0.15s, background 0.12s, border-color 0.12s;
	}
	.btn-primary:hover {
		transform: translateY(-1px);
		box-shadow: 0 10px 28px -6px rgba(99, 102, 241, 0.65);
	}
	.btn {
		transition: transform 0.15s, border-color 0.12s, background 0.12s;
	}
	.btn:not(.btn-primary):hover {
		transform: translateY(-1px);
	}

	.hero-stats {
		display: flex;
		gap: 36px;
		margin-top: 56px;
		flex-wrap: wrap;
		animation: fade-up 0.6s ease 0.2s both;
	}
	.hero-stat {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}
	.hero-stat strong {
		font-size: 28px;
		font-weight: 800;
		letter-spacing: -0.02em;
		color: var(--accent-dark);
	}
	.hero-stat span {
		font-size: 13px;
		color: var(--text-muted);
	}

	@keyframes fade-up {
		from {
			opacity: 0;
			transform: translateY(10px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.eyebrow-label {
		font-size: 13px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		color: var(--accent-dark);
		margin-bottom: 10px;
	}
	.section-h2 {
		font-size: 32px;
		font-weight: 800;
		letter-spacing: -0.02em;
		margin: 0 0 40px;
		max-width: 640px;
		line-height: 1.25;
	}

	.role-explainer {
		position: relative;
		z-index: 1;
		padding-top: var(--mkt-space-section-sm);
	}
	.role-layout {
		display: grid;
		grid-template-columns: 220px 1fr;
		gap: 28px;
		align-items: start;
	}
	.role-tabs {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}
	.role-tab {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 12px 14px;
		border-radius: 12px;
		border: 1px solid transparent;
		background: transparent;
		color: var(--text-muted);
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		text-align: left;
		transition: background 0.15s, color 0.15s, border-color 0.15s;
	}
	.role-tab-icon {
		display: inline-flex;
		flex-shrink: 0;
	}
	.role-tab:hover {
		background: var(--panel);
		color: var(--text);
	}
	.role-tab.active {
		background: var(--accent-bg);
		border-color: rgba(99, 102, 241, 0.3);
		color: var(--accent-dark);
	}
	.role-panel {
		max-width: none;
		padding: 32px;
		animation: fade-up 0.35s ease both;
	}
	.role-panel h3 {
		margin: 0 0 10px;
		font-size: 22px;
		letter-spacing: -0.01em;
	}
	.role-pitch {
		margin: 0 0 22px;
		font-size: 15px;
		line-height: 1.6;
		max-width: 540px;
	}
	.role-panel-icon {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 48px;
		height: 48px;
		border-radius: 12px;
		background: var(--accent-bg);
		color: var(--accent-dark);
		margin-bottom: 18px;
	}
	.role-features {
		margin: 0 0 26px;
		padding: 0;
		list-style: none;
		display: flex;
		flex-direction: column;
		gap: 12px;
		font-size: 14px;
		color: var(--text-muted);
		max-width: 560px;
	}
	.role-features li {
		display: flex;
		align-items: flex-start;
		gap: 10px;
		line-height: 1.5;
	}
	.role-features :global(svg) {
		flex-shrink: 0;
		margin-top: 2px;
		color: var(--green);
	}

	.how-it-works {
		position: relative;
		z-index: 1;
		padding-top: var(--mkt-space-section-sm);
	}
	.steps {
		display: grid;
		grid-template-columns: 1fr auto 1fr auto 1fr;
		gap: 20px;
		align-items: start;
	}
	.step {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}
	.step-number {
		font-size: 13px;
		font-weight: 800;
		color: var(--accent-dark);
		letter-spacing: 0.05em;
	}
	.step-icon {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 44px;
		height: 44px;
		border-radius: 12px;
		background: var(--panel);
		border: 1px solid var(--border);
		color: var(--accent-dark);
		margin-bottom: 4px;
	}
	.step h3 {
		margin: 0;
		font-size: 17px;
	}
	.step p {
		margin: 0;
		font-size: 14px;
		line-height: 1.55;
	}
	.step-connector {
		width: 40px;
		height: 1px;
		background: linear-gradient(90deg, var(--border-strong), transparent);
		margin-top: 22px;
	}

	.mechanisms {
		position: relative;
		z-index: 1;
		padding-top: var(--mkt-space-section-sm);
	}
	.mechanism-grid {
		gap: 20px;
	}
	.mechanism-card {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		gap: 8px;
		padding: 24px;
		transition: transform 0.18s, border-color 0.18s;
	}
	.mechanism-card:hover {
		transform: translateY(-3px);
		border-color: var(--border-strong);
	}
	.mechanism-card h3 {
		margin: 12px 0 2px;
		font-size: 17px;
	}
	.mechanism-card p {
		margin: 0;
		font-size: 14px;
	}

	.cta-band {
		position: relative;
		z-index: 1;
		padding-top: var(--mkt-space-section-sm);
	}
	.cta-card {
		position: relative;
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 24px;
		padding: 40px 44px;
		background: linear-gradient(135deg, var(--panel-raised), var(--panel));
		border-radius: var(--mkt-radius-lg);
		overflow: hidden;
	}
	.cta-card-glow {
		position: absolute;
		top: -60%;
		right: -10%;
		width: 320px;
		height: 320px;
		background: radial-gradient(circle, var(--accent-bg) 0%, transparent 70%);
		pointer-events: none;
	}
	.cta-card-content {
		position: relative;
		z-index: 1;
	}
	.cta-card-content h2 {
		margin: 0 0 6px;
		font-size: 26px;
		letter-spacing: -0.01em;
	}
	.cta-card-content p {
		margin: 0;
		font-size: 15px;
	}
	.cta-card :global(.btn) {
		position: relative;
		z-index: 1;
		flex-shrink: 0;
	}

	@media (max-width: 860px) {
		.steps {
			grid-template-columns: 1fr;
		}
		.step-connector {
			display: none;
		}
		.role-layout {
			grid-template-columns: 1fr;
		}
		.role-tabs {
			flex-direction: row;
			overflow-x: auto;
			padding-bottom: 4px;
			/* A 3rd tab that's wider than the viewport otherwise gets hard-clipped at the edge with no
			   visual cue it's reachable by scrolling — this fade signals "there's more" instead of
			   looking like a rendering bug. */
			mask-image: linear-gradient(to right, black calc(100% - 28px), transparent 100%);
			-webkit-mask-image: linear-gradient(to right, black calc(100% - 28px), transparent 100%);
		}
		.role-tab {
			flex-shrink: 0;
		}
		.role-tab-label {
			white-space: nowrap;
		}
	}

	@media (max-width: 640px) {
		.hero {
			padding-top: 56px;
		}
		.hero h1 {
			font-size: 34px;
		}
		.lede {
			font-size: 16px;
		}
		.section-h2 {
			font-size: 24px;
		}
		.hero-stats {
			gap: 24px;
		}
		.cta-card {
			flex-direction: column;
			align-items: flex-start;
			padding: 28px;
		}
		.role-panel {
			padding: 22px;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.eyebrow,
		.hero h1,
		.lede,
		.hero-actions,
		.hero-stats,
		.role-panel {
			animation: none;
		}
	}
</style>
