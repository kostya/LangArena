#!/usr/bin/env python3
"""Interleave two Zane binaries on run.js and report min times and B / A.

usage: ab.py A_BIN B_BIN [--rounds N] [--filter SUBSTR]
"""
import argparse, math, re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
LINE = re.compile(r'^(\S+): (OK|ERR\[[^\]]*\]) in ([0-9.]+)s', re.M)

def run(binary, flt):
    r = subprocess.run([binary, str(ROOT / 'run.js')] + ([flt] if flt else []),
                       text=True, capture_output=True, cwd=ROOT)
    # A failed checksum exits 1 after its Summary line. Any other nonzero exit
    # (a crash, or a filter that matched nothing) or a missing Summary line
    # is an incomplete run.
    if r.returncode not in (0, 1) or 'Summary:' not in r.stdout:
        sys.exit(f'{binary} exited with {r.returncode}:\n{r.stderr}')
    out = r.stdout
    return {n: (float(t) if s == 'OK' else None) for n, s, t in LINE.findall(out)}

p = argparse.ArgumentParser()
p.add_argument('a'); p.add_argument('b')
p.add_argument('--rounds', type=int, default=3)
p.add_argument('--filter')
a = p.parse_args()
t = {'a': {}, 'b': {}}
for r in range(a.rounds):
    for k, b in (('a', a.a), ('b', a.b)) if r % 2 == 0 else (('b', a.b), ('a', a.a)):
        for n, v in run(b, a.filter).items():
            t[k].setdefault(n, []).append(v)
print('| Test | A (s) | B (s) | B / A |\n| --- | ---: | ---: | ---: |')
logs = []
for n in t['a']:
    x, y = t['a'][n], t['b'].get(n, [None])
    if None in x or None in y:
        print(f'| {n} | ERR | ERR | |'); continue
    q = min(y) / min(x); logs.append(math.log(q))
    print(f'| {n} | {min(x):.3f} | {min(y):.3f} | {q:.3f} |')
if logs:
    print(f'\ngeomean B/A over {len(logs)} tests: {math.exp(sum(logs)/len(logs)):.3f}')
