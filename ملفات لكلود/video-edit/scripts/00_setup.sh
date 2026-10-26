#!/bin/bash
# ═══ فحص وتجهيز الأدوات — يكتشف الجهاز ويمشي بالمسار المناسب ═══
#   ./00_setup.sh            → يفحص ويطبع: الجهاز · الجاهز · الناقص وحجمه (بدون ما ينزّل شي)
#   ./00_setup.sh --install  → ينزّل الناقص (بعد موافقة المستخدم فقط)
#   ./00_setup.sh --install --cutout → ويندوز: ومعه قص الشخص بكرت الشاشة (اختياري، بعد موافقة المستخدم)
#   ./00_setup.sh --light    → ويندوز: اداة الرسم للمحرك الخفيف (اختياري، بعد موافقة المستخدم)
#   ./00_setup.sh --subjectcut → ويندوز: نموذج قص الصور لـsubjectcut.py ~180 ميقا (اختياري، بعد موافقة المستخدم)
#
#   ماك بمعالج أبل (M1+) : Homebrew · ffmpeg · Node · Python · mlx-whisper · أدوات Xcode (كاشف الوجه)
#   ماك إنتل            : نفسه، والتفريغ faster-whisper بدل mlx-whisper
#   ويندوز (Git Bash)     : winget · ffmpeg · Node · Python · faster-whisper · mediapipe (كاشف الوجه)
#                           بايثون 3.12، وادوات بايثون في venv واحد: <VEB_HOME>/tools/py
#   ريموشن (محرّك الرسم) نسخة وحدة لكل المقاطع (~400 ميقا مرة وحدة) بـ<VEB_HOME>/remotion-shared عبر 04b_remotion.sh engine.
case "$OSTYPE" in msys*|cygwin*) [ "$(command -v find)" = /usr/bin/find ] || export PATH="$HOME/bin:/mingw64/bin:/usr/bin:$PATH";; esac   # ويندوز: bash بلا login يبدا PATH بـSystem32: find حق ويندوز (ولو ادوات Git بالـPATH تجي بعدها)، وما فيه ~/bin حق python3؛ فلو find مو /usr/bin/find نحط ~/bin وادوات Git اول مثل login
INSTALL=0; [ "$1" = "--install" ] && INSTALL=1
MISS=(); OK=(); NOTE=(); SIZE=()
have(){ command -v "$1" >/dev/null 2>&1; }
line(){ printf '%s\n' "$1"; }

case "$(uname -s)" in
  Darwin)  OS=mac ;;
  MINGW*|MSYS*|CYGWIN*) OS=win ;;
  *)       # WSL (لينكس داخل ويندوز): مسارات C:/ ما تنفهم فيه، وبايثون المونتاج وادوات ويندوز مو فيه، فالمهارة تشتغل من Git Bash بس
           if grep -qi microsoft /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; then
             line "⛔ هذا WSL (لينكس داخل ويندوز) مو Git Bash: شغل المهارة من Git Bash على ويندوز نفسه"; exit 20; fi
           OS=linux ;;
esac
[ "$OS" = win ] && export PYTHONUTF8=1 PYTHONIOENCODING=utf-8   # ويندوز: بايثون بـUTF-8 لا بترميز النظام
ARCH="$(uname -m)"
APPLE=0; [ "$OS" = mac ] && [ "$ARCH" = arm64 ] && APPLE=1

