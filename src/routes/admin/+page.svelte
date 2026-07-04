<script lang="ts">
	let { data } = $props();
	const c = $derived(data.counts);
</script>

<div class="container">
	<h1>Admin</h1>

	{#if c}
		<div class="section-title">Platform overview</div>
		<div class="grid">
			<div class="card">
				<div class="muted" style="font-size:13px;">Creators / Advertisers / Managers</div>
				<div style="font-size:22px; font-weight:600; margin-top:4px;">{c.totalCreators} / {c.totalAdvertisers} / {c.totalManagers}</div>
			</div>
			<div class="card">
				<div class="muted" style="font-size:13px;">Open listings</div>
				<div style="font-size:22px; font-weight:600; margin-top:4px;">{c.openListings}</div>
			</div>
			<div class="card">
				<div class="muted" style="font-size:13px;">Deals in progress / completed</div>
				<div style="font-size:22px; font-weight:600; margin-top:4px;">{c.activeDeals} / {c.completedDeals}</div>
			</div>
		</div>

		<div class="section-title">Go to</div>
		<div class="grid">
			<a class="card admin-link" href="/admin/disputes">
				<strong>Disputes</strong>
				<div class="muted" style="font-size:13px; margin-top:4px;">
					{c.openDisputes} open dispute{c.openDisputes === 1 ? '' : 's'}
				</div>
			</a>
			<a class="card admin-link" href="/admin/feedback">
				<strong>Feedback</strong>
				<div class="muted" style="font-size:13px; margin-top:4px;">
					{c.feedbackCount} submission{c.feedbackCount === 1 ? '' : 's'} ({c.issueCount} issue{c.issueCount === 1 ? '' : 's'})
				</div>
			</a>
			<a class="card admin-link" href="/admin/audit-log">
				<strong>Audit Log</strong>
				<div class="muted" style="font-size:13px; margin-top:4px;">Every delegated/state-changing action, platform-wide</div>
			</a>
			<a class="card admin-link" href="/admin/orgs">
				<strong>Orgs</strong>
				<div class="muted" style="font-size:13px; margin-top:4px;">
					{c.totalOrgs} org{c.totalOrgs === 1 ? '' : 's'}
				</div>
			</a>
		</div>
	{:else}
		<div class="empty">Loading…</div>
	{/if}
</div>

<style>
	.admin-link {
		display: block;
		color: inherit;
		text-decoration: none;
	}
	.admin-link:hover {
		border-color: var(--accent);
		text-decoration: none;
	}
</style>
