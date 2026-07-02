<script lang="ts">
	import { page } from '$app/state';
	import { goto } from '$app/navigation';
	import {
		getListing,
		getCreator,
		getAdvertiser,
		getManager,
		viewerState,
		canManageCreator,
		formatMoney,
		formatDateTime,
		formatDate,
		mechanismShortExplainer,
		submitOffer,
		acceptOffer,
		requestExclusivity,
		proposeTerms,
		acceptNegotiation,
		reserveSlot,
		confirmFinalPrice,
		advertisers
	} from '$lib/store.svelte';
	import Badges from '$lib/Badges.svelte';

	const listingId = $derived(page.params.id ?? '');
	const listing = $derived(getListing(listingId));
	const creator = $derived(listing ? getCreator(listing.creatorId) : undefined);
	const viewer = $derived(viewerState.current);

	const isManagingCreator = $derived(listing ? canManageCreator(viewer, listing.creatorId) : false);
	const isAdvertiser = $derived(viewer.role === 'advertiser');
	const managerActingLabel = $derived(
		viewer.role === 'manager' && listing && canManageCreator(viewer, listing.creatorId)
			? `Acting as ${getManager(viewer.id)?.name} on behalf of ${creator?.name}`
			: null
	);

	// as-advertiser identity: if viewer is an advertiser, use their id; otherwise default to first advertiser for demo purposes
	const demoAdvertiserId = $derived(isAdvertiser ? viewer.id : advertisers[0].id);

	// ---- Mechanism A state ----
	let offerAmount = $state('');
	let offerNote = $state('');

	function submitAdvertiserOffer() {
		if (!listing || !offerAmount) return;
		submitOffer(listing, 'advertiser', Number(offerAmount), offerNote, demoAdvertiserId);
		offerAmount = '';
		offerNote = '';
	}

	function submitCreatorCounter() {
		if (!listing || !offerAmount) return;
		submitOffer(listing, 'creator', Number(offerAmount), offerNote);
		offerAmount = '';
		offerNote = '';
	}

	function handleAccept(offer: any) {
		if (!listing) return;
		const advertiserId = (listing as any)._advertiserId ?? demoAdvertiserId;
		acceptOffer(listing, offer, advertiserId);
	}

	// ---- Mechanism C state ----
	let negotiationPrice = $state('');
	let negotiationTerms = $state('');

	function doRequestExclusivity() {
		if (!listing) return;
		requestExclusivity(listing, demoAdvertiserId);
	}

	function submitProposal(from: 'advertiser' | 'creator') {
		if (!listing || !negotiationPrice) return;
		proposeTerms(listing, from, Number(negotiationPrice), negotiationTerms || listing.description);
		negotiationPrice = '';
		negotiationTerms = '';
	}

	function doAcceptNegotiation() {
		if (!listing) return;
		acceptNegotiation(listing);
	}

	// ---- Mechanism D state ----
	let confirmedPrice = $state('');
	let showReserveConfirm = $state(false);

	function doReserve() {
		if (!listing) return;
		reserveSlot(listing, demoAdvertiserId);
		showReserveConfirm = false;
		reserveToast = true;
		setTimeout(() => (reserveToast = false), 3000);
	}

	let reserveToast = $state(false);

	function doConfirmPrice() {
		if (!listing || !confirmedPrice) return;
		confirmFinalPrice(listing, Number(confirmedPrice));
		confirmedPrice = '';
	}

	function goToDeal() {
		if (listing?.status === 'deal') goto(`/deal/${listing.id}`);
	}
</script>

