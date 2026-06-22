import Foundation
import Combine

/// One ranked trade idea: a symbol joined with the advisor's verdict on its real
/// candle history. What the "Ideas" board renders.
struct StockSageIdea: Sendable, Equatable, Identifiable {
    let symbol: String
    let market: String
    let price: Double
    let advice: TradeAdvice
    /// Downsampled recent closes for the inline sparkline (newest last).
    let spark: [Double]
    var id: String { symbol }
}

// MARK: - StockSageStore
//
// In-memory store for tracked symbols. Reworked from the package's SwiftData
// `MarketStore` (renamed to avoid colliding with Chat A's `MarketStore` in
// `Views/MarketsStub.swift`, and de-SwiftData'd to drop the force-try container
// init).
//
// **Data source:** the StockSage v32 package shipped NO live price feed, so this
// store starts from a small, clearly-labeled SAMPLE set purely so the signal /
// briefing / monitor layers are demonstrable end-to-end. When Chat A's Phase-2
// Yahoo Finance feed lands, replace `seedSampleData()` with real fetches — every
// downstream layer is data-source-agnostic and just consumes `StockSageSymbol`s.
@MainActor
final class StockSageStore: ObservableObject {
    static let shared = StockSageStore()

    @Published private(set) var symbols: [StockSageSymbol] = []
    /// Distinguishes the built-in demo data from a real feed, so the UI/tool can
    /// say "sample data" honestly rather than implying live quotes.
    @Published private(set) var isSampleData = true
    /// True when the board is seeded from the DISK CACHE (real last-good prices) rather
    /// than sample data or a live fetch — cleared on the next successful refresh.
    @Published private(set) var loadedFromCache = false
    /// When the cached snapshot was saved (for an honest "last good as of …" label).
    @Published private(set) var cacheSavedAt: Date?

    /// When the last successful live refresh completed (nil = still on the sample
    /// seed). Drives the "updated HH:mm" status in the Markets header.
    @Published private(set) var lastUpdated: Date?
    /// True while a live fetch is in flight — spins the refresh control.
    @Published private(set) var isRefreshing = false
    /// Human-readable reason the last refresh produced no live data (offline,
    /// web access off, feed unreachable). nil when the feed is healthy.
    @Published private(set) var feedError: String?

    // Advice/ideas — the advisor run across the universe on real candle history.
    @Published private(set) var ideas: [StockSageIdea] = []
    @Published private(set) var isLoadingIdeas = false
    @Published private(set) var ideasUpdated: Date?
    @Published private(set) var ideasError: String?
    /// Symbols the last analysis couldn't fetch history for (feed miss / rate-limit) —
    /// surfaced so the board never silently ranks on a partial universe.
    @Published private(set) var ideasMissing: [String] = []

    /// Signal alerts — events (flips, stop/target crossings) detected between
    /// successive Ideas refreshes. Opt-in (off by default); a capped event log.
    @Published var alertsEnabled = false
    @Published private(set) var alerts: [IdeaAlert] = []
    private static let maxAlerts = 50

    func clearAlerts() { alerts = [] }

    // User-added watchlist tickers (beyond the curated universe), persisted.
    @Published private(set) var userSymbols: [String] = []
    @Published private(set) var isAddingSymbol = false
    @Published private(set) var addSymbolError: String?
    private static let userSymbolsKey = "stocksage_user_symbols"
    private static let userMarketLabel = "★ My watchlist"

    private init() {
        userSymbols = (UserDefaults.standard.array(forKey: Self.userSymbolsKey) as? [String]) ?? []
        seedSampleData()
        loadCachedQuotes()   // prefer real last-good prices over the sample seed when we have them
    }

    /// Seed the board from the disk cache (last successful quotes) so launch shows real
    /// last-good numbers instantly + works offline, instead of fabricated sample data.
    private func loadCachedQuotes() {
        guard let cache = StockSageQuoteCache.load(), !cache.entries.isEmpty else { return }
        let labels = Dictionary(trackedDefs().map { ($0.symbol.uppercased(), $0.market) },
                                uniquingKeysWith: { a, _ in a })
        symbols = cache.symbols(marketFor: { labels[$0.uppercased()] ?? Self.userMarketLabel })
        isSampleData = false
        loadedFromCache = true
        cacheSavedAt = cache.savedAt
    }

