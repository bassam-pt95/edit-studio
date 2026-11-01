
import os, sys

THREADS = min(8, max(4, (os.cpu_count() or 8) // 2))
CUDA_TYPES = ('float16', 'int8_float16')


def _nvidia_dlls():

    if os.name != 'nt':
        return
    import importlib.util
    spec = importlib.util.find_spec('nvidia')
    for root in (spec.submodule_search_locations if spec else None) or []:
        for n in sorted(os.listdir(root)):
            d = os.path.join(root, n, 'bin')
            if os.path.isdir(d):
                os.add_dll_directory(d)
                os.environ['PATH'] = d + os.pathsep + os.environ.get('PATH', '')


def _cuda(WhisperModel, name, ct):

    import numpy as np
    m = WhisperModel(name, device='cuda', compute_type=ct)
    try:
        segs, _ = m.transcribe(np.zeros(16000, np.float32), language='ar')
        list(segs)
    except Exception:
        m.model.unload_model()
        raise
    return m


def load(name, WhisperModel=None):

    _nvidia_dlls()
    if WhisperModel is None:
        from faster_whisper import WhisperModel
    try:
        import ctranslate2
        cards = ctranslate2.get_cuda_device_count()
    except Exception:
        cards = 0
    if os.environ.get('VEB_STT_DEVICE') != 'cpu' and cards > 0:
        for ct in (os.environ['VEB_STT_COMPUTE'],) if os.environ.get('VEB_STT_COMPUTE') else CUDA_TYPES:
            try:
                return _cuda(WhisperModel, name, ct), 'cuda'
            except Exception as e:
                print('CUDA %s unavailable: %s' % (ct, e), file=sys.stderr, flush=True)
                if 'memory' not in str(e).lower() and 'alloc' not in str(e).lower():
                    break
        print('CUDA unavailable, using CPU', file=sys.stderr, flush=True)
    return WhisperModel(name, device='cpu', compute_type='int8', cpu_threads=THREADS), 'cpu'
