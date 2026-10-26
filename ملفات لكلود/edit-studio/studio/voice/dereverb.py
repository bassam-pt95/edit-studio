





import os, sys, time
os.environ.setdefault('OPENBLAS_NUM_THREADS', '1'); os.environ.setdefault('VECLIB_MAXIMUM_THREADS', '1')
from concurrent.futures import ThreadPoolExecutor
import numpy as np, soundfile as sf
from nara_wpe.wpe import wpe
from nara_wpe.utils import stft, istft
src, dst = sys.argv[1], sys.argv[2]
taps = int(sys.argv[3]) if len(sys.argv) > 3 else 20
x, sr = sf.read(src, dtype='float64', always_2d=True)
t = time.time()
size, shift = 2048, 512


POOL = ThreadPoolExecutor(max_workers=max(1, min(16, (os.cpu_count() or 2) // 2)))


def clean(seg):
    Y = stft(seg.T, size=size, shift=shift).transpose(2, 0, 1)

    def job(a): Y[a:a + 16] = wpe(Y[a:a + 16], taps=taps, delay=3, iterations=3, statistics_mode='full')
    list(POOL.map(job, range(0, Y.shape[0], 16)))
    return istft(Y.transpose(1, 2, 0), size=size, shift=shift)[:, :seg.shape[0]].T


n = x.shape[0]
B, O = int(10 * sr), int(1 * sr)
if n <= int(15 * sr):
    z = clean(x)
else:
    z = np.zeros_like(x)
    starts = list(range(0, n, B))
    if n - starts[-1] < 5 * O: starts.pop()
    ramp = np.arange(2 * O) / (2 * O) + 0.5 / (2 * O)
    for i, s in enumerate(starts):
        last = i == len(starts) - 1
        a, b = max(0, s - O), n if last else s + B + O
        w = np.ones(b - a)
        if a > 0: w[:2 * O] = ramp
        if not last: w[-2 * O:] = 1 - ramp
        z[a:b] += clean(x[a:b]) * w[:, None]
        print('piece', i + 1, 'of', len(starts), flush=True)
sf.write(dst, z.astype('float32'), sr, subtype='FLOAT')
print('seconds', round(time.time() - t, 1))
