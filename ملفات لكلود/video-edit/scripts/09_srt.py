# -*- coding: utf-8 -*-
"""ملف ترجمة SRT + نص كامل من الكابشن.  python3 09_srt.py <workdir> [اسم_الأساس]
يطلّع: <base>.srt (يوتيوب يقراه، وانستقرام يقبله بالرفع) و<base>.txt (نص جاهز لكابشن البوست).
يقرأ caps.json — نفس التوقيتات اللي انرسمت بالفيديو، فالمزامنة مضمونة."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _paths; _paths.utf8_guard()   # ويندوز بدون UTF-8: يعيد تشغيل السكربت بـ-X utf8 (ماك/لينكس: لا شي)
import json

W = os.path.abspath(sys.argv[1])
_base0 = sys.argv[2] if len(sys.argv) > 2 else "ad-final"
# ويندوز: ? : " < > | * ما تنفع بأسماء الملفات (NTFS يخفي الباقي بعد : كأنه stream) — ننظّف الاسم ونقول لو تغيّر
base = _paths.sanitize_name(_base0)
if base != _base0: print(f"⚠️ الاسم «{_base0}» ما ينفع اسم ملف — استُعمل «{base}»")
caps = _paths.read_json(os.path.join(W, "caps.json"))
cards = caps["cards"]

def ts(t):
    t = max(0.0, float(t))
    h = int(t // 3600); m = int(t % 3600 // 60); s = int(t % 60); ms = int(round((t - int(t)) * 1000))
    if ms == 1000: s += 1; ms = 0
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"

MAXCH = 42          # سطر أطول من كذا ينقص بالجوال
def wrap(words):
    lines, cur = [], ""
    for w in words:
        cand = (cur + " " + w).strip()
        if len(cand) > MAXCH and cur:
            lines.append(cur); cur = w
        else:
            cur = cand
    if cur: lines.append(cur)
    return lines[:2] if len(lines) <= 2 else [" ".join(lines[:-1]), lines[-1]]

srt, txt = [], []
for i, c in enumerate(cards, 1):
    words = [w["t"] for w in c["w"]]
    end = c["e"]
    if i < len(cards):                       # لا تتداخل مع الكرت اللي بعده
        end = min(end, cards[i]["s"] - 0.02)
    if end <= c["s"]: end = c["s"] + 0.4
    srt.append(f"{i}\n{ts(c['s'])} --> {ts(end)}\n" + "\n".join(wrap(words)) + "\n")
    txt.append(" ".join(words))

sp = os.path.join(W, base + ".srt"); tp = os.path.join(W, base + ".txt")
open(sp, "w", encoding="utf-8").write("\n".join(srt))
open(tp, "w", encoding="utf-8").write("\n".join(txt) + "\n")
print(f"✅ {sp}  ({len(cards)} سطر ترجمة)")
print(f"✅ {tp}  ({sum(len(t.split()) for t in txt)} كلمة — جاهز لكابشن البوست)")
