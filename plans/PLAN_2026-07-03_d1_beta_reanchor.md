# PLAN 2026-07-03 — D-1 Beta drop-refit re-anchor · D-2 allInCost deletion · D-3 MonteCarlo guard

> Executor: follow `.claude/skills/executing-plans` + `gated-scope` + `spec-fidelity` (read them
> before Step 1). STOP on any mismatch between this plan and the tree; a step is DONE only when
> its verification command's actual OUTPUT is pasted and proves the behavior fired.

## 0. Plan metadata

- **Plan:** `plans/PLAN_2026-07-03_d1_beta_reanchor.md`
- **Written against:** HEAD `0f32d31` in worktree
  `/private/tmp/claude-501/-Users-saleh/d87fcfd1-345c-4e0f-aac3-875ea3d9859d/scratchpad/d1-worktree`
  (branch `ideas-card/d1-beta-reanchor`, cut from `main`). Line numbers are orientation only —
  edits anchor on exact text; missing/non-unique anchor ⇒ STOP.
- **Evidence base:** `/Users/saleh/ai/AUDIT_2026-07-03_math_redteam.md` (D-1/D-2/D-3) + the o1
  adversarial re-derivation (campaign/opus-review-output.json, field result.o1). The o1 review
  CONFIRMED D-1 and corrected the audit: the buggy flat map ships through the STANDARD selector
  route on ~4.4% of inverted-sample runs (worst shipped winProb 1.0 vs base 0.438) — "selector
  masks it" is false. Remediation: re-anchor the intercept whenever the surviving slope clamps
  to 0, both drop branches (mirrors the Platt guard at `StockSageConvictionCalibration.swift:229-237`).
- **Plan-author derivations already done (independent, not copied from o1):** the o1 replica at
  `scratchpad/d1_replica.py` was line-by-line verified against the Swift (init :348, ridge :376,
  Cramer :385-399, update :421, tol 1e-10, drop logic :428-448); the concrete n=40 fixture was
  re-generated, rounded to 6dp, and RE-verified end-to-end after rounding
  (`scratchpad/d1_dump_fixture.py`, `scratchpad/d1_pin_checks.py`). Executor still re-derives in
  Swift (Step 1) — plan-author numbers are cross-checks, not the test's source of truth.
- **Build isolation:** every xcodebuild in this plan runs FROM the worktree with
  `-derivedDataPath '/private/tmp/claude-501/-Users-saleh/d87fcfd1-345c-4e0f-aac3-875ea3d9859d/scratchpad/d1-dd'`.
  Gate on verdict LINES (`** BUILD SUCCEEDED **` / `** TEST SUCCEEDED **`). Never end a turn
  mid-build. WIP-commit after every step; NEVER push.
- **NOT in this plan:** `SOURCE_BUNDLE.md` regen and the merge itself — those belong to the
  `shipping-changes` pipeline when this branch lands on main.

## 1. Goal (one sentence)

A Beta drop-and-refit whose surviving slope clamps to 0 re-anchors to the honest intercept-only
base rate instead of shipping a flat win-prob map above it — plus deletion of the dead
double-charging `allInCost` (D-2) and a `max(1, minTrades)` trap guard in MonteCarloRuin (D-3).

## 2. Owner-gate check (list consulted → verdict)

| Gate | This plan touches it? |
|---|---|
| RANKING #10 (preferVelocity flip) | NO — no ranking-key change |
| F01/F02 (identity-calibration semantics) | NO — identity thin-branch, `buildIdentity`, and `selectCalibration` logic are byte-untouched; the fix lives inside `fitBeta`'s degenerate drop branches only |
| F08 (Conviction vs Signal strength wording) | NO |
| F10 (decimal-comma locale) | NO |
| F03/F44 (weekly gross-vs-net headline) | NO |
| Honesty floor | Strengthened, not touched: the fix makes win-prob maps strictly MORE honest (never overstate the base rate from a clamped fit); backed by audit D-1 + o1 adversarial confirmation + Step-1 hand-derivation |

**ABSOLUTE constraint (gated-scope §1):** every existing `StockSageCalibrationSelectorTests`
pin stays green UNMODIFIED. `git diff` on that file must show ONLY appended tests. If any
existing pin conflicts with the fix → STOP and report; do NOT edit the pin.
Plan-author pre-check: `betaMonotoneOnInvertedSample`'s sample already routes
`aNeg && bNeg → interceptOnly` (replica: σ(c)=0.500000 = its base rate) — untouched by this fix;
no test in the repo references `.dropA`/`.dropB`/`.interceptOnly`.

**Verdict: NOT GATED — proceed.**

## 3. Exact file list

1. `Salehman AI/StockSage/StockSageConvictionCalibration.swift` — edit (2 locations: drop
   branches; comment-only irls-init note)
2. `Salehman AITests/StockSageCalibrationSelectorTests.swift` — append 1 fixture constant + 2 tests (NO existing line modified)
3. `Salehman AI/StockSage/StockSageNetEdge.swift` — delete 2 blocks (`AllInCost` struct, `allInCost()` func)
4. `Salehman AITests/StockSageNetEdgeTests.swift` — delete 1 test func (`allInCostItemizesEveryLeg`)
5. `Salehman AI/StockSage/StockSageMonteCarloRuin.swift` — edit 1 guard
6. `Salehman AITests/StockSageMonteCarloRuinTests.swift` — append 1 test
7. `MARKETS_TAB_MAP.md` — 3 entry updates (NetEdge, ConvictionCalibration, MonteCarloRuin)
8. `DEVELOPMENT_LOG.md` — append entry LAST (owner directive)

**NO other file.** Known references to `allInCost` in `RESEARCH_2026-07-02_week_horizon_velocity.md`,
`TAX_REALCOST.md`, `DEVELOPMENT_LOG.md` (historical entry "#3 takerFeeBps dead-code unit trap")
are dated RECORDS — leave them untouched; the new dev-log entry marks #3 resolved.

## 4. Pre-flight captures

