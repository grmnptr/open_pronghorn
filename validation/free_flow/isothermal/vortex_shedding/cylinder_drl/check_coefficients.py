#!/usr/bin/env python3
import argparse
import csv
import sys


DRAG_MAX_BOUNDS = (3.22, 3.24)
ABS_LIFT_MAX_BOUNDS = (0.99, 1.01)


def read_series(path, min_time):
    with open(path, newline="") as csv_file:
        rows = [
            row
            for row in csv.DictReader(csv_file)
            if min_time is None or float(row["time"]) >= min_time
        ]

    if not rows:
        raise RuntimeError(f"{path} has no data rows")

    drag = [float(row["drag_coeff"]) for row in rows]
    lift = [float(row["lift_coeff"]) for row in rows]
    return drag, lift


def in_bounds(value, bounds):
    return bounds[0] <= value <= bounds[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("csv", nargs="?", default="flow_csv.csv")
    parser.add_argument(
        "--summary-only",
        action="store_true",
        help="Print coefficient extrema without enforcing validation bounds.",
    )
    parser.add_argument(
        "--min-time",
        type=float,
        default=None,
        help="Ignore rows earlier than this simulation time.",
    )
    args = parser.parse_args()

    drag, lift = read_series(args.csv, args.min_time)

    print(f"samples: {len(drag)}")
    metrics = {
        "drag_max": (max(drag), DRAG_MAX_BOUNDS),
        "abs_lift_max": (max(abs(value) for value in lift), ABS_LIFT_MAX_BOUNDS),
    }
    print(f"drag_min: {min(drag):.8g}")

    failed = False
    for name, (value, bounds) in metrics.items():
        if args.summary_only:
            print(f"{name}: {value:.8g}")
            continue

        passed = in_bounds(value, bounds)
        failed = failed or not passed
        status = "PASS" if passed else "FAIL"
        print(f"{status} {name}: {value:.8g} in [{bounds[0]}, {bounds[1]}]")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
