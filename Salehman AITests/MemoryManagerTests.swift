import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Pure policy: concurrencyLimit + shouldRefuseHeavyModel
//
// `MemoryManager`'s OS-signal subscriptions (DispatchSource + thermal
// notifications) are tested separately via the runtime app. These tests
// drive the *pure* static policy functions with synthetic inputs so we
// can pin behaviour at every RAM / pressure / thermal corner without
// needing the kernel to cooperate.

struct MemoryManagerPolicyTests {

    // MARK: concurrencyLimit — healthy state

    @Test func healthyBigMacGetsFourLanes() {
        let n = MemoryManager.concurrencyLimit(pressure: .normal, thermal: .nominal, physicalGB: 32)
        #expect(n == 4)
    }

    @Test func healthyMidMacGetsTwoLanes() {
        let n = MemoryManager.concurrencyLimit(pressure: .normal, thermal: .nominal, physicalGB: 16)
        #expect(n == 2)
    }

    @Test func healthySmallMacGetsOneLane() {
        let n = MemoryManager.concurrencyLimit(pressure: .normal, thermal: .nominal, physicalGB: 8)
        #expect(n == 1)
    }

    // MARK: concurrencyLimit — pressure dominates RAM

    @Test func warningPressureCollapsesAnyMacToOneLane() {
        for gb in [8, 16, 24, 64] {
            let n = MemoryManager.concurrencyLimit(pressure: .warning, thermal: .nominal, physicalGB: gb)
            #expect(n == 1, "warning pressure must cap to 1, got \(n) at \(gb) GB")
        }
    }

    @Test func criticalPressureCollapsesAnyMacToOneLane() {
        for gb in [8, 16, 24, 64] {
            let n = MemoryManager.concurrencyLimit(pressure: .critical, thermal: .nominal, physicalGB: gb)
            #expect(n == 1, "critical pressure must cap to 1, got \(n) at \(gb) GB")
        }
    }

    // MARK: concurrencyLimit — thermal dominates RAM

    @Test func fairThermalPinsToTwoLanesEvenOnBigMac() {
        // .fair is a soft heat hint; we allow 2 lanes regardless of RAM so
        // a hot 64 GB Mac doesn't keep saturating cores.
        let n = MemoryManager.concurrencyLimit(pressure: .normal, thermal: .fair, physicalGB: 64)
        #expect(n == 2)
    }

    @Test func seriousThermalCollapsesToOneLane() {
        let n = MemoryManager.concurrencyLimit(pressure: .normal, thermal: .serious, physicalGB: 64)
        #expect(n == 1)
    }

    @Test func criticalThermalCollapsesToOneLane() {
        let n = MemoryManager.concurrencyLimit(pressure: .normal, thermal: .critical, physicalGB: 64)
        #expect(n == 1)
    }

    // MARK: concurrencyLimit — worst signal wins

    @Test func warningPressureBeatsHealthyThermal() {
        let n = MemoryManager.concurrencyLimit(pressure: .warning, thermal: .nominal, physicalGB: 64)
        #expect(n == 1)
    }

    @Test func seriousThermalBeatsHealthyPressure() {
        let n = MemoryManager.concurrencyLimit(pressure: .normal, thermal: .serious, physicalGB: 64)
        #expect(n == 1)
    }

    // MARK: shouldRefuseHeavyModel

    @Test func refusesHeavyOnSmallMac() {
        #expect(MemoryManager.shouldRefuseHeavyModel(pressure: .normal, thermal: .nominal, physicalGB: 8))
        #expect(MemoryManager.shouldRefuseHeavyModel(pressure: .normal, thermal: .nominal, physicalGB: 16))
    }

    @Test func allowsHeavyOnBigHealthyMac() {
        #expect(!MemoryManager.shouldRefuseHeavyModel(pressure: .normal, thermal: .nominal, physicalGB: 32))
    }

    @Test func refusesHeavyOnBigMacUnderPressure() {
        #expect(MemoryManager.shouldRefuseHeavyModel(pressure: .warning, thermal: .nominal, physicalGB: 32))
        #expect(MemoryManager.shouldRefuseHeavyModel(pressure: .critical, thermal: .nominal, physicalGB: 32))
    }

    @Test func refusesHeavyOnBigMacUnderHeat() {
        #expect(MemoryManager.shouldRefuseHeavyModel(pressure: .normal, thermal: .serious, physicalGB: 32))
        #expect(MemoryManager.shouldRefuseHeavyModel(pressure: .normal, thermal: .critical, physicalGB: 32))
    }

    @Test func twentyFourGigBoundaryIsAllowedAtRest() {
        // 24 GB is the documented threshold; verify the exact edge.
        #expect(!MemoryManager.shouldRefuseHeavyModel(pressure: .normal, thermal: .nominal, physicalGB: 24))
        #expect( MemoryManager.shouldRefuseHeavyModel(pressure: .normal, thermal: .nominal, physicalGB: 23))
    }

    // MARK: Enum ordering — the API guarantees ordinal Comparable

    @Test func pressureOrderingIsOrdinal() {
        #expect(MemoryManager.Pressure.normal < .warning)
        #expect(MemoryManager.Pressure.warning < .critical)
        #expect(MemoryManager.Pressure.critical >= .warning)
    }

    @Test func thermalOrderingIsOrdinal() {
        #expect(MemoryManager.Thermal.nominal < .fair)
        #expect(MemoryManager.Thermal.fair < .serious)
        #expect(MemoryManager.Thermal.serious < .critical)
    }

    @Test func thermalFromProcessInfoMapsCanonically() {
        #expect(MemoryManager.Thermal(.nominal)  == .nominal)
        #expect(MemoryManager.Thermal(.fair)     == .fair)
        #expect(MemoryManager.Thermal(.serious)  == .serious)
        #expect(MemoryManager.Thermal(.critical) == .critical)
    }
}

// MARK: - Default model wiring
//
// Guards against accidental regressions where someone flips the default
// back to the heavy 32B model. These two assertions are the iron-clad
// statement of "7B is the sweet-spot default".

struct OllamaDefaultModelTests {
    @Test func codeModelIsSevenB() {
        #expect(OllamaClient.codeModel == "qwen2.5-coder:7b")
    }

    @Test func heavyCodeModelExistsButIsNotDefault() {
        #expect(OllamaClient.heavyCodeModel == "qwen2.5-coder:32b")
        #expect(OllamaClient.codeModel != OllamaClient.heavyCodeModel)
    }

    @Test func defaultNumCtxIsTight() {
        // 2048 is the documented sweet-spot. If someone bumps this,
        // they're knowingly trading RAM for context length — make them
        // update this test on purpose.
        #expect(OllamaClient.defaultNumCtx == 2048)
        #expect(OllamaClient.Generation.default.numCtx == 2048)
    }
}
