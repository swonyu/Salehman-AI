import SwiftUI

// MARK: - Risk & Allocation section
//
// Extracted (collision-safe, new file only) from MarketsView's three
// risk/allocation panels — `riskParityPanel`, `allocationPanel`,
// `correlationHeatmapPanel` — into one standalone `View`. This is a PURE UI
// presentation: it changes no engine, sizing, or logic. Every number is read
// from the same shared stores (`StockSageStore.shared`, `StockSagePortfolio.shared`)
// and the same pure `StockSage*` helpers the original panels used, so it shows
// only real, already-computed data — no fabricated values.
//
// The MarketsView-private helpers the originals leaned on (`currentPrice`,
// `holdingValue`, `fxRatesToUSD`) are recreated here verbatim so the section is
// self-contained; the private `parityRow` / `allocationGroup` row builders are
// recreated as private members of this struct. Honesty surfaces (the "assumed",
// caveat, and concentration-warning strings) are preserved verbatim.
//
// All three panels stand alone: every type and symbol they reference
// (RiskParityTarget, AllocationBreakdown.Slice, CorrelationMatrix,
// CorrelationCluster, StockSageRiskParity / Rebalance / Allocation / Sector /
// Currency / CorrelationCluster / Glossary, LuxPressStyle, and the DS.* tokens)
// is internal (non-private) and reachable from a file outside MarketsView.
//
// Wiring this into MarketsView is intentionally deferred to the file's owner
// (avoids clobbering the agents editing MarketsView.swift) — this struct is
// ready to drop in.
struct MarketsRiskAllocationSection: View {

    @ObservedObject var store: StockSageStore = .shared
    @ObservedObject var portfolio: StockSagePortfolio = .shared

    // Dynamic-Type-aware small fonts — mirror MarketsView's so the dense heatmap
    // layout is byte-identical at the default text size but still scales up.
    @ScaledMetric(relativeTo: .caption2) private var mvFont7: CGFloat = 7
    @ScaledMetric(relativeTo: .caption2) private var mvFont8: CGFloat = 8
    @ScaledMetric(relativeTo: .caption2) private var mvFont9: CGFloat = 9

