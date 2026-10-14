
import sys, time, numpy as np, soundfile as sf
from nara_wpe.wpe import wpe
from nara_wpe.utils import stft, istft
src, dst = sys.argv[1], sys.argv[2]
taps = int(sys.argv[3]) if len(sys.argv) > 3 else 20
x, sr = sf.read(src, dtype='float64', always_2d=True)
t = time.time()
size, shift = 2048, 512
Y = stft(x.T, size=size, shift=shift).transpose(2, 0, 1)
Z = wpe(Y, taps=taps, delay=3, iterations=3, statistics_mode='full').transpose(1, 2, 0)
z = istft(Z, size=size, shift=shift)[:, :x.shape[0]].T
sf.write(dst, z.astype('float32'), sr, subtype='FLOAT')
print('seconds', round(time.time() - t, 1))
