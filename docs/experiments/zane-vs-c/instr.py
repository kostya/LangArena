#!/usr/bin/env python3
"""Callgrind instruction counts of each named test for one or more binaries.

usage: instr.py FILTER BIN [BIN ...] [--scale K]
Each test of run.js whose name contains FILTER runs alone under Callgrind
with its iterations divided by K (default 10) and a warmup of a fifth of
those, the count the C harness defaults to, so checksums read ERR; the counts are for comparing builds. Brainfuck, which runs its
program once, runs its short warmup program 10000 times instead. The binaries
run in parallel. Prints a row per test.
"""
import argparse, json, re, subprocess, tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ap = argparse.ArgumentParser()
ap.add_argument('filter'); ap.add_argument('bins', nargs='+')
ap.add_argument('--scale', type=int, default=10)
a = ap.parse_args()
flt, bins, scale = a.filter, a.bins, a.scale
tests = [t for t in json.load(open(ROOT / 'run.js')) if flt.lower() in t['name'].lower()]
print('| Test | ' + ' | '.join(Path(b).name for b in bins) + ' |')
print('| --- |' + ' ---: |' * len(bins))
for t in tests:
    t = dict(t, iterations=max(1, t['iterations'] // scale))
    if 'warmup_program' in t:
        t = dict(t, program=t['warmup_program'], iterations=10000)
    # The C harness reads a warmup of 0 as a fifth of the iterations (at
    # least one), so every binary gets that count explicitly.
    t['warmup_iterations'] = max(1, int(t['iterations'] * 0.2))
    with tempfile.NamedTemporaryFile('w', suffix='.json', delete=False) as f:
        json.dump([t], f)
    def count(b):
        err = subprocess.run(['valgrind', '--tool=callgrind', '--callgrind-out-file=/dev/null', b, f.name],
                             text=True, capture_output=True).stderr
        m = re.search(r'refs:\s+([\d,]+)', err)
        return f"{int(m.group(1).replace(',', ''))/1e9:.3f}G" if m else 'fail'
    with ThreadPoolExecutor(4) as pool:
        row = list(pool.map(count, bins))
    print(f"| {t['name']} | " + ' | '.join(row) + ' |', flush=True)
