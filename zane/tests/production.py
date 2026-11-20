#!/usr/bin/env python3
"""Check every full run.js workload separately with a configurable timeout."""
import argparse
import json
from pathlib import Path
import resource
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]

def limits():
    # Zane reserves virtual address ranges for growable lists and worker regions.
    # RLIMIT_AS constrains those reservations, not resident memory, so it is not
    # a usable memory budget for these benchmarks.
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--shard', type=int, default=0)
    parser.add_argument('--shards', type=int, default=1)
    parser.add_argument('--timeout', type=float, default=300)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('timeout must be positive')
    if args.shards < 1 or not 0 <= args.shard < args.shards:
        parser.error('shard must be within the positive shard count')
    all_rows = json.loads((ROOT.parent / 'run.js').read_text())
    rows = [row for index, row in enumerate(all_rows) if index % args.shards == args.shard]
    failures = []
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / 'config.json'
        for row in rows:
            path.write_text(json.dumps([row]))
            started = time.monotonic()
            try:
                result = subprocess.run(
                    [str(ROOT / 'out/host/zane'), str(path)],
                    text=True, capture_output=True, timeout=args.timeout, preexec_fn=limits,
                )
                print(result.stdout, end='', flush=True)
                if result.stderr:
                    print(result.stderr, end='', flush=True)
                if result.returncode:
                    failures.append(row['name'])
            except subprocess.TimeoutExpired:
                failures.append(row['name'])
                print(f"{row['name']}: exceeded {args.timeout:g} seconds", flush=True)
            print(f"Process wall time: {time.monotonic() - started:.2f}s", flush=True)
    if failures:
        raise SystemExit("Failed workloads: " + ", ".join(failures))
    print(f"All {len(rows)} production checksums passed.", flush=True)

if __name__ == '__main__':
    main()
