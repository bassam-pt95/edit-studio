# -*- coding: utf-8 -*-
"""تحميل faster-whisper على ويندوز: كرت NVIDIA بـfloat16 لو يشتغل، والا int8_float16 على الكرت، والا المعالج بـint8.

load(name) → (model, 'cuda'|'cpu'). يستخدمه 01b_transcribe.py. نفس الكود حرفيا بالاستوديو (tools/np/fw_device.py، اللي يستخدمه
transcribe.py وstt-worker.py)، وهو الاصل: الجزء بين خطي «one copy» ينكتب من هناك بـsync-whisper.mjs، واختبار يتاكد انهم نفس الشي.
  • ctranslate2 ما يجيب cuBLAS: ينزل من pip (nvidia-cublas-cu12)، ومجلداته nvidia/*/bin تنضاف لـPATH ولـadd_dll_directory
    (الثاني لحاله ما كفى).
  • cuBLAS ينحمل اول تفريغ، فثانية سكوت تتفرغ على الكرت قبل: لو ناقص يطلع الخطا هناك ويكمل على المعالج بدل ما يطيح.
  • ثانية السكوت هذي ببايثون لحاله وله 30 ثانية (VEB_STT_PROBE_SECS): مع cuBLAS ناقص كان int8_float16 يعلق باول تفريغ،
    والتعليق ما ينلقط كخطا. الكرت اللي ما يرد ينقفل والتفريغ يكمل على المعالج، وبالسجل «no answer in 30 s».
  • كرت ذاكرته ما تكفي float16 يجرب int8_float16 على الكرت قبل المعالج. اي غلط ثاني يروح للمعالج على طول.
  • VEB_STT_DEVICE=cpu يجبر المعالج. VEB_STT_COMPUTE نوع واحد على الكرت بدل السلسلة (لو فشل: المعالج).
  • البذرة ثابتة (VEB_STT_SEED، الافتراضي 0): نفس الصوت يعطي نفس a.json كل مرة.
"""
import os
if os.name == 'nt':   # تحذير symlinks الانجليزي باول تنزيل للنموذج: لازم قبل استيراد huggingface_hub (يقراه وقت الاستيراد)
    os.environ.setdefault('HF_HUB_DISABLE_SYMLINKS_WARNING', '1')

# ── one copy: B Studio tools/np/fw_device.py = the montage skill's scripts/_whisper.py (sync-whisper.mjs writes it) ──
import os, subprocess, sys

THREADS = min(8, max(4, (os.cpu_count() or 8) // 2))   # half the cores, 4 to 8 (measured on 16: 8 a little faster than 4, 16 slower)
CUDA_TYPES = ('float16', 'int8_float16')   # on the GPU in this order, then the CPU
PROBE_SECS = float(os.environ.get('VEB_STT_PROBE_SECS') or 30)   # the card's answer to its first second of silence


def _nvidia_dlls():
    """ctranslate2 does not ship cuBLAS: the pip NVIDIA wheels' nvidia/*/bin folders go on the DLL search path and on
    PATH (add_dll_directory alone is not enough)."""
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
    """The model on the GPU, with a second of silence transcribed (cuBLAS loads at the first transcription). A model
    whose probe fails is unloaded before the next type is tried: with HF_HUB_OFFLINE=1 dropping it is not enough, its
    GPU memory stays taken."""
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
    """None when the card transcribes in type `ct` (_cuda in a Python of its own, this file run with --probe), else why: its
    last error line, or «no answer in 30 s» (killed: with cuBLAS missing int8_float16 hung in its first transcription)."""
    try:
        r = subprocess.run([sys.executable, os.path.abspath(__file__), '--probe', name, ct], stdin=subprocess.DEVNULL,
                           capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=PROBE_SECS,
                           creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))   # Windows: no console window
    except subprocess.TimeoutExpired:
        return 'no answer in %g s' % PROBE_SECS
    if r.returncode == 0 and 'probe-ok' in r.stdout:
        return None
    return ([ln for ln in r.stderr.splitlines() if ln.strip()] or ['exit %s' % r.returncode])[-1]


def load(name, WhisperModel=None):
    """(model, 'cuda'|'cpu'). float16 rather than 'auto' (int8_float16 on an RTX card). Each type is tried first in
    _probe; the model is loaded here only on a type that answered there. Any error but memory (cuBLAS missing, a type the
    card does not support, no answer) goes straight to the CPU. The seed is fixed (VEB_STT_SEED, 0): whisper samples
    again with temperature on a weak window, and the same sound gives the same words every time.
    VEB_STT_COMPUTE: that one type on the GPU instead of the chain; VEB_STT_DEVICE=cpu: never the card."""
    _nvidia_dlls()
    if WhisperModel is None:
        from faster_whisper import WhisperModel
    try:
        import ctranslate2
        getattr(ctranslate2, 'set_random_seed', lambda s: None)(int(os.environ.get('VEB_STT_SEED', '0')))
        cards = ctranslate2.get_cuda_device_count()
    except Exception:  # noqa: BLE001
        cards = 0
    if os.environ.get('VEB_STT_DEVICE') != 'cpu' and cards > 0:
        for ct in (os.environ['VEB_STT_COMPUTE'],) if os.environ.get('VEB_STT_COMPUTE') else CUDA_TYPES:
            why = _probe(name, ct)
            if why is None:
                try:
                    return _cuda(WhisperModel, name, ct), 'cuda'
                except Exception as e:  # noqa: BLE001
                    why = str(e)
            print('CUDA %s unavailable: %s' % (ct, why), file=sys.stderr, flush=True)
            if 'memory' not in why.lower() and 'alloc' not in why.lower():
                break
        print('CUDA unavailable, using CPU', file=sys.stderr, flush=True)
    return WhisperModel(name, device='cpu', compute_type='int8', cpu_threads=THREADS), 'cpu'


if __name__ == '__main__' and sys.argv[1:2] == ['--probe']:
    # _probe's child: the model on the card in one type and a second of silence, then «probe-ok»; an error ends it non-zero
    _nvidia_dlls()
    from faster_whisper import WhisperModel
    _cuda(WhisperModel, sys.argv[2], sys.argv[3])
    print('probe-ok', flush=True)
# ── end of the copy ──
