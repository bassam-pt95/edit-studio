

import os, subprocess, sys

THREADS = min(8, max(4, (os.cpu_count() or 8) // 2))
CUDA_TYPES = ('float16', 'int8_float16')
PROBE_SECS = float(os.environ.get('VEB_STT_PROBE_SECS') or 30)


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


def _probe(name, ct):

    try:
        r = subprocess.run([sys.executable, os.path.abspath(__file__), '--probe', name, ct], stdin=subprocess.DEVNULL,
                           capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=PROBE_SECS,
                           creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    except subprocess.TimeoutExpired:
        return 'no answer in %g s' % PROBE_SECS
    if r.returncode == 0 and 'probe-ok' in r.stdout:
        return None
    return ([ln for ln in r.stderr.splitlines() if ln.strip()] or ['exit %s' % r.returncode])[-1]


def load(name, WhisperModel=None):

    _nvidia_dlls()
    if WhisperModel is None:
        from faster_whisper import WhisperModel
    try:
        import ctranslate2
        getattr(ctranslate2, 'set_random_seed', lambda s: None)(int(os.environ.get('VEB_STT_SEED', '0')))
        cards = ctranslate2.get_cuda_device_count()
    except Exception:
        cards = 0
    if os.environ.get('VEB_STT_DEVICE') != 'cpu' and cards > 0:
        for ct in (os.environ['VEB_STT_COMPUTE'],) if os.environ.get('VEB_STT_COMPUTE') else CUDA_TYPES:
            why = _probe(name, ct)
            if why is None:
                try:
                    return _cuda(WhisperModel, name, ct), 'cuda'
                except Exception as e:
                    why = str(e)
            print('CUDA %s unavailable: %s' % (ct, why), file=sys.stderr, flush=True)
            if 'memory' not in why.lower() and 'alloc' not in why.lower():
                break
        print('CUDA unavailable, using CPU', file=sys.stderr, flush=True)
    return WhisperModel(name, device='cpu', compute_type='int8', cpu_threads=THREADS), 'cpu'


if __name__ == '__main__' and sys.argv[1:2] == ['--probe']:

    _nvidia_dlls()
    from faster_whisper import WhisperModel
    _cuda(WhisperModel, sys.argv[2], sys.argv[3])
    print('probe-ok', flush=True)

