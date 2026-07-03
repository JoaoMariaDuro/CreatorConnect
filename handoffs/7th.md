# CreatorConnect — Handoff Brief #7 (Manager Private Notes + Contract E-Signature)

*Direct continuation of Handoff #6. That handoff's "next steps" section named two candidates —
"manager roster CRM" and "contract e-signature" — as the cheapest, best-evidenced tests of the
"consolidate their work needs into this platform" framing. This handoff closes both. It also
corrects an imprecision in Handoff #6 itself: that document's Part B §4 described the manager
roster CRM as "already scoped... unbuilt," which conflated two different things — the roster-wide
**pipeline dashboard** (needs-attention queue, commission, activity counts) really was already
shipped in Handoff #6 Part A (commit `d0990b8`); what was still genuinely missing, and is what this
handoff actually builds, is a **private notes/relationship-context layer** — the non-transactional
half of a CRM that a pipeline view alone doesn't cover.*

---

## What shipped

### 1. Manager private notes (`manager-notes.sql`)

A manager's own working notes on a creator they represent — preferences, history, reminders. New
table `manager_creator_notes`, **fully invisible to the creator** — not just hidden in the UI, RLS
grants the creator zero access on any policy, anywhere. This had to be a new table rather than a
column on the existing `manager_creator_links`: that table's "creator controls own links" policy is
`for all using (creator_id = auth.uid())`, which already grants the creator full read/write on every
column of their own link rows — bolting a manager-private notes column onto it would have made the
notes immediately readable (and writable) by the creator too, since RLS is row-level, not
column-level. Same class of gap the `profiles.role` immutability fix exists to prevent, avoided here
by using a separate, narrowly-scoped table instead.

Write access additionally requires an active `manager_creator_links` row (integrity guard, not a
security boundary — the table's already fully private regardless) — so a note can only be
created/updated while the manager currently represents that creator, though existing notes stay
readable after a relationship lapses (historical record).

UI: a collapsible "Private notes" field on each roster card in `/settings/managers`.

### 2. Contract e-signature (`deal-signatures.sql`, `rpc-deal-signatures.sql`)

Closes the loop Handoff #6 flagged as the strongest "consolidate work needs" candidate: the
platform already generates contract content (`deals.disclosure_terms`/`cancellation_terms`, and as
of Handoff #6, prints to PDF) but never captured a signature. Deliberately a typed-name +
explicit-consent pattern (type your full legal name, check "I agree this constitutes my signature"),
not a drawn/canvas signature or a third-party e-signature provider — same "cheap, native, no new
dependency" posture already used for the printable contract itself (`window.print()`, no PDF
library).

New `deal_signatures` table, one row per deal per party, **immutable once written** — no
insert/update/delete policy exists for the authenticated role at all; `sign_deal_as()` (security
definer) is the only path in, checks the caller's real relationship to the deal (creator, delegated
manager acting for the creator, or advertiser — no manager-signs-for-advertiser path, matching the
existing precedent that advertiser-side actions have no delegation concept anywhere in this schema),
and refuses to overwrite an existing signature. Notifies the counterparty when the other side signs.

UI: a "Signatures" section on `/deal/[id]`'s contract card, showing both parties' status, with a
sign form for whichever role the current user holds (once, non-editable after). Included in the
printable/PDF contract view from Handoff #6 automatically, since it's part of the same card.

## Verification

`npm run check` clean throughout. Both new tables' RLS/RPC logic manually re-reviewed line by line
against the live-tested patterns already proven this session (party-visibility subquery matching
`deal_signatures`' shape to `deals`' own RLS; `is_authorized_for_creator` reused, not reimplemented).
Live-checked: no server errors on `/settings/managers` or an arbitrary `/deal/[id]`, confirming
nothing crashes even before the founder runs the new migrations. **Not yet verified**: the actual
authenticated flows (saving a note, signing a contract) — same standing constraint as every other
feature this session, needs a real signed-in session.

## What's still open

Everything Handoff #6 Part B flagged still stands — most importantly, the two questions only the
founder can answer (Facebook-literal vs. LinkedIn-shaped social mechanics; replace vs. integrate
outward for general-purpose tools). Neither of this handoff's two features required an answer to
proceed, since both are narrow completions of data/documents the platform already owns — but the
next tier of "consolidate work needs" candidates (advertiser campaign grouping, feed/connection
mechanics) does depend on those answers, and shouldn't be scoped without them.

**Needs founder action**: run `manager-notes.sql`, `deal-signatures.sql`, then
`rpc-deal-signatures.sql`, in that order (see `supabase/README.md` steps 19-21).

---

*Prepared by the orchestrating session immediately following Handoff #6, same continuous session,
2026-07-03. Both features verified against proven RLS/RPC patterns from earlier in this session
before being written up, per this project's established practice of testing rather than assuming.*
