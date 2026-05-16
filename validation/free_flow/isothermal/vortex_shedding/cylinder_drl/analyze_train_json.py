#!/usr/bin/env python3
"""Summarize MOOSE DRL trainer JSON reward diagnostics."""

import argparse
import json
import math
import statistics


def finite_equal(a, b, tol=1e-14):
    return a is not None and b is not None and math.isfinite(a) and math.isfinite(b) and abs(a - b) <= tol


def load_rows(path):
    with open(path, "r", encoding="utf-8") as handle:
        data = json.load(handle)

    rows = []
    for entry in data.get("time_steps", []):
        reward = entry.get("reward", {})
        samples = reward.get("sample_average_reward") or []
        sample_std = reward.get("sample_std_reward") or []
        rows.append(
            {
                "step": entry.get("time_step"),
                "time": entry.get("time"),
                "average_reward": reward.get("average_reward"),
                "std_reward": reward.get("std_reward"),
                "samples": samples,
                "sample_std": sample_std,
            }
        )
    return rows


def collapse_update_rows(rows):
    updates = []
    last_average = None
    for row in rows:
        if not row["samples"]:
            continue
        average = row["average_reward"]
        if last_average is None or not finite_equal(average, last_average):
            updates.append(row)
            last_average = average
    return updates


def print_block_summary(updates, block_size):
    for start in range(0, len(updates), block_size):
        block = updates[start : start + block_size]
        values = [row["average_reward"] for row in block]
        print(
            f"updates {start + 1:03d}-{start + len(block):03d}: "
            f"mean={statistics.fmean(values): .6f} "
            f"min={min(values): .6f} "
            f"max={max(values): .6f} "
            f"last={values[-1]: .6f}"
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("json_file", help="MOOSE JSON output from trainer.i")
    parser.add_argument(
        "--block-size",
        type=int,
        default=10,
        help="Number of policy updates per block summary.",
    )
    args = parser.parse_args()

    rows = load_rows(args.json_file)
    valid_rows = [row for row in rows if row["samples"]]
    updates = collapse_update_rows(rows)

    print(f"json rows: {len(rows)}")
    print(f"reward rows with samples: {len(valid_rows)}")
    print(f"distinct policy-update reward rows: {len(updates)}")
    print(f"sample counts per reward row: {sorted({len(row['samples']) for row in rows})}")

    if not updates:
        return

    best = max(updates, key=lambda row: row["average_reward"])
    worst = min(updates, key=lambda row: row["average_reward"])
    first = updates[0]
    last = updates[-1]
    values = [row["average_reward"] for row in updates]
    changes = [values[i] - values[i - 1] for i in range(1, len(values))]
    across_episode_stds = [
        statistics.pstdev(row["samples"]) for row in updates if len(row["samples"]) > 1
    ]

    print(
        "first update: "
        f"step={first['step']} average_reward={first['average_reward']: .6f} "
        f"std_reward={first['std_reward']: .6f}"
    )
    print(
        "best update: "
        f"step={best['step']} average_reward={best['average_reward']: .6f} "
        f"std_reward={best['std_reward']: .6f}"
    )
    print(
        "worst update: "
        f"step={worst['step']} average_reward={worst['average_reward']: .6f} "
        f"std_reward={worst['std_reward']: .6f}"
    )
    print(
        "last update: "
        f"step={last['step']} average_reward={last['average_reward']: .6f} "
        f"std_reward={last['std_reward']: .6f}"
    )

    if changes:
        print(
            "update-to-update changes: "
            f"mean={statistics.fmean(changes): .6f} "
            f"std={statistics.pstdev(changes): .6f} "
            f"max_up={max(changes): .6f} "
            f"max_down={min(changes): .6f}"
        )

    if across_episode_stds:
        print(
            "std across episode means: "
            f"mean={statistics.fmean(across_episode_stds): .6f} "
            f"min={min(across_episode_stds): .6f} "
            f"max={max(across_episode_stds): .6f}"
        )

    print_block_summary(updates, args.block_size)


if __name__ == "__main__":
    main()
