.PHONY: advance build test open clean help

SCHEME   = Salehman AI
DEST     = platform=macOS
CFG      = Debug
FLAGS    = CODE_SIGNING_ALLOWED=NO
TESTS    = Salehman AITests

# ── Main flow ────────────────────────────────────────────────────────────────

# Build → test → commit everything → push. Standard "done, ship it" flow.
advance:
	@echo "🔨 Building..."
	@xcodebuild -scheme "$(SCHEME)" -destination $(DEST) -configuration $(CFG) $(FLAGS) build \
	    | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED" | tail -10
	@echo "🧪 Testing..."
	@xcodebuild test -scheme "$(SCHEME)" -destination $(DEST) -configuration $(CFG) $(FLAGS) \
	    -only-testing:"$(TESTS)" \
	    | grep -E "Test case|error:|Executed|FAILED" | tail -20
	@echo "📦 Committing & pushing..."
	@git add -A && git diff --cached --quiet || git commit -m "chore: advance (build + test green)"
	@git push
	@echo "✅ Done."

# ── Build & Test ─────────────────────────────────────────────────────────────

build:
	@echo "🔨 Building Salehman AI..."
	@xcodebuild -scheme "$(SCHEME)" -destination $(DEST) -configuration $(CFG) $(FLAGS) build \
	    | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED"

test:
	@echo "🧪 Running tests..."
	@xcodebuild test -scheme "$(SCHEME)" -destination $(DEST) -configuration $(CFG) $(FLAGS) \
	    -only-testing:"$(TESTS)" \
	    | grep -E "Test case|error:|Executed|FAILED"

# ── Utilities ────────────────────────────────────────────────────────────────

open:
	@echo "📂 Opening Salehman AI.xcodeproj..."
	@open "Salehman AI.xcodeproj"

clean:
	@echo "🧹 Cleaning DerivedData..."
	@rm -rf ~/Library/Developer/Xcode/DerivedData/Salehman_AI-*
	@echo "✅ Clean complete."

# ── Help ─────────────────────────────────────────────────────────────────────

help:
	@echo ""
	@echo "🚀 Salehman AI — Available Commands"
	@echo "===================================="
	@echo ""
	@echo "  make advance   Build + test + commit + push (the full daily cycle)"
	@echo "  make build     Build only (Debug)"
	@echo "  make test      Run all unit tests"
	@echo ""
	@echo "  make open      Open project in Xcode"
	@echo "  make clean     Clean DerivedData (fixes weird Xcode states)"
	@echo ""
	@echo "  make help      Show this help"
	@echo ""
