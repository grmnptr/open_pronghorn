#!/usr/bin/env python3
import argparse
import csv
import glob
import json
import os
import sys


DEFAULT_WINDOW_STEPS = 25
DEFAULT_LIFT_WEIGHT = 0.2
DEFAULT_DRAG_BASELINE = 3.205


def read_csv_rows(path):
    with open(path, newline="") as csv_file:
        rows = list(csv.DictReader(csv_file))

    if not rows:
        raise RuntimeError(f"{path} has no data rows")

    return rows


def scalar(row, name, default=None):
    value = row.get(name, default)
    if value is None or value == "":
        return default

    return float(value)


def find_probe_csv(scalar_csv):
    directory = os.path.dirname(os.path.abspath(scalar_csv)) or "."
    scalar_base = os.path.splitext(os.path.basename(scalar_csv))[0]
    if scalar_base.endswith("_csv"):
        run_base = scalar_base[:-4]
        patterns = [
            f"{run_base}_probes_observation_probes_FINAL.csv",
            f"{run_base}_probes_observation_probes*.csv",
        ]
    else:
        patterns = [f"{scalar_base}_observation_probes*.csv", "*observation_probes*.csv"]

    matches = []
    for pattern in patterns:
        matches = glob.glob(os.path.join(directory, pattern))
        if matches:
            break

    if not matches:
        return None

    return max(matches, key=os.path.getmtime)


def read_observation(path):
    rows = read_csv_rows(path)
    if "id" in rows[0]:
        rows.sort(key=lambda row: int(float(row["id"])))

    if "pressure" in rows[0]:
        value_names = ["pressure"]
    elif "vel_x" in rows[0] and "vel_y" in rows[0]:
        value_names = ["vel_x", "vel_y"]
    else:
        coordinate_names = {"id", "x", "y", "z", "processor_id"}
        value_names = [name for name in rows[0] if name not in coordinate_names]

    observation = []
    points = []
    for row in rows:
        points.append(
            {
                "id": int(float(row["id"])) if "id" in row else len(points),
                "x": scalar(row, "x"),
                "y": scalar(row, "y"),
                "z": scalar(row, "z", None),
            }
        )
        observation.extend(scalar(row, name) for name in value_names)

    return observation, points, value_names


def main():
    parser = argparse.ArgumentParser(
        description="Collect reward scalars and the final probe observation for a cylinder DRL rollout."
    )
    parser.add_argument("csv", nargs="?", default="flow_csv.csv")
    parser.add_argument("--probes-csv", default=None)
    parser.add_argument("--window-steps", type=int, default=DEFAULT_WINDOW_STEPS)
    parser.add_argument("--lift-weight", type=float, default=DEFAULT_LIFT_WEIGHT)
    parser.add_argument("--drag-baseline", type=float, default=DEFAULT_DRAG_BASELINE)
    parser.add_argument("--summary-only", action="store_true")
    args = parser.parse_args()

    rows = read_csv_rows(args.csv)
    window = rows[-min(args.window_steps, len(rows)) :]

    avg_drag = sum(scalar(row, "drag_coeff") for row in window) / len(window)
    avg_lift = sum(scalar(row, "lift_coeff") for row in window) / len(window)
    reward_windowed = -avg_drag - args.lift_weight * abs(avg_lift)
    reward_shifted_windowed = args.drag_baseline + reward_windowed

    last = rows[-1]
    result = {
        "samples": len(rows),
        "window_samples": len(window),
        "time": scalar(last, "time"),
        "action": scalar(last, "jet_mfr_action", None),
        "drag_coeff": scalar(last, "drag_coeff"),
        "lift_coeff": scalar(last, "lift_coeff"),
        "reward_action_window": scalar(last, "reward"),
        "reward_instant": scalar(last, "reward_instant", None),
        "reward_shifted_instant": scalar(last, "reward_shifted", None),
        "avg_drag_coeff": avg_drag,
        "avg_lift_coeff": avg_lift,
        "reward_windowed": reward_windowed,
        "reward_shifted_windowed": reward_shifted_windowed,
    }

    probes_csv = args.probes_csv or find_probe_csv(args.csv)
    if probes_csv and os.path.exists(probes_csv):
        observation, points, value_names = read_observation(probes_csv)
        result["probes_csv"] = probes_csv
        result["num_probe_points"] = len(points)
        result["observation_size"] = len(observation)
        result["observation_variables"] = value_names
        if not args.summary_only:
            result["observation"] = observation
            result["probe_points"] = points

    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
