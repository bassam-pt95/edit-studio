#!/bin/bash
# setup.sh — تثبيت «استوديو المونتاج» أو تحديثه من هذه الحزمة إلى مجلد البيانات.
#   bash setup.sh             فحص فقط: يطبع الجاهز والناقص وحجمه (لا يغيّر شيئاً)
#   bash setup.sh --install   يثبّت أو يحدّث (بعد موافقة المستخدم): الاستوديو للقراءة فقط + بايثون الاستوديو + تطبيق سطح المكتب
#   خيارات: --no-python (بلا بايثون الاستوديو) · --no-app (بلا تطبيق سطح المكتب)
# الخروج: 0 جاهز · 10 فيه ناقص (فحص) · 11 أدوات المونتاج ناقصة أو Node قديم · 20 جهاز غير مدعوم · 1 فشل
. "$(dirname "$0")/_common.sh"
INSTALL=0; WITH_PY=1; WITH_APP=1
for a in "$@"; do case "$a" in --install) INSTALL=1 ;; --no-python) WITH_PY=0 ;; --no-app) WITH_APP=0 ;; esac; done

device_ok || { echo "$MSG_DEVICE"; exit 20; }
if [ ! -f "$PKG_DIR/studio/start.mjs" ] || [ "$PKG_DIR" = "$APP" ]; then
  echo "شغّل التثبيت من مجلد مهارة الاستوديو نفسها (اللي فيها studio/ وmanifest.json)."; exit 1
fi

