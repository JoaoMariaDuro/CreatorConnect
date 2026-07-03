<script lang="ts">
	import { page } from '$app/state';
	import { invalidateAll } from '$app/navigation';

	let { data } = $props();
	const profile = $derived(data.profile);
	const supabase = $derived(page.data.supabase);

	const roles = ['creator', 'advertiser', 'manager'] as const;

	let switching = $state<string | null>(null);
	let err = $state('');

	async function switchRole(role: (typeof roles)[number]) {
		if (!supabase || role === profile?.role) return;
		switching = role;
		err = '';
		const { error } = await supabase.rpc('set_own_test_role_as_admin', { p_role: role });
		switching = null;
		if (error) { err = error.message; return; }
		await invalidateAll();
	}
</script>

<div class="container narrow">
	<h1>Settings</h1>

	{#if !profile}
		<div class="empty">Loading…</div>
	{:else}
		<div class="card" style="margin-top:16px;">
			<h3 style="margin-top:0;">Test as a different role</h3>
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
			{#if err}<p class="warn">{err}</p>{/if}
		</div>
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
