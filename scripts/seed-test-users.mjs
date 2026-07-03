#!/usr/bin/env node
// CreatorConnect — creates 6 confirmed test accounts (3 creators, 2 advertisers, 1 manager) via the
// Supabase admin API, and prints a magic-link sign-in URL for each so the founder can click into the
// app AS any of these personas without needing a real inbox.
//
// This script only ever INSERTs test rows into auth.users (via the admin API) — it never touches
// real production data paths. Nothing here talks to Stripe; no real money is involved.
//
// USAGE (run once, locally, by the founder — never by an agent, never in CI):
//   export PUBLIC_SUPABASE_URL=https://xxxx.supabase.co        # same value as in your .env
//   export SUPABASE_SERVICE_ROLE_KEY=<paste from Supabase dashboard, this run only>
//   node scripts/seed-test-users.mjs
//
// SUPABASE_SERVICE_ROLE_KEY is a secret with full admin rights over your project. Export it in your
// shell for this one run and do not write it to any file, .env, or commit. This script never logs its
// value — only a "present/missing" check.
//
// Safe to re-run: if a test account's email already exists, this script catches that specific error,
// looks up the existing user instead of failing, and just regenerates a fresh sign-in link for it — it
// never creates duplicate users. Re-run any time a previously printed link goes stale/expired.
//
// After this script, run supabase/seed-data.sql (via the Supabase SQL Editor) to populate listings,
// negotiations, deals, and delegation rows owned by these 6 accounts. See supabase/README.md's
// "Test/seed data" section for the full two-step process.

import { createClient } from '@supabase/supabase-js';

// Obviously-fake domain — nobody can mistake these for real addresses, and it's easy to grep/delete
// later (e.g. `delete from auth.users where email like '%@seed.creatorconnect.test';`).
const FAKE_DOMAIN = 'seed.creatorconnect.test';

const SUPABASE_URL = process.env.PUBLIC_SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

// The app's local dev origin the magic link should redirect back into. Override with
// SEED_APP_ORIGIN=http://localhost:5174 (etc.) if your dev server runs on a different port.
const APP_ORIGIN = process.env.SEED_APP_ORIGIN ?? 'http://localhost:5173';
const REDIRECT_TO = `${APP_ORIGIN}/auth/confirm`;

function fail(message) {
	console.error(`\n✗ ${message}\n`);
	process.exit(1);
}

if (!SUPABASE_URL) {
	fail(
		'PUBLIC_SUPABASE_URL is not set. Export the same value you have in your .env, e.g.\n' +
			'  export PUBLIC_SUPABASE_URL=https://xxxx.supabase.co'
	);
}
if (!SERVICE_ROLE_KEY) {
	fail(
		'SUPABASE_SERVICE_ROLE_KEY is not set. Copy it from Supabase dashboard → Project Settings → API\n' +
			'  keys (the "service_role" secret key — NOT the publishable/anon key), and export it for this\n' +
			'  run only:\n' +
			'  export SUPABASE_SERVICE_ROLE_KEY=<paste here>\n' +
			'  Never commit this value or write it to a file.'
	);
}
console.log('✓ PUBLIC_SUPABASE_URL is set');
console.log('✓ SUPABASE_SERVICE_ROLE_KEY is present (value not logged)');
console.log(`✓ Magic links will redirect to ${REDIRECT_TO}\n`);

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
	auth: { autoRefreshToken: false, persistSession: false }
});

// The 6 test personas. `role` and `display_name` land in raw_user_meta_data, which
// public.handle_new_user() (supabase/schema.sql) reads to auto-create the matching profiles row.
// follower_count/niche/platform are NOT passed here — handle_new_user() only sets role + display_name;
// the rest of each profile (follower_count, niche_tags, platform_handles) is filled in by
// supabase/seed-data.sql's UPDATE statements against these same accounts, since that's plain table
// data, not auth metadata.
const TEST_USERS = [
	{
		email: `creator.jordan@${FAKE_DOMAIN}`,
		role: 'creator',
		display_name: 'Jordan Reyes',
		note: 'Creator — YouTube, ~120k subs, tech/gadget reviews'
	},
	{
		email: `creator.maya@${FAKE_DOMAIN}`,
		role: 'creator',
		display_name: 'Maya Lin',
		note: 'Creator — Instagram, ~85k followers, beauty/lifestyle'
	},
	{
		email: `creator.devon@${FAKE_DOMAIN}`,
		role: 'creator',
		display_name: 'Devon Brooks',
		note: 'Creator — TikTok, ~250k followers, comedy/skits'
	},
	{
		email: `advertiser.northwind@${FAKE_DOMAIN}`,
		role: 'advertiser',
		display_name: 'Northwind Outdoor Co.',
		note: 'Advertiser — outdoor gear brand'
	},
	{
		email: `advertiser.lumen@${FAKE_DOMAIN}`,
		role: 'advertiser',
		display_name: 'Lumen Skincare',
		note: 'Advertiser — skincare brand'
	},
	{
		email: `manager.priya@${FAKE_DOMAIN}`,
		role: 'manager',
		display_name: 'Priya Shah',
		note: 'Manager — represents 2 of the 3 test creators'
	}
];

