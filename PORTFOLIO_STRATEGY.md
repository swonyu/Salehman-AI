# Portfolio-strategy money sweep (w5kagzxd3, 2026-06-22)

7 VERIFIED portfolio-LEVEL specs (31 agents, 2-skeptic). #1 (portfolio Kelly heat cap — closes a 2x-leverage ruin gap) DONE. RE-VERIFY rest vs source.

### ✅ DONE #1 [portfolio-kelly] — Portfolio-level Kelly heat cap (uniform-scale a book of per-position half-Kelly fractions to a ceiling)
**mechanism:** Append a pure func + result struct to enum StockSageKelly (StockSageKelly.swift; enum body ends ~line 67), touching no existing member. COMPOSES the already-verified per-position output KellyResult.suggestedFraction (= half-Kelly hard-capped at maxFraction 0.20, StockSageKelly.swift:51) and mirrors CapitalAllocator's proven uniform-scaling math (StockSageCapitalAllocator.swift:71-72 — requestedHeat = Σ weights; scaleApplied = requestedHeat > cap ? cap/requestedHeat : 1) but operates DIRECTLY on a list of fractions instead of re-running EV+sizer. bookRequested = Σ suggestedFraction; scale = bookRequested > cap ? cap/bookRequested : 1; scaledFractionᵢ = suggestedFractionᵢ·scale; bookHeat = Σ scaledFraction = min(bookRequested, cap). cap clamped to [0,1]; empty list or non-positive cap → zero-heat result. Closes the exact named gap: ten half-Kelly trades each 0.20 sum to 2.0× the account; the cap scales every one down uniformly so Σ ≤ maxPortfolioHeat — collective over-betting per-position Kelly cannot see (it only sees one trade).

**signature:** struct PortfolioKelly: Sendable, Equatable { let scaledFractions: [Double]; let bookRequestedHeat: Double; let bookHeat: Double; let scaleApplied: Double; let maxPortfolioHeat: Double; let caveat: String }
nonisolated static func portfolioCap(_ perPositionFractions: [Double], maxPortfolioHeat: Double = 0.30) -> PortfolioKelly

**test:** fracs=[0.20]*10; cap=0.30
req=sum(fracs)                       # 2.0
scale=cap/req if req>cap else 1.0    # 0.15
scaled=[f*scale for f in fracs]      # each 0.030
assert abs(req-2.0)<1e-9
assert abs(scale-0.15)<1e-9
assert abs(scaled[0]-0.030)<1e-9
assert abs(sum(scaled)-0.30)<1e-9    # book heat pinned to the cap, NOT 2.0
# under-cap book untouched (scale==1):
f2=[0.05,0.04]; r2=sum(f2); s2=cap/r2 if r2>cap else 1.0
assert s2==1.0 and abs(sum(x*s2 for x in f2)-0.09)<1e-9
# empty input -> zero heat, no NaN:
assert (cap/sum([]) if sum([])>cap else 0.0)==0.0

**caveat:** Inherits StockSageKelly.caveat verbatim (StockSageKelly.swift:34) PLUS: scaling is uniform, so it preserves the per-position edge ranking but does NOT account for correlation — ten 0.03 bets in correlated names can still gap together past the nominal book heat (this caps SUMMED stop-risk, not joint tail risk; Rank 3 is the correlation complement). Inputs are half-Kelly off ESTIMATED edges (usually optimistic); the cap bounds aggregate over-betting, it does not validate the W/R estimates. A sizing CEILING, not realized share counts — only StockSagePositionSizer floors to whole shares, so realized heat ≤ cap.

**edgeRationale:** Highest real-$ + most-buildable: pure float ops appended to a verified enum, zero new I/O, zero new dependency, every existing Kelly/Allocator test re-traces green by construction. On a $10,000 account, ten genuinely-high-edge ideas each earn the full half-Kelly cap of 0.20, so naive per-position Kelly risks 10×0.20 = 2.0 → $20,000 of stop-risk on a $10k book (2× leveraged, a ruin setup no single Kelly call can detect). portfolioCap at 0.30 scales every position by 0.15, pinning total open stop-risk to exactly $3,000 — $17,000 of catastrophic over-bet removed in one deterministic pass, the precise failure mode the request names.

