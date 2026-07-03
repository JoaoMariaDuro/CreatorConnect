<script lang="ts">
	import { page } from '$app/state';
	import { goto, invalidate } from '$app/navigation';
	import { onMount } from 'svelte';
	import {
		Compass,
		LayoutDashboard,
		PlusCircle,
		Users,
		Map,
		LogOut,
		LogIn,
		KeyRound,
		ShieldAlert,
		Settings,
		Building2
	} from '@lucide/svelte';

	const user = $derived(page.data.user);
	const profile = $derived(page.data.profile);
	const supabase = $derived(page.data.supabase);
	const path = $derived(page.url.pathname);

	async function signOut() {
		await supabase?.auth.signOut();
		await invalidate('supabase:auth');
		goto('/');
	}

	function isActive(href: string) {
		return href === '/' ? path === '/' : path.startsWith(href);
	}

	let pkSupported = $state(false);
	let addingPasskey = $state(false);
	let passkeyMsg = $state('');
	onMount(() => {
		pkSupported = typeof window !== 'undefined' && !!window.PublicKeyCredential;
	});

	async function addPasskey() {
		if (!supabase) return;
		addingPasskey = true;
		passkeyMsg = '';
		const { error } = await supabase.auth.registerPasskey();
		addingPasskey = false;
		if (error) {
			console.error('registerPasskey failed:', error);
			passkeyMsg = `Could not add passkey: ${error.message}`;
		} else {
			passkeyMsg = 'Passkey added.';
		}
	}
</script>

