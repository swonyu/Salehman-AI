# Journal/portfolio/alerts bughunt (w9ecjev4i, 2026-06-22)

2 CONFIRMED bugs (survived 2-skeptic refute). #1 (alerts long-only crossing — LIVE) is HIGH priority next. RE-VERIFY vs source.

### ⬜ #1 [high] alerts — Stop/target crossing detector is long-only — misses a losing short's stop-out and fires a backwards stopBreach on a winning short
**failingInput:** detect(previous:[Idea("X",price:109,.sell,stop:108,target:84)], current:[Idea("X",price:107,.sell,stop:108,target:84)]) wrongly returns a .stopBreach ('Price 107.00 broke the 108.00 stop', isWarning=true) on a SHORT that is actually winning (price fell 109→107 toward the 84 target). And detect(previous:[Idea("X",107,.sell,stop:108,target:84)], current:[Idea("X",109,.sell,stop:108,target:84)]) returns NO stopBreach even though the short was stopped out at a real loss (price rose 107→109 through the 108 stop).

**fix:** Branch the crossing checks on the idea's side. Keep current geometry for .buy/.strongBuy (long). For .sell/.reduce (short, stop above entry / target below), flip directions: stopBreach when price crosses UP through the stop (`prev.price < stop && idea.price >= stop`) and targetHit when price crosses DOWN through the target (`prev.price > target && idea.price <= target`). Equivalently infer side from stop>price (short) vs stop<price (long). Add short-side tests mirroring stopBreachFiresOnlyOnCrossDown / targetHitFiresOnCrossUp with `.sell` ideas (stop above, target below) — the current StockSageAlertsTests pass only `.buy`, so the short path is uncovered.

### ⬜ #2 [medium] alerts — Same long-only crossing inversion in StockSageAlertDecision.evaluate (latent — no production caller today)
**failingInput:** evaluate(symbol:"X", recommendation:.strongSell, price:109, priorPrice:107, stop:108, target:84, lastAlertedRecommendation:nil) returns nil (real short stop-out at a loss missed); evaluate(..., price:107, priorPrice:109, stop:108, target:84, ...) returns .stopBreach 'the setup is invalidated; risk is realized' on a short whose price fell favorably toward the 84 target. Confirmed grep: no production caller — only StockSageAlertDecision.swift and StockSageAlertDecisionTests.swift reference it, so latent rather than user-facing today.

**fix:** Apply the same side-aware fix so the two detectors agree: pass position side (long vs short) into evaluate(), or infer it from stop>price (short) vs stop<price (long), and flip the stop/target inequality directions for shorts. Cover both detectors with short-side tests so they cannot drift.
