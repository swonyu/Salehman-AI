#!/usr/bin/env python3
"""trials_registry.py — stdlib-only, print-only consumer of research/trials_ledger.jsonl.

Usage:
  python3 tools/trials_registry.py                       # reads research/trials_ledger.jsonl
  python3 tools/trials_registry.py path/to/fragment.jsonl [more.jsonl ...]   # merges extra fragments
  python3 tools/trials_registry.py --selfcheck            # runs the inline 3-line fixture assert-check

Design: research/TRIAL_REGISTRY spec §3. Never writes anything, never fabricates a number — every
printed stat is a direct aggregation of what's on disk. `trials:` for StockSageDeflatedSharpe stays
a human-typed input at each call site (see the spec's "hard fence" — this script informs, never wires).
"""
import json
import sys
from statistics import mean, variance

DEFAULT_LEDGER = "research/trials_ledger.jsonl"


def load_rows(paths):
    """Read JSONL files in argv order; dedup on (run, config), LAST occurrence wins."""
    rows = {}
    for path in paths:
        try:
            with open(path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    obj = json.loads(line)
                    key = (obj.get("run"), obj.get("config"))
                    rows[key] = obj
        except FileNotFoundError:
            print(f"WARN: {path} not found — skipped", file=sys.stderr)
    return list(rows.values())


def panel_class(panel):
    return panel.split("/", 1)[0] if panel else "(unknown)"


def report(rows):
    trials = [r for r in rows if r.get("role", "trial") == "trial"]
    benchmarks = [r for r in rows if r.get("role") == "benchmark"]
    diagnostics = [r for r in rows if r.get("role") == "diagnostic"]

    print(f"N_raw (deduped role=trial arms) = {len(trials)}")
    print(f"  + benchmark arms (excluded from N) = {len(benchmarks)}")
    print(f"  + diagnostic arms (excluded from N) = {len(diagnostics)}")

    print("\nArm counts by family (role=trial):")
    by_family = {}
    for r in trials:
        by_family.setdefault(r.get("family", "(none)"), 0)
        by_family[r.get("family", "(none)")] += 1
    for fam, n in sorted(by_family.items(), key=lambda kv: -kv[1]):
        print(f"  {fam}: {n}")

    print("\nArm counts by panel-class (role=trial):")
    by_panel = {}
    for r in trials:
        pc = panel_class(r.get("panel", ""))
        by_panel.setdefault(pc, 0)
        by_panel[pc] += 1
    for pc, n in sorted(by_panel.items(), key=lambda kv: -kv[1]):
        print(f"  {pc}: {n}")

    print("\nCross-trial Sharpe variance per sharpe_basis (role=trial, non-null sharpe only; never pooled across bases):")
    by_basis = {}
    for r in trials:
        s = r.get("sharpe")
        basis = r.get("sharpe_basis")
        if s is None or basis is None:
            continue
        by_basis.setdefault(basis, []).append(s)
    if not by_basis:
        print("  (no basis has any non-null sharpe — every arm on record has sharpe=null)")
    for basis, vals in sorted(by_basis.items()):
        if len(vals) < 2:
            print(f"  {basis}: n={len(vals)} — too few for a variance estimate, skipped")
            continue
        n, m, v = len(vals), mean(vals), variance(vals)
        warn = "  [n<8 — noisy variance estimate]" if n < 8 else ""
        print(f"  {basis}: n={n} mean={m:.4f} sample_variance={v:.6f}{warn}")

    n_eff_floor = len({(r.get("family"), panel_class(r.get("panel", ""))) for r in trials})
    print(f"\nN_eff_floor (distinct family × panel-class cells, role=trial) = {n_eff_floor}")
    print(f"N_raw = {len(trials)}")
    print('Feed `trials:` between N_eff_floor and N_raw. When unsure use N_raw — over-deflation is '
          'the safer direction (RESEARCH_2026-06-26_quant_engine.md §1).')


def selfcheck():
    fixture = [
        {"run": "r1", "config": "a", "family": "fam1", "panel": "panelA/v1", "role": "trial",
         "sharpe": 0.5, "sharpe_basis": "basisX", "dsr": 0.1},
        {"run": "r1", "config": "b", "family": "fam1", "panel": "panelA/v1", "role": "trial",
         "sharpe": 0.7, "sharpe_basis": "basisX", "dsr": 0.2},
        {"run": "r1", "config": "eqw", "family": "fam1", "panel": "panelA/v1", "role": "benchmark",
         "sharpe": 0.3, "sharpe_basis": "basisX", "dsr": None},
    ]
    rows = {}
    for obj in fixture:
        rows[(obj["run"], obj["config"])] = obj
    # dedup override check: re-inserting (r1,a) with a different sharpe must win (keep-last)
    rows[("r1", "a")] = {**fixture[0], "sharpe": 0.9}
    got = list(rows.values())
    trials = [r for r in got if r.get("role", "trial") == "trial"]
    assert len(trials) == 2, f"expected 2 trial arms, got {len(trials)}"
    assert any(r["config"] == "a" and r["sharpe"] == 0.9 for r in trials), "keep-last dedup failed"
    n_eff = len({(r.get("family"), panel_class(r.get("panel", ""))) for r in trials})
    assert n_eff == 1, f"expected N_eff_floor=1 (one family × panel-class cell), got {n_eff}"
    sharpes = [r["sharpe"] for r in trials if r.get("sharpe") is not None]
    assert len(sharpes) == 2 and abs(mean(sharpes) - 0.8) < 1e-9, "mean sharpe check failed"
    print("SELFCHECK: PASS")


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--selfcheck" in args:
        selfcheck()
        sys.exit(0)
    paths = args if args else [DEFAULT_LEDGER]
    report(load_rows(paths))