    /// Every tracked instrument definition: the curated universe + the user's
    /// added tickers (deduped). Drives both the live feed and the ideas analysis,
    /// so user picks survive refreshes and get analyzed too.
    private func trackedDefs() -> [StockSageSymbol] {
        var defs = StockSageUniverse.worldwide
        let known = Set(defs.map { $0.symbol.uppercased() })
        for s in userSymbols where !known.contains(s.uppercased()) {
            defs.append(StockSageSymbol(symbol: s, market: Self.userMarketLabel))
        }
        return defs
    }

    /// Pure validation/normalization for a user-typed ticker. Returns the
    /// normalized symbol (or nil) and a rejection reason (or nil). Testable.
    static func validateNewSymbol(_ raw: String, alreadyTracked: Set<String>) -> (symbol: String?, error: String?) {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !s.isEmpty else { return (nil, "Enter a ticker.") }
        guard s.count <= 20, !s.contains(" ") else { return (nil, "That doesn't look like a ticker.") }
        guard !alreadyTracked.contains(s) else { return (nil, "\(s) is already tracked.") }
        return (s, nil)
    }

    /// Validate a typed ticker against a LIVE quote; if it prices, add it to the
    /// persisted watchlist and show it immediately. Honest rejection otherwise.
    func addSymbol(_ raw: String) async {
        guard !isAddingSymbol else { return }
        let tracked = Set(userSymbols.map { $0.uppercased() })
            .union(StockSageUniverse.worldwide.map { $0.symbol.uppercased() })
        let validation = Self.validateNewSymbol(raw, alreadyTracked: tracked)
        guard let symbol = validation.symbol else { addSymbolError = validation.error; return }
        if let reason = ToolPolicy.webToolsDisabledReason() { addSymbolError = reason; return }

        isAddingSymbol = true
        addSymbolError = nil
        let quotes = await StockSageQuoteService.fetchQuotes(for: [symbol])
        isAddingSymbol = false
        guard let q = quotes[symbol] else {
            addSymbolError = "Couldn't find a tradeable price for “\(symbol)”. Check the ticker (e.g. AAPL, 2222.SR, BTC-USD)."
            return
        }
        userSymbols.append(symbol)
        UserDefaults.standard.set(userSymbols, forKey: Self.userSymbolsKey)
        // Show it on the board now, without disturbing the sample/live flag.
        let added = StockSageSymbol(symbol: symbol, market: Self.userMarketLabel, quotes: [
            StockSageQuote(price: q.previousClose, previousPrice: q.previousClose, time: Date(timeIntervalSinceNow: -86_400)),
            StockSageQuote(price: q.price, previousPrice: q.previousClose),
        ])
        symbols = symbols.filter { $0.symbol.uppercased() != symbol } + [added]
    }

    /// Remove a user-added ticker (no-op for curated-universe symbols).
    func removeSymbol(_ symbol: String) {
        let up = symbol.uppercased()
        guard userSymbols.contains(where: { $0.uppercased() == up }) else { return }
        userSymbols.removeAll { $0.uppercased() == up }
        UserDefaults.standard.set(userSymbols, forKey: Self.userSymbolsKey)
        symbols = symbols.filter { $0.symbol.uppercased() != up }
    }

    /// Analyze the worldwide universe on real 1-year candle history and rank the
    /// results into actionable ideas (strongest buys first). Heavy (one history
    /// fetch per symbol), so it's user-triggered, never automatic. Non-destructive
    /// on failure. No-op-with-reason when external access is off.
    func refreshIdeas() async {
        guard !isLoadingIdeas else { return }
        if let reason = ToolPolicy.webToolsDisabledReason() {
            ideasError = reason
            return
        }
        isLoadingIdeas = true
        defer { isLoadingIdeas = false }   // stays true across the fetch AND the detached compute
        ideasError = nil
        let universe = trackedDefs()
        // Fetch the benchmark (^GSPC) in parallel so each idea can be scored on relative
        // strength vs the index; nil on failure → ideas degrade gracefully to absolute signals.
        async let benchmarkTask = StockSageQuoteService.fetchHistory("^GSPC", range: "1y")
        let histories = await StockSageQuoteService.fetchHistories(for: universe.map(\.symbol))
        let benchmark = await benchmarkTask

        guard !histories.isEmpty else {
            ideasError = "Couldn't reach the market feed for analysis — try again."
            return
        }
        let built = await Self.buildIdeas(defs: universe, histories: histories, benchmark: benchmark)
        let ranked = built.sorted { Self.rankScore($0.advice) > Self.rankScore($1.advice) }
        // Detect alert events vs the PREVIOUS snapshot before replacing it.
        if alertsEnabled, !ideas.isEmpty {
            let fired = StockSageAlerts.detect(previous: ideas, current: ranked)
            if !fired.isEmpty { alerts = Array((fired + alerts).prefix(Self.maxAlerts)) }
        }
        ideas = ranked
        // Partial success is honest success: keep the names that priced, and NAME the
        // ones that didn't so the EV ranking isn't silently computed on a subset.
        let analyzed = Set(built.map { $0.symbol.uppercased() })
        // Indices are DELIBERATELY skipped by buildIdeas (not buyable) — don't report them as fetch
        // failures, or ~17 healthy index tickers show a permanent "couldn't be fetched" with a retry
        // button that can never clear.
        ideasMissing = universe.map(\.symbol).filter {
            !analyzed.contains($0.uppercased()) && StockSageAllocation.assetClass($0) != "Index"
        }
        ideasUpdated = Date()
    }