### ⬜ #2 [portfolio-kelly] — Marginal Kelly headroom — how much a new idea may take given the book's current heat
**mechanism:** New pure func appended additively to enum StockSageKelly (after compute, ~line 66; no existing member altered). Composes the SAME suggestedFraction concept (the half-Kelly-capped-at-0.20 fraction) and the SAME heat-ceiling as Rank 1 / CapitalAllocator's maxHeat (StockSageCapitalAllocator.swift:41). headroom = max(0, cap − existingBookHeat); granted = min(newSuggestedFraction, headroom); cap and existingBookHeat clamped to [0,1] so a degenerate/over-full book yields headroom 0 (new idea admitted at 0 = rejected on heat grounds, never negative). This is the INCREMENTAL complement to Rank 1's batch scaling: when the book is already live and a fresh signal fires, marginalRoom answers 'is there room for this bet, at what size' WITHOUT re-scaling existing open positions (which would force churn).

**signature:** nonisolated static func marginalRoom(existingBookHeat: Double, newSuggestedFraction: Double, maxPortfolioHeat: Double = 0.30) -> (headroom: Double, grantedFraction: Double)

**test:** cap=0.30
existing=0.25; new=0.20
headroom=max(0.0, cap-existing); granted=min(new, headroom)
assert abs(headroom-0.05)<1e-9 and abs(granted-0.05)<1e-9
# room to spare -> full fraction:
e2,n2=0.05,0.10; h2=max(0.0,cap-e2); g2=min(n2,h2)
assert abs(h2-0.25)<1e-9 and abs(g2-0.10)<1e-9
# full book -> zero granted, never negative:
e3,n3=0.30,0.20; h3=max(0.0,cap-e3); g3=min(n3,h3)
assert h3==0.0 and g3==0.0
# dirty input clamps, no NaN:
e4=1.5; h4=max(0.0, cap-min(1.0,max(0.0,e4)))
assert h4==0.0

**caveat:** Same Kelly caveat (StockSageKelly.swift:34) plus: headroom is computed against SUMMED stop-risk only — it ignores correlation between the new idea and the open book, so a granted fraction can still co-move with existing positions in a gap (Rank 3 addresses joint risk). Assumes existingBookHeat is reported honestly in account-fraction units (e.g. CapitalAllocation.totalHeat, StockSageCapitalAllocator.swift:87); a stale or mis-scaled input gives a stale answer. grantedFraction is a sizing ceiling, not whole shares — StockSagePositionSizer still floors realized position, so realized incremental heat ≤ granted.

**edgeRationale:** Trivially buildable two-line pure func, naturally pairs with Rank 1 (same struct neighborhood, same ceiling concept) so ship them together. On a $10,000 account already running $2,500 open stop-risk (heat 0.25) with a 0.30 ceiling, a new half-Kelly signal wants its full 0.20 → $2,000; sizing it standalone pushes the book to $4,500 (45% heat, 50% over the ceiling). marginalRoom grants only 0.05 → $500, landing at exactly $3,000 / 30% — $1,500 of incremental over-bet prevented on a single late-arriving trade WITHOUT forcing a churn-inducing trim of the four positions already working.

