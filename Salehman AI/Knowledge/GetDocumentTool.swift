import Foundation
import FoundationModels

/// `get_document` — Foundation Models tool that returns the (capped) full text
/// of one document from the owner's private Knowledge vault, matched by name.
///
/// Pairs with `search_documents`:
///   • `search_documents` → top passages across the whole vault (RAG-style Q&A)
///   • `get_document`     → one document's text end-to-end (summary, translate,
///                          quote, table-of-contents, etc.)
///
/// Lookup is case-insensitive substring on the document name so the brain's
/// transcription doesn't have to be exact (e.g. "paper" finds "Paper Q3.pdf").
/// On a miss the tool returns the list of available names so the brain can
/// self-correct in its next call instead of hallucinating a document.
/// Always-on local core; no setting to toggle.
struct GetDocumentTool: Tool {
    let name = "get_document"
    let description = "Retrieve the full text of one document from the user's private Knowledge vault, matched by name (case-insensitive substring). Use after `search_documents` when you need an entire document — for summarizing, translating, quoting, or producing an outline."

    @Generable
    struct Arguments {
        @Guide(description: "Name or distinctive substring of the document to fetch. Case-insensitive; partial matches work.")
        var name: String
    }

    func call(arguments: Arguments) async throws -> String {
        let query = arguments.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return "Provide a document name to fetch."
        }

        let docs = KnowledgeStore.shared.allDocuments()
        guard !docs.isEmpty else {
            return "The Knowledge vault is empty — the user hasn't added any documents yet."
        }

        // Prefer the shortest matching name (more specific match), so "notes"
        // doesn't lose to "long-notes-with-lots-of-prefix.pdf" when both contain it.
        guard let doc = docs
            .filter({ $0.name.lowercased().contains(query) })
            .min(by: { $0.name.count < $1.name.count })
        else {
            let listing = docs.prefix(8).map(\.name).joined(separator: ", ")
            let more = docs.count > 8 ? " (and \(docs.count - 8) more)" : ""
            return "No document matched \"\(arguments.name)\". Available: \(listing)\(more)."
        }

        let text = KnowledgeStore.shared.text(forDocument: doc.id)
        if text.isEmpty {
            return "Found \"\(doc.name)\" but it has no extractable text."
        }

        // Document name in the header so the brain can cite it in its reply.
        return "Document: \(doc.name)\n\n\(text)"
    }
}
