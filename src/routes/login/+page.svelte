<script lang="ts">
	import { page } from '$app/state';

	let { data } = $props();
	let email = $state('');
	let role = $state<'creator' | 'advertiser' | 'manager'>('creator');
	let displayName = $state('');
	let sent = $state(false);
	let loading = $state(false);
	let err = $state('');

	// Unlike Lota (invite-only), CreatorConnect signup is open: shouldCreateUser defaults to true, and
	// role/display_name are passed as signup metadata for schema.sql's handle_new_user trigger to pick
	// up. They're only used the FIRST time this email signs in — on a returning user they're ignored
	// (the trigger only fires on a new auth.users row), so the form doesn't need to know in advance
	// whether this is a new or returning user.
	async function submit(e: SubmitEvent) {
		e.preventDefault();
		err = '';
		if (!data.supabaseReady || !data.supabase) {
			err = "Supabase isn't configured yet — check .env.";
			return;
		}
		if (!email.trim()) {
			err = 'Enter your email.';
			return;
		}
		if (!displayName.trim()) {
			err = 'Enter a display name (used if this is your first sign-in).';
			return;
		}
		loading = true;
		const { error } = await data.supabase.auth.signInWithOtp({
			email: email.trim(),
			options: {
				emailRedirectTo: `${page.url.origin}/auth/confirm`,
				data: { role, display_name: displayName.trim() }
			}
		});
		loading = false;
		if (error) err = error.message;
		else sent = true;
	}
</script>

<svelte:head><title>CreatorConnect — Sign in</title></svelte:head>

<main class="wrap">
	<div class="card">
		<h1>Sign in to CreatorConnect</h1>
		{#if page.url.searchParams.get('error') === 'expired'}
			<p class="warn">That link was invalid or expired. Request a fresh one.</p>
		{/if}
		{#if sent}
			<p class="ok">
				Check your inbox — we sent a magic link to <b>{email}</b>. Click it to sign in.
			</p>
			<button class="ghost" onclick={() => (sent = false)}>Use a different email</button>
		{:else}
			<p class="sub">No password — we'll email you a one-click sign-in link.</p>
			<form onsubmit={submit}>
				<div class="field">
					<label for="email">Email</label>
					<input id="email" type="email" bind:value={email} placeholder="you@example.com" />
				</div>
				<div class="field">
					<label for="displayName">Display name</label>
					<input id="displayName" type="text" bind:value={displayName} placeholder="Your name" />
					<span class="muted">Only used if this is your first sign-in.</span>
				</div>
				<div class="field">
					<label for="role">I am a...</label>
					<select id="role" bind:value={role}>
						<option value="creator">Creator</option>
						<option value="advertiser">Advertiser</option>
						<option value="manager">Manager / Agency</option>
					</select>
					<span class="muted">Only used if this is your first sign-in.</span>
				</div>
				{#if err}<p class="warn">{err}</p>{/if}
				<button class="btn btn-primary" type="submit" disabled={loading}>
					{loading ? 'Sending…' : 'Send magic link'}
				</button>
			</form>
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
		max-width: 420px;
		width: 100%;
		background: var(--panel);
		border: 1px solid var(--border);
		border-radius: 12px;
		padding: 32px;
	}
	.sub {
		color: var(--text-muted);
	}
	.field {
		margin-bottom: 16px;
		display: flex;
		flex-direction: column;
		gap: 4px;
	}
	.field label {
		font-weight: 600;
		font-size: 14px;
	}
	.field input,
	.field select {
		padding: 8px 12px;
		border: 1px solid #ddd;
		border-radius: 6px;
		font-size: 15px;
	}
	.muted {
		color: var(--text-muted);
		font-size: 12px;
	}
	.warn {
		color: var(--red);
	}
	.ok {
		color: var(--green);
	}
	.ghost {
		background: none;
		border: none;
		color: var(--accent-dark);
		cursor: pointer;
		text-decoration: underline;
		padding: 0;
	}
</style>
