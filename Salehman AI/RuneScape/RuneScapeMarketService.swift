import Foundation

// MARK: - RuneScapeMarketService
//
// Live Old School RuneScape Grand Exchange feed, via the community real-time
// prices API (`https://prices.runescape.wiki/api/v1/osrs`). Keyless and free —
// safe under the app's never-spend `.auto` rule — but it IS network, so every
// call is gated by `ToolPolicy.isExternalAllowed` (Web Access on + Offline off),
// the same gate the stock feed and web tools honor. The wiki asks API consumers
// to send a descriptive User-Agent; we do.
//
// Two endpoints:
//   * `/mapping` — every item's id → name / examine / buy-limit (static-ish; the
//     store fetches it once and caches).
//   * `/latest`  — current instant-buy (`high`) / instant-sell (`low`) per id.
enum RuneScapeMarketService {
    private static let base = "https://prices.runescape.wiki/api/v1/osrs"
    private static let ua = "Salehman AI (macOS personal markets app; contact salehalayed98@gmail.com)"

    /// Curated "blue-chip" OSRS items — high-interest, liquid GE staples used as
    /// the default watchlist. Names/limits are resolved live from `/mapping`, so
    /// these are just the seed ids (high-value first).
    static let featuredIDs: [Int] = [
        13190, // Old school bond
        20997, // Twisted bow
        22486, // Scythe of vitur
        21003, // Elder maul
        12817, // Elysian spirit shield
        11802, // Armadyl godsword
        13652, // Dragon claws
        11785, // Armadyl crossbow
        11832, // Bandos chestplate
        11834, // Bandos tassets
        4151,  // Abyssal whip
        6585,  // Amulet of fury
        561,   // Nature rune
        565,   // Blood rune
        560,   // Death rune
        1515,  // Yew logs
        1513,  // Magic logs
        385,   // Shark
        2357,  // Gold bar
        453,   // Coal
    ]

    // MARK: Fetch

    /// Latest GE prices keyed by item id. `[:]` when external access is disabled.
    static func fetchLatest() async -> [Int: RuneScapePrice] {
        guard ToolPolicy.isExternalAllowed else { return [:] }
        guard let data = await get("\(base)/latest") else { return [:] }
        return parseLatest(data)
    }

    /// The full item mapping (~4k items). Fetched once, then cached by the store.
    static func fetchMapping() async -> [RuneScapeItem] {
        guard ToolPolicy.isExternalAllowed else { return [] }
        guard let data = await get("\(base)/mapping") else { return [] }
        return parseMapping(data)
    }

    // MARK: Parsing (pure — unit-tested without the network)

    /// Decode `/latest`: `{ "data": { "<id>": { high, highTime, low, lowTime } } }`.
    /// Best-effort/total — unknown shapes yield `[:]`, bad rows are skipped.
    static func parseLatest(_ data: Data) -> [Int: RuneScapePrice] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dict = root["data"] as? [String: Any] else { return [:] }
        var out: [Int: RuneScapePrice] = [:]
        out.reserveCapacity(dict.count)
        for (key, value) in dict {
            guard let id = Int(key), let v = value as? [String: Any] else { continue }
            out[id] = RuneScapePrice(high: intval(v["high"]),
                                     highTime: timeval(v["highTime"]),
                                     low: intval(v["low"]),
                                     lowTime: timeval(v["lowTime"]))
        }
        return out
    }

    /// Decode `/mapping`: an array of item objects. Items without an id+name are
    /// dropped.
    static func parseMapping(_ data: Data) -> [RuneScapeItem] {
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { o in
            guard let id = intval(o["id"]), let name = o["name"] as? String else { return nil }
            return RuneScapeItem(id: id, name: name,
                                 examine: (o["examine"] as? String) ?? "",
                                 members: (o["members"] as? Bool) ?? false,
                                 buyLimit: intval(o["limit"]))
        }
    }

    // MARK: Internals

    private static func get(_ urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url)
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 15
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    /// Coerce a JSON numeric (Int / Double / NSNumber / numeric String) to Int.
    private static func intval(_ any: Any?) -> Int? {
        switch any {
        case let i as Int: return i
        case let d as Double: return Int(d)
        case let n as NSNumber: return n.intValue
        case let s as String: return Int(s)
        default: return nil
        }
    }

    /// Unix-seconds timestamp → Date.
    private static func timeval(_ any: Any?) -> Date? {
        guard let i = intval(any) else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(i))
    }
}
