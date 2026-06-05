import Foundation
import FoundationModels

/// `list_documents` — enumerates every document in the owner's private Knowledge
/// vault (name + kind + passage count). The third and smallest member of the
/// Knowledge tool family:
///   • `list_documents`   → what's in the vault
///   • `search_documents` → relevant passages across the vault (RAG)
///   • `get_document`     → one whole document by name
///
/// Always-on local core; no settings flag.
struct ListDocumentsTool: Tool {
    let name = "list_documents"
    let description = "List every document currently in the user's private Knowledge vault, with its kind and passage count. Use to answer 'what's in my Knowledge?' or before `search_documents`/`get_document` when you don't know what's available."

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        let docs = KnowledgeStore.shared.allDocuments()
        guard !docs.isEmpty else {
            return "The Knowledge vault is empty — the user hasn't added any documents yet."
        }
        let lines = docs.map { "• \($0.name) — \($0.kind), \($0.chunkCount) passage\($0.chunkCount == 1 ? "" : "s")" }
        let header = "Knowledge vault (\(docs.count) document\(docs.count == 1 ? "" : "s")):"
        return ([header] + lines).joined(separator: "\n")
    }
}