    /// Re-fetch ONLY the symbols the last scan couldn't price and merge them in, re-ranking.
    /// Cheap relative to a full refresh; user-triggered from the "Retry failed" affordance.
    func retryFailedIdeas() async {
        guard !isLoadingIdeas, !ideasMissing.isEmpty else { return }
        if let reason = ToolPolicy.webToolsDisabledReason() { ideasError = reason; return }
        isLoadingIdeas = true
        defer { isLoadingIdeas = false }
        ideasError = nil
        let retrySet = Set(ideasMissing.map { $0.uppercased() })
        let defs = trackedDefs().filter { retrySet.contains($0.symbol.uppercased()) }
        let histories = await StockSageQuoteService.fetchHistories(for: defs.map(\.symbol))
        guard !histories.isEmpty else {
            ideasError = "Still couldn't reach those symbols — try again later."
            return
        }
        let built = await Self.buildIdeas(defs: defs, histories: histories)
        let newSyms = Set(built.map { $0.symbol.uppercased() })
        let merged = (ideas.filter { !newSyms.contains($0.symbol.uppercased()) } + built)
            .sorted { Self.rankScore($0.advice) > Self.rankScore($1.advice) }
        ideas = merged
        let analyzed = Set(merged.map { $0.symbol.uppercased() })
        ideasMissing = trackedDefs().map(\.symbol).filter {
            !analyzed.contains($0.uppercased()) && StockSageAllocation.assetClass($0) != "Index"
        }
        ideasUpdated = Date()
    }

    /// Build ranked ideas off the main actor (the advisor runs every indicator over each
    /// symbol's full year). Pure over its inputs; everything it touches is Sendable.
    nonisolated static func buildIdeas(defs: [StockSageSymbol],
                                       histories: [String: StockSagePriceHistory],
                                       benchmark: StockSagePriceHistory? = nil) async -> [StockSageIdea] {
        await Task.detached(priority: .userInitiated) {
            var out: [StockSageIdea] = []
            for sym in defs {
                guard let history = histories[sym.symbol.uppercased()], let price = history.latestClose else { continue }
                // An index LEVEL (^GSPC/^VIX) is not a buyable instrument — never surface it as a
                // buy/stop/target/size idea (it would also pollute the EV/velocity/allocator math).
                guard StockSageAllocation.assetClass(sym.symbol) != "Index" else { continue }
                // Relative-strength-vs-S&P only means something for EQUITIES — pass the benchmark only
                // there so FX/crypto don't get a meaningless "Leading/Lagging the S&P" term (and an
                // index never benchmarks against itself, now moot since indices are excluded above).
                let bench = StockSageAllocation.assetClass(sym.symbol) == "Equity" ? benchmark : nil
                let advice = StockSageAdvisor.advise(history: history, benchmark: bench)
                let spark = SparkSeries.downsample(Array(history.closes.suffix(63)))
                out.append(StockSageIdea(symbol: sym.symbol, market: sym.market,
                                         price: price, advice: advice, spark: spark))
            }
            return out
        }.value
    }

    // Risk-parity — inverse-vol target weights across the owner's holdings.
    @Published private(set) var riskParity: [RiskParityTarget] = []
    @Published private(set) var isComputingParity = false
    @Published private(set) var parityError: String?

