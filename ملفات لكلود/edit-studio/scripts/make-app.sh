#!/bin/bash
# make-app.sh — يصنع تطبيق «B Studio» على سطح المكتب: ضغطة وحدة تشغّل الاستوديو وتفتحه.
#   bash make-app.sh [مجلد]     الافتراضي سطح المكتب. التطبيق يشغّل <البيانات>/studio/app/scripts/start.sh
. "$(dirname "$0")/_common.sh"
device_ok || { echo "$MSG_DEVICE"; exit 20; }
installed || { echo "$MSG_NOT_INSTALLED"; exit 12; }
NAME="${STUDIO_APP_NAME:-B Studio}"
DEST_DIR="${1:-$(desktop_dir)}"
DEST="$DEST_DIR/$NAME.app"
if [ "$OS" = win ]; then
  # ويندوز: اختصار على سطح المكتب يشغّل start.sh ببرنامج bash حق Git (بلا نافذة)
  mkdir -p "$DEST_DIR"
  LNK="$(cygpath -w "$DEST_DIR/$NAME.lnk")"; BASH_W="$(cygpath -w "$(command -v bash)")"
  # المسارات وسايط منفصلة لـ bash (مو داخل نص الامر)، فاي ' او مسافة بمسار المستخدم ما تخرب الامر
  ARGS="-lc 'STUDIO_DATA=\"\$1\" bash \"\$2\"' bash \"$(cygpath -m "$DATA")\" \"$(cygpath -m "$APP/scripts/start.sh")\""
  ICO="$(cygpath -w "$APP/studio/public/studio/icon.ico")"
  # الاختصار يشغل wscript بملف <البيانات>/launch-studio.js (برا app اللي تنفحص بصمته)، والملف يشغل start.sh ببرنامج bash
  # حق Git بنافذة مخفية وبدون -l، والمسارات تروح له بمتغيرات (STUDIO_DATA وSTUDIO_START): ولا نافذة طرفية.
  # Windows Script Host مقفل او ما فيه wscript: اختصار bash اللي فوق بنافذة مصغرة
  TGT="$BASH_W"; STYLE=7; JS=""
  WSCRIPT="$(cygpath -w "${SYSTEMROOT:-C:/Windows}")\\System32\\wscript.exe"
  wsh_on(){
    local k v
    [ -f "$WSCRIPT" ] || return 1
    for k in HKLM HKCU; do
      v="$(reg.exe query "$k\\Software\\Microsoft\\Windows Script Host\\Settings" -v Enabled 2>/dev/null | tr -d '\r' | awk '$1 == "Enabled" { print $NF }')"
      case "$v" in 0|0x0) return 1 ;; esac
    done
    return 0
  }
  # bash حق Git (bin\bash.exe) يجهز PATH بنفسه؛ لو ما فيه (MSYS2 مثلا) usr\bin\bash.exe مع -l
  GIT_BASH="$(cygpath -w /)bin\\bash.exe"; FLAG=-c
  [ -f "$GIT_BASH" ] || { GIT_BASH="$BASH_W"; FLAG=-lc; }
  NODE="$(find_node)"; LJS="$(cygpath -w "$DATA/launch-studio.js")"
  # الملف ASCII بس (wscript يقرا ملفات .js بترميز النظام)، وكل حرف غيره \uXXXX
  if wsh_on && [ -n "$NODE" ] && SD="$(cygpath -m "$DATA")" SS="$(cygpath -m "$APP/scripts/start.sh")" GB="$GIT_BASH" FLAG="$FLAG" "$NODE" -e '
    const fs = require("fs"), e = process.env;
    const q = (s) => JSON.stringify(s).replace(/[^ -~]/g, (c) => "\\u" + c.charCodeAt(0).toString(16).padStart(4, "0"));
    const cmd = "\"" + e.GB.replace(/\//g, "\\") + "\" " + e.FLAG + " \x27bash \"$STUDIO_START\"\x27";
    fs.writeFileSync(process.argv[1], [
      "// launch-studio.js, written by make-app.sh: the desktop shortcut runs it with wscript. It starts the studio",
      "// (start.sh through Git bash) in a hidden window; the paths travel as environment values.",
      "var sh = new ActiveXObject(\"WScript.Shell\"), env = sh.Environment(\"PROCESS\");",
      "env(\"STUDIO_DATA\") = " + q(e.SD) + ";",
      "env(\"STUDIO_START\") = " + q(e.SS) + ";",
      "sh.Run(" + q(cmd) + ", 0, false);", ""].join("\r\n"));' "$LJS" >/dev/null 2>&1; then
    TGT="$WSCRIPT"; STYLE=1; JS="$LJS"
  fi
  # الاختصار يكتبه Shell.Application (يحفظ الحروف العربية). WScript.Shell يحفظ مساراته بترميز النظام، فالعربي فيها يصير ?
  # لما يكون اسم المستخدم او مجلد البيانات عربي. يبدا من ملف .lnk فاضي (ترويسة 76 بايت) ويعبيه
  if LNK="$LNK" TGT="$TGT" ARGS="$ARGS" JS="$JS" STYLE="$STYLE" ICO="$ICO" powershell.exe -NoProfile -Command '$ErrorActionPreference = "Stop"
    try {
      $b = New-Object byte[] 80; $b[0] = 0x4C; $b[4] = 1; $b[5] = 0x14; $b[6] = 2; $b[12] = 0xC0; $b[19] = 0x46; $b[60] = 1
      [IO.File]::WriteAllBytes($env:LNK, $b)
      $s = (New-Object -ComObject Shell.Application).NameSpace([IO.Path]::GetDirectoryName($env:LNK)).ParseName([IO.Path]::GetFileName($env:LNK)).GetLink
      $s.Path = $env:TGT; $s.ShowCommand = [int]$env:STYLE
      if ($env:JS) { $s.Arguments = "//B //NoLogo `"$env:JS`"" } else { $s.Arguments = $env:ARGS }
      $s.WorkingDirectory = $env:USERPROFILE; $s.Description = "B Studio"
      if (Test-Path -LiteralPath $env:ICO) { $s.SetIconLocation($env:ICO, 0) }; $s.Save()
    } catch { Remove-Item -LiteralPath $env:LNK -ErrorAction SilentlyContinue; exit 1 }' >/dev/null 2>&1 && [ -e "$DEST_DIR/$NAME.lnk" ]; then
    echo "التطبيق جاهز: $(showpath "$DEST_DIR")/$NAME.lnk"
    [ -n "$JS" ] || echo "الاختصار بدون wscript (Windows Script Host مقفل او ما يشتغل هنا): يفتح نافذة طرفية مصغرة تظل في شريط المهام طول ما الاستوديو شغال، وتسكيرها ما يوقف الاستوديو."
    exit 0
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
