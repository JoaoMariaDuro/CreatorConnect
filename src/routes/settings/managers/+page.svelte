<script lang="ts">
	import { page } from '$app/state';
	import { invalidateAll } from '$app/navigation';

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
						<strong>{l.creator?.display_name}</strong>
						<span class="muted" style="font-size:13px; margin-left:8px;">{l.creator?.handle ?? ''}</span>
					</div>
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
</style>
