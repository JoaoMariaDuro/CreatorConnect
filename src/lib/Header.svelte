<script lang="ts">
	import {
		viewerState,
		setViewer,
		setActingAsCreator,
		creators,
		advertisers,
		managers,
		getManager
	} from '$lib/store.svelte';

	const viewer = $derived(viewerState.current);

	function onViewerSelect(e: Event) {
		const value = (e.target as HTMLSelectElement).value;
		const [role, id] = value.split(':');
		setViewer({ role, id } as any);
	}

	function onActingAsSelect(e: Event) {
		const value = (e.target as HTMLSelectElement).value;
		setActingAsCreator(value || undefined);
	}

	const currentManager = $derived(viewer.role === 'manager' ? getManager(viewer.id) : undefined);
</script>

<header>
	<div class="container header-inner">
		<a class="logo" href="/">CreatorConnect</a>
		<nav>
			<a href="/">Browse</a>
			<a href="/dashboard">Dashboard</a>
			<a href="/create">Create Listing</a>
		</nav>
		<div class="viewer-switcher">
			<label for="viewer-select" class="muted" style="font-size:12px;">Viewing as</label>
			<select id="viewer-select" value={`${viewer.role}:${viewer.id}`} onchange={onViewerSelect}>
				<optgroup label="Creators">
					{#each creators as c (c.id)}
						<option value={`creator:${c.id}`}>{c.name}</option>
					{/each}
				</optgroup>
				<optgroup label="Advertisers">
					{#each advertisers as a (a.id)}
						<option value={`advertiser:${a.id}`}>{a.company}</option>
					{/each}
				</optgroup>
				<optgroup label="Managers">
					{#each managers as m (m.id)}
						<option value={`manager:${m.id}`}>{m.name} ({m.agency})</option>
					{/each}
				</optgroup>
			</select>

			{#if viewer.role === 'manager' && currentManager}
				<select
					value={viewer.actingAsCreatorId ?? ''}
					onchange={onActingAsSelect}
					title="Acting as creator"
				>
					<option value="">— roster view —</option>
					{#each currentManager.creatorIds as cid}
						{@const c = creators.find((x) => x.id === cid)}
						{#if c}
							<option value={cid}>Acting as {c.name}</option>
						{/if}
					{/each}
				</select>
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
	.viewer-switcher {
		display: flex;
		align-items: center;
		gap: 8px;
	}
	select {
		font-family: inherit;
		font-size: 13px;
		padding: 6px 8px;
		border: 1px solid var(--border);
		border-radius: 6px;
		background: #fff;
	}
</style>
