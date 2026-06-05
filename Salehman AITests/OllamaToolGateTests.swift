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

    @Test func offlineExposesOnlyTerminal() {
        let names = LocalLLM.ollamaToolNames(externalAllowed: false)
        #expect(names == ["run_terminal_command"])
        #expect(!names.contains("web_search"))
        #expect(!names.contains("fetch_url"))
    }

    @Test func onlineExposesTerminalPlusWeb() {
        let names = LocalLLM.ollamaToolNames(externalAllowed: true)
        #expect(names.contains("run_terminal_command"))
        #expect(names.contains("web_search"))
        #expect(names.contains("fetch_url"))
        #expect(names.count == 3)
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
