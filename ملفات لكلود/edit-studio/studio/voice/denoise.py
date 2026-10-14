




import os, sys, time

MODEL = 'dpdfnet8_48khz_hr'
a = sys.argv[1:]


def opt(name, default=None):
    if name in a:
        i = a.index(name)
        v = a[i + 1]
        del a[i:i + 2]
        return v
    return default


models = opt('--models')
limit = opt('--attn-limit-db')
if models:
    os.environ['DPDFNET_CACHE_DIR'] = models
onnx = os.path.join(models, 'models', MODEL + '.onnx') if models else None

if a and a[0] == '--version':
    from importlib.metadata import version
    print('dpdfnet %s %s%s' % (version('dpdfnet'), MODEL, '' if not onnx or os.path.isfile(onnx) else ' (model missing)'))
    sys.exit(0)

import numpy as np, soundfile as sf
from dpdfnet.api import enhance

src, dst = a[0], a[1]
if onnx and not os.path.isfile(onnx):
    sys.exit('denoise: the model is not in %s' % models)
x, sr = sf.read(src, dtype='float32', always_2d=True)
t = time.time()
kw = {'model': MODEL}
if onnx:
    kw['onnx_path'] = onnx
if limit is not None:
    kw['attn_limit_db'] = float(limit)
y = np.stack([enhance(np.ascontiguousarray(x[:, c]), sr, **kw) for c in range(x.shape[1])], axis=1)
sf.write(dst, y.astype('float32'), sr, subtype='FLOAT')
print('seconds', round(time.time() - t, 1))
