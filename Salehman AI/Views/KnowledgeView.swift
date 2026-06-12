import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Shown when no on-device model is available. The Knowledge vault promises
/// privacy ("on this Mac"), so its answers go through `LocalLLM.generateOnDevice`
/// — which returns nil rather than falling back to a cloud brain. We say so
/// plainly instead of silently sending the document off-device.
private let onDeviceUnavailableMessage =
    "No on-device model is available right now, so I can't answer privately. Start Ollama (an on-device model) to use Knowledge privately on this Mac."

/// The Knowledge tab — a private, on-device document vault you can chat with. Add
/// files (button or drag-and-drop; extracted on-device by `AttachmentLoader`) or
/// paste text, then ask questions; answers are grounded in retrieved passages
/// with sources. The same vault is reachable from chat via `search_documents`.
struct KnowledgeView: View {
    @State private var docs: [KnowledgeDoc] = []
    @State private var question = ""
    @State private var answer = ""
    @State private var sources: [KnowledgeHit] = []
    @State private var asking = false
    /// Number of ingests in flight. Multiple files can be dropped at once, so a
    /// single Bool would flip "done" when the FIRST finishes; a counter keeps the
    /// spinner/disabled state true until ALL ingests complete.
    @State private var inFlight = 0
    private var ingesting: Bool { inFlight > 0 }
    @State private var dropTargeted = false
    @State private var showPaste = false
    @State private var pasteTitle = ""
    @State private var pasteBody = ""
    @State private var detailDoc: KnowledgeDoc?
    @State private var docSort: KnowledgeSort = .recent
    @State private var docFilter = ""
    @State private var hoveredDocID: UUID?
    /// Pulses briefly after "Save to Notes" to confirm the action.
    @State private var answerSaved = false
    /// Copy-feedback flash for the answer copy button.
    @State private var copiedAnswer = false
    /// Staggered entrance.
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                header
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(DS.Motion.entrance, value: appeared)
                askCard
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(DS.Motion.entrance.delay(0.07), value: appeared)
                documentsSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(DS.Motion.entrance.delay(0.14), value: appeared)
                    .animation(DS.Motion.smooth, value: docs.isEmpty)
            }
            .padding(DS.Space.xl)
            // Centered content column, same as the chat surfaces.
            .frame(maxWidth: 780, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        // Flat opaque working canvas (design language).
        .background(DS.Palette.codeSurface.ignoresSafeArea())
        .onAppear { appeared = true; reload() }
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { handleDrop($0) }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: DS.Radius.modal, style: .continuous)
                    .strokeBorder(DS.Palette.accent, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .background(DS.Palette.accent.opacity(0.08))
                    .overlay(Label("Drop to add to Knowledge", systemImage: "tray.and.arrow.down.fill")
                        .font(.headline).foregroundStyle(.white))
                    .padding(8).allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(DS.Motion.snappy, value: dropTargeted)
        .sheet(isPresented: $showPaste) { pasteSheet }
        .sheet(item: $detailDoc) { doc in DocDetailSheet(doc: doc) { detailDoc = nil } }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: DS.Space.md) {
            // Brand icon tile — matches TodayView / AgentsView header treatment.
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                    .fill(DS.Gradient.brand)
                    .frame(width: 36, height: 36)
                    .dsShadow(DS.Elevation.accentGlow(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                            .stroke(
                                LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.02)],
                                               startPoint: .top, endPoint: .bottom),
                                lineWidth: 0.75
                            )
                    )
                KeyframeAnimator(initialValue: CGFloat(1.0), trigger: appeared) { scale in
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(0.60, duration: 0.07)
                        SpringKeyframe(1.18, spring: .snappy, duration: 0.28)
                        SpringKeyframe(1.0, spring: .bouncy, duration: 0.22)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Knowledge")
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    Eyebrow(text: "Private Vault")
                }
                Text("Chat with your own documents — on this Mac only.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button { showPaste = true } label: { Image(systemName: "doc.on.clipboard") }
                .buttonStyle(.bordered).controlSize(.small).help("Paste text")
                .accessibilityLabel("Paste text").disabled(ingesting)
            Button(action: addFile) {
                HStack(spacing: 6) {
                    Group {
                        if ingesting { ProgressView().controlSize(.small).tint(.white).transition(.opacity) }
                        else { Image(systemName: "plus").transition(.opacity) }
                    }
                    .animation(DS.Motion.smooth, value: ingesting)
                    Text(ingesting ? "Reading…" : "Add file")
                        .contentTransition(.opacity)
                        .animation(DS.Motion.smooth, value: ingesting)
                }
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(DS.Gradient.brand, in: Capsule())
                .shadow(color: DS.Palette.accent.opacity(0.28), radius: 5, y: 2)
            }
            .buttonStyle(LuxPressStyle())
            .disabled(ingesting)
        }
    }

    private var askCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Ask your documents…", text: $question)
                    .textFieldStyle(.plain).font(.system(size: 15))
                    .onSubmit { Task { await ask() } }
                    .onKeyPress(.escape) { question = ""; return .handled }
                    .accessibilityLabel("Ask your documents")
                Button { Task { await ask() } } label: {
                    Group {
                        if asking { ProgressView().controlSize(.small).transition(.opacity) }
                        else { Image(systemName: "arrow.up.circle.fill").font(.system(size: 22)).foregroundStyle(DS.Palette.accent).transition(.opacity) }
                    }
                    .animation(DS.Motion.smooth, value: asking)
                }
                .buttonStyle(.plain).help("Ask your documents").accessibilityLabel("Ask")
                .disabled(asking || question.trimmingCharacters(in: .whitespaces).isEmpty || docs.isEmpty)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: DS.Radius.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.field, style: .continuous).stroke(DS.Palette.surfaceStroke, lineWidth: 1))

            if !answer.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                Text(answer).font(.callout).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                if !sources.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SOURCES").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.6)
                        ForEach(Array(sources.enumerated()), id: \.offset) { i, hit in
                            HStack(alignment: .top, spacing: 8) {
                                Text("[\(i + 1)]").font(.caption.weight(.bold)).foregroundStyle(DS.Palette.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hit.docName).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
                                    Text(hit.text).font(.caption2).foregroundStyle(.secondary).lineLimit(3)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                // Quick actions on the answer — Copy and Save to Notes.
                HStack(spacing: 16) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(answer, forType: .string)
                        copiedAnswer = true
                        Task { try? await Task.sleep(nanoseconds: 1_500_000_000); copiedAnswer = false }
                    } label: {
                        Label(copiedAnswer ? "Copied!" : "Copy",
                              systemImage: copiedAnswer ? "checkmark" : "doc.on.doc")
                            .contentTransition(.symbolEffect(.replace))
                            .animation(DS.Motion.smooth, value: copiedAnswer)
                    }
                    .help("Copy answer to clipboard")
                    .accessibilityLabel("Copy answer")
                    Button {
                        ScratchpadStore.shared.addNote(answer)
                        answerSaved = true
                        Task { try? await Task.sleep(nanoseconds: 1_500_000_000); answerSaved = false }
                    } label: {
                        Label(answerSaved ? "Saved!" : "Save to Notes",
                              systemImage: answerSaved ? "checkmark" : "note.text.badge.plus")
                    }
                    .help("Save answer as a note")
                    .accessibilityLabel("Save answer to Notes")
                    Spacer(minLength: 0)
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                }
                .transition(.opacity.combined(with: .offset(y: 6)))
            } else if docs.isEmpty {
                Text("Add a file above, then ask a question — Salehman answers only from what's in your documents.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(DS.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Bezel treatment — outer shell + inner core with subtle brand tint.
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Bezel.innerRadius, style: .continuous)
                    .fill(!answer.isEmpty
                          ? DS.Palette.accent.opacity(0.05)
                          : DS.Bezel.cardFill)
                RoundedRectangle(cornerRadius: DS.Bezel.innerRadius, style: .continuous)
                    .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
            }
        )
        .padding(DS.Bezel.shellPadding)
        .background(
            RoundedRectangle(cornerRadius: DS.Bezel.outerRadius, style: .continuous)
                .fill(DS.Bezel.shellFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Bezel.outerRadius, style: .continuous)
                .stroke(DS.Bezel.shellStroke, lineWidth: 1)
        )
        .animation(DS.Motion.smooth, value: answer.isEmpty)
    }

    @ViewBuilder private var documentsSection: some View {
        if docs.isEmpty {
            VStack(spacing: 12) {
                ZStack {
                    PhaseAnimator([0.18, 0.28, 0.18]) { opacity in
                        Circle()
                            .fill(DS.Palette.accent.opacity(opacity))
                            .frame(width: 100)
                            .blur(radius: 24)
                    } animation: { opacity in
                        opacity > 0.23
                            ? .spring(duration: 2.2, bounce: 0.06)
                            : .easeOut(duration: 1.8)
                    }
                    Image(systemName: “books.vertical.fill”)
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(DS.Palette.accent.opacity(0.9))
                }
                .padding(.bottom, 4)
                Text(“START YOUR VAULT”)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(DS.Palette.accent)
                Text(“No documents yet”)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text(“Add PDFs, text, or notes. Everything stays on this Mac.”)
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 40)
            .transition(.opacity)
        } else {
            let shown = docSort.apply(docs, filter: docFilter)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(“\(docs.count) document\(docs.count == 1 ? “” : “s”)”).font(.caption).foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(DS.Motion.smooth, value: docs.count)
                    Spacer()
                    if docs.count > 1 {
                        Menu {
                            ForEach(KnowledgeSort.allCases) { s in
                                Button { docSort = s } label: {
                                    Label(s.title, systemImage: docSort == s ? “checkmark” : “”)
                                }
                            }
                        } label: {
                            Label(“Sort: \(docSort.title)”, systemImage: “arrow.up.arrow.down”)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .menuStyle(.borderlessButton).fixedSize().accessibilityLabel(“Sort documents”)
                        .transition(.opacity)
                    }
                }
                .animation(DS.Motion.smooth, value: docs.count > 1)
                if docs.count > 10 {
                    docFilterRow
                        .transition(.opacity)
                }
                if shown.isEmpty {
                    Text(“No documents match “\(docFilter)”.”)
                        .font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 20)
                        .transition(.opacity)
                } else {
                    VStack(spacing: 1) {
                        ForEach(shown) { doc in
                            docRow(doc)
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                        }
                    }
                    .animation(DS.Motion.smooth, value: docs.count)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                                .fill(DS.Bezel.cardFill)
                            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                                .strokeBorder(DS.Bezel.coreInnerHighlight, lineWidth: 0.5)
                        }
                    )
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .stroke(DS.Palette.surfaceStroke, lineWidth: 1))
                    .transition(.opacity)
                }
            }
            .animation(DS.Motion.smooth, value: docs.count > 10)
            .animation(DS.Motion.smooth, value: shown.isEmpty)
            .transition(.opacity)
        }
    }

    private var docFilterRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.secondary)
            TextField("Find a document…", text: $docFilter)
                .textFieldStyle(.plain).font(.system(size: 13))
                .onKeyPress(.escape) { docFilter = ""; return .handled }
                .accessibilityLabel("Find a document")
            if !docFilter.isEmpty {
                Button { docFilter = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).accessibilityLabel("Clear filter")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous).stroke(DS.Palette.surfaceStroke, lineWidth: 1))
        .animation(DS.Motion.magnetic, value: docFilter.isEmpty)
    }

    private func docRow(_ doc: KnowledgeDoc) -> some View {
        let hovered = hoveredDocID == doc.id
        return HStack(spacing: 12) {
            // Tapping the row opens the detail sheet (on-device summary + info).
            Button { detailDoc = doc } label: {
                HStack(spacing: 12) {
                    // Icon well — consistent with ActionTile / AgentCard pattern.
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(DS.Palette.accent.opacity(hovered ? 0.20 : 0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: doc.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.Palette.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(doc.name)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(hovered ? .white : .white.opacity(0.90))
                            .lineLimit(1)
                        Text("\(doc.kind) · \(doc.chunkCount) passage\(doc.chunkCount == 1 ? "" : "s") · \(ScratchpadList.ageLabel(for: doc.addedAt))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: hovered ? "arrow.up.right" : "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(hovered ? DS.Palette.accent.opacity(0.80) : .secondary)
                        .offset(x: hovered ? 1 : 0, y: hovered ? -1 : 0)
                        .contentTransition(.symbolEffect(.replace))
                        .animation(DS.Motion.smooth, value: hovered)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).help("Open & summarize").accessibilityHint("Open \(doc.name) and summarize it")
            Button { KnowledgeStore.shared.deleteDocument(doc.id); reload() } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(hovered ? DS.Palette.danger.opacity(0.70) : .secondary.opacity(0.50))
            }
            .buttonStyle(.plain).help("Remove").accessibilityLabel("Remove \(doc.name)")
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 10)
        .background(hovered ? DS.Palette.accent.opacity(0.07) : Color.clear)
        .contentShape(Rectangle())
        .onHover { over in
            withAnimation(DS.Motion.magnetic) {
                if over { hoveredDocID = doc.id }
                else if hoveredDocID == doc.id { hoveredDocID = nil }
            }
        }
    }

    // MARK: Actions

    private func reload() { docs = KnowledgeStore.shared.allDocuments() }

    private func addFile() {
        guard let url = AttachmentLoader.pickFile() else { return }
        ingest(url)
    }

    private func ingest(_ url: URL) {
        inFlight += 1
        Task {
            let att = await AttachmentLoader.load(url: url)
            let (n, k, ic, txt) = (att.name, att.kind, att.icon, att.extractedText)
            // Embedding is CPU-heavy → run off the main actor.
            await Task.detached { KnowledgeStore.shared.addDocument(name: n, kind: k, icon: ic, fullText: txt) }.value
            inFlight -= 1
            reload()
        }
    }

    /// Drag-and-drop: ingest each dropped file URL.
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for p in providers where p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            handled = true
            p.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in self.ingest(url) }
            }
        }
        return handled
    }

    private func addPastedText() {
        let body = pasteBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        let title = pasteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = title.isEmpty ? "Pasted note" : title
        inFlight += 1
        showPaste = false
        Task {
            await Task.detached { KnowledgeStore.shared.addDocument(name: name, kind: "Text", icon: "doc.text", fullText: body) }.value
            pasteTitle = ""; pasteBody = ""; inFlight -= 1
            reload()
        }
    }

    private var pasteSheet: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            Text("Paste text").font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(.white)
            TextField("Title (optional)", text: $pasteTitle)
                .textFieldStyle(.plain).padding(8)
                .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
            TextEditor(text: $pasteBody)
                .font(.system(size: 13)).scrollContentBackground(.hidden)
                .padding(6).frame(height: 220)
                .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous).stroke(DS.Palette.surfaceStroke, lineWidth: 1))
            HStack {
                Spacer()
                Button("Cancel") { showPaste = false }.buttonStyle(.plain).foregroundStyle(.secondary)
                Button(action: addPastedText) {
                    Text("Add to Knowledge")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(DS.Palette.accent, in: Capsule())
                        .shadow(color: DS.Palette.accent.opacity(0.25), radius: 4, y: 1)
                }
                .buttonStyle(LuxPressStyle())
                .disabled(pasteBody.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DS.Space.xl)
        .frame(width: 460, height: 380)
        .background(DS.Palette.bgTop)
    }

    // (DocDetailSheet defined below the view.)

    private func ask() async {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        asking = true; answer = ""; sources = []
        let hits = await Task.detached { KnowledgeStore.shared.search(query: q, k: 5) }.value
        sources = hits
        guard !hits.isEmpty else {
            answer = "I couldn't find anything about that in your documents."
            asking = false
            return
        }
        let context = hits.enumerated().map { "[\($0 + 1)] (\($1.docName)) \($1.text)" }.joined(separator: "\n\n")
        let prompt = """
        Answer the question using ONLY the sources below. Cite sources inline as [n]. \
        If the answer isn't in them, say it's not in the documents — don't guess.

        SOURCES:
        \(context)

        QUESTION: \(q)
        """
        answer = await LocalLLM.generateOnDevice(prompt, maxTokens: 500) ?? onDeviceUnavailableMessage
        asking = false
    }
}