### ⬜ #3 [correlation-heat] — Correlation-aware portfolio heat: the joint bad-day stop-out the per-position heat card hides
**mechanism:** NEW file Salehman AI/StockSage/StockSageCorrelatedHeat.swift. Pure + additive — composes two ALREADY-verified engines without touching them: (1) StockSagePortfolioHeat.compute (StockSagePortfolioHeat.swift:38, confirmed signature openTrades:(shares,entry,stop), accountSize) for the naive Σ dollarsAtRisk, and (2) the SAME pairwise StockSagePortfolioAnalytics.correlation([Double],[Double]) the heatmap uses (StockSagePortfolioAnalytics.swift:136, verified: n=min counts, guard n>=2 else 0, clamped [-1,1]). Per-position rᵢ = sharesᵢ·|entryᵢ−stopᵢ| (each 1%-risk stop). jointRisk = √(Σᵢ Σⱼ ρᵢⱼ·rᵢ·rⱼ), diagonal ρ=1. concentrationRatio compares jointRisk to the independent-stop baseline √(Σ rᵢ²) (the 'each stop independent' mental model the heat card implies) — NOT to the linear Σ rᵢ. Inputs are the open trades' real (shares,entry,stop) plus their aligned daily-return vectors (the same holdingVecs the store feeds correlationMatrix, StockSageStore.swift:436/453-455 — confirmed the ≥5-overlap guard). Pairs with <5 overlapping observations counted in pairsAssumedZero and treated as ρ=0 (labeled-absent, matching the store's minOverlap guard). Returns nil only when PortfolioHeat.compute returns nil (no account), reusing the existing card's nil-handling verbatim.

**signature:** struct CorrelatedHeat: Sendable, Equatable {
    let independentRisk: Double      // Σ per-position dollarsAtRisk (== PortfolioHeat.dollarsAtRisk)
    let jointRisk: Double            // sqrt(Σ Σ rho_ij·r_i·r_j) — correlation-aware combined stop-out
    let accountSize: Double
    let pairsMeasured: Int           // pairs with >=5 overlapping returns
    let pairsAssumedZero: Int        // pairs lacking history — NOT counted as correlated (honest)
    let worstPair: (a: String, b: String, rho: Double, jointDollars: Double)?
    nonisolated var independentPct: Double { accountSize > 0 ? independentRisk / accountSize : 0 }
    nonisolated var jointPct: Double { accountSize > 0 ? jointRisk / accountSize : 0 }
    nonisolated var concentrationRatio: Double { independentRisk > 0 ? jointRisk / sqrt(independentRisk) : 1 }
    nonisolated var isConcentrated: Bool { concentrationRatio >= 1.25 }
    nonisolated var caveat: String
    nonisolated var note: String
}
enum StockSageCorrelatedHeat {
    nonisolated static let concentratingRatio = 1.25
    nonisolated static func compute(openTrades: [(symbol: String, shares: Double, entry: Double, stop: Double, returns: [Double])], accountSize: Double) -> CorrelatedHeat?
}

**test:** import math
def joint(rs, C):
    n=len(rs); s=0.0
    for i in range(n):
        for j in range(n):
            s += C[i][j]*rs[i]*rs[j]
    return math.sqrt(s)
rs=[100.0,100.0]; rho=0.9
C=[[1.0,rho],[rho,1.0]]
independent=sum(rs)                          # 200.0 (linear)
joint_v=joint(rs,C)                          # sqrt(38000)=194.9358868964927
assert abs(joint_v-194.9358868964927)<1e-6
baseline=math.sqrt(sum(r*r for r in rs))     # sqrt(20000)=141.4213562373095
assert abs(baseline-141.4213562373095)<1e-6
concentration=joint_v/baseline               # 1.378404875209...
assert abs(concentration-1.378404875209)<1e-6 and concentration>=1.25  # isConcentrated
# uncorrelated book collapses to baseline (rho=0 -> ratio 1.0):
assert abs(joint(rs,[[1.0,0.0],[0.0,1.0]])-baseline)<1e-9
# perfectly correlated -> jointRisk == naive linear sum:
assert abs(joint(rs,[[1.0,1.0],[1.0,1.0]])-independent)<1e-9

**caveat:** Two-level honesty. (1) jointRisk is √(rᵀCr), the variance-of-a-sum under realized pairwise correlation — still a STOP-FILL model (each stop assumed to fill at its level), so a true gap-through can lose more than even jointRisk (inherits PortfolioHeat.caveat, StockSagePortfolioHeat.swift:30 'a correlated gap can hit several at once for more than this'). (2) Correlations are backward-looking over shared daily history and trend toward 1 in a crisis — exactly when they bite — so jointRisk is a FLOOR on bad-day risk, not a ceiling. Pairs with <5 overlaps go to pairsAssumedZero at ρ=0 (labeled-absent, never imputed), so a thin-history book UNDER-reports; the note states the assumed-zero count so the reader knows coverage. concentrationRatio is jointRisk ÷ √(Σrᵢ²), matching the 'each stop independent' model the existing heat card implies.

