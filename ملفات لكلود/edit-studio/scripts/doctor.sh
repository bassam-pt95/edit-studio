#!/bin/bash
# doctor.sh — تشخيص «استوديو المونتاج»: يفحص كل شي ويطبع تقريراً واحداً بالعربي.
#   bash doctor.sh     الخروج = عدد المشكلات (0 = كل شي جاهز). التنبيهات (⚠) لا تُحسب مشكلات.
. "$(dirname "$0")/_common.sh"
P=0; W=0
ok(){ echo "✓ $1"; }
bad(){ echo "✗ $1"; P=$((P+1)); }
warn(){ echo "⚠ $1"; W=$((W+1)); }

echo "تقرير $STUDIO_NAME ($(date '+%Y-%m-%d %H:%M'))"

# الجهاز
if [ "$OS" = win ]; then ok "الجهاز: ويندوز ($(uname -m))"
elif device_ok; then ok "الجهاز: ماك بمعالج أبل، macOS $(sw_vers -productVersion 2>/dev/null)"
else bad "الجهاز غير مدعوم: $(uname -sm). $MSG_DEVICE"; echo "النتيجة: الاستوديو لا يعمل على هذا الجهاز."; exit 1; fi

# Node
NODE="$(find_node)"
if [ -z "$NODE" ]; then bad "Node غير موجود (يثبّته تجهيز مهارة المونتاج)"
else NV="$("$NODE" -v 2>/dev/null | tr -d v)"
  if [ "$(node_major "$NODE")" -ge 22 ] 2>/dev/null; then ok "Node $NV"; else bad "Node $NV قديم: يلزم 22 أو أحدث"; fi
fi

# ffmpeg + libx264 + ffprobe
if command -v ffmpeg >/dev/null 2>&1; then
  FV="$(ffmpeg -hide_banner -version 2>/dev/null | head -1 | awk '{print $3}')"
  if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q libx264; then ok "ffmpeg $FV مع libx264"; else bad "ffmpeg $FV بلا libx264 (التصدير يحتاجه)"; fi
else bad "ffmpeg غير موجود"; fi
command -v ffprobe >/dev/null 2>&1 && ok "ffprobe" || bad "ffprobe غير موجود"

# Python + التفريغ (مهارة المونتاج)
# أداة التفريغ: mlx_whisper على ماك أبل، faster_whisper على ويندوز (نفس اللي يثبّته تجهيز مهارة المونتاج)
STT_MOD=mlx_whisper; [ "$OS" = win ] && STT_MOD=faster_whisper
if command -v "$PYBIN" >/dev/null 2>&1; then
  PV="$("$PYBIN" -c 'import platform;print(platform.python_version())' 2>/dev/null)"
  if "$PYBIN" -c "import $STT_MOD" 2>/dev/null; then
    if [ -d "$HOME/.cache/huggingface/hub/models--mlx-community--whisper-large-v3-mlx" ] || [ -d "$HOME/.cache/huggingface/hub/models--Systran--faster-whisper-large-v3" ]; then ok "Python $PV مع أداة التفريغ ونموذجها"
    else ok "Python $PV مع أداة التفريغ"; warn "نموذج التفريغ يُنزَّل أول مرة (~3 غيغابايت)"; fi
  else bad "Python $PV بلا أداة التفريغ (يثبّتها تجهيز مهارة المونتاج)"; fi
  # كاشف الوجه: الماك عنده حقه، وويندوز يستخدم mediapipe (مكان فاضي، الكابشن والوجه، وسّط الوجه)
  if [ "$OS" = win ]; then
    if "$PYBIN" -c "import mediapipe as m, cv2; m.solutions.face_detection" 2>/dev/null; then ok "كاشف الوجه (mediapipe)"
    elif "$PYBIN" -c "import mediapipe" 2>/dev/null; then warn "كاشف الوجه: نسخة mediapipe المثبّتة جديدة وما فيها الكاشف، فأزرار الوجه ما تطلع. الحل: $PYBIN -m pip install \"mediapipe<0.10.30\""
    else warn "كاشف الوجه ناقص: أزرار الوجه ما تطلع بالاستوديو (يثبّته تجهيز مهارة المونتاج)"; fi
  fi