# ── أدوات المونتاج اللي يعتمد عليها الاستوديو
MISS=()
NODE="$(find_node)"; NV=0; [ -n "$NODE" ] && NV="$(node_major "$NODE")"
[ -n "$NODE" ] || MISS+=("Node")
command -v ffmpeg >/dev/null 2>&1 || MISS+=("ffmpeg")
command -v ffprobe >/dev/null 2>&1 || MISS+=("ffprobe")
command -v "$PYBIN" >/dev/null 2>&1 || MISS+=("Python")
if [ ${#MISS[@]} -gt 0 ]; then
  LIST="$(printf '%s، ' "${MISS[@]}")"
  echo "ناقص من أدوات المونتاج: ${LIST%، }"
  echo "شغّل تجهيز مهارة المونتاج أولاً (scripts/00_setup.sh) ثم ارجع لهنا."
  exit 11
fi
# Node موجود لكنه قديم: تجهيز المونتاج ما يحدّثه (يكتفي بوجوده)، فالحل تحديثه هو
case "$NV" in ""|*[!0-9]*) NV=0 ;; esac
if [ "$NV" -lt 22 ]; then
  echo "نسخة Node على الجهاز قديمة ($("$NODE" -v 2>/dev/null || echo "؟"))، والاستوديو يحتاج 22 أو أحدث."
  if [ "$OS" = win ]; then echo "التحديث: winget upgrade -e --id OpenJS.NodeJS.LTS (ثم سكّر تطبيق كلود وافتحه)"
  elif [ "$NODE" = /opt/homebrew/bin/node ] || [ "$NODE" = /usr/local/bin/node ]; then echo "التحديث: brew upgrade node"
  else echo "التحديث: brew install node (Node الحالي من مكان ثاني: $NODE)"; fi
  exit 11
fi

PKG_VER="$("$NODE" -e 'process.stdout.write(require(process.argv[1]).version)' "$PKG_DIR/manifest.json")"
CUR_VER=""; installed && CUR_VER="$("$NODE" -e 'try{process.stdout.write(require(process.argv[1]).version)}catch{}' "$APP/manifest.json")"
py_ok(){ [ -x "$PY" ] && "$PY" -c "import dpdfnet, nara_wpe, soundfile, numpy, cv2, PIL" 2>/dev/null; }
APP_NAME="${STUDIO_APP_NAME:-Edit Studio}"

if [ $INSTALL -eq 0 ]; then
  TODO=()
  if [ -z "$CUR_VER" ]; then TODO+=("الاستوديو نفسه (~30 ميقا)")
  elif [ "$CUR_VER" != "$PKG_VER" ]; then TODO+=("تحديث الاستوديو من $CUR_VER إلى $PKG_VER")
  elif ! cmp -s "$PKG_DIR/manifest.json" "$APP/manifest.json"; then TODO+=("تحديث الاستوديو (ملفات أحدث للنسخة $PKG_VER)")
  elif ! "$NODE" "$APP/studio/start.mjs" --check >/dev/null 2>&1; then TODO+=("إعادة تثبيت الاستوديو (ملفاته معدّلة)"); fi
  [ $WITH_PY -eq 1 ] && ! py_ok && TODO+=("أدوات تنظيف الصوت ومشاهد الرسم (~550 ميقا، تنزل من الإنترنت)")
  [ $WITH_APP -eq 1 ] && [ ! -e "$HOME/Desktop/$APP_NAME.$DESK_EXT" ] && TODO+=("تطبيق «$APP_NAME» على سطح المكتب")
  if [ ${#TODO[@]} -eq 0 ]; then echo "✅ الاستوديو مثبّت وجاهز (النسخة $PKG_VER)."; exit 0; fi
  echo "المطلوب:"; for t in "${TODO[@]}"; do echo "  • $t"; done
  echo "للتثبيت: bash \"$0\" --install"
  exit 10
fi

# ── 1) الاستوديو: نسخة جديدة بجانب القديمة، نتحقق منها، ثم نبدّل (للقراءة فقط)
mkdir -p "$DATA" || { echo "تعذّرت الكتابة في $DATA"; exit 1; }
NEW="$DATA/.app-new"; OLD="$DATA/.app-old"
for d in "$NEW" "$OLD"; do [ -d "$d" ] && { chmod -R u+w "$d"; rm -rf "$d"; }; done
mkdir -p "$NEW"
cp -R "$PKG_DIR/studio" "$PKG_DIR/scripts" "$NEW/" && cp "$PKG_DIR/manifest.json" "$PKG_DIR/LICENSE.md" "$NEW/" || { echo "فشل النسخ."; exit 1; }
find "$NEW" -name .DS_Store -delete 2>/dev/null
xattr -cr "$NEW" 2>/dev/null
chmod -R u+rwX,go+rX "$NEW"; chmod +x "$NEW/scripts/"*.sh
if ! "$NODE" "$NEW/studio/start.mjs" --check >/dev/null; then
  echo "الحزمة نفسها فيها ملفات معدّلة: $("$NODE" "$NEW/studio/start.mjs" --check)"
  echo "حمّل الحزمة الأصلية من جديد."; chmod -R u+w "$NEW"; rm -rf "$NEW"; exit 1
fi
if installed; then "$NODE" "$APP/studio/start.mjs" --stop >/dev/null 2>&1; fi
[ -d "$APP" ] && { chmod -R u+w "$APP"; mv "$APP" "$OLD"; }
mv "$NEW" "$APP" && { [ -d "$OLD" ] && rm -rf "$OLD"; }
chmod -R a-w "$APP"
"$NODE" "$APP/studio/start.mjs" --init >/dev/null || { echo "تعذّر تجهيز مجلد البيانات $DATA"; exit 1; }
echo "✅ الاستوديو مثبّت (النسخة $PKG_VER) في $APP"

# ── 2) بايثون الاستوديو (تنظيف الصوت ومشاهد الرسم). نموذج تنظيف الضجيج نفسه داخل الحزمة، فما ينزل شي غير المكتبات
if [ $WITH_PY -eq 1 ] && ! py_ok; then
  echo "⏬ أدوات تنظيف الصوت ومشاهد الرسم (~550 ميقا)…"
  if { [ -x "$PY" ] || "$PYBIN" -m venv "$DATA/py"; } && "$PY" -m pip install --quiet --disable-pip-version-check -r "$APP/studio/voice/requirements.txt"; then
    echo "✅ أدوات الصوت جاهزة"
  else
    echo "⚠️  ما اكتملت أدوات الصوت: الاستوديو يعمل، وتنظيف الصوت ومشاهد الرسم ما تشتغل لين نعيد المحاولة."
  fi
fi

# ── 3) تطبيق سطح المكتب
[ $WITH_APP -eq 1 ] && bash "$APP/scripts/make-app.sh"

# ── 4) تشخيص سريع
bash "$APP/scripts/doctor.sh"
