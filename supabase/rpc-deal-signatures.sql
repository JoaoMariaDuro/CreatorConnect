-- CreatorConnect — e-signature capture RPC. Run after deal-signatures.sql.

-- A party (or, for the creator side, a delegated manager acting on the creator's behalf) signs a
-- confirmed deal's contract by typing their name. Security definer because it needs to verify the
-- caller's real relationship to the deal before allowing the write (deal_signatures.sql grants no
-- direct insert policy at all), and because a signature must be immutable once created — a plain
-- upsert would let someone silently change what they'd already signed, which defeats the point of
-- a signature.
create or replace function public.sign_deal_as(p_deal_id uuid, p_signer_role text, p_typed_name text)
returns public.deal_signatures
language plpgsql security definer set search_path = public as $$
declare
  v_deal public.deals;
  v_is_manager boolean := false;
  v_existing public.deal_signatures;
  v_row public.deal_signatures;
begin
  if p_signer_role not in ('creator', 'advertiser') then
    raise exception 'invalid signer_role: %', p_signer_role;
  end if;
  if p_typed_name is null or trim(p_typed_name) = '' then
    raise exception 'typed name is required to sign';
  end if;

  select * into v_deal from public.deals where id = p_deal_id;
  if v_deal is null then
    raise exception 'deal not found';
  end if;

  if p_signer_role = 'creator' then
    if not public.is_authorized_for_creator(v_deal.creator_id) then
      raise exception 'not authorized to sign as the creator on this deal';
    end if;
    v_is_manager := (auth.uid() <> v_deal.creator_id);
  else
    -- No delegation on the advertiser side, matching confirm_delivery_as/flag_dispute_as's existing
    -- precedent: advertiser-side actions have no manager concept anywhere in this schema.
    if auth.uid() <> v_deal.advertiser_id then
      raise exception 'not authorized to sign as the advertiser on this deal';
    end if;
  end if;

  select * into v_existing from public.deal_signatures where deal_id = p_deal_id and signer_id = auth.uid();
  if v_existing is not null then
    raise exception 'you have already signed this contract';
  end if;

  insert into public.deal_signatures (deal_id, signer_id, signer_role, typed_name)
  values (p_deal_id, auth.uid(), p_signer_role, trim(p_typed_name))
  returning * into v_row;

  insert into public.audit_log (actor_id, acting_as_id, action, target_table, target_id, after)
  values (
    auth.uid(),
    case when v_is_manager then v_deal.creator_id else null end,
    'deal.signed', 'deal_signatures', v_row.id, to_jsonb(v_row)
  );

  -- Notify the other party that a signature landed — the counterparty is whichever of
  -- creator_id/advertiser_id ISN'T the signer's own side.
  insert into public.notifications (user_id, type, payload)
  values (
    case when p_signer_role = 'creator' then v_deal.advertiser_id else v_deal.creator_id end,
    'deal.signed',
    jsonb_build_object('deal_id', p_deal_id, 'message', trim(p_typed_name) || ' signed the contract for this deal.')
  );

  return v_row;
end $$;
