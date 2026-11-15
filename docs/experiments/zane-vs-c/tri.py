#!/usr/bin/env python3
# tri.py ROUNDS NAME=BIN... : interleave binaries on run.js, rotating order each round; min time per test.
import sys, re, subprocess, json, math
ROOT='/home/user/LangArena'; LINE=re.compile(r'^(\S+): (OK|ERR\[[^\]]*\]) in ([0-9.]+)s', re.M)
rounds=int(sys.argv[1]); bins=[a.split('=',1) for a in sys.argv[2:]]
t={n:{} for n,_ in bins}
for r in range(rounds):
    order=bins[r%len(bins):]+bins[:r%len(bins)]
    for n,b in order:
        p=subprocess.run(['taskset','-c','2',b,ROOT+'/run.js'],text=True,capture_output=True,cwd=ROOT)
        if p.returncode not in (0, 1) or 'Summary:' not in p.stdout: sys.exit(f'{b} exited with {p.returncode}:\n{p.stderr}')
        out=p.stdout
        for k,s,v in LINE.findall(out): t[n].setdefault(k,[]).append(float(v) if s=='OK' else None)
        print(f'round {r} {n} done', flush=True)
json.dump(t,open(sys.argv[0].replace('tri.py','tri.json'),'w'))
