#!/usr/bin/env python3







import csv, json, re, sys
import numpy as np

SR, N = 16000, 15600



NAMES = {'Whoosh, swoosh, swish': 'whoosh_swoosh_swish', 'Boom': 'boom', 'Thump, thud': 'thump_thud',
         'Clicking': 'click', 'Tick': 'tick', 'Bell': 'bell', 'Chime': 'chime', 'Wind chime': 'wind_chime', 'Gong': 'gong',
         'Beep, bleep': 'beep', 'Finger snapping': 'finger_snapping', 'Clapping': 'clapping',
         'Drum': 'drum', 'Bass drum': 'bass_drum', 'Snare drum': 'snare_drum', 'Percussion': 'percussion',
         'Music': 'music', 'Speech': 'speech'}


SCALE = {}


def snake(s):
    return re.sub(r'[^a-z0-9]+', '_', s.lower()).strip('_')


def labels_of(csv_file):
    with open(csv_file, encoding='utf-8', newline='') as f:
        rows = list(csv.reader(f))[1:]
    names = [r[2] for r in rows]
    missing = [k for k in NAMES if k not in names]
    if missing: raise SystemExit(f'error: not in {csv_file}: {", ".join(missing)}')
    return [NAMES.get(n) or snake(n) for n in names]


def arg(name):
    a = sys.argv
    return a[a.index(name) + 1] if name in a and a.index(name) + 1 < len(a) else None


if '--labels-only' in sys.argv:
    if arg('--labels'): labels_of(arg('--labels'))
    print('\n'.join(NAMES.values())); sys.exit(0)

pos = [x for i, x in enumerate(sys.argv[1:], 1) if not x.startswith('--') and sys.argv[i - 1] not in ('--model', '--labels')]
if not pos or not arg('--model') or not arg('--labels'):
    raise SystemExit('usage: hear.py <16 kHz wav> [window seconds] --model <yamnet.onnx> --labels <yamnet_class_map.csv>')
win = float(pos[1]) if len(pos) > 1 else 1.0
import soundfile as sf, onnxruntime as ort

labels = labels_of(arg('--labels'))
scale = np.array([SCALE.get(x, 1.0) for x in labels], np.float32)
a, sr = sf.read(pos[0], dtype='float32', always_2d=True)
if sr != SR: raise SystemExit(f'error: the audio is {sr} Hz, not {SR}')
a = a.mean(axis=1)
n = N if win <= 1 else round(win * SR)
hop = max(1, round(win * SR / 4))
if len(a) < n: a = np.pad(a, (0, n - len(a)))
starts = range(0, len(a) - n + 1, hop)

with open(arg('--model'), 'rb') as f:
    s = ort.InferenceSession(f.read(), providers=['CPUExecutionProvider'])
inp = s.get_inputs()[0]
out = s.get_outputs()[0].name
if len(inp.shape) == 2 and n == N:
    conf = np.concatenate([s.run([out], {inp.name: np.stack([a[t:t + n] for t in starts[i:i + 64]])})[0]
                           for i in range(0, len(starts), 64)])
else:
    conf = np.stack([s.run([out], {inp.name: a[t:t + n]})[0].mean(axis=0) for t in starts])
conf = np.minimum(conf * scale, 1.0)
lines = []
for t, c in zip(starts, conf):
    top = [i for i in np.argsort(-c)[:8] if c[i] >= 0.05]
    lines.append('{"t":%.2f,"d":%.2f,"top":[%s]}' % (t / SR, n / SR, ','.join('[%s,%.2f]' % (json.dumps(labels[i]), c[i]) for i in top)))
sys.stdout.buffer.write(('\n'.join(lines) + '\n').encode())
