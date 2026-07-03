<script lang="ts">
	import { formatDateTime } from '$lib/format';

	let { data } = $props();
	const auditLog = $derived(data.auditLog ?? []);

	// The full set of target_table values any RPC in supabase/rpc-*.sql writes into.
	const tables = [
		'all',
		'reservations',
		'deals',
		'listing_offers',
		'listing_exclusivity_grants',
		'manager_creator_links',
		'profiles'
	];
</script>

<div class="container">
	<h1>Audit Log</h1>

	<div class="field" style="max-width:280px; margin-bottom:16px;">
		<label for="target-table">Filter by table</label>
		<select id="target-table" value={data.targetTable} onchange={(e) => {
			const v = (e.target as HTMLSelectElement).value;
			const url = new URL(window.location.href);
			if (v === 'all') url.searchParams.delete('target_table');
			else url.searchParams.set('target_table', v);
			window.location.href = url.toString();
		}}>
			{#each tables as t}
				<option value={t}>{t === 'all' ? 'All tables' : t}</option>
			{/each}
		</select>
	</div>

	{#if auditLog.length === 0}
		<div class="empty">No audit log entries{data.targetTable !== 'all' ? ` for ${data.targetTable}` : ''}.</div>
	{:else}
		<div class="stack">
			{#each auditLog as row (row.id)}
				<div class="audit-row">
					<div class="row" style="justify-content: space-between;">
						<strong>{row.actor?.display_name ?? 'Unknown'}</strong>
						<span class="muted" style="font-size:12px;">{formatDateTime(row.created_at)}</span>
					</div>
					<div class="muted" style="font-size:13px;">{row.action} · {row.target_table}</div>
					{#if row.acting_as_id}
						<div class="acting-banner">Acting as {row.actor?.display_name} on behalf of {row.acting_as?.display_name}</div>
					{/if}
					<details>
						<summary>Details</summary>
						<pre>{JSON.stringify(row.before, null, 2)} &rarr; {JSON.stringify(row.after, null, 2)}</pre>
					</details>
				</div>
			{/each}
		</div>
		{#if auditLog.length === 200}
			<p class="muted" style="font-size:13px; margin-top:12px;">Showing the 200 most recent entries.</p>
		{/if}
	{/if}
</div>

<style>
	.audit-row {
		padding: 8px 0;
		border-bottom: 1px solid var(--border);
		font-size: 13px;
	}
	.audit-row:last-child {
		border-bottom: none;
	}
	.audit-row pre {
		font-size: 11px;
		white-space: pre-wrap;
		word-break: break-word;
		background: var(--panel-raised);
		padding: 8px;
		border-radius: 6px;
		margin-top: 6px;
	}
	.acting-banner {
		background: var(--purple-bg);
		color: var(--purple);
		padding: 6px 10px;
		border-radius: var(--radius);
		font-size: 12px;
		font-weight: 600;
		margin: 6px 0;
	}
</style>
