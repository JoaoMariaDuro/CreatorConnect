<script lang="ts">
	import { formatDateTime } from '$lib/format';

	let { data } = $props();

	let filter = $state<'all' | 'issue' | 'idea'>('all');
	const filtered = $derived(
		filter === 'all' ? data.feedback : data.feedback.filter((f: any) => f.kind === filter)
	);
</script>

<div class="container">
	<h1>Feedback</h1>

	<div class="row" style="gap:8px; margin-bottom:16px;">
		<button class="btn {filter === 'all' ? 'btn-primary' : ''}" onclick={() => (filter = 'all')}>
			All ({data.feedback.length})
		</button>
		<button class="btn {filter === 'issue' ? 'btn-primary' : ''}" onclick={() => (filter = 'issue')}>
			Issues ({data.feedback.filter((f: any) => f.kind === 'issue').length})
		</button>
		<button class="btn {filter === 'idea' ? 'btn-primary' : ''}" onclick={() => (filter = 'idea')}>
			Ideas ({data.feedback.filter((f: any) => f.kind === 'idea').length})
		</button>
	</div>

	{#if filtered.length === 0}
		<div class="empty">No {filter === 'all' ? 'feedback' : filter + 's'} submitted yet.</div>
	{:else}
		<div class="stack">
			{#each filtered as f (f.id)}
				<div class="card">
					<div class="row" style="justify-content: space-between; margin-bottom:8px;">
						<span class="badge {f.kind === 'issue' ? 'badge-stale-hard' : 'badge-d'}">
							{f.kind === 'issue' ? 'Issue' : 'Idea'}
						</span>
						<span class="muted" style="font-size:13px;">{formatDateTime(f.created_at)}</span>
					</div>
					<p style="margin:0 0 8px;">{f.message}</p>
					<div class="muted" style="font-size:13px;">
						{f.submitter?.display_name ?? 'Unknown user'} ({f.submitter?.role ?? '—'})
						{#if f.page_path}· on <code>{f.page_path}</code>{/if}
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>
