# CreatorConnect — Handoff Brief #8 (Org Hierarchy, Admin Org Tools, Marketing Redesign — and a stop-and-validate checkpoint)

Read this whole document before doing anything. **This one ends differently from #6/#7**: it is not
handing off a backlog of more features to build. The founder's own framing closing this session was
"we are in a good step to stop" — this handoff documents what shipped, then deliberately pivots its
last section into a **product validation and planning prompt**, not a task list. If you are an
agent picking this up, read "What happens next" below before assuming the next move is more code.

---

## What shipped since Handoff #7

### 1. Company → org rename, and a full role-hierarchy build-out

The founder gave a direct instruction mid-session — *"instead of company lets call it org"* — which
triggered a full rename across schema, routes, and UI (`orgs.sql`, `rpc-orgs.sql`,
`/settings/org`, `/org/[handle]`, `/u/[handle]`, `Sidebar`/`TopBar`). Two real production bugs
surfaced from live testing after the rename and were fixed same-session:
- A cross-file `DROP ... CASCADE` ordering bug (`orgs.sql` tried to drop a function another file's
  policies still depended on) — fixed by consolidating to one explicit drop-everything-then-recreate
  block at the top of `orgs.sql`.
- RLS infinite recursion in `org_members` (`is_active_org_owner`/`is_active_org_member` queried the
  same table their policies were attached to) — fixed with `security definer` on both functions,
  shipped as a standalone `fix-org-rls-recursion.sql` specifically so applying it wouldn't require
  re-running `orgs.sql`'s destructive drop-cascade against an org the founder had already created.

From there, the founder gave a full role-hierarchy spec: creators unchanged; managers can be a "free
agent" with no org (fully valid); **every advertiser always has an org** — a solo advertiser
auto-becomes the sole owner of their own org, no "individual" state exists for that role; invites use
a token/link (not email-only) so someone without an account yet can join. This shipped as two parts:

- **Advertiser auto-org** (`rpc-advertiser-auto-org.sql`): `ensure_advertiser_org()` /
  `ensure_advertiser_org_self()`. `schema.sql`'s `handle_new_user()` trigger now calls it for every
  advertiser signup, **skipped when `invite_token` is present in signup metadata** — without that
  skip, someone signing up specifically to accept an org invite would get a throwaway solo org
  created microseconds before `accept_org_invite_token` runs, which would then incorrectly block the
  very invite it's supposed to let through. `CompleteProfile.svelte` (the passkey-signup-with-no-
  metadata fallback) calls the self-wrapper directly. A backfill file
  (`fix-advertiser-org-backfill.sql`) covers advertiser accounts created before this shipped.
- **Token-based org invites** (`org-invites.sql`, `rpc-org-invites.sql`): opaque single-use links
  (`/invite/[token]`) that work for signed-out visitors — `get_org_invite_info()` is a
  security-definer RPC granted to `anon`, deliberately not a view, so the raw token column is never
  bulk-selectable. `accept_org_invite_token()` handles both a fresh post-signup landing and an
  already-signed-in user clicking the link. `login/+page.svelte` threads `next`/`role`/`invite_token`
  query params through `signInWithOtp`, and locks the role dropdown when arriving via an invite link.
  `settings/org` replaced its old "invite by email" form (which required the invitee to already have
  a matching-role account) with "create invite link." Added one more RLS policy while here — a member
  can now revoke their own membership (`fix-org-member-self-leave.sql`), needed because accepting a
  new org's invite blocks while already active elsewhere, so switching orgs needs a self-service exit.

### 2. Admin org tools + advertiser org analytics

Two items explicitly deferred out of the role-hierarchy plan, built this session as a fast-follow:

- **`/admin/orgs`** (`fix-org-admin-access.sql`, `rpc-admin-orgs.sql`): platform-admin-only page
  listing every org (owner, member count, type), an expandable roster with an admin-revoke button,
  and a "create an org for someone" form (`create_org_as_admin`, resolves the owner by email).
  Admin gets a full RLS bypass on `orgs`/`org_members`, mirroring the existing
  `or public.is_platform_admin()` convention already used on `deals`/`audit_log`/`feedback`.
- **Advertiser org analytics** (`rpc-org-advertiser-stats.sql`): `get_org_advertiser_stats` /
  `get_org_sponsored_creators`, owner-only, aggregate-only (deal counts, spend, unique creators
  worked with) — deliberately never exposes raw deal rows across org members, respecting
  `orgs.sql`'s own stated non-goal that org membership is identity-only, not a new authority tier
  over other members' deals. Rendered as an "Analytics" + "Creators sponsored" section on
  `/settings/org`, advertiser-org-owners only.

**Live-confirmed** (via direct `curl` against the real Supabase project, not just `npm run check`):
every new RPC from both of the above — `ensure_advertiser_org_self`, `create_org_invite_token`,
`get_org_invite_info`, `accept_org_invite_token`, `revoke_org_invite_token`, `create_org_as_admin`,
`get_org_advertiser_stats` — is deployed and behaves correctly (rejects unauthorized calls with the
right error message; `get_org_invite_info` correctly returns `[]` for an unknown token via the anon
key). The founder appears to have already run every new SQL file through `supabase/README.md` step
31.

### 3. Homepage + roadmap: interactive redesign, then a UI/UX pass

First round (direct, not delegated): added an interactive "Built for every side of the deal" section
to the homepage — click Creator/Advertiser/Manager tabs, the panel swaps tagline/pitch/features/CTA
per role — and rewrote the roadmap page's content (5 stale milestones → 18 accurate ones covering
everything shipped since it was last touched) with filterable category chips (Marketplace / Teams &
Orgs / Trust & Safety / Creator tools / Advertiser tools / Payments).

