import SwiftUI
import AppKit

/// "What I know about you" — lists the durable facts Salehman AI has saved to
/// long-term memory, with search, per-fact copy/delete, and a clear-all.
/// MemoryStore stays a plain (non-ObservableObject) store, so we load into local
/// state on appear.
struct MemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var facts: [String] = []
    @State private var confirmClear = false
    @State private var query = ""

    /// Facts filtered by the search box (case-insensitive substring).
    private var filtered: [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return q.isEmpty ? facts : facts.filter { $0.lowercased().contains(q) }
    }

    var body: some View {
        ZStack {
            // Route through DS canvas tokens so this sheet inherits any palette
            // swap (was a hardcoded cold-indigo that bypassed the token layer).
            DS.Palette.codeSurface.ignoresSafeArea()   // flat working canvas (design language)

            VStack(alignment: .leading, spacing: DS.Space.lg) {
                header

                if facts.isEmpty {
                    emptyState
                } else {
                    if facts.count > 3 { searchField }

                    let shown = filtered
                    if shown.isEmpty {
                        VStack(spacing: 6) {
                            Spacer()
                            Text("No memories match “\(query)”.")
                                .font(.callout).foregroundStyle(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 1) {
                                ForEach(shown, id: \.self) { fact in
                                    row(fact)
                                }
                            }
                            .background(DS.Palette.codeSurfaceSide, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                                .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
                        }
                    }

                    Button(role: .destructive) { confirmClear = true } label: {
                        Label("Forget everything", systemImage: "trash")
                            .font(.callout.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
            .padding(DS.Space.xl)
        }
        .frame(width: 480, height: 540)
        .preferredColorScheme(.dark)
        .onAppear(perform: reload)
        .confirmationDialog("Forget everything Salehman AI has remembered about you?",
                            isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Forget everything", role: .destructive) {
                MemoryStore.shared.clear(); reload()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("What I know about you")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(facts.count) fact\(facts.count == 1 ? "" : "s") saved on this Mac")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundStyle(.secondary)
            }.buttonStyle(.plain).accessibilityLabel("Close")
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Space.md) {
            Spacer()
            // Halo + tinted glyph — mirrors the chat empty-state's "brand glow"
            // pattern so an empty sheet still feels lived-in, not abandoned.
            ZStack {
                Circle()
                    .fill(DS.Palette.accent.opacity(0.14))
                    .frame(width: 84, height: 84)
                    .blur(radius: 16)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundStyle(DS.Palette.accent.opacity(0.85))
            }
            Text("Nothing remembered yet")
                .font(.headline).foregroundStyle(.white)
            Text("As you chat, Salehman AI saves durable facts about you here — like your name, preferences, and projects.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 320)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search memories…", text: $query)
                .textFieldStyle(.plain).font(.system(size: 14))
                .accessibilityLabel("Search memories")
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 9)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
            .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    private func row(_ fact: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkle").foregroundStyle(DS.Palette.accent).frame(width: 18)
            Text(fact).font(.system(size: 14)).foregroundStyle(.white)
                .textSelection(.enabled)
            Spacer(minLength: 8)
            Button { copy(fact) } label: {
                Image(systemName: "doc.on.doc").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy")
            .accessibilityLabel("Copy memory")
            Button { MemoryStore.shared.delete(fact); reload() } label: {
                Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Forget this")
            .accessibilityLabel("Forget this memory")
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 11)
    }

    private func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    private func reload() { facts = MemoryStore.shared.allFacts() }
}
