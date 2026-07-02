<script lang="ts">
	import { formatMoney, formatDate, formatDateTime, mechanismLabel } from '$lib/format';

	let { data } = $props();
	const deal = $derived(data.deal);

	const bookingPortion = $derived(deal ? Math.round(deal.final_price_cents * 0.5) : 0);
	const deliveryPortion = $derived(deal ? deal.final_price_cents - Math.round(deal.final_price_cents * 0.5) : 0);
	const platformFeeRate = 0.15;
	const platformFee = $derived(deal ? Math.round(deal.final_price_cents * platformFeeRate) : 0);
</script>

<div class="container narrow">
	{#if !deal}
		<div class="empty">No confirmed deal found.</div>
	{:else}
		<a href={`/listings/${deal.listing_id}`} class="back-link">&larr; Back to listing</a>

		<div class="contract card">
			<div class="contract-header">
				<div>
					<span class="badge" style="background:#dce8fd; color:var(--accent-dark);">Deal Confirmed</span>
					<h1 style="margin: 8px 0 0;">Sponsorship Agreement</h1>
					<p class="muted" style="margin-top:4px;">
						Reached via Mechanism {deal.listing?.pricing_mechanism} — {mechanismLabel[deal.listing?.pricing_mechanism as 'A' | 'C' | 'D']}
					</p>
				</div>
			</div>

			<hr class="sep" />

			<div class="parties">
				<div>
					<div class="section-title" style="margin-top:0;">Creator</div>
					<strong>{deal.creator?.display_name}</strong>
					<div class="muted">{deal.creator?.handle ?? ''}</div>
				</div>
				<div>
					<div class="section-title" style="margin-top:0;">Advertiser</div>
					<strong>{deal.advertiser?.display_name}</strong>
				</div>
			</div>

			<hr class="sep" />

			<div class="section-title" style="margin-top:0;">Deliverable</div>
			<p>{deal.deliverable_spec?.description ?? ''}</p>
			<div class="kv"><span class="muted">Platform</span><strong>{deal.listing?.platform}</strong></div>
			<div class="kv"><span class="muted">Content type</span><strong>{deal.listing?.content_type}</strong></div>
			{#if deal.delivery_due_at}
				<div class="kv"><span class="muted">Delivery date</span><strong>{formatDate(deal.delivery_due_at)}</strong></div>
			{/if}
			<div class="kv"><span class="muted">Disclosure requirement</span><strong>{deal.disclosure_terms}</strong></div>

			<div class="section-title">Pricing</div>
			<div class="kv"><span class="muted">Total price</span><strong>{formatMoney(deal.final_price_cents)}</strong></div>
			<div class="kv"><span class="muted">Due at booking confirmation (50%)</span><strong>{formatMoney(bookingPortion)}</strong></div>
			<div class="kv"><span class="muted">Released on delivery (50%)</span><strong>{formatMoney(deliveryPortion)}</strong></div>
			<div class="kv"><span class="muted">Platform fee (15%, deducted at payout)</span><strong>{formatMoney(platformFee)}</strong></div>

			<div class="section-title">Terms</div>
			<div class="kv"><span class="muted">Status</span><strong>{deal.status}</strong></div>
			<div class="kv"><span class="muted">Confirmed</span><strong>{formatDateTime(deal.confirmed_at)}</strong></div>

			<hr class="sep" />
			<p class="muted" style="font-size:12px;">
				Escrow/Stripe Connect isn't wired up yet (roadmap Phase 0 items 0.4/0.5) — this reflects the
				real <code>deals</code> row, but no payment has actually moved.
			</p>
		</div>
	{/if}
</div>

<style>
	.narrow {
		max-width: 640px;
	}
	.back-link {
		font-size: 13px;
	}
	.contract {
		margin-top: 16px;
	}
	.parties {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 16px;
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
</style>