/// Document ordering for the Knowledge list (Chat C feature). Pure `apply` → tested.
enum KnowledgeSort: String, CaseIterable, Identifiable {
    case recent, name, passages
    var id: String { rawValue }
    var title: String {
        switch self {
        case .recent:   return "Recent"
        case .name:     return "Name (A–Z)"
        case .passages: return "Most passages"
        }
    }
    func apply(_ docs: [KnowledgeDoc], filter q: String = "") -> [KnowledgeDoc] {
        let needle = q.trimmingCharacters(in: .whitespaces).lowercased()
        let matched = needle.isEmpty ? docs : docs.filter { $0.name.lowercased().contains(needle) }
        switch self {
        case .recent:   return matched.sorted { $0.addedAt > $1.addedAt }
        case .name:     return matched.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .passages: return matched.sorted { $0.chunkCount > $1.chunkCount }
        }
    }
}

/// Per-document detail: generates a faithful on-device summary when opened.
/// Text retrieval + generation both run off the main actor so the sheet stays
/// responsive while the local model works.
private struct DocDetailSheet: View {
    let doc: KnowledgeDoc
    let onClose: () -> Void
    @State private var summary = ""
    @State private var loading = true
    @State private var question = ""
    @State private var answer = ""
    @State private var asking = false
    @State private var answerSaved = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack(spacing: 10) {
                Image(systemName: doc.icon).font(.system(size: 18)).foregroundStyle(DS.Palette.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(doc.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
                    Text("\(doc.kind) · \(doc.chunkCount) passage\(doc.chunkCount == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundStyle(.secondary) }
                    .buttonStyle(.plain).accessibilityLabel("Close")
            }
            Divider().overlay(DS.Palette.hairline)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.md) {
                    Text("ON-DEVICE SUMMARY").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.6)
                    if loading {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Summarizing on-device…").font(.callout).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                    } else {
                        Text(summary).font(.callout).foregroundStyle(.white)
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity)
                    }

                    if !answer.isEmpty {
                        Divider().overlay(DS.Palette.hairline)
                        Text("ANSWER").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.6)
                        Text(answer).font(.callout).foregroundStyle(.white)
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 16) {
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(answer, forType: .string)
                            } label: { Label("Copy", systemImage: "doc.on.doc") }
                            .help("Copy answer to clipboard").accessibilityLabel("Copy answer")
                            Button {
                                ScratchpadStore.shared.addNote(answer)
                                answerSaved = true
                                Task { try? await Task.sleep(nanoseconds: 1_500_000_000); answerSaved = false }
                            } label: {
                                Label(answerSaved ? "Saved!" : "Save to Notes",
                                      systemImage: answerSaved ? "checkmark" : "note.text.badge.plus")
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .animation(DS.Motion.smooth, value: answerSaved)
                            .help("Save answer as a note").accessibilityLabel("Save answer to Notes")
                            Spacer(minLength: 0)
                        }
                        .font(.caption).buttonStyle(.plain).foregroundStyle(.secondary).padding(.top, 2)
                    }
                }
                .animation(DS.Motion.smooth, value: loading)
                .animation(DS.Motion.smooth, value: answer.isEmpty)
            }

            // Ask scoped to THIS document only.
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Ask about this document…", text: $question)
                    .textFieldStyle(.plain).font(.system(size: 14))
                    .onSubmit { Task { await ask() } }
                    .onKeyPress(.escape) { question = ""; return .handled }
                Button { Task { await ask() } } label: {
                    Group {
                        if asking { ProgressView().controlSize(.small) }
                        else { Image(systemName: "arrow.up.circle.fill").font(.system(size: 20)).foregroundStyle(DS.Palette.accent) }
                    }
                    .transition(.opacity)
                }
                .buttonStyle(.plain).accessibilityLabel("Ask about this document")
                .animation(DS.Motion.smooth, value: asking)
                .disabled(asking || question.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: DS.Radius.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.field, style: .continuous).stroke(DS.Palette.surfaceStroke, lineWidth: 1))
        }
        .padding(DS.Space.xl)
        .frame(width: 520, height: 540)
        .background(DS.Palette.bgTop)
        .task { await summarize() }
    }

    private func summarize() async {
        let id = doc.id
        let text = await Task.detached { KnowledgeStore.shared.text(forDocument: id) }.value
        guard !text.isEmpty else {
            summary = "This document has no extractable text to summarize."
            loading = false
            return
        }
        let prompt = """
        Summarize the following document in 4–6 sentences, capturing its key points. \
        Be faithful to the text and do not invent details not present in it.

        DOCUMENT:
        \(text)
        """
        summary = await LocalLLM.generateOnDevice(prompt, maxTokens: 400) ?? onDeviceUnavailableMessage
        loading = false
    }

    private func ask() async {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        asking = true; answer = ""
        let id = doc.id
        let hits = await Task.detached { KnowledgeStore.shared.search(query: q, k: 4, inDocument: id) }.value
        guard !hits.isEmpty else {
            answer = "That doesn't appear to be covered in this document."
            asking = false
            return
        }
        let context = hits.enumerated().map { "[\($0 + 1)] \($1.text)" }.joined(separator: "\n\n")
        let prompt = """
        Answer the question using ONLY the passages below, taken from "\(doc.name)". \
        If the answer isn't in them, say it's not in this document — don't guess.

        PASSAGES:
        \(context)

        QUESTION: \(q)
        """
        answer = await LocalLLM.generateOnDevice(prompt, maxTokens: 400) ?? onDeviceUnavailableMessage
        asking = false
    }
}
