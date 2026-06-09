.PHONY: advance advance-push advance-dry ci build test clean open help

advance:
	@./scripts/advance_tracks.sh

advance-push:
	@./scripts/advance_tracks.sh --push

advance-dry:
	@./scripts/advance_tracks.sh --dry-run

ci:
	@echo "Running CI pipeline (build + test + dry-run)..."
	@$(MAKE) -s build
	@$(MAKE) -s test
	@$(MAKE) -s advance-dry
	@echo "CI pipeline complete"

build:
	@echo "Building Salehman AI..."
	@xcodebuild -scheme "Salehman AI" -destination platform=macOS -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)" | tail -20

test:
	@echo "Running tests..."
	@xcodebuild test -scheme "Salehman AI" -destination platform=macOS -configuration Debug CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests" 2>&1 | grep -E "error:|warning:|Test (Suite|Case)|BUILD (SUCCEEDED|FAILED)|Executed" | tail -30

open:
	@open "Salehman AI.xcodeproj"

clean:
	@echo "Cleaning DerivedData..."
	@rm -rf ~/Library/Developer/Xcode/DerivedData/Salehman_AI-*
	@echo "Done"

help:
	@echo "Salehman AI Makefile targets:"
	@echo "  make advance      - Build + test + commit (safe checkpoint)"
	@echo "  make advance-push - Advance + push to origin"
	@echo "  make advance-dry  - Preview what advance would do"
	@echo "  make ci           - Build + test + advance-dry (no commit)"
	@echo "  make build        - Build the app (errors visible)"
	@echo "  make test         - Run unit tests"
	@echo "  make open         - Open in Xcode"
	@echo "  make clean        - Clean DerivedData"
