<script lang="ts">
	import { page } from '$app/state';
	import { goto, invalidate } from '$app/navigation';

	const user = $derived(page.data.user);
	const profile = $derived(page.data.profile);
	const supabase = $derived(page.data.supabase);

	async function signOut() {
		await supabase?.auth.signOut();
		await invalidate('supabase:auth');
		goto('/');
	}
</script>

<header>
	<div class="container header-inner">
		<a class="logo" href="/">CreatorConnect</a>
		<nav>
			<a href="/">Browse</a>
			{#if user}
				<a href="/dashboard">Dashboard</a>
				{#if profile?.role === 'creator' || profile?.role === 'manager'}
					<a href="/create">Create Listing</a>
					<a href="/settings/managers">{profile.role === 'creator' ? 'Managers' : 'My Roster'}</a>
				{/if}
			{/if}
		</nav>
		<div class="auth-area">
			{#if user && profile}
				<span class="who">
					<strong>{profile.display_name}</strong>
					<span class="role-badge">{profile.role}</span>
				</span>
				<button class="ghost" onclick={signOut}>Sign out</button>
			{:else if user && !profile}
				<span class="muted" style="font-size:13px;">Setting up your profile…</span>
			{:else}
				<a class="btn btn-primary" href="/login">Sign in</a>
			{/if}
		</div>
	</div>
</header>

<style>
	header {
		background: var(--panel);
		border-bottom: 1px solid var(--border);
		position: sticky;
		top: 0;
		z-index: 10;
	}
	.header-inner {
		display: flex;
		align-items: center;
		gap: 24px;
		padding-top: 14px;
		padding-bottom: 14px;
	}
	.logo {
		font-weight: 800;
		font-size: 17px;
		color: var(--text);
		text-decoration: none;
	}
	nav {
		display: flex;
		gap: 16px;
		flex: 1;
	}
	nav a {
		color: var(--text-muted);
		font-size: 14px;
		font-weight: 600;
	}
	nav a:hover {
		color: var(--text);
		text-decoration: none;
	}
	.auth-area {
		display: flex;
		align-items: center;
		gap: 12px;
	}
	.who {
		display: flex;
		align-items: center;
		gap: 8px;
		font-size: 14px;
	}
	.role-badge {
		font-size: 11px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.03em;
		background: #eef2ff;
		color: #4338ca;
		padding: 2px 8px;
		border-radius: 999px;
	}
	.ghost {
		background: none;
		border: none;
		color: var(--text-muted);
		cursor: pointer;
		font-size: 13px;
		text-decoration: underline;
		padding: 0;
	}
</style>
