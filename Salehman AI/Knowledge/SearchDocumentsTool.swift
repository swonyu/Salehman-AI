import Foundation
#if canImport(FoundationModels)
import FoundationModels

/// Foundation Models tool: let the chat brain pull from the owner's private
/// Knowledge vault mid-conversation. Returns the top passages with their source
/// document, so the model can answer + cite. Always-on local core (no network);
/// the vault itself is on-device.
struct SearchDocumentsTool: Tool {
    let name = "search_documents"
    let description = "Search the user's private Knowledge vault (documents and notes they added) and return the most relevant passages with their source. Use when the user asks about their own files, notes, or documents."

    @Generable
    struct Arguments {
        @Guide(description: "What to look for in the user's documents.")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        let q = arguments.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return "No query given." }
        let hits = KnowledgeStore.shared.search(query: q, k: 4)
        guard !hits.isEmpty else {
            return KnowledgeStore.shared.isEmpty()
                ? "The Knowledge vault is empty — the user hasn't added any documents yet."
                : "No passages in the Knowledge vault matched \"\(q)\"."
        }
        return hits.enumerated()
            .map { "[\($0 + 1)] (source: \($1.docName))\n\($1.text)" }
            .joined(separator: "\n\n")
    }
}
#endif
