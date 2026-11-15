#!/usr/bin/env python3
"""Hottest instruction addresses of one function in a Callgrind profile.

usage: hotspots.py CALLGRIND_OUT FUNCTION_SUBSTRING [N]
The profile must be made with --dump-instr=yes. Prints address and self
instruction count, hottest first; pair with objdump to read the loop.
"""
import collections, re, sys

path, want = sys.argv[1], sys.argv[2]
n = int(sys.argv[3]) if len(sys.argv) > 3 else 40
names, cost, fn, last, after_calls = {}, collections.Counter(), None, 0, False
for line in open(path):
    m = re.match(r'^(c?)fn=\((\d+)\)(?: (.*))?', line)
    if m:
        if m.group(3): names[m.group(2)] = m.group(3).strip()
        if not m.group(1): fn = names.get(m.group(2), '')
        continue
    if line.startswith('calls='):
        after_calls = True; continue
    m = re.match(r'^(0x[0-9a-f]+|\+\d+|-\d+|\*)\s+\S+\s+(\d+)', line)
    if m:
        a = m.group(1)
        if a.startswith('0x'): last = int(a, 16)
        elif a[0] in '+-': last += int(a)
        if after_calls:  # the line after calls= is the call's inclusive cost
            after_calls = False; continue
        if fn and want in fn:
            cost[last] += int(m.group(2))
for a, c in sorted(cost.items(), key=lambda x: -x[1])[:n]:
    print(f'{a:x} {c}')
