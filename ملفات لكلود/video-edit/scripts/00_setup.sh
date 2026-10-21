#!/bin/bash
# ═══ فحص وتجهيز الأدوات — يكتشف الجهاز ويمشي بالمسار المناسب ═══
#   ./00_setup.sh            → يفحص ويطبع: الجهاز · الجاهز · الناقص وحجمه (بدون ما ينزّل شي)
#   ./00_setup.sh --install  → ينزّل الناقص (بعد موافقة المستخدم فقط)
#
#   ماك بمعالج أبل (M1+) : Homebrew · ffmpeg · Node · Python · mlx-whisper · أدوات Xcode (كاشف الوجه)
#   ماك إنتل            : نفسه، والتفريغ faster-whisper بدل mlx-whisper
#   ويندوز (Git Bash)     : winget · ffmpeg · Node · Python · faster-whisper · mediapipe (كاشف الوجه)
#   ريموشن (محرّك الرسم) نسخة وحدة لكل المقاطع (~400 ميقا مرة وحدة) بـ<VEB_HOME>/remotion-shared عبر 04b_remotion.sh engine.
. "$(cd "$(dirname "$0")" && pwd)/_common.sh"   # PYTHONUTF8 · PATH ويندوز · رفض WSL · دوال ve_*
INSTALL=0; [ "$1" = "--install" ] && INSTALL=1
MISS=(); OK=(); NOTE=(); SIZE=(); WARN=()
have(){ command -v "$1" >/dev/null 2>&1; }
line(){ printf '%s\n' "$1"; }

case "$(uname -s)" in
  Darwin)  OS=mac ;;
  MINGW*|MSYS*|CYGWIN*) OS=win ;;
  *)       OS=linux ;;
esac
ARCH="$(uname -m)"
APPLE=0; [ "$OS" = mac ] && [ "$ARCH" = arm64 ] && APPLE=1

# ويندوز ARM (Snapdragon): Remotion وmediapipe ما عندهم نسخة ARM64 — ننزّل Node وPython بنسخة x64 (تشتغل بالمحاكاة)
WIN_ARM=0
[ "$OS" = win ] && { [ "$PROCESSOR_ARCHITECTURE" = ARM64 ] || [ "$PROCESSOR_ARCHITEW6432" = ARM64 ]; } && WIN_ARM=1

# بايثون: بالويندوز اسمه غالباً python لا python3، ويمكن python3 اختصار متجر مايكروسوفت (ما يشتغل) —
#   نجرّب كل واحد فعلاً ونسوي اختصار python3 عشان أوامر المهارة تشتغل
PY=python3
if [ "$OS" = win ]; then
  ve_pick_python || PY=""
elif ! have python3 && have python; then
  PY=python
fi
win_py_shim(){   # python3 → البايثون الشغّال (لـGit Bash بس: cmd وPowerShell ما يشوفون ~/bin)
  [ "$OS" = win ] && [ -n "$PY" ] && [ "$PY" != python3 ] || return 0
  mkdir -p "$HOME/bin"; printf '#!/bin/bash\nexec %s "$@"\n' "$PY" > "$HOME/bin/python3"; chmod +x "$HOME/bin/python3"; export PATH="$HOME/bin:$PATH"
}
win_py_shim
pymod(){ [ -n "$PY" ] && $PY -c "import $1" 2>/dev/null; }
pymod_ok(){ [ -n "$PY" ] && $PY -c "$1" 2>/dev/null; }

case $OS in
  mac) if [ $APPLE -eq 1 ]; then line "الجهاز: ماك بمعالج أبل (M) — التفريغ على معالج الرسوميات، أسرع شي"
       else line "الجهاز: ماك بمعالج إنتل — التفريغ على المعالج (أبطأ شوي)"; fi ;;
  win) if [ $WIN_ARM -eq 1 ]; then line "الجهاز: ويندوز ARM64 — محرّك الرسم والتفريغ ما يشتغلون إلا بنسخة x64 (محاكاة، أبطأ شوي)"; else line "الجهاز: ويندوز"; fi ;;
  *)   line "الجهاز: لينكس (غير مجرّب — المسار نفس الويندوز تقريباً)" ;;
esac

# ── الأساسيات
have ffmpeg && OK+=("ffmpeg") || { MISS+=("ffmpeg"); SIZE+=("أداة القص والصوت ~80 ميقا"); }
have node   && OK+=("node")   || { MISS+=("node");   SIZE+=("Node (يشغّل محرّك الرسم) ~70 ميقا"); }
[ -n "$PY" ] && have ${PY%% *} && OK+=("python") || { MISS+=("python"); SIZE+=("Python ~50 ميقا"); }
pymod numpy && OK+=("numpy")  || { MISS+=("numpy");  SIZE+=("numpy ~20 ميقا"); }
# ── التفريغ
if [ $APPLE -eq 1 ]; then
  pymod mlx_whisper && OK+=("التفريغ") || { MISS+=("mlx-whisper"); SIZE+=("أداة التفريغ ~50 ميقا + نموذجها أول تشغيل ~3 قيقا"); }
