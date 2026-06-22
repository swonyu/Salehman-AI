# Accessibility backlog (accessibility-audit wbee4epc0, 2026-06-22)

5 agents -> 11 a11y items (exact line+fix).

## Top quick wins
- Refresh button hit target: MarketsView.swift line 327 — change `.frame(width: 30, height: 30)` to `.frame(width: 44, height: 44)` (or add `.contentShape(Circle())` + keep the 30pt visual but pad to 44). One-line, zero-risk, fixes the only top-bar control that's below the 44pt floor.
- Search-field labels: add `.accessibilityLabel("Search RuneScape items")` to RuneScapeMarketView.swift TextField (line 159, after `.focused($searchFocused)`) and `.accessibilityLabel("Search markets")` to BrowseMarketsView.swift TextField (line 61). Both currently expose only placeholder text, which VoiceOver drops once typing starts. Two lines, batchable.
- R-multiple distribution bars (MarketsView.swift 1087-1098) are pure color (red bins 0-1, green bins 2+) with no VoiceOver text. Add `.accessibilityElement(children: .ignore).accessibilityLabel("\(bin.label): \(bin.count) trades")` to each bar's VStack (line 1089). Highest-value chart fix — the histogram is otherwise invisible to VoiceOver.
- Grid container labels: add `.accessibilityElement(children: .contain).accessibilityLabel(...)` to the market heatmap LazyVGrid (MarketsView.swift 1581, e.g. "Market heatmap, \(store.symbols.count) symbols by price change") and the correlation grid VStack (line 882). Individual tiles/cells are already labeled; the container just needs a heading so VoiceOver users know a grid follows. Use `.contain` not `.combine` so per-cell labels survive.

## Backlog
### ⬜ #1 — Refresh button hit target below 44pt
**File:** Salehman AI/Views/MarketsView.swift:327
**Fix:** Change `.frame(width: 30, height: 30)` on the refresh icon to `.frame(width: 44, height: 44)`, OR keep the 30pt circle visual and add `.contentShape(Circle())` with surrounding padding so the tappable region reaches 44x44. Only sub-44pt control in the Markets header. One line, zero risk.

### ⬜ #2 — R-multiple distribution histogram bars are color-only / invisible to VoiceOver
**File:** Salehman AI/Views/MarketsView.swift:1087
**Fix:** On each bar VStack (line 1089) add `.accessibilityElement(children: .ignore)` + `.accessibilityLabel("\(bin.label): \(bin.count) trades")`. Bars use red for bins 0-1 and green otherwise (line 1092) with no text alternative; counts/labels exist visually but the bar conveys magnitude by color+height only.

### ⬜ #3 — RuneScape & Browse search fields expose only placeholder, no accessibilityLabel
**File:** Salehman AI/Views/RuneScapeMarketView.swift:159
**Fix:** Add `.accessibilityLabel("Search RuneScape items")` after `.focused($searchFocused)` on the RuneScape TextField (line 159), and `.accessibilityLabel("Search markets")` on the BrowseMarketsView TextField (BrowseMarketsView.swift:61). Placeholder text is dropped by VoiceOver once a value is entered, leaving the field unlabeled.

### ⬜ #4 — Heatmap & correlation grids lack a container announcement
**File:** Salehman AI/Views/MarketsView.swift:1581
**Fix:** Add `.accessibilityElement(children: .contain).accessibilityLabel("Market heatmap, \(store.symbols.count) symbols by price change")` to the heatmap LazyVGrid (line 1581) and `.accessibilityElement(children: .contain).accessibilityLabel("Correlation heatmap, \(c.symbols.count) symbols")` to the correlation grid VStack (line 882). Use `.contain` (NOT `.combine`) so the already-present per-tile/per-cell labels are preserved as children.

### ⬜ #5 — Detail-sheet & compounding sparklines hidden from VoiceOver with no text summary
**File:** Salehman AI/Views/MarketsView.swift:2688
**Fix:** Replace `.accessibilityHidden(true)` on the detail-sheet Sparkline (line 2691) with `.accessibilityElement(children: .ignore).accessibilityLabel("Price sparkline, \(sparkTrendWord(idea.spark)), high \(fmt(max)), low \(fmt(min))")`. Do the same for the compounding sparkline (line 1064, currently unlabeled inside a combined parent). The idea-card sparkline at line 2068 is already covered by the card's `.combine` label, so leave it hidden.

### ⬜ #6 — Conviction meter gauge has no accessibilityValue
**File:** Salehman AI/Views/MarketsView.swift:3029
**Fix:** In `convictionMeter` add `.accessibilityElement(children: .ignore).accessibilityValue("\(Int(min(max(value,0),1) * 100)) percent")` to the GeometryReader. In the idea card the conviction % is already in the combined label, and the detail sheet pairs it with a visible 'Conviction X%' Text (line 2695) — so this is a polish-level gap, but the bare meter element is currently unlabeled when focused directly.

### ⬜ #7 — Fixed .system(size:) caption text does not scale with Dynamic Type (MarketsView)
**File:** Salehman AI/Views/MarketsView.swift:844
**Fix:** Add `@ScaledMetric(relativeTo: .caption2) private var mvFont10: CGFloat = 10` and `mvFont11 = 11`, `mvFont13 = 13` near the existing mvFont7/8/9 (line 35-37), then replace the literal `.system(size: 10/11/13)` calls at lines 844, 847, 1085, 1103, 1118, 1133, 1148, 1188 and the add-holding/add-trade fields (611, 1263, 1485) with the scaled vars. mvFont7/8/9 already scale; these were missed.

### ⬜ #8 — Fixed .system(size: 11/12/13) in RuneScape & Browse views don't scale
**File:** Salehman AI/Views/RuneScapeMarketView.swift:351
**Fix:** RuneScapeMarketView already has rsFont8/9 (lines 17-18); add `rsFont11 = 11` and `rsFont13 = 13` and apply to priceColumn value (line 351), fastest-flip name/value (212, 217, 219), and search/title text. In BrowseMarketsView add `@ScaledMetric(relativeTo: .caption2)` vars for the literal sizes at lines 51, 62, 86, 106, 107, 111, 117.

### ⬜ #9 — BrowseMarketsView rows: add/check button hit target undersized
**File:** Salehman AI/Views/BrowseMarketsView.swift:116
**Fix:** The plus/checkmark Image buttons (lines 111-120) sit in a row with `.padding(.vertical, 4)` (line 123), giving ~24pt height. Add `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` to the add Button (line 116) so its tappable region meets 44x44, and bump row padding toward `.padding(.vertical, 8)`.

### ⬜ #10 — Decorative magnifying-glass icons not hidden from VoiceOver
**File:** Salehman AI/Views/RuneScapeMarketView.swift:158
**Fix:** Add `.accessibilityHidden(true)` to the magnifyingglass Image at RuneScapeMarketView.swift:158 and BrowseMarketsView.swift:60. They are non-interactive decoration; without hiding, VoiceOver announces 'magnifying glass image' before the (now-labeled) search field. Low impact, trivial.

### ⬜ #11 — BrowseMarketsView asset-class Picker label hidden from sighted users
**File:** Salehman AI/Views/BrowseMarketsView.swift:71
**Fix:** The Picker uses `.labelsHidden()` (line 74), hiding the 'Asset class' label from sighted users. The segmented options (All/Stocks/ETFs/...) are self-describing, so VoiceOver is fine, but for visual clarity optionally add a small `Text("Asset class").font(.caption2).foregroundStyle(.secondary)` above. Cosmetic; lowest priority.
