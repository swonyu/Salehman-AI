import SwiftUI

/// The conversation-history sheet: archived chats (newest activity first),
/// restorable with one click. New chats archive the old conversation instead
/// of erasing it (`ChatStore.archiveCurrent`), so this list is the safety net
/// that makes ⌘N feel free. Design language: flat codeSurface sheet, hairline
/// rows, accent reserved for the one primary action per row.
struct ChatHistoryView: View {
    /// Restores the archive into the live transcript (the view's owner wires
    /// this to `restoreArchive`, which also archives the current conversation
    /// first — nothing is ever lost from this sheet).
    let onRestore: (ChatStore.ArchivedChat) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var archives: [ChatStore.ArchivedChat] = []
    @State private var hoveredRow: URL? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Conversations")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.Palette.accent)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(DS.Palette.codeSurfaceSide)
            .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1),
                     alignment: .bottom)

            if archives.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("No archived conversations yet")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Starting a new chat (⌘N) archives the current one here — nothing gets erased.")
                        .font(.system(size: 11.5)).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(archives) { item in
                            row(item)
                            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                        }
                    }
                }
            }
        }
        .frame(width: 520, height: 560)
        .background(DS.Palette.codeSurface)
        .preferredColorScheme(.dark)
        .onAppear { archives = ChatStore.archives() }
    }

    private func row(_ item: ChatStore.ArchivedChat) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Text("\(item.date.formatted(date: .abbreviated, time: .shortened)) · \(item.messageCount) messages")
                    .font(.system(size: 10.5)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button("Restore") { onRestore(item) }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.Palette.accent)
                .help("Replace the current conversation with this one (the current one is archived first)")
            Button {
                ChatStore.deleteArchive(item.id)
                archives.removeAll { $0.id == item.id }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete this archived conversation")
            .accessibilityLabel("Delete \(item.title)")
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(hoveredRow == item.id ? Color.white.opacity(0.04) : .clear)
        .contentShape(Rectangle())
        .onHover { hoveredRow = $0 ? item.id : (hoveredRow == item.id ? nil : hoveredRow) }
    }
}
