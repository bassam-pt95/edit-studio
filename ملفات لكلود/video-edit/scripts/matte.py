# -*- coding: utf-8 -*-
"""قناع الشخص بنموذج ONNX (MODNet) على كرت الشاشة (DirectML) او المعالج — حواف الشعر لتاثير الكلام ورا الشخص بالويندوز.

    python matte.py <inDir> <outDir> [feather] [guideDir]

نفس اقنعة personmask: <outDir>/<اسم>.png قناع رمادي بحجم الفريم (ابيض = الشخص). ما يكتب meta.json: الوجوه من personmask.
guideDir: اقنعة personmask لنفس الفريمات. النموذج ياخذ بس الحافة حول شخصها، وداخلها يبقى منها (ما يتخرم، وما يطلع غرض بعيد).
النموذج <VEB_HOME>/tools/models/modnet.onnx، ينزل مع ادوات كرت الشاشة بـ bash scripts/00_setup.sh --install --cutout
VEB_MATTE=cpu يجبره على المعالج.
"""
import sys, os
if os.name == 'nt' and not sys.flags.utf8_mode and (sys.flags.ignore_environment or not os.environ.get('PYTHONUTF8')):
    os.environ['PYTHONUTF8'] = '1'; import subprocess; sys.exit(subprocess.call([sys.executable, '-X', 'utf8', *sys.orig_argv[1:]]))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _paths

a = sys.argv
if len(a) < 3:
    print("usage: matte.py <inDir> <outDir> [feather] [guideDir]"); sys.exit(2)
in_dir, out_dir = a[1], a[2]
feather = float(a[3]) if len(a) > 3 else 2.5
guide = a[4] if len(a) > 4 else None
MODEL = _paths.data("tools", "models", "modnet.onnx")

try:
    import numpy as np
    import cv2
    import onnxruntime as ort
except ImportError:
    print('⚠️ ناقص onnxruntime او opencv — شغل bash scripts/00_setup.sh --install --cutout')
    sys.exit(3)
if not os.path.isfile(MODEL):
    print('⚠️ نموذج القص ناقص (' + MODEL + ') — شغل bash scripts/00_setup.sh --install --cutout')
    sys.exit(3)
os.makedirs(out_dir, exist_ok=True)

# DirectML يبي mem_pattern مطفي وتنفيذ متسلسل. high_performance يختار الكرت الاقوى (NVIDIA) مو كرت المعالج المدمج
so = ort.SessionOptions()
so.enable_mem_pattern = False
so.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
prov = ['CPUExecutionProvider']
if os.environ.get('VEB_MATTE') != 'cpu' and 'DmlExecutionProvider' in ort.get_available_providers():
    prov.insert(0, ('DmlExecutionProvider', {'device_filter': 'gpu', 'performance_preference': 'high_performance'}))
try:
    sess = ort.InferenceSession(MODEL, so, providers=prov)
except Exception as e:
    if len(prov) == 1: raise
    print('⚠️ DirectML ما اشتغل (' + str(e).splitlines()[0][:120] + ')، نكمل بالمعالج')
    sess = ort.InferenceSession(MODEL, so, providers=['CPUExecutionProvider'])
used = sess.get_providers()[0]
print(('القص بكرت الشاشة' if used == 'DmlExecutionProvider' else 'القص بالمعالج') + ' (' + used + ')', flush=True)
INP = sess.get_inputs()[0].name

# cv2.imread وimwrite ما يفتحون مسار فيه حروف غير انجليزية بويندوز، فنقرا ونكتب البايتات بنفسنا مثل personmask.py
def imread_u(p, flag=cv2.IMREAD_COLOR):
    b = np.fromfile(p, np.uint8)
    return cv2.imdecode(b, flag) if b.size else None

def imwrite_u(p, m):
    ok, enc = cv2.imencode(".png", m)
    if ok: enc.tofile(p)
    return ok

# الضلع الطويل 512 والثاني بنفس النسبة، وكل ضلع ينقص لمضاعف 32 (1080x1920 -> 288x512). RGB من -1 الى 1.
# MODNet الاصلي ياخذ الضلع القصير 512 (512x896)، بس على سيلفي قريب بضو خافت يخرم الوجه ويطلع اغراض الغرفة؛ الفريم كله بـ512 يعطي الشخص كامل
def size_for(W, H, ref=512):
    rw, rh = (ref, int(H / W * ref)) if W >= H else (int(W / H * ref), ref)
    return rw - rw % 32, rh - rh % 32

# حافة 6 بكسل بمقاس النموذج (512) = ~22 بكسل بفريم 1920
K = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (13, 13))

jpgs = sorted(x for x in os.listdir(in_dir) if x.lower().endswith(".jpg"))
n = 0
for f in jpgs:
    img = imread_u(os.path.join(in_dir, f))
    if img is None:
        continue
    H, W = img.shape[:2]
    x = cv2.resize(img, size_for(W, H), interpolation=cv2.INTER_AREA)
    x = cv2.cvtColor(x, cv2.COLOR_BGR2RGB).astype(np.float32) / 127.5 - 1.0
    m = sess.run(None, {INP: np.ascontiguousarray(x.transpose(2, 0, 1)[None])})[0][0, 0]
    gp = os.path.join(guide, f[:-4] + ".png") if guide else ""
    g = imread_u(gp, cv2.IMREAD_GRAYSCALE) if os.path.isfile(gp) else None
    if g is not None:   # النموذج بس قرب حدود شخص personmask (الحافة ناعمة)، ولب شخصها يبقى
        g = cv2.resize(g, m.shape[::-1], interpolation=cv2.INTER_AREA).astype(np.float32) / 255
        gate = cv2.GaussianBlur(cv2.dilate((g >= 0.5).astype(np.float32), K), (0, 0), 2)
        m = np.maximum(m * gate, cv2.erode(g, K))
    m = cv2.resize(m, (W, H), interpolation=cv2.INTER_LINEAR)
    m = (np.clip(m, 0, 1) * 255).astype(np.uint8)
    if feather > 0:   # نفس ريشة personmask.py
        m = cv2.GaussianBlur(m, (0, 0), feather)
    imwrite_u(os.path.join(out_dir, f[:-4] + ".png"), m)
    n += 1

if jpgs and not n:
    print("❌ ما قدرت اقرا الفريمات (مسار فيه حروف غير انجليزية؟)", file=sys.stderr)
    sys.exit(4)
print(f"✅ {n} قناع")
