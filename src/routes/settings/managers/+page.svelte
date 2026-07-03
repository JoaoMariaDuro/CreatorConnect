<script lang="ts">
	import { page } from '$app/state';
	import { invalidateAll } from '$app/navigation';
	import { formatMoney, formatDate } from '$lib/format';

	let { data } = $props();
	const profile = $derived(data.profile);
	const supabase = $derived(page.data.supabase);

	let managerEmail = $state('');
	let inviting = $state(false);
	let err = $state('');

	async function invite() {
		if (!supabase || !managerEmail.trim()) return;
		inviting = true;
		err = '';
		const { error } = await supabase.rpc('invite_manager_by_email', { p_manager_email: managerEmail.trim() });
		inviting = false;
		if (error) { err = error.message; return; }
		managerEmail = '';
		await invalidateAll();
	}

	async function revoke(linkId: string) {
		if (!supabase) return;
		await supabase.from('manager_creator_links').update({ status: 'revoked', revoked_at: new Date().toISOString() }).eq('id', linkId);
		await invalidateAll();
	}

	let accepting = $state<string | null>(null);

	async function accept(linkId: string) {
		if (!supabase) return;
		accepting = linkId;
		await supabase.rpc('accept_manager_link', { p_link_id: linkId });
		accepting = null;
		await invalidateAll();
	}

	// Private notes per creator (manager-notes.sql) — fully invisible to the creator, RLS-enforced,
	// not just hidden in this UI. Drafts keyed by creator_id, re-synced from loaded data whenever it
	// changes (same $effect-sync pattern used for draft state elsewhere, e.g. settings/+page.svelte),
	// saved individually so one creator's note doesn't block another's while saving.
	let noteDrafts = $state<Record<string, string>>({});
	$effect(() => {
		const byId = data.notesByCreatorId ?? {};
		noteDrafts = Object.fromEntries(Object.entries(byId).map(([k, v]: [string, any]) => [k, v.notes]));
	});
	let savingNoteFor = $state<string | null>(null);

	async function saveNote(creatorId: string) {
		if (!supabase) return;
		savingNoteFor = creatorId;
		await supabase
			.from('manager_creator_notes')
			.upsert({ manager_id: page.data.user.id, creator_id: creatorId, notes: noteDrafts[creatorId] ?? '' }, { onConflict: 'manager_id,creator_id' });
		savingNoteFor = null;
	}

	// Showcase requests: a manager/agency company proposing to publicly feature this creator.
	// Dual-consent (company-showcase.sql) — nothing shows up on the company's public page until the
	// creator responds here.
	let respondingId = $state<string | null>(null);

	async function respondShowcase(showcaseId: string, showcaseAccept: boolean) {
		if (!supabase) return;
		respondingId = showcaseId;
		await supabase.rpc('respond_showcase_creator', { p_showcase_id: showcaseId, p_accept: showcaseAccept });
		respondingId = null;
		await invalidateAll();
	}

	// Withdrawing consent AFTER already accepting isn't a "response" (respond_showcase_creator only
	// accepts a still-pending row) — it's a plain RLS-gated update, same "creator manages own showcase
	// consent" policy that lets them do this at any time (company-showcase.sql).
	async function withdrawShowcase(showcaseId: string) {
		if (!supabase) return;
		respondingId = showcaseId;
		await supabase.from('company_showcased_creators').update({ status: 'declined', responded_at: new Date().toISOString() }).eq('id', showcaseId);
		respondingId = null;
		await invalidateAll();
	}
</script>

