<script lang="ts">
	import { page } from '$app/state';
	import { invalidateAll } from '$app/navigation';

	const user = $derived(page.data.user);
	const supabase = $derived(page.data.supabase);

	let role = $state<'creator' | 'advertiser' | 'manager'>('creator');
	let displayName = $state('');
	let submitting = $state(false);
	let err = $state('');

	async function submit(e: SubmitEvent) {
		e.preventDefault();
		if (!supabase || !user || !displayName.trim()) return;
		submitting = true;
		err = '';
		const { error } = await supabase
			.from('profiles')
			.insert({ id: user.id, role, display_name: displayName.trim() });
		submitting = false;
		if (error) {
			err = error.message;
			return;
		}
		await invalidateAll();
	}
</script>

<div class="wrap">
	<div class="card">
		<h1 style="margin-top:0;">Finish setting up your account</h1>
		<p class="muted">
			We couldn't find a profile for you yet — this can happen depending on how you signed in. No
			data was lost; just tell us a bit about yourself to continue.
		</p>
		<form onsubmit={submit}>
			<div class="field">
				<label for="display-name">Display name</label>
				<input id="display-name" type="text" bind:value={displayName} placeholder="Your name" />
			</div>
			<div class="field">
				<label for="role">I am a...</label>
				<select id="role" bind:value={role}>
					<option value="creator">Creator</option>
					<option value="advertiser">Advertiser</option>
					<option value="manager">Manager / Agency</option>
				</select>
			</div>
			{#if err}<p class="warn">{err}</p>{/if}
			<button class="btn btn-primary" type="submit" disabled={!displayName.trim() || submitting}>
				{submitting ? 'Saving…' : 'Continue'}
			</button>
		</form>
	</div>
</div>

<style>
	.wrap {
		display: flex;
		justify-content: center;
		padding: 64px 16px;
	}
	.card {
		max-width: 420px;
		width: 100%;
	}
	.warn {
		color: var(--red);
		font-size: 13px;
	}
</style>