    /// Fetch each holding's history, derive its annualized volatility, and compute
    /// inverse-vol (risk-parity) target weights + rebalance deltas. User-triggered;
    /// non-destructive on failure.
    func refreshRiskParity() async {
        guard !isComputingParity else { return }
        let positions = StockSagePortfolio.shared.positions
        guard !positions.isEmpty else {
            riskParity = []
            parityError = "Add holdings to your portfolio first."
            return
        }
        if let reason = ToolPolicy.webToolsDisabledReason() {
            parityError = reason
            return
        }
        isComputingParity = true
        parityError = nil
        let histories = await StockSageQuoteService.fetchHistories(for: positions.map(\.symbol))
        isComputingParity = false

        var holdings: [RiskParityHolding] = []
        for p in positions {
            guard let history = histories[p.symbol.uppercased()],
                  let vol = StockSageIndicators.annualizedVolatility(history.closes), vol > 0,
                  let price = history.latestClose else { continue }
            holdings.append(RiskParityHolding(symbol: p.symbol, currentValue: price * p.shares, volatility: vol))
        }
        guard !holdings.isEmpty else {
            parityError = "Couldn't get enough history to risk-size the portfolio."
            return
        }
        riskParity = StockSageRiskParity.targets(holdings)
    }

    // Market regime — the risk-on/off meta-gauge.
    @Published private(set) var regime: MarketRegime?
    @Published private(set) var regimeGaugedAt: Date?
    @Published private(set) var isLoadingRegime = false
    @Published private(set) var regimeError: String?

    /// Gauge the market regime: the S&P 500 vs its 200DMA + index momentum, the
    /// VIX level, and breadth (fraction of a large-cap sample above their own
    /// 200DMA). User-triggered; non-destructive on failure.
    func refreshRegime() async {
        guard !isLoadingRegime else { return }
        if let reason = ToolPolicy.webToolsDisabledReason() {
            regimeError = reason
            return
        }
        isLoadingRegime = true
        defer { isLoadingRegime = false }
        regimeError = nil

        let sample = StockSageRegime.breadthSample
        async let indexHistory = StockSageQuoteService.fetchHistory("^GSPC", range: "1y")
        async let vixQuotes = StockSageQuoteService.fetchQuotes(for: ["^VIX"])
        async let breadthHistories = StockSageQuoteService.fetchHistories(for: sample)

        let idx = await indexHistory
        let vix = (await vixQuotes)["^VIX"]?.price
        let hists = await breadthHistories

        guard let idx else {
            regimeError = "Couldn't load the market index — try again."
            return
        }
        // Breadth: fraction of the sample above its own 200DMA (names without a
        // computable 200DMA are excluded from the denominator — see the helper).
        let priced = sample.compactMap { hists[$0.uppercased()] }
        let breadth = StockSageRegime.breadth(priced)

        regime = StockSageRegime.assess(indexCloses: idx.closes, vix: vix, breadthAbove200: breadth)
        regimeGaugedAt = Date()
    }

    /// True when the regime is older than ~6 trading hours (or never gauged) — a
    /// signal that any regime-derived sizing should be treated cautiously.
    var regimeIsStale: Bool {
        guard let at = regimeGaugedAt else { return true }
        return Date().timeIntervalSince(at) > 6 * 3600
    }

    // Multi-timeframe — daily+weekly trend agreement, cached per symbol.
    @Published private(set) var multiTimeframe: [String: MultiTimeframeTrend] = [:]

    /// Fetch a daily (1y) AND a weekly (2y, interval=1wk) history for one symbol and
    /// cache whether the two timeframes' trends agree. Computed once per symbol.
    func refreshMultiTimeframe(symbol: String) async {
        let up = symbol.uppercased()
        guard multiTimeframe[up] == nil, ToolPolicy.isExternalAllowed else { return }
        async let dailyHistory = StockSageQuoteService.fetchHistory(symbol, range: "1y", interval: "1d")
        async let weeklyHistory = StockSageQuoteService.fetchHistory(symbol, range: "2y", interval: "1wk")
        guard let d = await dailyHistory, let w = await weeklyHistory else { return }
        multiTimeframe[up] = StockSageMultiTimeframe.assess(dailyCloses: d.closes, weeklyCloses: w.closes)
    }

