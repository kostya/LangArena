#!/usr/bin/env python3
"""Run C and Zane on run.js, interleaved, and report min times and Zane/C.

usage: measure.py [--rounds N] [--filter SUBSTR] [--out results.json] [--zane BIN] [--c BIN]
Builds nothing: build c/target/prod/benchmark and zane/out/host/zane first.
"""
import argparse, json, math, re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
LINE = re.compile(r'^(\S+): (OK|ERR\[[^\]]*\]) in ([0-9.]+)s', re.M)

def run(binary, flt):
    args = [str(binary), str(ROOT / 'run.js')] + ([flt] if flt else [])
    r = subprocess.run(args, text=True, capture_output=True, cwd=ROOT)
    # A failed checksum exits 1 after its Summary line. Any other nonzero exit
    # (a crash, or a filter that matched nothing) or a missing Summary line
    # is an incomplete run.
    if r.returncode not in (0, 1) or 'Summary:' not in r.stdout:
        sys.exit(f'{binary} exited with {r.returncode}:\n{r.stderr}')
    out = r.stdout
    res = {}
    for name, status, t in LINE.findall(out):
        res[name] = float(t) if status == 'OK' else None
    return res

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--rounds', type=int, default=3)
    p.add_argument('--filter')
    p.add_argument('--out')
    p.add_argument('--zane', default=str(ROOT / 'zane/out/host/zane'))
    p.add_argument('--c', default=str(ROOT / 'c/target/prod/benchmark'))
    a = p.parse_args()
    times = {'c': {}, 'zane': {}}
    orders = []
    for r in range(a.rounds):
        order = (('c', a.c), ('zane', a.zane))
        ran = order if r % 2 == 0 else order[::-1]
        orders.append([lang for lang, _ in ran])
        for lang, b in ran:
            for k, v in run(b, a.filter).items():
                times[lang].setdefault(k, []).append(v)
        print(f'round {r+1}/{a.rounds} done', file=sys.stderr, flush=True)
    rows, logs = [], []
    for k in times['c']:
        cs, zs = times['c'][k], times['zane'].get(k, [None])
        if None in cs or None in zs:
            rows.append((k, None, None, None)); continue
        c, z = min(cs), min(zs)
        rows.append((k, c, z, z / c)); logs.append(math.log(z / c))
    print('| Test | C (s) | Zane (s) | Zane / C |\n| --- | ---: | ---: | ---: |')
    for k, c, z, q in rows:
        print(f'| {k} | {c:.3f} | {z:.3f} | {q:.2f} |' if q else f'| {k} | ERR | ERR | |')
    if logs:
        print(f'\ngeomean Zane/C over {len(logs)} tests: {math.exp(sum(logs)/len(logs)):.3f}')
    if a.out:
        # Per test, samples in round order; 'order' lists which ran first.
        Path(a.out).write_text(json.dumps(dict(times, order=orders), indent=1))

main()