# بايثون: بالويندوز اسمه غالباً python لا python3 — نسوي له اختصاراً عشان كل الأدوات تشتغل
if [ "$OS" = win ]; then
  # PATH اللي تشوفه اوامر كلود (قبل اي تعديل هنا). الفحص بعد --install يستلمه من الفحص الاول، عشان يعرف لو اداة نزلت وكلود ما يشوفها
  ORIG_PATH="${VEB_ORIG_PATH:-$PATH}"; WG=()
  # جهاز ARM (مثل Snapdragon X): متغيرات المعالج تتبع المحاكاة، فالمعالج الحقيقي من الريجستري (بلا تحويل /v لمسار، مثل /J).
  # ريموشن ما له نسخة ويندوز ARM، ولا ctranslate2 وmediapipe: Node وبايثون نسخة x64 تشتغل بالمحاكاة
  NAT="$(MSYS2_ARG_CONV_EXCL='*' reg query 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' /v PROCESSOR_ARCHITECTURE 2>/dev/null | tr -d '\r' | awk '/PROCESSOR_ARCHITECTURE/{print $NF}')"
  X64=(); [ "$NAT" = ARM64 ] && X64=(--architecture x64)
  # ويندوز: python وpython3 في WindowsApps اختصارات المتجر (تطبع «Python was not found»)، وmediapipe 0.10.21 ما له نسخة بعد بايثون 3.12.
  # base_py يطبع اول بايثون 3.12 حقيقي: py -3.12، ثم كل python/python3 في PATH، ثم مكان winget (يلقاه بعد التنزيل بدون اعادة تشغيل)
  base_py(){ local c lc
    { py -3.12 -c 'import sys;print(sys.executable)' </dev/null 2>/dev/null | tr -d '\r'; type -aP python python3
      [ -n "$LOCALAPPDATA" ] && printf '%s\n' "$(cygpath -u "$LOCALAPPDATA")/Programs/Python/Python312/python.exe"; } |
    while IFS= read -r c; do
      c="$(cygpath -u "$c")"; lc="$(printf '%s' "$c" | tr 'A-Z' 'a-z')"
      case "$lc" in */windowsapps/*) continue ;; /*) ;; *) continue ;; esac
      "$c" -c 'import sys;assert sys.version_info[:2]==(3,12)' </dev/null >/dev/null 2>&1 && { printf '%s\n' "$c"; break; }
    done; }
  # winget يكتب PATH بالريجستري بس، والـbash الشغال يكمل بالقديم. refresh_path يقرا Path حق الجهاز والمستخدم (UTF-8 عشان اسم مستخدم عربي)
  # ويضيف اللي مو فيه بالاخر (find وsort حق Git يبقون قبل System32)، مع WinGet\Links، وبلا WindowsApps (اختصار بايثون حق المتجر).
  # PowerShell بمساره من SYSTEMROOT، لو PATH ناقص حتى System32
  refresh_path(){ local p d m; m="$(shopt -p nocasematch)"; shopt -s nocasematch
    p="$("${SYSTEMROOT:+$SYSTEMROOT/System32/WindowsPowerShell/v1.0/}powershell.exe" -NoProfile -NonInteractive -Command "[Console]::OutputEncoding=[Text.UTF8Encoding]::new(\$false); [Environment]::GetEnvironmentVariable('Path','Machine')+';'+[Environment]::GetEnvironmentVariable('Path','User')" </dev/null 2>/dev/null | tr -d '\r')"
    [ -n "$LOCALAPPDATA" ] && p="$p;$LOCALAPPDATA\\Microsoft\\WinGet\\Links"
    while IFS= read -r d; do d="${d%/}"
      case "$d" in ""|*/windowsapps) continue ;; esac
      case ":$PATH:" in *":$d:"*) ;; *) PATH="$PATH:$d" ;; esac
    done < <(cygpath -u -p "$p" 2>/dev/null | tr ':' '\n')
    eval "$m"; export PATH; hash -r; }
  BASEPY="$(base_py)"
  # ادوات المونتاج (numpy والتفريغ وكاشف الوجه) في venv واحد تحت مجلد البيانات، ابد مو pip --user:
  # تطبيق كلود يحول كتابته في AppData لمجلد خاص فيه، فالاستوديو ما يشوفها. PY = بايثون الـvenv لو يشتغل
  # البيت الافتراضي من USERPROFILE مثل بايثون وnode (متغير HOME عام ما يقسم البيانات لمجلدين)، واختصار ~/bin يبقى تحت HOME
  H="$HOME"; [ -n "$USERPROFILE" ] && H="$(cygpath -u "$USERPROFILE")"
  # بلا VEB_HOME: نفس قاعدة الاستوديو (platform.mjs dataHomeDefault و_common.sh و_paths.py/_paths.js)، بلا بايثون لان الفحص يمكن قبل ما ينزل:
  #   C:/EditStudio لو <البيت>/Documents/video-edit فيه حروف غير انجليزية او onedrive او /appdata/، او OneDrive ماخذ المستندات
  veb_default(){ local d="$H/Documents/video-edit" od
    if printf '%s' "$d" | LC_ALL=C grep -q '[^ -~]' || printf '%s' "$d" | grep -qiE 'onedrive|/appdata/'; then printf 'C:/EditStudio'; return; fi
    for od in "$OneDrive" "$OneDriveConsumer" "$OneDriveCommercial"; do [ -n "$od" ] && [ -d "$(cygpath -u "$od")/Documents" ] && { printf 'C:/EditStudio'; return; }; done
    printf '%s' "$d"; }
  # مسار C:/ عشان python -m venv ما يسوي C:\c\... لو MSYS_NO_PATHCONV=1 او MSYS2_ARG_CONV_EXCL='*' (يوقفون تحويل /c/...)
  VEB="$(cygpath -m "${VEB_HOME:-$(veb_default)}")"; VENV="$VEB/tools/py"; VPY="$VENV/Scripts/python.exe"
  PY=""; "$VPY" -c 'import sys' >/dev/null 2>&1 && PY="$VPY"
  # python3 بخطوات المهارة = بايثون الـvenv بـUTF-8 (ينكتب من جديد كل فحص)، ابد مو بايثون الجهاز
  if [ -n "$PY" ]; then
    mkdir -p "$HOME/bin"; printf '#!/bin/bash\nexport PYTHONUTF8=1\nexec "%s" "$@"\n' "$(cygpath -u "$VPY")" > "$HOME/bin/python3"
    chmod +x "$HOME/bin/python3"; export PATH="$HOME/bin:$PATH"
  fi
  # --light: اداة الرسم للمحرك الخفيف (puppeteer-core، اختيارية) بنفس سطر _paths.js، بمجلد البيانات مو بمجلد المهارة
  if [ "$1" = "--light" ]; then
    refresh_path   # Node يمكن نزل للتو
    have npm || { line "⛔ Node ناقص: شغل bash $0 اول"; exit 10; }
    line "⏬ اداة الرسم للمحرك الخفيف…"
    OUT="$(npm i --no-audit --no-fund --prefix "$VEB/tools" puppeteer-core 2>&1)"
    if node -e "require.resolve('puppeteer-core',{paths:[process.argv[1]]})" "$VEB/tools" >/dev/null 2>&1; then line "✅ المحرك الخفيف جاهز"; exit 0; fi
    line "⛔ اداة الرسم ما نزلت: $(printf '%s\n' "$OUT" | grep -v -e '^[[:space:]]*$' -e 'complete log' | tail -1)"; exit 1
  fi
  # اختياري: نموذج قص الصور (ISNet) لـsubjectcut.py، للكولاج والصور المولدة بخلفية مو سادة. نسخة rembg مثبتة ببصمتها (sha256)،
  # وينحفظ بعد ما تطابق بس، فوجود الملف يكفي للفحص. بدونه subjectcut.py يقص الخلفية السادة الفاتحة بس
  ISNET="$VEB/tools/models/isnet-general-use.onnx"
  if [ "$1" = --subjectcut ]; then
    [ -s "$ISNET" ] && { line "✅ نموذج قص الصور موجود"; exit 0; }
    line "⏬ نموذج قص الصور (ISNet ~180 ميقا)…"; mkdir -p "$VEB/tools/models"
    if curl -fsSL --ssl-revoke-best-effort --retry 2 -o "$ISNET.part" https://github.com/danielgatis/rembg/releases/download/v0.0.0/isnet-general-use.onnx &&
       [ "$(sha256sum "$ISNET.part" | cut -d' ' -f1)" = 60920e99c45464f2ba57bee2ad08c919a52bbf852739e96947fbb4358c0d964a ]; then
      mv -f "$ISNET.part" "$ISNET"; line "✅ نموذج قص الصور جاهز"; exit 0
    fi
    rm -f "$ISNET.part"; line "⛔ نموذج قص الصور ما نزل او بصمته (sha256) مو نفس المثبتة، فما انحفظ"; exit 1
  fi
