<script lang="ts">
	import { page } from '$app/state';
	import { invalidateAll } from '$app/navigation';

	let { data } = $props();
	const profile = $derived(data.profile);
	const supabase = $derived(page.data.supabase);

	const activeMembership = $derived(data.memberships.find((m: any) => m.status === 'active'));
	const pendingMemberships = $derived(data.memberships.filter((m: any) => m.status === 'pending'));
	const isOwner = $derived(activeMembership?.role === 'owner');

	// Create org
	let orgName = $state('');
	let orgHandle = $state('');
	let orgBio = $state('');
	let creating = $state(false);
	let createErr = $state('');

	async function createOrg() {
		if (!supabase || !profile || !orgName.trim() || !orgHandle.trim()) return;
		creating = true;
		createErr = '';
		const { error } = await supabase.rpc('create_org', {
			p_name: orgName.trim(),
			p_handle: orgHandle.trim(),
			p_org_type: profile.role,
			p_bio: orgBio.trim() || null
		});
		creating = false;
		if (error) { createErr = error.message; return; }
		orgName = '';
		orgHandle = '';
		orgBio = '';
		await invalidateAll();
	}

	// Accept invite
	let accepting = $state<string | null>(null);

	async function accept(memberId: string) {
		if (!supabase) return;
		accepting = memberId;
		await supabase.rpc('accept_org_invite', { p_member_id: memberId });
		accepting = null;
		await invalidateAll();
	}

	// Invite a member
	let inviteEmail = $state('');
	let inviting = $state(false);
	let inviteErr = $state('');

	async function invite() {
		if (!supabase || !activeMembership || !inviteEmail.trim()) return;
		inviting = true;
		inviteErr = '';
		const { error } = await supabase.rpc('invite_org_member_by_email', {
			p_org_id: activeMembership.org.id,
			p_email: inviteEmail.trim()
		});
		inviting = false;
		if (error) { inviteErr = error.message; return; }
		inviteEmail = '';
		await invalidateAll();
	}

	// Revoke a member — plain RLS-gated update, same pattern as manager delegation revoke.
	let revokeErr = $state('');

	async function revoke(memberId: string) {
		if (!supabase) return;
		revokeErr = '';
		const { error } = await supabase
			.from('org_members')
			.update({ status: 'revoked', revoked_at: new Date().toISOString() })
			.eq('id', memberId);
		if (error) { revokeErr = error.message; return; }
		await invalidateAll();
	}

	// Showcase: creators the CALLER personally represents (own manager_creator_links), not yet
	// showcased (or previously declined) for this org — propose_showcase_creator() re-checks the
	// relationship server-side regardless of what this filter shows.
	const showcasableCreators = $derived(
		(data.myRepresentedCreators ?? []).filter(
			(c: any) => !data.showcased?.some((s: any) => s.creator_id === c.id && s.status !== 'declined')
		)
	);
	let proposingId = $state<string | null>(null);
	let showcaseErr = $state('');

	async function proposeShowcase(creatorId: string) {
		if (!supabase || !activeMembership) return;
		proposingId = creatorId;
		showcaseErr = '';
		const { error } = await supabase.rpc('propose_showcase_creator', {
			p_org_id: activeMembership.org.id,
			p_creator_id: creatorId
		});
		proposingId = null;
		if (error) { showcaseErr = error.message; return; }
		await invalidateAll();
	}

	async function retractShowcase(showcaseId: string) {
		if (!supabase) return;
		showcaseErr = '';
		const { error } = await supabase
			.from('org_showcased_creators')
			.update({ status: 'declined', responded_at: new Date().toISOString() })
			.eq('id', showcaseId);
		if (error) { showcaseErr = error.message; return; }
		await invalidateAll();
	}
</script>

