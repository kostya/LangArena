#!/usr/bin/env python3
"""Run C, a baseline Zane build and a new Zane build on run.js, interleaved.

usage: rebench3.py ROUNDS OUT.json  (appends rounds to OUT.json if it exists)
The baseline is /home/user/la-base: zane-perf 76bc235 built with the v0.36 release.
"""
import json, re, subprocess, sys
ROOT='/home/user/la-exp'
B={'c':ROOT+'/c/target/prod/benchmark','base':'/home/user/la-base/zane/out/host/zane','new':ROOT+'/zane/out/host/zane'}
LINE=re.compile(r'^(\S+): (OK|ERR\[[^\]]*\]) in ([0-9.]+)s', re.M)
R=int(sys.argv[1]); out=sys.argv[2]; import os; t=json.load(open(out)) if os.path.exists(out) else {k:{} for k in B}
for r in range(R):
    for k,b in B.items():
        p=subprocess.run([b,ROOT+'/run.js'],text=True,capture_output=True,cwd=ROOT)
        if p.returncode not in (0, 1) or 'Summary:' not in p.stdout: sys.exit(f'{b} exited with {p.returncode}:\n{p.stderr}')
        o=p.stdout
        for n,s,v in LINE.findall(o): t[k].setdefault(n,[]).append(float(v) if s=='OK' else None)
        json.dump(t,open(out,'w'),indent=1); print(r,k,flush=True)