async function findExistingUserByEmail(email) {
	// Admin API has no "get user by email" endpoint, so page through listUsers(). Test-account volumes
	// are tiny (6 users), so a single page (default 50/page) is always enough in practice — but loop
	// properly anyway in case this project's auth.users already has many users before this script runs.
	let page = 1;
	const perPage = 200;
	for (;;) {
		const { data, error } = await supabase.auth.admin.listUsers({ page, perPage });
		if (error) throw error;
		const match = data.users.find((u) => u.email?.toLowerCase() === email.toLowerCase());
		if (match) return match;
		if (data.users.length < perPage) return null; // last page, no match
		page += 1;
	}
}

async function createOrFetchUser(user) {
	const { data, error } = await supabase.auth.admin.createUser({
		email: user.email,
		email_confirm: true,
		user_metadata: { role: user.role, display_name: user.display_name }
	});

	if (!error) {
		return { authUser: data.user, created: true };
	}

	// Idempotent-ish re-run support: if this exact email already has an account (from a prior run of
	// this script), don't fail the whole batch — fetch the existing user and keep going. Any other
	// error (bad key, network, etc.) should still stop the script loudly.
	const alreadyExists =
		error.code === 'email_exists' ||
		error.status === 422 ||
		/already been registered|already exists/i.test(error.message ?? '');

	if (!alreadyExists) {
		throw error;
	}

	const existing = await findExistingUserByEmail(user.email);
	if (!existing) {
		// Shouldn't happen (createUser just told us it exists), but don't silently swallow it.
		throw new Error(`createUser reported "${user.email}" already exists, but it could not be found via listUsers()`);
	}
	return { authUser: existing, created: false };
}

async function generateSignInLink(email) {
	const { data, error } = await supabase.auth.admin.generateLink({
		type: 'magiclink',
		email,
		options: { redirectTo: REDIRECT_TO }
	});
	if (error) throw error;
	// action_link is already the full, ready-to-open URL:
	//   <supabase-url>/auth/v1/verify?type=magiclink&token=<hashed_token>&redirect_to=<REDIRECT_TO>
	// Opening it verifies the token server-side, then 303s into REDIRECT_TO with ?token_hash=&type=,
	// which src/routes/auth/confirm/+server.ts exchanges for a real session via verifyOtp().
	return data.properties.action_link;
}

async function main() {
	const results = [];

	for (const user of TEST_USERS) {
		process.stdout.write(`Processing ${user.email} (${user.role})... `);
		try {
			const { authUser, created } = await createOrFetchUser(user);
			const actionLink = await generateSignInLink(user.email);
			console.log(created ? 'created' : 'already existed, reused');
			results.push({ ...user, id: authUser.id, actionLink, created });
		} catch (err) {
			console.log('FAILED');
			console.error(`  ${err.message ?? err}`);
			results.push({ ...user, id: null, actionLink: null, created: false, failed: true });
		}
	}

	console.log('\n' + '='.repeat(100));
	console.log('SIGN-IN LINKS — copy/paste any of these into your browser to sign in as that persona');
	console.log('='.repeat(100));

	for (const r of results) {
		console.log(`\n${r.display_name}  <${r.email}>  [${r.role}]`);
		console.log(`  ${r.note}`);
		if (r.failed) {
			console.log('  FAILED — see error above, this account was not created/linked.');
		} else {
			console.log(`  Sign in as ${r.display_name}: ${r.actionLink}`);
		}
	}

	console.log('\n' + '='.repeat(100));
	console.log('SUMMARY TABLE');
	console.log('='.repeat(100));
	console.log(
		[
			'email'.padEnd(34),
			'role'.padEnd(11),
			'display_name'.padEnd(20),
			'status'
		].join(' | ')
	);
	console.log('-'.repeat(100));
	for (const r of results) {
		console.log(
			[
				r.email.padEnd(34),
				r.role.padEnd(11),
				r.display_name.padEnd(20),
				r.failed ? 'FAILED' : r.created ? 'created' : 'already existed'
			].join(' | ')
		);
	}

	console.log(
		'\nThese sign-in links are single-use and expire after a while. If one goes stale, just re-run\n' +
			'this script (`node scripts/seed-test-users.mjs`) — it will not create duplicate accounts, it will\n' +
			'just print a fresh link for each already-existing test user.\n' +
			'\n' +
			'Next step: run supabase/seed-data.sql via the Supabase SQL Editor to populate listings, deals,\n' +
			'and delegation data for these accounts (see supabase/README.md, "Test/seed data" section).\n'
	);

	const anyFailed = results.some((r) => r.failed);
	if (anyFailed) process.exit(1);
}

main().catch((err) => {
	fail(err.stack ?? String(err));
});