```bash
cd /private/tmp/claude-501/-Users-saleh/d87fcfd1-345c-4e0f-aac3-875ea3d9859d/scratchpad/d1-worktree

# PF-1: tree identity
git rev-parse --short HEAD          # EXPECTED: 0f32d31
git status --short                  # EXPECTED: empty (plans/PLAN_2026-07-03_d1_beta_reanchor.md is already committed)

# PF-2: D-1 anchors
grep -n 'activeFeatures: .dropA)' "Salehman AI/StockSage/StockSageConvictionCalibration.swift"
# EXPECTED: 443:            return BetaCalibration(a: 0.0, b: Swift.max(0.0, b1), c: c1, activeFeatures: .dropA)
grep -n 'activeFeatures: .dropB)' "Salehman AI/StockSage/StockSageConvictionCalibration.swift"
# EXPECTED: 447:            return BetaCalibration(a: 0.0, b: 0.0, c: c1, activeFeatures: .dropB)
# NOTE: :447 reads `a: Swift.max(0.0, a1), b: 0.0` — verify the FULL line with sed:
sed -n '444,448p' "Salehman AI/StockSage/StockSageConvictionCalibration.swift"
# EXPECTED (verbatim):
#         } else {
#             // Drop x2 (-ln(1-s)), refit with x1 only.
#             let (c1, a1, _) = irls(includeX1: true, includeX2: false)
#             return BetaCalibration(a: Swift.max(0.0, a1), b: 0.0, c: c1, activeFeatures: .dropB)
#         }
grep -n 'Init: intercept = ln((nNeg+1)/(nPos+1))' "Salehman AI/StockSage/StockSageConvictionCalibration.swift"
# EXPECTED: 347 (one hit, inside irls)

# PF-3: D-2 anchors + reference census
grep -n 'struct AllInCost' "Salehman AI/StockSage/StockSageNetEdge.swift"     # EXPECTED: 36
grep -n 'static func allInCost' "Salehman AI/StockSage/StockSageNetEdge.swift" # EXPECTED: 73
git grep -ln "allInCost\|AllInCost\|dominantLeg" -- ':!SOURCE_BUNDLE.md' ':!External Artifacts' ':!*_ARCHIVE.md'
# EXPECTED (exactly these 6): DEVELOPMENT_LOG.md, MARKETS_TAB_MAP.md,
#   RESEARCH_2026-07-02_week_horizon_velocity.md, Salehman AI/StockSage/StockSageNetEdge.swift,
#   Salehman AITests/StockSageNetEdgeTests.swift, TAX_REALCOST.md
# Any OTHER file (esp. under Salehman AI/) ⇒ NOT dead code ⇒ STOP.

# PF-4: D-3 anchor
grep -n 'guard rs.count >= minTrades' "Salehman AI/StockSage/StockSageMonteCarloRuin.swift"
# EXPECTED: 40:        guard rs.count >= minTrades, riskFraction > 0, horizon > 0, sims > 0 else { return nil }

# PF-5: collision check for new symbols
grep -rn "clampedDropAFixture\|betaClampedDrop\|degenerateMinTradesZero" "Salehman AI" "Salehman AITests" --include="*.swift"
# EXPECTED: no output

# PF-6: green baseline build
xcodebuild -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath '/private/tmp/claude-501/-Users-saleh/d87fcfd1-345c-4e0f-aac3-875ea3d9859d/scratchpad/d1-dd' build 2>&1 | tee /tmp/salehman_build.log | tail -5
# EXPECTED: contains ** BUILD SUCCEEDED **

# PF-7: baseline @Test count
grep -ch '@Test' "Salehman AITests"/*.swift | awk '{s+=$1} END {print s}'
# EXPECTED: 1502
```

## 5. Steps

### Step 1 — Standalone Swift hand-derivation of the D-1 fixtures

Write `/tmp/derive_d1_beta.swift` — a standalone replica of `fitBeta` (:325-449). It imports
NOTHING from the app. Full script (write verbatim):

