#!/usr/bin/env python3









import json, math, os, re, subprocess, sys
import numpy as np, cv2

png_dir, out, fn, fd = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
crf0 = int(sys.argv[5]) if len(sys.argv) > 5 else 12
WHOLE = len(sys.argv) > 6 and sys.argv[6] == 'whole'
FR = f'{fn}/{fd}'
files = sorted(((int(m.group(1)), os.path.join(png_dir, n)) for n in os.listdir(png_dir)
                if (m := re.search(r'(\d+)\.png$', n))), key=lambda x: x[0])
if not files:
    print(json.dumps({'empty': True, 'why': 'no frames'})); sys.exit(0)


def imread(p, flag):

    try: buf = np.fromfile(p, np.uint8)
    except OSError: return None
    return cv2.imdecode(buf, flag) if buf.size else None


def load(p):
    im = imread(p, cv2.IMREAD_UNCHANGED)
    if im is None: raise SystemExit(f'cannot read {p}')
    if im.ndim == 2: im = cv2.cvtColor(im, cv2.COLOR_GRAY2BGRA)
    if im.shape[2] == 3: im = np.concatenate([im, np.full(im.shape[:2] + (1,), 255, np.uint8)], 2)
    return im


H0, W0 = load(files[0][1]).shape[:2]
visible, opaque = [], True
x0, y0, x1, y1 = W0, H0, 0, 0
for f, p in files:
    a = load(p)[..., 3]
    nz = a > 0
    if not nz.any(): visible.append(False); continue
    visible.append(True)
    if a.min() < 255: opaque = False
    ys, xs = np.nonzero(nz)
    x0, y0, x1, y1 = min(x0, int(xs.min())), min(y0, int(ys.min())), max(x1, int(xs.max()) + 1), max(y1, int(ys.max()) + 1)
if not any(visible):
    print(json.dumps({'empty': True, 'why': 'all frames transparent', 'min': files[0][0]})); sys.exit(0)
i0 = visible.index(True); i1 = len(visible) - 1 - visible[::-1].index(True)
if WHOLE: i0, i1 = 0, len(visible) - 1
kept = files[i0:i1 + 1]
if any(not v for v in visible[i0:i1 + 1]): opaque = False
if opaque:
    x0, y0, cw, ch = 0, 0, W0, H0; W, H = W0, H0
else:
    x0, y0, x1, y1 = max(0, x0 - 4), max(0, y0 - 4), min(W0, x1 + 4), min(H0, y1 + 4)
    if (x1 - x0) % 2: x1 = x1 + 1 if x1 < W0 else x1; x0 = x0 - 1 if (x1 - x0) % 2 else x0
    if (y1 - y0) % 2: y1 = y1 + 1 if y1 < H0 else y1; y0 = y0 - 1 if (y1 - y0) % 2 else y0
    cw, ch = x1 - x0, y1 - y0; W, H = cw, ch * 2


def frame_rgb(p):
    im = load(p)
    rgb = cv2.cvtColor(im[..., :3], cv2.COLOR_BGR2RGB)[y0:y0 + ch, x0:x0 + cw]
    a = im[y0:y0 + ch, x0:x0 + cw, 3]
    return rgb, a


def encode(crf):
    tmp = out + '.tmp.mp4'
    pr = subprocess.Popen(['ffmpeg', '-nostdin', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', FR,
                           '-i', '-', '-vf', 'scale=out_color_matrix=bt709:in_range=pc:out_range=tv:flags=accurate_rnd+full_chroma_int,format=yuv420p',
                           '-c:v', 'libx264', '-crf', str(crf), '-preset', 'medium', '-g', '15', '-keyint_min', '15', '-sc_threshold', '0',
                           '-colorspace', 'bt709', '-color_primaries', 'bt709', '-color_trc', 'bt709', '-color_range', 'tv',
                           '-movflags', '+faststart', tmp], stdin=subprocess.PIPE)
    for _, p in kept:
        rgb, a = frame_rgb(p)
        if opaque: o = rgb
        else:
            top = np.rint(rgb.astype(np.float32) * (a.astype(np.float32) / 255)[..., None]).clip(0, 255).astype(np.uint8)
            o = np.concatenate([top, np.repeat(a[..., None], 3, 2)], 0)
        pr.stdin.write(np.ascontiguousarray(o).tobytes())
    pr.stdin.close()
    if pr.wait() != 0: raise SystemExit('ffmpeg encode failed')
    os.replace(tmp, out)


def decode(idx):
    sel = '+'.join(f'eq(n\\,{i})' for i in idx)
    r = subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-i', out, '-vf',
                        f"select='{sel}',scale=in_color_matrix=bt709:in_range=tv:out_range=pc:flags=accurate_rnd+full_chroma_int+full_chroma_inp,format=rgb24",
                        '-fps_mode', 'passthrough', '-f', 'rawvideo', '-'], capture_output=True, check=True)
    return np.frombuffer(r.stdout, np.uint8).reshape(len(idx), H, W, 3)


def psnr(a, b):
    mse = np.mean((a - b) ** 2)
    return 99.0 if mse == 0 else 10 * math.log10(255 ** 2 / mse)


n = len(kept)
idx = sorted({0, n // 2, n - 1})


def check():
    dec = decode(idx); res = []
    for k, i in enumerate(idx):
        rgb, a = frame_rgb(kept[i][1])
        rgb = rgb.astype(np.float64)
        if opaque: ref, got = rgb, dec[k].astype(np.float64)
        else:
            af = a.astype(np.float64)[..., None] / 255
            ref = rgb * af + (1 - af) * 128.0
            da = dec[k][ch:, :, :1].astype(np.float64) / 255
            got = dec[k][:ch].astype(np.float64) + (1 - da) * 128.0
        res.append(round(psnr(np.rint(ref).clip(0, 255), np.rint(got).clip(0, 255)), 2))
    return res


crf = crf0
encode(crf); ps = check()
if min(ps) < 40 and crf > 4:
    crf = 4; encode(crf); ps = check()
print(json.dumps({'empty': False, 'min': files[0][0], 'first': kept[0][0], 'last': kept[-1][0], 'n': n, 'kind': 'opaque' if opaque else 'alpha',
                  'W': W, 'H': H, 'x0': int(x0), 'y0': int(y0), 'cw': int(cw), 'ch': int(ch), 'frameW': W0, 'frameH': H0,
                  'crf': crf, 'checkFrames': [kept[i][0] for i in idx], 'psnr': ps, 'ok': min(ps) >= 40}))
