<script lang="ts">
	import { page } from '$app/state';
	import { invalidateAll } from '$app/navigation';
	import { formatMoney, formatDate, formatDateTime, mechanismLabel } from '$lib/format';

	let { data } = $props();
	const deal = $derived(data.deal);
	const user = $derived(page.data.user);
	const profile = $derived(page.data.profile);
	const supabase = $derived(page.data.supabase);

	const bookingPortion = $derived(deal ? Math.round(deal.final_price_cents * 0.5) : 0);
	const deliveryPortion = $derived(deal ? deal.final_price_cents - Math.round(deal.final_price_cents * 0.5) : 0);
	const platformFeeRate = 0.15;
	const platformFee = $derived(deal ? Math.round(deal.final_price_cents * platformFeeRate) : 0);

	// isAdvertiser stays direct-only: manager_creator_links delegation is creator-side only, so a
	// delegated manager acts on behalf of the creator, never the advertiser. isParty additionally
	// accepts a delegated manager — matches flag_dispute_as's own is_authorized_for_creator check
	// (rpc-delivery.sql), computed server-side in +page.server.ts (see listings/[id] for the same
	// pattern), so a legitimately linked manager sees the same "flag a dispute" action the creator does.
	const isAdvertiser = $derived(!!user && !!deal && user.id === deal.advertiser_id);
	const isParty = $derived(
		!!user && !!deal && (user.id === deal.advertiser_id || user.id === deal.creator_id || data.isDelegatedManager)
	);
	const isCreatorSide = $derived(!!user && !!deal && (user.id === deal.creator_id || data.isDelegatedManager));

	// E-signature (deal-signatures.sql): typed name + explicit consent, immutable once signed.
	const creatorSignature = $derived(data.signatures?.find((s: any) => s.signer_role === 'creator'));
	const advertiserSignature = $derived(data.signatures?.find((s: any) => s.signer_role === 'advertiser'));
	const myRole = $derived(isAdvertiser ? 'advertiser' : isCreatorSide ? 'creator' : null);
	const mySignature = $derived(myRole === 'advertiser' ? advertiserSignature : myRole === 'creator' ? creatorSignature : null);

	let signTypedName = $state('');
	let signAgreed = $state(false);
	let signing = $state(false);
	let signErr = $state('');

	async function signContract() {
		if (!supabase || !deal || !myRole || !signTypedName.trim() || !signAgreed) return;
		signing = true;
		signErr = '';
		const { error } = await supabase.rpc('sign_deal_as', {
			p_deal_id: deal.id,
			p_signer_role: myRole,
			p_typed_name: signTypedName.trim()
		});
		signing = false;
		if (error) { signErr = error.message; return; }
		await invalidateAll();
	}

	let busy = $state(false);
	let err = $state('');

	async function confirmDelivery() {
		if (!supabase || !deal) return;
		busy = true;
		err = '';
		const { error } = await supabase.rpc('confirm_delivery_as', { p_deal_id: deal.id });
		busy = false;
		if (error) { err = error.message; return; }
		await invalidateAll();
	}

	let showDisputeForm = $state(false);
	let disputeReason = $state('');

	async function flagDispute() {
		if (!supabase || !deal) return;
		busy = true;
		err = '';
		const { error } = await supabase.rpc('flag_dispute_as', { p_deal_id: deal.id, p_reason: disputeReason || null });
		busy = false;
		showDisputeForm = false;
		if (error) { err = error.message; return; }
		await invalidateAll();
	}
</script>

