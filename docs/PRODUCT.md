# CreatorConnect — Product Vision & MVP PRD

*Working document for a solo/small founder team. Stack: SvelteKit + Supabase + Hetzner, with Stripe Connect for payments. Not an investor deck — this is meant to drive architecture and sprint planning.*

*Grounded in `RESEARCH_BRIEF.md` (July 2026 research pass). Where this document departs from the original pitch, the reason is stated explicitly.*

---

## 1. Refined vision & positioning

**Drop "futures market" and "NASDAQ of content creation" as the primary framing. Reposition as a booking/reservation marketplace for upcoming creator content — closer to "the Booking.com for sponsorship slots" than "the NASDAQ of content."**

Reasoning: the research found the naming risk is real but low-probability (Section 3 — CFTC cares about economic substance, not branding, and a delivered service sits far from a cash-settled derivative). So this isn't primarily a legal-risk decision. It's a *product-truth* decision: nobody has built a working price-discovery auction for creator content, and the research gives a specific, credible reason why (non-fungible, reputation-sensitive goods resist blind competitive bidding — Section 2). "NASDAQ" promises a liquid, standardized, price-discovery market. CreatorConnect's actual mechanism (see Section 4) is closer to a curated reservation system with negotiated pricing than a trading floor. Marketing language that overpromises "auction" and "futures" sets user expectations the product can't and shouldn't meet, and invites exactly the press/regulator attention the research flags as the *real* exposure (not jurisdiction, but unwanted scrutiny).

The durable value prop survives the reframe intact: **advertisers get guaranteed forward access to specific creators' inventory before it's gone; creators get demand pulled forward and monetize their calendar instead of chasing one-off DMs.** That's the pitch — "reserve tomorrow's sponsorship slots today" — without borrowing language from commodities trading. Keep "CreatorConnect" as the working name (no direct naming conflict surfaced in research); revisit only if trademark search turns up a collision, which is outside this document's scope.

---

## 2. Target segment for MVP

**Target mid-to-established creators with proven brand-deal history (roughly 50K–1M engaged followers, "professional but not celebrity"), not the aspirational long tail, and not top-tier/celebrity ambassador talent. Cap the MVP forward-booking horizon at 4–8 weeks, not 1–6 months.**

This is a deliberate split from both ends of the research's spectrum, and it needs justifying because the brief points toward two different answers depending on which finding you weight:

- Section 4 says 3-6 month horizons only have real precedent at the *premium/ambassador tier* (YouTube Brandcast, Spotter Creator Upfronts) — which argues for targeting the top of the market.
- But those upfront events are **curated, negotiated, high-touch, and running today** through direct sales teams — top-tier creators and their agencies already have this solved via relationships. CreatorConnect has nothing to offer that segment on day one: no liquidity, no brand demand, no trust. A two-sided marketplace with zero users on both sides cannot win business that's already served by a white-glove sales process (Section 5's cold-start risk, compounded).
- The long tail (sub-50K, low/no deal history) has the lead-time norm that matches a real product (2-8 weeks, Section 4) but brings the weakest supply — thin brand demand exists for unproven creators, and the platform would be competing with free/DIY brand outreach (DMs, email) that this segment already uses successfully.

The mid-tier segment is the pragmatic middle: **they have enough deal history and stable rates to make a listing meaningful to an advertiser, they run on the 2-8 week booking cadence the research says is real and current (not 3-6 months), and they're underserved** — too small for CreatorIQ/Fohr-tier enterprise tools ($20K-60K/yr), too illiquid for one-off DM negotiation to scale as their deal volume grows. An 8-week outer bound also directly defuses the two structural resistance points in Section 5 (algorithm/reach uncertainty, rate appreciation) — a creator can reason about their rate and reach 8 weeks out; 6 months out, both the research and plain incentive logic say they'll resist committing.

Move to longer horizons and larger creators only after the marketplace has liquidity — that's a Phase 2+ expansion, not an MVP bet.

---

## 3. Personas

### Creator
**Who:** A mid-tier creator (50K–1M followers) on YouTube, Instagram, or TikTok, already doing 2-6 paid brand deals a quarter via DMs, email, or an agent, without a systematic way to sell out their calendar in advance.