else
PY=python3
if ! have python3 && have python; then
  PY=python
  if [ "$OS" = win ]; then mkdir -p "$HOME/bin"; printf '#!/bin/bash\nexec python "$@"\n' > "$HOME/bin/python3"; chmod +x "$HOME/bin/python3"; export PATH="$HOME/bin:$PATH"; fi
fi
fi
pymod(){ "$PY" -c "import $1" 2>/dev/null; }

case $OS in
  mac) if [ $APPLE -eq 1 ]; then line "الجهاز: ماك بمعالج أبل (M) — التفريغ على معالج الرسوميات، أسرع شي"
       else line "الجهاز: ماك بمعالج إنتل — التفريغ على المعالج (أبطأ شوي)"; fi ;;
  win) line "الجهاز: ويندوز"
       nvidia-smi -L >/dev/null 2>&1 || line "ما فيه كرت NVIDIA: التفريغ على المعالج (ابطا)"
       [ "$NAT" = ARM64 ] && line "جهازك ARM: Node وبايثون نسخة x64 (تشتغل بالمحاكاة، ابطا وما جربناها)" ;;
  *)   line "الجهاز: لينكس (غير مجرّب — المسار نفس الويندوز تقريباً)" ;;
esac

# ── الأساسيات
# ويندوز: 03_cut_zoom يمرر فلاتر المقطع الطويل بملف (-/filter_complex) وهذا يبي ffmpeg 7 او احدث، فالاقدم ناقص و--install يرقيه.
# نسخة رقمها ما ينقرا (nightly) تمشي
FFMAJ=""; [ "$OS" = win ] && have ffmpeg && FFMAJ="$(ffmpeg -hide_banner -version 2>/dev/null | head -1 | sed -n 's/^ffmpeg version n\{0,1\}\([0-9]*\)\..*/\1/p')"
if [ -n "$FFMAJ" ] && [ "$FFMAJ" -lt 7 ]; then MISS+=("ffmpeg-old"); SIZE+=("ffmpeg جديد (يلزم 7 او احدث، الموجود نسخة $FFMAJ في $(command -v ffmpeg)) ~80 ميقا")
else
have ffmpeg && OK+=("ffmpeg") || { MISS+=("ffmpeg"); SIZE+=("أداة القص والصوت ~80 ميقا"); }
fi
have node   && OK+=("node")   || { MISS+=("node");   SIZE+=("Node (يشغّل محرّك الرسم) ~70 ميقا"); }
if [ "$OS" = win ]; then
  # جهاز ARM: Node نسخة ARM ما يشغل ريموشن (ما له نسخة win32-arm64)
  [ "$NAT" = ARM64 ] && have node && [ "$(node -p process.arch </dev/null 2>/dev/null | tr -d '\r')" != x64 ] && { MISS+=("node-x64"); SIZE+=("Node نسخة x64 (اللي عندك نسخة ARM ومحرك الرسم ما يشتغل عليها) ~70 ميقا"); }
  # متصفح للاستوديو والمحرك الخفيف: كروم، او Edge اللي يجي مع ويندوز، او CHROME_PATH/CHROME. كروم من winget بس لو ما فيه ولا واحد
  PF86="$(printenv 'ProgramFiles(x86)')"
  if [ -f "$PROGRAMFILES/Google/Chrome/Application/chrome.exe" ] || [ -f "$PF86/Google/Chrome/Application/chrome.exe" ] || [ -f "$LOCALAPPDATA/Google/Chrome/Application/chrome.exe" ]; then OK+=("كروم")
  elif [ -f "$PF86/Microsoft/Edge/Application/msedge.exe" ] || [ -f "$PROGRAMFILES/Microsoft/Edge/Application/msedge.exe" ]; then OK+=("متصفح Edge")
  elif [ -n "${CHROME_PATH:-$CHROME}" ] && [ -f "${CHROME_PATH:-$CHROME}" ]; then OK+=("متصفح")
  else MISS+=("chrome"); SIZE+=("متصفح كروم (الاستوديو والمحرك الخفيف) ~120 ميقا"); fi
