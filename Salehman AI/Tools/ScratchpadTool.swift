import Foundation
#if canImport(FoundationModels)
import FoundationModels

// Foundation Models tools over `ScratchpadStore` — they let the assistant capture
// notes, add/complete tasks, and read the list back to summarize/organize. Each
// `call` hops to the main actor (the store is `@MainActor`) and returns a short
// confirmation string. Registered in `ToolPolicy.activeTools()` as always-on
// local core (no network, fully on-device).

/// Save a free-text note.
struct CaptureNoteTool: Tool {
    let name = "capture_note"
    let description = "Save a short note to the user's Scratchpad (Notes). Use when the user wants to jot down or remember something that isn't an actionable task."

    @Generable
    struct Arguments {
        @Guide(description: "The note text to save.")
        var text: String
    }

    func call(arguments: Arguments) async throws -> String {
        let text = arguments.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "Nothing to save." }
        await ScratchpadStore.shared.addNote(text)
        return "Saved a note: \"\(text)\""
    }
}

/// Add a to-do item.
struct AddTaskTool: Tool {
    let name = "add_task"
    let description = "Add a to-do item to the user's Scratchpad (Tasks). Use for actionable things the user wants to do."

    @Generable
    struct Arguments {
        @Guide(description: "The task title, e.g. 'Buy groceries'.")
        var title: String
    }

    func call(arguments: Arguments) async throws -> String {
        let title = arguments.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "No task given." }
        await ScratchpadStore.shared.addTask(title)
        return "Added task: \"\(title)\""
    }
}

/// Mark an open task done by matching its title.
struct CompleteTaskTool: Tool {
    let name = "complete_task"
    let description = "Mark one of the user's open tasks as done by matching words from its title."

    @Generable
    struct Arguments {
        @Guide(description: "Words from the task to complete, e.g. 'groceries'.")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        let done = await ScratchpadStore.shared.completeTask(matching: arguments.query)
        return done ? "Marked it done." : "No open task matched \"\(arguments.query)\"."
    }
}

/// List current notes + open tasks (for summarizing / organizing).
struct ListScratchpadTool: Tool {
    let name = "list_scratchpad"
    let description = "List the user's current notes and open tasks. Call this before summarizing or organizing them."

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        await ScratchpadStore.shared.summaryText()
    }
}
#endif
