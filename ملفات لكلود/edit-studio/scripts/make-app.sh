#!/bin/bash
# make-app.sh — يصنع تطبيق «Edit Studio» على سطح المكتب: ضغطة وحدة تشغّل الاستوديو وتفتحه.
#   bash make-app.sh [مجلد]     الافتراضي سطح المكتب. التطبيق يشغّل <البيانات>/studio/app/scripts/start.sh
. "$(dirname "$0")/_common.sh"
device_ok || { echo "$MSG_DEVICE"; exit 20; }
installed || { echo "$MSG_NOT_INSTALLED"; exit 12; }
NAME="${STUDIO_APP_NAME:-Edit Studio}"
DEST_DIR="${1:-$(desk_dir)}"      # ويندوز: سطح المكتب الحقيقي (قد يكون داخل OneDrive أو باسم عربي)
DEST="$DEST_DIR/$NAME.app"
if [ "$OS" = win ]; then
  # ويندوز: اختصار على سطح المكتب يشغّل start.sh ببرنامج bash حق Git (بلا نافذة)
  mkdir -p "$DEST_DIR"
  LNK="$(cygpath -w "$DEST_DIR/$NAME.lnk")"; BASH_W="$(cygpath -w "$(command -v bash)")"
  sq(){ printf '%s' "$1" | sed "s/'/'\\\\''/g"; }     # ' داخل المسار تنهرّب، وإلا انقطع الأمر عند أول ' فيه
  ARGS="-lc \"STUDIO_DATA='$(sq "$DATA")' bash '$(sq "$APP/scripts/start.sh")'\""
  ICO="$(cygpath -w "$APP/studio/public/studio/icon.ico")"
  if LNK="$LNK" BASH_W="$BASH_W" ARGS="$ARGS" ICO="$ICO" powershell.exe -NoProfile -Command '$s=(New-Object -ComObject WScript.Shell).CreateShortcut($env:LNK); $s.TargetPath=$env:BASH_W; $s.Arguments=$env:ARGS; $s.WindowStyle=7; $s.Description="Edit Studio"; if (Test-Path $env:ICO) { $s.IconLocation=$env:ICO }; $s.Save()' >/dev/null 2>&1 && [ -e "$DEST_DIR/$NAME.lnk" ]; then
    echo "التطبيق جاهز: $(wp "$DEST_DIR")/$NAME.lnk"; exit 0
  fi
  echo "تعذّر صنع اختصار سطح المكتب. الاستوديو يشتغل من المحادثة عادي."; exit 1
fi
START="$APP/scripts/start.sh"
TMP="$(mktemp -d)"
# المسار داخل أبل سكربت: نهرّب \ و "
esc(){ printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
printf 'do shell script "STUDIO_DATA=" & quoted form of "%s" & " /bin/bash " & quoted form of "%s" & " > /dev/null 2>&1 &"\n' \
  "$(esc "$DATA")" "$(esc "$START")" > "$TMP/main.applescript"
if ! osacompile -o "$TMP/$NAME.app" "$TMP/main.applescript" 2>"$TMP/err"; then
  echo "تعذّر صنع التطبيق: $(head -1 "$TMP/err")"; rm -rf "$TMP"; exit 1
fi
ICON="$APP/studio/public/studio/icon.icns"
if [ -f "$ICON" ]; then
  cp "$ICON" "$TMP/$NAME.app/Contents/Resources/applet.icns"
  rm -f "$TMP/$NAME.app/Contents/Resources/Assets.car"
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$TMP/$NAME.app/Contents/Info.plist" 2>/dev/null
fi
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $STUDIO_NAME" "$TMP/$NAME.app/Contents/Info.plist" 2>/dev/null
codesign --force --deep -s - "$TMP/$NAME.app" 2>/dev/null
mkdir -p "$DEST_DIR"
rm -rf "$DEST"
mv "$TMP/$NAME.app" "$DEST"
rm -rf "$TMP"
touch "$DEST"
echo "التطبيق جاهز: $DEST"
