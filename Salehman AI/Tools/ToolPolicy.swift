import Foundation

/// Controls whether external/non-local tools are allowed.
/// Default = .localOnly to maintain the local-first philosophy.
enum ToolPolicy {
    case localOnly
    case allowExternalTools

    /// Change this value to enable external tools later
    static var current: ToolPolicy = .localOnly
}