```swift
// derive_d1_beta.swift — standalone replica of StockSageConvictionCalibration.fitBeta
// (Swift :325-449 at 0f32d31). Run: swift /tmp/derive_d1_beta.swift
import Foundation

let eps = 1e-6
typealias Row = (x0: Double, x1: Double, x2: Double, y: Double)

func irls(_ rows: [Row], nPos: Int, nNeg: Int, includeX1: Bool, includeX2: Bool) -> (c: Double, a: Double, b: Double) {
    var c = log((Double(nNeg) + 1.0) / (Double(nPos) + 1.0))
    var a = includeX1 ? 1.0 : 0.0
    var b = includeX2 ? 1.0 : 0.0
    for _ in 0..<25 {
        var g0 = 0.0, g1 = 0.0, g2 = 0.0
        var h00 = 0.0, h01 = 0.0, h02 = 0.0, h11 = 0.0, h12 = 0.0, h22 = 0.0
        for r in rows {
            let z = c * r.x0 + a * r.x1 + b * r.x2
            let p = 1.0 / (1.0 + exp(-z))
            let dz = r.y - p
            let w = max(p * (1.0 - p), 1e-9)
            g0 += dz * r.x0
            if includeX1 { g1 += dz * r.x1 }
            if includeX2 { g2 += dz * r.x2 }
            h00 += w * r.x0 * r.x0
            if includeX1 { h01 += w * r.x0 * r.x1; h11 += w * r.x1 * r.x1 }
            if includeX2 { h02 += w * r.x0 * r.x2; h22 += w * r.x2 * r.x2 }
            if includeX1 && includeX2 { h12 += w * r.x1 * r.x2 }
        }
        let ridge = 1e-8
        h00 += ridge
        if includeX1 { h11 += ridge }
        if includeX2 { h22 += ridge }
        let dc: Double, da: Double, db: Double
        if includeX1 && includeX2 {
            let det = h00*(h11*h22 - h12*h12) - h01*(h01*h22 - h12*h02) + h02*(h01*h12 - h11*h02)
            if abs(det) <= 1e-12 { break }
            let c00 =  (h11*h22 - h12*h12)
            let c01 = -(h01*h22 - h12*h02)
            let c02 =  (h01*h12 - h11*h02)
            let c10 = c01
            let c11 =  (h00*h22 - h02*h02)
            let c12 = -(h00*h12 - h01*h02)
            let c20 = c02
            let c21 = c12
            let c22 =  (h00*h11 - h01*h01)
            dc = (c00*g0 + c10*g1 + c20*g2) / det
            da = (c01*g0 + c11*g1 + c21*g2) / det
            db = (c02*g0 + c12*g1 + c22*g2) / det
        } else if includeX1 {
            let det = h00*h11 - h01*h01
            if abs(det) <= 1e-12 { break }
            dc = (h11*g0 - h01*g1) / det; da = (h00*g1 - h01*g0) / det; db = 0.0
        } else if includeX2 {
            let det = h00*h22 - h02*h02
            if abs(det) <= 1e-12 { break }
            dc = (h22*g0 - h02*g2) / det; da = 0.0; db = (h00*g2 - h02*g0) / det
        } else {
            if abs(h00) <= 1e-12 { break }
            dc = g0 / h00; da = 0.0; db = 0.0
        }
        c += dc; a += da; b += db
        if abs(dc) + abs(da) + abs(db) < 1e-10 { break }
    }
    return (c, a, b)
}

func sigmoid(_ z: Double) -> Double { 1.0 / (1.0 + exp(-z)) }

func derive(_ name: String, _ outcomes: [(Double, Bool)]) {
    let n = outcomes.count
    let nPos = outcomes.filter { $0.1 }.count
    let nNeg = n - nPos
    let rows: [Row] = outcomes.map { o in
        let sc = max(eps, min(1.0 - eps, o.0))
        return (x0: 1.0, x1: log(sc), x2: -log(1.0 - sc), y: o.1 ? 1.0 : 0.0)
    }
    let base = Double(nPos) / Double(n)
    let (c0, a0, b0) = irls(rows, nPos: nPos, nNeg: nNeg, includeX1: true, includeX2: true)
    print("[\(name)] n=\(n) nPos=\(nPos) base=\(String(format: "%.6f", base))")
    print("  full fit a0=\(String(format: "%.4f", a0)) b0=\(String(format: "%.4f", b0))")
    if a0 < 0 && b0 >= 0 {
        let (c1, _, b1) = irls(rows, nPos: nPos, nNeg: nNeg, includeX1: false, includeX2: true)
        print("  branch dropA; x2-only refit c1=\(String(format: "%.6f", c1)) b1=\(String(format: "%.6f", b1)) clamps=\(b1 < 0)")
        print("  PRE-FIX shipped flat = \(String(format: "%.6f", sigmoid(c1)))")
    } else if b0 < 0 && a0 >= 0 {
        let (c1, a1, _) = irls(rows, nPos: nPos, nNeg: nNeg, includeX1: true, includeX2: false)
        print("  branch dropB; x1-only refit c1=\(String(format: "%.6f", c1)) a1=\(String(format: "%.6f", a1)) clamps=\(a1 < 0)")
        print("  PRE-FIX shipped flat = \(String(format: "%.6f", sigmoid(c1)))")
    } else {
        print("  branch \(a0 < 0 ? "interceptOnly" : "full") — NOT the D-1 path ⇒ STOP, fixture invalid")
    }
    let (cH, _, _) = irls(rows, nPos: nPos, nNeg: nNeg, includeX1: false, includeX2: false)
    print("  POST-FIX honest intercept-only = \(String(format: "%.6f", sigmoid(cH))) (must equal base rate)")
    print("  check: sigma(ln(nPos/nNeg)) = \(String(format: "%.6f", sigmoid(log(Double(nPos) / Double(nNeg)))))")
    _ = c0
}

let fixture: [(Double, Bool)] = [
    (0.582699, true), (0.385040, true), (0.622915, true), (0.389157, true),
    (0.741439, false), (0.919539, false), (0.669856, true), (0.532131, false),
    (0.384320, true), (0.181576, true), (0.257043, false), (0.316745, true),
    (0.919362, false), (0.856151, false), (0.249474, false), (0.425918, true),
    (0.489555, true), (0.098954, true), (0.520780, true), (0.321039, true),
    (0.795625, true), (0.771352, false), (0.107302, false), (0.292784, false),
    (0.100518, false), (0.585252, false), (0.515824, true), (0.050360, true),
    (0.217092, false), (0.144426, true), (0.227532, true), (0.628424, true),
    (0.601865, true), (0.613367, false), (0.480133, true), (0.442983, true),
    (0.639978, false), (0.285284, true), (0.852147, false), (0.286969, false)]

derive("fixture", fixture)
derive("mirror", fixture.map { (1.0 - $0.0, !$0.1) })
```

**Verify:** `swift /tmp/derive_d1_beta.swift`

**EXPECTED OUTPUT (verbatim-shape; the 6dp values are load-bearing, the a0/b0 magnitudes are a
non-converged quasi-separated fit and may differ in trailing digits):**
```
[fixture] n=40 nPos=23 base=0.575000
  full fit a0=-9076.4193 b0=6044.6804
  branch dropA; x2-only refit c1=1.198654 b1=-1.161951 clamps=true
  PRE-FIX shipped flat = 0.768285
  POST-FIX honest intercept-only = 0.575000 (must equal base rate)
  check: sigma(ln(nPos/nNeg)) = 0.575000
[mirror] n=40 nPos=17 base=0.425000
  full fit a0=... b0=...
  branch dropB; x1-only refit c1=-1.198654 a1=-1.161951 clamps=true
  PRE-FIX shipped flat = 0.231715
  POST-FIX honest intercept-only = 0.425000 (must equal base rate)
  check: sigma(ln(nPos/nNeg)) = 0.425000
```
If branch/clamp/6dp values disagree with the above → STOP (plan says X / derivation says Y).
Paste this output; the Step-2 test expected values (0.575000 / 0.425000, and the RED values
0.768285 / 0.231715) come from THIS output, not from the app code.

