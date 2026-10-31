#!/bin/bash
# doctor.sh — تشخيص «B Studio»: يفحص كل شي ويطبع تقريراً واحداً بالعربي.
#   bash doctor.sh     الخروج = عدد المشكلات (0 = كل شي جاهز). التنبيهات (⚠) لا تُحسب مشكلات.
#   bash doctor.sh --deep   ويندوز: ومعه تفريغ تجريبي على كرت الشاشة
. "$(dirname "$0")/_common.sh"
P=0; W=0
# --deep (ويندوز بس): يحمل نموذج التفريغ على الكرت (~4.5 غيغا من ذاكرته، 5-10 ث) ويفرغ ثانية سكوت. مو الافتراضي: ثقيل، وشغل واحد على الكرت بالمرة
DEEP=0; [ "$OS" = win ] && [ "${1:-}" = --deep ] && DEEP=1
ok(){ echo "✓ $1"; }
bad(){ echo "✗ $1"; P=$((P+1)); }
warn(){ echo "⚠ $1"; W=$((W+1)); }

echo "تقرير $STUDIO_NAME ($(date '+%Y-%m-%d %H:%M'))"

# الجهاز
if [ "$OS" = win ]; then ok "الجهاز: ويندوز ($(uname -m))"
elif device_ok; then ok "الجهاز: ماك بمعالج أبل، macOS $(sw_vers -productVersion 2>/dev/null)"
else bad "الجهاز غير مدعوم: $(uname -sm). $MSG_DEVICE"; echo "النتيجة: الاستوديو لا يعمل على هذا الجهاز."; exit 1; fi
win_arm && warn "$MSG_ARM"

# Node
NODE="$(find_node)"
# ويندوز: اداة ناقصة يمكن ركبها 00_setup.sh للتو وPATH هذا قديم: path_again يقرا PATH من الريجستري (مرة وحدة) ونعيد فحصها
[ -z "$NODE" ] && path_again && NODE="$(find_node)"
if [ -z "$NODE" ]; then bad "Node غير موجود (يثبّته تجهيز مهارة المونتاج)"
else NV="$("$NODE" -v 2>/dev/null | tr -d v)"
  if [ "$(node_major "$NODE")" -ge 22 ] 2>/dev/null; then ok "Node $NV"; else bad "Node $NV قديم: يلزم 22 أو أحدث"; fi
fi

# ffmpeg + libx264 + ffprobe
[ "$OS" = win ] && ! { command -v ffmpeg && command -v ffprobe; } >/dev/null 2>&1 && path_again
if command -v ffmpeg >/dev/null 2>&1; then
  FV="$(ffmpeg -hide_banner -version 2>/dev/null | head -1 | awk '{print $3}')"
  if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q libx264; then ok "ffmpeg $FV مع libx264"; else bad "ffmpeg $FV بلا libx264 (التصدير يحتاجه)"; fi
else bad "ffmpeg غير موجود"; fi
command -v ffprobe >/dev/null 2>&1 && ok "ffprobe" || bad "ffprobe غير موجود"

# ويندوز: كرت NVIDIA (الاسم والتعريف وقدرة CUDA)، وهل ffmpeg يرمز عليه. بدون nvidia-smi ما فيه سطر (سطر التفريغ تحت يكفي).
# NVENC معلومة بس: التصدير يرمز على المعالج (libx264). تعريف اقل من 580: كروت 50 تحتاج 570، وادوات CUDA 13 تحتاج 580
if [ "$OS" = win ] && GQ="$(nvidia-smi --query-gpu=name,driver_version,compute_cap --format=csv,noheader 2>/dev/null </dev/null)" && [ -n "$GQ" ]; then
  IFS=, read -r GN GD GC <<< "$(printf '%s\n' "$GQ" | head -1 | tr -d '\r')"
  GD="${GD# }"; GC="${GC# }"
  ok "كرت الشاشة: $GN (تعريف ${GD}، CUDA $GC)"
  [ "${GD%%.*}" -lt 580 ] 2>/dev/null && warn "تعريف NVIDIA $GD قديم: حدثه لـ580 او احدث"
  if command -v ffmpeg >/dev/null 2>&1; then
    if ffmpeg -hide_banner -v error -f lavfi -i color=c=black:s=1280x720:d=0.2 -c:v h264_nvenc -f null - </dev/null >/dev/null 2>&1; then ok "ffmpeg يرمز بكرت الشاشة (NVENC)"
    else warn "ffmpeg ما يرمز بكرت الشاشة (NVENC): التصدير يبقى على المعالج"; fi
  fi
