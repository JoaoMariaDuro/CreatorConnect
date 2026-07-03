-- CreatorConnect — lightweight e-signature capture on a confirmed deal's contract. Run after
-- deals.sql and delegation.sql (needs is_authorized_for_creator, audit_log, notifications).
--
-- Deliberately a typed-name + explicit-consent pattern (type your full legal name, check "I agree
-- this constitutes my signature"), not a drawn/canvas signature or a third-party e-signature
-- provider (DocuSign/HelloSign) — same "cheap, native, no new dependency" posture already used for
-- the printable contract (window.print(), no PDF library) earlier this session. This is the platform
-- completing a document it already generates and owns (deals.disclosure_terms/cancellation_terms),
-- not importing an external workflow — see handoffs/6th.md Part B §4's reasoning for why this was
-- picked as the strongest "consolidate work needs" candidate on the list.
--
-- No impersonation, same posture as everywhere else in this schema: a delegated manager signs while
-- authenticated as themselves, recorded via acting_as_id in audit_log (rpc-deal-signatures.sql),
-- exactly like confirm_deal_as/flag_dispute_as already do. No manager-signs-for-advertiser path
-- exists, matching the existing precedent that advertiser-side actions (confirm_delivery_as,
-- flag_dispute_as's advertiser branch) have no delegation concept at all.

create table if not exists public.deal_signatures (
  id            uuid        primary key default gen_random_uuid(),
  deal_id       uuid        not null references public.deals(id),
  signer_id     uuid        not null references public.profiles(id), -- who actually clicked, never a delegated party
  signer_role   text        not null check (signer_role in ('creator', 'advertiser')),
  typed_name    text        not null,
  signed_at     timestamptz not null default now(),
  unique (deal_id, signer_id)
);

alter table public.deal_signatures enable row level security;

-- Same party-visibility shape as deals itself: creator/advertiser/delegated-manager/admin. Read-only
-- from the client's perspective — see the "no insert/update/delete policy" note below.
drop policy if exists "parties read deal signatures" on public.deal_signatures;
create policy "parties read deal signatures" on public.deal_signatures
  for select
  using (exists (
    select 1 from public.deals d
    where d.id = deal_id
      and (d.creator_id = auth.uid() or d.advertiser_id = auth.uid() or d.manager_id = auth.uid()
           or public.is_authorized_for_creator(d.creator_id) or public.is_platform_admin())
  ));

-- No insert/update/delete policy for the authenticated role at all — sign_deal_as()
-- (rpc-deal-signatures.sql) is the only path in. A signature needs to be checked against the
-- signer's real relationship to the deal (creator vs. advertiser vs. delegated manager, matched
-- against signer_role) and, once written, should never be editable — an insert policy alone can't
-- express "immutable after creation" the way a security-definer function that simply refuses to
-- overwrite an existing row can.

create index if not exists deal_signatures_deal_idx on public.deal_signatures (deal_id);
