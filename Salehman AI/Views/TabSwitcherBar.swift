import SwiftUI

/// Frosted segmented tab bar matching the app's dark DS aesthetic. Left: brand
/// logo + name. Center: the tab pills. Right: a live market-status dot.
struct TabSwitcherBar: View {
    @Binding var selection: AppTab
    @ObservedObject private var market = MarketStore.shared

    var body: some View {
        HStack(spacing: DS.Space.md) {
            // Brand
            HStack(spacing: DS.Space.xs) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.icon, style: .continuous)
                        .fill(DS.Gradient.brand).frame(width: 28, height: 28)
                        .shadow(color: DS.Palette.accent.opacity(0.5), radius: 6, y: 2)
                    Image(systemName: "sparkles").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                }
                Text("Salehman AI")
                    .font(DS.Typography.titleM).foregroundStyle(.white)
            }

            Spacer(minLength: DS.Space.md)

            // Pills
            HStack(spacing: 4) {
                ForEach(AppTab.allCases) { tab in pill(tab) }
            }
            .padding(4)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))

            Spacer(minLength: DS.Space.md)

            // Live market status dot
            HStack(spacing: 6) {
                Circle().fill(market.session.isOpen ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(market.session.shortLabel).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(minWidth: 90, alignment: .trailing)
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.sm)
        .background(.ultraThinMaterial)
    }

    private func pill(_ tab: AppTab) -> some View {
        let selected = selection == tab
        return Button {
            withAnimation(DS.Motion.snappy) { selection = tab }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon).font(.system(size: 12, weight: .semibold))
                Text(tab.title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(selected ? .white : .secondary)
            .padding(.horizontal, DS.Space.md).padding(.vertical, 7)
            .background(selected ? AnyShapeStyle(DS.Gradient.brand) : AnyShapeStyle(Color.clear), in: Capsule())
            .shadow(color: selected ? DS.Palette.accent.opacity(0.4) : .clear, radius: 6, y: 2)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
