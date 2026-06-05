import Foundation
#if canImport(Combine)
import Combine
#endif

/// Shared byte-count constants. Centralizes the GiB conversion that was inlined
/// in three places (LocalLLM.swift, MemoryManager.swift, AppSettings.swift) —
/// the magic 1_073_741_824 literal isn't self-documenting, and three copies
/// drift the day someone "tunes" one without grepping for the other two.
enum ByteConstants {
    /// Bytes per gibibyte (2^30). Use to convert `ProcessInfo.physicalMemory` to GB.
    static let bytesPerGB = 1_073_741_824
}

/// System-wide, real-time RAM + thermal awareness for the intelligence layer.
///
/// Subscribes once at startup to the kernel-pushed signals that matter on
/// macOS — `DispatchSource.makeMemoryPressureSource` and
/// `ProcessInfo.thermalStateDidChangeNotification` — and exposes a *derived*
/// snapshot every caller can read cheaply. No polling, no Instruments
/// integration required — these are the same signals macOS itself uses to
/// throttle background apps.
///
/// Design notes:
/// * The `Pressure`/`Thermal` enums use ordinal comparison (`.warning < .urgent`)
///   so callers can write `pressure >= .warning` and have it mean "at least
///   warning level". This is the natural API for thresholding.
/// * The combine-into-`concurrencyLimit` and `shouldRefuseHeavyModel` logic
///   is *pure*: the actor's only mutable state is the two raw signals. That
///   makes the policy unit-testable without spinning up a dispatch source.
/// * `worstCase(of:and:)` is exposed for the tests — given a pressure and
///   thermal state, you can compute the recommendation deterministically.
///
/// Why an actor: the dispatch-source event handler and the thermal-state
/// notification fire on arbitrary queues. Funneling them through the actor's
/// serial executor is the simplest way to keep the raw signals coherent.
actor MemoryManager {
    static let shared = MemoryManager()

    // MARK: - Public surface

    enum Pressure: Int, Comparable, Sendable {
        case normal = 0, warning = 1, critical = 2
        static func < (a: Pressure, b: Pressure) -> Bool { a.rawValue < b.rawValue }
    }

    enum Thermal: Int, Comparable, Sendable {
        case nominal = 0, fair = 1, serious = 2, critical = 3
        static func < (a: Thermal, b: Thermal) -> Bool { a.rawValue < b.rawValue }

        init(_ state: ProcessInfo.ThermalState) {
            switch state {
            case .nominal:  self = .nominal
            case .fair:     self = .fair
            case .serious:  self = .serious
            case .critical: self = .critical
            @unknown default: self = .nominal
            }
        }
    }

    /// Snapshot of the current advisory state. Sendable so callers across
    /// actor boundaries can hold it briefly.
    struct Snapshot: Sendable, Equatable {
        let pressure: Pressure
        let thermal: Thermal
        let physicalGB: Int
        let concurrencyLimit: Int
        let refuseHeavyModel: Bool
    }

    func snapshot() -> Snapshot {
        let limit = Self.concurrencyLimit(pressure: pressure, thermal: thermal, physicalGB: physicalGB)
        let refuse = Self.shouldRefuseHeavyModel(pressure: pressure, thermal: thermal, physicalGB: physicalGB)
        return Snapshot(pressure: pressure, thermal: thermal,
                        physicalGB: physicalGB, concurrencyLimit: limit,
                        refuseHeavyModel: refuse)
    }

    /// Max concurrent agent tasks we recommend right now. Read this in any
    /// pipeline before spinning up parallel inferences.
    func concurrencyLimit() -> Int {
        Self.concurrencyLimit(pressure: pressure, thermal: thermal, physicalGB: physicalGB)
    }

    /// True iff the system is too warm or memory-stressed to load the heavy
    /// (32B) model. Honour this before unpacking heavyweight inferences.
    func shouldRefuseHeavyModel() -> Bool {
        Self.shouldRefuseHeavyModel(pressure: pressure, thermal: thermal, physicalGB: physicalGB)
    }

    /// Background eviction hook — call when entering low-memory states. Tells
    /// Ollama to drop loaded models from RAM immediately.
    func evictOllamaIfNeeded() async {
        guard pressure >= .warning else { return }
        await OllamaClient.unloadAll()
    }

    // MARK: - Pure policy (testable without OS signals)

    /// Pure mapping `(pressure, thermal, RAM)` → max concurrent agents.
    /// Kept `static` so the unit tests can drive it directly.
    nonisolated static func concurrencyLimit(pressure: Pressure,
                                             thermal: Thermal,
                                             physicalGB: Int) -> Int {
        // Worst-case wins: the dominating signal decides the cap.
        if pressure >= .critical || thermal >= .critical { return 1 }
        if pressure >= .warning  || thermal >= .serious  { return 1 }
        if thermal == .fair                              { return 2 }
        // Healthy state — let big Macs spread out.
        if physicalGB >= 24 { return 4 }
        if physicalGB >= 16 { return 2 }
        return 1
    }

    /// Pure mapping `(pressure, thermal, RAM)` → "drop the 32B model".
    /// The 32B Q4_K_M is ~19 GB resident; it's untenable on small Macs and
    /// any system warning.
    nonisolated static func shouldRefuseHeavyModel(pressure: Pressure,
                                                   thermal: Thermal,
                                                   physicalGB: Int) -> Bool {
        if physicalGB < 24      { return true }   // Heavy needs ~24 GB headroom.
        if pressure >= .warning { return true }
        if thermal  >= .serious { return true }
        return false
    }

    // MARK: - Raw signal state (actor-isolated)

    private var pressure: Pressure = .normal
    private var thermal:  Thermal  = .nominal
    private let physicalGB: Int

    // MARK: - OS subscriptions

    private let pressureSource: DispatchSourceMemoryPressure
    // `nonisolated(unsafe)` is honest here: this stores the
    // `addObserver(forName:object:queue:using:)` token exactly once during
    // `init`, and we never read or mutate it again (no `removeObserver` since
    // the singleton is process-lifetime). The Swift-6 rule that bans
    // assigning to isolated stored state from a nonisolated `init` doesn't
    // apply to a `nonisolated(unsafe)` property.
    nonisolated(unsafe) private var thermalObserver: NSObjectProtocol?

    private init() {
        let gb = Int((Double(ProcessInfo.processInfo.physicalMemory) / Double(ByteConstants.bytesPerGB)).rounded())
        self.physicalGB = max(gb, 1)
        self.thermal    = Thermal(ProcessInfo.processInfo.thermalState)

        // .all monitors both .warning and .critical so we never miss a transition.
        self.pressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: DispatchQueue.global(qos: .utility))

        // The closure runs on the utility queue; we hop into the actor to
        // mutate state coherently.
        self.pressureSource.setEventHandler { [weak self] in
            guard let self else { return }
            let raw = self.pressureSource.data
            let next: Pressure
            if raw.contains(.critical)     { next = .critical }
            else if raw.contains(.warning) { next = .warning  }
            else                           { next = .normal   }
            Task { await self.applyPressure(next) }
        }
        self.pressureSource.resume()

        self.thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil, queue: nil) { [weak self] _ in
                guard let self else { return }
                let next = Thermal(ProcessInfo.processInfo.thermalState)
                Task { await self.applyThermal(next) }
            }
    }

    // No `deinit`: `MemoryManager.shared` is process-lifetime, so cleanup is
    // implicit at termination. (Swift-6 also forbids touching isolated state
    // from an actor `deinit`, which we'd have to do for `pressureSource` /
    // `thermalObserver` — another reason to skip it.)

    // MARK: - Mutators (single coherent entry point per signal)

    private func applyPressure(_ next: Pressure) {
        guard next != pressure else { return }
        pressure = next
        // Auto-evict when we cross into warning territory — single most
        // important hook in this whole file.
        if pressure >= .warning {
            Task { await self.evictOllamaIfNeeded() }
        }
    }

    private func applyThermal(_ next: Thermal) {
        thermal = next
    }
}