else
  pymod faster_whisper && OK+=("التفريغ") || { MISS+=("faster-whisper"); SIZE+=("أداة التفريغ ~100 ميقا + نموذجها أول تشغيل ~3 قيقا"); }
fi
# ── كاشف الوجه وقصّ الشخص
if [ "$OS" = mac ]; then
  have swiftc && OK+=("كاشف الوجه") || { MISS+=("xcode"); SIZE+=("أدوات Xcode (كاشف الوجه، مجانية من أبل) ~1 قيقا"); }
else
  # mediapipe 0.10.30 وما بعده شال الكاشف اللي نستخدمه (mp.solutions): لازم نسخة قبله (0.10.21، على Python 3.12)، والفحص يتأكد إن الكاشف نفسه موجود
  #   الاستيراد وحده ما يكفي: الكاشف لازم ينبني فعلاً (بمسار بايثون فيه حروف عربية يطيّح بعدين)
  if ! pymod_ok "import mediapipe as m, cv2; m.solutions.face_detection"; then MISS+=("mediapipe"); SIZE+=("كاشف الوجه mediapipe ~150 ميقا")
  elif pymod_ok "import mediapipe as m; m.solutions.face_detection.FaceDetection(model_selection=1).close()"; then OK+=("كاشف الوجه")
  else WARN+=("كاشف الوجه mediapipe منزّل لكن ما ينبني — غالباً مسار بايثون فيه حروف غير إنجليزية؛ ثبّت بايثون بمسار إنجليزي (مثل C:\\Python312)"); fi
fi
if [ "$OS" = win ]; then
  # قص الخلفية للصور (أسلوب الكولاج والصور المولّدة): بالماك Vision، وبالويندوز مكتبة rembg
  pymod rembg && OK+=("قص الخلفية") || { MISS+=("rembg"); SIZE+=("قص الخلفية rembg ~200 ميقا + نموذجها أول تشغيل ~170 ميقا"); }
fi

# ── تحذيرات الجهاز (ويندوز/لينكس): كرت الشاشة والحماية والمعمارية. على الماك ما فيه شي منها.
if [ "$OS" != mac ]; then
  if have nvidia-smi && nvidia-smi -L 2>/dev/null | grep -qi gpu; then
    # كرت NVIDIA موجود: التفريغ يحتاج مكتبات CUDA (cublas) تنحمّل فعلاً، وإلا أول تفريغ يموت بنص الشغل
    if pymod faster_whisper && ! pymod_ok "
import ctypes, importlib.util, os, sys
try:
    ctypes.WinDLL('cublas64_12.dll'); sys.exit(0)
except Exception:
    pass
try:
    sp = importlib.util.find_spec('nvidia.cublas')
    d = list(sp.submodule_search_locations)[0] if sp and sp.submodule_search_locations else ''
except Exception:
    d = ''
sys.exit(0 if d and os.path.exists(os.path.join(d, 'bin', 'cublas64_12.dll')) else 1)"; then
      WARN+=("كرت NVIDIA موجود لكن مكتبات CUDA للتفريغ ناقصة (cublas64_12.dll) — التفريغ يرجع للمعالج أو يفشل. للتسريع: pip install nvidia-cublas-cu12 nvidia-cudnn-cu12 (حجمها كبير ~1 قيقا)")
    fi
  else
    WARN+=("ما لقيت كرت NVIDIA (nvidia-smi) — التفريغ يشتغل على المعالج وهو أبطأ بكثير (مقطع 10 دقايق ياخذ تقريباً ضعف مدته أو أكثر). لا تخلّي الجهاز ينام أثناء التفريغ")
  fi
fi
if [ "$OS" = win ]; then
  # الحماية من الفدية (Controlled Folder Access) تمنع ffmpeg وpython وnode من الكتابة بمجلد المستندات: يطلع Permission denied
  if [ "$(powershell.exe -NoProfile -Command "(Get-MpPreference).EnableControlledFolderAccess" 2>/dev/null | tr -d '\r\n ')" = 1 ]; then
    WARN+=("الحماية من برامج الفدية (Controlled Folder Access) شغّالة — ممكن تمنع ffmpeg وpython وnode من الكتابة بمجلد المستندات (يطلع Permission denied). افتح «Windows Security › Virus & threat protection › Ransomware protection › Allow an app through Controlled folder access» وأضفها، أو اضبط VEB_HOME على مجلد غير محمي مثل C:\\VideoEdit")
  fi
  if [ $WIN_ARM -eq 1 ]; then
    [ "$(node -p 'process.arch' 2>/dev/null | tr -d '\r')" = arm64 ] && WARN+=("Node عندك نسخة ARM64 — Remotion ما يدعمها؛ ثبّت نسخة x64")
    [ -n "$PY" ] && [ "$($PY -c 'import platform;print(platform.machine())' 2>/dev/null | tr -d '\r' | tr 'A-Z' 'a-z')" = arm64 ] && WARN+=("Python عندك نسخة ARM64 — mediapipe ما عنده نسخة لها؛ ثبّت Python x64")
  fi