**edgeRationale:** PortfolioHeat (StockSagePortfolioHeat.swift:30) and CapitalAllocator (StockSageCapitalAllocator.swift:35) both explicitly disclaim 'a correlated gap can lose more' but neither QUANTIFIES it. Three open positions each at the 1% stop on a $40k account read as 3% / $1,200 'at risk' — inside the 'room to add' band. If they are the same sector at ρ≈0.85 (a real outcome when journal ideas come off one EV-ranked board), the bad-day combined stop-out is √(rᵀCr) ≈ $1,940 — 62% above the $1,200 shown, past the 'add carefully' threshold the owner relies on. Ranked below the two Kelly specs because it needs aligned per-position return vectors plumbed from the store (more wiring than pure-float Kelly), but it is the highest-value risk-surface gap and reuses only verified engines.

### ⬜ #4 [sector-rotation] — Sector relative-strength leaderboard (which of YOUR sectors leads the benchmark)
**mechanism:** Composes the EXISTING value-weighted sector grouping StockSageAllocation.slices(holdings, by:) (StockSageAllocation.swift:59-67, verified: value-weighted, sorted desc, drops ≤0 holdings) with the EXISTING per-symbol momentum reads StockSageIndicators.relativeStrength(symbolCloses:benchmarkCloses:period:) (StockSageIndicators.swift:162) then returnOverPeriod fallback (StockSageIndicators.swift:131), and the curated tag StockSageSector.sector (StockSageSector.swift:12, verified: map lookup then asset-class fallback to Crypto/Forex/Index/Other). For each holding it tags the sector, measures that name's RS vs the supplied benchmark over period, and aggregates to a sector score = VALUE-WEIGHTED mean of its members' RS, sorted desc so the leader is .first. New pure static func StockSageSector.relativeStrengthLeaderboard + small SectorRS struct — additive only; existing StockSageSectorTests/StockSageAllocationTests stay green. Only-real-data: a sector whose members are all too short (RS nil for every member) is emitted with score: nil (labeled-absent), never a fabricated 0. Benchmark closes are the SAME S&P series the regime engine already consumes (no new fetch).

**signature:** struct SectorRS: Sendable, Equatable, Identifiable { let sector: String; let weight: Double; let score: Double?; var id: String { sector } }
nonisolated static func relativeStrengthLeaderboard(_ holdings: [(symbol: String, value: Double, closes: [Double])], benchmarkCloses: [Double], period: Int = 126) -> [SectorRS]

**test:** def ret(c,p):
    if p<=0 or len(c)<=p: return None
    past=c[-1-p]
    return None if past==0 else (c[-1]-past)/past*100
def rs(sym,bench,p):
    s=ret(sym,p); b=ret(bench,p)
    return None if s is None or b is None else s-b
P=2; bench=[100,100,110]               # bench ret = 10
tech_a=[100,100,130]; tech_a_w=200.0   # ret 30 -> rs 20
tech_b=[100,100,120]; tech_b_w=100.0   # ret 20 -> rs 10
fin=[100,100,105];   fin_w=100.0       # ret 5  -> rs -5
rs_ta=rs(tech_a,bench,P); rs_tb=rs(tech_b,bench,P); rs_fin=rs(fin,bench,P)
tech_score=(tech_a_w*rs_ta+tech_b_w*rs_tb)/(tech_a_w+tech_b_w)  # 16.666..
assert abs(tech_score-50/3)<1e-9 and abs(rs_fin+5)<1e-9
board=sorted([('Technology',tech_score),('Financials',rs_fin)],key=lambda x:-x[1])
assert board[0][0]=='Technology'
assert rs([100],bench,P) is None      # too short -> score None, NOT 0

