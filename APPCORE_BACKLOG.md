# App-core bug backlog (app-core-bughunt wa84658v8, 2026-06-22)

26 agents, 1.5M tokens -> 8 CONFIRMED bugs. #1 fixed in this commit.

Verified all 8 reported bugs against the actual source. Three persistence findings are genuine and high-value: JSONFileStore.swift:18 `.first!` is a real crash path (ranked #1; the safe fallback already exists in PromptLibrary, so it's a one-liner), and ScratchpadStore.save() (line 123) + PromptLibrary.save() (line 50) silently swallow write errors causing data loss (#2, #3). MemoryStore.persist() (line 30) is the same swallowed-error class, but the reported cross-thread *race* is NOT real — the NSLock serializes all writers — so I down-ranked it to medium (#4) and corrected the framing. The ContentView Vision/MainActor finding (#5) is real but a soft stall not a hard freeze (awaits yield, a spinner is shown). The OllamaClient missing-cancellation (#6) is real but low (local, finite stream). The CommandPalette selectedIndex staleness (#7) is cosmetic. The ChatViewModel append race (#8) is essentially a non-bug: the append at line 167 is already guarded by Task.isCancelled at line 161, and stop() already clears the running flags. Ranking is severity-to-effort: the four one-line persistence fixes lead, perf/UX issues follow, cosmetic/non-bugs last. No invented symbols — every line/method referenced was confirmed present.

## Backlog
### ✅ DONE #1 [high] Force-unwrap crash in JSONFileStore on applicationSupportDirectory lookup
**File:** Salehman AI/Persistence/JSONFileStore.swift
**Fix:** Line 18: replace `.first!` with the safe fallback already used in PromptLibrary.fileURL — `let base = baseDirectory ?? (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory).appendingPathComponent("SalehmanAI", isDirectory: true)`. One-line change, removes the only fatal-crash path in the persistence layer; this store backs MemoryStore and ScratchpadStore so the crash blast radius is wide.

### ✅ DONE #2 [high] Silent data loss in ScratchpadStore.save() (try? swallows every write error)
**File:** Salehman AI/Persistence/ScratchpadStore.swift
**Fix:** Line 123: replace `try? store.save(Snapshot(notes: notes, tasks: tasks))` with `do { try store.save(Snapshot(notes: notes, tasks: tasks)) } catch { NSLog("ScratchpadStore.save failed: %@", error.localizedDescription) }`. save() is called after every mutation (addNote/addTask/toggleTask/delete/clear); on encode or atomic-write failure the in-memory state silently diverges and notes/tasks are lost on next launch.

### ✅ DONE #3 [high] Silent data loss in PromptLibrary.save() (double try? on encode + write)
**File:** Salehman AI/Persistence/PromptLibrary.swift
**Fix:** Line 50: replace `if let data = try? JSONEncoder().encode(prompts) { try? data.write(to: fileURL, options: .atomic) }` with `do { let data = try JSONEncoder().encode(prompts); try data.write(to: fileURL, options: .atomic) } catch { NSLog("PromptLibrary.save failed: %@", error.localizedDescription) }`. Failure abandons user prompt edits in memory; next launch reverts to starters.

### ✅ DONE #4 [medium] MemoryStore.persist() swallows write errors (silent fact loss)
**File:** Salehman AI/Persistence/MemoryStore.swift
**Fix:** Line 30: `private nonisolated func persist() { try? store.save(items) }` discards errors from remember()/delete()/clear(). The NSLock already serializes writers, so the cross-thread race in the original report is NOT real — the actual defect is the swallowed error. Change to `do { try store.save(items) } catch { NSLog("MemoryStore.persist failed: %@", error.localizedDescription) }`. Same one-line class of fix as the other stores.

### ✅ DONE #5 [medium] Main-thread Vision analysis blocks composer when attaching images
**File:** Salehman AI/Views/ContentView.swift
**Fix:** Lines 1442/1455/1466 loop `await AttachmentLoader.load(url:)` on the MainActor; for images load() calls `await VisionAnalyzer.describe(url)` (Attachments.swift:95). Because the awaits are sequential, dropping N images serializes N on-device Vision passes before any attachment appears. Run the loads concurrently with a task group / `async let`, or move VisionAnalyzer.describe onto a detached background task inside load() and only hop back to MainActor to build the Attachment. (Not a hard freeze — awaits yield and attachmentLoads drives a spinner — so medium, not high.)

### ✅ DONE #6 [low] No Task.isCancelled check in OllamaClient.chatStream loop
**File:** Salehman AI/LLM/OllamaClient.swift
**Fix:** Loop at lines 440-457 keeps consuming the byte stream and calling onUpdate after the caller cancels. Add `if Task.isCancelled { break }` at the top of the `for try await line in bytes.lines` body so a cancelled generation frees the local model immediately instead of streaming to completion. Low severity (local stream, finite), trivial fix.

### ✅ VERIFIED-SAFE #7 (no change needed — see note) [low] CommandPalette selectedIndex can go stale on filter/hover change
**File:** Salehman AI/Views/CommandPalette.swift
**Fix:** `.onChange(of: query)` at line 219 only sets `selectedIndex = 0`, but the hover path (line 170) and arrow keys (98-101) set it independently; between a result-list shrink and the next render selectedIndex can exceed filtered.count-1, feeding a stale id to proxy.scrollTo (line 195). Clamp before resetting: `selectedIndex = min(selectedIndex, max(0, filtered.count - 1))`, and clamp in the onHover/arrow handlers too. Cosmetic-only (scroll target), lowest priority.

### ✅ DONE #8 [low] ChatViewModel auto-continue post-loop flag writes after cancel
**File:** Salehman AI/Views/ChatViewModel.swift
**Fix:** The append at line 167 is ALREADY guarded by `if Task.isCancelled { return }` at line 161, so the reported mid-append race does not occur within a turn. The only residual gap is the post-loop flag writes (lines 185-186) and BrainStatus.refresh (190) running after a late cancel — but stop() (lines 26-37) already clears isRunning/aiIsRunning, so this is benign. If hardening anyway, add `guard !Task.isCancelled else { return }` before line 185. Lowest priority; mostly a non-bug.

**2026-06-28 update:** #2-#6, #8 fixed (see DEVELOPMENT_LOG.md 2026-06-28 batch-1 entry). #7 re-verified: the only `selectedIndex` reset path (`onChange(of: query)` → 0) is always in-bounds when `filtered` is non-empty and a harmless no-op when empty — no speculative fix applied.
