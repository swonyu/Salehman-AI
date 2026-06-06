import Testing
import Foundation
@testable import Salehman_AI

// MARK: - LocalLLM brain routing (via BrainAdapter registry — §3 refactor target)
//
// These cases REQUIRE the BrainAdapter registry + injectable seams from Tab B's
// refactor (R1). Without a fakeable dispatch the routing ladder is a 200-line
// cascade of ifs with no seam for unit tests. Leave all cases disabled until
// the registry lands; then un-disable + supply a test double registry.
//
// Header note per COORDINATION + CODEBASE_REVIEW: do not enable until the
// refactor that makes currentBrain / generate / ensemble etc. dispatch through
// one registry instead of 3 copies of the ladder.

struct BrainRoutingDispatchTests {

    @Test(.disabled("TODO: §3 refactor (BrainAdapter registry) required — see CODEBASE_REVIEW §4 and Tab B mission"))
    func pinnedBrainPreferenceDispatchesToExactlyOneAdapterNoFallthrough() {
    }

    @Test(.disabled("TODO: §3 refactor (BrainAdapter registry) required — see CODEBASE_REVIEW §4 and Tab B mission"))
    func autoAndLocalPinsNeverInvokeAnyCloudAdapterLocalFirstInvariant() {
    }

    @Test(.disabled("TODO: §3 refactor (BrainAdapter registry) required — see CODEBASE_REVIEW §4 and Tab B mission"))
    func offlineModeForcesCloudPrefsToNoneAndExcludesThemFromEnsembleAndFreeAuto() {
    }

    @Test(.disabled("TODO: §3 refactor (BrainAdapter registry) required — see CODEBASE_REVIEW §4 and Tab B mission"))
    func freeAutoIncludesOnlyFreeProvidersNeverPaidClients() {
    }
}
