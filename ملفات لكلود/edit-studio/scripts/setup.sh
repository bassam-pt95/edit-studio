#!/bin/bash
# setup.sh — تثبيت «B Studio» أو تحديثه من هذه الحزمة إلى مجلد البيانات.
#   bash setup.sh             فحص فقط: يطبع الجاهز والناقص وحجمه (لا يغيّر شيئاً)
#   bash setup.sh --install   يثبّت أو يحدّث (بعد موافقة المستخدم) كل شي مع بعض: أدوات مهارة المونتاج (00_setup.sh --install:
#                             Node وffmpeg وبايثون والتفريغ وكاشف الوجه) + الاستوديو للقراءة فقط + بايثون الاستوديو + نموذج
#                             التفريغ (~3 قيقا، مرة وحدة) + تطبيق سطح المكتب
#   خيارات: --no-python (بلا بايثون الاستوديو) · --no-app (بلا تطبيق سطح المكتب) · --no-montage (بلا أدوات المونتاج ونموذج التفريغ)
# الخروج: 0 جاهز · 10 فيه ناقص (فحص) · 11 أدوات المونتاج ناقصة أو Node قديم أو (ويندوز) سكّر كلود وافتحه وعِد · 20 جهاز غير مدعوم · 1 فشل
. "$(dirname "$0")/_common.sh"
INSTALL=0; WITH_PY=1; WITH_APP=1; WITH_MONTAGE=1
for a in "$@"; do case "$a" in --install) INSTALL=1 ;; --no-python) WITH_PY=0 ;; --no-app) WITH_APP=0 ;; --no-montage) WITH_MONTAGE=0 ;; esac; done

device_ok || { echo "$MSG_DEVICE"; exit 20; }
win_arm && echo "⚠️  $MSG_ARM"
if [ ! -f "$PKG_DIR/studio/start.mjs" ] || [ "$PKG_DIR" = "$APP" ]; then
  echo "شغّل التثبيت من مجلد مهارة الاستوديو نفسها (اللي فيها studio/ وmanifest.json)."; exit 1
fi

# ── 0) أدوات مهارة المونتاج: تنزل مع الاستوديو بنفس الخطوة (2026-10-31، «كل الأدوات تنزل مع بعض»). قبل كانت خطوة لحالها
# قبل هذي، والتفريغ ما كان له نموذج لين أول تفريغ من محادثة كلود، فاللي استخدم الاستوديو لحاله ما اشتغل عنده التفريغ
MONTAGE_SETUP="$(dirname "$PKG_DIR")/video-edit/scripts/00_setup.sh"
[ -f "$MONTAGE_SETUP" ] || WITH_MONTAGE=0
if [ $INSTALL -eq 1 ] && [ $WITH_MONTAGE -eq 1 ]; then
  echo "⏬ أدوات مهارة المونتاج (التفريغ وكاشف الوجه وما ينقص من Node وffmpeg وبايثون)…"
  bash "$MONTAGE_SETUP" --install; MRC=$?
  # 11: ويندوز ثبّت أدوات بـwinget وأوامر كلود الحالية ما تشوفها: يسكّر كلود ويفتحه ويعيد نفس الأمر
  [ $MRC -eq 11 ] && exit 11
  [ $MRC -eq 0 ] || echo "⚠️  ما اكتملت أدوات مهارة المونتاج (الخروج $MRC): أكمل الاستوديو، والتشخيص بالآخر يقول وش الناقص."
fi

