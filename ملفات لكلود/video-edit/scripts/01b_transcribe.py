#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""01b_transcribe.py <work> [--model large-v3|large-v3-turbo|medium] [--lang ar] [--batched]

التفريغ بتوقيت الكلمة — يكتب <work>/a.json بنفس صيغة وِسبر (segments[].words[].start/end)
فيقرأه 02_captions.py و10_script_edit.py بلا تغيير.

المحرّك حسب الجهاز:
  • ماك بمعالج أبل (M1 وأحدث): mlx-whisper على معالج الرسوميات — أسرع بمرات.
  • ويندوز أو ماك إنتل: faster-whisper (كرت NVIDIA لو موجود، وإلا المعالج).
النموذج large-v3 هو الأدق للعربي. medium أسرع وأغلاطه أكثر بوضوح (قِسناها: ~20٪ أغلاط زيادة بالعامية).
⛔ البرومت باللهجة (initial_prompt) ما نفع بالتجربة. الحل: large-v3 + dialect.json + تصحيحك بـfixes.json.
⛔ large-v3 «يفصّح» العامية أحياناً («اللي الناس كانوا»→«التي كان الناس»). لو عندك سكربت المتحدث،
   قارن التفريغ به جملة جملة وصحّح لكلامه هو، لا للفصحى.
--batched (faster-whisper على كرت NVIDIA): يقسم الكلام عند السكتات لقطع لين 6 ثواني ويفرغها دفعات مع بعض، اسرع
   بمرات بالكلام الطويل، بس مسودة: كل قطعة بلا سياق اللي قبلها، فبعض الكلمات وحدود الجمل تختلف عن العادي.
   VEB_STT_BATCH حجم الدفعة (الافتراضي 8، اقل لو ذاكرة الكرت ما تكفي).