<aside class="sidebar">
	<nav>
		<a class="nav-item" class:active={isActive('/browse')} href="/browse">
			<Compass size={17} />
			<span>Browse</span>
		</a>
		{#if user}
			<a class="nav-item" class:active={isActive('/dashboard')} href="/dashboard">
				<LayoutDashboard size={17} />
				<span>Dashboard</span>
			</a>
			{#if profile?.role === 'creator' || profile?.role === 'manager'}
				<a class="nav-item" class:active={isActive('/create')} href="/create">
					<PlusCircle size={17} />
					<span>Create Listing</span>
				</a>
				<a class="nav-item" class:active={isActive('/settings/managers')} href="/settings/managers">
					<Users size={17} />
					<span>{profile.role === 'creator' ? 'Managers' : 'My Roster'}</span>
				</a>
			{/if}
			{#if profile?.role === 'advertiser' || profile?.role === 'manager'}
				<a class="nav-item" class:active={isActive('/settings/company')} href="/settings/company">
					<Building2 size={17} />
					<span>Company</span>
				</a>
			{/if}
			<a class="nav-item" class:active={path === '/settings'} href="/settings">
				<Settings size={17} />
				<span>Settings</span>
			</a>
		{/if}
		<a class="nav-item" class:active={isActive('/roadmap')} href="/roadmap">
			<Map size={17} />
			<span>Roadmap</span>
		</a>
		{#if profile?.is_platform_admin}
			<a class="nav-item admin" class:active={isActive('/admin')} href="/admin">
				<ShieldAlert size={17} />
				<span>Admin</span>
			</a>
		{/if}
	</nav>

	<div class="sidebar-footer">
		{#if user && profile}
			<div class="who">
				<strong>{profile.display_name}</strong>
				<span class="role-badge">{profile.role}</span>
			</div>
			{#if pkSupported}
				<button class="nav-item ghost-btn" onclick={addPasskey} disabled={addingPasskey}>
					<KeyRound size={17} />
					<span>{addingPasskey ? 'Adding…' : 'Add a passkey'}</span>
				</button>
				{#if passkeyMsg}<span class="muted" style="font-size:11px; padding: 0 12px;">{passkeyMsg}</span>{/if}
			{/if}
			<button class="nav-item ghost-btn" onclick={signOut}>
				<LogOut size={17} />
				<span>Sign out</span>
			</button>
		{:else if user && !profile}
			<span class="muted" style="font-size:12px; padding: 0 12px;">Setting up your profile…</span>
		{:else}
			<a class="nav-item" href="/login">
				<LogIn size={17} />
				<span>Sign in</span>
			</a>
		{/if}
	</div>
</aside>

<style>
	.sidebar {
		width: var(--sidebar-w);
		background: var(--panel);
		border-right: 1px solid var(--border);
		display: flex;
		flex-direction: column;
		position: fixed;
		top: var(--topbar-h);
		left: 0;
		height: calc(100vh - var(--topbar-h));
		overflow-y: auto;
		padding: 16px 12px;
	}
	nav {
		display: flex;
		flex-direction: column;
		gap: 2px;
		flex: 1;
	}
	.nav-item {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 9px 12px;
		border-radius: 8px;
		color: var(--text-muted);
		font-size: 14px;
		font-weight: 500;
		width: 100%;
		background: none;
		border: none;
		text-align: left;
		overflow: hidden;
		white-space: nowrap;
	}
	.nav-item:hover {
		background: var(--panel-raised);
		color: var(--text);
		text-decoration: none;
	}
	.nav-item.active {
		background: var(--accent-bg);
		color: var(--accent-dark);
	}
	.nav-item.admin {
		color: var(--red);
	}
	.nav-item.admin:hover {
		background: var(--red-bg);
		color: var(--red);
	}
	.nav-item.admin.active {
		background: var(--red-bg);
		color: var(--red);
	}
	.sidebar-footer {
		border-top: 1px solid var(--border);
		padding-top: 12px;
		display: flex;
		flex-direction: column;
		gap: 6px;
	}
	.who {
		display: flex;
		flex-direction: column;
		gap: 4px;
		padding: 8px 12px;
		font-size: 14px;
	}
	.role-badge {
		font-size: 10px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.03em;
		background: var(--accent-bg);
		color: var(--accent-dark);
		padding: 2px 8px;
		border-radius: 999px;
		width: fit-content;
	}
	.ghost-btn {
		cursor: pointer;
	}

	/* Desktop-only: collapse the sidebar to an icon-only rail by default,
	   expanding to the full-width panel on hover/focus. The expanded state
	   overlays on top of page content (app.css reserves space for the
	   collapsed width only), matching the Supabase dashboard nav pattern. */
	@media (min-width: 861px) {
		.sidebar {
			width: var(--sidebar-collapsed-w);
			overflow-x: hidden;
			transition: width 150ms ease;
			z-index: 50;
			box-shadow: 2px 0 12px rgba(0, 0, 0, 0.25);
		}
		.sidebar:hover,
		.sidebar:focus-within {
			width: var(--sidebar-w);
		}
		/* Collapsed rail: the icon is the only visible content (the label
		   next to it is clipped by the row's overflow:hidden), so give it a
		   fixed non-shrinking box and let symmetric padding read as centered
		   instead of centering the whole (icon + clipped label) flex line —
		   the latter drifts off-box once the wide label is factored in. */
		.nav-item :global(svg) {
			flex-shrink: 0;
		}
		.who {
			overflow: hidden;
			white-space: nowrap;
			opacity: 0;
		}
		.sidebar:hover .who,
		.sidebar:focus-within .who {
			opacity: 1;
		}
	}

	/* Match the breakpoint in app.css: below this width, take the
	   sidebar out of fixed positioning and stack it above the main
	   content at full width instead of squeezing content into a
	   ~155px column. Since it's now in normal document flow (not fixed),
	   it needs its own top offset so it starts below the fixed top bar
	   instead of being covered by it — app-main's padding-top doesn't
	   reach this flow-sibling. */
	@media (max-width: 860px) {
		.sidebar {
			position: static;
			width: 100%;
			height: auto;
			margin-top: var(--topbar-h);
			border-right: none;
			border-bottom: 1px solid var(--border);
		}
	}
</style>
