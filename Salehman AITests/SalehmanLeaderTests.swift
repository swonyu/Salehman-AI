import Testing
import Foundation
@testable import Salehman_AI

// MARK: - SalehmanLeader pure-logic guards
//
// SalehmanLeader.finalize is the last mile for every user-facing reply — it's
// too consequential to leave untested. The live engine paths can't run in CI,
// but the pure gatekeeping functions (isMostlyCode, isErrorReply guard,
// isLeading) are fully testable.

struct IsMostlyCodeTests {

    @Test func emptyStringIsNotMostlyCode() {
        #expect(!SalehmanLeader.isMostlyCode(""))
    }

    @Test func plainTextIsNotMostlyCode() {
        #expect(!SalehmanLeader.isMostlyCode("The quick brown fox."))
    }

    @Test func unclosedFenceIsNotMostlyCode() {
        // Need ≥1 opened+closed pair — a single ``` never closes.
        let text = "Here is some code:\n```swift\nlet x = 1"
        #expect(!SalehmanLeader.isMostlyCode(text))
    }

    @Test func smallCodeBlockInLargeTextIsNotMostlyCode() {
        // A one-liner code block inside a long reply is < 40%.
        let prose = String(repeating: "This is a sentence. ", count: 20)  // ~400 chars
        let text = prose + "\n```\nlet x = 1\n```"                        // ~20 char code
        #expect(!SalehmanLeader.isMostlyCode(text))
    }

    @Test func allCodeIsConsideredMostlyCode() {
        // The entire reply is inside fences → 100% code → definitely ≥40%.
        let text = "```swift\nfunc greet() { print(\"hello\") }\n```"
        #expect(SalehmanLeader.isMostlyCode(text))
    }

    @Test func halfCodeHalfTextBorderCase() {
        // `isMostlyCode` weighs the chars BETWEEN the fences (incl. the inner
        // newlines) against the WHOLE reply — the ``` markers count toward the
        // total but NOT the code tally. So a roughly even code/prose reply clears
        // the 40% bar only once the fenced side is the slight majority. (A literal
        // 50/50 inner split lands ~39% because the six marker chars inflate only
        // the denominator — the original example mis-counted that and never ran.)
        let code = "let x = 1"   // "\nlet x = 1\n" → 11 chars counted as code
        let prose = "Done"       // shorter prose keeps the fenced side on top
        let text = "```\n\(code)\n```\n\(prose)"
        #expect(SalehmanLeader.isMostlyCode(text))   // 11 / 22 = 50% ≥ 40% → true
    }

    @Test func multipleSmallFencesCanCrossThreshold() {
        // Three 30-char code blocks inside a 90-char total reply → each fence
        // is exactly 1/3 of the reply; together they are 100% → ≥40%.
        let fence = "```\nabc\n```"   // ~10 chars each
        let text = "\(fence)\(fence)\(fence)"
        #expect(SalehmanLeader.isMostlyCode(text))
    }
}

// MARK: - isLeading settings gate

struct IsLeadingTests {

    private func withSettings(leader: Bool, pref: BrainPreference,
                               _ body: () -> Bool) -> Bool {
        let lk = AppSettings.Keys.salehmanLeader
        let pk = AppSettings.Keys.brainPreference
        let priorL = UserDefaults.standard.object(forKey: lk)
        let priorP = UserDefaults.standard.string(forKey: pk)
        defer {
            if let priorL { UserDefaults.standard.set(priorL, forKey: lk) }
            else           { UserDefaults.standard.removeObject(forKey: lk) }
            if let priorP  { UserDefaults.standard.set(priorP, forKey: pk) }
            else           { UserDefaults.standard.removeObject(forKey: pk) }
        }
        UserDefaults.standard.set(leader,       forKey: lk)
        UserDefaults.standard.set(pref.rawValue, forKey: pk)
        return body()
    }

    @Test func leaderOffMeansNeverLeading() {
        let result = withSettings(leader: false, pref: .unslothStudio) { SalehmanLeader.isLeading }
        #expect(!result)
    }

    @Test func salehmanBrainNeverLeads() {
        // Salehman-on-Salehman would be a double-pass — explicitly excluded.
        let result = withSettings(leader: true, pref: .salehman) { SalehmanLeader.isLeading }
        #expect(!result)
    }

    @Test func unslothStudioBrainLeadsWhenEnabled() {
        let result = withSettings(leader: true, pref: .unslothStudio) { SalehmanLeader.isLeading }
        #expect(result)
    }

    @Test func uncensoredBrainLeadsWhenEnabled() {
        let result = withSettings(leader: true, pref: .uncensored) { SalehmanLeader.isLeading }
        #expect(result)
    }
}

// MARK: - Error-reply bypass guard

struct FinalizeErrorBypassTests {

    // These verify the isErrorReply + offMessage guards without needing a live
    // engine: the function returns the draft unchanged for bad inputs.

    @Test func emptyDraftReturnedUnchanged() async {
        let result = await SalehmanLeader.finalize(userPrompt: "q", draft: "")
        #expect(result == "")
    }

    @Test func offMessageReturnedUnchanged() async {
        let result = await SalehmanLeader.finalize(userPrompt: "q", draft: LocalLLM.offMessage)
        #expect(result == LocalLLM.offMessage)
    }

    @Test func bracketErrorReturnedUnchanged() async {
        // A bracket provider error must bypass the leader (not waste a generate call).
        let err = "[Groq error 429: rate limit exceeded]"
        let result = await SalehmanLeader.finalize(userPrompt: "q", draft: err)
        #expect(result == err)
    }

    @Test func requestFailedErrorReturnedUnchanged() async {
        let err = "[Mistral request failed (HTTP 503). Retry in a moment.]"
        let result = await SalehmanLeader.finalize(userPrompt: "q", draft: err)
        #expect(result == err)
    }

    @Test func onDeviceErrorReturnedUnchanged() async {
        let err = "[The on-device model couldn't complete the request]"
        let result = await SalehmanLeader.finalize(userPrompt: "q", draft: err)
        #expect(result == err)
    }
}