**Core pain (from original pitch):** Sponsorship deal flow is reactive and manual — inbound DMs, ad-hoc rate negotiation, no visibility into demand until a brand reaches out, and downtime between deals that could have been sold in advance.

**What they need from the platform:** A low-friction way to publish "I have a slot on [platform] around [date]" and have qualified advertisers come to *them*, without having to guarantee performance they can't control, and without giving up the ability to raise rates as their audience grows.

**Research-backed behavioral prediction:** They will resist any mechanic that locks them into a **fixed price weeks/months ahead** (Section 5 — force-majeure clauses on view counts, 15-40% documented annual rate increases, quarterly renegotiation norms). Expect creators to want a floor price they control and the ability to entertain competing offers close to the delivery date, not to "set and forget" a price at listing time. Product implication: never present the creator-side listing flow as "lock in your price now" — frame it as "set your terms, decide on offers as they come in."

### Advertiser
**Who:** A brand marketer or performance-marketing buyer (in-house or at a small/mid agency) running influencer campaigns who currently spends weeks sourcing creators cold via Grin/Upfluence/manual outreach, with no guarantee a creator they want is even available.

**Core pain (from original pitch):** Sourcing and locking in the right creator for a campaign date is slow (Agentio's data: ~45 days time-to-first-bid is the status quo) and uncertain — by the time terms are negotiated, the creator may have filled their calendar with someone else.

**What they need from the platform:** Visibility into which specific creators have open slots in their planning window, with enough data (past performance, audience demos, price range) to shortlist and commit quickly, plus confidence the transaction won't fall through (escrow) or ghost mid-negotiation.

**Research-backed behavioral prediction:** Advertisers plan in **8-12 week campaign cycles** (Section 4) but execute individual bookings in the 2-8 week window — so they will want to browse/shortlist earlier than they commit financially. Expect a "watch/shortlist" behavior before "buy" — the product should support browsing and soft-holds, not force an immediate binding commitment at first contact. There's no evidence advertisers want or will use a real-time competitive bidding UI (Section 2) — expect them to behave like RFP/marketplace buyers (Aspire, Popular Pays pattern), not eBay bidders.

### Manager / Agency
**Who:** Represents 3-30 creators, currently juggling rate cards, availability, and deal negotiation across spreadsheets, email, and DMs per creator; takes a commission (typically 15-20%) on deals they broker.

**Core pain (from original pitch):** No single system to manage listings/pricing/deal flow across a roster; commission collection is manual and trust-dependent (chasing creators for payment after the fact).

**What they need from the platform:** Centralized visibility and control over their whole roster's listings and incoming offers, with commission collected automatically at settlement rather than chased after the fact — this is a real, concrete pain the platform can solve mechanically via Stripe Connect payout splits, independent of the pricing-mechanism question.

**Research-backed behavioral prediction:** Nothing in the research directly addresses agency behavior, but the same rate-appreciation and reach-uncertainty dynamics apply one level removed — a manager negotiating on a creator's behalf has the same incentive to avoid locking a client into a stale price, and an additional incentive (commission-maximizing) to keep pricing flexible rather than fixed. Expect managers to want override/approval power over final price, not just administrative listing management. This directly informs the POA design in Section 5: managers should be able to *operate* deal flow but final price acceptance on behalf of a creator needs a clear, auditable authorization model (see below), both for trust and because a manager unilaterally accepting a below-market price is a foreseeable dispute vector.

---

## 4. The pricing/matching mechanism

This is the make-or-break design decision. The research is unambiguous that this is unsolved territory (Section 2: "no true competitive bidding/auction mechanic exists anywhere in the space," with a specific economic reason — non-fungible, reputation-sensitive goods resist blind price competition) and that a fixed-price-locked-far-in-advance model fights the grain of how creators actually behave (Section 5). The mechanism has to solve two things simultaneously: give the advertiser enough certainty to justify planning around it, and never force the creator into a stale, unilaterally-fixed price.

### Alternatives considered

**A. Fixed asking price with counter-offer (classifieds model).**
Creator lists a slot with an asking price; advertisers can accept at asking or submit a counter; creator accepts/rejects/counters back. Simple, familiar (Collabstr, Intellifluence already do this), easy to build. *Weakness:* still requires the creator to publish a firm number weeks/months ahead, which is exactly what Section 5 says creators resist — it just moves the "stale price" problem into a negotiation thread rather than solving it, and does nothing to leverage the platform's central advantage (multiple advertisers seeing the same slot).

**B. True multi-bidder ascending auction, price locked at listing time.**
This is what the original pitch describes. Rejected outright: Section 2 is explicit that this has never worked for creator content and gives a specific causal reason (reputation-sensitive, non-fungible good; both sides have incentive to avoid a transparent bidding war). Building the one mechanic the research says has a specific, credible failure mode as the MVP's core feature is the highest-risk possible starting point. Not pursued.

**C. Reserve-the-relationship, not the price (a la #paid's Creator Calendar).**
Advertisers get exclusive early access/first-refusal on a creator's upcoming availability window, with actual pricing negotiated bilaterally once a real deal is in motion, closer to delivery. *Strength:* directly matches the closest real precedent found in research, and structurally respects both creator resistance points (no fixed price commitment, no reach guarantee at listing time). *Weakness:* on its own it's a discovery/CRM feature, not a transaction mechanism — it doesn't give the advertiser the "locked slot" certainty the original pitch's core value prop depends on, and it doesn't give the platform a clean transaction event to take a fee on.

**D. Tiered starting-price-plus-escalator, price discovered near delivery.**
Creator sets a **floor price** and a **reservation deadline** (not a final price) at listing time. Advertisers can place a binding "reserve" (small non-refundable deposit, e.g. 10%) to lock the *slot* — taking it off the market for other advertisers — while the *final price* is confirmed in a short (48-72 hour) window shortly before or as the reservation is made, based on the creator's current rate card, not a rate fossilized at listing time. If multiple advertisers want the same slot simultaneously, the platform runs a short, capped, sealed-bid tiebreaker (not open ascending auction) among only the advertisers who already reserved — never full open bidding to strangers.

### Recommendation: **D, with elements of C folded in — "Reserve the slot, confirm the price close to reservation, tiebreak only among committed reservers."**

Reasoning:
- It directly answers Section 5's two structural objections: the creator never commits to a number that can go stale, because the price that matters is the one current at/near the moment of reservation, not the one published weeks earlier.
- It avoids Section 2's specific failure mode: there's no open, transparent, multi-party bidding war over a non-fungible good. The rare tiebreaker only fires between advertisers who already made a real commitment (deposit paid), among a small closed set, and is capped/sealed rather than a public ascending auction — this keeps price discovery bounded and private rather than turning creator inventory into a spectacle.
- It gives the platform a genuine transaction event (the reservation deposit) to build fee revenue and escrow around, unlike pure "Creator Calendar" access (option C alone).
- It's buildable: this is essentially a calendar-hold + deposit + confirm workflow, not a real-time bidding engine — dramatically lower engineering risk for a solo/small team than option B, and more defensible/differentiated than plain fixed-price-and-counter (option A).
- It matches Section 4's Preferred Deals cautionary note (avoid "fixed price, no guaranteed volume — worst of both worlds") by giving the *advertiser* the guarantee (a held slot) while giving the *creator* the pricing flexibility, rather than the reverse.

**What's deferred, explicitly:**
- Any open, multi-party ascending-bid auction UI — flagged in the research as unproven and mechanically risky; revisit only if MVP data shows advertisers actively fighting over the same slots and creators are comfortable with visible competition.
- Price escalator formulas / algorithmic dynamic pricing — start with the creator manually updating their rate card; automate later if there's enough transaction data to justify it.
- Secondary market / resale of a reserved slot.

---

## 5. Core user flows

### Flow 1 — Creator lists a slot
1. Creator (or their manager, see Flow 3) creates a listing: platform (YouTube/IG/TikTok), content type (integration, dedicated post, story, etc.), **availability window** (e.g. "week of Aug 10-17"), floor price, and a **reservation deadline** (last date an advertiser can reserve this slot).
2. Creator attaches supporting data: recent performance stats (manually entered or pulled via a supported platform API in later phases — MVP is manual entry, see Section 6), audience demographics, and any hard constraints (e.g. "no competitor brands to X").
3. Listing goes live in the marketplace, status = **Open**.
4. Creator can edit floor price and rate card at any time before a reservation is placed; once reserved, price for that specific slot is locked for that specific advertiser only (doesn't affect other open listings).
5. Creator receives reservation notifications and has a defined response window (e.g. 24-48h) to confirm final terms once an advertiser reserves — if they don't respond, the reservation auto-expires and the deposit is refunded.

### Flow 2 — Advertiser discovers and secures a slot
1. Advertiser browses/filters listings by platform, content type, follower range, price range, availability window, and (later) audience demographics.
2. Advertiser can **shortlist/watch** a listing with no commitment (matches the research-backed prediction that advertisers browse ahead of committing — Section 3 persona notes).
3. To secure a slot, advertiser places a **reservation** — pays a deposit (e.g. 10% of the floor price, held via Stripe Connect) which takes the slot off the market for other advertisers and starts the creator's confirmation clock.
4. Creator confirms final price/terms (at or above floor) within the response window. If multiple advertisers reserved the same slot in the same short window (rare — most listings won't have contention), the sealed-bid tiebreaker among that closed set resolves it; the losers' deposits are refunded automatically.
5. On confirmation, the platform generates the deal contract (deliverable spec, price, delivery date, disclosure requirements per FTC-guide mandate, cancellation terms) and moves the remaining balance into escrow logic: 50% due at booking confirmation, 50% released after delivery.
6. Advertiser tracks delivery status; on delivery + advertiser sign-off (or an auto-release timeout, e.g. 5 days with no dispute), the remaining 50% releases to the creator (minus platform fee) via Stripe Connect payout.

### Flow 3 — Manager/agency operates on behalf of creators (Power of Attorney design)
The POA model needs a clear, auditable split between what a manager can do autonomously and what needs creator confirmation, because a manager unilaterally accepting a bad deal is a foreseeable dispute (Section 3 persona note).

**Manager can do without creator confirmation (delegated, administrative):**
- Create/edit/pause draft listings (platform, content type, availability, floor price, description) for creators who've granted them access.
- Respond to advertiser inquiries, negotiate within a **pre-authorized price band** the creator has explicitly set (e.g. "auto-accept any confirmed price ≥ $X for this listing").
- View roster-wide dashboard: all listings, reservations, and deal statuses across their managed creators.
- Manage payout routing (commission split is automated via Stripe Connect, not manually invoiced).

**Requires explicit creator confirmation (cannot be delegated, ever, in MVP):**
- Final acceptance of a price **outside** the pre-authorized band.
- Anything that commits the creator to a deliverable spec beyond what the listing described (e.g. exclusivity clauses, usage rights beyond default).
- Removing/transferring the manager relationship itself (only the creator can revoke a manager's access, not the reverse).

**Mechanics:** every manager action on a creator's behalf is logged with an explicit "acting as [manager] on behalf of [creator]" audit trail, visible to the creator at any time. The creator can set/adjust the pre-authorized price band per listing or globally at any time; changing it doesn't retroactively affect deals already confirmed. Commission (the pitch's "+5% on manager-run transactions") is calculated and split automatically at the Stripe Connect payout step — the manager never needs to invoice or chase the creator for it, which is the concrete pain point this persona has today.

---

## 6. MVP feature scope vs. deferred

**In scope for v1 — narrow and opinionated:**
- Creator, Advertiser, and Manager account types with the POA delegation model in Flow 3 (band-based auto-accept + audit log — this is core to the three-sided value prop, not gold-plating).
- Listing creation (manual entry of platform, content type, availability window, floor price, reservation deadline, manually-entered performance stats and audience demographics — no automated ingestion yet).
- Browse/filter/shortlist for advertisers.
- Reservation + deposit flow (mechanism D from Section 4), including the closed-set sealed-bid tiebreaker for the rare contention case.
- Contract generation from confirmed deal terms, with mandatory #ad/FTC disclosure language baked into every generated contract (Section 3's cheapest, most concrete regulatory mitigation).
- Escrow via **Stripe Connect** (agent-of-payee structure, not custom fund-holding — Section 3 is explicit this is a legal/technical hard constraint): 50% booking / 50% delivery split, auto-release on delivery confirmation or timeout, manual dispute flag that pauses release.
- Basic dispute flow: either party can flag a delivery dispute before auto-release, which freezes the remaining balance for manual (founder-mediated, MVP-stage) resolution. No automated arbitration in v1.
- 15% platform transaction fee + 5% additional on manager-run transactions, taken automatically at Stripe Connect payout.
- 4-8 week booking horizon (per Section 2's recommendation) — the product should not offer or encourage listings dated further out in v1.

**Explicitly deferred:**
- **Secondary market/resale of reserved slots** — consumer-protection complexity (Section 3) not worth taking on before the core two-sided flow has liquidity.
- **AI-assisted/algorithmic price discovery or matching** — no transaction data yet to train or justify it; manual rate cards and human negotiation first.
- **Multi-platform performance metrics ingestion (API pulls from YouTube/IG/TikTok)** — start with manual entry; automate once there's proof creators/advertisers actually rely on the stats field, not before.
- **Manager bulk tools** (bulk listing creation/editing across a full roster, bulk rate-card updates) — v1 manager tooling is per-creator; bulk operations are a retention/efficiency feature for later, not a bootstrapping one.
- **Premium subscriptions** — revenue-diversification feature; the transaction fee is the only monetization needed to validate the core loop.
- **Open, multi-party ascending-bid auctions** — deferred per Section 4's reasoning; revisit only with real contention data from the sealed-bid tiebreaker usage.
- **Expansion beyond the mid-tier creator segment** (celebrity/ambassador tier, or long-tail/sub-50K creators) and beyond the 4-8 week horizon — Phase 2+ only, after liquidity is proven.
- **International/multi-currency, multi-jurisdiction escrow nuance** (EU EMI partner specifics, state-by-state MTL edge cases beyond what Stripe Connect handles out of the box) — go with Stripe Connect's standard coverage for MVP geography; revisit with counsel before expanding beyond it.

---

## 7. Open product questions

These need direct evidence (creator interviews, pilot data), not more web research — the brief is explicit that search-based research hit a wall here (Section 5: "no direct evidence of creators refusing to pre-book... this is a genuine research gap").

1. **Will creators actually accept a non-refundable deposit model that takes their slot off the market before final price is confirmed?** The mechanism in Section 4 assumes creators are comfortable with a binding reservation preceding final price agreement — this is an assumption, not a validated behavior. Needs 10-15 real creator interviews before committing engineering time to the tiebreaker logic specifically.

2. **What reservation deposit percentage and response-window length actually clear the market** (i.e., are high enough to filter serious advertisers but low enough that advertisers will risk it on a slot months out)? The 10% / 24-48h figures in this doc are placeholders for pilot testing, not researched numbers.

3. **How much manual performance-stat entry will creators tolerate before they stop maintaining accurate listings?** The MVP deliberately defers automated metrics ingestion (Section 6) — but if manual entry causes listings to go stale or be abandoned, that undermines advertiser trust in the core discovery flow. Needs early usage data, not assumption.

4. **What does a "dispute" actually look like in practice, and how much founder-mediation time will v1's manual dispute flow actually consume?** The MVP dispute design (Section 6) assumes low volume and founder-scale manual resolution — worth pressure-testing with even a handful of pilot transactions before assuming it scales past a few dozen deals a month.

5. **Do managers actually want band-based delegated authority, or do they expect (and will only adopt the platform if given) full autonomous control over deal acceptance?** The POA design in Flow 3 is a founder-designed compromise between creator trust and manager efficiency — it hasn't been validated against how agencies actually operate today (some may run far more autonomously than this model assumes, others far less). Needs direct interviews with 2-3 working creator managers/agencies before finalizing the permission model in the data layer.

---

*Document owner: founder. Source: `RESEARCH_BRIEF.md` (July 2026). Revisit Sections 2 and 4 first if pilot data contradicts the assumptions above — those are the two highest-uncertainty calls in this document.*