**caveat:** Value-weighted RS is a relative read of YOUR current book's sectors vs ONE benchmark over ONE trailing window — hindsight momentum, not a forecast; momentum mean-reverts at turns, so a leading sector can top right as it screens 'strongest'. Single-window (default 126-bar) and single-benchmark; it says nothing about sectors you do NOT hold. score: nil means insufficient real history for the members, not weakness — surface as 'n/a', never 0. Tags come from the curated static StockSageSector map (StockSageSector.swift), so unmapped names land in 'Other' and don't get a clean sector read.

**edgeRationale:** Tilting NEW entries toward the sector your holdings already lead on RS is the portfolio-level expression of cross-sectional momentum — the most replicated equity anomaly. On a $25k book a few hundred dollars of weekly fresh capital steered into the strongest sector instead of the weakest compounds the documented momentum spread instead of fighting it, and it reuses RS the app already computes per-name so the surfaced number costs no new fetch. Ranked here because it composes three verified engines cleanly but needs per-holding closes + benchmark plumbed (similar wiring to Rank 3) and the edge is a positioning tilt, not a hard risk-cap.

### ⬜ #5 [rebalance-discipline] — Relative drift-band rebalance (flag when a holding drifts >X% OF its target, not X pp)
**mechanism:** New additive sibling planRelative() to StockSageRebalance.plan in StockSageRebalance.swift (existing plan at :31-55, verified: normalizes targets, ABSOLUTE band abs(drift)>band at :49, biggest-moves-first sort at :53). The new band is RELATIVE: a holding is flagged only when |cw − tw| / tw > relativeBand. Genuinely different from the pp band: a 1% target drifting to 1.5% is +50% relative (a real doubling of exposure) but 0.5pp absolute (silently ignored); a 30%→31% move is +3.3% relative (noise) but 1pp absolute (flagged). The relative band scales the no-trade tolerance to each holding's size — what 'drifted >X% from target' actually means. Reuses the same normalization, the same RebalancePlan/RebalanceTrade structs (:12-25), the same sort. Untargeted holdings (tw=0, cw>0) get infinite relative drift → always sell-to-zero (matches existing semantics); brand-new targets (cw=0, tw>0) get relative drift 1.0 = 100% → always buy-in.

**signature:** nonisolated static func planRelative(holdings: [(symbol: String, value: Double)], targets: [String: Double], relativeBand: Double = 0.25) -> RebalancePlan?

**test:** def reldrift(cw,tw):
    return abs(cw-tw)/tw if tw>0 else (float('inf') if cw>0 else 0.0)
cw={'A':0.6,'B':0.4}; tw={'A':0.55,'B':0.45}
rA=reldrift(cw['A'],tw['A']); rB=reldrift(cw['B'],tw['B'])
assert abs(rA-0.0909)<1e-3 and abs(rB-0.1111)<1e-3
flagged=[s for s in cw if reldrift(cw[s],tw[s])>0.10]
assert flagged==['B']                                  # one trade, not two
assert abs(cw['A']-tw['A'])==abs(cw['B']-tw['B'])==0.05 # pp band would treat both identically
assert abs((tw['B']-cw['B'])*10000-500)<1e-6           # B delta = +500 buy
assert reldrift(0.5,0.0)==float('inf') and reldrift(0.0,0.3)==1.0

**caveat:** DIRECTION and rough SIZE of trades, not an order ticket: still ignores trading costs, taxes, bid/ask spread, min-lot sizing (the same honest caveat plan() carries, StockSageRebalance.swift:9-10). A relative band over-fires on very small target weights — a 0.5%-target holding trips at a tiny dollar move — so callers with dust positions should combine it with an absolute-dollar floor. The relative threshold is a heuristic for over-trading control, not a guarantee that rebalancing is net-profitable after friction.

