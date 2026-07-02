<script lang="ts">
	import { page } from '$app/state';
	import { goto, invalidateAll } from '$app/navigation';
	import { formatMoney, formatDateTime, formatDate, mechanismShortExplainer } from '$lib/format';
	import Badges from '$lib/Badges.svelte';

	let { data } = $props();

	const listing = $derived(data.listing);
	const reservation = $derived(data.reservation);
	const user = $derived(page.data.user);
	const profile = $derived(page.data.profile);
	const supabase = $derived(page.data.supabase);

	// Real delegation check (direct ownership OR an active manager_creator_links row), computed
	// server-side in +page.server.ts — matches confirm_deal_as's own is_authorized_for_creator logic,
	// so a legitimately linked manager sees the same confirm/manage actions the creator does.
	const isOwnerOrManager = $derived(
		(!!user && !!listing && user.id === listing.creator_id) || data.isDelegatedManager
	);
	const isAdvertiser = $derived(profile?.role === 'advertiser');

	let showReserveConfirm = $state(false);
	let reserving = $state(false);
	let reserveErr = $state('');

	async function doReserve() {
		if (!listing || !supabase) return;
		reserving = true;
		reserveErr = '';
		const { error } = await supabase.rpc('place_reservation', { p_listing_id: listing.id });
		reserving = false;
		showReserveConfirm = false;
		if (error) {
			reserveErr = error.message;
			return;
		}
		await invalidateAll();
	}

	let confirmedPrice = $state('');
	let confirming = $state(false);
	let confirmErr = $state('');

	async function doConfirmPrice() {
		if (!listing || !reservation || !supabase || !confirmedPrice) return;
		confirming = true;
		confirmErr = '';
		const { data: deal, error } = await supabase.rpc('confirm_deal_as', {
			p_creator_id: listing.creator_id,
			p_reservation_id: reservation.id,
			p_price_cents: Math.round(Number(confirmedPrice) * 100)
		});
		confirming = false;
		if (error) {
			confirmErr = error.message;
			return;
		}
		goto(`/deal/${deal.id}`);
	}
</script>

