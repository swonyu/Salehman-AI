import Testing
@testable import Salehman_AI

// MARK: - LocalLLM.ollamaToolNames — Ollama tool-loop security gate
//
// The Ollama tool-calling loop MUST NEVER expose qwen to the web tools
// (web_search, fetch_url) while external access is off (Offline mode or
// "Web access" toggled off). The spec list IS the gate: a model that
// doesn't see the tool can't call it. The executor's defense-in-depth
// re-check is a second layer; this suite locks in the first layer.

struct OllamaToolGateTests {

    @Test func offlineHidesWebToolsButKeepsOnDeviceOnes() {
        let names = LocalLLM.ollamaToolNames(externalAllowed: false)
        // THE security gate: the web tools are NEVER exposed while external access
        // is off (Offline mode / "Web access" off).
        #expect(!names.contains("web_search"))
        #expect(!names.contains("fetch_url"))
        // On-device tools (no network) ARE available offline: terminal + the
        // knowledge/notes/tasks/memory tools.
        #expect(names.contains("run_terminal_command"))
        #expect(names.contains("search_documents"))
        #expect(names.contains("capture_note"))
        #expect(names.contains("add_task"))
        #expect(names.contains("remember_fact"))
        #expect(names.contains("pack_repository"))
    }

    @Test func onlineAddsExactlyTheTwoWebTools() {
        let offline = Set(LocalLLM.ollamaToolNames(externalAllowed: false))
        let online = Set(LocalLLM.ollamaToolNames(externalAllowed: true))
        // Going online adds the two web tools — and nothing else.
        #expect(online.subtracting(offline) == ["web_search", "fetch_url"])
        // …and every offline (on-device) tool is still present.
        #expect(offline.isSubset(of: online))
    }

    @Test func namesMatchSpecsExactly() {
        // ollamaToolNames is *derived* from ollamaToolSpecs — both must stay in
        // lockstep so a future tool added to the specs is also reflected in
        // the test surface. A drift here would mean the security assertions
        // above are silently incomplete.
        for allowed in [false, true] {
            let specs = LocalLLM.ollamaToolSpecs(externalAllowed: allowed)
            let names = LocalLLM.ollamaToolNames(externalAllowed: allowed)
            #expect(specs.count == names.count, "spec/name count mismatch for allowed=\(allowed)")
        }
    }
}

// MARK: - LocalLLM.runLocalTool — on-device tool dispatch (knowledge/notes/tasks/memory)
//
// The shared executor used by BOTH tool loops. Critical contract: it returns nil
// for any name it doesn't own, so the loops fall through to terminal/web/unknown.
// The blank-arg cases hit their guard BEFORE touching a store, so they're safe to
// run in parallel without mutating the shared singletons.
@MainActor
struct LocalToolDispatchTests {
    @Test func nonLocalToolsFallThrough() {
        #expect(LocalLLM.runLocalTool("run_terminal_command", ["command": "ls"]) == nil)
        #expect(LocalLLM.runLocalTool("web_search", ["query": "x"]) == nil)
        #expect(LocalLLM.runLocalTool("fetch_url", ["url": "https://example.com"]) == nil)
        #expect(LocalLLM.runLocalTool("not_a_real_tool", [:]) == nil)
    }

    @Test func blankArgsAreRecognizedAndGuardedWithoutMutating() {
        // Non-nil ⇒ recognized as a local tool; the guard fires before any write,
        // so no shared store is mutated by this assertion.
        #expect(LocalLLM.runLocalTool("search_documents", ["query": "   "]) != nil)
        #expect(LocalLLM.runLocalTool("capture_note", ["text": ""]) != nil)
        #expect(LocalLLM.runLocalTool("add_task", [:]) != nil)
        #expect(LocalLLM.runLocalTool("remember_fact", ["fact": "  "]) != nil)
    }
}
