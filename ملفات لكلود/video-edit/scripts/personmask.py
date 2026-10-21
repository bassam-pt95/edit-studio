# -*- coding: utf-8 -*-
"""قصّ الشخص من كل فريم + بيانات الوجه — نسخة ويندوز (وأي جهاز ما فيه مكتبة أبل Vision).

    python3 personmask.py <inDir> <outDir> [fast|balanced|accurate] [feather]

نفس مدخلات ومخرجات personmask.swift بالضبط، عشان الأدوات اللي تستدعيه ما تفرق:
  <outDir>/<اسم>.png  قناع رمادي للشخص (أبيض = الشخص)
  <outDir>/meta.json  [{"f": اسم الفريم, "face": {"x","y","w","h"}}]  إحداثيات بالبكسل، الأصل أعلى يسار
يحتاج: pip install "mediapipe<0.10.30" opencv-python numpy
"""
import sys, os, json
# ⛔ ويندوز بدون PYTHONUTF8: stdout بـcp1252 فأي print عربي يطيح السكربت بعد ما خلص شغله. نثبّت UTF-8 أول شي.
for _st in (sys.stdout, sys.stderr):
    try: _st.reconfigure(encoding="utf-8", errors="replace")
    except Exception: pass

try:
    import numpy as np
    import cv2
    import mediapipe as mp
except ImportError:
    print('⚠️ ناقص mediapipe أو opencv — شغّل: pip install "mediapipe<0.10.30" opencv-python')
    sys.exit(3)

a = sys.argv
if len(a) < 3:
    print("usage: personmask.py <inDir> <outDir> [quality] [feather]"); sys.exit(2)
in_dir, out_dir = a[1], a[2]
quality = a[3] if len(a) > 3 else "accurate"
feather = float(a[4]) if len(a) > 4 else 2.5
os.makedirs(out_dir, exist_ok=True)

# model_selection: 0 = العام (256×256، للطولي والمربع) · 1 = العرضي الأخف (256×144). كان معكوساً (fast→0 · accurate→1)
# فالدقيق ياخذ الأخف. الآن: العام دايماً، والعرضي بس لإطار عريض بوضع fast.
_segs = {}
def seg_for(w, h):
    sel = 1 if (quality == "fast" and w > h) else 0
    if sel not in _segs:
        _segs[sel] = mp.solutions.selfie_segmentation.SelfieSegmentation(model_selection=sel)
    return _segs[sel]
fd = mp.solutions.face_detection.FaceDetection(model_selection=1, min_detection_confidence=0.5)

meta = []
for f in sorted(x for x in os.listdir(in_dir) if x.lower().endswith(".jpg")):
    # imdecode(fromfile): cv2.imread ما يقرا المسار العربي على ويندوز ويرجع None بصمت
    img = cv2.imdecode(np.fromfile(os.path.join(in_dir, f), np.uint8), cv2.IMREAD_COLOR)
    if img is None:
        continue
    H, W = img.shape[:2]
    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    m = seg_for(W, H).process(rgb).segmentation_mask
    if m is None:
        continue
    m = (np.clip(m, 0, 1) * 255).astype(np.uint8)
    if feather > 0:
        # نواة تلقائية من السيجما (٦σ+1): كانت 5×5 فتقصّ التنعيم عند ~4 بكسل بدل ~8 مثل CIGaussianBlur
        m = cv2.GaussianBlur(m, (0, 0), feather)
    cv2.imencode(".png", m)[1].tofile(os.path.join(out_dir, f[:-4] + ".png"))   # imwrite نفس مشكلة المسار العربي

    row = {"f": f}
    r = fd.process(rgb)
    if r.detections:
        best = max(r.detections, key=lambda d: d.location_data.relative_bounding_box.width)
        b = best.location_data.relative_bounding_box
        row["face"] = {"x": b.xmin * W, "y": b.ymin * H, "w": b.width * W, "h": b.height * H}
    meta.append(row)

with open(os.path.join(out_dir, "meta.json"), "w", encoding="utf-8") as _mf:
    json.dump(meta, _mf, ensure_ascii=False)
print(f"masks: {len(meta)}")   # ASCII مثل نسخة Swift