<div class="container">
	{#if !listing}
		<div class="empty">Listing not found.</div>
	{:else}
		<a href="/" class="back-link">&larr; Back to listings</a>

		<div class="row" style="justify-content: space-between; align-items: flex-start; margin: 10px 0 4px;">
			<div>
				<h1 style="margin-bottom:4px;">{listing.creator?.display_name} — {listing.content_type} on {listing.platform}</h1>
				<div class="muted">
					{listing.creator?.handle ?? ''} · {(listing.creator?.follower_count ?? 0).toLocaleString()} followers
					{#if listing.creator?.niche_tags?.length}
						· {listing.creator.niche_tags.join(', ')}
					{/if}
				</div>
			</div>
			<div class="row">
				<Badges mechanism={listing.pricing_mechanism} />
				<Badges status={listing.status} />
			</div>
		</div>

		{#if data.isDelegatedManager}
			<div class="acting-banner">Acting as {profile?.display_name} on behalf of {listing.creator?.display_name}</div>
		{/if}

		{#if listing.status === 'deal'}
			<div class="deal-banner">This listing is a confirmed deal.</div>
		{/if}

		<div class="detail-grid">
			<div class="stack">
				<div class="card">
					<h3 style="margin-top:0;">Listing details</h3>
					<p>{listing.description}</p>
					<div class="kv"><span class="muted">Availability window</span><strong>{listing.availability_window}</strong></div>
					<div class="kv"><span class="muted">Platform</span><strong>{listing.platform}</strong></div>
					<div class="kv"><span class="muted">Content type</span><strong>{listing.content_type}</strong></div>
					{#if listing.pricing_mechanism === 'A'}
						<div class="kv"><span class="muted">Asking price</span><strong>{formatMoney(listing.floor_price_cents ?? 0)}</strong></div>
					{:else if listing.pricing_mechanism === 'C'}
						<div class="kv"><span class="muted">Exclusivity window</span><strong>{listing.exclusivity_window}</strong></div>
						{#if listing.rate_card_low_cents && listing.rate_card_high_cents}
							<div class="kv"><span class="muted">Rate-card range (context)</span><strong>{formatMoney(listing.rate_card_low_cents)}–{formatMoney(listing.rate_card_high_cents)}</strong></div>
						{/if}
					{:else if listing.pricing_mechanism === 'D'}
						<div class="kv"><span class="muted">Floor price</span><strong>{formatMoney(listing.floor_price_cents ?? 0)}</strong></div>
						<div class="kv"><span class="muted">Reservation deadline</span><strong>{formatDate(listing.reservation_deadline ?? '')}</strong></div>
					{/if}
				</div>

				<div class="card explainer">
					<strong>How Mechanism {listing.pricing_mechanism} works:</strong>
					<p class="muted" style="margin:6px 0 0;">{mechanismShortExplainer[listing.pricing_mechanism as 'A' | 'C' | 'D']}</p>
				</div>
			</div>

			<div class="stack">
				{#if listing.pricing_mechanism === 'D'}
					<div class="card">
						<h3 style="margin-top:0;">Reservation status</h3>
						<div class="kv"><span class="muted">Floor price</span><strong>{formatMoney(listing.floor_price_cents ?? 0)}</strong></div>
						<div class="kv"><span class="muted">Reservation deadline</span><strong>{formatDate(listing.reservation_deadline ?? '')}</strong></div>

						{#if !reservation || reservation.status === 'expired' || reservation.status === 'cancelled'}
							<hr class="sep" />
							{#if !user}
								<p class="muted">Open — <a href="/login">sign in</a> to reserve this slot.</p>
							{:else if isOwnerOrManager}
								<p class="muted">Open — no reservation placed yet.</p>
							{:else}
								<p class="muted">Open — no reservation placed yet.</p>
								<button class="btn btn-primary" onclick={() => (showReserveConfirm = true)}>Reserve this slot</button>
								{#if showReserveConfirm}
									<div class="confirm-box">
										<p style="margin-top:0;">
											Confirm reservation: pay a {formatMoney(Math.round((listing.floor_price_cents ?? 0) * 0.1))} deposit
											(10% of floor price) to lock this slot. Non-refundable if the creator confirms within the response window.
										</p>
										<div class="row">
											<button class="btn btn-primary btn-sm" onclick={doReserve} disabled={reserving}>
												{reserving ? 'Reserving…' : 'Confirm & pay deposit'}
											</button>
											<button class="btn btn-sm" onclick={() => (showReserveConfirm = false)}>Cancel</button>
										</div>
									</div>
								{/if}
								{#if reserveErr}<p class="warn">{reserveErr}</p>{/if}
							{/if}
						{:else}
							<hr class="sep" />
							<div class="kv"><span class="muted">Reserved by</span><strong>{reservation.advertiser?.display_name}</strong></div>
							<div class="kv"><span class="muted">Deposit (10% of floor)</span><strong>{formatMoney(reservation.deposit_amount_cents ?? 0)}</strong></div>
							<div class="kv"><span class="muted">Response deadline</span><strong>{formatDateTime(reservation.confirmation_deadline)}</strong></div>
							<div class="kv"><span class="muted">Status</span><strong>{reservation.status === 'confirmed' ? 'Confirmed' : 'Awaiting creator confirmation'}</strong></div>

							{#if reservation.status === 'held' && isOwnerOrManager}
								<hr class="sep" />
								<p class="muted" style="font-size:13px;">Confirm the final price (must be at or above the floor price):</p>
								<div class="field">
									<label for="final-price">Final price ($)</label>
									<input id="final-price" type="number" min={(listing.floor_price_cents ?? 0) / 100} bind:value={confirmedPrice} placeholder={String((listing.floor_price_cents ?? 0) / 100)} />
								</div>
								<button class="btn btn-primary btn-sm" onclick={doConfirmPrice} disabled={!confirmedPrice || confirming}>
									{confirming ? 'Confirming…' : 'Confirm final price'}
								</button>
								{#if confirmErr}<p class="warn">{confirmErr}</p>{/if}
							{:else if reservation.status === 'held'}
								<p class="muted" style="font-size:13px;">Waiting on the creator to confirm the final price.</p>
							{/if}
						{/if}
					</div>
				{:else}
					<div class="card">
						<h3 style="margin-top:0;">{listing.pricing_mechanism === 'A' ? 'Offer thread' : 'Exclusivity status'}</h3>
						<p class="muted">
							Mechanism {listing.pricing_mechanism}'s live negotiation isn't wired up to the real backend yet —
							only mechanism D (reserve-the-slot) is connected so far, per the roadmap's "ship D first"
							sequencing. This mechanism's tables and RLS already exist (<code>listing_offers</code> /
							<code>listing_exclusivity_grants</code>), just not the RPCs yet.
						</p>
					</div>
				{/if}
			</div>
		</div>
	{/if}
</div>

<style>
	.back-link {
		font-size: 13px;
	}
	.deal-banner {
		background: #dce8fd;
		color: var(--accent-dark);
		padding: 10px 12px;
		border-radius: var(--radius);
		font-size: 14px;
		margin: 12px 0;
	}
	.acting-banner {
		background: var(--purple-bg);
		color: var(--purple);
		padding: 8px 12px;
		border-radius: var(--radius);
		font-size: 13px;
		font-weight: 600;
		margin: 12px 0;
	}
	.detail-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 20px;
		margin-top: 16px;
	}
	@media (max-width: 760px) {
		.detail-grid {
			grid-template-columns: 1fr;
		}
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
	.explainer {
		background: #fafafe;
	}
	.confirm-box {
		margin-top: 12px;
		padding: 12px;
		border: 1px solid var(--border);
		border-radius: 8px;
		background: #fafafe;
		font-size: 13px;
	}
	.warn {
		color: #b91c1c;
		font-size: 13px;
	}
</style>