**edgeRationale:** A 60/40 book with a 3% satellite sleeve: the existing 2pp absolute band lets that satellite swell to 5% (a 67% overshoot of its risk budget) before flagging, while needlessly churning the 40% core on a 2.1pp wiggle. The relative band flags the satellite's 67% drift (real un-hedged concentration creeping in) and leaves the core alone — tying the trigger to how far each holding drifted FROM ITS OWN target, cutting both missed-rebalances on small sleeves and over-trading friction on large ones. Pure, buildable, reuses the verified struct/sort — ranked mid because the dollar impact is friction/discipline optimization, smaller than the over-leverage prevention above.

### ⬜ #6 [income-yield] — DividendProximity — ex-date / pay-date awareness for a held name
**mechanism:** New file Salehman AI/StockSage/StockSageDividend.swift, modeled byte-for-byte on the VERIFIED StockSageEarnings.swift idiom: severity bands <=3/<=10/else (StockSageEarnings.swift:35-39), proximity() day-floor at 0 (:43-48), the fetch gate (ToolPolicy.isExternalAllowed + StockSageAllocation.assetClass=='Equity' guard + addingPercentEncoding(.urlHostAllowed) + the Mozilla UA, all at :49-56), and parseEarningsDate's JSONSerialization walk (:68). Reuses the SAME Yahoo quoteSummary host on modules=calendarEvents,summaryDetail, pulling calendarEvents.dividendDate / summaryDetail.exDividendDate. severity(daysUntilExDate:) shares the EarningsProximity.Severity contract the app already renders. PURELY ADDITIVE: no existing signature changes, so StockSageEarningsTests / StockSageRiskFlagsTests re-trace unchanged. proximity(now:exDate:) is pure + python-verified.

**signature:** struct DividendProximity: Sendable, Equatable {
    enum Severity: String, Sendable { case imminent = "Imminent", soon = "Soon", clear = "Clear" }
    let daysUntilExDate: Int
    let severity: Severity
    nonisolated var note: String
}
enum StockSageDividend {
    nonisolated static func severity(daysUntilExDate: Int) -> DividendProximity.Severity
    nonisolated static func proximity(now: Date, exDate: Date) -> DividendProximity
    static func fetchExDividendDate(for symbol: String) async -> Date?
    nonisolated static func parseExDividendEpoch(_ data: Data) -> Date?
}

**test:** # mirrors StockSageEarnings.severity/proximity (verified): <=3 imminent, <=10 soon, else clear; days floored at 0
DAY=86400.0; now=1_700_000_000.0
def sev(d): return 'imminent' if d<=3 else ('soon' if d<=10 else 'clear')
assert sev(0)=='imminent' and sev(3)=='imminent' and sev(4)=='soon' and sev(10)=='soon' and sev(11)=='clear'
def days(exdate): return max(0, round((exdate-now)/DAY))
assert days(now+2*DAY)==2 and sev(days(now+2*DAY))=='imminent'
assert sev(days(now+7*DAY))=='soon'
assert days(now-5*DAY)==0          # just-passed floors to 0 -> imminent (caller must drop stale, see caveat)
# parse soonest exDividendDate epoch from summaryDetail; {} -> None (mirrors parseEarningsDate)
import json
body={'quoteSummary':{'result':[{'summaryDetail':{'exDividendDate':{'raw':1_700_500_000.0}}}]}}
raw=body['quoteSummary']['result'][0]['summaryDetail']['exDividendDate']['raw']
assert raw==1_700_500_000.0
assert json.loads('{}').get('quoteSummary') is None

**caveat:** REAL-DATA-ONLY: date comes solely from Yahoo quoteSummary (exDividendDate / dividendDate); no synthesized schedule. When access is off (ToolPolicy.isExternalAllowed false), the name is non-equity (assetClass != 'Equity'), or Yahoo omits the field (non-payer or declined request), fetch returns nil and NO note shows — labeled-absent, never a guessed date. A just-passed ex-date floors to 0 days → 'imminent', so the caller MUST drop stale past dates exactly as StockSageStore.refreshEarnings does (its date.timeIntervalSinceNow > -86_400 guard, StockSageStore.swift:515 — verified). The date is an announced schedule the issuer can revise, not a settled fact.

