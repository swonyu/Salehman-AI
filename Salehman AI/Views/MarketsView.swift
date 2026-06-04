import SwiftUI

/// The Markets tab. Phase 1: a shell with the section switcher and disclaimer.
/// Data, charts, signals, alerts, and the extras land in later phases.
struct MarketsView: View {
    @State private var section: MarketSection = .watchlist

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    header
                    sectionPicker
                    placeholder
                }
                .padding(DS.Space.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            MarketDisclaimerFooter()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Saudi Markets")
                .font(DS.Typography.titleL).foregroundStyle(.white)
            Text("Live Tadawul (TASI) monitoring · educational, not financial advice")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var sectionPicker: some View {
        Picker("", selection: $section) {
            ForEach(MarketSection.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 520)
    }

    private var placeholder: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                Label("Markets engine coming online", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.headline).foregroundStyle(.white)
                Text("This tab will show all ~200 TASI symbols with live quotes, charts, AI buy/hold/sell signals from news + the web, a portfolio tracker, custom alerts, and a daily briefing — with Telegram + Mac notifications.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Sections shown inside the single Markets tab.
enum MarketSection: String, CaseIterable, Identifiable {
    case watchlist, all, heatmap, portfolio, alerts, briefing
    var id: String { rawValue }
    var title: String {
        switch self {
        case .watchlist: return "Watchlist"
        case .all:       return "All"
        case .heatmap:   return "Heatmap"
        case .portfolio: return "Portfolio"
        case .alerts:    return "Alerts"
        case .briefing:  return "Briefing"
        }
    }
}

/// Reusable disclaimer footer (reuses the canonical StockSageMini text).
struct MarketDisclaimerFooter: View {
    var body: some View {
        Text(StockSageMini.disclaimer)
            .font(.caption2).foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1), alignment: .top)
    }
}
