import Foundation

// MARK: - StockSageQuoteService
//
// The live worldwide price feed the StockSage subsystem was always designed for
// (see `StockSageStore`'s doc: "When Chat A's Phase-2 Yahoo Finance feed lands,
// replace `seedSampleData()` with real fetches"). This is that feed.
//
// **Source:** Yahoo Finance's keyless `v8/finance/chart` endpoint — one of the
// few quote sources that needs no API key and covers virtually every exchange on
// Earth via symbol suffix (`.SR` Tadawul, `.L` LSE, `.T` Tokyo, `.HK` HKEX,
// `.NS` NSE India, `.AX` ASX, `.SA` B3 Brazil, `.PA` Euronext, `.DE` XETRA,
// `.SS` Shanghai, `.KS` KRX, `.TO` TSX, `^` = an index). Quotes are typically
// delayed ~15 min — the UI says so; we don't claim real-time.
//
// **Cost:** free / keyless, so it's safe under the app's local-first, never-spend
// `.auto` philosophy. It IS network, though, so every fetch is gated by
// `ToolPolicy.isExternalAllowed` (Web Access on AND Offline Mode off) — exactly
// the same gate the web/media tools honor.
enum StockSageQuoteService {

    /// A single live observation: the current market price and the prior session's
    /// close (the signal engine's % change is computed against this close, so a
    /// move here is a real one-day move, not a tick).
    struct LiveQuote: Sendable, Equatable {
        let symbol: String
        let price: Double
        let previousClose: Double
    }

    /// Browser-like UA — Yahoo's public endpoints answer plain clients far more
    /// reliably with one set (same rationale as `MediaSearch.ua`).
    private static let ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    // MARK: Public fetch

    /// Fetch live quotes for many symbols concurrently (bounded fan-out so we
    /// don't open 46 sockets at once). Returns a map keyed by the **requested**
    /// symbol, uppercased — symbols the feed couldn't price are simply absent, so
    /// callers should treat a missing key as "no live data for this one" rather
    /// than an error. No-ops (returns `[:]`) when external access is disabled.
    static func fetchQuotes(for symbols: [String], concurrency: Int = 6) async -> [String: LiveQuote] {
        guard ToolPolicy.isExternalAllowed else { return [:] }
        guard !symbols.isEmpty else { return [:] }

        var out: [String: LiveQuote] = [:]
        // Process in fixed-size chunks; each chunk is a TaskGroup that resolves
        // before the next starts — caps concurrency without a semaphore.
        let chunks = stride(from: 0, to: symbols.count, by: max(1, concurrency)).map {
            Array(symbols[$0 ..< min($0 + concurrency, symbols.count)])
        }
        for chunk in chunks {
            let results: [LiveQuote] = await withTaskGroup(of: LiveQuote?.self) { group in
                for symbol in chunk {
                    group.addTask { await fetchOne(symbol) }
                }
                var acc: [LiveQuote] = []
                for await q in group where q != nil { acc.append(q!) }
                return acc
            }
            for q in results { out[q.symbol.uppercased()] = q }
        }
        return out
    }

    // MARK: One symbol

