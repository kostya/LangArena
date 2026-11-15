#!/usr/bin/env python3
"""Profile one test in Zane and in C with Callgrind and print, for each,
its hottest functions and the hot instructions of the top ones beside their
disassembly.

  hotasm.py TEST ZANE_BIN [--iterations N] [--real] [--funcs K] [--min FRAC]
            [--out DIR]

TEST is a run.js name. Iterations default to a tenth of run.js's; --real
runs a Brainfuck test's timed program instead of its warmup program.
--funcs is how many functions per side get their code printed (default 2),
--min the share of a function's cost an instruction needs to be printed
(default 0.002). Profiles are kept in --out (default the scratchpad dir
given by $S, else /tmp).
"""
import argparse, json, os, re, subprocess, sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
p = argparse.ArgumentParser()
p.add_argument('test'); p.add_argument('zane')
p.add_argument('--iterations', type=int)
p.add_argument('--real', action='store_true')
p.add_argument('--funcs', type=int, default=2)
p.add_argument('--min', type=float, default=0.002)
p.add_argument('--out', default=os.environ.get('S', '/tmp'))
a = p.parse_args()
a.out = str(Path(a.out).resolve())
a.zane = str(Path(a.zane).resolve())

t = next(x for x in json.load(open(ROOT / 'run.js')) if x['name'] == a.test)
t = dict(t)
t['iterations'] = a.iterations or max(1, t['iterations'] // 10)
# The C harness reads a warmup of 0 as its default (a fifth of the
# iterations, at least one), so both get that count explicitly.
t['warmup_iterations'] = max(1, int(t['iterations'] * 0.2))
if 'warmup_program' in t and not a.real:
    t['program'] = t['warmup_program']
tag = re.sub(r'\W', '_', a.test)
cfg = Path(a.out) / f'{tag}.json'
json.dump([t], open(cfg, 'w'))


def profile(name, binary, cwd):
    out = Path(a.out) / f'cg-{tag}-{name}.out'
    r = subprocess.run(['valgrind', '--tool=callgrind', '--dump-instr=yes',
                        f'--callgrind-out-file={out}', binary, str(cfg)],
                       cwd=cwd, capture_output=True, text=True)
    total = int(re.search(r'refs:\s+([\d,]+)', r.stderr).group(1).replace(',', ''))
    return out, total


def costs(path):
    """Per function: total self cost and per-address cost."""
    names, fn, funcs = {}, None, defaultdict(lambda: defaultdict(int))
    sub = None  # inside a calls= block: next line is the call's cost, skip it
    last = 0
    for line in open(path):
        m = re.match(r'(c?fn)=\((\d+)\)(?: (.*))?', line)
        if m:
            k, i, n = m.groups()
            if n: names[i] = n.strip()
            if k == 'fn': fn = names[i]
            continue
        if line.startswith('calls='):
            sub = True; continue
        if line[:1] in '0123456789+-*' and fn:
            parts = line.split()
            if len(parts) < 2: continue
            addr = parts[0]
            if addr.startswith('0x'): last = int(addr, 16)
            elif addr.startswith(('+', '-')): last += int(addr)
            elif addr != '*': last = int(addr, 16) if re.match(r'^[0-9a-f]+$', addr) else last
            if sub: sub = None; continue
            funcs[fn][last] += int(parts[-1])
    return funcs


def show(name, binary, cwd):
    out, total = profile(name, binary, cwd)
    funcs = costs(out)
    ranked = sorted(funcs.items(), key=lambda kv: -sum(kv[1].values()))
    print(f'\n===== {name}: {total/1e6:.0f}M instructions =====')
    for f, c in ranked[:8]:
        s = sum(c.values())
        print(f'{s/1e6:9.1f}M {100*s/total:5.1f}%  {f[:110]}')
    for f, c in ranked[:a.funcs]:
        s = sum(c.values())
        hot = {k: v for k, v in c.items() if v >= a.min * s}
        if not hot: continue
        lo, hi = min(hot), max(hot)
        dis = subprocess.run(['objdump', '-d', '--no-show-raw-insn', f'--start-address={lo}',
                              f'--stop-address={hi + 16}', binary], capture_output=True, text=True).stdout
        print(f'\n--- {f[:110]} ({s/1e6:.1f}M)')
        for line in dis.splitlines():
            m = re.match(r'\s*([0-9a-f]+):\s*(.*)', line)
            if not m: continue
            ad = int(m.group(1), 16)
            if ad in hot:
                print(f'{hot[ad]/1e6:8.1f}M  {ad:x}: {m.group(2)[:100]}')


show('zane', a.zane, ROOT / 'zane')
show('c', str(ROOT / 'c/target/prod/benchmark'), ROOT / 'c')
