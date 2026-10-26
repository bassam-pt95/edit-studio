# -*- coding: utf-8 -*-
"""قصّ الشخص من كل فريم + بيانات الوجه — نسخة ويندوز (وأي جهاز ما فيه مكتبة أبل Vision).

    python3 personmask.py <inDir> <outDir> [fast|balanced|accurate] [feather] [--faces-only]

نفس مدخلات ومخرجات personmask.swift بالضبط، عشان الأدوات اللي تستدعيه ما تفرق:
  <outDir>/<اسم>.png  قناع رمادي للشخص (أبيض = الشخص)
  <outDir>/meta.json  [{"f": اسم الفريم, "face": {"x","y","w","h"}}]  إحداثيات بالبكسل، الأصل أعلى يسار
--faces-only: meta.json بس (نفسه بالضبط)، بلا قص الشخص ولا التنعيم ولا ملفات PNG — لمن يقرا صناديق الوجه بس
يحتاج: mediapipe وopencv وnumpy، شغل bash scripts/00_setup.sh --install
"""
import sys, os, json
if os.name == 'nt' and not sys.flags.utf8_mode and (sys.flags.ignore_environment or not os.environ.get('PYTHONUTF8')):
    os.environ['PYTHONUTF8'] = '1'; import subprocess; sys.exit(subprocess.call([sys.executable, '-X', 'utf8', *sys.orig_argv[1:]]))

try:
    import numpy as np
    import cv2
    import mediapipe as mp
except ImportError:
    print('⚠️ ناقص mediapipe أو opencv — شغل bash scripts/00_setup.sh --install')
    sys.exit(3)

a = [x for x in sys.argv if x != "--faces-only"]
faces_only = len(a) < len(sys.argv)   # حارس الوجه وfaceX يقرون الوجوه بس: نتخطى نموذج القص والتنعيم وكتابة PNG
if len(a) < 3:
    print("usage: personmask.py <inDir> <outDir> [quality] [feather] [--faces-only]"); sys.exit(2)
in_dir, out_dir = a[1], a[2]
quality = a[3] if len(a) > 3 else "accurate"
feather = float(a[4]) if len(a) > 4 else 2.5
os.makedirs(out_dir, exist_ok=True)

seg = None   # يتبنى من اول فريم: النموذج العام 256x256 (0)، والعرضي 144x256 (1) بس للسريع على فريم عرضه اكبر من طوله
fd = mp.solutions.face_detection.FaceDetection(model_selection=1, min_detection_confidence=0.5)

# cv2.imread وimwrite بويندوز ما يفتحون مسار فيه حروف غير انجليزية (مجلد شغل عربي) ويرجعون None وFalse بصمت،
# فنقرا ونكتب البايتات بنفسنا مثل studio/server/face.py
def imread_u(p):
    b = np.fromfile(p, np.uint8)
    return cv2.imdecode(b, cv2.IMREAD_COLOR) if b.size else None

def imwrite_u(p, m):
    ok, enc = cv2.imencode(".png", m)
    if ok: enc.tofile(p)
    return ok

meta = []
jpgs = sorted(x for x in os.listdir(in_dir) if x.lower().endswith(".jpg"))
n_read = 0
for f in jpgs:
    img = imread_u(os.path.join(in_dir, f))
    if img is None:
        continue
    n_read += 1
    H, W = img.shape[:2]
    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    if not faces_only:
        if seg is None:
            seg = mp.solutions.selfie_segmentation.SelfieSegmentation(model_selection=1 if (quality == "fast" and W > H) else 0)
        m = seg.process(rgb).segmentation_mask
        if m is None:
            continue
        m = (np.clip(m, 0, 1) * 255).astype(np.uint8)
        if feather > 0:   # (0, 0): الكيرنل من sigma نفسها (17x17 لـ2.5) مثل CIGaussianBlur بالماك، مو 5x5 يقص الحواف
            m = cv2.GaussianBlur(m, (0, 0), feather)
        imwrite_u(os.path.join(out_dir, f[:-4] + ".png"), m)

    row = {"f": f}
    r = fd.process(rgb)
    if r.detections:
        best = max(r.detections, key=lambda d: d.location_data.relative_bounding_box.width)
        b = best.location_data.relative_bounding_box
        row["face"] = {"x": b.xmin * W, "y": b.ymin * H, "w": b.width * W, "h": b.height * H}
    meta.append(row)

# فيه فريمات وما انقرا ولا واحد: هذا خطا قراءة مو «ما فيه وجه»، فنطلع بـ4 عشان اللي ينادينا ما يكمل على نتيجة فاضية
if jpgs and not n_read:
    print("❌ ما قدرت اقرا الفريمات (مسار فيه حروف غير انجليزية؟)", file=sys.stderr)
    sys.exit(4)
with open(os.path.join(out_dir, "meta.json"), "w", encoding="utf-8") as fh: json.dump(meta, fh, ensure_ascii=False)
print(f"✅ {len(meta)} فريم")