The founder's reaction was blunt — *"the ui ux is terable"* — with an explicit instruction to
delegate to a different agent framed as a UI/UX expert, scoped to exactly these two pages. That
agent's diagnosis, confirmed correct on review: **the entire app, including these two public
marketing pages, was sharing the internal dashboard's layout** (fixed top bar + icon-only sidebar).
For a signed-out visitor, that rendered a near-empty icon-only sidebar next to marketing copy —
reading as an unfinished internal tool, not a landing page. Fix: a `(marketing)` route group for
`/` and `/roadmap` with its own sticky header/footer; the root `+layout.svelte` now conditionally
skips the dashboard chrome for exactly those two paths, leaving every other route (including the
authenticated dashboard) byte-for-byte unchanged — verified live, not just asserted. Visual result:
real hero with gradient accent text and a stat row, a vertical sidebar-style role switcher, staggered
entrance animation, a kanban-style 3-column roadmap board with a shipped-progress bar.

One real bug caught in review (not by the redesign agent): on mobile, the third role tab
("Managers / Agencies") scrolled off-screen with no visual affordance that it was reachable —
functional (confirmed via `scrollWidth` > `clientWidth`), but looked broken. Fixed with a fade-out
edge mask signaling "swipe for more."

## Verification

`npm run check` clean throughout (0 errors at every checkpoint). Every new anon/admin-reachable RPC
checked live against the real Supabase project via `curl` with the actual anon key, not just
asserted from reading the SQL. UI changes checked in the live preview at desktop (1280px) and mobile
(375px) widths, including click-testing the role tabs, roadmap filter chips, and confirming
`/dashboard` (and every other route) render their original chrome unchanged after the layout split.

**Still not exercisable without the founder's own action** (flagged in Handoff #7 too, still
outstanding): the actual signup/invite click-through loop end to end — sign up a fresh advertiser and
confirm an org auto-appears; create an invite link, open it in a fresh/incognito session, sign up,
confirm landing in the org joined. No agent in this session had a way to trigger a real signup email.

---

## What happens next

**Do not treat this as "here's the next backlog, keep building."** A large amount of speculative
product surface has shipped since the last real validation checkpoint — the Phase 0 creator/manager
interviews recorded in `docs/PRODUCT.md` (Section 7). Everything from Handoff #5 onward (company/org
profiles, dual-consent showcase, manager notes, e-signature, the full org/hierarchy/invite system,
admin org tools, advertiser analytics, and now the marketing redesign) was built on the founder's own
product judgment, not on interviews or real usage — a reasonable way to move fast, but it means a
real backlog of unvalidated assumptions has now accumulated, larger than at any prior checkpoint in
this project's history. The founder's own words ending this session — *"we are in a good step to
stop"* — line up with that: this is a natural pause point to validate before compounding further.

**If you are an agent (or the founder) opening this document to start the next session, do this
first, before writing any code:**

1. **Close the loop on what's already built but unverified.** Run the manual end-to-end tests
   flagged above and in Handoff #7 (advertiser auto-org at signup, the invite-link loop,
   `/admin/orgs` against a real org). These are cheap, fast, and should happen before anything else
   — there's no point validating product direction on top of a foundation that might have a bug no
   one's actually clicked through yet.

2. **Get the org/hierarchy and marketing changes in front of real people**, the same way Phase 0 did
   for the original mechanism design (`docs/PRODUCT.md` Section 7 — 10-15 creator/manager
   interviews, resolved and recorded). Concrete questions worth asking, per audience:
   - **Creators**: does anything about org affiliation (agencies, the dual-consent showcase) make
     sense from their side, or is it invisible/irrelevant to how they actually think about being
     represented?
   - **Advertisers**: does "every advertiser always has an org, even solo" feel natural, or does it
     feel like unwanted structure imposed on someone who just wants to book a slot? Does the
     analytics/"creators sponsored" view answer a real question they have, or a fabricated one?
   - **Managers/agencies**: is the invite-link flow (inviting someone with no account yet) something
     they'd actually use to onboard a team, or do real agencies not work that way? Was the private
     notes feature (Handoff #7) actually used, or ignored?
   - **Fresh visitors** (anyone, ideally close to the target creator/advertiser/manager profile): does
     the redesigned homepage's per-role pitch actually persuade someone who's never heard of
     CreatorConnect, or does it still read as generic?

3. **Decide what "validated enough to keep building" looks like** before running the above — same
   discipline `docs/ROADMAP.md` Section 1 already establishes ("validate the cheapest-to-check
   unknowns before writing more code"). A finding of "nobody used the showcase feature" or "the org
   model confused every agency we showed it to" should change the plan, not get filed away.

4. **Only after that**, turn findings into a re-scoped, prioritized plan for what's next — likely
   candidates already known to be waiting regardless of validation outcome: real payments (Stripe
   Connect — still simulated, the single biggest gap between "usable demo" and "real marketplace"),
   and whatever the interviews surface as the actual next-highest-value gap, which may not be
   anything currently on `docs/ROADMAP.md`'s list at all.

**Explicit instruction to whatever picks this up**: resist defaulting to more feature construction.
The founder stopped here on purpose. Help them validate and plan first; the next round of engineering
should be scoped by what that produces, not by what's easiest to build next.

---

*Prepared at the close of the same continuous session that shipped the org/hierarchy work, the admin
org tools, and the marketing redesign, 2026-07-04. All three RPC batches confirmed live against the
real Supabase project via direct `curl` checks before this document was written, per this project's
established practice of testing rather than assuming.*
