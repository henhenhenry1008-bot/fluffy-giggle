#!/usr/bin/env python3
"""Read-only CPU-time measurement: 100% means one fully occupied core.

Run against an already running PulseBar. Keep its window state, cadence and
history length unchanged across comparisons. Do not profile/build concurrently.
"""

import argparse
import datetime
import json
import subprocess
import time


def snapshot(pid):
    result = subprocess.check_output(
        ["/bin/ps", "-p", str(pid), "-o", "time=,rss=,lstart="], text=True
    ).strip().split(maxsplit=2)
    if len(result) != 3:
        raise RuntimeError("Target process exited or could not be read")
    cpu, rss, started = result
    days = 0
    if "-" in cpu:
        day_text, cpu = cpu.split("-", 1)
        days = int(day_text)
    seconds = 0.0
    for component in cpu.split(":"):
        seconds = seconds * 60 + float(component)
    return seconds + days * 86400, int(rss), started, time.monotonic()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pid", type=int)
    parser.add_argument("--seconds", type=float, default=20)
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--warmup", type=float, default=0,
                        help="Seconds to fill chart history before measurement (0–300)")
    parser.add_argument("--label", required=True)
    args = parser.parse_args()
    if args.pid <= 0 or not 1 <= args.seconds <= 60 or not 1 <= args.runs <= 10:
        parser.error("Use a positive PID, 1–60 seconds and 1–10 runs")
    if not 0 <= args.warmup <= 300:
        parser.error("Warmup must be 0–300 seconds")
    remaining = args.warmup
    while remaining > 0:
        pause = min(remaining, 30)
        print(json.dumps({"label": args.label, "warmup_seconds_remaining": remaining}), flush=True)
        time.sleep(pause)
        remaining -= pause
    results = []
    for run in range(args.runs):
        before = snapshot(args.pid)
        time.sleep(args.seconds)
        after = snapshot(args.pid)
        if before[2] != after[2] or after[0] < before[0]:
            raise RuntimeError("Process identity/counters changed; discard the run")
        elapsed = after[3] - before[3]
        cpu_seconds = after[0] - before[0]
        item = {
            "label": args.label, "pid": args.pid, "run": run + 1,
            "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "wall_seconds": round(elapsed, 3),
            "cpu_seconds": round(cpu_seconds, 3),
            "cpu_percent_one_core": round(cpu_seconds / elapsed * 100, 3),
            "rss_mb": round(after[1] / 1024, 1),
        }
        results.append(item)
        print(json.dumps(item), flush=True)
    print(json.dumps({"label": args.label, "mean_cpu_percent_one_core": round(
        sum(item["cpu_percent_one_core"] for item in results) / len(results), 3
    )}), flush=True)


if __name__ == "__main__":
    main()
