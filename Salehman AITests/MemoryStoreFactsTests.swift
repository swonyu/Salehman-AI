import Testing
import Foundation
@testable import Salehman_AI

/// Heavy coverage for the Memory tab's store: the pure `extractFacts` pattern
/// extractor (auto-memory — runs after every reply, zero model calls) and the
/// `remember` dedup/trim contract. Store tests use a throwaway temp directory.
@MainActor
struct MemoryStoreFactsTests {

    private func freshStore() -> MemoryStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("memtest-\(UUID().uuidString)", isDirectory: true)
        return MemoryStore(baseDirectory: dir)
    }

    // MARK: extractFacts — one assertion per pattern family

    @Test func extractsName() {
        #expect(MemoryStore.extractFacts(from: "My name is Saleh") == ["User's name is Saleh."])
    }
    @Test func extractsRoleEndingInAKnownProfession() {
        #expect(MemoryStore.extractFacts(from: "I'm a software engineer") == ["User is a software engineer."])
    }
    @Test func extractsWorkplace() {
        #expect(MemoryStore.extractFacts(from: "I work at Anthropic") == ["User works at Anthropic."])
    }
    @Test func extractsLocation() {
        #expect(MemoryStore.extractFacts(from: "I'm from Riyadh") == ["User is from Riyadh."])
    }
    @Test func extractsPreference() {
        #expect(MemoryStore.extractFacts(from: "I love hiking") == ["User prefers hiking."])
    }
    @Test func extractsDislike() {
        #expect(MemoryStore.extractFacts(from: "I hate meetings") == ["User dislikes meetings."])
    }
    @Test func extractsTool() {
        #expect(MemoryStore.extractFacts(from: "I'm using SwiftUI") == ["User uses SwiftUI."])
    }
    @Test func caseInsensitiveAndTrimsTrailingPunctuation() {
        #expect(MemoryStore.extractFacts(from: "MY NAME IS Bob.") == ["User's name is Bob."])
    }
    @Test func ignoresPlainProse() {
        #expect(MemoryStore.extractFacts(from: "hello there, how are you").isEmpty)
    }
    @Test func ignoresTooShortInput() {
        #expect(MemoryStore.extractFacts(from: "hi").isEmpty)
    }
    @Test func skipsNoiseValues() {
        #expect(MemoryStore.extractFacts(from: "I like that").isEmpty)   // "that" is noise
    }

    // MARK: remember / dedup / delete / clear / recall

    @Test func rememberStoresAFact() {
        let m = freshStore()
        m.remember("User likes coffee")
        #expect(m.allFacts() == ["User likes coffee"])
    }
    @Test func rememberDedupsCaseInsensitively() {
        let m = freshStore()
        m.remember("Hello"); m.remember("hello"); m.remember("HELLO")
        #expect(m.allFacts().count == 1)
    }
    @Test func rememberTrimsAndIgnoresBlank() {
        let m = freshStore()
        m.remember("   spaced   ")
        m.remember("   ")
        #expect(m.allFacts() == ["spaced"])
    }
    @Test func deleteThenClear() {
        let m = freshStore()
        m.remember("a"); m.remember("b")
        m.delete("a")
        #expect(m.allFacts() == ["b"])
        m.clear()
        #expect(m.allFacts().isEmpty)
    }
    @Test func recallFindsAKeywordMatch() {
        let m = freshStore()
        m.remember("User lives in Riyadh")
        m.remember("User likes coffee")
        #expect(m.recall("coffee please").contains("User likes coffee"))
    }
}
