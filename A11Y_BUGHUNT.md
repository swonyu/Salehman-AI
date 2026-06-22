# Accessibility bughunt (woobpb79o, 2026-06-23)

15 CONFIRMED a11y findings on the money surfaces (25 agents, adversarial verify). #1+#2 (HIGH — risk/staleness warnings invisible to VoiceOver) DONE. RE-VERIFY rest vs source.

### ✅ DONE #1 [high] — RuneScape stale-spread warning is dropped from the row's VoiceOver label — launders a stale spread as live
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/RuneScapeMarketView.swift:352-362
**fix:** The row uses .accessibilityElement(children: .combine) then an explicit .accessibilityLabel (353-362) that REPLACES the merged children, discarding the visible '⚠︎ … stale; may not fill at this spread' Text (313-317). Append the stale clause to the label string: after line 362's closing paren, add + (stale ? ", stale — \(priceAge.map(rsAgeLabel) ?? \"\"), may not fill at this spread" : ""). stale/priceAge are already computed at 282-283. This is the safety signal commit edbc2bf added; a VoiceOver owner currently hears a clean fresh-looking spread with zero staleness cue.

### ✅ DONE #2 [high] — Money-velocity drawdown-brake & fast-lane-concentration risk warnings are unreachable by VoiceOver
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift:2554-2564 (warnings) vs 2574 (Button label override)
**fix:** Both ⚠︎ warnings (brake at 2554-2558, concentration at 2560-2564) live inside the label: closure of the Button opened at 2498, which carries an overriding .accessibilityLabel("Money velocity summary; tap for the best opportunity") at 2574. SwiftUI collapses the Button to one leaf, so the inner per-Text .accessibilityLabels are dead. Fix: conditionally fold the two warnings into the Button's accessibilityLabel (mirroring ideaCard at 2297-2299), e.g. append " — warning: drawdown brake …" / " — warning: fast lane concentrated …" when s.worstRunDrawdownPct/worstRunLosses and fastLaneConcentration().isConcentrated fire; OR pull the two warning Texts out of the Button into siblings in the outer VStack (2497) so their existing labels stay live.

