<script lang="ts">
	import { page } from '$app/state';
	import { goto } from '$app/navigation';
	import { mechanismLabel, mechanismShortExplainer, type Mechanism } from '$lib/format';

	let { data } = $props();

	const profile = $derived(page.data.profile);
	const isManager = $derived(profile?.role === 'manager');
	const isAdvertiser = $derived(profile?.role === 'advertiser');

	// Which creator this listing will be created for. Creators create for themselves; managers pick
	// from their linked roster (data.roster, loaded server-side in +page.server.ts).
	let selectedCreatorId = $state<string>('');
	$effect(() => {
		if (!isManager && profile) selectedCreatorId = profile.id;
	});

	let platform = $state('YouTube');
	let contentType = $state('Integration');
	let availabilityWindow = $state('');
	let description = $state('');
	let mechanism = $state<Mechanism | ''>('');

	let askingPrice = $state('');
	let exclusivityWindowDays = $state('7');
	let rateCardRangeLow = $state('');
	let rateCardRangeHigh = $state('');
	let floorPrice = $state('');
	let reservationDeadline = $state('');

	let created = $state<string | null>(null);
	let submitting = $state(false);
	let err = $state('');

	const canSubmit = $derived(
		!!selectedCreatorId &&
			!!availabilityWindow &&
			!!description &&
			!!mechanism &&
			(mechanism === 'A'
				? !!askingPrice
				: mechanism === 'C'
					? !!exclusivityWindowDays
					: mechanism === 'D'
						? !!floorPrice && !!reservationDeadline
						: false)
	);

	async function submit() {
		if (!canSubmit || !mechanism || !data.supabase) return;
		submitting = true;
		err = '';

		const row: Record<string, unknown> = {
			creator_id: selectedCreatorId,
			created_by: page.data.user.id,
			platform,
			content_type: contentType,
			availability_window: availabilityWindow,
			description,
			pricing_mechanism: mechanism,
			status: 'open'
		};
		if (mechanism === 'A') {
			row.floor_price_cents = Math.round(Number(askingPrice) * 100);
		} else if (mechanism === 'C') {
			row.exclusivity_window = `${exclusivityWindowDays} days`;
			if (rateCardRangeLow) row.rate_card_low_cents = Math.round(Number(rateCardRangeLow) * 100);
			if (rateCardRangeHigh) row.rate_card_high_cents = Math.round(Number(rateCardRangeHigh) * 100);
		} else if (mechanism === 'D') {
			row.floor_price_cents = Math.round(Number(floorPrice) * 100);
			row.reservation_deadline = new Date(reservationDeadline).toISOString();
		}

		const { data: inserted, error } = await data.supabase.from('creator_listings').insert(row).select('id').single();
		submitting = false;
		if (error) {
			err = error.message;
			return;
		}
		created = inserted.id;
	}

	function viewListing() {
		if (created) goto(`/listings/${created}`);
	}
</script>

