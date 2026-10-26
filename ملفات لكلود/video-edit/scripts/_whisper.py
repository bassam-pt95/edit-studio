# -*- coding: utf-8 -*-
"""تحميل faster-whisper على ويندوز: كرت NVIDIA بـfloat16 لو يشتغل، والا int8_float16 على الكرت، والا المعالج بـint8.

load(name) → (model, 'cuda'|'cpu'). يستخدمه 01b_transcribe.py (وstt-worker.py حق الاستوديو فيه نسخة منه).
  • ctranslate2 ما يجيب cuBLAS: ينزل من pip (nvidia-cublas-cu12)، ومجلداته nvidia/*/bin تنضاف هنا لـPATH
    ولـadd_dll_directory (الثاني لحاله ما كفى).
  • cuBLAS ينحمل اول تفريغ، فثانية سكوت تتفرغ هنا: لو ناقص يطلع الخطا هنا ويكمل على المعالج بدل ما يطيح.
  • كرت ذاكرته ما تكفي float16 يجرب int8_float16 على الكرت قبل المعالج. اي غلط ثاني (مثلا cuBLAS ناقص، او الكرت
    ما يدعم النوع) يروح للمعالج على طول: مع cuBLAS ناقص كان int8_float16 يعلق باول تفريغ.
  • VEB_STT_DEVICE=cpu يجبر المعالج. VEB_STT_COMPUTE نوع واحد على الكرت بدل السلسلة (لو فشل: المعالج).
  • لما نافذة تطلع مكررة او ضعيفة يعيدها whisper بحرارة (يسحب الكلمات بالقرعة)، فالكلمات تتغير من مرة لمرة.
    البذرة ثابتة (VEB_STT_SEED، الافتراضي 0): نفس الصوت يعطي نفس a.json كل مرة.
"""
import os, sys, importlib.util
if os.name == 'nt':   # تحذير symlinks الانجليزي باول تنزيل للنموذج: لازم قبل استيراد huggingface_hub (يقراه وقت الاستيراد)
    os.environ.setdefault('HF_HUB_DISABLE_SYMLINKS_WARNING', '1')

# خيوط المعالج: الافتراضي 4. نص الانوية لين 8 (قسناها على 16 نواة: 8 اسرع شوي من 4، و16 ابطا من 4)
THREADS = min(8, max(4, (os.cpu_count() or 8) // 2))
# float16 اول (قسناها على RTX 5090): الدقة متعادلة (425 موضع يختلف فيه النصين في كلام 38 دقيقة: float16 اقرب لقراية
# الموضع لحاله في 141 وint8_float16 في 135)، وعلى الكلام الطويل اسرع (358 ثانية ضد 430)، وعلى مقطع 96 ثانية ابطا
# بثانية تقريبا. int8_float16 ياخذ من ذاكرة الكرت اقل بـ2.5 قيقا، فهو البديل لما float16 ما يكفيه مكان.
CUDA_TYPES = ('float16', 'int8_float16')   # على الكرت بالترتيب، وبعدها المعالج


def _nvidia_dlls():
    if os.name != 'nt':
        return
    spec = importlib.util.find_spec('nvidia')
    for root in (spec.submodule_search_locations if spec else None) or []:
        for n in sorted(os.listdir(root)):
            d = os.path.join(root, n, 'bin')
            if os.path.isdir(d):
                os.add_dll_directory(d)
                os.environ['PATH'] = d + os.pathsep + os.environ.get('PATH', '')


def _cuda(WhisperModel, name, ct):
    # بدالة لحالها: لو فشل، الموديل ينفك من ذاكرة الكرت قبل النوع اللي بعده. unload_model لان مسح الموديل بس
    # ما يكفي مع HF_HUB_OFFLINE=1 (الذاكرة تبقى محجوزة والنوع اللي بعده ينحمل فوقها)
    import numpy as np
    m = WhisperModel(name, device='cuda', compute_type=ct)
    try:
        segs, _ = m.transcribe(np.zeros(16000, np.float32), language='ar')
        list(segs)
    except Exception:
        m.model.unload_model()
        raise
    return m


def load(name):
    _nvidia_dlls()
    import ctranslate2
    from faster_whisper import WhisperModel
    getattr(ctranslate2, 'set_random_seed', lambda s: None)(int(os.environ.get('VEB_STT_SEED', '0')))
    if os.environ.get('VEB_STT_DEVICE') != 'cpu' and ctranslate2.get_cuda_device_count() > 0:
        for ct in (os.environ['VEB_STT_COMPUTE'],) if os.environ.get('VEB_STT_COMPUTE') else CUDA_TYPES:
            try:
                return _cuda(WhisperModel, name, ct), 'cuda'
            except Exception as e:  # noqa: BLE001
                print('CUDA %s unavailable: %s' % (ct, e), file=sys.stderr, flush=True)
                if 'memory' not in str(e).lower() and 'alloc' not in str(e).lower():
                    break
        print('CUDA unavailable, using CPU', file=sys.stderr, flush=True)
    return WhisperModel(name, device='cpu', compute_type='int8', cpu_threads=THREADS), 'cpu'