    // Strategy backtest — the advisor's rules aggregated across a sample universe.
    @Published private(set) var strategyBacktest: StrategyBacktest?
    @Published private(set) var isLoadingStrategy = false
    @Published private(set) var strategyError: String?

    /// Fetch ~5y for a bounded equity sample, walk-forward each off-main, and
    /// aggregate honest strategy-wide stats. User-triggered (heavy).
    func refreshStrategyBacktest() async {
        guard !isLoadingStrategy else { return }
        if let reason = ToolPolicy.webToolsDisabledReason() {
            strategyError = reason
            return
        }
        isLoadingStrategy = true
        defer { isLoadingStrategy = false }
        strategyError = nil

        let symbols = StockSageStrategyBacktest.sampleSymbols
        let histories = await StockSageQuoteService.fetchHistories(for: symbols, range: "5y")
        guard !histories.isEmpty else {
            strategyError = "Couldn't load histories to backtest the strategy — try again."
            return
        }
        let results: [BacktestResult] = await Task.detached {
            symbols.compactMap { sym -> BacktestResult? in
                guard let h = histories[sym.uppercased()] else { return nil }
                // Charge each symbol's asset-class round-trip cost so the strategy result
                // is what you'd net, not a frictionless fantasy.
                return StockSageBacktester.run(h, costs: StockSageNetEdge.defaultCosts(forSymbol: sym))
            }
        }.value
        strategyBacktest = StockSageStrategyBacktest.aggregate(results)
    }

    // Portfolio risk analytics — the full backward-looking risk/return suite.
    @Published private(set) var analytics: PortfolioAnalytics?
    @Published private(set) var correlation: CorrelationMatrix?
    @Published private(set) var isLoadingAnalytics = false
    @Published private(set) var analyticsError: String?

    /// Fetch each holding's history and compute the portfolio risk/return suite
    /// (Sharpe/Sortino/Calmar, max drawdown, VaR, correlation → diversification).
    /// User-triggered; heavy compute runs off-main; non-destructive on failure.
    func refreshPortfolioAnalytics() async {
        guard !isLoadingAnalytics else { return }
        let positions = StockSagePortfolio.shared.positions
        guard !positions.isEmpty else {
            analytics = nil
            analyticsError = "Add holdings to your portfolio first."
            return
        }
        if let reason = ToolPolicy.webToolsDisabledReason() {
            analyticsError = reason
            return
        }
        isLoadingAnalytics = true
        defer { isLoadingAnalytics = false }
        analyticsError = nil

        async let gspcHistory = StockSageQuoteService.fetchHistory("^GSPC", range: "1y")
        let histories = await StockSageQuoteService.fetchHistories(for: positions.map(\.symbol))

        // Build DATED returns per holding so co-movement stats can align by calendar
        // day, not array position — holdings span exchanges with different holidays.
        var symbols: [String] = []
        var weights: [Double] = []
        var datedHoldingReturns: [[(date: Date, ret: Double)]] = []
        for p in positions {
            guard let h = histories[p.symbol.uppercased()], let price = h.latestClose else { continue }
            let dr = StockSagePortfolioAnalytics.datedReturns(dates: h.dates, closes: h.closes)
            guard !dr.isEmpty else { continue }
            symbols.append(p.symbol)
            weights.append(price * p.shares)
            datedHoldingReturns.append(dr)
        }
        guard !symbols.isEmpty else {
            analyticsError = "Couldn't load enough history to analyze the portfolio."
            return
        }

        let marketDated = (await gspcHistory).map {
            StockSagePortfolioAnalytics.datedReturns(dates: $0.dates, closes: $0.closes)
        } ?? []

        // Align every holding (and the market when present) to their common days.
        let toAlign = marketDated.isEmpty ? datedHoldingReturns : datedHoldingReturns + [marketDated]
        let aligned = StockSagePortfolioAnalytics.alignByDate(toAlign)
        let holdingVecs = marketDated.isEmpty ? aligned : Array(aligned.dropLast())
        let marketVec = marketDated.isEmpty ? [] : (aligned.last ?? [])

        // Analytics suite over date-aligned data: rebuild pseudo-closes (cumulative
        // product of 1+ret) so compute()'s closes path runs on the aligned returns.
        let alignedHoldings: [(weight: Double, closes: [Double])] = zip(weights, holdingVecs).map { w, rets in
            var closes: [Double] = [100]
            for r in rets { closes.append(closes[closes.count - 1] * (1 + r)) }
            return (weight: w, closes: closes)
        }
        let computed = await Task.detached { StockSagePortfolioAnalytics.compute(holdings: alignedHoldings) }.value
        analytics = computed
        if computed == nil {
            analyticsError = "Not enough overlapping history across your holdings yet."
        }

        // Heatmap from the date-aligned holding return vectors.
        if symbols.count >= 2, (holdingVecs.first?.count ?? 0) >= 5 {
            correlation = CorrelationMatrix(symbols: symbols,
                                            matrix: StockSagePortfolioAnalytics.correlationMatrix(holdingVecs))
        } else {
            correlation = nil
        }

        // Beta: value-weighted portfolio vs the SAME-DAY market vector.
        let port = StockSagePortfolioAnalytics.portfolioReturns(holdings: alignedHoldings)
        portfolioBeta = (port.isEmpty || marketVec.isEmpty)
            ? nil : StockSagePortfolioAnalytics.beta(portfolio: port, market: marketVec)
    }