"""
import sys, os, json, time, subprocess, platform
if os.name == 'nt' and not sys.flags.utf8_mode and (sys.flags.ignore_environment or not os.environ.get('PYTHONUTF8')):
    os.environ['PYTHONUTF8'] = '1'; import subprocess; sys.exit(subprocess.call([sys.executable, '-X', 'utf8', *sys.orig_argv[1:]]))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _paths

if len(sys.argv) < 2: print(__doc__); sys.exit(2)
W = os.path.abspath(sys.argv[1]) + "/"
MODEL = sys.argv[sys.argv.index("--model") + 1] if "--model" in sys.argv else "large-v3"
LANG = sys.argv[sys.argv.index("--lang") + 1] if "--lang" in sys.argv else "ar"
BATCHED = "--batched" in sys.argv

src = W + "src.mov"
if not os.path.exists(W + "a.wav"):
    # ⛔⛔ a.wav للتفريغ فقط (16 كيلو أحادي) — ممنوع بالتجميع النهائي (القاعدة ١٩)
    subprocess.run(["ffmpeg", "-v", "error", "-i", src, "-vn", "-ac", "1", "-ar", "16000", "-y", W + "a.wav"], check=True)

APPLE = platform.system() == "Darwin" and platform.machine() == "arm64"
t0 = time.time()
if APPLE:
    try:
        import mlx_whisper
    except ImportError:
        sys.exit("⛔ mlx-whisper غير مثبّت — شغّل scripts/00_setup.sh --install")
    REPO = {"large-v3": "mlx-community/whisper-large-v3-mlx",
            "large-v3-turbo": "mlx-community/whisper-large-v3-turbo",
            "medium": "mlx-community/whisper-medium-mlx"}[MODEL]
    if BATCHED: print("--batched لـfaster-whisper بس: mlx-whisper يفرغ بالطريقة العادية", flush=True)
    r = mlx_whisper.transcribe(W + "a.wav", path_or_hf_repo=REPO, language=LANG, word_timestamps=True)
else:
    # ويندوز بلا Developer Mode: اول تنزيل للنموذج يطبع تحذير symlinks طويل بالانجليزي. huggingface_hub يقرا المتغير وقت الاستيراد
    if os.name == "nt": os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")
    try:
        from faster_whisper import WhisperModel
    except ImportError:
        sys.exit("⛔ faster-whisper غير مثبّت — شغّل scripts/00_setup.sh --install")
    if os.name == "nt":
        # ويندوز: كرت NVIDIA بـfloat16 والا المعالج (_whisper.py)، ووقت متوقع من مدة a.wav، والجهاز ما ينام لين يخلص
        import _whisper, wave, ctypes
        fw, DEV = _whisper.load(MODEL)
        print(f"التفريغ على كرت الشاشة (cuda {fw.model.compute_type})" if DEV == "cuda"
              else f"التفريغ على المعالج (int8، {_whisper.THREADS} خيوط)", flush=True)
        if BATCHED and DEV != "cuda": BATCHED = False; print("--batched على كرت الشاشة بس: التفريغ بالطريقة العادية", flush=True)
        try:   # من مدة المقطع: الكرت ~0.2 منها (5090) و--batched ~0.05، المعالج ~1.0 (قسنا 0.6 على 16 نواة، واللابتوب ابطا)
            with wave.open(W + "a.wav") as wf: est = wf.getnframes() / wf.getframerate() * ((0.05 if BATCHED else 0.2) if DEV == "cuda" else 1.0)
            print(f"⏱ متوقع ~{round(est / 60)} دقيقة" if est >= 60 else "⏱ متوقع اقل من دقيقة", flush=True)
        except Exception: pass
        if DEV == "cpu" and MODEL == "large-v3": print("على المعالج: --model large-v3-turbo اسرع", flush=True)
        ctypes.windll.kernel32.SetThreadExecutionState(0x80000001)   # ES_CONTINUOUS|ES_SYSTEM_REQUIRED: ينتهي مع خروج العملية
    else:
        fw = WhisperModel(MODEL, device="auto", compute_type="auto")
    if BATCHED:
        # دفعات: Silero VAD (جوا faster-whisper، ما ينزل شي) يقسم الكلام عند السكتات لقطع تتفرغ مع بعض بلا سياق اللي
        # قبلها. قسناها على كلام 38 دقيقة (RTX 5090): بقطع 30 ثانية (الافتراضي) طاح كلام، 15٪ مع التوقيتات و5.5٪ بدونها،
        # وبدونها كل قطعة جملة وحدة (كرت كابشن 30 ثانية يغطي اكثر من مقطع بالقص). بقطع 6 ثواني مع التوقيتات ما طاح الا
        # 0.1٪، والجمل قصيرة مثل العادي. الدفعة 8 و16 و24: 105 و109 و122 ثانية، و8 ياخذ من ذاكرة الكرت اقل (~6 قيقا مع النموذج، 16 ياخذ ~9)
        from faster_whisper import BatchedInferencePipeline
        bs = int(os.environ.get("VEB_STT_BATCH", "8"))
        print(f"تفريغ دفعات (batch {bs})", flush=True)
        segs, info = BatchedInferencePipeline(model=fw).transcribe(W + "a.wav", language=LANG, word_timestamps=True, batch_size=bs,
                                                                   beam_size=5, chunk_length=6, without_timestamps=False)
    else:
        segs, info = fw.transcribe(W + "a.wav", language=LANG, word_timestamps=True, vad_filter=False)
    segs = list(segs)
    r = {"text": "".join(s.text for s in segs), "language": info.language,
         "segments": [{"start": s.start, "end": s.end, "text": s.text,
                       "words": [{"word": w.word, "start": w.start, "end": w.end, "probability": w.probability}
                                 for w in (s.words or [])]} for s in segs]}
dt = time.time() - t0
# نفس صيغة وِسبر الأصلية: segments[].words[] بمفاتيح word/start/end
out = {"text": r["text"], "language": r.get("language", "ar"), "model": MODEL,
       "segments": [{"id": i, "start": s["start"], "end": s["end"], "text": s["text"],
                     "words": [{"word": w["word"], "start": w["start"], "end": w["end"], "probability": w.get("probability", 1.0)}
                               for w in s.get("words", [])]} for i, s in enumerate(r["segments"])]}
# إملاء المتحدث (dialect.json بمجلد بياناته): كلمة بكلمة فما تختل التوقيتات — يقلّل التصحيح اليدوي.
# يبدأ فاضي، وكل كلمة تتكرر بتصحيحاتك تنضاف له (مثال: {"هذه": "هذي", "شيء": "شي"}).
DM = _paths.load("dialect.json", {})
DM = {k: v for k, v in DM.items() if not k.startswith("_") and " " not in k}
strip = lambda w: w.strip(" ،.؟!")
for seg in out["segments"]:
    for w in seg["words"]:
        core = strip(w["word"])
        if core in DM: w["word"] = w["word"].replace(core, DM[core])
    seg["text"] = "".join(w["word"] for w in seg["words"]) if seg["words"] else seg["text"]
with open(W + "a.json", "w", encoding="utf-8") as fh: json.dump(out, fh, ensure_ascii=False, indent=1)
nw = sum(len(s["words"]) for s in out["segments"])
print(f"✅ a.json — {MODEL} · {len(out['segments'])} جملة · {nw} كلمة · {dt:.0f} ثانية")
print("الخطوة التالية: صحّح كل جملة بـfixes.json (التفريغ يغلط بالعامية) ثم 02_captions.py")
