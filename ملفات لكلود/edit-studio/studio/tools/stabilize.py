
import json
import math
import sys

import cv2
import numpy as np


STEADY_PX = 0.6


def main():
    src, t0, t1 = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
    cap = cv2.VideoCapture(src)
    if not cap.isOpened():
        print(json.dumps({"error": "open"}))
        return 2
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    cap.set(cv2.CAP_PROP_POS_MSEC, t0 * 1000.0)
    want = max(1, int(round((t1 - t0) * fps)))
    prev = None
    moves = []
    scale = None
    for i in range(want):
        ok, frame = cap.read()
        if not ok:
            break
        if scale is None:
            h0, w0 = frame.shape[:2]
            scale = 480.0 / max(w0, h0)
        small = cv2.resize(frame, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
        gray = cv2.cvtColor(small, cv2.COLOR_BGR2GRAY)
        dx = dy = da = 0.0
        if prev is not None:
            pts = cv2.goodFeaturesToTrack(prev, maxCorners=200, qualityLevel=0.01, minDistance=20, blockSize=3)
            if pts is not None and len(pts) >= 8:
                nxt, st, _ = cv2.calcOpticalFlowPyrLK(prev, gray, pts, None)
                good = st.reshape(-1) == 1
                if good.sum() >= 8:
                    m, _ = cv2.estimateAffinePartial2D(pts[good], nxt[good])
                    if m is not None:
                        dx, dy, da = float(m[0, 2]), float(m[1, 2]), math.atan2(m[1, 0], m[0, 0])
        moves.append((dx, dy, da))
        prev = gray
        if i % 15 == 0:
            print(f"p {i / want:.3f}", file=sys.stderr, flush=True)
    cap.release()
    if not moves:
        print(json.dumps({"error": "empty"}))
        return 2
    h, w = gray.shape[:2]
    path = np.cumsum(np.array(moves), axis=0)
    r = max(1, int(round(fps / 2)))
    pad = np.pad(path, ((r, r), (0, 0)), mode="edge")
    kernel = np.ones(2 * r + 1) / (2 * r + 1)
    smooth = np.stack([np.convolve(pad[:, j], kernel, mode="valid") for j in range(3)], axis=1)
    corr = smooth - path
    d = [[round(c[0] / w, 5), round(c[1] / h, 5), round(math.degrees(c[2]), 4)] for c in corr]
    need = max(max(abs(x[0]) for x in d) * 2, max(abs(x[1]) for x in d) * 2) + max(abs(x[2]) for x in d) * math.pi / 180
    s = round(min(1.15, 1.0 + need + 0.01), 4)

    shake = float(np.mean([math.hypot(m[0], m[1]) for m in moves[1:]])) if len(moves) > 1 else 0.0
    print(json.dumps({"t0": t0, "fps": fps, "s": s, "d": d, "n": len(d), "shake": round(shake, 3), "steady": shake < STEADY_PX}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