<div class="container narrow">
	<h1>Manager access</h1>

	{#if !profile}
		<div class="empty">Loading…</div>
	{:else if profile.role === 'creator'}
		<p class="muted">Grant a manager delegated access to list and confirm deals on your behalf, within a price band you control.</p>

		<div class="card" style="margin-top:16px;">
			<h3 style="margin-top:0;">Invite a manager</h3>
			<div class="field">
				<label for="manager-email">Manager's email</label>
				<input id="manager-email" type="email" bind:value={managerEmail} placeholder="manager@agency.com" />
				<span class="hint">They must already have a CreatorConnect account registered as a manager.</span>
			</div>
			{#if err}<p class="warn">{err}</p>{/if}
			<button class="btn btn-primary" onclick={invite} disabled={!managerEmail.trim() || inviting}>
				{inviting ? 'Sending…' : 'Send invite'}
			</button>
		</div>

		<div class="section-title">Your managers</div>
		{#if data.links.length === 0}
			<div class="empty">No managers linked yet.</div>
		{:else}
			<div class="stack">
				{#each data.links as l (l.id)}
					<div class="card">
						<div class="row" style="justify-content: space-between;">
							<div>
								<strong>{l.manager?.display_name}</strong>
								<span class="badge" style="margin-left:8px; background:var(--panel-raised); color:var(--text-muted);">{l.status}</span>
							</div>
							{#if l.status !== 'revoked'}
								<button class="btn btn-sm" style="color:var(--red);" onclick={() => revoke(l.id)}>Revoke</button>
							{/if}
						</div>
					</div>
				{/each}
			</div>
		{/if}

		{#if data.showcaseRequests?.length}
			<div class="section-title">Showcase requests</div>
			<p class="muted" style="font-size:13px;">
				An agency wants to feature you on their public company page. Nothing is shown publicly unless you accept.
			</p>
			<div class="stack">
				{#each data.showcaseRequests as s (s.id)}
					<div class="card">
						<div class="row" style="justify-content: space-between;">
							<div>
								<strong>{s.company?.name}</strong>
								<span class="badge" style="margin-left:8px; background:var(--panel-raised); color:var(--text-muted);">{s.status}</span>
							</div>
							{#if s.status === 'pending'}
								<div class="row" style="gap:6px;">
									<button class="btn btn-primary btn-sm" onclick={() => respondShowcase(s.id, true)} disabled={respondingId === s.id}>
										Accept
									</button>
									<button class="btn btn-sm" onclick={() => respondShowcase(s.id, false)} disabled={respondingId === s.id}>
										Decline
									</button>
								</div>
							{:else if s.status === 'accepted'}
								<button class="btn btn-sm" style="color:var(--red);" onclick={() => withdrawShowcase(s.id)}>Remove</button>
							{/if}
						</div>
					</div>
				{/each}
			</div>
		{/if}

	{:else if profile.role === 'manager'}
		<p class="muted">Creators who grant you access appear here. Accept a pending invite to start managing their listings.</p>

		<div class="section-title">Pending invites</div>
		{#if data.links.filter((l: any) => l.status === 'pending').length === 0}
			<div class="empty">No pending invites.</div>
		{:else}
			<div class="stack">
				{#each data.links.filter((l: any) => l.status === 'pending') as l (l.id)}
					<div class="card">
						<div class="row" style="justify-content: space-between;">
							<strong>{l.creator?.display_name}</strong>
							<button class="btn btn-primary btn-sm" onclick={() => accept(l.id)} disabled={accepting === l.id}>
								{accepting === l.id ? 'Accepting…' : 'Accept'}
							</button>
						</div>
					</div>
				{/each}
			</div>
		{/if}

		<div class="section-title">Active roster</div>
		{#if data.links.filter((l: any) => l.status === 'active').length === 0}
			<div class="empty">No active creators yet.</div>
		{:else}
			<div class="stack">
				{#each data.links.filter((l: any) => l.status === 'active') as l (l.id)}
					<div class="card">
						<div class="row" style="justify-content: space-between;">
							<strong>{l.creator?.display_name}</strong>
							<span class="muted" style="font-size:13px;">{(l.commission_bps / 100).toFixed(1)}% commission</span>
						</div>
						<div class="muted" style="font-size:13px; margin-top:4px;">
							{l.creator?.handle ?? ''}
							{#if l.creator?.follower_count}· {l.creator.follower_count.toLocaleString()} followers{/if}
							· {l.creator?.completed_deals_count ?? 0} completed deal{(l.creator?.completed_deals_count ?? 0) === 1 ? '' : 's'}
						</div>
						{#if l.creator?.niche_tags?.length}
							<div class="row" style="gap:6px; margin-top:8px; flex-wrap:wrap;">
								{#each l.creator.niche_tags as tag (tag)}
									<span class="badge" style="background:var(--panel-raised); color:var(--text-muted);">{tag}</span>
								{/each}
							</div>
						{/if}
						<details style="margin-top:10px;">
							<summary class="muted" style="font-size:13px; cursor:pointer;">Private notes</summary>
							<textarea
								style="margin-top:8px;"
								bind:value={noteDrafts[l.creator.id]}
								placeholder="Preferences, history, reminders — visible only to you."
							></textarea>
							<button class="btn btn-sm" style="margin-top:6px;" onclick={() => saveNote(l.creator.id)} disabled={savingNoteFor === l.creator.id}>
								{savingNoteFor === l.creator.id ? 'Saving…' : 'Save note'}
							</button>
						</details>
					</div>
				{/each}
			</div>
		{/if}

		{#if data.commissionLedger?.length}
			<div class="section-title">Commission ledger</div>
			<div class="stack">
				{#each data.commissionLedger as d (d.id)}
					<a class="card ledger-row" href={`/deal/${d.id}`}>
						<div class="row" style="justify-content: space-between;">
							<strong>{d.creator?.display_name}</strong>
							<strong>{formatMoney(d.commission_cents)}</strong>
						</div>
						<div class="muted" style="font-size:13px; margin-top:4px;">
							{formatMoney(d.final_price_cents)} deal · {d.status}
							{#if d.confirmed_at}· {formatDate(d.confirmed_at)}{/if}
						</div>
					</a>
				{/each}
			</div>
		{/if}

		{#if data.bands?.length}
			<div class="section-title">Your auto-accept bands</div>
			<div class="stack">
				{#each data.bands as b (b.id)}
					<a class="card ledger-row" href={`/listings/${b.listing_id}`}>
						<div class="row" style="justify-content: space-between;">
							<strong>{b.listing?.creator?.display_name} — {b.listing?.content_type} on {b.listing?.platform}</strong>
							<strong>{formatMoney(b.auto_accept_floor_cents)}+</strong>
						</div>
					</a>
				{/each}
			</div>
		{/if}
	{:else}
		<p class="muted">Manager delegation is only relevant for creator and manager accounts.</p>
	{/if}
</div>

<style>
	.narrow {
		max-width: 560px;
	}
	.warn {
		color: var(--red);
		font-size: 13px;
	}
	.ledger-row {
		display: block;
		color: inherit;
		text-decoration: none;
	}
	.ledger-row:hover {
		border-color: var(--accent);
		text-decoration: none;
	}
</style>
