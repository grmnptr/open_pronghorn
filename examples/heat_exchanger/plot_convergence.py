#!/usr/bin/env python3
"""Outer-iteration residual history of SIMPLE runs, one panel per equation.

Usage: python plot_convergence.py LABEL=run.log [LABEL=run.log ...] [-o out.png]
For energy and solid energy (several CHT sweeps per outer iteration), the
first sweep's initial residual is plotted.
"""
import argparse
import re

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

ANSI = re.compile(r"\x1b\[[0-9;]*m")
PATTERNS = [
    ("Momentum x", re.compile(r"Momentum equation: Component 1 (\S+)")),
    ("Momentum y", re.compile(r"Momentum equation: Component 2 (\S+)")),
    ("Momentum z", re.compile(r"Momentum equation: Component 3 (\S+)")),
    ("Pressure", re.compile(r"Pressure equation: (\S+)")),
    ("TKE", re.compile(r"TKE_system (\S+)")),
    ("TKED", re.compile(r"TKED_system (\S+)")),
    ("Fluid energy", re.compile(r"energy_system (\S+)")),
    ("Solid energy", re.compile(r"Solid energy equation: (\S+)")),
]
TOL = {"TKE": 1e-6, "TKED": 1e-6}  # all other equations: 1e-6 as well
COLORS = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100"]


def parse(path):
    hist = {name: {} for name, _ in PATTERNS}
    it = None
    for line in open(path, errors="replace"):
        line = ANSI.sub("", line)
        m = re.match(r"Iteration (\d+) Initial residual norms", line)
        if m:
            it = int(m.group(1))
            continue
        if it is None:
            continue
        for name, pat in PATTERNS:
            m = pat.search(line)
            if m and it not in hist[name]:  # first CHT sweep only
                hist[name][it] = float(m.group(1))
    return hist


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("runs", nargs="+", help="LABEL=path/to/log")
    ap.add_argument("-o", "--out", default="convergence.png")
    args = ap.parse_args()
    runs = [(r.rsplit("=", 1)[0], parse(r.rsplit("=", 1)[1])) for r in args.runs]

    fig, axes = plt.subplots(2, 4, figsize=(15, 7), sharex=True, sharey=True)
    for ax, (name, _) in zip(axes.flat, PATTERNS):
        for (label, hist), c in zip(runs, COLORS):
            h = hist[name]
            if h:
                its = sorted(h)
                ax.semilogy(its, [h[i] for i in its], color=c, lw=1.6, label=label)
        ax.axhline(TOL.get(name, 1e-6), color="#8a8984", lw=1, ls="--")
        ax.set_title(name, loc="left", fontsize=11, color="#0b0b0b")
        ax.grid(True, which="major", color="#e4e3df", lw=0.6)
        for s in ("top", "right"):
            ax.spines[s].set_visible(False)
        for s in ("left", "bottom"):
            ax.spines[s].set_color("#b5b4ae")
        ax.tick_params(colors="#52514e", labelsize=9)
    for ax in axes[1]:
        ax.set_xlabel("outer iteration", color="#52514e")
    for ax in axes[:, 0]:
        ax.set_ylabel("initial residual", color="#52514e")
    handles, labels = axes.flat[0].get_legend_handles_labels()
    handles.append(plt.Line2D([], [], color="#8a8984", lw=1, ls="--"))
    labels.append("tolerance (1e-6)")
    fig.legend(handles, labels, loc="upper center", ncol=len(labels), frameon=False, fontsize=10)
    fig.suptitle("")
    fig.tight_layout(rect=(0, 0, 1, 0.94))
    fig.savefig(args.out, dpi=130, facecolor="#fcfcfb")
    print("wrote", args.out)


if __name__ == "__main__":
    main()