# ── أدوات المونتاج اللي يعتمد عليها الاستوديو
tools_check(){
MISS=()
NODE="$(find_node)"; NV=0; [ -n "$NODE" ] && NV="$(node_major "$NODE")"
[ -n "$NODE" ] || MISS+=("Node")
command -v ffmpeg >/dev/null 2>&1 || MISS+=("ffmpeg")
command -v ffprobe >/dev/null 2>&1 || MISS+=("ffprobe")
if [ "$OS" = win ]; then resolve_pybin; [ -n "$PYBIN" ] || MISS+=("Python")   # ويندوز: اختصار المتجر ما ينحسب بايثون
else
command -v "$PYBIN" >/dev/null 2>&1 || MISS+=("Python")
fi
}
tools_check
# ويندوز: اداة ركبها 00_setup.sh للتو بـwinget ما تبان بـPATH القديم، فنقرا PATH من الريجستري ونعيد الفحص (الماك ما يتغير)
[ ${#MISS[@]} -gt 0 ] && path_again && tools_check
if [ ${#MISS[@]} -gt 0 ]; then
  LIST="$(printf '%s، ' "${MISS[@]}")"
  echo "ناقص من أدوات المونتاج: ${LIST%، }"
  if [ $WITH_MONTAGE -eq 1 ]; then echo "للتثبيت (ينزّلها كلها مع الاستوديو): bash \"$0\" --install"
  else echo "شغّل تجهيز مهارة المونتاج أولاً (scripts/00_setup.sh) ثم ارجع لهنا."; fi
  [ "$OS" = win ] && echo "لو ثبتها تجهيز مهارة المونتاج للتو: سكر تطبيق كلود وافتحه، وبعدها عيد."
  exit 11
fi
# Node موجود لكنه قديم: تجهيز المونتاج ما يحدّثه (يكتفي بوجوده)، فالحل تحديثه هو
case "$NV" in ""|*[!0-9]*) NV=0 ;; esac
if [ "$NV" -lt 22 ]; then
  echo "نسخة Node على الجهاز قديمة ($("$NODE" -v 2>/dev/null || echo "؟"))، والاستوديو يحتاج 22 أو أحدث."
  if [ "$OS" = win ]; then
    # ويندوز: الامر حسب اللي ركب Node: nvm-windows (NVM_SYMLINK او C:\nvm4w) او Volta او fnm، والا winget (upgrade لو هو ركبه، والا install)
    NVMS=/nonexistent; [ -n "${NVM_SYMLINK:-}" ] && NVMS="$(cygpath -u "$NVM_SYMLINK")"
    case "$NODE" in
      "$NVMS"/node|"$NVMS"/node.exe|*/nvm4w/*|*/nvm/*) echo "التحديث: nvm install lts ثم nvm use lts (ثم سكر تطبيق كلود وافتحه)" ;;
      */Volta/*) echo "التحديث: volta install node (ثم سكر تطبيق كلود وافتحه)" ;;
      */fnm/*|*/fnm_multishells/*) echo "التحديث: fnm install --lts (ثم سكر تطبيق كلود وافتحه)" ;;
      *) if winget list -e --id OpenJS.NodeJS.LTS --accept-source-agreements </dev/null >/dev/null 2>&1; then echo "التحديث: winget upgrade -e --id OpenJS.NodeJS.LTS (ثم سكّر تطبيق كلود وافتحه)"
         else echo "التثبيت: winget install -e --id OpenJS.NodeJS.LTS (ثم سكر تطبيق كلود وافتحه)"; fi ;;
    esac
  elif [ "$NODE" = /opt/homebrew/bin/node ] || [ "$NODE" = /usr/local/bin/node ]; then echo "التحديث: brew upgrade node"
  else echo "التحديث: brew install node (Node الحالي من مكان ثاني: $NODE)"; fi
  exit 11
fi

PKG_VER="$("$NODE" -e 'process.stdout.write(require(process.argv[1]).version)' "$PKG_DIR/manifest.json")"
CUR_VER=""; installed && CUR_VER="$("$NODE" -e 'try{process.stdout.write(require(process.argv[1]).version)}catch{}' "$APP/manifest.json")"
py_ok(){ [ -x "$PY" ] && "$PY" -c "import dpdfnet, nara_wpe, soundfile, numpy, cv2, PIL" 2>/dev/null; }
# ويندوز: مصنف الاصوات (YAMNet من قوقل، Apache-2.0، نسخة ONNX) يعطي التشريح وفحص القصات اسماء الموثرات والموسيقى،
# ويشتغل على بايثون الاستوديو (studio/tools/hear.py). الماك عنده مصنفه. اختياري: لو ما نزل يكمل الاستوديو بدونه
YAM="${MOHRER_HOME:-$DATA/home}/models/yamnet"
YAM_URL="https://huggingface.co/zeropointnine/yamnet-onnx/resolve/ac2ca3bd45d12ec1f19f1144205ea529b4e9dedf"
yam_ok(){ [ -s "$YAM/yamnet.onnx" ] && [ -s "$YAM/yamnet_class_map.csv" ]; }
yam_get(){   # <الملف> <بصمته>: ينزل لاسم موقت، ولو البصمة نفسها ينقله لمكانه
  mkdir -p "$YAM" && curl -fsSL $CURL_TLS --max-time 600 -o "$YAM/$1.part" "$YAM_URL/$1" && [ "$(sha256_of "$YAM/$1.part")" = "$2" ] && mv -f "$YAM/$1.part" "$YAM/$1" && return 0
  rm -f "$YAM/$1.part"; return 1
}
APP_NAME="${STUDIO_APP_NAME:-B Studio}"
# بايثون التفريغ: بويندوز venv مهارة المونتاج (MPY من _common.sh)، وبالماك بايثون الجهاز اللي فيه mlx_whisper
stt_py(){
  local c
  for c in "${MPY:-}" "${MOHRER_STT_PYTHON:-}" python3 /opt/homebrew/bin/python3 /usr/local/bin/python3; do
    [ -n "$c" ] || continue
    command -v "$c" >/dev/null 2>&1 || [ -x "$c" ] || continue
    "$c" -c "import importlib.util as u, sys; sys.exit(0 if (sys.platform == 'darwin' and u.find_spec('mlx_whisper')) or u.find_spec('faster_whisper') else 1)" </dev/null >/dev/null 2>&1 && { printf '%s' "$c"; return 0; }
  done
  return 1
}
FETCH="$PKG_DIR/studio/tools/np/model_fetch.py"
model_ok(){ local t; t="$(stt_py)" || return 1; "$t" "$FETCH" --has </dev/null >/dev/null 2>&1; }

if [ $INSTALL -eq 0 ]; then
  TODO=()
  if [ -z "$CUR_VER" ]; then TODO+=("الاستوديو نفسه (~30 ميقا)")
  elif [ "$CUR_VER" != "$PKG_VER" ]; then TODO+=("تحديث الاستوديو من $CUR_VER إلى $PKG_VER")
  elif ! cmp -s "$PKG_DIR/manifest.json" "$APP/manifest.json"; then TODO+=("تحديث الاستوديو (ملفات أحدث للنسخة $PKG_VER)")
  elif ! "$NODE" "$APP/studio/start.mjs" --check >/dev/null 2>&1; then TODO+=("إعادة تثبيت الاستوديو (ملفاته معدّلة)"); fi
  [ $WITH_PY -eq 1 ] && ! py_ok && TODO+=("أدوات تنظيف الصوت ومشاهد الرسم (~550 ميقا، تنزل من الإنترنت)")
  [ "$OS" = win ] && [ $WITH_PY -eq 1 ] && ! yam_ok && TODO+=("مصنف الاصوات (~15 ميقا)")
  [ $WITH_APP -eq 1 ] && [ ! -e "$(desktop_dir)/$APP_NAME.$DESK_EXT" ] && TODO+=("تطبيق «${APP_NAME}» على سطح المكتب")
  if [ $WITH_MONTAGE -eq 1 ]; then
    bash "$MONTAGE_SETUP" </dev/null >/dev/null 2>&1 || TODO+=("أدوات مهارة المونتاج: التفريغ وكاشف الوجه (تفاصيلها: bash \"$MONTAGE_SETUP\")")
    stt_py >/dev/null && ! model_ok && TODO+=("نموذج التفريغ (~3 قيقا، مرة وحدة)")
  fi
  if [ ${#TODO[@]} -eq 0 ]; then echo "✅ الاستوديو مثبّت وجاهز (النسخة $PKG_VER)."; exit 0; fi
  echo "المطلوب:"; for t in "${TODO[@]}"; do echo "  • $t"; done
  echo "للتثبيت: bash \"$0\" --install"
  exit 10
fi

# ── 1) الاستوديو: نسخة جديدة بجانب القديمة، نتحقق منها، ثم نبدّل (للقراءة فقط)
# ويندوز: المجلد اللي فيه طرفية واقفة ما ينقل، فهذا السكربت نفسه يطلع منه (ممكن ينشغل من داخل app)
[ "$OS" = win ] && cd "$HOME"
mkdir -p "$DATA" || { echo "تعذّرت الكتابة في $DATA"; exit 1; }
NEW="$DATA/.app-new"; OLD="$DATA/.app-old"
for d in "$NEW" "$OLD"; do [ -d "$d" ] && { chmod -R u+w "$d"; rm -rf "$d"; }; done
mkdir -p "$NEW"
cp -R "$PKG_DIR/studio" "$PKG_DIR/scripts" "$NEW/" && cp "$PKG_DIR/manifest.json" "$PKG_DIR/LICENSE.md" "$NEW/" || { echo "فشل النسخ."; exit 1; }
find "$NEW" -name .DS_Store -delete 2>/dev/null
find "$NEW" \( -name '._*' -o -iname Thumbs.db -o -iname ehthumbs.db -o -iname desktop.ini \) -delete 2>/dev/null   # ملفات ._ (نسخ من الماك على فلاشة) وملفات يكتبها Explorer
xattr -cr "$NEW" 2>/dev/null
chmod -R u+rwX,go+rX "$NEW"; chmod +x "$NEW/scripts/"*.sh
# ويندوز: git clone مع core.autocrlf=true يحول الملفات الى CRLF فتتغير بصماتها كلها. نسمي السبب بدل «ملفات معدلة»
if [ "$OS" = win ] && grep -qU $'\r' "$NEW/scripts/"*.sh 2>/dev/null; then   # -U: grep حق Git for Windows يشيل CR من اخر السطر بدونه
  echo "ملفات الحزمة فيها نهايات اسطر ويندوز (CRLF): نزل الحزمة من جديد، او استنسخها بـ git clone -c core.autocrlf=false"
  chmod -R u+w "$NEW"; rm -rf "$NEW"; exit 1
fi
if ! "$NODE" "$NEW/studio/start.mjs" --check >/dev/null; then
  echo "الحزمة نفسها فيها ملفات معدّلة: $("$NODE" "$NEW/studio/start.mjs" --check)"
  echo "حمّل الحزمة الأصلية من جديد."; chmod -R u+w "$NEW"; rm -rf "$NEW"; exit 1
fi
if installed; then "$NODE" "$APP/studio/start.mjs" --stop >/dev/null 2>&1; fi
# التبديل: ويندوز ما يغير اسم مجلد فيه ملف مفتوح او طرفية واقفة داخله، والسيرفر ممكن ياخذ لحظة يطلع.
# نعيد المحاولة، ولو ظل نوقف برسالة بدل ما تنحط الجديدة داخل القديمة ونقول ✅
if [ "$OS" != win ]; then
# الماك (مثل قبل نقل ويندوز): محاولة وحدة. لو القديمة ما انتقلت (برنامج فاتح شي فيها: طرفية، محرر، مشغّل) نوقف ونبقي
# القديمة شغّالة، ما نحط الجديدة داخلها
if [ -d "$APP" ]; then
  chmod -R u+w "$APP"
  if ! mv "$APP" "$OLD" 2>/dev/null; then
    echo "تعذّر تبديل نسخة الاستوديو القديمة: غالباً برنامج فاتح شي داخل مجلدها ($(wp "$APP")). سكّر أي طرفية أو محرر أو مشغّل فيديو فاتح هناك وأعد التثبيت. القديمة باقية كما هي."
    chmod -R a-w "$APP"; chmod -R u+w "$NEW"; rm -rf "$NEW"; exit 1
  fi
fi
if ! mv "$NEW" "$APP"; then
  echo "تعذّر وضع النسخة الجديدة."; [ -d "$OLD" ] && mv "$OLD" "$APP"; exit 1
fi
else
if [ -d "$APP" ]; then
  chmod -R u+w "$APP"
  for i in 1 2 3 4 5; do mv "$APP" "$OLD" 2>/dev/null && break; sleep 1; done
  if [ -d "$APP" ]; then
    echo "تعذر استبدال النسخة القديمة (فيه ملف او نافذة مفتوحة داخل $APP). سكر الاستوديو والطرفيات اللي داخله وعيد المحاولة."
    chmod -R a-w "$APP"; chmod -R u+w "$NEW"; rm -rf "$NEW"; exit 1
  fi
fi
mv "$NEW" "$APP" || { [ -d "$OLD" ] && mv "$OLD" "$APP" && chmod -R a-w "$APP"; echo "فشل التبديل"; exit 1; }
fi
[ -d "$OLD" ] && rm -rf "$OLD"
chmod -R a-w "$APP"
"$NODE" "$APP/studio/start.mjs" --init >/dev/null || { echo "تعذّر تجهيز مجلد البيانات $DATA"; exit 1; }
echo "✅ الاستوديو مثبّت (النسخة $PKG_VER) في $(showpath "$APP")"

# ── 2) بايثون الاستوديو (تنظيف الصوت ومشاهد الرسم). نموذج تنظيف الضجيج نفسه داخل الحزمة، فما ينزل شي غير المكتبات
if [ $WITH_PY -eq 1 ] && ! py_ok; then
  echo "⏬ أدوات تنظيف الصوت ومشاهد الرسم (~550 ميقا)…"
  if { [ -x "$PY" ] || "$PYBIN" -m venv "$(wp "$DATA/py")"; } && "$PY" -m pip install --quiet --disable-pip-version-check -r "$APP/studio/voice/requirements.txt"; then
    echo "✅ أدوات الصوت جاهزة"
  else
    echo "⚠️  ما اكتملت أدوات الصوت: الاستوديو يعمل، وتنظيف الصوت ومشاهد الرسم ما تشتغل لين نعيد المحاولة."
  fi
fi
if [ "$OS" = win ] && [ $WITH_PY -eq 1 ] && ! yam_ok; then
  echo "⏬ مصنف الاصوات (~15 ميقا)…"
  if yam_get yamnet_class_map.csv cdf24d193e196d9e95912a2667051ae203e92a2ba09449218ccb40ef787c6df2 \
     && yam_get yamnet.onnx 1510041dce24a2e9e84ec546807ac408ae496da6d1ed41bc3ccba649623f8e19; then echo "✅ مصنف الاصوات جاهز"
  else echo "⚠️  ما نزل مصنف الاصوات: الاستوديو يعمل، والتشريح وفحص القصات بدون اسماء الموثرات والموسيقى لين نعيد التثبيت."; fi
fi

# ── 2ب) نموذج التفريغ، مرة وحدة مع باقي الأدوات (الاستوديو نفسه ينزّله لو ناقص وقت التفريغ، بس هنا أحسن: قبل أول مقطع)
if [ $WITH_MONTAGE -eq 1 ]; then
  if TPY="$(stt_py)"; then
    if model_ok; then :
    else
      echo "⏬ نموذج التفريغ (~3 قيقا، مرة وحدة)…"
      if "$TPY" "$APP/studio/tools/np/model_fetch.py" --ensure </dev/null; then echo "✅ نموذج التفريغ جاهز"
      else echo "⚠️  ما نزل نموذج التفريغ: الاستوديو يعمل، وينزّله بنفسه أول ما تفرّغ مقطع."; fi
    fi
  else echo "⚠️  أداة التفريغ مو موجودة، فما نزل نموذجها: التشخيص بالآخر يقول وش الناقص."; fi
fi

# ── 3) تطبيق سطح المكتب
[ $WITH_APP -eq 1 ] && bash "$APP/scripts/make-app.sh"

# ── 4) تشخيص سريع
bash "$APP/scripts/doctor.sh"
