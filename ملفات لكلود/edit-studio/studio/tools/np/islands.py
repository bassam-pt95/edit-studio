#!/usr/bin/env python3

import os, sys, json, argparse
import numpy as np

WIN, HOP = 0.010, 0.001


def open_wav(path):

    with open(path, 'rb') as f:
        head = f.read(12)
        if head[0:4] != b'RIFF' or head[8:12] != b'WAVE':
            raise SystemExit('not a WAV file: ' + path)
        fmt, o = None, 12
        while True:
            f.seek(o)
            h = f.read(8)
            if len(h) < 8:
                break
            cid, size = h[0:4], int.from_bytes(h[4:8], 'little')
            if cid == b'fmt ':
                b = f.read(16)
                fmt = dict(tag=int.from_bytes(b[0:2], 'little'), ch=int.from_bytes(b[2:4], 'little'),
                           sr=int.from_bytes(b[4:8], 'little'), bits=int.from_bytes(b[14:16], 'little'))
            elif cid == b'data' and fmt:
                total = os.path.getsize(path) - (o + 8)
                if size == 0 or size > total:
                    size = total
                fmt['off'] = o + 8
                fmt['n'] = size // (fmt['ch'] * fmt['bits'] // 8)
                if fmt['bits'] not in (16, 24, 32) or (fmt['tag'] == 3 and fmt['bits'] != 32):
                    raise SystemExit('unsupported WAV format (tag %d, %d bits)' % (fmt['tag'], fmt['bits']))
                return fmt
            o += 8 + size + (size & 1)
    raise SystemExit('no data chunk: ' + path)


def read_mono(path, w, f0, f1):

    f0, f1 = max(0, f0), min(w['n'], f1)
    if f1 <= f0:
        return np.zeros(0)
    bpf = w['ch'] * w['bits'] // 8
    raw = np.memmap(path, np.uint8, 'r', offset=w['off'] + f0 * bpf, shape=((f1 - f0) * bpf,))
    if w['tag'] == 3:
        x = np.frombuffer(raw, '<f4').astype(np.float64)
    elif w['bits'] == 16:
        x = np.frombuffer(raw, '<i2').astype(np.float64) / 32768.0
    elif w['bits'] == 24:
        u = np.asarray(raw).reshape(-1, 3).astype(np.int32)
        v = u[:, 0] | (u[:, 1] << 8) | (u[:, 2] << 16)
        v = np.where(v >= 1 << 23, v - (1 << 24), v)
        x = v.astype(np.float64) / 8388608.0
    else:
        x = np.frombuffer(raw, '<i4').astype(np.float64) / 2147483648.0
    x = x.reshape(-1, w['ch'])
    return x[:, 0] if w['ch'] == 1 else (x[:, 0] + x[:, 1]) / 2.0


