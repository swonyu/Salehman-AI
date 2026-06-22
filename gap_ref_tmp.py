def opening_gap(opens, closes, baseline_bars=20):
    if len(opens) < 2 or len(closes) < 2:
        return None
    latest = (opens[-1] - closes[-2]) / closes[-2] * 100.0
    gaps = []
    for i in range(1, len(opens)):
        if i < len(closes) and closes[i-1] != 0:
            gaps.append(abs(opens[i] - closes[i-1]) / closes[i-1] * 100.0)
    if not gaps:
        return None
    sample = gaps[-baseline_bars:]
    baseline = sum(sample) / len(sample)
    return (latest, baseline)

def avoid_open_entry(gap_pct, baseline_gap_pct, trend_ok):
    anomalous = abs(gap_pct) >= 3.0 * max(baseline_gap_pct, 1e-9) and abs(gap_pct) >= 1.0
    if not anomalous:
        return False
    if trend_ok is True:
        return False
    return True

closesA = [100.0] * 21
opensA = [100.2] * 20 + [100.2]
rA = opening_gap(opensA, closesA)
print("A:", rA, "avoid=", avoid_open_entry(rA[0], rA[1], False))

closesB = [100.0] * 21
opensB = [100.5] * 20 + [106.0]
rB = opening_gap(opensB, closesB)
print("B:", rB, "avoid=", avoid_open_entry(rB[0], rB[1], False))

rC = opening_gap(opensB, closesB)
print("C:", rC, "avoid=", avoid_open_entry(rC[0], rC[1], True))

print("D <2 ->", opening_gap([], []))
closesE = [100.0] * 21
opensE = [100.0] * 21
rE = opening_gap(opensE, closesE)
print("   all-equal:", rE, "-> baseline 0; spec says gate to nil/no-flag")