fi

# Python + التفريغ (مهارة المونتاج)
# أداة التفريغ: mlx_whisper على ماك أبل، faster_whisper على ويندوز (نفس اللي يثبّته تجهيز مهارة المونتاج)
STT_MOD=mlx_whisper; [ "$OS" = win ] && STT_MOD=faster_whisper
[ "$OS" = win ] && resolve_pybin   # ويندوز: بايثون venv المونتاج، والا بايثون حقيقي (مو اختصار المتجر)
[ "$OS" = win ] && [ -z "$PYBIN" ] && path_again && resolve_pybin
# مجلد نماذج التفريغ. ويندوز: بايثون ياخذه من HF_HOME، والا من مجلد المستخدم (USERPROFILE، مو HOME حق bash)
HFHUB="$HOME/.cache/huggingface/hub"
[ "$OS" = win ] && HFHUB="$(cygpath -u "${HF_HOME:-${USERPROFILE:-$HOME}/.cache/huggingface}")/hub"
# ويندوز: التفريغ على كرت NVIDIA يحتاج cuBLAS 12 (ctranslate2 ما يجيبه)، وfaster-whisper 1.2 ما يشتغل مع PyAV 15 واحدث.
# بايثون لحاله (لو طاح بسبب DLL ما يطيح التقرير)، ومجلدات nvidia/*/bin قبل البحث مثل التفريغ نفسه (_whisper.py بمهارة المونتاج).
# يطبع: نسخة PyAV، نسخة ctranslate2، عدد كروت CUDA، 1 لو الكرت يدعم float16، 1 لو cuBLAS يشتغل على الكرت، مكان cuBLAS (او -).
# find_library يثبت ان الملف موجود بس: cublasCreate يثبت ان التعريف وcuBLAS يشتغلون فعلا (بالبحث في PATH مثل التفريغ، winmode=0).
# stt_probe deep (--deep): نموذج التفريغ نفسه على الكرت بـfloat16 وثانية سكوت مثل _whisper.load، بلا انترنت (ما ينزل شي)
# ومهلته دقيقتين. يطبع deep-ok والثواني (والخطا لو طاح)
stt_probe(){ ${1:+timeout 120} "$PYBIN" - "$@" <<'PY'
import os, sys, importlib.util
from ctypes.util import find_library
s = importlib.util.find_spec("nvidia")
for root in (s.submodule_search_locations if s else None) or []:
    for n in sorted(os.listdir(root)):
        d = os.path.join(root, n, "bin")
        if os.path.isdir(d):
            os.add_dll_directory(d)
            os.environ["PATH"] = d + os.pathsep + os.environ.get("PATH", "")
if sys.argv[1:] == ["deep"]:
    import time, numpy as np
    os.environ["HF_HUB_OFFLINE"] = "1"
    from faster_whisper import WhisperModel
    t = time.time()
    segs, _ = WhisperModel("large-v3", device="cuda", compute_type="float16").transcribe(np.zeros(16000, np.float32), language="ar")
    list(segs)
    print("deep-ok %.1f" % (time.time() - t))
    sys.exit()
import av, ctranslate2 as c
n = c.get_cuda_device_count()
cub, cok = find_library("cublas64_12"), 0
if cub:
    import ctypes
    try:
        lib, h = ctypes.WinDLL(cub, winmode=0), ctypes.c_void_p()
        if lib.cublasCreate_v2(ctypes.byref(h)) == 0:
            lib.cublasDestroy_v2(h); cok = 1
    except Exception:
        pass
print(av.__version__, c.__version__, n, int(n > 0 and "float16" in c.get_supported_compute_types("cuda")), cok, cub or "-")
PY
}
if command -v "$PYBIN" >/dev/null 2>&1; then
  PV="$("$PYBIN" -c 'import platform;print(platform.python_version())' 2>/dev/null)"
  [ "$OS" = win ] && PV="$PV ($(cygpath -w "$PYBIN"))"   # ويندوز: مسار البايثون في السطر (التفريغ وكاشف الوجه يتفحصون عليه هو)
  # ويندوز على ARM: بايثون ARM64 ما يلقى له pip نسخ كاشف الوجه والتفريغ (يتفحص على ARM بس، فباقي الاجهزة ما يزيد عليها شي)
  if win_arm && [ "$("$PYBIN" -c 'import platform;print(platform.machine())' 2>/dev/null | tr -d '\r')" = ARM64 ]; then
    bad "Python $PV نسخة ARM64: كاشف الوجه والتفريغ ما ينركبون عليه. ركب Python 3.12 نسخة x64 وبعدها شغل تجهيز مهارة المونتاج (00_setup.sh --install)"
  fi
  if "$PYBIN" -c "import $STT_MOD" 2>/dev/null; then
    if [ -d "$HFHUB/models--mlx-community--whisper-large-v3-mlx" ] || [ -d "$HFHUB/models--Systran--faster-whisper-large-v3" ]; then ok "Python $PV مع أداة التفريغ ونموذجها"
    else ok "Python $PV مع أداة التفريغ"; warn "نموذج التفريغ مو منزّل (~3 غيغابايت): ينزل مع setup.sh --install، أو الاستوديو ينزّله بنفسه أول تفريغ"; fi
    if [ "$OS" = win ]; then
      read -r AVV CTV NDEV F16 CUBOK CUB <<< "$(stt_probe 2>/dev/null | tr -d '\r')"
      if [ -z "$NDEV" ]; then warn "تعذر فحص التفريغ على كرت الشاشة"
      else
        [ "${AVV%%.*}" -ge 15 ] 2>/dev/null && bad "PyAV $AVV لا يناسب faster-whisper: شغل تجهيز مهارة المونتاج (00_setup.sh --install)"
        if [ "$NDEV" -gt 0 ] && [ "$F16" = 1 ] && [ "$CUB" != - ] && [ "$CUBOK" = 1 ]; then ok "التفريغ على كرت الشاشة (ctranslate2 ${CTV}، PyAV ${AVV}، cuBLAS موجود)"
        elif [ "$NDEV" -gt 0 ] && [ "$F16" = 1 ] && [ "$CUB" != - ]; then warn "cuBLAS موجود بس ما اشتغل على الكرت: حدث تعريف NVIDIA او شغل تجهيز مهارة المونتاج (00_setup.sh --install)"
        elif [ "$NDEV" -gt 0 ] && [ "$F16" = 1 ]; then warn "كرت NVIDIA بدون cuBLAS 12: التفريغ على المعالج (ابطا). الحل: شغل تجهيز مهارة المونتاج (00_setup.sh --install)"
        else warn "التفريغ على المعالج (ابطا): ما فيه كرت NVIDIA يشتغل معه (ctranslate2 $CTV)"; fi
      fi
      # --deep: تفريغ تجريبي فعلي على الكرت (بايثون لحاله، مهلة دقيقتين). نموذج مو منزل او ما فيه كرت: ملاحظة بس، ما ينزل شي
      if [ "$DEEP" = 1 ]; then
        if [ ! -d "$HFHUB/models--Systran--faster-whisper-large-v3" ]; then echo "– التفريغ التجريبي ما اشتغل: نموذج التفريغ مو منزل (الفحص ما ينزله)"
        elif ! [ "${NDEV:-0}" -gt 0 ] 2>/dev/null; then echo "– التفريغ التجريبي ما اشتغل: ما فيه كرت NVIDIA يشتغل مع التفريغ"
        else
          R="$(stt_probe deep 2>&1)"; RC=$?
          R="$(printf '%s\n' "$R" | tr -d '\r')"; DT="$(printf '%s\n' "$R" | sed -n 's/^deep-ok //p' | tail -1)"
          if [ "$RC" -eq 0 ] && [ -n "$DT" ]; then ok "تفريغ تجريبي على كرت الشاشة: $DT ث"
          elif [ "$RC" -eq 124 ]; then warn "التفريغ التجريبي على كرت الشاشة ما خلص خلال دقيقتين"
          else R="$(printf '%s\n' "$R" | grep . | tail -1)"; warn "التفريغ التجريبي على كرت الشاشة ما اشتغل: ${R:-بلا رسالة}"; fi
        fi
      fi
    fi
  else bad "Python $PV بلا أداة التفريغ (يثبّتها تجهيز مهارة المونتاج)"; fi
  # كاشف الوجه: الماك عنده حقه، وويندوز يستخدم mediapipe (مكان فاضي، الكابشن والوجه، وسّط الوجه)
  if [ "$OS" = win ]; then
    # الكاشف نفسه ينحمل (FaceDetection)، مو بس الاستيراد: من مسار فيه حروف غير انجليزية mediapipe يستورد وما يلقى ملفات الكاشف
    if "$PYBIN" -c "import mediapipe as m, cv2; m.solutions.face_detection.FaceDetection(model_selection=1).close()" 2>/dev/null; then ok "كاشف الوجه (mediapipe)"
    elif "$PYBIN" -c "import mediapipe as m, cv2; m.solutions.face_detection" 2>/dev/null; then
      if printf '%s' "$VEB$PYBIN" | LC_ALL=C grep -q '[^ -~]'; then warn "كاشف الوجه ما يشتغل: بايثون او مجلد البيانات بمسار فيه حروف غير انجليزية، حط VEB_HOME بمسار انجليزي (التنزيل ما يحله)"
      else warn "كاشف الوجه ما ينحمل، فازرار الوجه ما تطلع. الحل: شغل تجهيز مهارة المونتاج (00_setup.sh --install)"; fi
    elif "$PYBIN" -c "import mediapipe" 2>/dev/null; then warn "كاشف الوجه: نسخة mediapipe المثبّتة جديدة وما فيها الكاشف، فأزرار الوجه ما تطلع. الحل: شغل تجهيز مهارة المونتاج (00_setup.sh --install)"
    else warn "كاشف الوجه ناقص: أزرار الوجه ما تطلع بالاستوديو (يثبّته تجهيز مهارة المونتاج)"; fi
  fi
