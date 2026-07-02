# CreatorConnect — Handoff Brief #1

Read this whole document before touching code. It has three parts: (A) the orchestrator
instructions you must follow, (B) full project context, (C) the prioritized task backlog you're
being handed. Part C is the actual work order — A and B exist so you can execute it correctly
without re-deriving decisions that have already been made.

---

## Part A — Orchestrator instructions (Fable)

You are Fable, acting exclusively as an *orchestrator*. You never act as the primary agent that
performs tasks directly. Your job is to configure, direct, and evaluate subagents running on
Sonnet or Haiku (whichever version is currently available) — not to do the work yourself.

1. **Set up a subagent for every task that requires execution**, and explicitly choose which
   model runs it — Sonnet or Haiku (the current available version) — based on the task's
   complexity and required capability. State which model you chose and why before dispatching.
   Do not perform substantive work yourself.
2. **Define a clear, final goal for each subagent** before dispatching it. A general task
   description is not sufficient — provide an explicit, checkable criterion that defines when
   the result counts as achieved.
3. **Explicitly decide the context-sharing policy for each set of subagents**, and state that
   decision before dispatching them:
   - Fully isolated subagents (no context leakage between them), or
   - Deliberate, scoped context-sharing between specific subagents.
   Never leave this undecided or implicit — always declare which mode you're using and why.
4. **Run a review loop after each subagent response:**
   - Evaluate the response against the final goal defined in step 2.
   - If the result is unsatisfactory, send it back to the same subagent with an explicit,
     specific reason for rejection — never a vague "try again." The subagent must know exactly
     what to fix.
   - Repeat until the result meets the goal. Do not accept a first-pass result by default.
5. **Cap review loops at 5 iterations per subagent task.**
   - If the goal is met within 5 iterations, accept the result and proceed.
   - If not met after 5 iterations, stop the loop and escalate — report the unresolved gap
     between your expectations and the subagent's output rather than continuing indefinitely.