    /// Portfolio beta vs the S&P 500 (computed alongside the analytics).
    @Published private(set) var portfolioBeta: Double?

    // Correlation pre-check — how a candidate would affect portfolio concentration.
    @Published private(set) var precheck: [String: CorrelationPrecheck] = [:]
    /// The holdings fingerprint each cached verdict was computed under, so the
    /// cache RECOMPUTES when the book changes (add/remove a holding) instead of
    /// serving a stale concentration verdict.
    private var precheckFingerprint: [String: String] = [:]

    /// Compute (and cache) how adding `symbol` would correlate with the current
    /// holdings. Cached per (symbol + holdings fingerprint); no-op when access is off.
    func refreshPrecheck(symbol: String) async {
        let up = symbol.uppercased()
        let positions = StockSagePortfolio.shared.positions
        let fingerprint = positions.map { $0.symbol.uppercased() }.sorted().joined(separator: ",")
        // Fresh only if the verdict was computed under the CURRENT book.
        guard precheckFingerprint[up] != fingerprint else { return }
        if ToolPolicy.webToolsDisabledReason() != nil { return }
        guard !positions.isEmpty else {
            precheck[up] = CorrelationPrecheck(verdict: .noHoldings, avgCorrelation: 0,
                                               comparedCount: 0, mostCorrelatedSymbol: nil, mostCorrelation: 0)
            precheckFingerprint[up] = fingerprint
            return
        }
        var symbols = Set(positions.map { $0.symbol.uppercased() })
        symbols.insert(up)
        let hists = await StockSageQuoteService.fetchHistories(for: Array(symbols))
        guard let cand = hists[up] else { return }
        let candReturns = StockSagePortfolioAnalytics.dailyReturns(cand.closes)
        let holdReturns: [(symbol: String, returns: [Double])] = positions.compactMap { p in
            let psym = p.symbol.uppercased()
            guard psym != up, let h = hists[psym] else { return nil }
            return (p.symbol, StockSagePortfolioAnalytics.dailyReturns(h.closes))
        }
        precheck[up] = await Task.detached {
            StockSageCorrelationPrecheck.assess(candidate: candReturns, holdings: holdReturns)
        }.value
        precheckFingerprint[up] = fingerprint
    }

    // Earnings proximity — overnight-gap event risk for an equity. Cached per
    // symbol (earnings dates don't shift within a session).
    @Published private(set) var earnings: [String: EarningsProximity] = [:]

    func refreshEarnings(symbol: String) async {
        let up = symbol.uppercased()
        guard earnings[up] == nil else { return }
        guard let date = await StockSageEarnings.fetchNextEarnings(for: symbol),
              date.timeIntervalSinceNow > -86_400 else { return }   // ignore a stale past date
        earnings[up] = StockSageEarnings.proximity(now: Date(), earnings: date)
    }

    // Monthly seasonality — calendar-month return tendency over a long history.
    @Published private(set) var seasonality: [String: MonthlySeasonality] = [:]

    func refreshSeasonality(symbol: String) async {
        let up = symbol.uppercased()
        guard seasonality[up] == nil else { return }
        if ToolPolicy.webToolsDisabledReason() != nil { return }
        guard let h = await StockSageQuoteService.fetchHistory(symbol, range: "10y", interval: "1mo") else { return }
        seasonality[up] = await Task.detached {
            StockSageSeasonality.compute(dates: h.dates, closes: h.closes)
        }.value
    }