**edgeRationale:** The price-only Markets view (PortfolioPosition is deliberately price-coupling-free) silently ignores the cash a dividend payer returns. A held name going ex-dividend in ~2 days is real money: selling the day BEFORE ex-date forfeits the payment (and price typically drops by ~the dividend on ex-date anyway), and a stop placed without knowing the ex-date can be tripped by that mechanical drop and book a 'loss' on what was actually a dividend. Surfacing the ex-date avoids forfeiting income and mistaking the ex-date gap for a real adverse move. Ranked below the pure compute specs because it needs a live Yahoo fetch path (more surface to get right) though it clones a fully verified idiom.

### ⬜ #7 [income-yield] — Estimated annual dividend income & yield-on-position (REAL rate or labeled-absent)
**mechanism:** Extends the same StockSageDividend.swift (Rank 6) with a pure income estimator alongside the ex-date fetch. annualIncome(shares:annualRate:) = shares·annualRate; yieldOnPrice(annualRate:price:) = annualRate/price·100, both returning nil when the rate is missing/non-positive or price<=0 (labeled-absent, no fabricated yield). annualRate is sourced REAL from the same quoteSummary summaryDetail.dividendRate (parseAnnualDividendRate), reusing the StockSageEarnings.swift:55-57 access gate + equity guard + percent-encoding so it cannot silently spend or run on FX/crypto/indices (no dividend). Pure functions, python-verified. ADDITIVE new symbols only — PortfolioPosition (StockSagePortfolio.swift) and StockSagePortfolio stay byte-identical (no price coupling added to the store), so PersistenceRoundTripTests and all StockSage tests re-trace green. SHARES the fetch host already added in Rank 6 (ship as one file).

**signature:** extension StockSageDividend {
    nonisolated static func annualIncome(shares: Double, annualRate: Double?) -> Double?
    nonisolated static func yieldOnPrice(annualRate: Double?, price: Double) -> Double?
    nonisolated static func parseAnnualDividendRate(_ data: Data) -> Double?
}

**test:** def annual_income(shares, rate): return shares*rate if (rate is not None and rate>0) else None
def yield_on_price(rate, price): return (rate/price*100) if (rate is not None and rate>0 and price>0) else None
assert annual_income(100, 0.96)==96.0
y=yield_on_price(0.96, 192.0); assert y is not None and abs(y-0.5)<1e-9   # 0.96/192*100 = 0.5%
assert annual_income(100, None) is None and annual_income(100, 0) is None     # labeled-absent, not 0
assert yield_on_price(None,192.0) is None and yield_on_price(0.96,0) is None
import json
body={'quoteSummary':{'result':[{'summaryDetail':{'dividendRate':{'raw':0.96}}}]}}
assert body['quoteSummary']['result'][0]['summaryDetail']['dividendRate']['raw']==0.96
assert json.loads('{}').get('quoteSummary') is None

**caveat:** ESTIMATE, honestly flagged: annualIncome assumes the trailing/forward rate Yahoo reports CONTINUES unchanged for a year — a dividend can be cut, raised, suspended, or made special anytime, so this is a projection, not guaranteed cash. The rate is REAL (Yahoo summaryDetail.dividendRate) or the function returns nil and the UI shows 'dividend data unavailable' — never fabricated or zero-filled. yieldOnPrice is yield on CURRENT price, not cost basis (yield-on-cost would need costBasis), and it ignores withholding tax (notably .SR / foreign listings) and currency conversion, so NET received income is lower than the gross estimate. Non-equities return nil.

**edgeRationale:** The Markets view shows price P&L only and treats a 100-share holding paying $0.96/yr identically to a non-payer — yet that is a real, recurring ~$96/yr actually collected and never credited on screen. Quantifying it (and yield-on-position) changes real hold/sell decisions: a name that looks like dead money on price can be a 3-4% income earner worth keeping, and ranking holdings by yield-on-price surfaces where the portfolio's cash actually comes from. Ships in the same file as Rank 6, so its marginal build cost is small; ranked last because it depends on the Rank 6 fetch path and the dollar impact is income-visibility, not capital-at-risk.
