import SwiftUI

/// "What I know about you" — lists the durable facts Salehman AI has saved to
/// long-term memory, with per-fact delete and a clear-all. MemoryStore stays a
/// plain (non-ObservableObject) store, so we load into local state on appear.
struct MemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var facts: [String] = []
    @State private var confirmClear = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.06, green: 0.07, blue: 0.12), Color.black],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            VStack(alignment: .leading, spacing: DS.Space.lg) {
                header

                if facts.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 1) {
                            ForEach(facts, id: \.self) { fact in
                                row(fact)
                            }
                        }
                        .background(DS.Palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
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
            }.buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Space.md) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40)).foregroundStyle(.secondary)
            Text("Nothing remembered yet")
                .font(.headline).foregroundStyle(.white)
            Text("As you chat, Salehman AI saves durable facts about you here — like your name, preferences, and projects.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 320)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ fact: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkle").foregroundStyle(DS.Palette.accent).frame(width: 18)
            Text(fact).font(.system(size: 14)).foregroundStyle(.white)
                .textSelection(.enabled)
            Spacer(minLength: 8)
            Button { MemoryStore.shared.delete(fact); reload() } label: {
                Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Forget this")
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 11)
    }

    private func reload() { facts = MemoryStore.shared.allFacts() }
}