fi

line "الجاهز: ${OK[*]:-لا شيء}"
[ ${#WARN[@]} -gt 0 ] && printf '⚠️  %s\n' "${WARN[@]}"
if [ ${#MISS[@]} -eq 0 ]; then
  if [ ${#WARN[@]} -eq 0 ]; then line "✅ كل شي جاهز — نقدر نبدأ."; else line "ما فيه شي ناقص للتنزيل — راجع التحذيرات فوق."; fi
  exit 0
fi
line "الناقص:"
for s in "${SIZE[@]}"; do line "  • $s"; done
line "(ومحرّك الرسم ريموشن ينزل مرة وحدة لكل المقاطع ~400 ميقا، بموافقتك أول مشروع)"

if [ $INSTALL -eq 0 ]; then line "للتنزيل: $0 --install"; exit 10; fi

pipi(){ [ -n "$PY" ] || return 1; $PY -m pip install --quiet --user "$@" 2>/dev/null || $PY -m pip install --quiet --break-system-packages "$@" 2>/dev/null || $PY -m pip install --quiet "$@"; }
winget_i(){ winget install --silent --accept-package-agreements --accept-source-agreements -e --id "$1" "${@:2}"; }
X64=(); [ $WIN_ARM -eq 1 ] && X64=(--architecture x64)
WINGET_RAN=0

for m in "${MISS[@]}"; do
  case "$m" in
    ffmpeg|node|python)
      if [ "$OS" = mac ]; then
        if ! have brew; then NOTE+=("لازم Homebrew أول — المستخدم يلصق هذا بالتيرمنال: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""); continue; fi
        case $m in ffmpeg) line "⏬ ffmpeg…"; brew install ffmpeg ;; node) line "⏬ Node…"; brew install node ;; python) line "⏬ Python…"; brew install python ;; esac || NOTE+=("$m فشل")
      elif [ "$OS" = win ]; then
        if ! have winget; then NOTE+=("winget مو موجود — حدّث «App Installer» من متجر مايكروسوفت"); continue; fi
        line "ℹ️  ممكن تطلع نافذة صلاحيات ويندوز (UAC) تسأل «هل تسمح لهذا التطبيق بإجراء تغييرات؟» — اضغط «نعم» (لو ما ظهرت شوف شريط المهام تحت)"
        case $m in ffmpeg) line "⏬ ffmpeg…"; winget_i Gyan.FFmpeg ;; node) line "⏬ Node…"; winget_i OpenJS.NodeJS.LTS "${X64[@]}" ;; python) line "⏬ Python…"; winget_i Python.Python.3.12 "${X64[@]}" ;; esac || NOTE+=("$m فشل")
        WINGET_RAN=1
        # winget يكتب المسار الجديد بالسجل بس؛ نقرأه من هناك عشان نكمّل بدون ما يسكّر المستخدم كلود
        ve_refresh_win_path
        if [ "$m" = python ]; then ve_pick_python || PY=""; win_py_shim; fi
      else NOTE+=("نزّل $m بمدير الحزم (apt/dnf)"); fi ;;
    numpy)          line "⏬ numpy…"; pipi numpy || NOTE+=("numpy فشل") ;;
    mlx-whisper)    line "⏬ mlx-whisper…"; pipi mlx-whisper || NOTE+=("mlx-whisper فشل") ;;
    faster-whisper) line "⏬ faster-whisper…"; pipi faster-whisper || NOTE+=("faster-whisper فشل") ;;
    mediapipe)      line "⏬ mediapipe…"; pipi "mediapipe<0.10.30" opencv-python || NOTE+=("mediapipe فشل") ;;
    rembg)          line "⏬ rembg…"; pipi "rembg[cpu]" pillow || NOTE+=("rembg فشل") ;;
    xcode)          xcode-select --install 2>/dev/null
                    NOTE+=("طلعت نافذة من أبل لأدوات Xcode — اضغط «Install» وانتظرها تخلص (~10 دقايق)، وبعدها كمّل") ;;
  esac
done

# ويندوز: لو الأداة اننزلت وما زالت ما تبان بالمسار، إعادة الفحص بنفس الـbash تعطي نفس الناقص — نوقف برسالة واضحة
if [ "$WINGET_RAN" = 1 ]; then
  for m in "${MISS[@]}"; do
    case "$m" in
      ffmpeg) have ffmpeg && continue ;;
      node)   have node && continue ;;
      python) [ -n "$PY" ] && continue ;;
      *) continue ;;
    esac
    NOTE+=("بعد تنزيل $m بالويندوز ما ظهر بالمسار: سكّر تطبيق كلود وافتحه من جديد (عشان يقرأ المسار الجديد)، وبعدها شغّل: bash scripts/00_setup.sh")
    STOP=11
  done
fi
[ ${#NOTE[@]} -gt 0 ] && printf '⚠️  %s\n' "${NOTE[@]}"
[ -n "$STOP" ] && exit "$STOP"
exec "$0"    # يفحص من جديد ويطبع النتيجة النهائية
