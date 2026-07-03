<script lang="ts">
	import { page } from '$app/state';
	import { invalidateAll } from '$app/navigation';

	let { data } = $props();
	const profile = $derived(data.profile);
	const supabase = $derived(page.data.supabase);

	const roles = ['creator', 'advertiser', 'manager'] as const;

	// Drafts, re-synced from the loaded profile whenever it changes (nav, or after a save triggers
	// invalidateAll()) — not bound directly to `profile` so typing doesn't fight a stale re-render.
	let displayName = $state('');
	let handle = $state('');
	let avatarUrl = $state('');
	let bio = $state('');
	let nicheTagsDraft = $state('');
	let followerCountDraft = $state('');
	let youtubeHandle = $state('');
	let instagramHandle = $state('');
	let tiktokHandle = $state('');

	$effect(() => {
		if (!profile) return;
		displayName = profile.display_name ?? '';
		handle = profile.handle ?? '';
		avatarUrl = profile.avatar_url ?? '';
		bio = profile.bio ?? '';
		nicheTagsDraft = (profile.niche_tags ?? []).join(', ');
		followerCountDraft = profile.follower_count != null ? String(profile.follower_count) : '';
		youtubeHandle = profile.platform_handles?.youtube ?? '';
		instagramHandle = profile.platform_handles?.instagram ?? '';
		tiktokHandle = profile.platform_handles?.tiktok ?? '';
	});

	let saving = $state(false);
	let err = $state('');
	let saved = $state(false);

	async function saveProfile() {
		if (!supabase || !profile || !displayName.trim()) return;
		saving = true;
		err = '';
		saved = false;

		const platform_handles: Record<string, string> = {};
		if (youtubeHandle.trim()) platform_handles.youtube = youtubeHandle.trim();
		if (instagramHandle.trim()) platform_handles.instagram = instagramHandle.trim();
		if (tiktokHandle.trim()) platform_handles.tiktok = tiktokHandle.trim();

		const { error } = await supabase
			.from('profiles')
			.update({
				display_name: displayName.trim(),
				handle: handle.trim() || null,
				avatar_url: avatarUrl.trim() || null,
				bio: bio.trim() || null,
				niche_tags: nicheTagsDraft
					.split(',')
					.map((t) => t.trim())
					.filter(Boolean),
				follower_count: followerCountDraft !== '' ? Math.round(Number(followerCountDraft)) : null,
				platform_handles
			})
			.eq('id', profile.id);

		saving = false;
		if (error) {
			err = error.message;
			return;
		}
		saved = true;
		await invalidateAll();
	}

	let switching = $state<string | null>(null);
	let roleErr = $state('');

	async function switchRole(role: (typeof roles)[number]) {
		if (!supabase || role === profile?.role) return;
		switching = role;
		roleErr = '';
		const { error } = await supabase.rpc('set_own_test_role_as_admin', { p_role: role });
		switching = null;
		if (error) { roleErr = error.message; return; }
		await invalidateAll();
	}
</script>

<div class="container narrow">
	<h1>Settings</h1>

	{#if !profile}
		<div class="empty">Loading…</div>
	{:else}
		<div class="section-title">Your profile</div>
		<div class="card">
			<div class="field">
				<label for="display-name">Display name</label>
				<input id="display-name" type="text" bind:value={displayName} placeholder="Your name" />
			</div>
			<div class="field">
				<label for="handle">Handle</label>
				<input id="handle" type="text" bind:value={handle} placeholder="@yourhandle" />
			</div>
			<div class="field">
				<label for="avatar-url">Avatar URL</label>
				<input id="avatar-url" type="text" bind:value={avatarUrl} placeholder="https://…" />
			</div>
			<div class="field">
				<label for="bio">Bio</label>
				<textarea id="bio" bind:value={bio} placeholder="A short line about you or your business…"></textarea>
			</div>

			{#if profile.role === 'creator'}
				<div class="field">
					<label for="niche-tags">Niche tags</label>
					<input id="niche-tags" type="text" bind:value={nicheTagsDraft} placeholder="tech, gadget-reviews" />
					<span class="hint">Comma-separated — shown on browse and your public profile page.</span>
				</div>
				<div class="field">
					<label for="follower-count">Follower count</label>
					<input id="follower-count" type="number" min="0" bind:value={followerCountDraft} />
				</div>
				<div class="field">
					<label for="youtube-handle">YouTube handle</label>
					<input id="youtube-handle" type="text" bind:value={youtubeHandle} placeholder="@yourchannel" />
				</div>
				<div class="field">
					<label for="instagram-handle">Instagram handle</label>
					<input id="instagram-handle" type="text" bind:value={instagramHandle} placeholder="@yourhandle" />
				</div>
				<div class="field">
					<label for="tiktok-handle">TikTok handle</label>
					<input id="tiktok-handle" type="text" bind:value={tiktokHandle} placeholder="@yourhandle" />
				</div>
			{/if}

			{#if err}<p class="warn">{err}</p>{/if}
			<div class="row" style="margin-top:12px; gap:8px; align-items:center;">
				<button class="btn btn-primary" onclick={saveProfile} disabled={saving || !displayName.trim()}>
					{saving ? 'Saving…' : 'Save changes'}
				</button>
				{#if saved}<span class="muted" style="font-size:13px;">Saved.</span>{/if}
			</div>
		</div>

		{#if profile.is_platform_admin}
			<div class="section-title">Test as a different role</div>
			<div class="card">
				<p class="muted" style="font-size:13px;">
					You're currently viewing the app as: <strong>{profile.role}</strong>. This only affects
					your own account and does not affect real users.
				</p>
				<p class="muted" style="font-size:13px;">
					Admin-only testing tool — lets one founder account exercise all three role-differentiated
					experiences (creator, advertiser, manager) without needing separate test accounts.
				</p>
				<div class="row" style="margin-top:12px; gap:8px;">
					{#each roles as role}
						<button
							class="btn {role === profile.role ? 'btn-primary' : ''}"
							onclick={() => switchRole(role)}
							disabled={switching !== null || role === profile.role}
						>
							{switching === role ? 'Switching…' : role.charAt(0).toUpperCase() + role.slice(1)}
						</button>
					{/each}
				</div>
				{#if roleErr}<p class="warn">{roleErr}</p>{/if}
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