fi
if [ "$OS" = win ]; then   # ويندوز: numpy والتفريغ وكاشف الوجه من venv ادوات المونتاج، فحجمها سطر واحد
  [ -n "$BASEPY$PY" ] && OK+=("python") || { MISS+=("python"); SIZE+=("Python 3.12 ~50 ميقا"); }   # 3.13 واحدث ما تكفي
  # جهاز ARM: venv من بايثون ARM يفشل فيه pip (ctranslate2 وmediapipe ما لهم نسخة win_arm64)، وكل --install بعدها يرجع له. الفحص على بايثون الـvenv لو موجود
  [ "$NAT" = ARM64 ] && [ -n "$BASEPY$PY" ] && [ "$("${PY:-$BASEPY}" -c 'import sysconfig;print(sysconfig.get_platform())' </dev/null 2>/dev/null | tr -d '\r')" != win-amd64 ] && { MISS+=("python-x64"); SIZE+=("Python 3.12 نسخة x64 (اللي عندك نسخة ARM وادوات التفريغ وكاشف الوجه ما تشتغل عليها) ~50 ميقا"); }
  pymod numpy          && OK+=("numpy")   || MISS+=("numpy")
  # faster-whisper 1.2 يطيح مع PyAV 15 واحدث (metadata_errors)، فالفحص يرفضها و--install يرجع av<15
  if "$PY" -c 'import faster_whisper, av, sys; sys.exit(int(av.__version__.split(".")[0]) >= 15)' 2>/dev/null; then OK+=("التفريغ")
    # كرت NVIDIA: ctranslate2 ما يجيب cuBLAS، وبدونه التفريغ يرجع للمعالج. الفحص يحمل الـDLL فعلا من مجلدات nvidia في الـvenv (نفس _whisper.py)
    # او من PATH (مثل CUDA Toolkit): winmode=0 يدور مثل ctranslate2، والافتراضي يتجاهل PATH
    if nvidia-smi -L >/dev/null 2>&1 && ! "$PY" -c 'import sys,ctypes;sys.path.insert(0,sys.argv[1]);import _whisper;_whisper._nvidia_dlls();ctypes.WinDLL("cublas64_12.dll", winmode=0)' "$(cygpath -m "$(cd "$(dirname "$0")" && pwd)")" 2>/dev/null; then
      MISS+=("cuda-libs"); SIZE+=("مكتبات كرت NVIDIA للتفريغ ~600 ميقا")
    fi
  else MISS+=("faster-whisper"); fi
  # الكاشف نفسه ينحمل (FaceDetection)، مو بس الاستيراد: mediapipe بمسار فيه حروف غير انجليزية يستورد وما يلقى ملفات الكاشف، وهذا ما يحله التنزيل
  if "$PY" -c 'import mediapipe as m, cv2; m.solutions.face_detection.FaceDetection(model_selection=1).close()' 2>/dev/null; then OK+=("كاشف الوجه")
  elif pymod mediapipe; then MISS+=("face-path"); SIZE+=("كاشف الوجه ما يشتغل: بايثون او مجلد البيانات بمسار فيه حروف غير انجليزية، حط VEB_HOME بمسار انجليزي (التنزيل ما يحله)")
  else MISS+=("mediapipe"); fi
  case " ${MISS[*]} " in *" numpy "*|*" faster-whisper "*|*" mediapipe "*)
    SIZE+=("ادوات بايثون للمونتاج (التفريغ وكاشف الوجه) ~300 ميقا + نموذج التفريغ اول تشغيل ~3 قيقا")
    nvidia-smi -L >/dev/null 2>&1 && SIZE+=("مكتبات كرت NVIDIA للتفريغ ~600 ميقا") ;;
  esac
  # «الحماية من برامج الفدية» (Controlled folder access) وSmart App Control وOneDrive، مثل doctor.sh حق الاستوديو: تنبيه
  # يطلع حتى لو كل شي جاهز. وفحص كتابة حقيقي بـffmpeg نفسه في مجلد البيانات: لو فشل ناقص، والتنزيل ما يحله
  VW="$(cygpath -w "$VEB")"; vw="$(printf '%s\\' "$VW" | tr 'A-Z' 'a-z')"
  IFS='|' read -r CFA SAC <<< "$(powershell.exe -NoProfile -NonInteractive -Command '"$((Get-MpPreference).EnableControlledFolderAccess)|$((Get-MpComputerStatus).SmartAppControlState)"' </dev/null 2>/dev/null | tr -d '\r')"
  if [ "$CFA" = 1 ]; then case "$vw" in *\\documents\\*|*\\desktop\\*|*\\pictures\\*|*\\videos\\*|*\\music\\*)
    line "⚠️  الحماية من برامج الفدية (Controlled folder access) شغالة ومجلد البيانات في مجلد محمي ($VW): ffmpeg وبايثون وNode ممكن ينمنعون من الكتابة فيه. الاسلم VEB_HOME برا المجلدات المحمية (مثل C:/VideoEdit)، او اسمح لـffmpeg.exe وnode.exe وpython.exe من Windows Security > Ransomware protection > Allow an app" ;;
  esac; fi
  [ "$SAC" = On ] && line "⚠️  Smart App Control شغال: ممكن يمنع ffmpeg او مكتبات التفريغ وكاشف الوجه. ما له استثناء لبرنامج واحد: لو انمنع شي فالحل اطفاوه (Windows Security > App & browser control)، وهذا قرار المستخدم"
  for d in "$OneDrive" "$OneDriveConsumer" "$OneDriveCommercial"; do
    d="$(printf '%s' "${d%\\}" | tr 'A-Z' 'a-z')"
    [ -n "$d" ] && case "$vw" in "$d"\\*) line "⚠️  مجلد البيانات داخل OneDrive ($VW): الفيديوهات والنسخ والادوات (غيغابايتات) بتتزامن للسحابة. حط VEB_HOME برا OneDrive (مثل C:/VideoEdit)"; break ;; esac
  done
  if have ffmpeg; then
    mkdir -p "$VEB" 2>/dev/null
    ffmpeg -v error -f lavfi -i anullsrc=r=48000:cl=mono -t 0.1 -y "$VEB/.write-probe.wav" </dev/null >/dev/null 2>&1 ||
      { MISS+=("write"); SIZE+=("ffmpeg ما يقدر يكتب في مجلد البيانات ($VW): غالبا الحماية من برامج الفدية او برنامج حماية ثاني. الحل VEB_HOME برا Documents (مثل C:/VideoEdit)، او اسمح لـffmpeg.exe من Windows Security > Ransomware protection > Allow an app (التنزيل ما يحله)"); }
    rm -f "$VEB/.write-probe.wav" 2>/dev/null
  fi
  # اختياري، ما ينحسب ناقص: قص الشخص بنموذج MODNet لتاثير الكلام ورا الشخص (حواف الشعر احسن من mediapipe). النموذج بس يشتغل بالمعالج
  # من venv ادوات المونتاج، ومعه venv القص (onnxruntime-directml) يشتغل بكرت الشاشة. venv القص منفصل لان onnxruntime-directml
  # وonnxruntime حق faster-whisper نفس مجلد الحزمة. النموذج من نسخة مثبتة ببصمتها (sha256)، وغير البصمة ما ينحفظ
  MODEL="$VEB/tools/models/modnet.onnx"; CUT="$VEB/tools/cutout"; CPY="$CUT/Scripts/python.exe"
  MODNET_URL=https://huggingface.co/Xenova/modnet/resolve/fa2fa546052fba4c08921230a26cc69a333fca12/onnx/model.onnx
  MODNET_SHA=07c308cf0fc7e6e8b2065a12ed7fc07e1de8febb7dc7839d7b7f15dd66584df9
  model_ok(){ [ "$(sha256sum "$MODEL" 2>/dev/null | cut -d' ' -f1)" = "$MODNET_SHA" ]; }
  dml_ok(){ "$CPY" -c 'import numpy, cv2, onnxruntime as o, sys; sys.exit("DmlExecutionProvider" not in o.get_available_providers())' 2>/dev/null; }
  if [ $INSTALL -eq 1 ] && [ "$2" = --cutout ]; then
    if ! model_ok; then
      line "⏬ نموذج قص الشخص (MODNet ~26 ميقا)…"; mkdir -p "$VEB/tools/models"
      if curl -fsSL --retry 2 -o "$MODEL.part" "$MODNET_URL" && [ "$(sha256sum "$MODEL.part" | cut -d' ' -f1)" = "$MODNET_SHA" ]; then mv -f "$MODEL.part" "$MODEL"
      else rm -f "$MODEL.part"; line "⚠️  نموذج قص الشخص ما نزل او بصمته (sha256) مو نفس المثبتة، فما انحفظ"; fi
    fi
    if ! dml_ok; then
      line "⏬ ادوات القص بكرت الشاشة (onnxruntime-directml ~85 ميقا)…"
      { [ -x "$CPY" ] || "${BASEPY:-$VPY}" -m venv "$CUT"; } &&
        "$CPY" -m pip install --quiet --disable-pip-version-check --only-binary=:all: onnxruntime-directml numpy "opencv-python-headless<5" ||
        line "⚠️  ادوات القص بكرت الشاشة ما تثبتت"
    fi
  fi
  if model_ok && dml_ok; then OK+=("القص بكرت الشاشة")
  elif model_ok && "$PY" -c 'import cv2, onnxruntime' 2>/dev/null; then OK+=("القص بالمعالج"); line "اختياري: القص بكرت الشاشة (اسرع) ~85 ميقا: $0 --install --cutout"
  else line "اختياري: قص الشخص بنموذج على كرت الشاشة (حواف شعر احسن لتاثير الكلام ورا الشخص) ~110 ميقا: $0 --install --cutout"; fi
  [ -s "$ISNET" ] && OK+=("قص الصور") || line "اختياري: نموذج قص الصور (الكولاج والصور المولدة) ~180 ميقا: $0 --subjectcut. بدونه subjectcut.py يقص الخلفية السادة بس"