    // Liquidity — avg daily $ volume + tier, cached per symbol (equities/crypto only).
    @Published private(set) var liquidity: [String: LiquidityProfile] = [:]

    func refreshLiquidity(symbol: String) async {
        let up = symbol.uppercased()
        guard liquidity[up] == nil else { return }
        // USD-priced only: a foreign listing's local-currency volume mislabeled "$"
        // (and London's pence quotes) would give a wrong tier/number. FX/index too.
        guard StockSageLiquidity.isUSDPriced(symbol) else { return }
        if ToolPolicy.webToolsDisabledReason() != nil { return }
        guard let h = await StockSageQuoteService.fetchHistory(symbol, range: "3mo") else { return }
        if let p = StockSageLiquidity.profile(closes: h.closes, volumes: h.volumes) {
            liquidity[up] = p
        }
    }

    // ATR trailing-stop suggestion, cached per symbol.
    @Published private(set) var trailingStop: [String: TrailingStop] = [:]

    func refreshTrailingStop(symbol: String) async {
        let up = symbol.uppercased()
        guard trailingStop[up] == nil else { return }
        if ToolPolicy.webToolsDisabledReason() != nil { return }
        guard let h = await StockSageQuoteService.fetchHistory(symbol, range: "6mo") else { return }
        if let ts = StockSageTrailingStop.suggest(highs: h.highs, lows: h.lows, closes: h.closes) {
            trailingStop[up] = ts
        }
    }

    // Backtest — the honesty check for one symbol.
    @Published private(set) var backtest: BacktestResult?
    @Published private(set) var backtestSymbol: String?
    @Published private(set) var isBacktesting = false
    @Published private(set) var backtestError: String?

    /// Fetch a multi-year history for `symbol` and walk-forward backtest the
    /// advisor's rules over it. User-triggered; non-destructive on failure.
    func runBacktest(symbol: String) async {
        guard !isBacktesting else { return }
        backtestSymbol = symbol                     // surface which symbol, even while running/failed
        if let reason = ToolPolicy.webToolsDisabledReason() {
            backtestError = reason
            return
        }
        isBacktesting = true
        defer { isBacktesting = false }             // stays true across the fetch AND the O(bars²) compute
        backtestError = nil
        backtest = nil                              // clear the prior result while this runs
        underwater = nil
        // 5 years of daily bars → room to trade after the 200-day warmup.
        let history = await StockSageQuoteService.fetchHistory(symbol, range: "5y")
        guard let history else {
            backtestError = "Couldn't load enough history to backtest \(symbol)."
            return
        }
        // The walk-forward is O(bars²) (advisor re-run each bar) — keep it off-main.
        // Charge the symbol's asset-class round-trip cost so the equity curve is honest.
        let btCosts = StockSageNetEdge.defaultCosts(forSymbol: symbol)
        backtest = await Task.detached(priority: .userInitiated) { StockSageBacktester.run(history, costs: btCosts) }.value
        // Buy-and-hold underwater curve over the same 5y window (cheap, O(n)).
        underwater = StockSageDrawdown.underwater(history.closes)
    }

    /// Buy-and-hold underwater curve for the last backtested symbol (5y closes).
    @Published private(set) var underwater: UnderwaterCurve?

    /// Ranking score for the "best ideas now" board: strongest conviction buys
    /// first, holds/avoids in the middle, sells last.
    private static func rankScore(_ a: TradeAdvice) -> Double {
        switch a.action {
        case .strongBuy: return 2 + a.conviction
        case .buy:       return 1 + a.conviction
        case .hold:      return 0
        case .avoid:     return -0.1
        case .reduce:    return -1 - a.conviction
        case .sell:      return -2 - a.conviction
        }
    }

    // MARK: - Live worldwide feed

