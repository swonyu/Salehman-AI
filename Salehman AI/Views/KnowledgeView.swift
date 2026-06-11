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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                header
                askCard
                documentsSection
            }
            .padding(DS.Space.xl)
            // Centered content column, same as the chat surfaces.
            .frame(maxWidth: 780, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        // Flat opaque working canvas (design language).
        .background(DS.Palette.codeSurface.ignoresSafeArea())
        .onAppear(perform: reload)
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { handleDrop($0) }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: DS.Radius.modal, style: .continuous)
                    .strokeBorder(DS.Palette.accent, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .background(DS.Palette.accent.opacity(0.08))
                    .overlay(Label("Drop to add to Knowledge", systemImage: "tray.and.arrow.down.fill")
                        .font(.headline).foregroundStyle(.white))
                    .padding(8).allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $showPaste) { pasteSheet }
        .sheet(item: $detailDoc) { doc in DocDetailSheet(doc: doc) { detailDoc = nil } }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Knowledge").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                Text("Chat with your own documents — private, on this Mac.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button { showPaste = true } label: { Image(systemName: "doc.on.clipboard") }
                .buttonStyle(.bordered).controlSize(.small).help("Paste text")
                .accessibilityLabel("Paste text").disabled(ingesting)
            Button(action: addFile) {
                HStack(spacing: 6) {
                    if ingesting { ProgressView().controlSize(.small) } else { Image(systemName: "plus") }
                    Text(ingesting ? "Reading…" : "Add file")
                }
            }
            .buttonStyle(.borderedProminent).tint(DS.Palette.accent).controlSize(.small)
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
                    .accessibilityLabel("Ask your documents")
                Button { Task { await ask() } } label: {
                    if asking { ProgressView().controlSize(.small) }
                    else { Image(systemName: "arrow.up.circle.fill").font(.system(size: 22)).foregroundStyle(DS.Palette.accent) }
                }
                .buttonStyle(.plain).help("Ask your documents").accessibilityLabel("Ask")
                .disabled(asking || question.trimmingCharacters(in: .whitespaces).isEmpty || docs.isEmpty)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: DS.Radius.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.field, style: .continuous).stroke(DS.Palette.surfaceStroke, lineWidth: 1))

            if !answer.isEmpty {
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
            } else if docs.isEmpty {
                Text("Add a file above, then ask a question — Salehman answers only from what's in your documents.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(DS.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Flat opaque panel + hairline (design language).
        .background(DS.Palette.codeSurfaceSide, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).stroke(DS.Palette.surfaceStroke, lineWidth: 1))
    }

    @ViewBuilder private var documentsSection: some View {
        if docs.isEmpty {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(DS.Palette.accent.opacity(0.14)).frame(width: 84, height: 84).blur(radius: 16)
                    Image(systemName: "books.vertical.fill").font(.system(size: 38)).foregroundStyle(DS.Palette.accent.opacity(0.85))
                }
                Text("No documents yet").font(.headline).foregroundStyle(.white)
                Text("Add PDFs, text, or notes. Everything stays on this Mac.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 30)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(docs.count) document\(docs.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                VStack(spacing: 1) {
                    ForEach(docs) { doc in docRow(doc) }
                }
                .background(DS.Palette.codeSurfaceSide, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).stroke(DS.Palette.surfaceStroke, lineWidth: 1))
            }
        }
    }

    private func docRow(_ doc: KnowledgeDoc) -> some View {
        HStack(spacing: 12) {
            // Tapping the row opens the detail sheet (on-device summary + info).
            Button { detailDoc = doc } label: {
                HStack(spacing: 12) {
                    Image(systemName: doc.icon).font(.system(size: 14)).foregroundStyle(DS.Palette.accent).frame(width: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(doc.name).font(.system(size: 14, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                        Text("\(doc.kind) · \(doc.chunkCount) passage\(doc.chunkCount == 1 ? "" : "s")")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "sparkles").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).help("Open & summarize").accessibilityHint("Open \(doc.name) and summarize it")
            Button { KnowledgeStore.shared.deleteDocument(doc.id); reload() } label: {
                Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain).help("Remove").accessibilityLabel("Remove \(doc.name)")
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, 10)
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
                Button("Add to Knowledge", action: addPastedText)
                    .buttonStyle(.borderedProminent).tint(DS.Palette.accent)
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
                    } else {
                        Text(summary).font(.callout).foregroundStyle(.white)
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !answer.isEmpty {
                        Divider().overlay(DS.Palette.hairline)
                        Text("ANSWER").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.6)
                        Text(answer).font(.callout).foregroundStyle(.white)
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            // Ask scoped to THIS document only.
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Ask about this document…", text: $question)
                    .textFieldStyle(.plain).font(.system(size: 14))
                    .onSubmit { Task { await ask() } }
                Button { Task { await ask() } } label: {
                    if asking { ProgressView().controlSize(.small) }
                    else { Image(systemName: "arrow.up.circle.fill").font(.system(size: 20)).foregroundStyle(DS.Palette.accent) }
                }
                .buttonStyle(.plain).accessibilityLabel("Ask about this document")
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