**WIP commit:** none (script lives in /tmp; paste output into the Step-2 test comments).

**HASTY-MODEL TRAP:** using the app's `fitBeta` to produce the expected values — that is the
code under test (F40/NetEdge rule: expected values come ONLY from the standalone derivation).
Second trap: "the mirror is symmetric so I'll skip running it" — run both; the derive output is
the falsifiability record for BOTH tests.

### Step 2 — D-1: red tests first, then the re-anchor fix

**File:** `Salehman AITests/StockSageCalibrationSelectorTests.swift` · **Anchor:** end of test 13.

**OLD (exact, complete — the file tail):**
```swift
        Self.verifyUnitInterval(beta, label: "betaWinProbRange")
    }
}
```

**NEW (exact, complete):**
```swift
        Self.verifyUnitInterval(beta, label: "betaWinProbRange")
    }

    // MARK: - 14. D-1 (2026-07-03): clamped drop-and-refit re-anchors at the honest base rate
    //
    // Fixture hand-derived via the standalone replica /tmp/derive_d1_beta.swift (imports NOTHING
    // from the app; output pasted in the plan/dev-log). Routing proof: this exact sample runs the
    // full fit to a quasi-separated a0<0 (dropA), the x2-only refit lands b1=-1.161951 → clamp —
    // PRE-FIX the co-fitted intercept shipped a FLAT map σ(1.198654)=0.768285 vs base rate
    // 23/40=0.575000 (+0.193 overstatement; the o1-review concrete failing input). POST-FIX the
    // clamped drop branch refits the intercept alone (honest base-rate MLE σ(ln(23/17))=0.575000,
    // labeled .interceptOnly). NB: the both-slopes-negative path would have produced 0.575 even
    // pre-fix — the pre-fix RED value 0.768285 is what proves this fixture exercised dropA.
    private static let clampedDropAFixture: [Outcome] = [
        (conviction: 0.582699, won: true), (conviction: 0.385040, won: true),
        (conviction: 0.622915, won: true), (conviction: 0.389157, won: true),
        (conviction: 0.741439, won: false), (conviction: 0.919539, won: false),
        (conviction: 0.669856, won: true), (conviction: 0.532131, won: false),
        (conviction: 0.384320, won: true), (conviction: 0.181576, won: true),
        (conviction: 0.257043, won: false), (conviction: 0.316745, won: true),
        (conviction: 0.919362, won: false), (conviction: 0.856151, won: false),
        (conviction: 0.249474, won: false), (conviction: 0.425918, won: true),
        (conviction: 0.489555, won: true), (conviction: 0.098954, won: true),
        (conviction: 0.520780, won: true), (conviction: 0.321039, won: true),
        (conviction: 0.795625, won: true), (conviction: 0.771352, won: false),
        (conviction: 0.107302, won: false), (conviction: 0.292784, won: false),
        (conviction: 0.100518, won: false), (conviction: 0.585252, won: false),
        (conviction: 0.515824, won: true), (conviction: 0.050360, won: true),
        (conviction: 0.217092, won: false), (conviction: 0.144426, won: true),
        (conviction: 0.227532, won: true), (conviction: 0.628424, won: true),
        (conviction: 0.601865, won: true), (conviction: 0.613367, won: false),
        (conviction: 0.480133, won: true), (conviction: 0.442983, won: true),
        (conviction: 0.639978, won: false), (conviction: 0.285284, won: true),
        (conviction: 0.852147, won: false), (conviction: 0.286969, won: false)
    ]

    @Test func betaClampedDropARefitAnchorsAtHonestBaseRate() {
        guard let beta = Cal.fitBeta(Self.clampedDropAFixture) else {
            Issue.record("fitBeta returned nil on the D-1 dropA fixture")
            return
        }
        #expect(beta.activeFeatures == .interceptOnly,
                "clamped dropA must re-anchor as interceptOnly, got \(beta.activeFeatures)")
        for s in [0.05, 0.25, 0.5, 0.75, 0.95] {
            let p = beta.winProb(s)
            // derive_d1_beta.swift: POST-FIX honest intercept-only = 0.575000 (= base rate 23/40)
            #expect(abs(p - 0.575) < 1e-6, "honest flat base rate at s=\(s), got \(p)")
            // Honesty floor: NEVER overstate the sample base rate from a clamped fit.
            #expect(p <= 0.575 + 1e-9, "overstates base rate at s=\(s): \(p)")
        }
    }

    @Test func betaClampedDropBRefitAnchorsAtHonestBaseRate() {
        // Exact mirror (s → 1−s, won → !won) of the dropA fixture — lands dropB with
        // a1=-1.161951 clamped; PRE-FIX shipped σ(-1.198654)=0.231715 (an UNDERstated flat map —
        // same single cause, opposite sign); POST-FIX honest base rate 17/40 = 0.425000.
        let mirror: [Outcome] = Self.clampedDropAFixture.map {
            (conviction: 1.0 - $0.conviction, won: !$0.won)
        }
        guard let beta = Cal.fitBeta(mirror) else {
            Issue.record("fitBeta returned nil on the D-1 dropB mirror fixture")
            return
        }
        #expect(beta.activeFeatures == .interceptOnly,
                "clamped dropB must re-anchor as interceptOnly, got \(beta.activeFeatures)")
        for s in [0.05, 0.25, 0.5, 0.75, 0.95] {
            let p = beta.winProb(s)
            // derive_d1_beta.swift: POST-FIX honest intercept-only = 0.425000 (= base rate 17/40)
            #expect(abs(p - 0.425) < 1e-6, "honest flat base rate at s=\(s), got \(p)")
        }
    }
}
```

