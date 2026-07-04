<script lang="ts">
	import { page } from '$app/state';
	import { invalidateAll } from '$app/navigation';

	let { data } = $props();
	const supabase = $derived(page.data.supabase);

	let expandedId = $state<string | null>(null);

	// Create org
	let orgName = $state('');
	let orgHandle = $state('');
	let orgType = $state<'advertiser' | 'manager'>('advertiser');
	let ownerEmail = $state('');
	let creating = $state(false);
	let createErr = $state('');

	async function createOrg() {
		if (!supabase || !orgName.trim() || !orgHandle.trim() || !ownerEmail.trim()) return;
		creating = true;
		createErr = '';
		const { error } = await supabase.rpc('create_org_as_admin', {
			p_name: orgName.trim(),
			p_handle: orgHandle.trim(),
			p_org_type: orgType,
			p_owner_email: ownerEmail.trim()
		});
		creating = false;
		if (error) {
			createErr = error.message;
			return;
		}
		orgName = '';
		orgHandle = '';
		ownerEmail = '';
		await invalidateAll();
	}

	let revokingId = $state<string | null>(null);

	async function revokeMember(memberId: string) {
		if (!supabase) return;
		revokingId = memberId;
		await supabase
			.from('org_members')
			.update({ status: 'revoked', revoked_at: new Date().toISOString() })
			.eq('id', memberId);
		revokingId = null;
		await invalidateAll();
	}
</script>

<div class="container">
	<h1>Orgs</h1>

	<div class="card">
		<h3 style="margin-top:0;">Create an org</h3>
		<p class="muted" style="font-size:13px; margin-top:0;">
			The owner must already have a CreatorConnect account with a matching role.
		</p>
		<div class="row" style="gap:10px; flex-wrap:wrap;">
			<div class="field" style="flex:1; min-width:160px;">
				<label for="admin-org-name">Name</label>
				<input id="admin-org-name" type="text" bind:value={orgName} placeholder="Acme Inc." />
			</div>
			<div class="field" style="flex:1; min-width:120px;">
				<label for="admin-org-handle">Handle</label>
				<input id="admin-org-handle" type="text" bind:value={orgHandle} placeholder="acme" />
			</div>
			<div class="field" style="min-width:140px;">
				<label for="admin-org-type">Type</label>
				<select id="admin-org-type" bind:value={orgType}>
					<option value="advertiser">Advertiser</option>
					<option value="manager">Manager</option>
				</select>
			</div>
			<div class="field" style="flex:1; min-width:180px;">
				<label for="admin-org-owner">Owner email</label>
				<input id="admin-org-owner" type="email" bind:value={ownerEmail} placeholder="owner@example.com" />
			</div>
		</div>
		{#if createErr}<p class="warn">{createErr}</p>{/if}
		<button
			class="btn btn-primary"
			style="margin-top:10px;"
			onclick={createOrg}
			disabled={!orgName.trim() || !orgHandle.trim() || !ownerEmail.trim() || creating}
		>
			{creating ? 'Creating…' : 'Create org'}
		</button>
	</div>

	<div class="section-title">All orgs ({data.orgs.length})</div>
	<div class="stack">
		{#each data.orgs as org (org.id)}
			<div class="card">
				<button
					type="button"
					class="row expand-toggle"
					style="justify-content: space-between; width:100%; text-align:left; background:none; border:none; padding:0; cursor:pointer;"
					onclick={() => (expandedId = expandedId === org.id ? null : org.id)}
				>
					<div>
						<strong>{org.name}</strong>
						<span class="badge" style="margin-left:8px; background:var(--panel-raised); color:var(--text-muted);">{org.org_type}</span>
						<div class="muted" style="font-size:13px; margin-top:2px;">
							<a href={`/org/${org.handle}`} onclick={(e) => e.stopPropagation()}>{org.handle}</a>
							· owner: {org.owner?.display_name ?? 'unknown'}
							· {org.members.filter((m: any) => m.status === 'active').length} active member{org.members.filter((m: any) => m.status === 'active').length === 1 ? '' : 's'}
						</div>
					</div>
					<span class="muted" style="font-size:13px;">{expandedId === org.id ? 'Hide' : 'Roster'}</span>
				</button>

				{#if expandedId === org.id}
					<div class="stack" style="margin-top:12px;">
						{#each org.members as m (m.id)}
							<div class="row" style="justify-content: space-between; padding:8px 0; border-top:1px solid var(--border);">
								<div>
									<strong style="font-size:13px;">{m.member?.display_name}</strong>
									<span class="badge" style="margin-left:8px; background:var(--panel-raised); color:var(--text-muted);">
										{m.role}{m.status !== 'active' ? ` · ${m.status}` : ''}
									</span>
								</div>
								{#if m.status !== 'revoked'}
									<button class="btn btn-sm" style="color:var(--red);" onclick={() => revokeMember(m.id)} disabled={revokingId === m.id}>
										{revokingId === m.id ? 'Revoking…' : 'Revoke'}
									</button>
								{/if}
							</div>
						{/each}
						{#if org.members.length === 0}
							<p class="muted" style="font-size:13px;">No members.</p>
						{/if}
					</div>
				{/if}
			</div>
		{/each}
		{#if data.orgs.length === 0}
			<div class="empty">No orgs yet.</div>
		{/if}
	</div>
</div>

<style>
	.warn {
		color: var(--red);
		font-size: 13px;
		margin-top: 8px;
	}
</style>