<div class="container">
	{#if !listing || !creator}
		<div class="empty">Listing not found.</div>
	{:else}
		<a href="/" class="back-link">&larr; Back to listings</a>

		<div class="row" style="justify-content: space-between; align-items: flex-start; margin: 10px 0 4px;">
			<div>
				<h1 style="margin-bottom:4px;">{creator.name} — {listing.contentType} on {listing.platform}</h1>
				<div class="muted">{creator.handle} · {creator.followers.toLocaleString()} followers · {creator.niche}</div>
			</div>
			<div class="row">
				<Badges mechanism={listing.mechanism} />
				<Badges status={listing.status} />
			</div>
		</div>

		{#if managerActingLabel}
			<div class="acting-banner">{managerActingLabel}</div>
		{/if}

		{#if listing.status === 'deal'}
			<div class="deal-banner">
				This listing is a confirmed deal. <a href={`/deal/${listing.id}`}>View contract summary &rarr;</a>
			</div>
		{/if}

		<div class="detail-grid">
			<div class="stack">
				<div class="card">
					<h3 style="margin-top:0;">Listing details</h3>
					<p>{listing.description}</p>
					<div class="kv"><span class="muted">Availability window</span><strong>{listing.availabilityWindow}</strong></div>
					<div class="kv"><span class="muted">Platform</span><strong>{listing.platform}</strong></div>
					<div class="kv"><span class="muted">Content type</span><strong>{listing.contentType}</strong></div>
					{#if listing.mechanism === 'A'}
						<div class="kv"><span class="muted">Asking price</span><strong>{formatMoney(listing.askingPrice ?? 0)}</strong></div>
					{:else if listing.mechanism === 'C'}
						<div class="kv"><span class="muted">Exclusivity window</span><strong>{listing.exclusivityWindowDays} days</strong></div>
						{#if listing.rateCardRangeLow && listing.rateCardRangeHigh}
							<div class="kv"><span class="muted">Rate-card range (context)</span><strong>{formatMoney(listing.rateCardRangeLow)}–{formatMoney(listing.rateCardRangeHigh)}</strong></div>
						{/if}
					{:else if listing.mechanism === 'D'}
						<div class="kv"><span class="muted">Floor price</span><strong>{formatMoney(listing.floorPrice ?? 0)}</strong></div>
						<div class="kv"><span class="muted">Reservation deadline</span><strong>{formatDate(listing.reservationDeadline ?? '')}</strong></div>
					{/if}
				</div>

				<div class="card explainer">
					<strong>How Mechanism {listing.mechanism} works:</strong>
					<p class="muted" style="margin:6px 0 0;">{mechanismShortExplainer[listing.mechanism]}</p>
				</div>
			</div>

			<div class="stack">
				<!-- ===================== MECHANISM A ===================== -->
				{#if listing.mechanism === 'A'}
					<div class="card">
						<h3 style="margin-top:0;">Offer thread</h3>
						{#if !listing.offers || listing.offers.length === 0}
							<p class="muted">No offers yet.</p>
							{#if isAdvertiser || (!isManagingCreator && !isAdvertiser)}
								<div class="field">
									<label for="offer-amount">Make an offer ($)</label>
									<input id="offer-amount" type="number" bind:value={offerAmount} placeholder={String(listing.askingPrice ?? '')} />
								</div>
								<div class="field">
									<label for="offer-note">Note (optional)</label>
									<textarea id="offer-note" bind:value={offerNote}></textarea>
								</div>
								<button class="btn btn-primary" onclick={submitAdvertiserOffer} disabled={!offerAmount}>
									Submit offer
								</button>
							{/if}
						{:else}
							<div class="stack">
								{#each listing.offers as offer (offer.id)}
									<div class="offer-bubble" class:from-creator={offer.from === 'creator'}>
										<div class="row" style="justify-content: space-between;">
											<strong>{offer.from === 'creator' ? creator.name : 'Advertiser'}</strong>
											<span class="muted" style="font-size:12px;">{formatDateTime(offer.createdAt)}</span>
										</div>
										<div style="font-size:18px; font-weight:700; margin:4px 0;">{formatMoney(offer.amount)}</div>
										{#if offer.note}<div class="muted" style="font-size:13px;">{offer.note}</div>{/if}
										<span class="badge" style="margin-top:6px; background:#eee; color:#555;">{offer.status}</span>
									</div>
								{/each}
							</div>

							{#if listing.status !== 'deal'}
								{@const latest = listing.offers[listing.offers.length - 1]}
								{#if latest.status === 'pending'}
									{#if latest.from === 'advertiser' && (isManagingCreator || !isAdvertiser)}
										<hr class="sep" />
										<p class="muted" style="font-size:13px;">Respond as {creator.name}:</p>
										<div class="row">
											<button class="btn btn-primary btn-sm" onclick={() => handleAccept(latest)}>Accept {formatMoney(latest.amount)}</button>
										</div>
										<div class="field" style="margin-top:10px;">
											<label for="counter-amount">Counter-offer ($)</label>
											<input id="counter-amount" type="number" bind:value={offerAmount} />
										</div>
										<div class="field">
											<label for="counter-note">Note</label>
											<textarea id="counter-note" bind:value={offerNote}></textarea>
										</div>
										<button class="btn btn-sm" onclick={submitCreatorCounter} disabled={!offerAmount}>Send counter</button>
									{:else if latest.from === 'creator' && (isAdvertiser || !isManagingCreator)}
										<hr class="sep" />
										<p class="muted" style="font-size:13px;">Respond as advertiser:</p>
										<div class="row">
											<button class="btn btn-primary btn-sm" onclick={() => handleAccept(latest)}>Accept {formatMoney(latest.amount)}</button>
										</div>
										<div class="field" style="margin-top:10px;">
											<label for="counter-amount2">Counter-offer ($)</label>
											<input id="counter-amount2" type="number" bind:value={offerAmount} />
										</div>
										<div class="field">
											<label for="counter-note2">Note</label>
											<textarea id="counter-note2" bind:value={offerNote}></textarea>
										</div>
										<button class="btn btn-sm" onclick={submitAdvertiserOffer} disabled={!offerAmount}>Send counter</button>
									{:else}
										<p class="muted" style="font-size:13px;">Waiting on the other party to respond.</p>
									{/if}
								{/if}
							{/if}
						{/if}
					</div>

				<!-- ===================== MECHANISM C ===================== -->
				{:else if listing.mechanism === 'C'}
					<div class="card">
						<h3 style="margin-top:0;">Exclusivity status</h3>
						{#if !listing.exclusivity}
							<p class="muted">Open — no advertiser currently holds exclusive access.</p>
							{#if isAdvertiser || (!isManagingCreator && !isAdvertiser)}
								<button class="btn btn-primary" onclick={doRequestExclusivity}>Request exclusivity</button>
							{/if}
						{:else}
							{@const ex = listing.exclusivity}
							{@const advertiser = getAdvertiser(ex.advertiserId)}
							<div class="kv"><span class="muted">Held by</span><strong>{advertiser?.company ?? 'Advertiser'}</strong></div>
							<div class="kv"><span class="muted">Granted</span><strong>{formatDate(ex.grantedAt)}</strong></div>
							<div class="kv"><span class="muted">Expires</span><strong>{formatDate(ex.expiresAt)}</strong></div>

							<hr class="sep" />

							{#if listing.status === 'deal'}
								<p class="muted">Terms agreed — see contract summary above.</p>
							{:else if !ex.negotiation}
								<p class="muted" style="font-size:13px;">No proposal yet.</p>
								{#if isAdvertiser || (!isManagingCreator && !isAdvertiser)}
									<div class="field">
										<label for="neg-price">Propose price ($)</label>
										<input id="neg-price" type="number" bind:value={negotiationPrice} />
									</div>
									<div class="field">
										<label for="neg-terms">Terms</label>
										<textarea id="neg-terms" bind:value={negotiationTerms} placeholder={listing.description}></textarea>
									</div>
									<button class="btn btn-primary btn-sm" onclick={() => submitProposal('advertiser')} disabled={!negotiationPrice}>
										Propose terms
									</button>
								{:else}
									<p class="muted" style="font-size:13px;">Waiting on {advertiser?.company} to propose terms.</p>
								{/if}
							{:else}
								<div class="offer-bubble">
									<div class="row" style="justify-content: space-between;">
										<strong>{ex.negotiation.from === 'creator' ? creator.name : advertiser?.company}</strong>
										<span class="badge" style="background:#eee; color:#555;">{ex.negotiation.status}</span>
									</div>
									<div style="font-size:18px; font-weight:700; margin:4px 0;">{formatMoney(ex.negotiation.proposedPrice)}</div>
									<div class="muted" style="font-size:13px;">{ex.negotiation.proposedTerms}</div>
								</div>

								{#if ex.negotiation.status === 'proposed'}
									{#if ex.negotiation.from === 'advertiser' && (isManagingCreator || !isAdvertiser)}
										<hr class="sep" />
										<div class="row">
											<button class="btn btn-primary btn-sm" onclick={doAcceptNegotiation}>Accept terms</button>
										</div>
										<div class="field" style="margin-top:10px;">
											<label for="counter-price">Counter-propose price ($)</label>
											<input id="counter-price" type="number" bind:value={negotiationPrice} />
										</div>
										<div class="field">
											<label for="counter-terms">Terms</label>
											<textarea id="counter-terms" bind:value={negotiationTerms} placeholder={ex.negotiation.proposedTerms}></textarea>
										</div>
										<button class="btn btn-sm" onclick={() => submitProposal('creator')} disabled={!negotiationPrice}>Send counter-proposal</button>
									{:else if ex.negotiation.from === 'creator' && (isAdvertiser || !isManagingCreator)}
										<hr class="sep" />
										<div class="row">
											<button class="btn btn-primary btn-sm" onclick={doAcceptNegotiation}>Accept terms</button>
										</div>
										<div class="field" style="margin-top:10px;">
											<label for="counter-price2">Counter-propose price ($)</label>
											<input id="counter-price2" type="number" bind:value={negotiationPrice} />
										</div>
										<div class="field">
											<label for="counter-terms2">Terms</label>
											<textarea id="counter-terms2" bind:value={negotiationTerms} placeholder={ex.negotiation.proposedTerms}></textarea>
										</div>
										<button class="btn btn-sm" onclick={() => submitProposal('advertiser')} disabled={!negotiationPrice}>Send counter-proposal</button>
									{:else}
										<p class="muted" style="font-size:13px;">Waiting on the other party to respond.</p>
									{/if}
								{/if}
							{/if}
						{/if}
					</div>

				<!-- ===================== MECHANISM D ===================== -->
				{:else if listing.mechanism === 'D'}
					<div class="card">
						<h3 style="margin-top:0;">Reservation status</h3>
						<div class="kv"><span class="muted">Floor price</span><strong>{formatMoney(listing.floorPrice ?? 0)}</strong></div>
						<div class="kv"><span class="muted">Reservation deadline</span><strong>{formatDate(listing.reservationDeadline ?? '')}</strong></div>

						{#if !listing.reservation}
							<hr class="sep" />
							<p class="muted">Open — no reservation placed yet.</p>
							{#if isAdvertiser || (!isManagingCreator && !isAdvertiser)}
								<button class="btn btn-primary" onclick={() => (showReserveConfirm = true)}>Reserve this slot</button>
								{#if showReserveConfirm}
									<div class="confirm-box">
										<p style="margin-top:0;">
											Confirm reservation: pay a {formatMoney(Math.round((listing.floorPrice ?? 0) * 0.1))} deposit
											(10% of floor price) to lock this slot. Non-refundable if the creator confirms within the response window.
										</p>
										<div class="row">
											<button class="btn btn-primary btn-sm" onclick={doReserve}>Confirm &amp; pay deposit</button>
											<button class="btn btn-sm" onclick={() => (showReserveConfirm = false)}>Cancel</button>
										</div>
									</div>
								{/if}
							{/if}
						{:else}
							{@const res = listing.reservation}
							{@const advertiser = getAdvertiser(res.advertiserId)}
							<hr class="sep" />
							<div class="kv"><span class="muted">Reserved by</span><strong>{advertiser?.company}</strong></div>
							<div class="kv"><span class="muted">Deposit paid</span><strong>{formatMoney(res.depositAmount)}</strong></div>
							<div class="kv"><span class="muted">Response deadline</span><strong>{formatDate(res.responseDeadline)}</strong></div>
							<div class="kv"><span class="muted">Status</span><strong>{res.status === 'confirmed' ? `Confirmed at ${formatMoney(res.confirmedPrice ?? 0)}` : 'Awaiting creator confirmation'}</strong></div>

							{#if res.status === 'awaiting_confirmation' && (isManagingCreator || !isAdvertiser)}
								<hr class="sep" />
								<p class="muted" style="font-size:13px;">Confirm the final price as {creator.name} (must be at or above the floor price):</p>
								<div class="field">
									<label for="final-price">Final price ($)</label>
									<input id="final-price" type="number" min={listing.floorPrice} bind:value={confirmedPrice} placeholder={String(listing.floorPrice ?? '')} />
								</div>
								<button class="btn btn-primary btn-sm" onclick={doConfirmPrice} disabled={!confirmedPrice || Number(confirmedPrice) < (listing.floorPrice ?? 0)}>
									Confirm final price
								</button>
							{:else if res.status === 'awaiting_confirmation'}
								<p class="muted" style="font-size:13px;">Waiting on {creator.name} to confirm the final price.</p>
							{/if}
						{/if}
					</div>
				{/if}

				{#if reserveToast}
					<div class="toast">Deposit paid — slot reserved.</div>
				{/if}
			</div>
		</div>
	{/if}
</div>

<style>
	.back-link {
		font-size: 13px;
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
	.deal-banner {
		background: #dce8fd;
		color: var(--accent-dark);
		padding: 10px 12px;
		border-radius: var(--radius);
		font-size: 14px;
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
	.offer-bubble {
		border: 1px solid var(--border);
		border-radius: 8px;
		padding: 10px 12px;
		background: #fafafe;
	}
	.offer-bubble.from-creator {
		background: #f1f6ff;
	}
	.confirm-box {
		margin-top: 12px;
		padding: 12px;
		border: 1px solid var(--border);
		border-radius: 8px;
		background: #fafafe;
		font-size: 13px;
	}
	.toast {
		background: var(--green-bg);
		color: var(--green);
		padding: 10px 12px;
		border-radius: var(--radius);
		font-size: 14px;
		font-weight: 600;
	}
</style>