else bad "Python غير موجود"; fi

# Chrome (المعاينة والتصدير)
if [ "$OS" = win ]; then
  # ويندوز: كروم، والا Edge (التصدير ونافذة الاستوديو يشتغلون على الاثنين). السطر فيه مسار المتصفح
  if b="$(app_browser_win)"; then ok "متصفح: $(cygpath -w "$b")"
  else bad "ما فيه Chrome ولا Edge (التصدير يحتاج واحد منهم): نزل Chrome من google.com/chrome"; fi
elif has_chrome; then ok "متصفح Google Chrome"
else bad "متصفح Google Chrome غير موجود (التصدير يحتاجه): نزّله من google.com/chrome"; fi

# مجلد البيانات
if mkdir -p "$DATA" 2>/dev/null && touch "$DATA/.write-test" 2>/dev/null; then rm -f "$DATA/.write-test"; ok "مجلد البيانات قابل للكتابة: $(showpath "$DATA")"
else bad "تعذّرت الكتابة في $(showpath "$DATA")"; fi
FREE_GB="$(df -Pk "$DATA" 2>/dev/null | awk 'NR==2{printf "%d", $4/1048576}')"
if [ "${FREE_GB:-0}" -lt 3 ]; then bad "المساحة المتاحة ${FREE_GB:-0} غيغابايت فقط (يلزم 3 على الأقل، والأفضل 5)"
elif [ "${FREE_GB:-0}" -lt 5 ]; then warn "المساحة المتاحة ${FREE_GB} غيغابايت (الأفضل 5 أو أكثر)"
else ok "المساحة المتاحة ${FREE_GB} غيغابايت"; fi
# ويندوز: «الحماية من برامج الفدية» (Controlled folder access) تمنع البرامج اللي مو موثوقة (مثل ffmpeg من winget) تكتب في
# Documents وسطح المكتب والصور والفيديو والموسيقى، ومجلد البيانات الافتراضي في Documents. وSmart App Control ممكن يمنع ffmpeg
# ومكتبات بايثون. استدعاء PowerShell واحد يطبع «CFA|SAC» (فاضي لو برنامج حماية غير Defender). وOneDrive يزامن مجلد البيانات كله.
# وفحص كتابة حقيقي بـffmpeg نفسه (touch حق bash فوق ما يكفي: الحماية تفرق بين برنامج وبرنامج)
if [ "$OS" = win ]; then
  VW="$(cygpath -w "$VEB")"; vw="$(printf '%s\\' "$VW" | tr 'A-Z' 'a-z')"
  IFS='|' read -r CFA SAC <<< "$(powershell.exe -NoProfile -NonInteractive -Command '"$((Get-MpPreference).EnableControlledFolderAccess)|$((Get-MpComputerStatus).SmartAppControlState)"' </dev/null 2>/dev/null | tr -d '\r')"
  if [ "$CFA" = 1 ]; then case "$vw" in *\\documents\\*|*\\desktop\\*|*\\pictures\\*|*\\videos\\*|*\\music\\*)
    warn "الحماية من برامج الفدية (Controlled folder access) شغالة ومجلد البيانات في مجلد محمي ($VW): ffmpeg وبايثون وNode ممكن ينمنعون من الكتابة فيه. الاسلم VEB_HOME برا المجلدات المحمية (مثل C:/VideoEdit)، او اسمح لـffmpeg.exe وnode.exe وpython.exe من Windows Security > Ransomware protection > Allow an app" ;;
  esac; fi
  [ "$SAC" = On ] && warn "Smart App Control شغال: ممكن يمنع ffmpeg او مكتبات التفريغ وكاشف الوجه. ما له استثناء لبرنامج واحد: لو انمنع شي فالحل اطفاوه (Windows Security > App & browser control)، وهذا قرار المستخدم"
  for d in "$OneDrive" "$OneDriveConsumer" "$OneDriveCommercial"; do
    d="$(printf '%s' "${d%\\}" | tr 'A-Z' 'a-z')"
    [ -n "$d" ] && case "$vw" in "$d"\\*) warn "مجلد البيانات داخل OneDrive ($VW): الفيديوهات والنسخ والادوات (غيغابايتات) بتتزامن للسحابة. حط VEB_HOME برا OneDrive (مثل C:/VideoEdit)"; break ;; esac
  done
  if [ -d "$VEB" ] && command -v ffmpeg >/dev/null 2>&1; then
    if ffmpeg -v error -f lavfi -i anullsrc=r=48000:cl=mono -t 0.1 -y "$VEB/.write-probe.wav" </dev/null >/dev/null 2>&1; then ok "ffmpeg يكتب في مجلد البيانات"
    else bad "ffmpeg ما يقدر يكتب في مجلد البيانات ($VW): غالبا الحماية من برامج الفدية او برنامج حماية ثاني. الحل VEB_HOME برا Documents (مثل C:/VideoEdit)، او اسمح لـffmpeg.exe من Windows Security > Ransomware protection > Allow an app"; fi
    rm -f "$VEB/.write-probe.wav" 2>/dev/null
  fi
