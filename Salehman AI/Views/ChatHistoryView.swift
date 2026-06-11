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
    @State private var query = ""
    /// Staggered row reveal on open (capped at 8 steps so deep lists don't
    /// crawl). Pre-revealed on QA launches — offscreen renders never fire
    /// onAppear, so the chat_history capture would photograph empty rows.
    @State private var revealed = ProcessInfo.processInfo.arguments.contains("--qa")
    /// Archive summaries decode up to 100 JSON files — that work now runs
    /// off-main (it was a visible hitch on sheet-open with a deep history).
    @State private var loaded = false

    /// Title filter — case/diacritic-insensitive substring; blank = everything.
    /// Pure for tests (same pattern as the Knowledge/Agents filters).
    nonisolated static func filtered(_ archives: [ChatStore.ArchivedChat],
                                     query: String) -> [ChatStore.ArchivedChat] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return archives }
        return archives.filter {
            $0.title.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

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

            if !loaded {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if archives.isEmpty {
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
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    TextField("Filter by title…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .accessibilityIdentifier("history.filter")
                }
                .padding(.horizontal, 18).padding(.vertical, 8)
                .background(DS.Palette.codeSurfaceSide.opacity(0.6))
                .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1),
                         alignment: .bottom)

                let shown = Self.filtered(archives, query: query)
                if shown.isEmpty {
                    Text("No conversations match “\(query.trimmingCharacters(in: .whitespaces))”")
                        .font(.system(size: 11.5)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(shown.enumerated()), id: \.element.id) { idx, item in
                                row(item)
                                    // Staggered mask reveal — each row fades up
                                    // 40ms after the one above (lux curve).
                                    .opacity(revealed ? 1 : 0)
                                    .offset(y: revealed ? 0 : 12)
                                    .animation(DS.Motion.lux.delay(Double(min(idx, 8)) * 0.04),
                                               value: revealed)
                                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 520, height: 560)
        .background(DS.Palette.codeSurface)
        .preferredColorScheme(.dark)
        .task {
            archives = await Task.detached(priority: .userInitiated) {
                ChatStore.archives()
            }.value
            loaded = true
            // The reveal flip must land a frame AFTER the rows mount: flipping
            // in the same update as insertion renders them at final values and
            // `.animation(value:)` has no transition to interpolate (self-review
            // catch — the cascade silently never fired when set together).
            try? await Task.sleep(for: .milliseconds(50))
            revealed = true
        }
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
                .buttonStyle(PressableStyle())
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