**Verify (RED first — code not yet fixed):**
```bash
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath '/private/tmp/claude-501/-Users-saleh/d87fcfd1-345c-4e0f-aac3-875ea3d9859d/scratchpad/d1-dd' -only-testing:"Salehman AITests/StockSageCalibrationSelectorTests" 2>&1 | tee /tmp/salehman_build.log | tail -25
grep -E "betaClampedDrop|failed" /tmp/salehman_build.log | head -20
```
**EXPECTED:** `** TEST FAILED **`; ONLY the two new tests fail; the dropA failure message shows
`got 0.768285…` (proves the buggy path fired); every pre-existing test in the suite passes.
Any OTHER failing test ⇒ STOP.

**Then apply the fix. File:** `Salehman AI/StockSage/StockSageConvictionCalibration.swift`

**Edit 2a — OLD (exact, :440-448):**
```swift
        } else if aNeg {
            // Drop x1 (ln s), refit with x2 only.
            let (c1, _, b1) = irls(includeX1: false, includeX2: true)
            return BetaCalibration(a: 0.0, b: Swift.max(0.0, b1), c: c1, activeFeatures: .dropA)
        } else {
            // Drop x2 (-ln(1-s)), refit with x1 only.
            let (c1, a1, _) = irls(includeX1: true, includeX2: false)
            return BetaCalibration(a: Swift.max(0.0, a1), b: 0.0, c: c1, activeFeatures: .dropB)
        }
```

**NEW (exact, complete):**
```swift
        } else if aNeg {
            // Drop x1 (ln s), refit with x2 only.
            let (c1, _, b1) = irls(includeX1: false, includeX2: true)
            // [D-1 2026-07-03] If the surviving slope ALSO fails monotonicity (b1 ≤ 0) the map is
            // flat — but c1 was co-fitted WITH that discarded negative slope and sits above the
            // sample's base-rate log-odds (score equation: mean σ(c1 + b1·x2) = base rate; with
            // b1 < 0 and x2 > 0 for all rows, σ(c1) > base rate strictly). Shipping σ(c1) would
            // overstate win-prob for EVERY conviction band (honesty floor). Mirror the Platt
            // A-clamp B-re-anchor above and the .interceptOnly sibling: refit the intercept
            // alone → the honest base-rate MLE.
            if b1 <= 0 {
                let (c2, _, _) = irls(includeX1: false, includeX2: false)
                return BetaCalibration(a: 0.0, b: 0.0, c: c2, activeFeatures: .interceptOnly)
            }
            return BetaCalibration(a: 0.0, b: b1, c: c1, activeFeatures: .dropA)
        } else {
            // Drop x2 (-ln(1-s)), refit with x1 only.
            let (c1, a1, _) = irls(includeX1: true, includeX2: false)
            // [D-1 2026-07-03] Symmetric guard. A CONVERGED clamped dropB understates (the score-
            // equation sign flips), and a non-converged quasi-separated fit can land here
            // overstating — same single cause (intercept co-fitted with a discarded slope),
            // same re-anchor.
            if a1 <= 0 {
                let (c2, _, _) = irls(includeX1: false, includeX2: false)
                return BetaCalibration(a: 0.0, b: 0.0, c: c2, activeFeatures: .interceptOnly)
            }
            return BetaCalibration(a: a1, b: 0.0, c: c1, activeFeatures: .dropB)
        }
```

**Edit 2b (comment-only; the o1 init nit — VERIFIED by plan author: this file's irls fits
p = σ(+z) (:361) while fitPlatt fits p = σ(−z) (:212), so the copied init is the loss-rate
log-odds). OLD (exact, :346-348):**
```swift
        func irls(includeX1: Bool, includeX2: Bool) -> (c: Double, a: Double, b: Double) {
            // Init: intercept = ln((nNeg+1)/(nPos+1)), slopes = 1 (identity start).
            var c = Foundation.log((Double(nNeg) + 1.0) / (Double(nPos) + 1.0))
```
**NEW:**
```swift
        func irls(includeX1: Bool, includeX2: Bool) -> (c: Double, a: Double, b: Double) {
            // Init: intercept = ln((nNeg+1)/(nPos+1)), slopes = 1 (identity start).
            // [D-1 nit 2026-07-03] Under THIS function's p = σ(+z) convention that intercept init
            // is the smoothed LOSS-rate log-odds — a sign-flipped copy of fitPlatt's B-init (which
            // lives in a p = σ(−z) convention). Harmless at convergence (IRLS is init-independent
            // at the MLE; the intercept-only fit converges to ln(nPos/nNeg) regardless) and
            // deliberately left unchanged; the non-converged quasi-separated cases it could worsen
            // are covered by the clamped-slope re-anchor in the drop branches below.
            var c = Foundation.log((Double(nNeg) + 1.0) / (Double(nPos) + 1.0))
```

**Verify (GREEN):** re-run the same `-only-testing` command as the RED run.
**EXPECTED:** tail contains `** TEST SUCCEEDED **`; log names both `betaClampedDropARefitAnchorsAtHonestBaseRate`
and `betaClampedDropBRefitAnchorsAtHonestBaseRate` as passed; and
`git diff --stat -- "Salehman AITests/StockSageCalibrationSelectorTests.swift"` shows insertions ONLY
(pin-gate: confirm with `git diff` that no existing test line changed).

**WIP commit:**
```bash
git add "Salehman AI/StockSage/StockSageConvictionCalibration.swift" "Salehman AITests/StockSageCalibrationSelectorTests.swift"
git commit -m "WIP(d1): D-1 Beta clamped drop-refit re-anchors to honest base rate + red-first fixtures"
```

**HASTY-MODEL TRAP:** "the two new tests are red, so I'll tweak the expected value to what the
code prints" — NEVER re-assert (NetEdge scar); 0.575000/0.425000 come from Step 1's derivation.
Second trap: touching an existing pin "just to make the diff cleaner" — the pin file is
append-only in this plan (gated-scope ABSOLUTE); a pin conflict = STOP, not an edit.

### Step 3 — D-2: delete dead `allInCost` (+ orphan test, + stale map prose)