    /// Pull live quotes for the worldwide universe and swap them in, flipping the
    /// store off "sample". A no-op-with-reason when external access is disabled,
    /// and a non-destructive no-op when the feed is unreachable — the existing
    /// (sample or last-good) data stays on screen rather than blanking out.
    func refresh() async {
        guard !isRefreshing else { return }
        if let reason = ToolPolicy.webToolsDisabledReason() {
            feedError = reason
            return
        }

        isRefreshing = true
        feedError = nil
        let universe = trackedDefs()
        let quotes = await StockSageQuoteService.fetchQuotes(for: universe.map(\.symbol))
        isRefreshing = false

        // Merge each curated symbol (keeps the friendly market label) with its
        // live quote; drop any the feed couldn't price.
        let live: [StockSageSymbol] = universe.compactMap { sym in
            guard let q = quotes[sym.symbol.uppercased()] else { return nil }
            return StockSageSymbol(symbol: sym.symbol, market: sym.market, quotes: [
                StockSageQuote(price: q.previousClose, previousPrice: q.previousClose,
                               time: Date(timeIntervalSinceNow: -86_400)),
                StockSageQuote(price: q.price, previousPrice: q.previousClose),
            ])
        }
        guard !live.isEmpty else {
            feedError = "Couldn't reach the market feed — showing the last data."
            return
        }
        // Don't let a partial outage replace a full live board with a handful of
        // rows: if coverage collapsed and we already have live data, keep the
        // last-good snapshot instead of blanking most of it.
        let coverage = Double(live.count) / Double(max(universe.count, 1))
        if coverage < 0.5, !isSampleData, !symbols.isEmpty {
            feedError = "Partial market data this refresh — keeping the last full snapshot."
            return
        }
        // Preserve user-added tickers this refresh's pre-await snapshot may have
        // missed — e.g. a symbol added DURING the network await would otherwise be
        // wiped by the wholesale replace until the next cycle.
        // A removeSymbol() that landed DURING the await must win: this refresh's pre-await snapshot
        // still fetched + priced that ticker, so it sits in `live` and would otherwise revert the
        // removal on screen AND re-persist it to the cache (surviving relaunch). Drop any user-market
        // row whose symbol is no longer tracked. Curated rows are untouched (removeSymbol no-ops there).
        let tracked = Set(userSymbols.map { $0.uppercased() })
        let liveFiltered = live.filter {
            $0.market != Self.userMarketLabel || tracked.contains($0.symbol.uppercased())
        }
        let liveKeys = Set(liveFiltered.map { $0.symbol.uppercased() })
        let preservedUserRows = symbols.filter {
            $0.market == Self.userMarketLabel && !liveKeys.contains($0.symbol.uppercased())
        }
        let committed = liveFiltered + preservedUserRows
        replaceAll(committed, isSample: false)
        lastUpdated = Date()
        // Persist EXACTLY what is on screen (incl. preserved user-added tickers the feed missed this
        // cycle) — caching only `live` dropped them, so a tracked ticker vanished from the offline /
        // last-good board on next launch.
        loadedFromCache = false
        StockSageQuoteCache.from(symbols: committed, savedAt: lastUpdated ?? Date()).save()
    }

    func fetchAllSymbols() -> [StockSageSymbol] {
        symbols.sorted { $0.symbol < $1.symbol }
    }

    func symbol(named name: String) -> StockSageSymbol? {
        symbols.first { $0.symbol.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Replace the whole set (e.g. when a live feed delivers a fresh snapshot).
    /// Marks the store as no-longer-sample.
    func replaceAll(_ newSymbols: [StockSageSymbol], isSample: Bool = false) {
        symbols = newSymbols
        isSampleData = isSample
    }

    // MARK: - Sample data
    //
    // A handful of TASI + US names with one prior + current quote each, chosen to
    // exercise every signal branch (a strong mover, a moderate mover, a flat
    // one). NOT live — see the type doc above.
    private func seedSampleData() {
        symbols = [
            Self.sample("2222.SR", "TASI", previous: 28.50, current: 30.40),   // +6.7% → strong buy
            Self.sample("1120.SR", "TASI", previous: 92.10, current: 89.30),   // -3.0% → sell
            Self.sample("AAPL",    "NASDAQ", previous: 226.0, current: 227.1), // +0.5% → hold
            Self.sample("NVDA",    "NASDAQ", previous: 118.0, current: 126.5), // +7.2% → strong buy
            Self.sample("7010.SR", "TASI", previous: 41.0,  current: 42.3),    // +3.2% → buy
        ]
        isSampleData = true
    }

    private static func sample(_ ticker: String, _ market: String,
                               previous: Double, current: Double) -> StockSageSymbol {
        StockSageSymbol(symbol: ticker, market: market, quotes: [
            StockSageQuote(price: previous, previousPrice: previous,
                           time: Date(timeIntervalSinceNow: -3600)),
            StockSageQuote(price: current, previousPrice: previous),
        ])
    }
}
