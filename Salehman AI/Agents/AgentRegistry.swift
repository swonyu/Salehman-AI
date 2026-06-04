import Foundation

/// Registry for dynamic agent registration and execution.
/// Designed to be simple, safe, and easy to extend.
struct AgentRegistry {
    
    typealias AgentHandler = (inout MissionMemory) async -> String
    
    private static var handlers: [String: AgentHandler] = [:]
    
    /// Register a new agent. Prevents accidental duplicates.
    static func register(name: String, handler: @escaping AgentHandler) {
        if handlers[name] != nil {
            print("⚠️ Warning: Agent '\(name)' is already registered.")
            return
        }
        handlers[name] = handler
        print("✓ Agent registered: \(name)")
    }
    
    /// Get the handler for an agent (if it exists)
    static func handler(for name: String) -> AgentHandler? {
        return handlers[name]
    }
    
    /// Execute a list of agents in order
    static func execute(agents: [String], memory: inout MissionMemory) async {
        for name in agents {
            guard let handler = handlers[name] else {
                print("❌ Error: No handler found for agent '\(name)'")
                continue
            }
            
            print("\n▶ Running agent: \(name)")
            let result = await handler(&memory)
            memory.recordAgentOutput(name: name, output: result)
        }
    }
    
    /// Returns a list of all registered agents
    static func registeredAgents() -> [String] {
        return Array(handlers.keys).sorted()
    }
    
    /// Check if an agent is already registered
    static func isRegistered(_ name: String) -> Bool {
        return handlers[name] != nil
    }
}