**File:** `Salehman AI/StockSage/StockSageNetEdge.swift` — two deletions.

**Edit 3a — OLD (exact, :32-50 + trailing blank line) → NEW: (nothing — delete the block):**
```swift
/// The round-trip cost broken into its real legs (all in price units PER SHARE) so the owner
/// can see WHICH friction eats the edge — not just one collapsed number. Every leg is a LABELED
/// ESTIMATE, never a venue quote. Spread/slippage bps are round-trip by convention; the taker
/// fee is charged on BOTH fills; financing is the overnight/borrow leg (0 for a same-day cash long).
struct AllInCost: Sendable, Equatable {
    let spreadCost: Double
    let slippageCost: Double
    let commissionCost: Double
    let financingCost: Double
    let takerFeeCost: Double
    nonisolated var total: Double { spreadCost + slippageCost + commissionCost + financingCost + takerFeeCost }
    /// The largest single leg — the "what's eating the edge" line for the UI.
    nonisolated var dominantLeg: String {
        let legs: [(String, Double)] = [("spread", spreadCost), ("slippage", slippageCost),
                                        ("commission", commissionCost), ("financing", financingCost),
                                        ("takerFee", takerFeeCost)]
        return legs.max { $0.1 < $1.1 }?.0 ?? "spread"
    }
}

```

**Edit 3b — OLD (exact, :69-83 + trailing blank line) → NEW: (nothing — delete the block):**
```swift
    /// Itemize the round-trip friction per share. ADDITIVE — `evaluate()` is untouched. Financing
    /// is rate·holdDays (0 for a same-day or cash position — the caller passes the borrow rate only
    /// when it applies); the taker fee is charged on BOTH fills (the crypto "GE-2% tax" analog).
    /// All bps/rates are caller-supplied LABELED ESTIMATES, never scraped venue numbers.
    nonisolated static func allInCost(entry: Double, spreadBps: Double = 0, slippageBps: Double = 0,
                                      commissionPerShare: Double = 0, takerFeeBps: Double = 0,
                                      annualFinancingRate: Double = 0, holdDays: Double = 0) -> AllInCost {
        let e = Swift.max(0, entry)
        return AllInCost(
            spreadCost: e * Swift.max(0, spreadBps) / 10_000,
            slippageCost: e * Swift.max(0, slippageBps) / 10_000,
            commissionCost: Swift.max(0, commissionPerShare),
            financingCost: e * Swift.max(0, annualFinancingRate) * Swift.max(0, holdDays) / 365,
            takerFeeCost: e * 2 * Swift.max(0, takerFeeBps) / 10_000)   // both fills
    }

```

**Edit 3c — File:** `Salehman AITests/StockSageNetEdgeTests.swift` — OLD (exact, the whole test
func :24-37 + trailing blank line) → NEW: (nothing — delete the block):
```swift
    @Test func allInCostItemizesEveryLeg() {
        // entry 100, 8bps spread, 5bps slip, $0.04 comm → 0.08/0.05/0.04, total 0.17, dominant spread.
        let c = NE.allInCost(entry: 100, spreadBps: 8, slippageBps: 5, commissionPerShare: 0.04)
        #expect(abs(c.spreadCost - 0.08) < 1e-9 && abs(c.slippageCost - 0.05) < 1e-9 && abs(c.commissionCost - 0.04) < 1e-9)
        #expect(abs(c.total - 0.17) < 1e-9 && c.dominantLeg == "spread")
        // Financing only on a held position: same-day → 0; 10-day at 6% → entry·0.06·10/365.
        #expect(NE.allInCost(entry: 100, annualFinancingRate: 0.06, holdDays: 0).financingCost == 0)
        #expect(abs(NE.allInCost(entry: 100, annualFinancingRate: 0.06, holdDays: 10).financingCost - 100 * 0.06 * 10 / 365) < 1e-9)
        // Crypto taker on BOTH fills (the GE-2% analog); equities pay none.
        #expect(abs(NE.allInCost(entry: 50_000, takerFeeBps: 15).takerFeeCost - 150) < 1e-9)
        #expect(NE.allInCost(entry: 100, takerFeeBps: 0).takerFeeCost == 0)
        // dominantLeg names the biggest friction (a thin crypto scalp → taker fee dominates).
        #expect(NE.allInCost(entry: 100, spreadBps: 2, takerFeeBps: 20).dominantLeg == "takerFee")
    }

```

**Edit 3d — File:** `MARKETS_TAB_MAP.md`, the `### StockSageNetEdge.swift` entry — three
surgical prose edits (each OLD string is unique within the file):

1. In **Key symbols:** OLD `AllInCost (struct: spreadCost/slippageCost/commissionCost/financingCost/takerFeeCost/total/dominantLeg), ` → NEW `` (delete), and OLD `allInCost() (itemized legs), ` → NEW `` (delete).
2. In **Consumers:** OLD `MarketsView.swift (netRR convenience wrapper in R:R display, evaluate+allInCost in detail sheet cost breakdown and Copy Plan)` → NEW `MarketsView.swift (netRR convenience wrapper in R:R display, evaluate in detail sheet cost breakdown and Copy Plan)` — the old text was STALE even pre-deletion (plan-author grep: no MarketsView reference to allInCost existed at 0f32d31; source wins over docs, IL-20).
3. In **Gotchas:** OLD `allInCost()'s financingCost is exactly the same rate*days/365 formula as evaluate()'s financingCost leg - one source of truth by documented intent.` → NEW `AllInCost/allInCost() were DELETED 2026-07-03 (audit D-2, the logged "#3 takerFeeBps dead-code unit trap"): its taker-fee leg charged ×2 per-fill while evaluate()/roundTripBps treat takerFeeBps as round-trip (crypto default 20bps = the labeled 70bps total) — +29% cost disagreement had it ever been wired in; deleted rather than fixed since no live path ever called it.`