    private static func fetchOne(_ symbol: String) async -> LiveQuote? {
        // `^` (index marker) and other reserved chars must be percent-encoded in
        // the path; `.` and `-` (the exchange suffixes) are path-legal and stay.
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?range=1d&interval=1d") else {
            return nil
        }
        var req = URLRequest(url: url)
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 12
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let parsed = parseChart(data) else { return nil }
        // Preserve the symbol we *asked* for so it maps back to the curated market
        // label (Yahoo echoes its own canonical symbol, which can differ in case).
        return LiveQuote(symbol: symbol, price: parsed.price, previousClose: parsed.previousClose)
    }

    // MARK: Parsing (pure — unit-tested without the network)

    /// Decode Yahoo's `v8/chart` JSON into a `LiveQuote`. Best-effort and total:
    /// any shape it doesn't recognize (an error payload, a missing price, a
    /// zero/negative price) yields `nil` rather than throwing. Reads `previousClose`
    /// with a `chartPreviousClose` fallback (indices often carry only the latter).
    static func parseChart(_ data: Data) -> LiveQuote? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = root["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let meta = results.first?["meta"] as? [String: Any],
              let symbol = meta["symbol"] as? String else { return nil }

        guard let price = number(meta["regularMarketPrice"]), price > 0 else { return nil }
        let previousClose = number(meta["previousClose"])
            ?? number(meta["chartPreviousClose"])
            ?? price   // brand-new listing with no prior close → flat (0% move → hold)
        return LiveQuote(symbol: symbol, price: price, previousClose: previousClose)
    }

    // MARK: Candle history (for indicators / the advisor)

    /// Fetch ~1 year of daily OHLC bars for one symbol — enough for the 200-day
    /// trend and every indicator. `nil` on failure / when external access is off.
    static func fetchHistory(_ symbol: String, range: String = "1y", interval: String = "1d") async -> StockSagePriceHistory? {
        guard ToolPolicy.isExternalAllowed else { return nil }
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?range=\(range)&interval=\(interval)") else { return nil }
        var req = URLRequest(url: url)
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return parseHistory(data, symbol: symbol)
    }

    /// Fetch candle histories for many symbols concurrently (bounded fan-out),
    /// keyed by uppercased requested symbol. `[:]` when external access is off.
    static func fetchHistories(for symbols: [String], range: String = "1y", concurrency: Int = 6) async -> [String: StockSagePriceHistory] {
        guard ToolPolicy.isExternalAllowed, !symbols.isEmpty else { return [:] }
        var out: [String: StockSagePriceHistory] = [:]
        let chunks = stride(from: 0, to: symbols.count, by: max(1, concurrency)).map {
            Array(symbols[$0 ..< min($0 + concurrency, symbols.count)])
        }
        for chunk in chunks {
            let results: [StockSagePriceHistory] = await withTaskGroup(of: StockSagePriceHistory?.self) { group in
                for symbol in chunk { group.addTask { await fetchHistory(symbol, range: range) } }
                var acc: [StockSagePriceHistory] = []
                for await h in group where h != nil { acc.append(h!) }
                return acc
            }
            for h in results { out[h.symbol.uppercased()] = h }
        }
        return out
    }

    /// Decode Yahoo `v8/chart` time-series JSON into a candle history. Yahoo emits
    /// `null` for non-trading gaps; those bars are dropped so the parallel arrays
    /// stay aligned and indicator math never meets a NaN. Newest bar LAST.
    static func parseHistory(_ data: Data, symbol: String) -> StockSagePriceHistory? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = root["chart"] as? [String: Any],
              let result = (chart["result"] as? [[String: Any]])?.first,
              let timestamps = result["timestamp"] as? [Any],
              let indicators = result["indicators"] as? [String: Any],
              let quote = (indicators["quote"] as? [[String: Any]])?.first,
              let opens = quote["open"] as? [Any],
              let highs = quote["high"] as? [Any],
              let lows = quote["low"] as? [Any],
              let closes = quote["close"] as? [Any] else { return nil }
        let volumes = (quote["volume"] as? [Any]) ?? []
        let n = timestamps.count
        guard n > 0, opens.count == n, highs.count == n, lows.count == n, closes.count == n else { return nil }

        var dt: [Date] = [], o: [Double] = [], h: [Double] = [], l: [Double] = [], c: [Double] = [], v: [Double] = []
        for i in 0..<n {
            guard let ts = number(timestamps[i]),
                  let oo = number(opens[i]), let hh = number(highs[i]),
                  let ll = number(lows[i]), let cc = number(closes[i]) else { continue }
            dt.append(Date(timeIntervalSince1970: ts))
            o.append(oo); h.append(hh); l.append(ll); c.append(cc)
            v.append(i < volumes.count ? (number(volumes[i]) ?? 0) : 0)
        }
        guard c.count >= 2 else { return nil }
        return StockSagePriceHistory(symbol: symbol, dates: dt, opens: o, highs: h, lows: l, closes: c, volumes: v)
    }

    /// Coax a JSON numeric (Double / Int / NSNumber / numeric String) into a
    /// Double — `JSONSerialization` hands numbers back as `NSNumber`, and a few
    /// fields occasionally arrive as strings.
    private static func number(_ any: Any?) -> Double? {
        let value: Double?
        switch any {
        case let d as Double:   value = d
        case let i as Int:      value = Double(i)
        case let n as NSNumber: value = n.doubleValue
        case let s as String:   value = Double(s)
        default:                value = nil
        }
        // Reject NaN / ±Inf so a non-finite field is dropped exactly like a null
        // bar — preserves the "indicator math never meets a NaN" invariant.
        guard let v = value, v.isFinite else { return nil }
        return v
    }
}

