<script lang="ts">
	import { page } from '$app/state';
	import { TriangleAlert, Lightbulb, X } from '@lucide/svelte';

	let { onClose } = $props();

	const user = $derived(page.data.user);
	const supabase = $derived(page.data.supabase);

	let kind = $state<'issue' | 'idea' | null>(null);
	let message = $state('');
	let busy = $state(false);
	let err = $state('');
	let done = $state(false);

	function pick(k: 'issue' | 'idea') {
		kind = k;
		err = '';
	}

	function back() {
		kind = null;
		err = '';
	}

	async function submit() {
		if (!supabase || !user || !kind || !message.trim()) return;
		busy = true;
		err = '';
		const { error } = await supabase.from('feedback').insert({
			user_id: user.id,
			kind,
			message: message.trim(),
			page_path: page.url.pathname
		});
		busy = false;
		if (error) {
			err = error.message;
			return;
		}
		done = true;
	}
</script>

<div
	class="overlay"
	role="presentation"
	onclick={onClose}
	onkeydown={(e) => e.key === 'Escape' && onClose()}
>
	<div
		class="modal"
		role="dialog"
		aria-modal="true"
		aria-label="Feedback"
		tabindex="-1"
		onclick={(e) => e.stopPropagation()}
		onkeydown={(e) => e.key === 'Escape' && onClose()}
	>
		<button class="close-btn" onclick={onClose} aria-label="Close">
			<X size={18} />
		</button>

		{#if done}
			<div class="done">
				<h3>Thanks, got it.</h3>
				<p class="muted">We appreciate you taking the time to let us know.</p>
				<button class="btn btn-primary btn-sm" onclick={onClose}>Close</button>
			</div>
		{:else if !kind}
			<h3 class="title">Send feedback</h3>
			<div class="options">
				<button class="option" onclick={() => pick('issue')}>
					<TriangleAlert size={24} />
					<div class="option-title">Report an issue</div>
					<div class="option-sub muted">Something broken or not working as expected</div>
				</button>
				<button class="option" onclick={() => pick('idea')}>
					<Lightbulb size={24} />
					<div class="option-title">Suggest an idea</div>
					<div class="option-sub muted">A feature or improvement you'd like to see</div>
				</button>
			</div>
		{:else}
			<h3 class="title">{kind === 'issue' ? 'Report an issue' : 'Suggest an idea'}</h3>
			<div class="field">
				<label for="feedback-message">
					{kind === 'issue' ? 'What went wrong?' : 'What would you like to see?'}
				</label>
				<textarea
					id="feedback-message"
					bind:value={message}
					placeholder={kind === 'issue' ? 'Describe the issue you ran into…' : 'Describe your idea…'}
					required
				></textarea>
			</div>
			{#if err}<p class="warn">{err}</p>{/if}
			<div class="row">
				<button class="btn btn-primary btn-sm" onclick={submit} disabled={busy || !message.trim()}>
					{busy ? 'Sending…' : 'Send feedback'}
				</button>
				<button class="btn btn-sm" onclick={back} disabled={busy}>Back</button>
			</div>
		{/if}
	</div>
</div>

<style>
	.overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.55);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 200;
		padding: 20px;
	}
	.modal {
		position: relative;
		background: var(--panel);
		border: 1px solid var(--border);
		border-radius: var(--radius);
		padding: 24px;
		width: 100%;
		max-width: 420px;
		box-shadow: 0 12px 40px rgba(0, 0, 0, 0.4);
	}
	.close-btn {
		position: absolute;
		top: 12px;
		right: 12px;
		background: none;
		border: none;
		color: var(--text-muted);
		padding: 4px;
		display: flex;
	}
	.close-btn:hover {
		color: var(--text);
	}
	.title {
		margin: 0 0 16px;
		font-size: 16px;
	}
	.options {
		display: flex;
		flex-direction: column;
		gap: 10px;
	}
	.option {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		gap: 6px;
		text-align: left;
		background: var(--panel-raised);
		border: 1px solid var(--border-strong);
		border-radius: var(--radius);
		padding: 16px;
		color: var(--text);
		transition: border-color 0.12s, background 0.12s;
	}
	.option:hover {
		border-color: var(--accent);
		background: var(--accent-bg);
	}
	.option-title {
		font-weight: 700;
		font-size: 14px;
	}
	.option-sub {
		font-size: 12px;
	}
	.done {
		text-align: center;
	}
	.done h3 {
		margin: 8px 0 4px;
	}
	.done p {
		margin: 0 0 16px;
	}
	.warn {
		color: var(--red);
		font-size: 13px;
	}
</style>
