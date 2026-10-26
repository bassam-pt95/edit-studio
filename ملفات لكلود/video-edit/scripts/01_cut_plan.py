# -*- coding: utf-8 -*-
"""خطة القص: يقيس السكتات بالصوت ويطلع مقاطع الكلام.  الاستخدام: python3 01_cut_plan.py <workdir>"""
import subprocess, re, json, sys, os
if os.name == 'nt' and not sys.flags.utf8_mode and (sys.flags.ignore_environment or not os.environ.get('PYTHONUTF8')):
    os.environ['PYTHONUTF8'] = '1'; import subprocess; sys.exit(subprocess.call([sys.executable, '-X', 'utf8', *sys.orig_argv[1:]]))
W = os.path.abspath(sys.argv[1]); SRC = os.path.join(W, "src.mov")
NOISE, MIND, PAD, MERGE = "-32dB", 0.35, 0.13, 0.20

dur = float(subprocess.run(["ffprobe","-v","error","-show_entries","format=duration",
    "-of","csv=p=0", SRC], capture_output=True, text=True, encoding="utf-8", errors="replace").stdout.strip())
# the video is copied, not decoded (a 15 min 4K clip: 197 s → 1 s, the same silences); not -vn: an MPEG-TS source
# whose audio starts late would shift every silence time (Ziyad's Windows port, 4ff1380)
out = subprocess.run(["ffmpeg","-hide_banner","-nostats","-i",SRC,"-c:v","copy","-sn","-dn","-af",
    f"silencedetect=noise={NOISE}:d={MIND}","-f","null","-"], capture_output=True, text=True, encoding="utf-8", errors="replace").stderr

sil=[]; s=None
for m in re.finditer(r"silence_(start|end): ([0-9.]+)", out):
    k,v = m.group(1), float(m.group(2))
    if k=="start": s=v
    else:
        sil.append(((0.0 if s is None else s), v)); s=None
if s is not None: sil.append((s,dur))

keep=[]; cur=0.0
for a,b in sil:
    if a-cur>0.01: keep.append([cur,a])
    cur=b
if dur-cur>0.01: keep.append([cur,dur])
keep=[[max(0,a-PAD),min(dur,b+PAD)] for a,b in keep]
m=[]
for seg in keep:
    if m and seg[0]-m[-1][1]<MERGE: m[-1][1]=seg[1]
    else: m.append(seg)
m=[x for x in m if x[1]-x[0]>=0.30]
tot=sum(b-a for a,b in m)
with open(os.path.join(W,"cut.json"),"w",encoding="utf-8") as fh: json.dump({"keep":m,"total":tot,"src_dur":dur}, fh, indent=1)
print(f"مقاطع={len(m)}  الباقي={tot:.2f}s  انشال={dur-tot:.2f}s ({(dur-tot)/dur*100:.0f}%)")
for a,b in m: print(f"  {a:7.2f} -> {b:7.2f}  ({b-a:5.2f}s)")
