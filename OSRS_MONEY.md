# OSRS GE money optimization roadmap (wbf7xfo87, 2026-06-22)

8 items — gp/hr HONESTY (current gpPerHour assumes 100% fill). Real prices.runescape.wiki /24h data. RE-VERIFY vs source; engine-first + python-verified test.

### ⬜ #1 — Add RuneScapeDailyVolume model + /24h fetch/parse (the missing liquidity input)
**mechanism:** Prerequisite data plumbing. Verified gap: RuneScapeMarketService (RuneScape/RuneScapeMarketService.swift) fetches only /mapping (line 56) and /latest (line 49) — the Swift side has NO volume data at all, so StockSageGEFlip.gpPerHour (StockSage/StockSageGEFlip.swift:65) cannot gate on liquidity. The Java FlipFinder already fetches volumes (FlipFinder.java:43) and sums both legs (lines 78-79). Mirror that exactly: add a Sendable value type for the real /24h payload, a pure parser following the identical {"data":{"<id>":{...}}} shape parseLatest already decodes (RuneScapeMarketService.swift:66-79), and a keyless fetch gated by ToolPolicy.isExternalAllowed like fetchLatest (line 50). Reuse the existing private intval coercion (line 108) and the get() helper (line 96) — no new HTTP code. nil when a field/id is absent; never zero-that-passes, never fabricated.

**signature:** // RuneScapeModels.swift
struct RuneScapeDailyVolume: Sendable, Equatable {
    let avgHighPrice: Int?
    let highPriceVolume: Int?
    let avgLowPrice: Int?
    let lowPriceVolume: Int?
    /// 24h units across both legs; nil only if BOTH legs are nil (never coerced to 0).
    var totalVolume: Int? { guard highPriceVolume != nil || lowPriceVolume != nil else { return nil }; return (highPriceVolume ?? 0) + (lowPriceVolume ?? 0) }
    /// Slower leg gates a two-sided flip; min of the two when both known, else the known one.
    var bindingLegVolume: Int? { switch (highPriceVolume, lowPriceVolume) { case let (h?, l?): return Swift.min(h, l); case let (h?, nil): return h; case let (nil, l?): return l; default: return nil } }
}
// RuneScapeMarketService.swift — mirror fetchLatest/parseLatest
static func fetchDailyVolume() async -> [Int: RuneScapeDailyVolume]   // GET \(base)/24h, gated by ToolPolicy.isExternalAllowed
static func parseDailyVolume(_ data: Data) -> [Int: RuneScapeDailyVolume]   // pure; same {"data":{...}} shape as parseLatest; bad rows skipped, returns [:] on garbage

**test:** parseDailyVolume24hShapeAndNulls (no network, mirrors the parseLatest test discipline): feed a literal 2-id JSON fixture — one full row {"avgHighPrice":288,"highPriceVolume":3684977,"avgLowPrice":283,"lowPriceVolume":1845326}, one row with highPriceVolume null → assert exact decoded ints, totalVolume sums both legs, bindingLegVolume returns min when both present and the surviving leg when one is nil; a both-legs-null row → totalVolume==nil (NOT 0); malformed/empty body → [:] with no crash.

**caveat:** /24h is a 24-hour AVERAGE/total — it does not see a sudden spike or a dead hour, and reports volume that ALREADY occurred at market prices, so it is a liquidity PROXY, not a guarantee your offer fills at the current quote. It matches what the Java side already trusts; label it a 24h average. Keyless+free, same ToolPolicy gate as the existing fetches — .auto must not be made to spend. prices.runescape.wiki is community-run, not official Jagex data.

### ⬜ #2 — Thread volume through RuneScapeStore.refresh() so the velocity path has data
**mechanism:** Without this the new model is dead. RuneScapeStore.refresh() (RuneScape/RuneScapeStore.swift:37) currently awaits fetchMapping (line 47) + fetchLatest (line 53) only and stores latest (line 60). Add one keyless GET: await RuneScapeMarketService.fetchDailyVolume() alongside fetchLatest, store it in a private `volumes: [Int: RuneScapeDailyVolume]` next to `latest` (line 31), and expose it so the flips path can consume it. Non-destructive on failure, matching the existing pattern where an empty prices result keeps the last data (lines 56-59) — a missing /24h map just means volume is unknown (nil downstream), never zero.

