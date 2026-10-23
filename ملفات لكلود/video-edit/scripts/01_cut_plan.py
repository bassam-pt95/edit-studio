# -*- coding: utf-8 -*-
"""خطة القص: يقيس السكتات بالصوت ويطلع مقاطع الكلام.  الاستخدام: python3 01_cut_plan.py <workdir>"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _paths; _paths.utf8_guard()   # ويندوز بدون UTF-8: يعيد تشغيل السكربت بـ-X utf8 (ماك/لينكس: لا شي)
import subprocess, re, json
W = os.path.abspath(sys.argv[1]); SRC = os.path.join(W, "src.mov")
NOISE, MIND, PAD, MERGE = "-32dB", 0.35, 0.13, 0.20

dur = float(subprocess.run(["ffprobe","-v","error","-show_entries","format=duration",
    "-of","csv=p=0", SRC], capture_output=True, text=True, encoding="utf-8", errors="replace").stdout.strip())
out = subprocess.run(["ffmpeg","-hide_banner","-nostats","-i",SRC,"-af",
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
_paths.write_json(os.path.join(W,"cut.json"), {"keep":m,"total":tot,"src_dur":dur})
print(f"مقاطع={len(m)}  الباقي={tot:.2f}s  انشال={dur-tot:.2f}s ({(dur-tot)/dur*100:.0f}%)")
for a,b in m: print(f"  {a:7.2f} -> {b:7.2f}  ({b-a:5.2f}s)")
