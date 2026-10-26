# -*- coding: utf-8 -*-
"""قص «الموضوع» من صورة (شخص، جرة، اسد…) — نسخة ويندوز من subjectcut.swift (مكتبة Vision حق ابل مو بالويندوز).

    python3 subjectcut.py <in> <out.png> [--keep] [--engine auto|model|plain]

نفس مدخلات ومخرجات subjectcut.swift: PNG شفاف مقصوص على حدود الموضوع، و--keep بمقاس الصورة الاصلي وبنفس المكان.
يطبع ok WxH instances=N، وبلا موضوع يطبع no subject ويطلع بـ3.
  model : نموذج ISNet (<VEB_HOME>/tools/models/isnet-general-use.onnx) على onnxruntime حق venv ادوات المونتاج (المعالج).
          ينزل بـbash scripts/00_setup.sh --subjectcut بعد موافقة المستخدم (~180 ميقا)
  plain : بلا تنزيل، للصور المولدة بخلفية سادة فاتحة (رمادي فاتح او كريمي): الخلفية = لون اطار الصورة والمتصل
          بالحواف بس، فالفاتح داخل الموضوع يبقى. خلفية مو سادة فاتحة (صورة حقيقية) تطلع بـ4
  auto  : (الافتراضي) model لو النموذج موجود، والا plain
"""
import sys, os
if os.name == 'nt' and not sys.flags.utf8_mode and (sys.flags.ignore_environment or not os.environ.get('PYTHONUTF8')):
    os.environ['PYTHONUTF8'] = '1'; import subprocess; sys.exit(subprocess.call([sys.executable, '-X', 'utf8', *sys.orig_argv[1:]]))

try:
    import numpy as np
    import cv2
except ImportError:
    print('⚠️ ناقص opencv او numpy — شغل bash scripts/00_setup.sh --install')
    sys.exit(1)

import _paths

ENGINES = ("auto", "model", "plain")
MODEL = _paths.data("tools", "models", "isnet-general-use.onnx")
HINT = "نزل نموذج قص الصور (bash scripts/00_setup.sh --subjectcut بعد موافقة المستخدم، ~180 ميقا) او اطلب الصورة بخلفية سادة فاتحة (رمادي فاتح او كريمي)"

a, keep, engine = [], False, "auto"
it = iter(sys.argv[1:])
for x in it:
    if x == "--keep": keep = True
    elif x == "--engine": engine = next(it, "")
    elif x.startswith("--engine="): engine = x.split("=", 1)[1]
    else: a.append(x)
if len(a) < 2 or engine not in ENGINES:
    print(f"usage: subjectcut.py <in> <out.png> [--keep] [--engine {'|'.join(ENGINES)}]"); sys.exit(2)
src, dst = a[0], a[1]

# cv2.imread وimwrite بويندوز ما يفتحون مسار فيه حروف غير انجليزية، فنقرا ونكتب البايتات بنفسنا (مثل personmask.py)
b = np.fromfile(src, np.uint8) if os.path.isfile(src) else np.zeros(0, np.uint8)
img = cv2.imdecode(b, cv2.IMREAD_COLOR) if b.size else None
if img is None:
    print(f"ما انفتحت الصورة: {src}"); sys.exit(1)
H, W = img.shape[:2]

def plain():
    """الخلفية السادة: لون شريط الاطار (2%) بفرق Lab، والقريب منه المتصل بالحواف بس خلفية، ثم تنظيف وتنعيم الحافة."""
    lab = cv2.cvtColor(img.astype(np.float32) / 255, cv2.COLOR_BGR2LAB)
    m = max(2, round(min(H, W) * 0.02))
    band = np.ones((H, W), bool); band[m:-m, m:-m] = False
    ref = np.median(lab[band], axis=0)
    d = np.linalg.norm(lab - ref, axis=2)
    spread = float(np.percentile(d[band], 60))   # 60%: موضوع يلمس حافة او حافتين ما يخرب القياس
    if spread > 8 or ref[0] < 60:   # الغامق (مشهد مظلم) فروقه صغيرة وهو مو خلفية سادة
        print("الخلفية مو سادة فاتحة: " + HINT); sys.exit(4)
    _, lbl = cv2.connectedComponents((d < max(10, 3 * spread + 6)).astype(np.uint8), connectivity=4)
    edge = np.unique(np.concatenate([lbl[0], lbl[-1], lbl[:, 0], lbl[:, -1]]))
    fg = (~np.isin(lbl, edge[edge > 0])).astype(np.uint8) * 255
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5) if min(H, W) < 1500 else (9, 9))
    fg = cv2.morphologyEx(cv2.morphologyEx(fg, cv2.MORPH_OPEN, k), cv2.MORPH_CLOSE, k)
    return cv2.GaussianBlur(fg, (0, 0), 1.5)

def model():
    """ISNet بنفس تجهيز rembg (جلسة DIS): 1024x1024، القيم على اعلى قيمة بالصورة ناقص 0.5، والناتج min-max."""
    try:
        import onnxruntime as ort
    except ImportError:
        print("⚠️ ناقص onnxruntime — شغل bash scripts/00_setup.sh --install"); sys.exit(4)
    sess = ort.InferenceSession(MODEL, providers=["CPUExecutionProvider"])
    x = cv2.resize(cv2.cvtColor(img, cv2.COLOR_BGR2RGB), (1024, 1024),
                   interpolation=cv2.INTER_AREA if W * H > 1024 * 1024 else cv2.INTER_LANCZOS4).astype(np.float32)
    x = x / max(float(x.max()), 1e-6) - 0.5
    p = sess.run(None, {sess.get_inputs()[0].name: x.transpose(2, 0, 1)[None]})[0][0, 0]
    if p.max() < 0.5:   # ما فيه موضوع: min-max بعده يحول صورة سادة لتشويش
        print("no subject"); sys.exit(3)
    p = (p - p.min()) / max(float(p.max() - p.min()), 1e-6)
    return cv2.resize((p * 255).astype(np.uint8), (W, H), interpolation=cv2.INTER_LANCZOS4)

if engine == "auto":
    engine = "model" if os.path.isfile(MODEL) else "plain"
if engine == "model" and not os.path.isfile(MODEL):
    print("نموذج قص الصور مو موجود: " + HINT); sys.exit(4)
alpha = model() if engine == "model" else plain()

ys, xs = np.nonzero(alpha > 8)
inst = 0
if xs.size:
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    _, _, st, _ = cv2.connectedComponentsWithStats((alpha > 127).astype(np.uint8), connectivity=8)
    inst = int(np.sum(st[1:, cv2.CC_STAT_AREA] >= 0.01 * (x1 - x0) * (y1 - y0)))
if not inst:
    print("no subject"); sys.exit(3)
out = np.dstack([img, alpha])
if not keep:
    out = out[y0:y1, x0:x1]
ok, enc = cv2.imencode(".png", out)
if not ok:
    print(f"ما انكتبت الصورة: {dst}"); sys.exit(1)
enc.tofile(dst)
print(f"ok {out.shape[1]}x{out.shape[0]} instances={inst}")
