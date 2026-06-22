import SwiftUI

/// The **RuneScape** tab (⌘8) — live Old School RuneScape Grand Exchange prices.
/// A curated "blue-chip" watchlist (Twisted bow, bonds, runes, logs…) joined with
/// the community real-time feed (`RuneScapeMarketService`), plus name search over
/// the full ~4k-item mapping. Data is honestly flagged: community-run, not
/// official, and educational only.
struct RuneScapeMarketView: View {
    @ObservedObject private var store = RuneScapeStore.shared
    @State private var query = ""
    @State private var hoveredID: Int?
    /// Pre-set under `--qa` so the offscreen snapshot captures the settled layout.
    @State private var appeared = ProcessInfo.processInfo.arguments.contains("--qa")
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Dynamic-Type-aware small fonts (base size at default, scale up when enlarged).
    @ScaledMetric(relativeTo: .caption2) private var rsFont8: CGFloat = 8
    @ScaledMetric(relativeTo: .caption2) private var rsFont9: CGFloat = 9
    /// Gp budget for the "with N gp, flip these" optimizer (persisted; editable inline).
    @AppStorage("geFlipBudgetGp") private var geBudgetText = "10000000"

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private var rows: [RuneScapeListing] {
        isSearching ? store.searchResults : store.featured
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    header
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10)
                        .animation(DS.Motion.lux, value: appeared)
                    statusBanner
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                        .animation(DS.Motion.lux.delay(0.05), value: appeared)
                    searchField
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                        .animation(DS.Motion.lux.delay(0.08), value: appeared)
                    content
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 6)
                        .animation(DS.Motion.lux.delay(0.12), value: appeared)
                }
                .padding(DS.Space.xl)
                .frame(maxWidth: 780, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            footer
        }
        .background(DS.Palette.codeSurface.ignoresSafeArea())
        .onAppear { appeared = true }
        .task {
            // Auto-pull a live snapshot on open — skipped under the QA harness.
            guard !ProcessInfo.processInfo.arguments.contains("--qa") else { return }
            await store.refresh()
        }
        .onChange(of: query) { _, q in
            if q.trimmingCharacters(in: .whitespaces).isEmpty { store.clearSearch() }
            else { store.search(q) }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: DS.Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                    .fill(DS.Gradient.brand)
                    .frame(width: 36, height: 36)
                    .dsShadow(DS.Elevation.accentGlow(0.35))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                        .stroke(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.02)],
                                               startPoint: .top, endPoint: .bottom), lineWidth: 0.75))
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("RuneScape")
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    Eyebrow(text: "Grand Exchange")
                }
                Text(headerSubtitle)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                    .animation(DS.Motion.smooth, value: headerSubtitle)
            }
            Spacer()
            refreshButton
        }
    }

    private var headerSubtitle: String {
        if let when = store.lastUpdated {
            let items = store.itemCount > 0 ? "\(store.itemCount.formatted()) items · " : ""
            return "Live OSRS prices · \(items)updated \(Self.timeFormatter.string(from: when))"
        }
        return "Live Old School RuneScape item prices · educational, community data"
    }

    private var refreshButton: some View {
        Button { Task { await store.refresh() } } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .rotationEffect(.degrees(store.isLoading ? 360 : 0))
                .animation(store.isLoading
                           ? .linear(duration: 0.9).repeatForever(autoreverses: false)
                           : .default, value: store.isLoading)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.08), in: Circle())
                .overlay(Circle().stroke(
                    LinearGradient(colors: [Color.white.opacity(0.20), Color.white.opacity(0.04)],
                                   startPoint: .top, endPoint: .bottom), lineWidth: 1))
        }
        .buttonStyle(LuxPressStyle())
        .disabled(store.isLoading)
        .help("Refresh Grand Exchange prices")
        .accessibilityLabel("Refresh Grand Exchange prices")
    }

    // MARK: Status banner

    @ViewBuilder private var statusBanner: some View {
        if let err = store.error {
            banner(icon: "exclamationmark.triangle.fill", tint: DS.Palette.warningSoft, text: err)
        } else if store.lastUpdated != nil {
            banner(icon: "dot.radiowaves.left.and.right", tint: DS.Palette.successSoft,
                   text: "Live Grand Exchange prices from prices.runescape.wiki (community-run). Instant-buy / instant-sell, refreshed on demand.")
        } else {
            banner(icon: "info.circle.fill", tint: DS.Palette.warningSoft,
                   text: "Connecting to the live Grand Exchange feed…")
        }
    }

    private func banner(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text)
                .font(.caption).foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, DS.Space.sm)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
            .stroke(LinearGradient(colors: [tint.opacity(0.48), tint.opacity(0.10)],
                                   startPoint: .top, endPoint: .bottom), lineWidth: 1))
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundStyle(.secondary)
            TextField("Search any item (e.g. whip, bond, rune)…", text: $query)
                .textFieldStyle(.plain).font(.system(size: 13))
                .focused($searchFocused)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).help("Clear search").accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.white.opacity(searchFocused ? 0.11 : 0.08),
                    in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
            .stroke(searchFocused
                    ? AnyShapeStyle(LinearGradient(colors: [DS.Palette.accent.opacity(0.55), DS.Palette.accent.opacity(0.15)],
                                                   startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(DS.Palette.surfaceStroke), lineWidth: 1))
        .animation(DS.Motion.lux, value: searchFocused)
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        if rows.isEmpty {
            emptyState
        } else {
            VStack(spacing: DS.Space.md) {
                fastestFlipsStrip
                VStack(spacing: 1) {
                    ForEach(rows) { listingRow($0) }
                }
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).fill(DS.Bezel.cardFill)
                        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
                    }
                )
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
            }
        }
    }

    // Fastest flips — the GE money-velocity strip: top flips by gp/HOUR (margin × buy
    // limit ÷ 4h), not raw margin. An estimate that assumes you fill the buy limit.
    @ViewBuilder private var fastestFlipsStrip: some View {
        // Match the RuneLite plugin's shipped min-margin floor so the two surfaces agree on the same prices.
        let flips = StockSageGEFlip.flips(rows, minMargin: StockSageGEFlip.defaultMinMargin, asOf: Date())
        if flips.count >= 2 {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "hare.fill").font(.system(size: 11)).foregroundStyle(DS.Palette.warningSoft)
                    Text("Fastest flips — gp/hour").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    Spacer()
                }
                ForEach(flips.prefix(3)) { flip in
                    HStack(spacing: 8) {
                        Text(flip.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                            .lineLimit(1).frame(maxWidth: 150, alignment: .leading)
                        Text("≈ \(RSFormat.gp(Int(flip.gpPerHour)))/hr")
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(DS.Palette.successSoft)
                            .opacity(flip.stale ? 0.5 : 1)   // stale leg → may not fill at this gp/hr
                        if flip.stale {
                            Text("⚠︎ stale").font(.system(size: rsFont8, weight: .bold)).foregroundStyle(DS.Palette.warningSoft)
                        }
                        Spacer(minLength: 0)
                        Text("\(RSFormat.gp(flip.profitPerItem))/ea · ×\(flip.buyLimit.formatted())")
                            .font(.system(size: rsFont9)).foregroundStyle(.secondary)
                            .opacity(flip.stale ? 0.5 : 1)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(flip.name), about \(RSFormat.gp(Int(flip.gpPerHour))) per hour, \(RSFormat.gp(flip.profitPerItem)) each"
                        + (flip.stale ? ", stale spread, may not fill at this margin" : ""))
                }
                Text("gp/hour = (margin − GE tax) × buy limit ÷ 4h. An estimate — assumes you fill the limit; real fills depend on volume.")
                    .font(.system(size: rsFont9)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    .help(StockSageGlossary.explain(.gpPerHour))
                if let topROI = StockSageGEFlip.bestFlipsByROI(flips).first {
                    Text("Best ROI/cycle: \(topROI.name) +\(String(format: "%.1f", topROI.roiPct))% on \(RSFormat.gp(topROI.buyPrice))/ea — most capital-efficient for a small bankroll (net of tax; fills are volume-gated).")
                        .font(.system(size: rsFont9)).foregroundStyle(DS.Palette.accent).fixedSize(horizontal: false, vertical: true)
                }

                // Budget-aware: "with N gp, flip these" (greedy by gp/hour within the budget).
                Divider().overlay(DS.Palette.surfaceStroke)
                let validBudget = StockSageInput.positiveInt(geBudgetText)
                let budget = validBudget ?? 0
                let plan = StockSageGEFlip.bestFlipsForBudget(flips, budget: budget)
                HStack(spacing: 6) {
                    Text("With").font(.system(size: rsFont9)).foregroundStyle(.secondary)
                    TextField("gp", text: $geBudgetText)
                        .font(.system(size: rsFont9, design: .monospaced)).foregroundStyle(.white)
                        .textFieldStyle(.plain).frame(width: 90)
                        .accessibilityLabel("Flip budget in gp")
                    Text("gp:").font(.system(size: rsFont9)).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    if !plan.flips.isEmpty {
                        Text("≈ \(RSFormat.gp(Int(plan.totalGpPerHour)))/hr")
                            .font(.system(size: rsFont9, weight: .bold)).foregroundStyle(DS.Palette.successSoft)
                    }
                }
                if !plan.flips.isEmpty {
                    let anyStale = plan.flips.contains { $0.stale }
                    Text("Flip: " + plan.flips.map { "\($0.name) ×\($0.units.formatted())" }.joined(separator: ", ")
                         + " — estimate; assumes you fill what you buy, fills depend on volume."
                         + (anyStale ? " ⚠︎ Some legs are stale — those margins may not actually fill." : ""))
                        .font(.system(size: rsFont9))
                        .foregroundStyle(anyStale ? DS.Palette.warningSoft : .secondary).fixedSize(horizontal: false, vertical: true)
                } else if budget > 0 {
                    Text("Budget too small to fund a full unit of the fastest flips — raise it.")
                        .font(.system(size: rsFont9)).foregroundStyle(DS.Palette.warningSoft).fixedSize(horizontal: false, vertical: true)
                } else if validBudget == nil, !geBudgetText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Enter a whole number of gp (digits only, no decimals).")
                        .font(.system(size: rsFont9)).foregroundStyle(DS.Palette.warningSoft).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(DS.Space.md).frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Palette.warningSoft.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).stroke(DS.Palette.warningSoft.opacity(0.25), lineWidth: 1))
        }
    }

    /// "5m old" / "3h old" / "2d old" for a leg age in seconds.
    private func rsAgeLabel(_ s: TimeInterval) -> String {
        if s < 3600 { return "\(Int(s / 60))m old" }
        if s < 86_400 { return "\(Int(s / 3600))h old" }
        return "\(Int(s / 86_400))d old"
    }

    private func listingRow(_ listing: RuneScapeListing) -> some View {
        let hovered = hoveredID == listing.id
        let price = listing.price
        // A thin item's older leg can be days stale while the spread is shown green — flag + de-emphasize.
        let priceAge = price.oldestLegAge(asOf: Date())
        let stale = price.isStale(asOf: Date())
        return HStack(spacing: DS.Space.md) {
            AsyncImage(url: listing.item.iconURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    Image(systemName: "cube").font(.system(size: 14)).foregroundStyle(.secondary)
                }
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(listing.item.name)
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .lineLimit(1)
                    if listing.item.members {
                        Text("P2P").font(.system(size: rsFont8, weight: .bold)).foregroundStyle(Color(white: 0.12))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(DS.Palette.warningSoft, in: Capsule())
                    }
                }
                if let limit = listing.item.buyLimit {
                    Text("buy limit \(limit.formatted())").font(.caption2).foregroundStyle(.secondary)
                }
                if let buy = price.low, let sell = price.high, let limit = listing.item.buyLimit,
                   let gph = StockSageGEFlip.gpPerHour(buy: buy, sell: sell, buyLimit: limit) {
                    Text("≈ \(RSFormat.gp(Int(gph)))/hr").font(.caption2)
                        .foregroundStyle(DS.Palette.successSoft).opacity(stale ? 0.5 : 1)
                }
                if stale, let age = priceAge {
                    Text("⚠︎ \(rsAgeLabel(age)) — stale; may not fill at this spread")
                        .font(.system(size: rsFont8, weight: .medium)).foregroundStyle(DS.Palette.warningSoft)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)

            // Buy (instant-buy / high) and Sell (instant-sell / low) columns.
            priceColumn("Buy", price.high, color: DS.Palette.successSoft)
            priceColumn("Sell", price.low, color: DS.Palette.danger)

            // Flip margin chip — NET of the 2% GE sell tax, so the edge shown is what you keep.
            if let margin = price.margin, let high = price.high {
                let tax = StockSageGEFlip.sellTax(high)
                let net = margin - tax
                let up = net >= 0
                Text((up ? "+" : "") + RSFormat.gp(net))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(up ? Color(white: 0.06) : .white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(up ? DS.Palette.successSoft : DS.Palette.danger, in: Capsule())
                    .opacity(stale ? 0.45 : 1)   // a stale spread's margin may not actually be fillable
                    .frame(width: 70, alignment: .trailing)
                    .help("NET flip margin after the 2% GE sell tax: raw \(RSFormat.gp(margin)) − tax \(RSFormat.gp(tax)) = \(RSFormat.gp(net)) (tax live since 2025-05-29)" + (stale ? " — STALE leg, may not fill" : ""))
            } else {
                Color.clear.frame(width: 70, height: 1)
            }
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 9)
        .background(hovered ? DS.Palette.accent.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
        .onHover { over in
            withAnimation(DS.Motion.smooth) {
                if over { hoveredID = listing.id }
                else if hoveredID == listing.id { hoveredID = nil }
            }
        }
        .help(listing.item.examine)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(listing.item.name), buy \(price.high.map(RSFormat.gp) ?? "unknown"), sell \(price.low.map(RSFormat.gp) ?? "unknown")"
            + ({ () -> String in
                guard let m = price.margin, let h = price.high else { return "" }
                return ", net margin \(RSFormat.gp(m - StockSageGEFlip.sellTax(h))) after tax"
            }())
            + ({ () -> String in
                guard let b = price.low, let s = price.high, let lim = listing.item.buyLimit,
                      let gph = StockSageGEFlip.gpPerHour(buy: b, sell: s, buyLimit: lim) else { return "" }
                return ", about \(RSFormat.gp(Int(gph))) per hour"
            }())
            // Keep the only-real-data staleness cue in the SCREEN-READER path: .combine + this explicit
            // label otherwise discards the visible "stale; may not fill" Text (the edbc2bf safety signal).
            + (stale ? ", stale: older leg \(priceAge.map(rsAgeLabel) ?? "") old, may not fill at this spread" : ""))
    }

    private func priceColumn(_ label: String, _ value: Int?, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label).font(.system(size: rsFont9, weight: .semibold)).foregroundStyle(.secondary)
            Text(value.map(RSFormat.gp) ?? "—")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(value == nil ? Color.secondary : color)
                .contentTransition(.numericText())
        }
        .frame(width: 64, alignment: .trailing)
        .help(value.map { "\($0.formatted()) gp" } ?? "No recent trade")
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: isSearching ? "magnifyingglass" : "building.columns")
                .font(.system(size: 22, weight: .light)).foregroundStyle(DS.Palette.accent)
                .frame(width: 50, height: 50)
                .background(RadialGradient(colors: [DS.Palette.accent.opacity(0.18), DS.Palette.accent.opacity(0.05)],
                                           center: .center, startRadius: 0, endRadius: 25), in: Circle())
                .overlay(Circle().stroke(LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)],
                                                        startPoint: .top, endPoint: .bottom), lineWidth: 1))
            Text(emptyMessage).font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 28)
    }

    private var emptyMessage: String {
        if store.isLoading { return "Loading the Grand Exchange…" }
        if isSearching {
            // The store only searches at ≥2 chars — say "keep typing" for 1 char
            // rather than the misleading "no items match" (no search ran yet).
            if query.trimmingCharacters(in: .whitespaces).count < 2 { return "Keep typing to search…" }
            return store.itemCount == 0
                ? "Refresh first to load the item list, then search."
                : "No items match “\(query)”."
        }
        return store.error == nil
            ? "Tap refresh to load live Grand Exchange prices."
            : "No prices yet."
    }

    // MARK: Footer

    private var footer: some View {
        Text("Live OSRS Grand Exchange data via prices.runescape.wiki (community-run, ~real-time, unofficial). Informational only — not investment or trading advice. RuneScape is a trademark of Jagex Ltd.")
            .font(.caption2).foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Palette.codeSurfaceSide)
            .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1), alignment: .top)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()
}

// MARK: - GP formatting
//
// RuneScape-style coin formatting: big numbers compact to K/M/B, smaller ones
// show full grouped digits. Pure + nonisolated so it's safe to call from any row.
enum RSFormat {
    static func gp(_ n: Int) -> String {
        let a = abs(n)
        switch a {
        case 1_000_000_000...: return String(format: "%.2fB", Double(n) / 1_000_000_000)
        case 1_000_000...:     return String(format: "%.2fM", Double(n) / 1_000_000)
        case 100_000...:       return String(format: "%.1fK", Double(n) / 1_000)
        default:               return n.formatted()
        }
    }
}
