import Testing
import Foundation
@testable import Salehman_AI

// MARK: - Security hardening (2026-06-05 review)
//
// Pins the two confirmed security fixes:
//   1. SSRF guard on `Web.fetch` — refuses non-http(s) schemes and
//      private/loopback/link-local hosts so an LLM tool call can't reach
//      localhost services (Ollama on 127.0.0.1:11434), the cloud metadata
//      endpoint, or the LAN.
//   2. Project-escape guard on `SelfImprove.isInsideProject` — now resolves
//      symlinks, so a planted symlink can't redirect a write outside the root.
//
// The rejection paths return BEFORE any network/disk I/O, so these are
// deterministic (no real fetch happens). We deliberately do NOT assert that a
// public URL succeeds — that would hit the network.

struct WebFetchSSRFTests {

    @Test func rejectsNonHTTPSchemes() async {
        let file = await Web.fetch("file:///etc/passwd")
        let ftp  = await Web.fetch("ftp://example.com/x")
        #expect(file.hasPrefix("Refused"))
        #expect(ftp.hasPrefix("Refused"))
    }

    @Test func rejectsLoopbackAndPrivateHosts() async {
        let targets = [
            "http://127.0.0.1:11434/api/tags",         // Ollama
            "http://localhost:8080",
            "http://169.254.169.254/latest/meta-data", // cloud metadata
            "http://10.0.0.5",
            "http://192.168.1.1",
            "http://172.16.0.9",
            "http://172.31.255.255",
        ]
        for u in targets {
            let r = await Web.fetch(u)
            #expect(r.hasPrefix("Refused"), "should refuse \(u) but got: \(r.prefix(40))")
        }
    }

    @Test func rejectsIPv6Loopback() async {
        let r = await Web.fetch("http://[::1]:11434")
        #expect(r.hasPrefix("Refused"))
    }

    @Test func doesNotFalselyBlockPublicDomains() async {
        // A real domain whose name merely starts with "fc"/"fd" must NOT be
        // mistaken for an IPv6 unique-local address (the bracket-vs-colon guard).
        // We can't assert success without a network call, but we CAN assert it is
        // not refused at the guard stage (a refusal is synchronous; a real network
        // failure says "Could not fetch").
        let r = await Web.fetch("http://fc-barcelona.example")
        #expect(!r.hasPrefix("Refused: \"fc-barcelona.example\""))
    }
}

struct SelfImproveEscapeTests {

    @Test func rejectsPathsOutsideProject() {
        #expect(!SelfImprove.isInsideProject("/etc/passwd"))
        #expect(!SelfImprove.isInsideProject("/tmp/evil.swift"))
        #expect(!SelfImprove.isInsideProject("/Users/nobody/elsewhere/File.swift"))
        #expect(!SelfImprove.isInsideProject("/private/var/root/.ssh/authorized_keys"))
    }
}

// MARK: - SSRF guard unit tests (deterministic — operate on the decision
// function directly, so no network I/O and no flakiness).
//
// The redirect guard (RedirectGuard.willPerformHTTPRedirection) reuses this same
// `ssrfRejectionReason`, so testing the function thoroughly also pins the
// redirect-revalidation fix; an actual 30x→localhost test would need a live mock
// server (integration, not unit), so it's intentionally out of scope here.

struct SSRFGuardUnitTests {

    @Test func acceptsPublicHosts() {
        #expect(Web.ssrfRejectionReason(URL(string: "https://example.com")!) == nil)
        #expect(Web.ssrfRejectionReason(URL(string: "https://1.1.1.1")!) == nil)
        // Public IPv6 (Google DNS) must NOT be mistaken for private.
        if let u = URL(string: "https://[2001:4860:4860::8888]") {
            #expect(Web.ssrfRejectionReason(u) == nil)
        }
    }

    @Test func rejectsPrivateIPv6() {
        for s in ["http://[::1]", "http://[fc00::1]", "http://[fd12:3456::1]", "http://[fe80::1]"] {
            if let u = URL(string: s) {
                #expect(Web.ssrfRejectionReason(u) != nil, "should refuse \(s)")
            }
        }
    }

    @Test func rejectsIPv4MappedIPv6() {
        // Dotted IPv4-mapped IPv6 loopback/metadata must not slip through.
        if let u = URL(string: "http://[::ffff:127.0.0.1]") {
            #expect(Web.ssrfRejectionReason(u) != nil)
        }
        // The embedded-v4 classifier directly (no URL-parsing dependency).
        #expect(Web.isPrivateIPv4("127.0.0.1"))
        #expect(Web.isPrivateIPv4("169.254.169.254"))
    }

    @Test func isPrivateIPv4Classifies() {
        #expect(Web.isPrivateIPv4("127.0.0.1"))
        #expect(Web.isPrivateIPv4("10.1.2.3"))
        #expect(Web.isPrivateIPv4("192.168.0.1"))
        #expect(Web.isPrivateIPv4("169.254.0.1"))
        #expect(Web.isPrivateIPv4("172.16.0.1"))
        #expect(Web.isPrivateIPv4("172.31.255.255"))
        #expect(!Web.isPrivateIPv4("8.8.8.8"))
        #expect(!Web.isPrivateIPv4("1.2.3.4"))
        #expect(!Web.isPrivateIPv4("172.32.0.1"))   // just outside 172.16–31
        #expect(!Web.isPrivateIPv4("not-an-ip"))
    }
}
