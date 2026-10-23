#!/usr/bin/env python3





import subprocess, sys
import numpy as np, cv2


def imread(p, flag):

    try: buf = np.fromfile(p, np.uint8)
    except OSError: return None
    return cv2.imdecode(buf, flag) if buf.size else None


blk, idx, x0, y0, W0, H0, packed, pic, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6]), sys.argv[7] == '1', sys.argv[8], sys.argv[9]
ow = int(sys.argv[10]) if len(sys.argv) > 10 else 540

probe = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height', '-of', 'csv=p=0', blk], capture_output=True, text=True, check=True)
bw, bh = (int(v) for v in probe.stdout.strip().split(',')[:2])
r = subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-i', blk, '-vf',
                    f"select='eq(n\\,{idx})',scale=in_color_matrix=bt709:in_range=tv:out_range=pc:flags=accurate_rnd+full_chroma_int+full_chroma_inp,format=rgb24",
                    '-fps_mode', 'passthrough', '-frames:v', '1', '-f', 'rawvideo', '-'], capture_output=True, check=True)
if len(r.stdout) < bw * bh * 3: raise SystemExit(f'no frame {idx} in {blk}')
f = np.frombuffer(r.stdout[:bw * bh * 3], np.uint8).reshape(bh, bw, 3).astype(np.float32)

if pic != '-':
    bg = imread(pic, cv2.IMREAD_COLOR)
    if bg is None: raise SystemExit(f'cannot read {pic}')
    bg = cv2.cvtColor(cv2.resize(bg, (W0, H0), interpolation=cv2.INTER_AREA), cv2.COLOR_BGR2RGB).astype(np.float32)
else:
    bg = np.full((H0, W0, 3), 96, np.float32)
if packed:
    ch = bh // 2
    top, a = f[:ch], f[ch:2 * ch, :, :1] / 255
    cw = bw
else:
    ch, cw = bh, bw
    top, a = f, np.ones((bh, bw, 1), np.float32)

xa, ya, xb, yb = max(0, x0), max(0, y0), min(W0, x0 + cw), min(H0, y0 + ch)
if xb > xa and yb > ya:
    sub = (slice(ya - y0, yb - y0), slice(xa - x0, xb - x0))
    bg[ya:yb, xa:xb] = top[sub] + (1 - a[sub]) * bg[ya:yb, xa:xb]
im = cv2.cvtColor(np.rint(bg).clip(0, 255).astype(np.uint8), cv2.COLOR_RGB2BGR)
oh = round(H0 * ow / W0 / 2) * 2
cv2.imencode('.jpg', cv2.resize(im, (ow, oh), interpolation=cv2.INTER_AREA), [cv2.IMWRITE_JPEG_QUALITY, 82])[1].tofile(out)
print(out)
