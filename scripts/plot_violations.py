#!/usr/bin/env python3
"""
Parse test.log (OpenROAD DRT output) and plot violation count trend.

Examples:
  python3 scripts/plot_violations.py --log test.log --out violations.png --csv violations.csv --last
  python3 scripts/plot_violations.py --log test.log --out violations.png
"""

import argparse
import re
import sys
from typing import List, Tuple


def find_last_start(lines: List[str]) -> int:
    """Return index after the last detail-routing start marker."""
    markers = [
        re.compile(r"Start detail routing"),
        re.compile(r"Start 0th optimization iteration"),
    ]
    last_idx = 0
    for i, line in enumerate(lines):
        if any(m.search(line) for m in markers):
            last_idx = i
    return last_idx


def parse_violations(lines: List[str], start_idx: int = 0) -> List[Tuple[int, int]]:
    """Return list of (iteration, violations)."""
    data: List[Tuple[int, int]] = []
    cur_iter = None
    iter_re = re.compile(r"Start (\d+)(?:st|nd|rd|th) optimization iteration")
    viol_re = re.compile(r"Number of violations = (\d+)")

    for line in lines[start_idx:]:
        m = iter_re.search(line)
        if m:
            try:
                cur_iter = int(m.group(1))
            except ValueError:
                cur_iter = None

        m = viol_re.search(line)
        if m:
            viol = int(m.group(1))
            if cur_iter is None:
                cur_iter = len(data)
            data.append((cur_iter, viol))

    return data


def write_csv(path: str, data: List[Tuple[int, int]]) -> None:
    with open(path, "w", encoding="utf-8") as f:
        f.write("iteration,violations\n")
        for it, v in data:
            f.write(f"{it},{v}\n")


def plot_png(path: str, data: List[Tuple[int, int]], title: str) -> bool:
    try:
        import matplotlib.pyplot as plt  # type: ignore
    except Exception:
        return False

    xs = [d[0] for d in data]
    ys = [d[1] for d in data]

    plt.figure(figsize=(10, 4))
    plt.plot(xs, ys, marker="o", linewidth=1)
    plt.yscale("log")

    # Mark current minimum
    min_idx = min(range(len(ys)), key=lambda i: ys[i])
    min_x, min_y = xs[min_idx], ys[min_idx]
    plt.scatter([min_x], [min_y], color="red", zorder=5, label=f"min {min_y}")
    plt.annotate(f"min {min_y}", xy=(min_x, min_y), xytext=(8, 8), textcoords="offset points")
    plt.title(title)
    plt.xlabel("Optimization iteration")
    plt.ylabel("Violations")
    plt.grid(True, linestyle="--", linewidth=0.5, alpha=0.6)
    plt.tight_layout()
    plt.savefig(path, dpi=150)
    plt.close()
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", default="test.log", help="Path to test.log")
    ap.add_argument("--out", default="violations.png", help="Output PNG path")
    ap.add_argument("--csv", default="violations.csv", help="Output CSV path")
    ap.add_argument("--last", action="store_true", help="Only parse last DRT run")
    args = ap.parse_args()

    try:
        with open(args.log, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
    except FileNotFoundError:
        print(f"log not found: {args.log}")
        return 1

    start_idx = find_last_start(lines) if args.last else 0
    data = parse_violations(lines, start_idx=start_idx)

    if not data:
        print("no violation entries found")
        return 2

    write_csv(args.csv, data)

    title = "OpenROAD DRT Violations"
    if args.last:
        title += " (last run)"

    if not plot_png(args.out, data, title):
        print("matplotlib not available; wrote CSV only:")
        print(f"  {args.csv}")
        print("Install matplotlib to get PNG output.")
        return 0

    print(f"wrote: {args.out}")
    print(f"wrote: {args.csv}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