<div class="container narrow">
	<h1>Org</h1>

	{#if !profile}
		<div class="empty">Loading…</div>
	{:else if profile.role === 'creator'}
		<p class="muted">Org affiliation is only available for advertiser and manager accounts.</p>
	{:else}
		{#if pendingMemberships.length > 0}
			<div class="section-title">Invitations</div>
			<div class="stack">
				{#each pendingMemberships as m (m.id)}
					<div class="card">
						<div class="row" style="justify-content: space-between;">
							<strong>{m.org?.name}</strong>
							<button class="btn btn-primary btn-sm" onclick={() => accept(m.id)} disabled={accepting === m.id}>
								{accepting === m.id ? 'Accepting…' : 'Accept'}
							</button>
						</div>
					</div>
				{/each}
			</div>
		{/if}

		{#if activeMembership}
			<div class="section-title">Your org</div>
			<div class="card">
				<div class="row" style="justify-content: space-between;">
					<strong>{activeMembership.org.name}</strong>
					<span class="muted" style="font-size:13px;">{isOwner ? 'Owner' : 'Member'}</span>
				</div>
				<div class="muted" style="font-size:13px; margin-top:4px;">
					<a href={`/org/${activeMembership.org.handle}`}>{activeMembership.org.handle}</a>
				</div>
				{#if activeMembership.org.bio}
					<p class="muted" style="font-size:13px; margin-top:8px;">{activeMembership.org.bio}</p>
				{/if}
			</div>

			{#if isOwner}
				<div class="card" style="margin-top:16px;">
					<h3 style="margin-top:0;">Invite a member</h3>
					<div class="field">
						<label for="invite-email">Their email</label>
						<input id="invite-email" type="email" bind:value={inviteEmail} placeholder="coworker@org.com" />
						<span class="hint">They must already have a CreatorConnect account registered as {profile.role === 'advertiser' ? 'an advertiser' : 'a manager'}.</span>
					</div>
					{#if inviteErr}<p class="warn">{inviteErr}</p>{/if}
					<button class="btn btn-primary" onclick={invite} disabled={!inviteEmail.trim() || inviting}>
						{inviting ? 'Sending…' : 'Send invite'}
					</button>
				</div>
			{/if}

			<div class="section-title">Roster</div>
			{#if revokeErr}<p class="warn">{revokeErr}</p>{/if}
			<div class="stack">
				{#each data.roster as m (m.id)}
					<div class="card">
						<div class="row" style="justify-content: space-between;">
							<div>
								<strong>{m.member?.display_name}</strong>
								<span class="badge" style="margin-left:8px; background:var(--panel-raised); color:var(--text-muted);">
									{m.role}{m.status === 'pending' ? ' · pending' : ''}
								</span>
							</div>
							{#if isOwner && m.status !== 'revoked'}
								<button class="btn btn-sm" style="color:var(--red);" onclick={() => revoke(m.id)}>Revoke</button>
							{/if}
						</div>
					</div>
				{/each}
			</div>

			{#if activeMembership.org.org_type === 'manager'}
				<div class="section-title">Represented creators (public showcase)</div>
				<p class="muted" style="font-size:13px;">
					Propose showcasing a creator you represent on your public org page. They have to accept before anyone sees it.
				</p>
				{#if showcaseErr}<p class="warn">{showcaseErr}</p>{/if}
				{#if data.showcased?.length}
					<div class="stack" style="margin-bottom:12px;">
						{#each data.showcased as s (s.id)}
							<div class="card">
								<div class="row" style="justify-content: space-between;">
									<div>
										<strong>{s.creator?.display_name}</strong>
										<span class="badge" style="margin-left:8px; background:var(--panel-raised); color:var(--text-muted);">{s.status}</span>
									</div>
									{#if s.status !== 'declined'}
										<button class="btn btn-sm" style="color:var(--red);" onclick={() => retractShowcase(s.id)}>Remove</button>
									{/if}
								</div>
							</div>
						{/each}
					</div>
				{/if}
				{#if showcasableCreators.length}
					<div class="stack">
						{#each showcasableCreators as c (c.id)}
							<div class="card">
								<div class="row" style="justify-content: space-between;">
									<strong>{c.display_name}</strong>
									<button class="btn btn-sm" onclick={() => proposeShowcase(c.id)} disabled={proposingId === c.id}>
										{proposingId === c.id ? 'Proposing…' : 'Propose showcase'}
									</button>
								</div>
							</div>
						{/each}
					</div>
				{/if}
			{/if}
		{:else if pendingMemberships.length === 0}
			<div class="section-title">Create an org</div>
			<div class="card">
				<p class="muted" style="font-size:13px;">
					Set up a shared account for your {profile.role === 'advertiser' ? 'brand' : 'agency'} — invite coworkers, and get a public org page.
				</p>
				<div class="field">
					<label for="org-name">Org name</label>
					<input id="org-name" type="text" bind:value={orgName} placeholder="Acme Inc." />
				</div>
				<div class="field" style="margin-top:10px;">
					<label for="org-handle">Handle</label>
					<input id="org-handle" type="text" bind:value={orgHandle} placeholder="@acme" />
				</div>
				<div class="field" style="margin-top:10px;">
					<label for="org-bio">Bio</label>
					<textarea id="org-bio" bind:value={orgBio} placeholder="A short line about your org…"></textarea>
				</div>
				{#if createErr}<p class="warn">{createErr}</p>{/if}
				<button class="btn btn-primary" style="margin-top:10px;" onclick={createOrg} disabled={!orgName.trim() || !orgHandle.trim() || creating}>
					{creating ? 'Creating…' : 'Create org'}
				</button>
			</div>
		{/if}
	{/if}
</div>

<style>
	.narrow {
		max-width: 560px;
	}
	.warn {
		color: var(--red);
		font-size: 13px;
		margin-top: 8px;
	}
</style>
