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
	const isOwner = $derived(!!user && !!listing && user.id === listing.creator_id);

	let bandDrafts = $state<Record<string, string>>({});
	let savingBand = $state<string | null>(null);
	let bandErr = $state('');

	async function saveBand(managerId: string) {
		if (!listing || !supabase) return;
		const raw = bandDrafts[managerId];
		if (!raw) return;
		savingBand = managerId;
		bandErr = '';
		const { error } = await supabase
			.from('listing_price_bands')
			.upsert(
				{ listing_id: listing.id, manager_id: managerId, auto_accept_floor_cents: Math.round(Number(raw) * 100) },
				{ onConflict: 'listing_id,manager_id' }
			);
		savingBand = null;
		if (error) { bandErr = error.message; return; }
		await invalidateAll();
	}

	// performance_stats jsonb shape (no schema-level enforcement, so documenting here where it's
	// read/written): { avg_views_per_post?: number, engagement_rate_pct?: number } — the two most
	// standard, self-reportable media-kit metrics; kept minimal for MVP manual entry.
	let statsAvgViewsDraft = $state('');
	let statsEngagementDraft = $state('');
	let statsBusy = $state(false);
	let statsErr = $state('');

	$effect(() => {
		if (listing) {
			statsAvgViewsDraft = listing.performance_stats?.avg_views_per_post != null ? String(listing.performance_stats.avg_views_per_post) : '';
			statsEngagementDraft = listing.performance_stats?.engagement_rate_pct != null ? String(listing.performance_stats.engagement_rate_pct) : '';
		}
	});

	async function saveStats() {
		if (!listing || !supabase) return;
		statsBusy = true;
		statsErr = '';
		const performance_stats: Record<string, number> = {};
		if (statsAvgViewsDraft !== '') performance_stats.avg_views_per_post = Math.round(Number(statsAvgViewsDraft));
		if (statsEngagementDraft !== '') performance_stats.engagement_rate_pct = Number(statsEngagementDraft);
		const { error } = await supabase
			.from('creator_listings')
			.update({ performance_stats, performance_stats_updated_at: new Date().toISOString() })
			.eq('id', listing.id);
		statsBusy = false;
		if (error) { statsErr = error.message; return; }
		await invalidateAll();
	}

	// Staleness signal per PRODUCT.md §7 Q3: soft warning at 60-179 days since last update, hard flag
	// at 180+ days (6 months). No badge if never entered or under 60 days.
	const statsDaysSinceUpdate = $derived(
		listing?.performance_stats_updated_at
			? Math.floor((Date.now() - new Date(listing.performance_stats_updated_at).getTime()) / (1000 * 60 * 60 * 24))
			: null
	);
	const statsStaleness = $derived(
		statsDaysSinceUpdate == null ? null : statsDaysSinceUpdate >= 180 ? 'hard' : statsDaysSinceUpdate >= 60 ? 'soft' : 'fresh'
	);
	const hasStatsToShow = $derived(
		!!listing?.performance_stats &&
			(listing.performance_stats.avg_views_per_post != null || listing.performance_stats.engagement_rate_pct != null)
	);

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
			// The RPC's manager-band rejection ("price % is outside the manager's authorized band —
			// needs creator confirmation", rpc-mechanism-d.sql's confirm_deal_as) is a distinct, expected
			// case for a delegated manager — give it a friendly, actionable message instead of the raw
			// Postgres error text. Every other error (below listing floor, reservation not held, etc.)
			// still surfaces raw, as before.
			if (error.message?.includes('authorized band')) {
				confirmErr = `This is below your authorized floor — send to ${listing.creator?.display_name} for confirmation instead.`;
			} else {
				confirmErr = error.message;
			}
			return;
		}
		goto(`/deal/${deal.id}`);
	}

	// ---- Mechanism A ----
	const offers = $derived(data.offers ?? []);
	const latestOffer = $derived(offers.length ? offers[offers.length - 1] : null);

	let offerAmount = $state('');
	let offerNote = $state('');
	let offerBusy = $state(false);
	let offerErr = $state('');

	async function submitOffer(from: 'advertiser' | 'creator') {
		if (!listing || !supabase || !offerAmount) return;
		offerBusy = true;
		offerErr = '';
		const { error } = await supabase.rpc('submit_offer_as', {
			p_listing_id: listing.id,
			p_from: from,
			p_amount_cents: Math.round(Number(offerAmount) * 100),
			p_note: offerNote || null
		});
		offerBusy = false;
		if (error) { offerErr = error.message; return; }
		offerAmount = '';
		offerNote = '';
		await invalidateAll();
	}

	async function acceptOffer() {
		if (!listing || !supabase || !latestOffer) return;
		offerBusy = true;
		offerErr = '';
		const rpc = latestOffer.proposed_by === 'advertiser' ? 'accept_offer_as' : 'accept_offer_as_advertiser';
		const args = latestOffer.proposed_by === 'advertiser'
			? { p_creator_id: listing.creator_id, p_offer_id: latestOffer.id }
			: { p_offer_id: latestOffer.id };
		const { data: deal, error } = await supabase.rpc(rpc, args);
		offerBusy = false;
		if (error) { offerErr = error.message; return; }
		goto(`/deal/${deal.id}`);
	}

	// ---- Mechanism C ----
	const grant = $derived(data.grant);

	let requestingExclusivity = $state(false);
	let exclusivityErr = $state('');

	async function doRequestExclusivity() {
		if (!listing || !supabase) return;
		requestingExclusivity = true;
		exclusivityErr = '';
		const { error } = await supabase.rpc('request_exclusivity_as', { p_listing_id: listing.id });
		requestingExclusivity = false;
		if (error) { exclusivityErr = error.message; return; }
		await invalidateAll();
	}

	let negotiationPrice = $state('');
	let negotiationTerms = $state('');
	let negotiationBusy = $state(false);

	async function submitProposal(from: 'advertiser' | 'creator') {
		if (!grant || !supabase || !negotiationPrice) return;
		negotiationBusy = true;
		exclusivityErr = '';
		const { error } = await supabase.rpc('propose_exclusivity_terms_as', {
			p_grant_id: grant.id,
			p_from: from,
			p_price_cents: Math.round(Number(negotiationPrice) * 100),
			p_terms: negotiationTerms || listing?.description || ''
		});
		negotiationBusy = false;
		if (error) { exclusivityErr = error.message; return; }
		negotiationPrice = '';
		negotiationTerms = '';
		await invalidateAll();
	}

	async function acceptExclusivityTerms() {
		if (!listing || !grant || !supabase) return;
		negotiationBusy = true;
		exclusivityErr = '';
		const proposedByAdvertiser = grant.negotiation?.from === 'advertiser';
		const rpc = proposedByAdvertiser ? 'convert_exclusivity_as' : 'convert_exclusivity_as_advertiser';
		const args = proposedByAdvertiser
			? { p_creator_id: listing.creator_id, p_grant_id: grant.id }
			: { p_grant_id: grant.id };
		const { data: deal, error } = await supabase.rpc(rpc, args);
		negotiationBusy = false;
		if (error) { exclusivityErr = error.message; return; }
		goto(`/deal/${deal.id}`);
	}
