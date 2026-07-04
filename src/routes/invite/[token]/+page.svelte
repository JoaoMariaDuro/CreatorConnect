<script lang="ts">
	import { page } from '$app/state';
	import { goto } from '$app/navigation';

	let { data } = $props();
	const supabase = $derived(page.data.supabase);
	const invite = $derived(data.invite);
	const roleLabel = $derived(invite.org_type === 'advertiser' ? 'advertiser' : 'manager');

	const signedIn = $derived(!!data.userId);
	const roleMatches = $derived(data.profile?.role === invite.org_type);

	let accepting = $state(false);
	let acceptErr = $state('');
	let accepted = $state(false);

	async function accept() {
		if (!supabase) return;
		accepting = true;
		acceptErr = '';
		const { error } = await supabase.rpc('accept_org_invite_token', { p_token: data.token });
		accepting = false;
		if (error) {
			acceptErr = error.message;
			return;
		}
		accepted = true;
		setTimeout(() => goto('/settings/org'), 1200);
	}

	function signInHref() {
		const params = new URLSearchParams({
			next: page.url.pathname,
			role: invite.org_type,
			invite_token: data.token
		});
		return `/login?${params.toString()}`;
	}
</script>

<svelte:head><title>CreatorConnect — Org invite</title></svelte:head>

<main class="wrap">
	<div class="card">
		{#if !invite.valid}
			<h1>This invite {invite.reason === 'expired' ? 'has expired' : invite.reason === 'used' ? 'has already been used' : 'was revoked'}</h1>
			<p class="muted">Ask {invite.org_name} for a fresh invite link.</p>
		{:else}
			<h1>Join {invite.org_name}</h1>
			<p class="muted">
				You've been invited to join <b>{invite.org_name}</b> ({invite.org_handle}) on CreatorConnect
				as a {roleLabel}.
			</p>

			{#if accepted}
				<p class="ok">You're in! Redirecting…</p>
			{:else if !signedIn}
				<p class="sub">Sign in or create an account to accept.</p>
				<a class="btn btn-primary" href={signInHref()}>Continue to sign in</a>
			{:else if !roleMatches}
				<p class="warn">
					Your account is registered as {data.profile?.role} — this org only accepts {roleLabel}
					accounts. Sign in with a different account to accept this invite.
				</p>
			{:else}
				{#if acceptErr}<p class="warn">{acceptErr}</p>{/if}
				<button class="btn btn-primary" onclick={accept} disabled={accepting}>
					{accepting ? 'Joining…' : `Accept & join ${invite.org_name}`}
				</button>
			{/if}
		{/if}
	</div>
</main>

<style>
	.wrap {
		display: flex;
		justify-content: center;
		padding: 64px 16px;
	}
	.card {
		max-width: 460px;
		width: 100%;
		background: var(--panel);
		border: 1px solid var(--border);
		border-radius: 12px;
		padding: 32px;
	}
	.sub {
		color: var(--text-muted);
	}
	.muted {
		color: var(--text-muted);
	}
	.warn {
		color: var(--red);
	}
	.ok {
		color: var(--green);
	}
</style>
