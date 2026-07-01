import SwiftUI

// MARK: - Browse all markets
//
// The discovery surface over the full `StockSageUniverse.catalog` (analyzed core +
// long-tail). Sectioned by market group, searchable, asset-class filterable, with
// one-tap add. The add path lazily fetches a SINGLE quote (store.addSymbol) — so the
// directory scales independently of the bulk history feed: browsing costs nothing,
// only an explicit add touches the network. Honest: catalog symbols are searchable-but-
// not-scanned until you add them to your watchlist.

struct BrowseMarketsView: View {
    @ObservedObject var store: StockSageStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var asset: AssetFilter = .all

    enum AssetFilter: String, CaseIterable, Identifiable {
        case all = "All", stocks = "Stocks", etf = "ETFs", crypto = "Crypto", fx = "Forex", index = "Indices"
        var id: String { rawValue }
    }

    private var tracked: Set<String> { Set(store.symbols.map { $0.symbol.uppercased() }) }

    private func matches(_ s: StockSageSymbol) -> Bool {
        let sym = s.symbol.uppercased()
        switch asset {
        case .all:    return true
        case .crypto: return sym.hasSuffix("-USD")
        case .fx:     return sym.hasSuffix("=X")
        case .index:  return sym.hasPrefix("^")
        case .etf:    return s.market.localizedCaseInsensitiveContains("ETF")
        case .stocks: return !sym.hasSuffix("-USD") && !sym.hasSuffix("=X") && !sym.hasPrefix("^")
                          && !s.market.localizedCaseInsensitiveContains("ETF")
        }
    }

    private var sections: [(market: String, rows: [StockSageSymbol])] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let base = q.isEmpty ? StockSageUniverse.catalog : StockSageUniverse.search(q, limit: 500)
        let filtered = base.filter(matches)
        return Dictionary(grouping: filtered, by: { $0.market })
            .map { (market: $0.key, rows: $0.value.sorted { $0.symbol < $1.symbol }) }
            .sorted { $0.market < $1.market }
    }

    var body: some View {
        VStack(spacing: DS.Space.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Browse markets").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    Text("\(StockSageUniverse.catalog.count) instruments · tap + to track (fetches one live quote)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.plain).foregroundStyle(DS.Palette.accent)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Search symbol or market…", text: $query)
                    .textFieldStyle(.plain).font(.system(size: 13))
                    .accessibilityLabel("Search markets")
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))

            Picker("Asset class", selection: $asset) {
                ForEach(AssetFilter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()

            if let err = store.addSymbolError {
                Text(err).font(.caption2).foregroundStyle(DS.Palette.warningSoft).fixedSize(horizontal: false, vertical: true)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2, pinnedViews: [.sectionHeaders]) {
                    ForEach(sections, id: \.market) { section in
                        Section {
                            ForEach(section.rows) { row(_for: $0) }
                        } header: {
                            Text(section.market).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 3).padding(.horizontal, 4)
                                .background(.ultraThinMaterial)
                        }
                    }
                    if sections.isEmpty {
                        Text("No matches.").font(.caption).foregroundStyle(.secondary).padding()
                    }
                }
            }
        }
        .padding(DS.Space.md)
        .frame(minWidth: 420, minHeight: 520)
        .background(DS.Palette.surface)
    }

    @ViewBuilder private func row(_for s: StockSageSymbol) -> some View {
        let isTracked = tracked.contains(s.symbol.uppercased())
        HStack(spacing: 10) {
            Text(s.symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 96, alignment: .leading).lineLimit(1)
            Text(s.market).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 4)
            if isTracked {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundStyle(DS.Palette.successSoft)
                    .accessibilityLabel("\(s.symbol) already tracked")
            } else if store.isAddingSymbol {
                ProgressView().controlSize(.small)
            } else {
                Button { Task { await store.addSymbol(s.symbol) } } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 15)).foregroundStyle(DS.Palette.accent)
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("Add \(s.symbol), \(s.market)")
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 6)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
    }
}
