<script lang="ts">
	import { page } from '$app/state';
	import { invalidateAll } from '$app/navigation';
	import { formatMoney, formatDate, formatDateTime, mechanismLabel } from '$lib/format';

	let { data } = $props();
	const deal = $derived(data.deal);
	const escrowTransactions = $derived(data.escrowTransactions ?? []);
	const auditLog = $derived(data.auditLog ?? []);
	const supabase = $derived(page.data.supabase);

	// ---- Resolution panel ----
	let resolution = $state<'release' | 'refund' | 'cancel'>('release');
	let refundAmount = $state('');
	let notes = $state('');
	let showConfirm = $state(false);
	let busy = $state(false);
	let err = $state('');

	async function resolveDispute() {
		if (!supabase || !deal) return;
		busy = true;
		err = '';
		const { error } = await supabase.rpc('resolve_dispute_as_admin', {
			p_deal_id: deal.id,
			p_resolution: resolution,
			p_refund_amount_cents: resolution === 'refund' && refundAmount ? Math.round(Number(refundAmount) * 100) : null,
			p_notes: notes
		});
		busy = false;
		showConfirm = false;
		if (error) {
			err = error.message;
			return;
		}
		await invalidateAll();
	}
</script>

<div class="container narrow">
	{#if !deal}
		<div class="empty">Deal not found.</div>
	{:else}
		<a href="/admin/disputes" class="back-link">&larr; Back to disputes</a>

		<div class="card">
			<h2 style="margin-top:0;">Deal terms</h2>
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
			<div class="kv"><span class="muted">Platform</span><strong>{deal.listing?.platform}</strong></div>
			<div class="kv"><span class="muted">Content type</span><strong>{deal.listing?.content_type}</strong></div>
			<div class="kv">
				<span class="muted">Mechanism</span>
				<strong>{deal.listing?.pricing_mechanism} — {mechanismLabel[deal.listing?.pricing_mechanism as 'A' | 'C' | 'D']}</strong>
			</div>
			<div class="kv"><span class="muted">Final price</span><strong>{formatMoney(deal.final_price_cents)}</strong></div>
			<div class="kv"><span class="muted">Status</span><strong>{deal.status}</strong></div>
			<div class="kv"><span class="muted">Confirmed</span><strong>{formatDateTime(deal.confirmed_at)}</strong></div>
			{#if deal.delivery_due_at}
				<div class="kv"><span class="muted">Delivery due</span><strong>{formatDate(deal.delivery_due_at)}</strong></div>
			{/if}
			{#if deal.delivery_confirmed_at}
				<div class="kv"><span class="muted">Delivery confirmed</span><strong>{formatDateTime(deal.delivery_confirmed_at)}</strong></div>
			{/if}
			{#if deal.auto_release_at}
				<div class="kv"><span class="muted">Auto-release scheduled</span><strong>{formatDateTime(deal.auto_release_at)}</strong></div>
			{/if}
		</div>

		<div class="card">
			<h2 style="margin-top:0;">Escrow state</h2>
			{#if escrowTransactions.length === 0}
				<p class="muted">No escrow transactions recorded yet — Stripe integration not live.</p>
			{:else}
				<div class="stack">
					{#each escrowTransactions as tx (tx.id)}
						<div class="kv">
							<span class="muted">{tx.kind}</span>
							<strong>{formatMoney(tx.amount_cents)} — {tx.status}{tx.stripe_object_id ? ` (${tx.stripe_object_id})` : ''}</strong>
						</div>
					{/each}
				</div>
			{/if}
		</div>

		<div class="card">
			<h2 style="margin-top:0;">Audit trail</h2>
			{#if auditLog.length === 0}
				<p class="muted">No audit log entries for this deal.</p>
			{:else}
				<div class="stack">
					{#each auditLog as row (row.id)}
						<div class="audit-row">
							<div class="row" style="justify-content: space-between;">
								<strong>{row.actor?.display_name ?? 'Unknown'}</strong>
								<span class="muted" style="font-size:12px;">{formatDateTime(row.created_at)}</span>
							</div>
							<div class="muted" style="font-size:13px;">{row.action}</div>
							{#if row.acting_as_id}
								<div class="acting-banner">Acting as {row.actor?.display_name} on behalf of {row.acting_as?.display_name}</div>
							{/if}
							<details>
								<summary>Details</summary>
								<pre>{JSON.stringify(row.before, null, 2)} &rarr; {JSON.stringify(row.after, null, 2)}</pre>
							</details>
						</div>
					{/each}
				</div>
			{/if}
		</div>

		{#if deal.status === 'disputed'}
			<div class="card">
				<h2 style="margin-top:0;">Resolve dispute</h2>
				<div class="field">
					<label>
						<input type="radio" bind:group={resolution} value="release" />
						Release full balance to creator
					</label>
				</div>
				<div class="field">
					<label>
						<input type="radio" bind:group={resolution} value="refund" />
						Refund advertiser
					</label>
				</div>
				{#if resolution === 'refund'}
					<div class="field" style="margin-left:24px;">
						<label for="refund-amount">Refund amount ($)</label>
						<input id="refund-amount" type="number" min="0" bind:value={refundAmount} />
					</div>
				{/if}
				<div class="field">
					<label>
						<input type="radio" bind:group={resolution} value="cancel" />
						Cancel deal, no payout
					</label>
				</div>

				<div class="field" style="margin-top:10px;">
					<label for="resolution-notes">Notes (required)</label>
					<textarea id="resolution-notes" bind:value={notes} required></textarea>
				</div>

				{#if !showConfirm}
					<button
						class="btn btn-primary btn-sm"
						style="background:var(--red); border-color:var(--red);"
						onclick={() => (showConfirm = true)}
						disabled={!notes}
					>
						Resolve dispute
					</button>
				{:else}
					<div class="confirm-box">
						<p style="margin-top:0;">
							This will set the deal to {resolution === 'release' ? 'completed' : 'cancelled'} and cannot be undone.
							Are you sure?
						</p>
						<div class="row">
							<button
								class="btn btn-primary btn-sm"
								style="background:var(--red); border-color:var(--red);"
								onclick={resolveDispute}
								disabled={busy}
							>
								{busy ? 'Resolving…' : 'Confirm resolution'}
							</button>
							<button class="btn btn-sm" onclick={() => (showConfirm = false)}>Cancel</button>
						</div>
					</div>
				{/if}

				{#if err}<p class="warn">{err}</p>{/if}
			</div>
		{/if}
	{/if}
</div>

<style>
	.narrow {
		max-width: 640px;
	}
	.back-link {
		font-size: 13px;
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
	.audit-row {
		padding: 8px 0;
		border-bottom: 1px solid var(--border);
		font-size: 13px;
	}
	.audit-row:last-child {
		border-bottom: none;
	}
	.audit-row pre {
		font-size: 11px;
		white-space: pre-wrap;
		word-break: break-word;
		background: var(--panel-raised);
		padding: 8px;
		border-radius: 6px;
		margin-top: 6px;
	}
	.acting-banner {
		background: var(--purple-bg);
		color: var(--purple);
		padding: 6px 10px;
		border-radius: var(--radius);
		font-size: 12px;
		font-weight: 600;
		margin: 6px 0;
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