// MARK: - StockSagePriceHistory
//
// A daily OHLC candle history for one symbol (newest LAST) — the input the
// indicators + advisor consume. Parallel arrays (kept equal-length by the parser)
// make windows cheap to slice. Sendable so it crosses the fetch → main-actor hop.
struct StockSagePriceHistory: Sendable, Equatable {
    let symbol: String
    let dates: [Date]
    let opens: [Double]
    let highs: [Double]
    let lows: [Double]
    let closes: [Double]
    let volumes: [Double]

    nonisolated var count: Int { closes.count }
    nonisolated var latestClose: Double? { closes.last }
}

// MARK: - StockSageUniverse
//
// The "whole world" default watchlist: blue-chip names + benchmark indices across
// every inhabited continent, in Yahoo symbology. Saudi/Tadawul leads (the owner's
// home market); the rest spans the Americas, Europe, the Middle East, Asia and
// Oceania so the Markets tab is genuinely global out of the box. The `market`
// label (with a flag) is what the watchlist/heatmap show under each ticker, so
// regions stay visually grouped in feed order. Extend freely — every downstream
// layer is symbol-agnostic.
enum StockSageUniverse {
    // (friendly market label, tickers). Explicitly typed so the big literals
    // type-check cheaply (Swift's inference chokes on a bare tuple-array).
    //
    // TWO tiers, deliberately separated for the feed's sake:
    //   • `groups`       — the ANALYZED CORE: history-fetched + live-quoted in bulk
    //                      (board, ideas ranking, heatmap, allocation). Kept to a
    //                      liquid, recognizable set so a manual refresh stays sane.
    //   • `catalogExtra` — DISCOVERY long-tail: searchable + one-tap addable, but NOT
    //                      bulk-fetched. Adding one fetches just that single quote.
    // Together they form `catalog`, the searchable directory behind the add-ticker box —
    // so the owner can find effectively any liquid stock without hammering the feed.

    private static let groups: [(label: String, tickers: [String])] = [
        // ── United States (mega/large cap, by sector) ──
        ("🇺🇸 US Mega-cap Tech",   ["AAPL", "MSFT", "NVDA", "GOOGL", "AMZN", "META", "AVGO", "TSLA", "ORCL", "AMD"]),
        ("🇺🇸 US Semis & Hardware", ["INTC", "QCOM", "TXN", "MU", "AMAT", "ADI", "LRCX", "KLAC", "CSCO", "IBM"]),
        ("🇺🇸 US Software",        ["CRM", "ADBE", "NOW", "INTU", "PANW", "SNPS", "CDNS", "NFLX"]),
        ("🇺🇸 US Financials",      ["JPM", "BAC", "WFC", "GS", "MS", "C", "BLK", "SCHW", "AXP", "V", "MA"]),
        ("🇺🇸 US Health",          ["UNH", "JNJ", "LLY", "PFE", "MRK", "ABBV", "TMO", "ABT", "DHR", "AMGN"]),
        ("🇺🇸 US Consumer",        ["HD", "MCD", "NKE", "SBUX", "COST", "WMT", "PG", "KO", "PEP", "DIS"]),
        ("🇺🇸 US Energy & Industrials", ["XOM", "CVX", "COP", "BA", "CAT", "GE", "HON", "UPS", "RTX", "LMT"]),
        ("📊 ETFs (broad & sector)", ["SPY", "QQQ", "DIA", "IWM", "VTI", "XLK", "XLF", "XLE", "XLV", "GLD", "SLV", "TLT"]),
        // ── International (blue chips by exchange) ──
        ("🇸🇦 Tadawul (TASI)",     ["2222.SR", "1120.SR", "7010.SR", "2010.SR", "1180.SR", "2350.SR"]),
        ("🇬🇧 London (LSE)",       ["SHEL.L", "AZN.L", "HSBA.L", "ULVR.L", "BP.L", "GSK.L"]),
        ("🇩🇪 Frankfurt (XETRA)",  ["SAP.DE", "SIE.DE", "ALV.DE", "BMW.DE"]),
        ("🇫🇷 Paris (Euronext)",   ["MC.PA", "OR.PA", "AIR.PA", "TTE.PA"]),
        ("🇯🇵 Tokyo (TSE)",        ["7203.T", "6758.T", "9984.T", "8306.T"]),
        ("🇭🇰 Hong Kong (HKEX)",   ["0700.HK", "9988.HK", "3690.HK"]),
        ("🇨🇳 Shanghai (SSE)",     ["600519.SS"]),
        ("🇰🇷 Seoul (KRX)",        ["005930.KS", "000660.KS"]),
        ("🇮🇳 Mumbai (NSE)",       ["RELIANCE.NS", "TCS.NS", "INFY.NS", "HDFCBANK.NS"]),
        ("🇹🇼 Taiwan (TWSE)",      ["2330.TW", "2317.TW"]),
        ("🇸🇬 Singapore (SGX)",    ["D05.SI", "O39.SI"]),
        ("🇦🇺 Sydney (ASX)",       ["BHP.AX", "CBA.AX", "CSL.AX"]),
        ("🇧🇷 São Paulo (B3)",     ["PETR4.SA", "VALE3.SA", "ITUB4.SA"]),
        ("🇲🇽 Mexico (BMV)",       ["AMXB.MX", "WALMEX.MX"]),
        ("🇨🇦 Toronto (TSX)",      ["RY.TO", "SHOP.TO", "ENB.TO"]),
        ("🇨🇭 Zurich (SIX)",       ["NESN.SW", "ROG.SW", "NOVN.SW"]),
        ("🇳🇱 Amsterdam (Euronext)", ["ASML.AS", "ADYEN.AS"]),
        ("🇪🇸 Madrid (BME)",       ["SAN.MC", "IBE.MC", "ITX.MC"]),
        ("🇮🇹 Milan (Borsa)",      ["ENI.MI", "ISP.MI", "RACE.MI"]),
        ("🇸🇪 Stockholm (OMX)",    ["VOLV-B.ST", "ERIC-B.ST"]),
        ("🇦🇪 UAE (ADX/DFM)",      ["FAB.AD", "EMAAR.DU"]),
        ("🇶🇦 Qatar (QSE)",        ["QNBK.QA"]),
        ("🇪🇬 Egypt (EGX)",        ["COMI.CA"]),
        ("🇿🇦 Johannesburg (JSE)", ["NPN.JO", "AGL.JO"]),
        ("🌍 World indices",       ["^GSPC", "^IXIC", "^DJI", "^RUT", "^VIX", "^FTSE", "^GDAXI", "^FCHI", "^STOXX50E", "^N225", "^HSI", "^NSEI", "^TWII", "^STI", "^BVSP", "^AXJO", "^GSPTSE", "^TASI.SR"]),
        // Forex (Yahoo `=X` pairs) — trades ~24×5; SAR included for the owner's home currency.
        ("💱 Forex (24×5)",        ["EURUSD=X", "GBPUSD=X", "USDJPY=X", "USDSAR=X", "USDCNY=X", "AUDUSD=X", "USDCAD=X", "USDCHF=X"]),
        // Crypto (Yahoo `-USD`) — trades 24/7 and is far more volatile than equities.
        ("₿ Crypto (24/7)",        ["BTC-USD", "ETH-USD", "SOL-USD", "XRP-USD", "BNB-USD", "ADA-USD", "DOGE-USD", "AVAX-USD", "DOT-USD", "LINK-USD"]),
    ]