fi

# الاستوديو: التثبيت والسلامة
if installed && [ -n "$NODE" ]; then
  VER="$("$NODE" -e 'try{process.stdout.write(require(process.argv[1]).version)}catch{}' "$APP/manifest.json")"
  ok "الاستوديو مثبّت، النسخة $VER"
  LINE="$("$NODE" "$APP/studio/start.mjs" --check 2>/dev/null)"
  if [ $? -eq 0 ]; then ok "$LINE"; else bad "${LINE:-تعذّر فحص سلامة الملفات}"; fi
  if [ -f "$PKG_DIR/manifest.json" ] && [ "$PKG_DIR" != "$APP" ]; then
    PV2="$("$NODE" -e 'try{process.stdout.write(require(process.argv[1]).version)}catch{}' "$PKG_DIR/manifest.json")"
    [ -n "$PV2" ] && [ "$PV2" != "$VER" ] && warn "الحزمة الحالية نسختها $PV2 والمثبّتة $VER: شغّل التحديث"
  fi
  # الصوت
  # تنظيف الضجيج بـDPDFNet (سكربته ونموذجه داخل الحزمة، ومكتبته ببايثون الاستوديو). تثبيت أقدم عنده DeepFilterNet يكمل به
  DN="$APP/studio/voice/denoise.py"; DNM="$APP/studio/voice/dpdfnet"
  DF="$DATA/voice/deep-filter"; [ "$OS" = win ] && DF="$DF.exe"
  if [ -x "$PY" ] && "$PY" "$DN" --version --models "$DNM" 2>/dev/null | grep -q "^dpdfnet" && ! "$PY" "$DN" --version --models "$DNM" 2>/dev/null | grep -q "model missing"; then
    if "$PY" -c "import nara_wpe, soundfile, numpy" 2>/dev/null; then ok "تنظيف الصوت: الخفيف والكامل"
    else warn "تنظيف الصوت: الخفيف فقط (الكامل يحتاج أدوات الصوت: أعد التثبيت)"; fi
  elif [ -e "$DF" ] && "$DF" --version >/dev/null 2>&1; then warn "تنظيف الصوت يعمل بالأداة القديمة: أعد التثبيت لتنزل الجديدة"
  else warn "تنظيف الصوت لا يعمل (أدوات الصوت ناقصة: أعد التثبيت)"; fi
  if [ -x "$PY" ] && "$PY" -c "import cv2, PIL" 2>/dev/null; then ok "أدوات مشاهد الرسم"
  else warn "مشاهد الرسم لا تنتقل للاستوديو (أدواتها ناقصة: أعد التثبيت)"; fi
  # ويندوز: مصنف الاصوات (setup.sh ينزله، ويشتغل على بايثون الاستوديو). الماك يستخدم مصنفه هو
  if [ "$OS" = win ]; then
    YAM="${MOHRER_HOME:-$DATA/home}/models/yamnet"
    if [ -s "$YAM/yamnet.onnx" ] && [ -s "$YAM/yamnet_class_map.csv" ] && [ -x "$PY" ] && "$PY" -c "import onnxruntime" 2>/dev/null; then ok "مصنف الاصوات (YAMNet)"
    else warn "مصنف الاصوات ناقص: التشريح وفحص القصات بدون اسماء الموثرات والموسيقى (setup.sh --install ينزله، ~15 ميقا)"; fi
  fi
  # يعمل؟ المنفذ؟
  URL="$("$NODE" "$APP/studio/start.mjs" --url 2>/dev/null)"
  # ويندوز: المنفذ (STUDIO_PORT او 8795) يتفحص بالحجز نفسه مثل start.mjs، مو بنص netstat (كلمة LISTENING تتغير بلغة ويندوز).
  # يطبع free او رمز الخطا: EADDRINUSE مشغول، EACCES داخل مدى يحجزه ويندوز (Hyper-V او WSL او Docker، وnetstat ما يشوفه)
  SP=8795; PB=""
  if [ "$OS" = win ] && [ -z "$URL" ]; then
    SP="${STUDIO_PORT:-8795}"
    PB="$("$NODE" -e "const s=require('net').createServer();s.once('error',e=>process.stdout.write(e.code||'ERR'));s.listen(+process.argv[1],'127.0.0.1',()=>s.close(()=>process.stdout.write('free')))" "$SP" 2>/dev/null)"
  fi
  if [ -n "$URL" ]; then ok "الاستوديو يعمل الآن: $URL"
  elif [ "$PB" = EACCES ]; then warn "المنفذ $SP محجوز من ويندوز (Hyper-V او WSL او Docker): الاستوديو ياخذ منفذ ثاني لحاله"
  elif { [ "$OS" = win ] && [ "$PB" != free ]; } || { [ "$OS" != win ] && lsof -nP -iTCP:8795 -sTCP:LISTEN >/dev/null 2>&1; }; then warn "الاستوديو لا يعمل الآن، والمنفذ $SP مشغول ببرنامج آخر (سيأخذ منفذاً قريباً)"
  else ok "الاستوديو لا يعمل الآن، والمنفذ $SP متاح"; fi
  if [ "$OS" = win ]; then
    # ويندوز: الاختصار اللي يكتبه make-app.sh (سطح المكتب الحقيقي) لازم يفتح هذي النسخة: اختصار بنفس الاسم من تثبيت ثاني
    #   (مجلد بيانات ثاني) كان ينحسب موجود. وسايطه فيها مجلد البيانات: ...\launch-studio.js او "C:/..." او '/c/...' (نسخ اقدم)
    DLNK="$(desktop_dir)/${STUDIO_APP_NAME:-B Studio}.lnk"
    if [ ! -e "$DLNK" ]; then warn "تطبيق سطح المكتب غير موجود"
    else
      LA="$(LNK="$(cygpath -w "$DLNK")" "${SYSTEMROOT:+$SYSTEMROOT/System32/WindowsPowerShell/v1.0/}powershell.exe" -NoProfile -NonInteractive -Command "[Console]::OutputEncoding=[Text.UTF8Encoding]::new(\$false); try { (New-Object -ComObject Shell.Application).NameSpace([IO.Path]::GetDirectoryName(\$env:LNK)).ParseName([IO.Path]::GetFileName(\$env:LNK)).GetLink.Arguments } catch {}" </dev/null 2>/dev/null | tr -d '\r' | tr '\\A-Z' '/a-z')"
      DM="$(cygpath -m "$DATA" | tr 'A-Z' 'a-z')"; DU="$(cygpath -u "$DATA" | tr 'A-Z' 'a-z')"
      case "$LA" in
        "") ok "تطبيق سطح المكتب موجود" ;;   # ما انقرا: مثل قبل
        *"$DM/launch-studio.js"*) if [ -f "$DATA/launch-studio.js" ]; then ok "تطبيق سطح المكتب موجود"; else warn "تطبيق سطح المكتب ناقص ملفه launch-studio.js: bash make-app.sh يصنعه من جديد"; fi ;;
        *"$DM\""*|*"$DM'"*|*"$DU\""*|*"$DU'"*) ok "تطبيق سطح المكتب موجود" ;;
        *) warn "تطبيق سطح المكتب يفتح استوديو من مجلد ثاني، مو $(cygpath -m "$DATA"): bash make-app.sh يصنعه لهذا" ;;
      esac
    fi
  else
  [ -e "$(desktop_dir)/${STUDIO_APP_NAME:-B Studio}.$DESK_EXT" ] && ok "تطبيق سطح المكتب موجود" || warn "تطبيق سطح المكتب غير موجود"
  fi