<div class="container narrow">
	<h1>Create a Listing</h1>
	<p class="muted">Publish an open slot so qualified advertisers can come to you.</p>

	{#if created}
		<div class="card" style="margin-top:20px;">
			<h3 style="margin-top:0;">Listing published</h3>
			<p class="muted">Your listing is live in the marketplace with status <strong>Open</strong>.</p>
			<div class="row">
				<button class="btn btn-primary" onclick={viewListing}>View listing</button>
				<a class="btn" href="/dashboard">Go to dashboard</a>
			</div>
		</div>
	{:else}
		<div class="card" style="margin-top:20px;">
			{#if isAdvertiser}
				<p class="muted">You're signed in as an advertiser. Only creators and managers can create listings.</p>
			{:else}
				{#if isManager}
					<div class="field">
						<label for="creator-select">Creating for</label>
						<select id="creator-select" bind:value={selectedCreatorId}>
							<option value="">Select a creator on your roster…</option>
							{#each data.roster as c (c.id)}
								<option value={c.id}>{c.display_name}</option>
							{/each}
						</select>
						{#if data.roster.length === 0}
							<span class="hint">No linked creators yet — a creator needs to grant you access first.</span>
						{/if}
					</div>
				{/if}

				<div class="field">
					<label for="platform">Platform</label>
					<select id="platform" bind:value={platform}>
						<option value="YouTube">YouTube</option>
						<option value="Instagram">Instagram</option>
						<option value="TikTok">TikTok</option>
					</select>
				</div>

				<div class="field">
					<label for="content-type">Content type</label>
					<select id="content-type" bind:value={contentType}>
						<option value="Dedicated Video">Dedicated Video</option>
						<option value="Integration">Integration</option>
						<option value="Feed Post">Feed Post</option>
						<option value="Story Set">Story Set</option>
						<option value="Reel">Reel</option>
					</select>
				</div>

				<div class="field">
					<label for="availability">Availability window</label>
					<input id="availability" type="text" bind:value={availabilityWindow} placeholder="e.g. Week of Aug 10-17, 2026" />
				</div>

				<div class="field">
					<label for="description">Description / constraints</label>
					<textarea id="description" bind:value={description} placeholder="What the content looks like, any hard constraints (e.g. no competitor brands to X)"></textarea>
				</div>

				<div class="section-title">Pricing mechanism</div>
				<div class="mechanism-choices">
					{#each ['A', 'C', 'D'] as m}
						<button
							type="button"
							class="mechanism-choice"
							class:selected={mechanism === m}
							onclick={() => (mechanism = m as Mechanism)}
						>
							<strong>{m} — {mechanismLabel[m as Mechanism]}</strong>
							<p class="muted" style="font-size:13px; margin: 6px 0 0;">{mechanismShortExplainer[m as Mechanism]}</p>
						</button>
					{/each}
				</div>

				{#if mechanism === 'A'}
					<div class="field" style="margin-top:16px;">
						<label for="asking-price">Asking price ($)</label>
						<input id="asking-price" type="number" bind:value={askingPrice} />
						<span class="hint">Advertisers can accept this outright or counter-offer.</span>
					</div>
				{:else if mechanism === 'C'}
					<div class="field" style="margin-top:16px;">
						<label for="excl-window">Exclusivity window (days)</label>
						<input id="excl-window" type="number" bind:value={exclusivityWindowDays} />
						<span class="hint">How long an advertiser's early access lasts before it opens to others.</span>
					</div>
					<div class="row">
						<div class="field" style="flex:1;">
							<label for="rate-low">Rate-card range — low ($, optional)</label>
							<input id="rate-low" type="number" bind:value={rateCardRangeLow} />
						</div>
						<div class="field" style="flex:1;">
							<label for="rate-high">Rate-card range — high ($, optional)</label>
							<input id="rate-high" type="number" bind:value={rateCardRangeHigh} />
						</div>
					</div>
				{:else if mechanism === 'D'}
					<div class="field" style="margin-top:16px;">
						<label for="floor-price">Floor price ($)</label>
						<input id="floor-price" type="number" bind:value={floorPrice} />
						<span class="hint">The minimum you'll accept — not a fixed final price.</span>
					</div>
					<div class="field">
						<label for="res-deadline">Reservation deadline</label>
						<input id="res-deadline" type="date" bind:value={reservationDeadline} />
						<span class="hint">Advertisers must reserve (pay deposit) before this date.</span>
					</div>
				{/if}

				{#if err}<p class="warn">{err}</p>{/if}
				<button class="btn btn-primary" style="margin-top:16px;" onclick={submit} disabled={!canSubmit || submitting}>
					{submitting ? 'Publishing…' : 'Publish listing'}
				</button>
			{/if}
		</div>
	{/if}
</div>

<style>
	.narrow {
		max-width: 640px;
	}
	.mechanism-choices {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}
	.mechanism-choice {
		text-align: left;
		background: #fff;
		border: 1px solid var(--border);
		border-radius: var(--radius);
		padding: 12px;
	}
	.mechanism-choice.selected {
		border-color: var(--accent);
		box-shadow: 0 0 0 1px var(--accent);
		background: #f5f7ff;
	}
	.warn {
		color: #b91c1c;
		font-size: 13px;
	}
</style>