**Verify:**
```bash
git grep -ln "allInCost\|AllInCost\|dominantLeg" -- ':!SOURCE_BUNDLE.md' ':!External Artifacts' ':!*_ARCHIVE.md'
# EXPECTED (records only): DEVELOPMENT_LOG.md, MARKETS_TAB_MAP.md (the new Gotchas sentence),
#   RESEARCH_2026-07-02_week_horizon_velocity.md, TAX_REALCOST.md — and NOTHING under
#   Salehman AI/ or Salehman AITests/
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath '/private/tmp/claude-501/-Users-saleh/d87fcfd1-345c-4e0f-aac3-875ea3d9859d/scratchpad/d1-dd' -only-testing:"Salehman AITests/StockSageNetEdgeTests" 2>&1 | tee /tmp/salehman_build.log | tail -10
# EXPECTED: ** TEST SUCCEEDED ** (9 remaining NetEdge tests)
```

**WIP commit:** `git add -A && git commit -m "WIP(d1): D-2 delete dead allInCost (double-charged taker) + orphan test + stale map prose"`

**HASTY-MODEL TRAP:** "while I'm here I'll fix the ×2 instead of deleting" — the o1 verdict and
this plan chose DELETE (dead code, convention disagreement, zero live callers); fixing dead code
keeps the trap alive. Also: do NOT touch the allInCost mentions in RESEARCH_*/TAX_REALCOST/old
dev-log entries — they are dated records (§3).

### Step 4 — D-3: `max(1, minTrades)` guard + trap test (red = the actual trap)

**File (test first):** `Salehman AITests/StockSageMonteCarloRuinTests.swift` · **Anchor:** file tail.

**OLD (exact, complete):**
```swift
        #expect(StockSageMonteCarloRuin.caveat.lowercased().contains("independent"))
    }
}
```
**NEW (exact, complete):**
```swift
        #expect(StockSageMonteCarloRuin.caveat.lowercased().contains("independent"))
    }

    @Test func degenerateMinTradesZeroReturnsNilInsteadOfTrapping() {
        // D-3 (2026-07-03): pre-guard, minTrades: 0 with an empty log passed the count guard
        // (0 >= 0) and reached `rng.next() % UInt64(0)` — a runtime division-by-zero trap.
        #expect(StockSageMonteCarloRuin.simulate([], riskFraction: 0.1, minTrades: 0) == nil)
        #expect(StockSageMonteCarloRuin.simulate([], riskFraction: 0.1, minTrades: -5) == nil)
        // A 1-trade log with an explicit minTrades: 1 may still simulate (floor is max(1, minTrades)).
        #expect(StockSageMonteCarloRuin.simulate([tr(110)], riskFraction: 0.1, sims: 100, minTrades: 1) != nil)
    }
}
```