elif installed; then
  warn "الاستوديو مثبّت، وفحص ملفاته يحتاج Node أولاً"
else
  bad "$MSG_NOT_INSTALLED"
fi

# مهارة المونتاج
if [ -f "$HOME/.claude/skills/video-edit/SKILL.md" ]; then ok "مهارة المونتاج: ~/.claude/skills/video-edit"
else warn "مهارة المونتاج ليست في ~/.claude/skills (تنركّب من ملف «B Studio»: الخطوة 0ب)"; fi

# العدد بالعربي: nar <العدد> <واحد> <اثنان> <من 3 إلى 10> <11 فأكثر>
nar(){ if [ "$1" -eq 1 ]; then echo "$2"; elif [ "$1" -eq 2 ]; then echo "$3"; elif [ "$1" -le 10 ]; then echo "$1 $4"; else echo "$1 $5"; fi; }
echo "────"
if [ $P -eq 0 ] && [ $W -eq 0 ]; then echo "النتيجة: كل شيء جاهز."
elif [ $P -eq 0 ]; then echo "النتيجة: كل شيء جاهز. التنبيهات (⚠) أعلاه لا تمنع العمل."
else echo "النتيجة: $(nar $P 'مشكلة واحدة' 'مشكلتان' 'مشكلات' 'مشكلة'). إن لم تُحل، أرسل هذا التقرير كما هو لبسام."; fi
exit $P