    // Tasteful, non-data-bearing hover lift — the only added behavior. Pure polish.
    @State private var hoverParity = false
    @State private var hoverAlloc = false
    @State private var hoverCorr = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            riskParityPanel
            allocationPanel
            correlationHeatmapPanel
        }
    }

    // MARK: - Recreated MarketsView helpers (pure presentation derivation)

    /// Latest traded price for a symbol from the shared store (case-insensitive).
    private func currentPrice(_ symbol: String) -> Double? {
        store.symbols.first { $0.symbol.uppercased() == symbol.uppercased() }?.latest?.price
    }

    /// THE one true holding value: per-share price × shares with the symbol's quote
    /// unit applied (London .L trades in PENCE — raw price×shares is ~100× the real £).
    private func holdingValue(_ symbol: String, perShare: Double, shares: Double) -> Double {
        StockSageCurrency.majorUnitValue(symbol: symbol, rawValue: perShare * shares)
    }

    /// CCY→USD rates for every currency held (direct CCYUSD=X, else inverse 1/USDCCY=X; USD = 1).
    private var fxRatesToUSD: [String: Double] {
        var rates: [String: Double] = ["USD": 1]
        for ccy in Set(portfolio.positions.map { StockSageCurrency.currencyForSymbol($0.symbol) }) where ccy != "USD" {
            if let r = currentPrice("\(ccy)USD=X"), r > 0 { rates[ccy] = r }
            else if let inv = currentPrice("USD\(ccy)=X"), inv > 0 { rates[ccy] = 1 / inv }
        }
        return rates
    }

    /// Shared machined-card chrome (DS tokens, no hardcoded colors) + a tasteful
    /// hover lift. Factors the three panels' identical background/overlay so the
    /// polish is consistent and centralized.
    private func cardChrome(hovering: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).fill(DS.Bezel.cardFill)
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
        }
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .stroke(hovering ? DS.Palette.accent.opacity(0.35) : DS.Palette.surfaceStroke,
                    lineWidth: 1))
        .shadow(color: DS.Elevation.shadow1.color.opacity(hovering ? 1 : 0),
                radius: DS.Elevation.shadow1.radius, y: DS.Elevation.shadow1.y)
    }

    /// Shared panel header: accent icon + title + subtitle. Faithful to the
    /// per-panel HStacks, centralized so spacing/typography stay identical.
    private func panelHeader(icon: String, title: String, subtitle: String,
                             help: String? = nil) -> some View {
        HStack(spacing: DS.Space.md) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(DS.Palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DS.Typography.titleM).foregroundStyle(.white).help(help ?? "")
                Text(subtitle)
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Risk parity

    private var riskParityPanel: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.md) {
                Image(systemName: "scalemass.fill").font(.system(size: 16)).foregroundStyle(DS.Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Risk-parity weights").font(DS.Typography.titleM).foregroundStyle(.white)
                    Text("Size each holding by 1 ÷ volatility so they contribute equal risk.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button { Task { await store.refreshRiskParity() } } label: {
                    HStack(spacing: 6) {
                        Group {
                            if store.isComputingParity { ProgressView().controlSize(.small).tint(.white) }
                            else { Image(systemName: "scalemass").font(.system(size: 11, weight: .semibold)) }
                        }
                        Text(store.isComputingParity ? "Sizing…" : "Balance by risk")
                            .font(.system(size: 11.5, weight: .semibold)).contentTransition(.opacity)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(DS.Palette.accent, in: Capsule())
                }
                .buttonStyle(LuxPressStyle()).disabled(store.isComputingParity)
            }
            if let err = store.parityError {
                Text(err).font(.caption2).foregroundStyle(DS.Palette.warningSoft)
            }
            if !store.riskParity.isEmpty {
                VStack(spacing: 1) { ForEach(store.riskParity) { parityRow($0) } }
                if let vs = StockSageRiskParity.vsEqualWeight(store.riskParity) {
                    Text(vs.note).font(.caption2).foregroundStyle(DS.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Equalizes risk, not a profit promise. Risk parity can suffer in correlation shocks — keep a cash sleeve.")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

                // Concrete rebalance: the actual $ trades to reach the risk-parity targets,
                // with a 2% no-trade band so you don't churn on tiny drifts.
                // Convert each holding to USD BEFORE the plan (mirrors portfolioTotals) — summing
                // GBP/SAR/JPY at 1:1 skewed the target weights AND mislabeled the trade sizes as "$".
                // Untracked-FX holdings are excluded (no rate to convert), same as the headline total.
                let rebalFX = fxRatesToUSD
                let rebalHoldings = portfolio.positions.compactMap { p -> (symbol: String, value: Double)? in
                    guard let rate = rebalFX[StockSageCurrency.currencyForSymbol(p.symbol)] else { return nil }
                    return (symbol: p.symbol,
                            value: holdingValue(p.symbol, perShare: currentPrice(p.symbol) ?? p.costBasis, shares: p.shares) * rate)
                }
                let rebalTargets = Dictionary(store.riskParity.map { ($0.symbol, $0.targetWeight) },
                                              uniquingKeysWith: { a, _ in a })
                if let plan = StockSageRebalance.plan(holdings: rebalHoldings, targets: rebalTargets) {
                    if plan.isBalanced {
                        Text("✓ Within 2% of target — no rebalance needed.")
                            .font(.caption2).foregroundStyle(DS.Palette.successSoft)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("To rebalance (≈$ trades, ignores costs/taxes):")
                                .font(.system(size: mvFont9, weight: .semibold)).foregroundStyle(.secondary)
                            ForEach(plan.trades) { t in
                                Text("\(t.action) \(String(format: "$%.0f", abs(t.deltaValue))) of \(t.symbol)  (\(String(format: "%.0f%%→%.0f%%", t.currentWeight * 100, t.targetWeight * 100)))")
                                    .font(.system(size: mvFont9, design: .monospaced))
                                    .foregroundStyle(t.deltaValue > 0 ? DS.Palette.successSoft : DS.Palette.danger)
                            }
                        }
                    }
                }
            }
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardChrome(hovering: hoverParity))
        .onHover { hoverParity = $0 }
        .animation(DS.Motion.smooth, value: hoverParity)
    }

    private func parityRow(_ t: RiskParityTarget) -> some View {
        let up = t.deltaWeight >= 0
        return HStack(spacing: 10) {
            Text(t.symbol).font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white).frame(width: 70, alignment: .leading).lineLimit(1)
            Text(String(format: "vol %.0f%%", t.volatility * 100)).font(.caption2).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(String(format: "%.0f%% → %.0f%%", t.currentWeight * 100, t.targetWeight * 100))
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                .contentTransition(.numericText())
            Text((up ? "+" : "") + String(format: "%.0f%%", t.deltaWeight * 100))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(up ? DS.Palette.successSoft : DS.Palette.danger)
                .frame(width: 46, alignment: .trailing)
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(t.symbol), target \(Int(t.targetWeight * 100)) percent")
    }

    // MARK: - Allocation breakdown

    private var allocationPanel: some View {
        // Convert to USD before the breakdown (mirrors portfolioTotals/rebalance) — summing currencies
        // at 1:1 skews the asset-class / region slice percentages. Untracked-FX holdings are excluded.
        let allocFX = fxRatesToUSD
        let holdings = portfolio.positions.compactMap { p -> (symbol: String, value: Double)? in
            guard let rate = allocFX[StockSageCurrency.currencyForSymbol(p.symbol)] else { return nil }
            return (symbol: p.symbol,
                    value: holdingValue(p.symbol, perShare: currentPrice(p.symbol) ?? p.costBasis, shares: p.shares) * rate)
        }
        let alloc = StockSageAllocation.breakdown(holdings)
        return VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.md) {
                Image(systemName: "chart.bar.doc.horizontal.fill").font(.system(size: 16)).foregroundStyle(DS.Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Allocation").font(DS.Typography.titleM).foregroundStyle(.white)
                    Text("Where the money sits — by asset class, region and sector.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            allocationGroup("By asset class", alloc.byClass)
            allocationGroup("By region", alloc.byRegion)
            allocationGroup("By sector", StockSageAllocation.slices(holdings, by: StockSageSector.sector))
            if alloc.topClassConcentration > 0.6 {
                Text("⚠︎ \(Int(alloc.topClassConcentration * 100))% in one asset class — concentrated.")
                    .font(.caption2).foregroundStyle(DS.Palette.warningSoft)
            }

            // Currency exposure — only worth showing when there's an actual FX dimension.
            let ccyHoldings = portfolio.positions.map { pos -> (value: Double, currency: String) in
                let raw = (currentPrice(pos.symbol) ?? pos.costBasis) * pos.shares
                // London .L is quoted in pence — normalize to pounds so GBP isn't inflated ~100×.
                return (value: StockSageCurrency.majorUnitValue(symbol: pos.symbol, rawValue: raw),
                        currency: StockSageCurrency.currencyForSymbol(pos.symbol))
            }
            let fxRates: [String: Double] = Dictionary(uniqueKeysWithValues:
                Set(ccyHoldings.map(\.currency)).subtracting(["USD"]).compactMap { ccy -> (String, Double)? in
                    // Prefer the direct CCYUSD=X rate; fall back to the inverse USDCCY=X (1/rate),
                    // since the tracked FX universe often quotes the USD-leading pair (USDSAR=X, …).
                    if let r = currentPrice("\(ccy)USD=X"), r > 0 { return (ccy, r) }
                    if let inv = currentPrice("USD\(ccy)=X"), inv > 0 { return (ccy, 1.0 / inv) }
                    return nil
                })
            if let cb = StockSageCurrency.breakdown(holdings: ccyHoldings, ratesToBase: fxRates, base: "USD"),
               cb.exposures.count > 1 || !cb.unpriced.isEmpty {
                Text("Currency exposure (base USD)").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                ForEach(cb.exposures) { e in
                    HStack(spacing: 8) {
                        Text(e.currency).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white).frame(width: 46, alignment: .leading)
                        Text(String(format: "%.0f%%", e.weight * 100)).font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text(e.baseValue.formatted(.number.precision(.fractionLength(0)))).font(.caption2).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(e.currency): \(Int(e.weight * 100)) percent of the priced book")
                }
                if let c = cb.concentration {
                    Text("⚠︎ \(Int(c.weight * 100))% in \(c.currency) — FX risk (currency moves swing your USD value).")
                        .font(.caption2).foregroundStyle(DS.Palette.warningSoft).fixedSize(horizontal: false, vertical: true)
                }
                if !cb.unpriced.isEmpty {
                    Text("Unpriced (track \(cb.unpriced.first ?? "")USD=X to convert): \(cb.unpriced.joined(separator: ", ")) — excluded from the split.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Text("Local prices assumed in each market's currency (London .L in pence may distort). Rates are snapshots; FX moves are real, un-modeled risk.")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardChrome(hovering: hoverAlloc))
        .onHover { hoverAlloc = $0 }
        .animation(DS.Motion.smooth, value: hoverAlloc)
    }

    private func allocationGroup(_ title: String, _ slices: [AllocationBreakdown.Slice]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            ForEach(slices) { s in
                HStack(spacing: 8) {
                    Text(s.label).font(.system(size: 11)).foregroundStyle(.white)
                        .frame(width: 92, alignment: .leading).lineLimit(1)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08)).frame(height: 6)
                            Capsule().fill(DS.Palette.accent)
                                .frame(width: max(4, geo.size.width * s.fraction), height: 6)
                        }
                    }
                    .frame(height: 6)
                    Text(String(format: "%.0f%%", s.fraction * 100))
                        .font(.caption2).foregroundStyle(.secondary).frame(width: 36, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(s.label) \(Int(s.fraction * 100)) percent")
            }
        }
    }

    // MARK: - Correlation heatmap

    @ViewBuilder private var correlationHeatmapPanel: some View {
        if let c = store.correlation, c.symbols.count >= 2 {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack(spacing: DS.Space.md) {
                    Image(systemName: "square.grid.3x3.fill").font(.system(size: 16)).foregroundStyle(DS.Palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Correlation heatmap").font(DS.Typography.titleM).foregroundStyle(.white)
                            .help(StockSageGlossary.heatmapHelp)
                        Text("Green = independent · red = moves together (concentration risk).")
                            .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(c.symbols.indices, id: \.self) { i in
                            HStack(spacing: 2) {
                                Text(String(c.symbols[i].prefix(6)))
                                    .font(.system(size: mvFont8, weight: .semibold)).foregroundStyle(.secondary)
                                    .frame(width: 46, alignment: .leading).lineLimit(1)
                                ForEach(c.symbols.indices, id: \.self) { j in
                                    let v = c.matrix[i][j]
                                    Rectangle().fill(correlationColor(v))
                                        .frame(width: 26, height: 18)
                                        .overlay(Text(String(format: "%.1f", v))
                                            .font(.system(size: mvFont7, weight: .bold)).foregroundStyle(.white.opacity(0.92)))
                                        .accessibilityElement(children: .ignore)
                                        .accessibilityLabel("\(c.symbols[i]) vs \(c.symbols[j]), correlation \(String(format: "%.1f", v))")
                                }
                            }
                        }
                    }
                }
                if let cluster = StockSageCorrelationCluster.largest(c) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "link").font(.system(size: 11)).foregroundStyle(DS.Palette.danger)
                        Text(cluster.note).font(.caption2).foregroundStyle(DS.Palette.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text("Pairwise daily-return correlation over the overlapping window — lower (greener) off-diagonal = better diversified.")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(DS.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardChrome(hovering: hoverCorr))
            .onHover { hoverCorr = $0 }
            .animation(DS.Motion.smooth, value: hoverCorr)
        }
    }

    /// ≤0 (green, independent/hedged) → +1 (red, moves together / concentration).
    /// A correlation of ~0 IS the diversified case, so it must read green, not red.
    private func correlationColor(_ v: Double) -> Color {
        if v > 0 { return DS.Palette.danger.opacity(0.22 + min(v, 1) * 0.55) }
        return DS.Palette.successSoft.opacity(0.22 + min(-v, 1) * 0.55)
    }
}

#if DEBUG
#Preview("Risk & Allocation section") {
    MarketsRiskAllocationSection()
        .padding(DS.Space.lg)
        .frame(width: 480)
        .background(DS.Gradient.bg)
}
#endif
