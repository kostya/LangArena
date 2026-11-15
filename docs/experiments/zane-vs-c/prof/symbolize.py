# symbolize.py SAMPLES [TOP] [FUNCTION]: per-function sample share, using nm on
# each mapped file; with FUNCTION (a substring), the hottest addresses inside it.
import sys, subprocess, bisect, collections
maps=[]; pcs=[]
for l in open(sys.argv[1]):
    if l.startswith('#'):
        p=l[1:].split()
        if len(p)>=6 and 'x' in p[1]:
            a,b=(int(x,16) for x in p[0].split('-')); maps.append((a,b,int(p[2],16),p[5]))
    else: pcs.append(int(l,16))
syms={}
def table(path):
    if path in syms: return syms[path]
    out=subprocess.run(['nm','-n','--defined-only','-C',path],capture_output=True,text=True).stdout.split('\n')
    out+=subprocess.run(['nm','-n','-D','--defined-only','-C',path],capture_output=True,text=True).stdout.split('\n')
    t=sorted((int(x.split()[0],16),x.split(None,2)[2]) for x in out if len(x.split())>=3 and x.split()[1] in 'tTwWiI')
    syms[path]=([a for a,_ in t],[n for _,n in t]); return syms[path]
# file offset -> vaddr: assume first-segment-based PIE (vaddr == offset for text in typical layouts)
base={}
for a,b,off,p in maps: base.setdefault(p,[]).append((a,b,off))
c=collections.Counter(); pcs_in=collections.Counter()
want=sys.argv[3] if len(sys.argv)>3 else None
for pc in pcs:
    for a,b,off,p in maps:
        if a<=pc<b:
            addrs,names=table(p); rel=pc-a+off
            # non-PIE executables: symbols are absolute
            for cand in (rel,pc):
                i=bisect.bisect_right(addrs,cand)-1
                if i>=0 and cand-addrs[i]<1<<20:
                    c[(p.split('/')[-1],names[i])]+=1
                    if want and want in names[i]: pcs_in[cand]+=1
                    break
            else: c[(p.split('/')[-1],'?')]+=1
            break
    else: c[('?','?')]+=1
tot=sum(c.values()); top=int(sys.argv[2]) if len(sys.argv)>2 else 25
print(f'{tot} samples')
for (f,n),k in c.most_common(top): print(f'{100*k/tot:5.1f}%  {f:20.20}  {n}')
if want:
    print(f'hottest addresses in {want}:')
    for a,k in pcs_in.most_common(40): print(f'{100*k/tot:5.1f}%  {a:x}')