**Verify (RED — the unguarded code TRAPS, which is this test's falsifiability proof):**
```bash
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath '/private/tmp/claude-501/-Users-saleh/d87fcfd1-345c-4e0f-aac3-875ea3d9859d/scratchpad/d1-dd' -only-testing:"Salehman AITests/StockSageMonteCarloRuinTests/degenerateMinTradesZeroReturnsNilInsteadOfTrapping" 2>&1 | tee /tmp/salehman_build.log | tail -15
grep -i "division by zero\|crash\|fatal" /tmp/salehman_build.log | head -3
```
**EXPECTED:** the run FAILS with a crash — grep shows `Fatal error: Division by zero in remainder
operation` (or the runner reports the test crashed). Paste it.

**Then the fix. File:** `Salehman AI/StockSage/StockSageMonteCarloRuin.swift` · **OLD (exact, :40):**
```swift
        guard rs.count >= minTrades, riskFraction > 0, horizon > 0, sims > 0 else { return nil }
```
**NEW:**
```swift
        // [D-3 2026-07-03] Floor at max(1, minTrades): a caller-supplied minTrades <= 0 must not
        // let an empty sample reach the bootstrap draw below (`% UInt64(n)` traps on n == 0).
        guard rs.count >= Swift.max(1, minTrades), riskFraction > 0, horizon > 0, sims > 0 else { return nil }
```

**Edit 4b — File:** `MARKETS_TAB_MAP.md`, `### StockSageMonteCarloRuin.swift` entry, **Invariants:**
OLD `**Invariants:** Returns nil when fewer than minTrades R-defined closed trades exist — refuses to fabricate a scary or falsely comforting number from thin data.` → NEW `**Invariants:** Returns nil when fewer than minTrades R-defined closed trades exist — refuses to fabricate a scary or falsely comforting number from thin data. The guard floors at max(1, minTrades) (D-3 2026-07-03) so a degenerate minTrades <= 0 returns nil instead of trapping on modulo-by-zero.`

**Verify (GREEN):** re-run the full `StockSageMonteCarloRuinTests` suite (same command minus the
trailing `/degenerate…` test name). **EXPECTED:** `** TEST SUCCEEDED **`, both tests named in the log.

**WIP commit:** `git add -A && git commit -m "WIP(d1): D-3 MonteCarloRuin max(1,minTrades) guard + trap test + map note"`

**HASTY-MODEL TRAP:** skipping the RED run "because a crash pollutes the log" — the crash IS the
proof the guard is load-bearing; without it the test is WHIPPYX-green forever. Also don't
"harden" other params (horizon/sims already guarded > 0) — scope fence.

### Step 5 — Calibration map entry, full-suite gate, dev-log, final commit

**Edit 5a — File:** `MARKETS_TAB_MAP.md`, `### StockSageConvictionCalibration.swift` entry,
**Invariants:** OLD `Platt via A<=0 clamp (with B reset to prior log-odds when A was clamped), Beta via drop-and-refit.` → NEW `Platt via A<=0 clamp (with B reset to prior log-odds when A was clamped), Beta via drop-and-refit (D-1 2026-07-03: a drop-refit whose SURVIVING slope also clamps to 0 re-anchors via an intercept-only refit → honest base-rate MLE, labeled interceptOnly — pre-fix it shipped the co-fitted intercept as a flat map ABOVE the base rate, e.g. 0.768 vs 0.575 on the pinned n=40 fixture).`

**Full-suite gate:**
```bash
cd /private/tmp/claude-501/-Users-saleh/d87fcfd1-345c-4e0f-aac3-875ea3d9859d/scratchpad/d1-worktree
xcodebuild test -scheme "Salehman AI" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath '/private/tmp/claude-501/-Users-saleh/d87fcfd1-345c-4e0f-aac3-875ea3d9859d/scratchpad/d1-dd' -only-testing:"Salehman AITests" 2>&1 | tee /tmp/salehman_build.log | tail -25
# on failure only:
grep -E "Test case '.*' failed" /tmp/salehman_build.log | sed -E "s/.*'([^']+)'.*/\1/" | sort -u
grep -c '@Test' "Salehman AITests"/*.swift | awk -F: '{s+=$NF} END {print s}'   # count check
grep -E "betaClampedDropARefit|betaClampedDropBRefit|degenerateMinTradesZero" /tmp/salehman_build.log | head -6
```
**EXPECTED:** `** TEST SUCCEEDED **`; @Test count = **1504** (1502 baseline − 1 deleted + 2 calib + 1 MC);
all three new test names appear in the log as executed.

**Edit 5b — `DEVELOPMENT_LOG.md`:** append just above the "Standing notes" section (find the
anchor with `grep -n "Standing notes" DEVELOPMENT_LOG.md`, do not Read the whole file):

```
## 2026-07-03 · Math red-team fixes: D-1 Beta drop-refit re-anchor · D-2 allInCost deletion · D-3 MonteCarlo guard
**Files:** Salehman AI/StockSage/StockSageConvictionCalibration.swift; Salehman AITests/StockSageCalibrationSelectorTests.swift; Salehman AI/StockSage/StockSageNetEdge.swift; Salehman AITests/StockSageNetEdgeTests.swift; Salehman AI/StockSage/StockSageMonteCarloRuin.swift; Salehman AITests/StockSageMonteCarloRuinTests.swift; MARKETS_TAB_MAP.md; plans/PLAN_2026-07-03_d1_beta_reanchor.md
**What & why:** (D-1, HIGH — AUDIT_2026-07-03_math_redteam.md + o1 adversarial re-derivation) fitBeta's dropA/dropB branches clamped a negative surviving slope to 0 but KEPT the intercept co-fitted with that discarded slope, shipping a flat win-prob map above the sample base rate (pinned o1 failing input: n=40, base 0.575 → shipped 0.768; ~4.4% of inverted-sample runs shipped this through the standard selector route — "selector masks it" was disproved). Now a clamped surviving slope triggers an intercept-only refit (honest base-rate MLE, labeled .interceptOnly), mirroring the Platt A-clamp B-re-anchor; comment-only note added on the irls init sign-flip nit (loss-rate log-odds under the σ(+z) convention; harmless at convergence). 2 fixture tests hand-derived via standalone replica (/tmp/derive_d1_beta.swift), shown red pre-fix (0.768285 / 0.231715) and green post-fix (0.575000 / 0.425000); all pre-existing CalibrationSelectorTests pins green UNMODIFIED. (D-2, latent — resolves logged "#3 takerFeeBps dead-code unit trap") deleted dead AllInCost/allInCost(): its taker leg charged ×2 per-fill vs evaluate()/roundTripBps' round-trip convention (90 vs the labeled 70bps on crypto); zero live callers (grep-proven), orphan test deleted, stale MARKETS_TAB_MAP consumer claim (MarketsView never called it) corrected. (D-3, LOW) MonteCarloRuin.simulate guard floors at max(1, minTrades) — minTrades ≤ 0 with an empty log previously reached `% UInt64(0)` (runtime trap, proven red in the run log); trap test added.
**Result:** <paste the ** TEST SUCCEEDED ** tail line + @Test count 1504 + git diff --stat>
```

**Final commit:**
```bash
git add -A && git commit -m "d1: Beta clamped drop-refit re-anchor (D-1) + allInCost deletion (D-2) + MonteCarlo minTrades guard (D-3)"
git diff main --stat   # paste in report
```

**HASTY-MODEL TRAP:** writing the dev-log **Result** from memory instead of pasting the actual
verdict lines and diff stat (the "72px spacer" scar) — fill the placeholder from the real output.

## 6. Rollback (exact commands)

```bash
cd /private/tmp/claude-501/-Users-saleh/d87fcfd1-345c-4e0f-aac3-875ea3d9859d/scratchpad/d1-worktree
git reset --hard 0f32d31        # worktree branch only; main repo untouched
# to abandon entirely:
git -C /Users/saleh/ai worktree remove --force /private/tmp/claude-501/-Users-saleh/d87fcfd1-345c-4e0f-aac3-875ea3d9859d/scratchpad/d1-worktree
git -C /Users/saleh/ai branch -D ideas-card/d1-beta-reanchor
```

## 7. Done-means (every box = PASTED OUTPUT, not a claim)

- [ ] All pre-flight captures matched (or execution stopped at the first mismatch and reported it).
- [ ] Step-1 derive-script output pasted; test expected values traceable to it, not to app code.
- [ ] D-1 tests shown RED pre-fix (0.768285 visible in the failure) then GREEN post-fix.
- [ ] `git diff -- "Salehman AITests/StockSageCalibrationSelectorTests.swift"` shows appended lines ONLY (owner gate).
- [ ] D-2: reference census grep pasted (no app/test hits); NetEdge suite green.
- [ ] D-3: trap shown red (Fatal error line pasted), guard green.
- [ ] Full-suite `** TEST SUCCEEDED **` with @Test count 1504 and all three new test names in the log.
- [ ] MARKETS_TAB_MAP (3 entries) + DEVELOPMENT_LOG appended; files touched ⊆ §3 list (confirmed by `git diff main --stat`).
- [ ] WIP commit after every step; final commit present; NOTHING pushed.
