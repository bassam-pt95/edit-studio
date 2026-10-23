#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""01b_transcribe.py <work> [--model large-v3|large-v3-turbo|medium] [--lang ar]

التفريغ بتوقيت الكلمة — يكتب <work>/a.json بنفس صيغة وِسبر (segments[].words[].start/end)
فيقرأه 02_captions.py و10_script_edit.py بلا تغيير.

المحرّك حسب الجهاز:
  • ماك بمعالج أبل (M1 وأحدث): mlx-whisper على معالج الرسوميات — أسرع بمرات.
  • ويندوز أو ماك إنتل: faster-whisper (كرت NVIDIA لو موجود، وإلا المعالج).
    بلا كرت NVIDIA على ويندوز/لينكس: الافتراضي large-v3-turbo بـint8 (وlarge-v3 يبقى بـ--model large-v3)، والسكربت يقول الوقت التقريبي ويمنع نوم الجهاز.
النموذج large-v3 هو الأدق للعربي. medium أسرع وأغلاطه أكثر بوضوح (قِسناها: ~20٪ أغلاط زيادة بالعامية).
⛔ البرومت باللهجة (initial_prompt) ما نفع بالتجربة. الحل: large-v3 + dialect.json + تصحيحك بـfixes.json.
⛔ large-v3 «يفصّح» العامية أحياناً («اللي الناس كانوا»→«التي كان الناس»). لو عندك سكربت المتحدث،
   قارن التفريغ به جملة جملة وصحّح لكلامه هو، لا للفصحى.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _paths; _paths.utf8_guard()   # ويندوز بدون UTF-8: يعيد تشغيل السكربت بـ-X utf8 (ماك/لينكس: لا شي)
import json, time, subprocess, platform, wave, atexit

if len(sys.argv) < 2: print(__doc__); sys.exit(2)
W = os.path.abspath(sys.argv[1]) + "/"
MODEL_GIVEN = "--model" in sys.argv
MODEL = sys.argv[sys.argv.index("--model") + 1] if MODEL_GIVEN else "large-v3"
LANG = sys.argv[sys.argv.index("--lang") + 1] if "--lang" in sys.argv else "ar"

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
    r = mlx_whisper.transcribe(W + "a.wav", path_or_hf_repo=REPO, language=LANG, word_timestamps=True)
else:
    if sys.platform == "win32":   # أول تنزيل للنموذج بدون Developer Mode يطبع تحذير symlinks طويل (طبيعي، بس يخوّف)
        os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")
    try:
        from faster_whisper import WhisperModel
    except ImportError:
        sys.exit("⛔ faster-whisper غير مثبّت — شغّل scripts/00_setup.sh --install")
    try:
        import ctranslate2
        CUDA = ctranslate2.get_cuda_device_count()
    except Exception:
        CUDA = 0
    # بلا كرت NVIDIA (ويندوز/لينكس): large-v3 على المعالج أبطأ من مدة المقطع نفسه (قِيس: 41 ث كلام = 68 ث، RTF 1.66 على 16 نواة).
    # الافتراضي هناك large-v3-turbo بـint8 (مفكّك أخف بكثير)، ونقول الوقت الحقيقي بدل «٣ دقايق»، ونمنع النوم. الماك وكرت NVIDIA: بلا تغيير.
    CPU_BOX = CUDA == 0 and platform.system() != "Darwin"
    if CPU_BOX:
        if not MODEL_GIVEN:
            MODEL = "large-v3-turbo"
        try:
            with wave.open(W + "a.wav") as _w: _dur = _w.getnframes() / _w.getframerate()
        except Exception:
            _dur = 0.0
        _rtf = {"large-v3": 1.7, "large-v3-turbo": 0.6, "medium": 0.9}.get(MODEL, 1.0)
        print(f"⚠️ ما فيه كرت NVIDIA — التفريغ على المعالج ({os.cpu_count()} نواة) بنموذج {MODEL} int8."
              + (f" المقطع {_dur/60:.1f} دقيقة، الوقت التقريبي ~{max(1, round(_dur*_rtf/60))} دقيقة" if _dur else "")
              + " (تقدير مقيس على معالج 16 نواة — جهازك يختلف). لا تقفل الجهاز.", flush=True)
        _paths.keep_awake(True)
        atexit.register(_paths.keep_awake, False)
        try:
            fw = WhisperModel(MODEL, device="cpu", compute_type="int8", cpu_threads=os.cpu_count() or 4)
        except Exception as e:
            if MODEL_GIVEN or MODEL != "large-v3-turbo": raise
            print(f"   النموذج turbo ما اشتغل ({e}) — نرجع لـlarge-v3 (أبطأ).", flush=True)
            MODEL = "large-v3"
            fw = WhisperModel(MODEL, device="cpu", compute_type="int8", cpu_threads=os.cpu_count() or 4)
    else:
        fw = WhisperModel(MODEL, device="auto", compute_type="auto")
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
_paths.write_json(W + "a.json", out)
nw = sum(len(s["words"]) for s in out["segments"])
print(f"✅ a.json — {MODEL} · {len(out['segments'])} جملة · {nw} كلمة · {dt:.0f} ثانية")
print("الخطوة التالية: صحّح كل جملة بـfixes.json (التفريغ يغلط بالعامية) ثم 02_captions.py")
