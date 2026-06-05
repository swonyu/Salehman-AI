import Testing
import Foundation
@testable import Salehman_AI

// MARK: - SettingsView brainReady / testActiveBrain / subtitle surface
//
// brainReady is called on every Settings body recompute (grid + polls).
// It currently does live Keychain syscalls; the P2 perf item + the routing
// refactor (extract brainReady seam) are needed for full testability without
// real keys / side effects. testActiveBrain classification (offMessage etc.)
// and the no-leak subtitle rule also benefit from the registry + cached flags.
//
// Leave disabled until the §3 refactor provides the injection / seams.

struct SettingsBrainReadyTests {

    @Test(.disabled("TODO: §3 refactor (BrainAdapter + brainReady extraction + cached flags) required — see CODEBASE_REVIEW §4 and Tab B"))
    func freeAutoReturnsTrueOnlyWhenAFreeCloudKeyIsPresent() {
    }

    @Test(.disabled("TODO: §3 refactor (BrainAdapter + brainReady extraction + cached flags) required — see CODEBASE_REVIEW §4 and Tab B"))
    func autoReturnsTrueForAppleOrOllamaAloneAndFalseWhenNeither() {
    }

    @Test(.disabled("TODO: §3 refactor (BrainAdapter + brainReady extraction + cached flags) required — see CODEBASE_REVIEW §4 and Tab B"))
    func salehmanIsFalseWhenCustomModelNameEmptyEvenIfOllamaUp() {
    }

    @Test(.disabled("TODO: §3 refactor (BrainAdapter + brainReady extraction + cached flags) required — see CODEBASE_REVIEW §4 and Tab B"))
    func supersededTestActiveBrainDoesNotWriteActiveBrainWorkingAndClearsTesting() {
    }

    @Test(.disabled("TODO: §3 refactor (BrainAdapter + brainReady extraction + cached flags) required — see CODEBASE_REVIEW §4 and Tab B"))
    func anthropicSubtitleMasksNonSkAntKeysAndNeverLeaksSecretBytes() {
    }
}
