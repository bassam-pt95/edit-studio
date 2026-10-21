#!/usr/bin/env python3










import json, subprocess, sys
import numpy as np, cv2


def imread(p, flag):

    try: buf = np.fromfile(p, np.uint8)
    except OSError: return None
    return cv2.imdecode(buf, flag) if buf.size else None


sys.stdin.reconfigure(encoding='utf-8')
spec = json.load(sys.stdin)
W, H, THR = int(spec['W']), int(spec['H']), int(spec.get('thr', 16))


def probe(f):
    r = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height', '-of', 'csv=p=0', f], capture_output=True, text=True, check=True)
    w, h = (int(v) for v in r.stdout.strip().split(',')[:2])
    return w, h


def rgb_frames(f, w, h, select=None, seek=None):
    args = ['ffmpeg', '-nostdin', '-v', 'error'] + (['-ss', f'{seek:.4f}'] if seek is not None else []) + ['-i', f]
    vf = 'scale=in_color_matrix=bt709:in_range=tv:out_range=pc:flags=accurate_rnd+full_chroma_int+full_chroma_inp,format=rgb24'
    if select is not None: vf = f"select='{select}'," + vf
    args += ['-vf', vf, '-fps_mode', 'passthrough'] + (['-frames:v', '1'] if seek is not None else []) + ['-f', 'rawvideo', '-']
    out = subprocess.run(args, capture_output=True, check=True).stdout
    n = len(out) // (w * h * 3)
    return np.frombuffer(out[:n * w * h * 3], np.uint8).reshape(n, h, w, 3)


def alpha_of(fr, packed):
    if not packed: return np.full(fr.shape[:2], 255, np.uint8)
    ch = fr.shape[0] // 2
    return fr[ch:2 * ch, :, 0]


def placed(a, rect):

    x, y, w, h = (int(round(v)) for v in rect)
    out = np.zeros((H, W), np.uint8)
    if w <= 0 or h <= 0: return out
    a = cv2.resize(a, (w, h), interpolation=cv2.INTER_AREA if w < a.shape[1] else cv2.INTER_LINEAR)
    xa, ya, xb, yb = max(0, x), max(0, y), min(W, x + w), min(H, y + h)
    if xb > xa and yb > ya: out[ya:yb, xa:xb] = a[ya - y:yb - y, xa - x:xb - x]
    return out


def bounds(m):
    ys, xs = np.nonzero(m)
    return None if not len(xs) else [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]


new = spec['new']
bw, bh = probe(new['file'])
allf = rgb_frames(new['file'], bw, bh)
alphas = [alpha_of(f, new['packed']) for f in allf]

union = None
for k, x, y, w, h in new['frames']:
    if k < 0 or k >= len(alphas): continue
    b = bounds(placed(alphas[k], [x, y, w, h]) > THR)
    if b: union = b if union is None else [min(union[0], b[0]), min(union[1], b[1]), max(union[2], b[2]), max(union[3], b[3])]

cache = {}
samples = []
for s in spec.get('samples', []):
    k = int(s['k'])
    if k < 0 or k >= len(alphas): continue
    m = placed(alphas[k], s['rect']) > THR
    area = int(m.sum())
    capsin = 0
    if area:
        cm = np.zeros((H, W), bool)
        for x, y, w, h in s.get('caps', []):
            x0, y0, x1, y1 = max(0, int(x)), max(0, int(y)), min(W, int(x + w)), min(H, int(y + h))
            if x1 > x0 and y1 > y0: cm[y0:y1, x0:x1] = True
        capsin = int((m & cm).sum())
    others = []
    for o in s.get('others', []):
        try:
            if o.get('kind') == 'image':
                im = cache.get(o['file'])
                if im is None:
                    im = imread(o['file'], cv2.IMREAD_UNCHANGED)
                    cache[o['file']] = im
                if im is None: continue
                a = im[..., 3] if im.ndim == 3 and im.shape[2] == 4 else np.full(im.shape[:2], 255, np.uint8)
            else:
                ow, oh = cache.get(('size', o['file'])) or probe(o['file'])
                cache[('size', o['file'])] = (ow, oh)
                fr = rgb_frames(o['file'], ow, oh, seek=max(0.0, float(o['t'])))
                if not len(fr): continue
                a = alpha_of(fr[0], o.get('packed'))
            om = placed(a, o['rect']) > THR
        except Exception:
            continue
        cover = om.sum() / (W * H)
        both = int((m & om).sum())
        others.append({'id': o['id'], 'share': round(both / area, 4) if area else 0, 'backdrop': bool(cover > 0.5)})
    samples.append({'k': k, 'box': bounds(m), 'area': area, 'caps': round(capsin / area, 4) if area else 0, 'others': others})

print(json.dumps({'union': union, 'samples': samples}))