else
have $PY    && OK+=("python") || { MISS+=("python"); SIZE+=("Python ~50 ميقا"); }
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
  $PY -c "import mediapipe as m, cv2; m.solutions.face_detection" 2>/dev/null && OK+=("كاشف الوجه") || { MISS+=("mediapipe"); SIZE+=("كاشف الوجه mediapipe ~150 ميقا"); }
fi
fi

line "الجاهز: ${OK[*]:-لا شيء}"
# ويندوز بعد --install: اداة من winget (ffmpeg او Node) تبان هنا بس PATH القديم ما يلقاها (او يلقى غيرها)، فاوامر كلود الجاية ما تشوفها.
# --install ثاني ما يحلها: خطوة وحدة، اعادة تشغيل كلود (exit 11). بايثون ما يحتاجها: اختصار python3 بمساره الكامل
if [ "$OS" = win ] && [ -n "$VEB_AFTER" ] && [ ${#MISS[@]} -eq 0 ]; then
  NEW=""; for t in $VEB_WINGET; do [ "$(PATH="$VEB_ORIG_PATH"; hash -r; command -v "$t")" = "$(command -v "$t")" ] || NEW="$NEW $t"; done
  if [ -n "$NEW" ]; then line "✅ كل الادوات نزلت، بس اوامر كلود الحالية ما تشوف:$NEW"; line "⛔ سكر تطبيق كلود وافتحه، وبعدها شغل 00_setup.sh مرة ثانية"; exit 11; fi
fi
# ويندوز: المحرك الخفيف بديل اختياري (ريموشن هو الاساسي)، فسطر اختياري مو ناقص
[ "$OS" = win ] && [ ${#MISS[@]} -eq 0 ] && [ ! -f "$VEB/tools/node_modules/puppeteer-core/package.json" ] && line "اختياري: المحرك الخفيف (puppeteer-core، ~30 ميقا): bash $0 --light"
if [ ${#MISS[@]} -eq 0 ]; then line "✅ كل شي جاهز — نقدر نبدأ."; exit 0; fi
line "الناقص:"
for s in "${SIZE[@]}"; do line "  • $s"; done
line "(ومحرّك الرسم ريموشن ينزل مرة وحدة لكل المقاطع ~400 ميقا، بموافقتك أول مشروع)"

if [ $INSTALL -eq 0 ]; then [ "$OS" = win ] && [ -n "$VEB_AFTER" ] || line "للتنزيل: $0 --install"; exit 10; fi   # ويندوز: الفحص بعد --install ما يطلب --install من جديد

if [ "$OS" = win ]; then
  pipi(){ "$VPY" -m pip install --quiet "$@"; }; VDONE=""
  # الـvenv بنسخ مثبتة: numpy<2 (يبيها mediapipe)، av<15 (faster-whisper 1.2.1 يمرر metadata_errors اللي انشال من av 15)،
  # mediapipe 0.10.21 (اخر نسخة فيها mp.solutions) وهو يجيب opencv-contrib-python، فلا opencv-python معه (نسختين من cv2).
  # --only-binary: الويندوز ما فيه مترجم C، فنسخة بلا wheel (مثل av 14.4.0) تفشل، وكذا pip ياخذ اخر نسخة لها wheel
  venv_install(){
    [ -n "$PY" ] || { [ -n "$BASEPY" ] && "$BASEPY" -m venv "$VENV"; } || return 1
    PY="$VPY"
    "$VPY" -m pip install --quiet --disable-pip-version-check --only-binary=:all: "numpy<2" "faster-whisper>=1.2" "ctranslate2>=4.6.3,<5" "av<15" "mediapipe==0.10.21" || return 1
    if nvidia-smi -L >/dev/null 2>&1; then "$VPY" -m pip install --quiet --disable-pip-version-check --only-binary=:all: "nvidia-cublas-cu12>=12.8"; fi
  }
  # Node وكروم مثبتات للجهاز كله: حتى مع --silent تطلع نافذة الاذن (UAC) وwinget ينطرها، وممكن تطلع ايقونة تومض بس
  UAC="🔐 بتطلع لك نافذة من ويندوز تطلب الاذن، اضغط «نعم». لو ما ظهرت، شوف الايقونة اللي تومض تحت بشريط المهام"
else
pipi(){ $PY -m pip install --quiet --user "$@" 2>/dev/null || $PY -m pip install --quiet --break-system-packages "$@" 2>/dev/null || $PY -m pip install --quiet "$@"; }
fi
winget_i(){ winget install --silent --accept-package-agreements --accept-source-agreements -e --id "$@"; }

for m in "${MISS[@]}"; do
  if [ "$OS" = win ]; then   # ويندوز: numpy والتفريغ وكاشف الوجه venv واحد ينبني مرة وحدة (بعد بايثون)
    case "$m" in numpy|faster-whisper|mediapipe)
      [ -n "$VDONE" ] || { VDONE=1; line "⏬ ادوات بايثون للمونتاج…"; venv_install || NOTE+=("ادوات بايثون للمونتاج فشلت"); }; continue ;;
    cuda-libs)   # cuBLAS 12 بس: ctranslate2 من 4.6.3 ما يحتاج cuDNN
      line "⏬ مكتبات كرت NVIDIA…"
      "$VPY" -m pip install --quiet --disable-pip-version-check --only-binary=:all: "ctranslate2>=4.6.3,<5" "nvidia-cublas-cu12>=12.8" || NOTE+=("مكتبات كرت NVIDIA فشلت"); continue ;;
    ffmpeg-old)  # ffmpeg اقدم من 7: winget يرقيه، ولو ما نزل من winget ينزل نسخة جديدة
      if ! have winget; then NOTE+=("winget مو موجود: حدث «App Installer» من متجر مايكروسوفت"); continue; fi
      line "⏬ ffmpeg…"
      winget upgrade --silent --accept-package-agreements --accept-source-agreements -e --id Gyan.FFmpeg || winget_i Gyan.FFmpeg || NOTE+=("ffmpeg فشل")
      refresh_path; WG+=(ffmpeg); continue ;;
    chrome)      # بلا كروم ولا Edge. الفحص يلقاه بمكانه، مو بـPATH، فما يحتاج refresh_path
      if ! have winget; then NOTE+=("winget مو موجود: حدث «App Installer» من متجر مايكروسوفت"); continue; fi
      line "⏬ كروم…"; line "$UAC"
      winget_i Google.Chrome || NOTE+=("كروم فشل"); continue ;;
    node-x64)    # تبديل Node مثبت بنسخة ثانية ما جربناه، فالمستخدم يشيله اول وبعدها --install ينزل x64
      NOTE+=("Node اللي عندك نسخة ARM: شيله من الاعدادات > التطبيقات، وبعدها شغل 00_setup.sh --install ينزل نسخة x64"); continue ;;
    python-x64)  # نفسه لبايثون، ومعه الـvenv اللي انبنى منه. VDONE: لا venv جديد من بايثون ARM
      VDONE=1; NOTE+=("بايثون اللي عندك نسخة ARM: شيله من الاعدادات > التطبيقات$([ -d "$VENV" ] && printf ' وامسح مجلد %s' "$VENV")، وبعدها شغل 00_setup.sh --install ينزل نسخة x64"); continue ;;
    esac
  fi
  case "$m" in
    ffmpeg|node|python)
      if [ "$OS" = mac ]; then
        if ! have brew; then NOTE+=("لازم Homebrew أول — المستخدم يلصق هذا بالتيرمنال: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""); continue; fi
        case $m in ffmpeg) line "⏬ ffmpeg…"; brew install ffmpeg ;; node) line "⏬ Node…"; brew install node ;; python) line "⏬ Python…"; brew install python ;; esac || NOTE+=("$m فشل")
      elif [ "$OS" = win ]; then
        if ! have winget; then NOTE+=("winget مو موجود — حدّث «App Installer» من متجر مايكروسوفت"); continue; fi
        case $m in ffmpeg) line "⏬ ffmpeg…"; winget_i Gyan.FFmpeg ;; node) line "⏬ Node…"; line "$UAC"; winget_i OpenJS.NodeJS.LTS "${X64[@]}" ;; python) line "⏬ Python…"; winget_i Python.Python.3.12 "${X64[@]}" ;; esac
        refresh_path   # بايثون ينعاد اختياره بالـPATH الجديد قبل الـvenv، واداة ما تبان بعده فشلت
        case $m in python) BASEPY="$(base_py)"; [ -n "$BASEPY" ] ;; *) WG+=("$m"); have $m ;; esac || NOTE+=("$m فشل")
      else NOTE+=("نزّل $m بمدير الحزم (apt/dnf)"); fi ;;
    numpy)          line "⏬ numpy…"; pipi numpy || NOTE+=("numpy فشل") ;;
    mlx-whisper)    line "⏬ mlx-whisper…"; pipi mlx-whisper || NOTE+=("mlx-whisper فشل") ;;
    faster-whisper) line "⏬ faster-whisper…"; pipi faster-whisper || NOTE+=("faster-whisper فشل") ;;
    mediapipe)      line "⏬ mediapipe…"; pipi "mediapipe<0.10.30" opencv-python || NOTE+=("mediapipe فشل") ;;
    xcode)          xcode-select --install 2>/dev/null
                    NOTE+=("طلعت نافذة من أبل لأدوات Xcode — اضغط «Install» وانتظرها تخلص (~10 دقايق)، وبعدها كمّل") ;;
  esac
done

[ ${#NOTE[@]} -gt 0 ] && printf '⚠️  %s\n' "${NOTE[@]}"
[ "$OS" = win ] && VEB_ORIG_PATH="$ORIG_PATH" VEB_WINGET="${WG[*]}" VEB_AFTER=1 exec "$0"   # ويندوز: الفحص الجديد يعرف PATH القديم والادوات اللي نزلت من winget
exec "$0"    # يفحص من جديد ويطبع النتيجة النهائية