def envelope(path, w):

    sr, n = w['sr'], w['n']
    W, H = int(round(WIN * sr)), int(round(HOP * sr))
    if n < W:
        return np.zeros(0), np.zeros(0)
    if W != 10 * H:
        mono = read_mono(path, w, 0, n)
        c = np.concatenate(([0.0], np.cumsum(mono * mono)))
        starts = np.arange(0, n - W + 1, H)
        ms = (c[starts + W] - c[starts]) / W
    else:
        nb = n // H
        blk = np.zeros(nb)
        step = H * 10000
        for a in range(0, nb * H, step):
            b = min(nb * H, a + step)
            m = read_mono(path, w, a, b)
            blk[a // H:b // H] = (m * m).reshape(-1, H).sum(axis=1)
        c = np.concatenate(([0.0], np.cumsum(blk)))
        j = np.arange(0, nb - 10 + 1)
        ms = (c[j + 10] - c[j]) / W
        starts = j * H
    db = 10.0 * np.log10(np.maximum(ms, 1e-12))
    t = (starts + W / 2.0) / sr
    return t, db


def runs_of(mask):

    if not len(mask):
        return []
    d = np.diff(np.concatenate(([0], mask.astype(np.int8), [0])))
    s = np.flatnonzero(d == 1)
    e = np.flatnonzero(d == -1) - 1
    return list(zip(s.tolist(), e.tolist()))


def islands(t, db, threshold, gap, minlen):
    runs = runs_of(db >= threshold)
    win_pts, gap_pts, min_pts = int(round(WIN / HOP)), int(round(gap / HOP)), int(round(minlen / HOP))
    merged = []
    for i0, i1 in runs:
        if merged:
            below = i0 - merged[-1][1] - 1
            if (below - 1) + win_pts < gap_pts:
                merged[-1][1] = i1
                continue
        merged.append([i0, i1])
    out = []
    for i0, i1 in merged:
        if i1 - i0 < min_pts:
            continue
        out.append({'s': round(float(t[i0]), 4), 'e': round(float(t[i1]), 4), 'peak': round(float(db[i0:i1 + 1].max()), 1)})
    return out


def level_at(path, w, ts):
    sr = w['sr']
    W = int(round(WIN * sr))
    out = []
    for x in ts:
        a = int(round(x * sr - W / 2.0))
        a = max(0, min(w['n'] - W, a))
        seg = read_mono(path, w, a, a + W)
        ms = float(np.mean(seg * seg)) if len(seg) else 0.0
        out.append(round(10.0 * np.log10(max(ms, 1e-12)), 1))
    return out


def soft(path, w, asks, floor):

    SOFT_IN, SOFT_OUT, SOFT_LEVEL, LEAD, RULE_TAIL = 0.06, 0.08, -52.0, 0.02, 0.01
    sr = w['sr']
    W, H = int(round(WIN * sr)), int(round(HOP * sr))

    def env(t0, t1):
        a = max(0, int(round(t0 * sr - W / 2.0)))
        b = min(w['n'], int(round(t1 * sr + W / 2.0)))
        x = read_mono(path, w, a, b)
        if len(x) < W:
            return np.zeros(0), np.zeros(0)
        c = np.concatenate(([0.0], np.cumsum(x * x)))
        st = np.arange(0, len(x) - W + 1, H)
        return (a + st + W / 2.0) / sr, 10.0 * np.log10(np.maximum((c[st + W] - c[st]) / W, 1e-12))

    lvl = max(-60.0, floor + 10.0)
    out = []
    for s, e, s_lim, e_lim in asks:
        start = end = None
        t, db = env(max(s_lim, s - SOFT_IN), s)
        if len(t):
            j = len(t) - 1
            while j > 0 and db[j - 1] >= lvl:
                j -= 1
            if db[j] >= lvl and s - t[j] > LEAD + 0.005:
                start = round(float(t[j]) - 0.005, 4)
        t, db = env(e, min(e_lim, e + SOFT_OUT))
        if len(t):
            on = np.flatnonzero(db >= SOFT_LEVEL)
            last = None
            for i in on:
                if (t[i] - (t[last] if last is not None else e)) > 0.015:
                    break
                last = i
            if last is not None and t[last] - e > RULE_TAIL + 0.005:
                end = round(float(t[last]) + 0.005, 4)
        out.append({'start': start, 'end': end})
    return out


def json_arg(v):

    if v.startswith('@'):
        with open(v[1:], encoding='utf-8-sig') as f:
            return json.load(f)
    return json.loads(v)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('pcm')
    ap.add_argument('--threshold', type=float, default=-45.0)
    ap.add_argument('--gap', type=float, default=0.15)
    ap.add_argument('--min', type=float, default=0.04)
    ap.add_argument('--floor-limit', type=float, default=-51.0)
    ap.add_argument('--floor-margin', type=float, default=6.0)
    ap.add_argument('--at', default=None, help='JSON list of times (s): levels only')
    ap.add_argument('--soft', default=None, help='JSON list of [s, e, s_limit, e_limit]: soft letters at the edges')
    ap.add_argument('--floor', type=float, default=-120.0)
    a = ap.parse_args()
    w = open_wav(a.pcm)
    if a.soft is not None:
        print(json.dumps({'edges': soft(a.pcm, w, json_arg(a.soft), a.floor)}))
        return
    if a.at is not None:
        print(json.dumps({'levels': level_at(a.pcm, w, json_arg(a.at))}))
        return
    t, db = envelope(a.pcm, w)
    floor = float(np.percentile(db, 10)) if len(db) else -120.0
    thr, adjusted = a.threshold, False
    if floor > a.floor_limit:
        thr, adjusted = floor + a.floor_margin, True
    res = {'sr': w['sr'], 'ch': w['ch'], 'samples': int(w['n']), 'dur': round(w['n'] / w['sr'], 6),
           'threshold': round(thr, 1), 'floor': round(floor, 1), 'adjusted': adjusted,
           'islands': islands(t, db, thr, a.gap, a.min)}
    print(json.dumps(res))


if __name__ == '__main__':
    main()