<div class="container narrow">
	{#if !deal}
		<div class="empty">No confirmed deal found.</div>
	{:else}
		<a href={`/listings/${deal.listing_id}`} class="back-link no-print">&larr; Back to listing</a>

		{#if data.isDelegatedManager}
			<div class="acting-banner no-print">Acting as {profile?.display_name} on behalf of {deal.creator?.display_name}</div>
		{/if}

		<button class="btn btn-sm no-print" style="margin-bottom:12px;" onclick={() => window.print()}>
			Print / Save as PDF
		</button>

		<div class="contract card">
			<div class="contract-header">
				<div>
					<span class="badge" style="background:var(--accent-bg); color:var(--accent-dark);">Deal Confirmed</span>
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
			{#if deal.cancellation_terms}
				<div class="kv"><span class="muted">Cancellation terms</span><strong>{deal.cancellation_terms}</strong></div>
			{/if}

			<div class="section-title">Pricing</div>
			<div class="kv"><span class="muted">Total price</span><strong>{formatMoney(deal.final_price_cents)}</strong></div>
			<div class="kv"><span class="muted">Due at booking confirmation (50%)</span><strong>{formatMoney(bookingPortion)}</strong></div>
			<div class="kv"><span class="muted">Released on delivery (50%)</span><strong>{formatMoney(deliveryPortion)}</strong></div>
			<div class="kv"><span class="muted">Platform fee (15%, deducted at payout)</span><strong>{formatMoney(platformFee)}</strong></div>

			<div class="section-title">Terms</div>
			<div class="kv"><span class="muted">Status</span><strong>{deal.status}</strong></div>
			<div class="kv"><span class="muted">Confirmed</span><strong>{formatDateTime(deal.confirmed_at)}</strong></div>
			{#if deal.delivery_confirmed_at}
				<div class="kv"><span class="muted">Delivery confirmed</span><strong>{formatDateTime(deal.delivery_confirmed_at)}</strong></div>
			{/if}
			{#if deal.auto_release_at}
				<div class="kv"><span class="muted">Auto-release scheduled</span><strong>{formatDateTime(deal.auto_release_at)}</strong></div>
			{/if}

			<div class="section-title">Signatures</div>
			<div class="kv">
				<span class="muted">Creator</span>
				<strong>{creatorSignature ? `${creatorSignature.typed_name} · ${formatDate(creatorSignature.signed_at)}` : 'Not yet signed'}</strong>
			</div>
			<div class="kv">
				<span class="muted">Advertiser</span>
				<strong>{advertiserSignature ? `${advertiserSignature.typed_name} · ${formatDate(advertiserSignature.signed_at)}` : 'Not yet signed'}</strong>
			</div>

			{#if myRole && !mySignature}
				<div class="confirm-box no-print">
					<p style="margin-top:0; font-size:13px;">
						Type your full legal name to sign this contract as the {myRole}. This is a real signature — it can't be undone or edited once submitted.
					</p>
					<div class="field">
						<label for="sign-name">Full legal name</label>
						<input id="sign-name" type="text" bind:value={signTypedName} placeholder="Jane Doe" />
					</div>
					<label class="row" style="gap:8px; font-size:13px; margin-top:8px; align-items:flex-start;">
						<input type="checkbox" bind:checked={signAgreed} style="margin-top:3px;" />
						I agree that typing my name above constitutes my legal signature on this contract.
					</label>
					{#if signErr}<p class="warn">{signErr}</p>{/if}
					<button class="btn btn-primary btn-sm" style="margin-top:10px;" onclick={signContract} disabled={signing || !signTypedName.trim() || !signAgreed}>
						{signing ? 'Signing…' : 'Sign contract'}
					</button>
				</div>
			{/if}

			<div class="no-print">
				{#if deal.status === 'active' && isAdvertiser}
					<hr class="sep" />
					<p class="muted" style="font-size:13px;">Once the creator delivers, confirm it here to start the 5-day release window.</p>
					<div class="row">
						<button class="btn btn-primary btn-sm" onclick={confirmDelivery} disabled={busy}>
							{busy ? 'Confirming…' : 'Confirm delivery'}
						</button>
						<button class="btn btn-sm" style="color:var(--red);" onclick={() => (showDisputeForm = true)}>Flag a dispute</button>
					</div>
				{:else if (deal.status === 'active' || deal.status === 'delivered') && isParty}
					<hr class="sep" />
					<button class="btn btn-sm" style="color:var(--red);" onclick={() => (showDisputeForm = true)}>Flag a dispute</button>
				{/if}

				{#if showDisputeForm}
					<div class="confirm-box">
						<p style="margin-top:0;">This freezes the remaining balance for manual, founder-mediated resolution — no automated arbitration in v1.</p>
						<div class="field">
							<label for="dispute-reason">Reason (optional)</label>
							<textarea id="dispute-reason" bind:value={disputeReason}></textarea>
						</div>
						<div class="row">
							<button class="btn btn-primary btn-sm" style="background:var(--red); border-color:var(--red);" onclick={flagDispute} disabled={busy}>
								{busy ? 'Flagging…' : 'Confirm dispute'}
							</button>
							<button class="btn btn-sm" onclick={() => (showDisputeForm = false)}>Cancel</button>
						</div>
					</div>
				{/if}
			</div>

			{#if deal.status === 'disputed'}
				<hr class="sep" />
				<p class="warn">This deal is disputed — the remaining balance is frozen pending manual resolution.</p>
			{:else if deal.status === 'delivered'}
				<hr class="sep" />
				<p class="muted" style="font-size:13px;">Delivery confirmed — the remaining balance releases automatically at the scheduled time (once the release job is running), or via manual founder action.</p>
			{:else if deal.status === 'completed'}
				<hr class="sep" />
				<p class="muted" style="font-size:13px;">Deal completed — full balance released.</p>
			{/if}

			{#if err}<p class="warn">{err}</p>{/if}

			<hr class="sep no-print" />
			<p class="muted no-print" style="font-size:12px;">
				Escrow/Stripe Connect isn't wired up yet (roadmap Phase 0 items 0.4/0.5) — this reflects the
				real <code>deals</code> row and its real status transitions, but no payment has actually moved.
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
	.acting-banner {
		background: var(--purple-bg);
		color: var(--purple);
		padding: 8px 12px;
		border-radius: var(--radius);
		font-size: 13px;
		font-weight: 600;
		margin: 12px 0;
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
	.confirm-box {
		margin-top: 12px;
		padding: 12px;
		border: 1px solid var(--border);
		border-radius: 8px;
		background: var(--panel-raised);
		font-size: 13px;
	}
	.warn {
		color: var(--red);
		font-size: 13px;
	}
</style>