    // Discovery long-tail — searchable + addable, NOT bulk-fetched. Real, liquid Yahoo
    // tickers; if one ever fails to price on add, the add box says so honestly.
    private static let catalogExtra: [(label: String, tickers: [String])] = [
        ("🇺🇸 US Tech & Growth",   ["GOOG", "MRVL", "ON", "MCHP", "NXPI", "SNOW", "PLTR", "CRWD", "DDOG", "ZS", "NET", "WDAY", "TEAM", "DELL", "HPQ", "UBER", "ABNB", "COIN", "SQ", "PYPL", "SHOP", "MDB", "DOCU", "ROKU", "PINS"]),
        ("🇺🇸 US Financials+",     ["SPGI", "MCO", "ICE", "CME", "COF", "USB", "PNC", "TFC", "BX", "KKR", "APO", "MET", "PRU", "AIG", "TRV"]),
        ("🇺🇸 US Health+",         ["VRTX", "REGN", "BMY", "GILD", "CVS", "MDT", "ISRG", "ZTS", "SYK", "BDX", "HCA", "CI", "ELV", "BSX", "MRNA"]),
        ("🇺🇸 US Consumer+",       ["LOW", "TGT", "TJX", "BKNG", "PM", "MDLZ", "CL", "EL", "KHC", "GIS", "KMB", "MNST", "YUM", "CMG", "MAR"]),
        ("🇺🇸 US Energy/Industrial+", ["EOG", "SLB", "PSX", "MPC", "VLO", "OXY", "WMB", "KMI", "DE", "MMM", "GD", "NOC", "FDX", "EMR", "ETN", "ITW", "PH"]),
        ("🇺🇸 US Comms/Utility/Materials", ["T", "VZ", "TMUS", "CMCSA", "CHTR", "NEE", "DUK", "SO", "D", "LIN", "SHW", "FCX", "NEM", "APD", "DOW"]),
        ("🇺🇸 US Real Estate",     ["PLD", "AMT", "EQIX", "SPG", "O", "CCI", "PSA", "WELL"]),
        ("📊 ETFs+ (broad/intl/bond)", ["VOO", "VEA", "VWO", "EFA", "EEM", "XLY", "XLP", "XLI", "XLU", "XLB", "XLRE", "XLC", "SMH", "SOXX", "ARKK", "USO", "HYG", "LQD", "VNQ", "SCHD", "DVY", "IEF", "AGG", "BND", "EWJ", "FXI", "EWZ", "INDA"]),
        ("🇬🇧 London+",            ["BARC.L", "LLOY.L", "VOD.L", "RIO.L", "BATS.L", "DGE.L", "NWG.L", "TSCO.L"]),
        ("🇩🇪 Frankfurt+",         ["BAS.DE", "BAYN.DE", "VOW3.DE", "MBG.DE", "DTE.DE", "DBK.DE", "IFX.DE", "ADS.DE"]),
        ("🇫🇷 Paris+",             ["SAN.PA", "BNP.PA", "SU.PA", "AI.PA", "EL.PA", "CS.PA"]),
        ("🇯🇵 Tokyo+",             ["6861.T", "9433.T", "6098.T", "7974.T", "8035.T", "4063.T"]),
        ("🇭🇰 Hong Kong+",         ["0941.HK", "1299.HK", "0005.HK", "0388.HK", "1810.HK"]),
        ("🇨🇳 Shanghai+",          ["601318.SS", "600036.SS", "601888.SS"]),
        ("🇰🇷 Seoul+",             ["005380.KS", "035420.KS"]),
        ("🇮🇳 Mumbai+",            ["ICICIBANK.NS", "BHARTIARTL.NS", "SBIN.NS", "HINDUNILVR.NS"]),
        ("🌏 Asia-Pacific+",       ["2454.TW", "U11.SI", "NAB.AX", "WBC.AX", "WES.AX"]),
        ("🌎 Americas+",           ["BBDC4.SA", "GFNORTEO.MX", "TD.TO", "CNR.TO", "BN.TO"]),
        ("🇪🇺 Europe+",            ["UBSG.SW", "ZURN.SW", "INGA.AS", "PRX.AS", "BBVA.MC", "UCG.MI", "ATCO-A.ST", "INVE-B.ST"]),
        ("💱 Forex+",              ["NZDUSD=X", "EURGBP=X", "EURJPY=X", "GBPJPY=X"]),
        ("₿ Crypto+",              ["MATIC-USD", "LTC-USD", "BCH-USD", "ATOM-USD", "UNI-USD", "ETC-USD", "NEAR-USD", "APT-USD"]),
    ]