</script>

<div class="container">
	{#if !listing}
		<div class="empty">Listing not found.</div>
	{:else}
		<a href="/browse" class="back-link">&larr; Back to listings</a>

		<div class="row" style="justify-content: space-between; align-items: flex-start; margin: 10px 0 4px;">
			<div>
				<h1 style="margin-bottom:4px;">{listing.creator?.display_name} — {listing.content_type} on {listing.platform}</h1>
				<div class="muted">
					{listing.creator?.handle ?? ''} · {(listing.creator?.follower_count ?? 0).toLocaleString()} followers
					{#if listing.creator?.completed_deals_count > 0}
						· {listing.creator.completed_deals_count} completed deal{listing.creator.completed_deals_count === 1 ? '' : 's'}
					{/if}
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

					{#if hasStatsToShow}
						<hr class="sep" />
						{#if listing.performance_stats.avg_views_per_post != null}
							<div class="kv"><span class="muted">Avg. views per post</span><strong>{Number(listing.performance_stats.avg_views_per_post).toLocaleString()}</strong></div>
						{/if}
						{#if listing.performance_stats.engagement_rate_pct != null}
							<div class="kv"><span class="muted">Engagement rate</span><strong>{listing.performance_stats.engagement_rate_pct}%</strong></div>
						{/if}
						{#if statsStaleness === 'soft'}
							<span class="badge badge-stale-soft" style="margin-top:8px;">Stats last updated {formatDate(listing.performance_stats_updated_at)} — may be outdated</span>
						{:else if statsStaleness === 'hard'}
							<span class="badge badge-stale-hard" style="margin-top:8px;">Stats last updated {formatDate(listing.performance_stats_updated_at)} — likely outdated</span>
						{/if}
					{/if}
				</div>

				{#if isOwnerOrManager && (listing.status === 'draft' || listing.status === 'open')}
					<div class="card">
						<h3 style="margin-top:0;">Performance stats</h3>
						<p class="muted" style="font-size:13px;">
							Self-reported media-kit stats shown to advertisers on this listing. Manual entry — keep it current.
						</p>
						<div class="field">
							<label for="stats-avg-views">Average views per post</label>
							<input id="stats-avg-views" type="number" min="0" bind:value={statsAvgViewsDraft} placeholder="e.g. 12000" />
						</div>
						<div class="field" style="margin-top:10px;">
							<label for="stats-engagement">Engagement rate (%)</label>
							<input id="stats-engagement" type="number" min="0" max="100" step="0.1" bind:value={statsEngagementDraft} placeholder="e.g. 4.2" />
						</div>
						<button class="btn btn-sm" style="margin-top:10px;" onclick={saveStats} disabled={statsBusy}>
							{statsBusy ? 'Saving…' : 'Save stats'}
						</button>
						{#if statsErr}<p class="warn">{statsErr}</p>{/if}
					</div>
				{/if}

				<div class="card explainer">
					<strong>How Mechanism {listing.pricing_mechanism} works:</strong>
					<p class="muted" style="margin:6px 0 0;">{mechanismShortExplainer[listing.pricing_mechanism as 'A' | 'C' | 'D']}</p>
				</div>

				{#if isOwner && data.ownerManagerBands?.length}
					<div class="card">
						<h3 style="margin-top:0;">Manager auto-accept bands</h3>
						<p class="muted" style="font-size:13px;">
							A linked manager can confirm a price on your behalf without asking, as long as it's at or
							above this floor for this specific listing. No band set means that manager can't confirm
							this listing at all — they'll need to ask you directly.
						</p>
						{#each data.ownerManagerBands as b}
							<div class="field" style="margin-top:10px;">
								<label for={`band-${b.manager.id}`}>{b.manager.display_name}</label>
								<div class="row">
									<input
										id={`band-${b.manager.id}`}
										type="number"
										placeholder={b.auto_accept_floor_cents ? String(b.auto_accept_floor_cents / 100) : 'No band set'}
										bind:value={bandDrafts[b.manager.id]}
									/>
									<button class="btn btn-sm" onclick={() => saveBand(b.manager.id)} disabled={savingBand === b.manager.id || !bandDrafts[b.manager.id]}>
										{savingBand === b.manager.id ? 'Saving…' : 'Save'}
									</button>
								</div>
								{#if b.auto_accept_floor_cents}
									<span class="hint">Currently: auto-accept ≥ {formatMoney(b.auto_accept_floor_cents)}</span>
								{/if}
							</div>
						{/each}
						{#if bandErr}<p class="warn">{bandErr}</p>{/if}
					</div>
				{/if}
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
								{#if data.isDelegatedManager}
									{#if data.myBand}
										<div class="kv">
											<span class="muted">Your authorized floor {data.myBand.isDefault ? '(creator default)' : 'for this listing'}</span>
											<strong>{formatMoney(data.myBand.auto_accept_floor_cents ?? 0)}</strong>
										</div>
									{:else}
										<p class="muted" style="font-size:13px;">No authorized band set for this listing — your confirmation will need the creator's approval.</p>
									{/if}
								{/if}
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
				{:else if listing.pricing_mechanism === 'A'}
					<div class="card">
						<h3 style="margin-top:0;">Offer thread</h3>
						{#if offers.length === 0}
							<p class="muted">No offers yet.</p>
							{#if !user}
								<p class="muted">Open — <a href="/login">sign in</a> to make an offer.</p>
							{:else if !isOwnerOrManager}
								<div class="field">
									<label for="offer-amount">Make an offer ($)</label>
									<input id="offer-amount" type="number" bind:value={offerAmount} placeholder={String((listing.floor_price_cents ?? 0) / 100)} />
								</div>
								<div class="field">
									<label for="offer-note">Note (optional)</label>
									<textarea id="offer-note" bind:value={offerNote}></textarea>
								</div>
								<button class="btn btn-primary" onclick={() => submitOffer('advertiser')} disabled={!offerAmount || offerBusy}>
									{offerBusy ? 'Submitting…' : 'Submit offer'}
								</button>
							{/if}
						{:else}
							<div class="stack">
								{#each offers as offer (offer.id)}
									<div class="offer-bubble" class:from-creator={offer.proposed_by === 'creator'}>
										<div class="row" style="justify-content: space-between;">
											<strong>{offer.proposed_by === 'creator' ? listing.creator?.display_name : 'Advertiser'}</strong>
											<span class="muted" style="font-size:12px;">{formatDateTime(offer.created_at)}</span>
										</div>
										<div style="font-size:18px; font-weight:700; margin:4px 0;">{formatMoney(offer.offer_amount_cents)}</div>
										{#if offer.note}<div class="muted" style="font-size:13px;">{offer.note}</div>{/if}
										<span class="badge" style="margin-top:6px; background:var(--panel-raised); color:var(--text-muted);">{offer.status}</span>
									</div>
								{/each}
							</div>

							{#if listing.status !== 'deal' && latestOffer?.status === 'open'}
								{#if latestOffer.proposed_by === 'advertiser' && isOwnerOrManager}
									<hr class="sep" />
									<p class="muted" style="font-size:13px;">Respond as {listing.creator?.display_name}:</p>
									<div class="row">
										<button class="btn btn-primary btn-sm" onclick={acceptOffer} disabled={offerBusy}>Accept {formatMoney(latestOffer.offer_amount_cents)}</button>
									</div>
									<div class="field" style="margin-top:10px;">
										<label for="counter-amount">Counter-offer ($)</label>
										<input id="counter-amount" type="number" bind:value={offerAmount} />
									</div>
									<button class="btn btn-sm" onclick={() => submitOffer('creator')} disabled={!offerAmount || offerBusy}>Send counter</button>
								{:else if latestOffer.proposed_by === 'creator' && !isOwnerOrManager}
									<hr class="sep" />
									<p class="muted" style="font-size:13px;">Respond as advertiser:</p>
									<div class="row">
										<button class="btn btn-primary btn-sm" onclick={acceptOffer} disabled={offerBusy}>Accept {formatMoney(latestOffer.offer_amount_cents)}</button>
									</div>
									<div class="field" style="margin-top:10px;">
										<label for="counter-amount2">Counter-offer ($)</label>
										<input id="counter-amount2" type="number" bind:value={offerAmount} />
									</div>
									<button class="btn btn-sm" onclick={() => submitOffer('advertiser')} disabled={!offerAmount || offerBusy}>Send counter</button>
								{:else}
									<p class="muted" style="font-size:13px;">Waiting on the other party to respond.</p>
								{/if}
							{/if}
						{/if}
						{#if offerErr}<p class="warn">{offerErr}</p>{/if}
					</div>
				{:else if listing.pricing_mechanism === 'C'}
					<div class="card">
						<h3 style="margin-top:0;">Exclusivity status</h3>
						{#if !grant || grant.status === 'expired' || grant.status === 'revoked'}
							<p class="muted">Open — no advertiser currently holds exclusive access.</p>
							{#if !user}
								<p class="muted">Open — <a href="/login">sign in</a> to request exclusivity.</p>
							{:else if !isOwnerOrManager}
								<button class="btn btn-primary" onclick={doRequestExclusivity} disabled={requestingExclusivity}>
									{requestingExclusivity ? 'Requesting…' : 'Request exclusivity'}
								</button>
							{/if}
						{:else}
							<div class="kv"><span class="muted">Held by</span><strong>{grant.advertiser?.display_name ?? 'Advertiser'}</strong></div>
							<div class="kv"><span class="muted">Granted</span><strong>{formatDate(grant.window_starts_at)}</strong></div>
							<div class="kv"><span class="muted">Expires</span><strong>{formatDate(grant.window_ends_at)}</strong></div>

							<hr class="sep" />

							{#if listing.status === 'deal'}
								<p class="muted">Terms agreed — see contract summary above.</p>
							{:else if !grant.negotiation}
								<p class="muted" style="font-size:13px;">No proposal yet.</p>
								{#if !isOwnerOrManager}
									<div class="field">
										<label for="neg-price">Propose price ($)</label>
										<input id="neg-price" type="number" bind:value={negotiationPrice} />
									</div>
									<div class="field">
										<label for="neg-terms">Terms</label>
										<textarea id="neg-terms" bind:value={negotiationTerms} placeholder={listing.description}></textarea>
									</div>
									<button class="btn btn-primary btn-sm" onclick={() => submitProposal('advertiser')} disabled={!negotiationPrice || negotiationBusy}>
										Propose terms
									</button>
								{:else}
									<p class="muted" style="font-size:13px;">Waiting on {grant.advertiser?.display_name} to propose terms.</p>
								{/if}
							{:else}
								<div class="offer-bubble">
									<div class="row" style="justify-content: space-between;">
										<strong>{grant.negotiation.from === 'creator' ? listing.creator?.display_name : grant.advertiser?.display_name}</strong>
										<span class="badge" style="background:var(--panel-raised); color:var(--text-muted);">{grant.negotiation.status}</span>
									</div>
									<div style="font-size:18px; font-weight:700; margin:4px 0;">{formatMoney(grant.negotiation.proposedPrice)}</div>
									<div class="muted" style="font-size:13px;">{grant.negotiation.proposedTerms}</div>
								</div>

								{#if grant.negotiation.status === 'proposed'}
									{#if grant.negotiation.from === 'advertiser' && isOwnerOrManager}
										<hr class="sep" />
										<div class="row">
											<button class="btn btn-primary btn-sm" onclick={acceptExclusivityTerms} disabled={negotiationBusy}>Accept terms</button>
										</div>
										<div class="field" style="margin-top:10px;">
											<label for="counter-price">Counter-propose price ($)</label>
											<input id="counter-price" type="number" bind:value={negotiationPrice} />
										</div>
										<div class="field">
											<label for="counter-terms">Terms</label>
											<textarea id="counter-terms" bind:value={negotiationTerms} placeholder={grant.negotiation.proposedTerms}></textarea>
										</div>
										<button class="btn btn-sm" onclick={() => submitProposal('creator')} disabled={!negotiationPrice || negotiationBusy}>Send counter-proposal</button>
									{:else if grant.negotiation.from === 'creator' && !isOwnerOrManager}
										<hr class="sep" />
										<div class="row">
											<button class="btn btn-primary btn-sm" onclick={acceptExclusivityTerms} disabled={negotiationBusy}>Accept terms</button>
										</div>
										<div class="field" style="margin-top:10px;">
											<label for="counter-price2">Counter-propose price ($)</label>
											<input id="counter-price2" type="number" bind:value={negotiationPrice} />
										</div>
										<div class="field">
											<label for="counter-terms2">Terms</label>
											<textarea id="counter-terms2" bind:value={negotiationTerms} placeholder={grant.negotiation.proposedTerms}></textarea>
										</div>
										<button class="btn btn-sm" onclick={() => submitProposal('advertiser')} disabled={!negotiationPrice || negotiationBusy}>Send counter-proposal</button>
									{:else}
										<p class="muted" style="font-size:13px;">Waiting on the other party to respond.</p>
									{/if}
								{/if}
							{/if}
						{/if}
						{#if exclusivityErr}<p class="warn">{exclusivityErr}</p>{/if}
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
		background: var(--accent-bg);
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
		background: var(--panel-raised);
	}
	.confirm-box {
		margin-top: 12px;
		padding: 12px;
		border: 1px solid var(--border);
		border-radius: 8px;
		background: var(--panel-raised);
		font-size: 13px;
	}
	.offer-bubble {
		border: 1px solid var(--border);
		border-radius: 8px;
		padding: 10px 12px;
		background: var(--panel-raised);
	}
	.offer-bubble.from-creator {
		background: var(--accent-bg);
	}
	.warn {
		color: var(--red);
		font-size: 13px;
	}
</style>