6. **Follow the Superpowers methodology** ([obra/superpowers](https://github.com/obra/superpowers))
   for structuring agentic workflows. In particular, apply the `subagent-driven-development`
   skill: dispatch a fresh subagent per task, and review each result in two stages — first spec
   compliance, then code/output quality — before accepting it.

**Constraints:**
- Never let a subagent operate as the primary decision-maker on whether its own output is
  acceptable — that authority always belongs to you, the orchestrator.
- Never dispatch a subagent without a stated final goal and a stated context-sharing decision.
- Never dispatch a subagent without explicitly stating which model it runs on and the reasoning.
- Never exceed 5 review iterations per task without escalating.

**Success criteria:** a task is complete when the orchestrator has confirmed, against the
originally stated goal, that the subagent's output meets it — not merely when a subagent has
produced a response.

---

## Part B — Project context

### What this is

CreatorConnect is a booking/reservation marketplace connecting brand advertisers with mid-tier
creators (50K–1M followers) for sponsorship slots — positioned as "Booking.com for sponsorship
slots," not an auction. Solo-founder project (same founder as the Lota car-flipping tool, reusing
that SvelteKit + Supabase stack pattern). Currently pre-launch, no real users, no real money moved
yet — Stripe is stubbed/simulated throughout.

Working directory: `/Users/joaoduro/Desktop/exploration/creator-connect`. This is its own git
repo (`git log` shows 15 commits, `main` branch, 11 commits ahead of `origin/main` — never
pushed). One uncommitted change exists right now: `supabase/README.md` (a redirect-URL port
number fix, 5299→5173, not yet committed — harmless, low priority to commit whenever).

### Foundational docs — read these first, in order

1. [`docs/RESEARCH_BRIEF.md`](../docs/RESEARCH_BRIEF.md) — market research that grounds
   everything else.
2. [`docs/PRODUCT.md`](../docs/PRODUCT.md) — product vision, personas, the three pricing
   mechanisms (A/C/D), MVP scope, open questions. **Revised once** based on real Phase 0
   founder-conducted creator/manager interviews — read the revision log at the top and Section 7
   (open questions, two now marked RESOLVED).
3. [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) — schema/RLS/RPC design, the six numbered
   risks (concurrency, delegation surface area, Stripe delayed-transfer mechanics, etc.).
4. [`docs/ROADMAP.md`](../docs/ROADMAP.md) — phased build sequencing. **Important divergence to
   know about:** the roadmap's stated sequencing is "ship mechanism D first as the full Phase 1
   MVP, build A and C as a Fast-Follow immediately after, not simultaneously." What actually got
   built (see commit log below) shipped D, then A/C shortly after in a dedicated commit
   (`baa42fe`) — so in practice the sequencing intent was followed reasonably closely, but read
   the roadmap as an *aspirational planning document written before/during the build*, not a
   changelog. Cross-check against actual code before assuming any epic's "done when" criteria are
   met — several are not (see Part C).
5. [`supabase/README.md`](../supabase/README.md) — the exact SQL run order for a fresh Supabase
   project, plus a live-maintained "What's NOT here yet" section. **Keep this file updated** as
   you close gaps — it's the single source of truth for what's actually shipped in the DB layer,
   more reliable than ROADMAP.md for that specific question.

### Stack

SvelteKit (Svelte 5 runes — `$state`, `$derived`, `$props()`, `$effect()`) + TypeScript, Supabase
(Postgres + RLS + `security definer` RPCs + `pg_cron`), `@supabase/ssr` for SSR auth (magic link +
WebAuthn passkeys), `@lucide/svelte` icons, dark-theme CSS design system inspired by the Supabase
dashboard UI. No test framework installed yet (see Part C, P0 item on this — it's a real gap, not
an oversight to route around).

### The three pricing mechanisms (core domain model — internalize this before writing any code)

Creators choose one of three mechanisms **per listing** at creation time:
- **Mechanism A** — fixed asking price + sequential counter-offer (classifieds-style, one
  advertiser at a time, no deposit).
- **Mechanism C** — reserve-the-relationship: advertiser gets an exclusivity window (early access,
  no binding hold, no deposit); real price negotiated bilaterally once a deal is in motion.
- **Mechanism D** — reserve-the-slot: advertiser pays a non-refundable deposit that takes the slot
  off market and starts a creator confirmation clock; richest mechanism, has a sealed-bid
  tiebreaker for rare contention (**tiebreaker itself is deferred to Phase 1.5 — tables exist,
  RPCs don't**, this is intentional, see `ROADMAP.md` §3).

All three converge into one `deals` table (`reservation_id` / `offer_id` / `exclusivity_grant_id`
— exactly one non-null, enforced by a check constraint) so contract generation, escrow, delivery,
and dispute logic are mechanism-agnostic and written once.

### What's actually built (verified against the filesystem, not assumed from docs)

**Schema/RPCs (`supabase/*.sql`, run in the numbered order in `supabase/README.md`):**
`schema.sql` (profiles + signup trigger), `listings.sql`, `negotiations.sql` (reservations,
listing_offers, listing_exclusivity_grants, + unpopulated tiebreak tables), `deals.sql`,
`delegation.sql` (manager links, price bands, audit log, notifications), `rpc-mechanism-d.sql`,
`rpc-delivery.sql`, `rpc-delegation.sql`, `cron-scheduling.sql`, `rpc-mechanism-ac.sql`,
`fix-profile-self-insert.sql`.

**Pages (`src/routes/`):** landing (`+page.svelte`), `login` (magic link + passkey),
`browse` (platform/mechanism filter, **no text search**), `create` (listing creation with
mechanism picker), `dashboard`, `listings/[id]` (the big one — full A/C/D interaction UI +
manager price-band UI), `deal/[id]`, `settings/managers`, `roadmap` (public), `+error.svelte`
(404). **No listing edit/cancel route exists** — `create/` is create-only.

**Auth:** SSR-aware via `hooks.server.ts` / `+layout.server.ts` / `+layout.ts`, magic link +
WebAuthn passkeys (`experimental.passkey` flag, `signInWithPasskey()` /
`auth.registerPasskey()`). Passkey RP ID is set to `localhost` in the Supabase dashboard,
dev server pinned to port 5173 in `.claude/launch.json` to match. **Passkey sign-in was wired
and the config error fixed, but end-to-end success was never visually confirmed** in the previous
session (blocked by a dev-server port conflict with the founder's own manually-run process) — see
Part C, P0.

**Explicitly, deliberately NOT built (per docs, not bugs):**
- Real Stripe Connect — escrow/deposit/payout are simulated state transitions in the DB only, no
  real money moves anywhere. Deferred by explicit founder instruction ("let's leave Stripe for
  later"). Do not build this without the founder asking for it by name.
- Sealed-bid tiebreaker RPCs (Phase 1.5, contention-triggered — not urgent, no real users yet so
  no real contention to trigger it).
- Admin dispute UI (Phase 2.5, volume-triggered — currently founder resolves disputes by hand via
  direct SQL/dashboard access, which is fine at zero-user scale).

### Session conventions worth preserving

- The founder tests changes himself before anything gets committed — don't commit speculatively;
  commit only when explicitly asked, same as the general Claude Code default.
- `docs/*.md` revisions are done by **striking through** superseded text (`~~...~~`) rather than
  deleting it, with a revision-log paragraph at the top explaining what changed and why — preserve
  this pattern if you touch those docs again.
- Dev server: use `.claude/launch.json`'s `creator-connect-dev` config (port 5173, hardcoded to
  match the Supabase passkey RP Origins setting) via the preview tool, not a manually-run
  `npm run dev` — the two conflict over the port. If port 5173 is already occupied by a
  non-preview-tool process, that's the founder's own manual server; ask before killing it.

---

## Part C — Task backlog (priority-ordered)

Work top to bottom. Each item states its "done when" criterion per the orchestrator's own rule
(§A.2) — use it verbatim as the subagent's final goal, don't loosen it.

### P0 — Close MVP gaps that block a real pilot launch

1. **Verify passkey auth end-to-end.** Last known state: config error fixed, RP ID set to
   `localhost`, port pinned to 5173, but never visually confirmed working after the fix. Done
   when: a fresh browser session can register a passkey via the sidebar "Add a passkey" button
   and *separately* sign in from a logged-out state via "Sign in with a passkey" on `/login`,
   both confirmed via the preview tool (screenshot/snapshot), no console errors.
2. **Add listing edit/pause.** `PRODUCT.md` Flow 1 step 5 explicitly requires creators be able to
   edit price/terms any time before a binding commitment exists on that listing. No edit route
   exists (`create/` is create-only). Done when: a creator (or delegated manager, band-checked)
   can edit an open listing's terms and pause/unpublish it, with RLS preventing edits once a
   binding commitment exists (accepted offer in A, confirmed deal in C, placed reservation in D)
   — matching the existing lifecycle status machine, not inventing a new one.
3. **Add browse text search.** Currently only platform/mechanism dropdown filters exist. Done
   when: advertisers can filter browse results by a free-text query against listing title/
   description/creator name, combinable with the existing filters.
4. **Schedule mechanism C's expiry job.** `expire_exclusivity` exists in
   `rpc-mechanism-ac.sql` but `cron-scheduling.sql` only schedules D's two jobs — flagged as a
   known gap in `supabase/README.md`'s "What's NOT here yet" section. Done when: a third
   `cron.schedule` entry runs `expire_exclusivity` on the same per-row exception-handling wrapper
   pattern already used for D's jobs (see `cron-scheduling.sql` for the pattern to copy), and
   `supabase/README.md` is updated to remove this from the "not yet" list.

### P1 — Test coverage (the single highest-priority Phase 2 item per ARCHITECTURE.md, and currently at zero)

5. **Stand up an RLS/RPC test suite from scratch.** There is currently no test framework
   installed and no test files anywhere in the repo. `ARCHITECTURE.md` calls the tripled (A/C/D)
   delegation/RLS surface area "the single biggest build risk" and `ROADMAP.md` §4 (2.1) demands
   per-mechanism coverage of every band-checked RPC (`confirm_deal_as` for D,
   `accept_offer_as`/`counter_offer_as` for A, `convert_exclusivity_as` for C) plus the shared
   `check_price_band` helper and the `deals` three-way-exclusive-origin constraint. Done when: a
   test framework is chosen and installed, and there is at least one passing test per RPC family
   proving (a) a manager cannot exceed their price band, (b) a manager cannot touch a creator
   they're not linked to, and (c) the `deals` origin constraint rejects a row with more than one
   of `reservation_id`/`offer_id`/`exclusivity_grant_id` set. This is a foundation to build on, not
   a one-shot — treat "done" as "the harness exists and proves the highest-risk cases," not
   "every possible case is covered."
6. **Concurrency load test for `place_reservation`.** `ROADMAP.md` epic 1 calls this out as the
   one bug class that directly breaks user trust (double-booking a paid deposit) and says it was
   supposed to be proven *before* any other reservation-flow code was written — worth confirming
   it was actually verified, not just implemented. Done when: a script or test fires concurrent
   simulated reservation attempts at the same listing and confirms exactly one `held` reservation
   results, every time, across multiple runs.

### P2 — Product polish (not blocking, but next after P0/P1)

7. **Notification/email polish** — `ROADMAP.md` §4 (2.4): reminder emails at ~75% of confirmation
   window elapsed, richer deal-lifecycle emails, in-app notification bell backed by the existing
   `notifications` table + Realtime. No "done when" gate here beyond founder judgment — this is
   genuinely open-ended, scope it down before dispatching a subagent on it.
8. **Founder-facing dashboard metrics** for the kill-switch signals `ROADMAP.md` §6 names
   (time-to-first-listing, time-to-first-reservation, deposit-refund rate, listing
   abandonment rate, dispute rate, mechanism-choice distribution) — currently nothing surfaces
   these anywhere; the founder would have to query Supabase directly. Not urgent pre-launch, but
   worth having before the first pilot cohort goes live, since these are the actual go/no-go
   signals per the roadmap.

### Explicitly out of scope for this handoff — do not build without a direct founder ask

- Real Stripe Connect integration (deferred by explicit instruction, still true).
- The sealed-bid tiebreaker RPCs (Phase 1.5, contention-triggered — no real users yet).
- The admin dispute UI (Phase 2.5, volume-triggered).
- Anything in `docs/ROADMAP.md` Section 5 ("Phase 3 — Post-MVP expansion") — all of it is
  explicitly usage-triggered and none of the triggers have fired (there is no usage yet).

---

*Prepared by the orchestrating session on 2026-07-02. If you (the next Fable instance) find that
reality has diverged from this brief by the time you start — a task already done, a new bug found,
a file moved — trust the filesystem and `git log` over this document, and note the divergence
before proceeding.*