### ⬜ #3 [medium] — PSR pass/fail signalled by green-vs-amber tint alone (no glyph, no pass/fail word, no a11y label)
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift:2761-2766
**fix:** The 'Real-edge confidence (PSR)' Text's only verdict affordance is .foregroundStyle(psr > 0.95 ? successSoft : warningSoft) — successSoft (0.45,0.85,0.55) and warningSoft (1.0,0.72,0.35) collapse to the same yellow-green under deuteranopia, so a color-blind owner can't tell a 97% pass from a 92% fail. Add a state-distinct glyph: prepend Image(systemName: psr > 0.95 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"); inject a literal verdict word into the string ("… N% — PASS (>95%)" / "… N% — BELOW BAR (<95%)"); and add .accessibilityLabel(String(format: "Real edge confidence, probabilistic Sharpe ratio %.0f percent, %@ the 95 percent bar.", psr*100, psr > 0.95 ? "passes" : "below")). Move StockSageDeflatedSharpe.caveat to .accessibilityHint. This is the headline 'is the edge real' stat and the one backtest row missing the non-color backup its siblings have.

### ⬜ #4 [medium] — Stale flip-margin chip (opacity 0.45) drops below WCAG AA contrast — faintest exactly when scrutiny matters
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/RuneScapeMarketView.swift:330-336
**fix:** .opacity(stale ? 0.45 : 1) at line 335 composites the chip's 11pt-bold label AND fill together onto the dark card: red loss chip ≈ 2.71:1, green profit chip ≈ 3.22:1 — both under AA 4.5:1 for normal text, on the single most decision-relevant number (net gp kept after tax). Dim only the capsule background, keep the label fully opaque: replace the chip's .background(up ? successSoft : danger, in: Capsule()) + .opacity(0.45) with .background((up ? DS.Palette.successSoft : DS.Palette.danger).opacity(stale ? 0.55 : 1), in: Capsule()) and drop the whole-chip .opacity. The adjacent '⚠︎ … stale' line (313-317) already carries the skeptic signal.

### ⬜ #5 [medium] — PSR row read literally by VoiceOver — 'P(true Sharpe > 0)' loses parens and the load-bearing '>' inverts the honesty threshold
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift:2761-2766
**fix:** Plain Text(String(format: ...)) with only .help (hover-only) and no .accessibilityLabel. VoiceOver speaks '(PSR)' as 'P S R', '>95% is the honest bar' commonly drops the '>' to '95 percent is the honest bar' — inverting the meaning on a money/risk stat. Add .accessibilityLabel(String(format: "Real edge confidence, probabilistic Sharpe ratio %.0f percent. Probability the true Sharpe is above zero after a sample, skew and fat-tail haircut. The honest bar is above 95 percent.", psr*100)) and move StockSageDeflatedSharpe.caveat to .accessibilityHint. (Combine with rank 3's label if doing both at once.)

### ⬜ #6 [medium] — Monte-Carlo forward-ruin journal line has no accessibilityLabel — '@', middle-dots and 'P(ruin)' spoken as punctuation
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift:1172-1177
**fix:** Plain Text with only .help; sits in a plain VStack with no parent .combine, so VoiceOver reads the literal format result — '@' as 'at', U+00B7 dots dropped, 'P(ruin)'/'P(>20% drawdown)' as bare letters with dropped parens, '95th-pct' as '95th hyphen pct'. Add .accessibilityLabel(String(format: "Forward ruin risk from %d simulations at %.0f percent risk per trade. Probability of ruin %.0f percent. Probability of over 20 percent drawdown %.0f percent. 95th percentile maximum drawdown %.0f percent. Bootstrapped from your %d closed trades.", mc.sims, mcRiskFraction*100, mc.pRuin*100, mc.p20DrawdownProb*100, mc.p95MaxDD*100, mc.sampleSize)) and move StockSageMonteCarloRuin.caveat to .accessibilityHint. Gates at minTrades:20.

### ⬜ #7 [medium] — Out-of-sample decay row read without the in→out transition — '→' arrow spoken silently, cause→effect lost
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift:2768-2775
**fix:** Bare Text with no .accessibilityLabel and no parent combine; the U+2192 '→' is read unpredictably (usually dropped), so 'in-sample +0.40R → out-of-sample +0.10R' collapses to two disconnected R-values and the RED-FLAG overfit tail rides the same unstructured string. Add .accessibilityLabel built with '→' replaced by 'falling to': String(format: "Out of sample, kept %.0f percent of the edge. In sample %+.2f R falling to out of sample %+.2f R.", d.decayRatio*100, d.isAvgR, d.oosAvgR) + tail (tail is already speech-safe). Keep the red-flag wording so the warning is announced.

### ⬜ #8 [medium] — Stale gp/hour velocity estimate at opacity 0.5 falls below AA for low-vision readers
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/RuneScapeMarketView.swift:310-311
**fix:** successSoft caption2 (~11pt, normal text) at .opacity(stale ? 0.5 : 1) over the dark card composites to ≈3.36:1, under AA 4.5:1. Raise the stale floor to 0.7 (≈5.3:1, clears AA) or keep the figure full-opacity and rely on the '⚠︎ stale' line (313-317) to mark staleness. Screen-reader path is already covered by the row label, so this is a sighted low-vision fix only.

### ⬜ #9 [medium] — Buy/Sell gp prices fixed at size 13 with no Dynamic-Type scaling or shrink-fit
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/RuneScapeMarketView.swift:368-373
**fix:** priceColumn renders the live Buy/Sell prices at hard-coded .font(.system(size: 13, weight: .semibold, design: .rounded)) (369) in a fixed .frame(width: 64) (373) while the label above scales via rsFont9 — the price is the lone unscaled element. Add @ScaledMetric var rsFont13: CGFloat = 13 (relativeTo: .body), use it at 369, append .lineLimit(1).minimumScaleFactor(0.6), and widen 373 to .frame(minWidth: 64, alignment: .trailing). (RSFormat.gp abbreviates so no truncation at default size; the real defect is non-scaling under enlarged text.)

### ⬜ #10 [medium] — Journal realized-dollars and R-multiples fixed at size 11 in width-locked frames
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift:1229,1244,1263,1281
**fix:** by-month/by-side/by-sector totalR (1229/1263/1281, each in .frame(width: 60)) and yearly realizedDollars (1244) render at hard-coded .font(.system(size: 11, weight: .semibold)) and ignore the in-scope @ScaledMetric mvFont7/8/9 (35-37) added for exactly this. Change each to .font(.system(size: mvFont9 + 2, weight: .semibold)) (or add @ScaledMetric mvFont11), add .lineLimit(1).minimumScaleFactor(0.7), and change the .frame(width: 60) entries to .frame(minWidth: 60, alignment: .trailing).

### ⬜ #11 [medium] — Open/closed-trade per-trade P&L fixed at size 11 with no scale factor
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/MarketsView.swift:1513,1564
**fix:** Open-trade unrealized P&L (1513) and closed-trade realized P&L (1564) render Text(String(format: "%+.2f", pnl)).font(.system(size: 11, weight: .semibold)) — the smallest, non-scaling element in rows whose siblings already scale via mvFont9/.caption2. VoiceOver is covered (.combine labels speak the pnl) but the sighted low-vision path is not. Switch both to .font(.system(size: mvFont9 + 2, weight: .semibold)) (or a new mvFont11) and add .lineLimit(1).minimumScaleFactor(0.7).

### ⬜ #12 [medium] — Red 'Sell' price column below AA at 13pt — asymmetric with the 9.3:1 Buy column
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/RuneScapeMarketView.swift:323,365-370
**fix:** priceColumn("Sell", price.low, color: DS.Palette.danger) renders pure Color.red at 13pt semibold (not large text) ≈ 4.08:1 on codeSurface, under AA 4.5:1, while the Buy column uses successSoft at 9.3:1. Add a 'dangerSoft' swatch ≈ Color(red:1.0,green:0.45,blue:0.45) (≈6.2:1) to DS.Palette and use it for the Sell price (and the loss chip), mirroring how successSoft replaced Color.green for Buy.

### ⬜ #13 [medium] — 'Best ROI/cycle' recommendation unreadable: saturated-red accent at 9pt ≈3.82:1
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/RuneScapeMarketView.swift:230-232
**fix:** The 'Best ROI/cycle: …' line (most-capital-efficient item to flip) renders in DS.Palette.accent (0.98,0.18,0.29 saturated red) at rsFont9 (9pt) on the warningSoft@0.06 strip ≈ 3.82:1, under AA for small text. Recolor to .white.opacity(0.85) (~11:1) or DS.Palette.warningSoft (~8.4:1); reserve accent for non-text emphasis.

### ⬜ #14 [low] — Net flip-margin chip fixed at size 11 in a locked 70pt frame — no Dynamic Type, no shrink-fit
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/RuneScapeMarketView.swift:330-336
**fix:** The NET flip-margin number renders .font(.system(size: 11, weight: .bold)) (331) inside .frame(width: 70) (336) with no @ScaledMetric and no .minimumScaleFactor, so it can't grow with enlarged text nor shrink to fit. Drive size off a scaled metric (rsFont9 + 2 or a new rsFont11), add .lineLimit(1).minimumScaleFactor(0.7), and relax 336 to .frame(minWidth: 70, alignment: .trailing). Lower urgency: value is duplicated in the .help tooltip and row a11y label.

### ⬜ #15 [low] — Loss-state margin chip (white on Color.red) below AA even when not stale
**file:** /Users/saleh/Desktop/Salehman AI/Salehman AI/Views/RuneScapeMarketView.swift:330-334
**fix:** Negative net renders white text on a DS.Palette.danger (pure/system red) capsule ≈ 3.55–4.0:1, under AA 4.5:1 for the 11pt-bold label, while the profit chip uses near-black on successSoft (~10.9:1). Either darken the loss background (a deeper red than Color.red gives white more headroom) or switch to dark text on the proposed dangerSoft (rank 12), mirroring the profit chip. Confirm ≥4.5:1.
