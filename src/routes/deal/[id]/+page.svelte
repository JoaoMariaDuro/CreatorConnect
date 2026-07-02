<script lang="ts">
	import { page } from '$app/state';
	import {
		getListing,
		getCreator,
		getAdvertiser,
		formatMoney,
		formatDate,
		formatDateTime,
		mechanismLabel
	} from '$lib/store.svelte';

	const listing = $derived(getListing(page.params.id ?? ''));
	const creator = $derived(listing ? getCreator(listing.creatorId) : undefined);
	const advertiser = $derived(listing?.deal ? getAdvertiser(listing.deal.advertiserId) : undefined);

	const bookingPortion = $derived(listing?.deal ? Math.round(listing.deal.price * 0.5) : 0);
	const deliveryPortion = $derived(listing?.deal ? listing.deal.price - Math.round(listing.deal.price * 0.5) : 0);
	const platformFeeRate = 0.15;
	const platformFee = $derived(listing?.deal ? Math.round(listing.deal.price * platformFeeRate) : 0);
</script>

<div class="container narrow">
	{#if !listing || !listing.deal || !creator}
		<div class="empty">No confirmed deal found for this listing.</div>
	{:else}
		{@const deal = listing.deal}
		<a href={`/listings/${listing.id}`} class="back-link">&larr; Back to listing</a>

		<div class="contract card">
			<div class="contract-header">
				<div>
					<span class="badge" style="background:#dce8fd; color:var(--accent-dark);">Deal Confirmed</span>
					<h1 style="margin: 8px 0 0;">Sponsorship Agreement</h1>
					<p class="muted" style="margin-top:4px;">
						Reached via Mechanism {deal.mechanism} — {mechanismLabel[deal.mechanism]}
					</p>
				</div>
			</div>

			<hr class="sep" />

			<div class="parties">
				<div>
					<div class="section-title" style="margin-top:0;">Creator</div>
					<strong>{creator.name}</strong>
					<div class="muted">{creator.handle} · {creator.platforms.join(', ')}</div>
				</div>
				<div>
					<div class="section-title" style="margin-top:0;">Advertiser</div>
					<strong>{advertiser?.company}</strong>
					<div class="muted">{advertiser?.contactName}</div>
				</div>
			</div>

			<hr class="sep" />

			<div class="section-title" style="margin-top:0;">Deliverable</div>
			<p>{deal.deliverySpec}</p>
			<div class="kv"><span class="muted">Platform</span><strong>{listing.platform}</strong></div>
			<div class="kv"><span class="muted">Content type</span><strong>{listing.contentType}</strong></div>
			<div class="kv"><span class="muted">Delivery date</span><strong>{formatDate(deal.deliveryDate)}</strong></div>
			<div class="kv"><span class="muted">Disclosure requirement</span><strong>#ad / FTC-compliant disclosure required</strong></div>

			<div class="section-title">Pricing</div>
			<div class="kv"><span class="muted">Total price</span><strong>{formatMoney(deal.price)}</strong></div>
			<div class="kv"><span class="muted">Due at booking confirmation (50%)</span><strong>{formatMoney(bookingPortion)}</strong></div>
			<div class="kv"><span class="muted">Released on delivery (50%)</span><strong>{formatMoney(deliveryPortion)}</strong></div>
			<div class="kv"><span class="muted">Platform fee (15%, deducted at payout)</span><strong>{formatMoney(platformFee)}</strong></div>

			<div class="section-title">Terms</div>
			<div class="kv"><span class="muted">Cancellation</span><strong>Standard escrow terms — dispute freezes remaining balance</strong></div>
			<div class="kv"><span class="muted">Confirmed</span><strong>{formatDateTime(deal.confirmedAt)}</strong></div>

			<hr class="sep" />
			<p class="muted" style="font-size:12px;">
				This is a prototype summary screen — no PDF generation, escrow, or payment processing occurs. In production this
				would be a generated contract with Stripe Connect escrow behind it.
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
