#!/usr/bin/env python3
"""
compare.py — Parse benchmark output from JS and Cangjie runs and print a
             side-by-side Markdown table with speedup ratios.

Usage:
    python3 bench/compare.py js-bench.txt cj-bench.txt

Output format:
    | Scenario                | JS (ns/op) | CJ (ns/op) | Speedup | Status |
    |-------------------------|-----------|-----------|---------|--------|
    | WGS84 → GCJ02           |     1,240 |       350 |  3.54×  | ✅ CJ faster |
    ...

Requires Python 3.6+. No external dependencies.
"""

import re
import sys

# ── canonical scenario names (order determines table row order) ───────────────
CANONICAL = [
    ("WGS84 → GCJ02",    ["WGS84 → GCJ02",    "WGS84 → GCJ02"]),
    ("GCJ02 → WGS84",    ["GCJ02 → WGS84",    "GCJ02 → WGS84"]),
    ("GCJ02 → BD09",     ["GCJ02 → BD09",     "GCJ02 → BD09"]),
    ("BD09  → GCJ02",    ["BD09  → GCJ02",    "BD09  → GCJ02",  "BD09 → GCJ02"]),
    ("WGS84 → BD09",     ["WGS84 → BD09",     "WGS84 → BD09"]),
    ("BD09  → WGS84",    ["BD09  → WGS84",    "BD09  → WGS84",  "BD09 → WGS84"]),
    ("WGS84 → EPSG3857", ["WGS84 → EPSG3857", "WGS84 → EPSG3857"]),
    ("EPSG3857 → WGS84", ["EPSG3857 → WGS84", "EPSG3857 → WGS84"]),
    ("GeoJSON Point WGS84→GCJ02", ["GeoJSON Point WGS84→GCJ02", "GeoJSON WGS84→GCJ02"]),
    ("GeoJSON Point GCJ02→WGS84", ["GeoJSON Point GCJ02→WGS84", "GeoJSON GCJ02→WGS84"]),
    ("GeoJSON Point WGS84→BD09",  ["GeoJSON Point WGS84→BD09",  "GeoJSON WGS84→BD09"]),
]

# ── parse ns/op values from a benchmark output file ──────────────────────────
NS_RE = re.compile(r"(\d+(?:\.\d+)?)\s*ns/op", re.IGNORECASE)

def parse_file(path: str) -> dict:
    """Return {scenario_fragment -> ns_per_op} for every line that has ns/op."""
    result = {}
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                m = NS_RE.search(line)
                if m:
                    ns = float(m.group(1))
                    result[line.strip()] = ns
    except FileNotFoundError:
        pass
    return result

def find_ns(data: dict, fragments: list) -> float | None:
    """Find the first line in data whose text contains any of the fragments."""
    for frag in fragments:
        for line, ns in data.items():
            if frag.lower() in line.lower():
                return ns
    return None

# ── main ─────────────────────────────────────────────────────────────────────
def main(js_path: str, cj_path: str) -> None:
    js_data = parse_file(js_path)
    cj_data = parse_file(cj_path)

    if not js_data and not cj_data:
        print("No benchmark data found. Both files are empty or missing.")
        sys.exit(0)

    # Column widths
    w_scenario = 28
    w_ns = 12

    sep  = "─" * (w_scenario + 4 * w_ns + 5 * 3)
    hdr  = f"{'Scenario':{w_scenario}} | {'JS (ns/op)':>{w_ns}} | {'CJ (ns/op)':>{w_ns}} | {'Speedup':>{w_ns}} | Status"

    print()
    print("=" * len(hdr))
    print("  Performance Comparison: JavaScript vs Cangjie LTS 1.0.0")
    print("  (Speedup > 1× means Cangjie is faster; < 1× means JS is faster)")
    print("=" * len(hdr))
    print(hdr)
    print(sep)

    speedups = []
    for display_name, fragments in CANONICAL:
        js_ns = find_ns(js_data, fragments)
        cj_ns = find_ns(cj_data, fragments)

        js_s = f"{js_ns:>10,.1f}" if js_ns is not None else "    (missing)"
        cj_s = f"{cj_ns:>10,.1f}" if cj_ns is not None else "    (missing)"

        if js_ns is not None and cj_ns is not None and cj_ns > 0:
            ratio = js_ns / cj_ns
            speedups.append(ratio)
            ratio_s = f"{ratio:>9.2f}×"
            if ratio >= 2.0:
                status = "✅ CJ fast"
            elif ratio >= 1.0:
                status = "✅ CJ faster"
            elif ratio >= 0.83:  # within 20%
                status = "≈  comparable"
            else:
                status = "❌ JS faster"
        else:
            ratio_s = "    (n/a)"
            status = "⚠  missing"

        print(f"{display_name:{w_scenario}} | {js_s:>{w_ns}} | {cj_s:>{w_ns}} | {ratio_s:>{w_ns}} | {status}")

    print(sep)
    if speedups:
        avg = sum(speedups) / len(speedups)
        geo = 1.0
        for s in speedups:
            geo *= s
        geo = geo ** (1.0 / len(speedups))
        print(f"  Arithmetic mean speedup: {avg:.2f}×")
        print(f"  Geometric  mean speedup: {geo:.2f}×")
        print()
        if geo >= 1.2:
            print("  ✅ Cangjie is consistently faster than JS (geo mean ≥ 1.2×)")
        elif geo >= 0.83:
            print("  ≈  Cangjie and JS are roughly on par (geo mean within ±20%)")
        else:
            print("  ❌ JS is faster — investigate uneliminated heap allocations or GC pressure")
    print()

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <js-bench.txt> <cj-bench.txt>")
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