else bad "Python غير موجود"; fi

# Chrome (المعاينة والتصدير)
if has_chrome; then ok "متصفح Google Chrome"
else bad "متصفح Google Chrome غير موجود (التصدير يحتاجه): نزّله من google.com/chrome"; fi

# مجلد البيانات
if mkdir -p "$DATA" 2>/dev/null && touch "$DATA/.write-test" 2>/dev/null; then rm -f "$DATA/.write-test"; ok "مجلد البيانات قابل للكتابة: $DATA"
else bad "تعذّرت الكتابة في $DATA"; fi
FREE_GB="$(df -Pk "$DATA" 2>/dev/null | awk 'NR==2{printf "%d", $4/1048576}')"
if [ "${FREE_GB:-0}" -lt 3 ]; then bad "المساحة المتاحة ${FREE_GB:-0} غيغابايت فقط (يلزم 3 على الأقل، والأفضل 5)"
elif [ "${FREE_GB:-0}" -lt 5 ]; then warn "المساحة المتاحة ${FREE_GB} غيغابايت (الأفضل 5 أو أكثر)"
else ok "المساحة المتاحة ${FREE_GB} غيغابايت"; fi

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
  # يعمل؟ المنفذ؟
  URL="$("$NODE" "$APP/studio/start.mjs" --url 2>/dev/null)"
  if [ -n "$URL" ]; then ok "الاستوديو يعمل الآن: $URL"
  elif { [ "$OS" = win ] && netstat -ano 2>/dev/null | grep -q ":8795 .*LISTENING"; } || { [ "$OS" != win ] && lsof -nP -iTCP:8795 -sTCP:LISTEN >/dev/null 2>&1; }; then warn "الاستوديو لا يعمل الآن، والمنفذ 8795 مشغول ببرنامج آخر (سيأخذ منفذاً قريباً)"
  else ok "الاستوديو لا يعمل الآن، والمنفذ 8795 متاح"; fi
  [ -e "$HOME/Desktop/${STUDIO_APP_NAME:-Edit Studio}.$DESK_EXT" ] && ok "تطبيق سطح المكتب موجود" || warn "تطبيق سطح المكتب غير موجود"
elif installed; then
  warn "الاستوديو مثبّت، وفحص ملفاته يحتاج Node أولاً"
else
  bad "$MSG_NOT_INSTALLED"
fi

# مهارة المونتاج
if [ -f "$HOME/.claude/skills/video-edit/SKILL.md" ]; then ok "مهارة المونتاج: ~/.claude/skills/video-edit"
else warn "مهارة المونتاج ليست في ~/.claude/skills (تنركّب من ملف «استوديو المونتاج»: الخطوة 0ب)"; fi

# العدد بالعربي: nar <العدد> <واحد> <اثنان> <من 3 إلى 10> <11 فأكثر>
nar(){ if [ "$1" -eq 1 ]; then echo "$2"; elif [ "$1" -eq 2 ]; then echo "$3"; elif [ "$1" -le 10 ]; then echo "$1 $4"; else echo "$1 $5"; fi; }
echo "────"
if [ $P -eq 0 ] && [ $W -eq 0 ]; then echo "النتيجة: كل شيء جاهز."
elif [ $P -eq 0 ]; then echo "النتيجة: كل شيء جاهز. التنبيهات (⚠) أعلاه لا تمنع العمل."
else echo "النتيجة: $(nar $P 'مشكلة واحدة' 'مشكلتان' 'مشكلات' 'مشكلة'). إن لم تُحل، أرسل هذا التقرير كما هو لبسام."; fi
exit $P
