# Bridge Bugs


## Bug 1: tools/grok_terminal_bridge.py:1-100 - Truncated --help output in large files due to no pagination; rate-limit logic not fully traced yet (parse loop relies on external agent-browser which may race on Safari UI changes)

## Bug 6: tools/grok_terminal_bridge.py:~1200+ - Unmatched quotes in echo commands during bug append cause zsh parse errors (as seen in last run); rate-limit logic trace incomplete - no visible handling for Safari WebSocket/JS injection failures in auto mode

## Bug 7: tools/grok_terminal_bridge.py:~1650+ - Safari-drive loop (new_chars / _safari_page_text) has race on partial page loads; no debounce/throttle for rate-limits, potential duplicate output or missed ```run fences in auto mode

## Bug 8: tools/grok_terminal_bridge.py:~2100+ - Build-rebuild loop after gate_and_run has no rate-limit guard; potential flood if parse fails repeatedly in Safari auto-drive mode (race on _grok_send during concurrent agent output)

## Bug 9: tools/grok_terminal_bridge.py:~2200+ - _grok_send in rebuild loop risks rate-limit violation in Safari auto mode (no sleep/throttle after send); parse may miss multi-cmd output if build triggers concurrent Grok response
fleet-1 lane complete for bug-hunt