    private static func build(_ gs: [(label: String, tickers: [String])]) -> [StockSageSymbol] {
        gs.flatMap { g in g.tickers.map { StockSageSymbol(symbol: $0, market: g.label) } }
    }

    static let worldwide: [StockSageSymbol] = build(groups)

    /// Distinct exchanges/regions covered — surfaced in the live banner ("N markets").
    static let marketCount: Int = groups.count

    /// The full searchable directory: analyzed core + discovery long-tail, deduped
    /// (first occurrence wins, so a core symbol keeps its core market label).
    static let catalog: [StockSageSymbol] = {
        var seen: Set<String> = []
        var out: [StockSageSymbol] = []
        for s in build(groups) + build(catalogExtra) where seen.insert(s.symbol.uppercased()).inserted {
            out.append(s)
        }
        return out
    }()

    /// Case-insensitive catalog search for the add-ticker autocomplete: exact match
    /// first, then prefix, then substring, then a market-label hit. Pure + bounded.
    static func search(_ query: String, limit: Int = 8) -> [StockSageSymbol] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !q.isEmpty else { return [] }
        var scored: [(sym: StockSageSymbol, score: Int)] = []
        for s in catalog {
            let sym = s.symbol.uppercased()
            let score: Int
            if sym == q { score = 0 }
            else if sym.hasPrefix(q) { score = 1 }
            else if sym.contains(q) { score = 2 }
            else if s.market.uppercased().contains(q) { score = 3 }
            else { continue }
            scored.append((s, score))
        }
        return scored
            .sorted { $0.score != $1.score ? $0.score < $1.score : $0.sym.symbol.count < $1.sym.symbol.count }
            .prefix(limit).map(\.sym)
    }
}
