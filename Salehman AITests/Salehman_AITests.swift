import Testing
import Foundation
@testable import Salehman_AI

// MARK: - ShellTool blocklist

struct ShellToolTests {
    @Test func blocksDestructiveRm() throws {
        #expect(Shell.isBlocked("rm -rf /") != nil)
        #expect(Shell.isBlocked("rm -rf ~") != nil)
        #expect(Shell.isBlocked("rm -rf ~/") != nil)
        #expect(Shell.isBlocked("rm -fr /") != nil)
    }

    @Test func blocksForkBomb() throws {
        #expect(Shell.isBlocked(":(){:|:&};:") != nil)
    }

    @Test func blocksDiskOps() throws {
        #expect(Shell.isBlocked("dd if=/dev/zero of=/dev/disk2") != nil)
        #expect(Shell.isBlocked("diskutil eraseDisk JHFS+ x disk2") != nil)
        #expect(Shell.isBlocked("mkfs.ext4 /dev/sda1") != nil)
    }

    @Test func blocksSystemControl() throws {
        #expect(Shell.isBlocked("shutdown -h now") != nil)
        #expect(Shell.isBlocked("reboot") != nil)
        #expect(Shell.isBlocked("sudo rm something") != nil)
        #expect(Shell.isBlocked("csrutil disable") != nil)
    }

    @Test func allowsBenignCommands() throws {
        #expect(Shell.isBlocked("ls -la") == nil)
        #expect(Shell.isBlocked("sw_vers") == nil)
        #expect(Shell.isBlocked("echo hello") == nil)
        #expect(Shell.isBlocked("df -h") == nil)
    }

    @Test func runEchoReturnsOutput() throws {
        let result = Shell.run("echo SalehmanAI_OK", timeout: 5)
        #expect(result.exitCode == 0)
        #expect(result.timedOut == false)
        #expect(result.output.contains("SalehmanAI_OK"))
    }

    @Test func runHonoursTimeout() throws {
        let result = Shell.run("sleep 5", timeout: 1)
        #expect(result.timedOut == true)
    }

    // --- Hardened blocklist: case-insensitivity, chaining, path prefixes,
    //     expanded patterns, and NO over-blocking of benign commands. ---

    @Test func blockListIsCaseInsensitive() throws {
        #expect(Shell.isBlocked("RM -RF /") != nil)
        #expect(Shell.isBlocked("Sudo rm file") != nil)
        #expect(Shell.isBlocked("ReBoot") != nil)
        #expect(Shell.isBlocked("Chmod -R 000 /") != nil)
    }

    @Test func blocksChainedAndIndirectDangerousCommands() throws {
        // A destructive command hidden after a separator must still be caught.
        #expect(Shell.isBlocked("echo hi && sudo rm -rf /tmp/x") != nil)
        #expect(Shell.isBlocked("ls; reboot") != nil)
        #expect(Shell.isBlocked("true | killall Finder") != nil)
        // Variable-indirection bypass: blocked because `eval` is a refused command.
        #expect(Shell.isBlocked("export CMD=foo; eval $CMD") != nil)
    }

    @Test func blocksPathPrefixedDangerousCommands() throws {
        #expect(Shell.isBlocked("/sbin/reboot") != nil)
        #expect(Shell.isBlocked("/usr/bin/sudo whoami") != nil)
    }

    @Test func blocksExpandedDestructivePatterns() throws {
        #expect(Shell.isBlocked("chmod -R 777 /") != nil)
        #expect(Shell.isBlocked("chown -R root /etc") != nil)
        #expect(Shell.isBlocked("launchctl unload -w /System/x.plist") != nil)
        #expect(Shell.isBlocked("diskutil reformat disk2") != nil)
    }

    @Test func allowsBenignCommandsThatLookScary() throws {
        // Token-aware matching must NOT over-block these safe, common commands.
        #expect(Shell.isBlocked("chmod +x build.sh") == nil)              // not recursive/zeroing
        #expect(Shell.isBlocked("git commit -m 'halt the bug'") == nil)   // 'halt' is an arg, not the command
        #expect(Shell.isBlocked("ps aux | grep node") == nil)            // 'grep' segment leader is safe
        #expect(Shell.isBlocked("ls /dev") == nil)                       // listing /dev is fine; /dev/disk is the trigger
    }
}

// MARK: - MarkdownText caching + parsing

struct MarkdownTextTests {
    @Test func splitsCodeAndText() throws {
        let body = """
        Here is some text.

        ```swift
        let x = 1
        ```

        And more text.
        """
        let segments = MarkdownText.segments(for: body)
        #expect(segments.count == 3)
        if case .text(let t) = segments[0] {
            #expect(t.contains("some text"))
        } else { Issue.record("Expected text first") }
        if case .code(let lang, let code) = segments[1] {
            #expect(lang == "swift")
            #expect(code.contains("let x = 1"))
        } else { Issue.record("Expected code second") }
        if case .text(let t) = segments[2] {
            #expect(t.contains("more text"))
        } else { Issue.record("Expected text third") }
    }

    @Test func returnsIdenticalCachedSegments() throws {
        let body = "Plain text body for cache key check."
        let a = MarkdownText.segments(for: body)
        let b = MarkdownText.segments(for: body)
        #expect(a.count == b.count)
    }

    @Test func emptyStringYieldsNoSegments() throws {
        #expect(MarkdownText.segments(for: "").isEmpty)
        #expect(MarkdownText.segments(for: "   \n   ").isEmpty)
    }
}

// MARK: - ChatMessage codec round-trip (in-memory; doesn't touch user data)

struct ChatMessageCodecTests {
    @Test func encodesAndDecodesIdentically() throws {
        let original = [
            ChatMessage(id: UUID(), text: "hi", isUser: true, timestamp: Date()),
            ChatMessage(id: UUID(), text: "hello", isUser: false, timestamp: Date(),
                        imagePath: "/tmp/x.png")
        ]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([ChatMessage].self, from: data)
        #expect(decoded.count == original.count)
        #expect(decoded.last?.text == "hello")
        #expect(decoded.last?.imagePath == "/tmp/x.png")
    }
}
