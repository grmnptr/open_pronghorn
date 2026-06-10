#!/usr/bin/env python3

import argparse
import sys

import pandas as pd
import matplotlib.pyplot as plt


def main():
    parser = argparse.ArgumentParser(
        description="Plot CSV columns y1=f(x), y2=f(x), ... in separate subplots."
    )

    parser.add_argument(
        "csv_file",
        help="Path to the CSV file with a header row"
    )

    parser.add_argument(
        "--x",
        required=True,
        help="Header name of the x-axis column"
    )

    parser.add_argument(
        "--y",
        required=True,
        nargs="+",
        help="Header names of one or more y-axis columns"
    )

    parser.add_argument(
        "--output",
        default=None,
        help="Optional output image file, e.g. plot.png or plot.pdf"
    )

    parser.add_argument(
        "--title",
        default=None,
        help="Optional overall figure title"
    )

    args = parser.parse_args()

    try:
        df = pd.read_csv(args.csv_file)
    except Exception as e:
        print(f"Error reading CSV file: {e}", file=sys.stderr)
        sys.exit(1)

    required_columns = [args.x] + args.y
    missing_columns = [col for col in required_columns if col not in df.columns]

    if missing_columns:
        print("Error: missing columns in CSV:", file=sys.stderr)
        for col in missing_columns:
            print(f"  {col}", file=sys.stderr)
        print("\nAvailable columns:", file=sys.stderr)
        for col in df.columns:
            print(f"  {col}", file=sys.stderr)
        sys.exit(1)

    x = df[args.x]
    y_columns = args.y
    nplots = len(y_columns)

    fig, axes = plt.subplots(
        nplots,
        1,
        figsize=(8, 3 * nplots),
        sharex=True
    )

    if nplots == 1:
        axes = [axes]

    for ax, y_col in zip(axes, y_columns):
        ax.plot(x, df[y_col])
        ax.set_ylabel(y_col)
        ax.grid(True)

    axes[-1].set_xlabel(args.x)

    if args.title:
        fig.suptitle(args.title)

    fig.tight_layout()

    if args.output:
        plt.savefig(args.output, dpi=300, bbox_inches="tight")
        print(f"Saved plot to {args.output}")
    else:
        plt.show()


if __name__ == "__main__":
    main()