**signature:** // RuneScapeStore.swift
private var volumes: [Int: RuneScapeDailyVolume] = [:]   // sibling of `latest` (line 31)
// inside refresh(), after fetchLatest:
let vols = await RuneScapeMarketService.fetchDailyVolume()
if !vols.isEmpty { volumes = vols }   // keep last on failure, like prices

**test:** No new unit test required for the store (it is @MainActor I/O); covered indirectly by the flips() ranking test in rank 4. Build-green check only: the extra await compiles and the empty-result branch leaves `volumes` untouched. Do not assert against live network in tests.

**caveat:** One extra keyless GET per refresh on the same gate — confirm it stays behind ToolPolicy.webToolsDisabledReason() (RuneScapeStore.swift:39) so Offline/Web-off still produces no network. A nil volume for an id MUST propagate as 'unknown', never silently become 0 (which would wrongly read as 'illiquid, drop it') or full-limit (which would wrongly read as 'infinitely liquid').

### ⬜ #3 — freshnessFactor — decay gp/hour by how stale the quote legs are (activate the dead timestamps)
**mechanism:** RuneScapePrice.highTime/lowTime (RuneScapeModels.swift:34-36) are parsed from /latest but the velocity path never reads them — a quote last traded 3 days ago ranks identically to one 30 seconds old. Add a pure multiplier in [0,1] from the OLDER leg (the limiting factor), matching FlipFinder.oldestTradedTimestamp (FlipFinder.java:155-162) which takes min(highTime,lowTime). Exponential decay pow(0.5, ageMin/halfLifeMin) replaces the Java binary maxStaleMinutes cliff (FlipFinder.java:117) with a smooth taper. `now: Date` is passed IN (not read from the clock) so it stays pure and deterministic, exactly as FlipFinder.rank takes nowSeconds (FlipFinder.java:55). nil timestamp returns an explicit unknownFactor (default 1.0 to preserve today's numbers), never a silent assumption of freshness.

**signature:** // StockSageGEFlip.swift
nonisolated static func freshnessFactor(now: Date, highTime: Date?, lowTime: Date?, halfLifeMinutes: Double = 30, unknownFactor: Double = 1.0) -> Double
//  ageMinutes from the OLDER (max age) of the two legs; pow(0.5, ageMinutes/halfLifeMinutes) clamped to [0,1]; returns unknownFactor when either time is nil

**test:** freshnessFactor pure, deterministic via injected now: both legs at now → ≈1.0; both at now-30min, halfLife 30 → ≈0.5; one leg now-60min + one now-1min uses the 60-min (older) leg → ≈0.25; either time nil → unknownFactor; result always within [0,1]. No clock read.

**caveat:** Half-life is a heuristic, not a measured fill probability — owner-tunable. Using the older leg can over-penalize an item whose buy side is fresh but whose sell side rarely prints; that conservatism is intentional (a one-sided fresh spread is risky) and must be disclosed in the UI explainer, not hidden. Default unknownFactor 1.0 keeps current ranking until the owner opts into penalizing unknowns.

### ⬜ #4 — liquidityFactor + volume-throttled flips() — cap realized fill at daily volume, rank honestly
**mechanism:** The core honesty fix. gpPerHour (StockSageGEFlip.swift:65) credits profit×buyLimit÷4h unconditionally — a 100%-fill fantasy that gives a 5M-gp item trading 12×/day the same per-window completeness as a nature rune. Add liquidityFactor in [0,1]: expectedFillUnits = min(buyLimit, floor(bindingLegVolume × windowHours/24 × participationShare)); factor = expectedFillUnits / buyLimit. participationShare (default 0.10) is the ONE modeling parameter — you are one flipper among many — exposed as an argument and labeled an assumption, never a measured fact. Then thread it through: extend GEFlip with dailyVolume, effGpPerHour, freshnessFactor, and isVolumeBound (expectedFill < buyLimit); change flips() to accept the /24h map + now: Date and sort by effGpPerHour = gpPerHour × freshnessFactor × liquidityFactor DESC instead of raw gpPerHour (line 82). Keep raw gpPerHour as nominal so the UI shows the gap. nil volume → conservative unknownLiquidity (default 0.25, NOT 1.0 — unknown must not score like proven), surfaced as 'liquidity unknown'.

**signature:** // StockSageGEFlip.swift
nonisolated static let windowsPerDay = 6.0   // 24/4
nonisolated static let defaultParticipation = 0.10   // labeled assumption, tunable
nonisolated static func liquidityFactor(buyLimit: Int, dailyVolume: Int?, participationShare: Double = defaultParticipation, unknownLiquidity: Double = 0.25) -> Double   // vol nil→unknownLiquidity; vol 0→0; else min(1, floor(dailyVolume*windowHours/24*share)/max(buyLimit,1))
nonisolated static func effGpPerHour(buy: Int, sell: Int, buyLimit: Int, dailyVolume: Int?, highTime: Date?, lowTime: Date?, now: Date, rate: Double = defaultRate, halfLifeMinutes: Double = 30, participationShare: Double = defaultParticipation) -> Double?   // gpPerHour(...).map { $0 * freshnessFactor(...) * liquidityFactor(...) }
nonisolated static func flips(_ listings: [RuneScapeListing], volumes: [Int: RuneScapeDailyVolume], now: Date, rate: Double = defaultRate, participation: Double = defaultParticipation) -> [GEFlip]   // sorted by effGpPerHour desc
// GEFlip gains: let dailyVolume: Int?; let effGpPerHour: Double; let freshnessFactor: Double; let isVolumeBound: Bool; var nominalGpPerHour: Double { gpPerHour }

**test:** liquidityFactor(buyLimit:1000, dailyVolume:60000, share:0.10) → floor(60000*(4/24)*0.10)=1000 → 1.0 (limit-bound); (buyLimit:1000, dailyVolume:120, share:0.10) → floor(2)=2 → 0.002 (illiquid trap crushed); dailyVolume 0→0; nil→0.25; result ∈[0,1]. flipsRankByEffGpPerHourDemotingIlliquid: FAT (buy 1M/sell 1.05M, limit 8, volume 50/day) vs THIN-FAST (buy 100/sell 130, limit 10000, volume 5,000,000/day) — assert effGpPerHour ranks THIN-FAST first (FAT volume-bound to ~0, isVolumeBound==true), and a volume-nil item keeps nominal with isVolumeBound==false.

**caveat:** BREAKING: extending GEFlip touches every initializer — the call site at StockSageGEFlip.swift:79-80 AND the test helper at StockSageGEFlipTests.swift:37-39 must add the new fields. The existing flipsRankByGpPerHourDescDroppingLosers (StockSageGEFlipTests.swift:73) and gpPerHourUsesMarginTaxAndBuyLimit (line 14) assert OLD full-limit numbers and the OLD flips() arity — update them, do not leave red. participationShare and the 24h→4h proration are coarse approximations of an order book the API can't see; the UI must label effGpPerHour 'expected at ~10% volume share' and surface isVolumeBound, never silently treat missing volume as fast. Defaults preserve today's behavior only if you pass unknownLiquidity 1.0; the recommended 0.25 is an intentional opt-in ranking change — log it in DEVELOPMENT_LOG.md per repo directive.

### ⬜ #5 — hoursToFillLimit + unitsPerHour — human-readable fill-time estimate
**mechanism:** The throughput fix answers gp/hour; flippers also want 'how long until my offer fills'. Derive transparently from the same real /24h binding-leg volume + real /mapping buyLimit (RuneScapeModels.swift:20), reusing the SAME participationShare from rank 4 so the two estimates stay internally consistent (not re-invented). Surfaces that a fat margin taking 40h to clear one limit is visibly NOT fast — the readable companion to effGpPerHour, feeding the same isVolumeBound story.

**signature:** // StockSageGEFlip.swift
nonisolated static func unitsPerHour(volume24h: Int?, participation: Double = defaultParticipation) -> Double?   // volume24h/24*participation; nil if volume unknown
nonisolated static func hoursToFillLimit(buyLimit: Int, volume24h: Int?, participation: Double = defaultParticipation) -> Double?   // buyLimit / unitsPerHour; nil if volume unknown OR zero (no division blowup)

**test:** hoursToFillTracksVolume: buyLimit 10000, volume24h 240000, share 0.10 → unitsPerHour 1000 → hoursToFillLimit 10.0; halve volume → 20.0; volume24h nil → nil (no fabricated time); volume24h 0 → nil (no divide-by-zero).

**caveat:** Fill time from a 24h average is a planning estimate, not a promise — real fills cluster (peak vs dead hours) and depend on how aggressively you price. Label 'est. hrs to fill one limit at ~10% share'; when nil (volume unknown), the UI must say 'fill time unknown', never imply instant.

### ⬜ #6 — GEFlipAllocation + AllocatedGEFlip value types (gp-denominated, expectedFill-capped)
**mechanism:** New result structs mirroring the stock-side CapitalAllocation/AllocatedPosition shape but in gp. Pure value types, no financial math. AllocatedGEFlip carries per item: itemId, name, buyPrice, units, capital, gpPerWindow, effGpPerHour, and limitBound (true when units hit the per-window cap — the signal that MORE CAPITAL yields ZERO extra gp/hr). Critically, the per-window cap must be expectedUnitsPerWindow = min(buyLimit, volume-feasible) from rank 4, NOT raw buyLimit, or the plan over-promises fills the market can't supply — the existing bestFlipsForBudget (StockSageGEFlip.swift:95-110) caps at raw buyLimit (line 100), which is the dishonesty this carries forward to fix. GEFlipAllocation aggregates flips, deployedCapital, idleCapital (budget − deployed − reserve, exact Int), reserve, totalGpPerHour, boardCeilingGpPerHour, marginalGpPerHourPerMillion, and caveat:String.

**signature:** struct AllocatedGEFlip: Sendable, Equatable, Identifiable { let itemId: Int; let name: String; let buyPrice: Int; let units: Int; let capital: Int; let gpPerWindow: Int; let effGpPerHour: Double; let limitBound: Bool; var id: Int { itemId } }
struct GEFlipAllocation: Sendable, Equatable { let flips: [AllocatedGEFlip]; let deployedCapital: Int; let idleCapital: Int; let reserve: Int; let totalGpPerHour: Double; let boardCeilingGpPerHour: Double; let marginalGpPerHourPerMillion: Double; let caveat: String }

**test:** Equatable/Encodable round-trip; limitBound true iff units==expectedUnitsPerWindow; idleCapital + deployedCapital + reserve == budget exactly (Int, no rounding drift); flips sorted desc effGpPerHour with itemId tie-break. gp is Int (64-bit on macOS) so gpPerWindow on a huge limit can't overflow — same discipline the existing gpPerHourHandlesHugeBuyLimitWithoutOverflow test (StockSageGEFlipTests.swift:30) proved for the Double path.

**caveat:** gp is Int throughout (OSRS coins are integers); per-hour figures are Double. The cap must be the volume-aware expectedUnitsPerWindow, not raw buyLimit, otherwise the allocator inherits the same 100%-fill fantasy this whole roadmap removes.

### ⬜ #7 — StockSageGEFlip.allocate(...) — multi-item, limit-and-volume-respecting capital allocator
**mechanism:** Replace the thin greedy bestFlipsForBudget (StockSageGEFlip.swift:95) with a spread-aware allocator encoding buy-limit-AND-volume-as-binding-constraint. Algorithm: (1) reserve floor(budget*reserveFraction) for slippage/partial fills — the existing greedy assumes 100% deployment, line 96's honesty gap. (2) Rank profitable flips by effGpPerHour desc. (3) Waterfall deployable budget: units = min(expectedUnitsPerWindow, remaining/buyPrice); when an item saturates its per-window cap its gp/hr is FIXED and capital MUST flow to the next item ('more items, not bigger stacks' made mechanical). (4) boardCeilingGpPerHour = sum over ALL profitable flips of full-cap eff gp/hr. (5) When deployable exceeds sum(cap*buyPrice), surplus is idleCapital with total pinned at the ceiling — proving income is CAPPED. Pure, deterministic, integer-exact; reuses gpPerHour/sellTax/effGpPerHour — no new financial math.

**signature:** // StockSageGEFlip.swift
nonisolated static func allocate(_ flips: [GEFlip], budget: Int, reserveFraction: Double = 0.05, maxItems: Int = .max) -> GEFlipAllocation

**test:** Synthetic board (same style as the existing bestFlipsForBudgetGreedyByVelocity test, StockSageGEFlipTests.swift:56 — no real-item price claims): budget 200k/reserve 0 → A only, A.limitBound false; budget at saturation/reserve 0 → all items saturated, totalGpPerHour==boardCeilingGpPerHour, idleCapital 0; budget 10× saturation/reserve 0 → STILL ==ceiling, idleCapital>0 (the cap proof); marginalGpPerHourPerMillion falls as budget grows; reserveFraction 0.05 → deployed ≤ budget−reserve; empty flips / budget≤0 → empty allocation, no crash; maxItems caps the spread.

**caveat:** GE flip income is CAPPED, not exponential. Each item's gp/hr is hard-bounded by profitPerItem×expectedUnitsPerWindow/4h; the board total by the sum, so beyond the saturation bankroll EXTRA CAPITAL ADDS ZERO INCOME. More bankroll buys WIDER spread until the profitable universe is exhausted, then the ceiling is absolute until prices/limits/volume move. This is the same volume reality the RuneLite plugin enforces via minVolume (FlipFinder.java:96) — the allocator must cap on expectedUnitsPerWindow, not raw buyLimit, to match.

### ⬜ #8 — boardCeilingGpPerHour + saturationBudget — the hard income cap as on-screen numbers
**mechanism:** Two standalone pure helpers so the cap shows WITHOUT running a full allocation. boardCeilingGpPerHour = sum over profitable flips of profitPerItem×expectedUnitsPerWindow÷windowHours — the single number disproving 'scale bankroll → scale income'; it depends only on the current board + volume, not on how much gp you hold. saturationBudget = sum(expectedUnitsPerWindow×buyPrice) — the exact gp where the board saturates and total reaches the ceiling. RuneScapeMarketView already calls bestFlipsForBudget near the budget slider (RuneScapeMarketView.swift, the budget-plan path); surface 'Max achievable: X gp/hr — more gp past Y won't help' there.

**signature:** // StockSageGEFlip.swift
nonisolated static func boardCeilingGpPerHour(_ flips: [GEFlip]) -> Double
nonisolated static func saturationBudget(_ flips: [GEFlip]) -> Int

**test:** boardCeilingGpPerHour: empty→0; single flip→its own effGpPerHour; multi→sum; equals allocate(...).totalGpPerHour when budget ≥ saturationBudget (the saturation-equivalence invariant — both paths must agree at the cap). saturationBudget: allocate(board, budget: saturationBudget, reserveFraction: 0) has idleCapital 0 AND total==ceiling; at saturationBudget+1 → idleCapital 1; empty→0.

**caveat:** This ceiling assumes every per-window cap fills each window, so it's an OPTIMISTIC upper bound — realized income is ≤ this, never more. It moves as live margins/limits/volume move; not a guaranteed rate. GE flipping is fixed-ceiling income, not exponential compounding — saturationBudget is typically reached fast on a small profitable universe, after which growth needs NEW profitable items (price moves), not more gp. The 2% sell tax (StockSageGEFlip.sellTax, line 58) is already subtracted in profitPerItem, so every figure here is post-tax. Per repo directive, after implementing append a DEVELOPMENT_LOG.md entry and add the /24h volume fetch to PROJECT_CONTEXT.md.
