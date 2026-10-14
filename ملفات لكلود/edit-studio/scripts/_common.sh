# _common.sh — مشترك بين سكربتات «استوديو المونتاج» (يُقرأ بـ source، لا يُشغَّل وحده)
#   SCRIPTS_DIR : مجلد هذه السكربتات      PKG_DIR : المجلد فوقه (مجلد المهارة، أو مجلد التثبيت app)
#   VEB         : مجلد بيانات مهارة المونتاج (VEB_HOME أو ~/Documents/video-edit)
#   DATA        : مجلد الاستوديو داخله (STUDIO_DATA أو $VEB/studio)   APP : النسخة المثبّتة ($DATA/app)
STUDIO_NAME="استوديو المونتاج"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
VEB="${VEB_HOME:-$HOME/Documents/video-edit}"
DATA="${STUDIO_DATA:-$VEB/studio}"
APP="$DATA/app"
PROJECTS="$DATA/projects"
# بايثون يقرأ الملفات UTF-8 بكل الأنظمة (على ويندوز الافتراضي ترميز النظام، فالملف اللي فيه عربي يوقّف pip أو السكربت)
export PYTHONUTF8=1
# النظام: ماك، أو ويندوز من Git Bash (اللي يشتغل فيه كلود على ويندوز)
case "$(uname -s)" in Darwin) OS=mac ;; MINGW*|MSYS*|CYGWIN*) OS=win ;; *) OS=other ;; esac
if [ "$OS" = win ]; then
  PY="$DATA/py/Scripts/python.exe"; PYBIN=python      # venv على ويندوز يحط بايثون في Scripts، واسم بايثون الجهاز python
  DESK_EXT="lnk"; CHROME_WIN="/c/Program Files/Google/Chrome/Application/chrome.exe"
else
  PY="$DATA/py/bin/python"; PYBIN=python3
  DESK_EXT="app"
  export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
fi
# بصمة ملف (shasum على الماك، sha256sum على ويندوز)
sha256_of(){ if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d" " -f1; else sha256sum "$1" | cut -d" " -f1 | tr -d '*'; fi; }
# يفتح الاستوديو بنافذة لحاله: كروم بدون تبويبات ولا شريط عنوان (--app، نفس المحرّك فاللون والتصدير ما يتغيرون).
# على ويندوز لو ما فيه كروم يفتحها Edge (من نفس المحرّك وموجود بكل ويندوز). ولو ما فيه ولا واحد: المتصفح الأساسي.
EDGE_WIN_LIST=("/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" "/c/Program Files/Microsoft/Edge/Application/msedge.exe")
CHROME_MAC="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
app_browser_win(){
  local c
  for c in "$CHROME_WIN" "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" "$LOCALAPPDATA/Google/Chrome/Application/chrome.exe" "${EDGE_WIN_LIST[@]}"; do
    [ -n "$c" ] && [ -x "$c" ] && { printf '%s' "$c"; return 0; }
  done
  return 1
}
open_url(){
  if [ "$OS" = win ]; then
    local b; b="$(app_browser_win)"
    if [ -n "$b" ]; then "$b" --app="$1" >/dev/null 2>&1 & else cmd.exe //c start "" "$1" >/dev/null 2>&1; fi
  elif [ -x "$CHROME_MAC" ]; then
    # كروم شغّال: ياخذ الطلب ويفتح النافذة. مقفول: يشتغل ومعه النافذة
    if pgrep -xq "Google Chrome"; then "$CHROME_MAC" --app="$1" >/dev/null 2>&1 &
    else open -a "Google Chrome" --args --app="$1" 2>/dev/null || open "$1"; fi
  else open "$1"; fi
}
has_chrome(){ if [ "$OS" = win ]; then [ -x "$CHROME_WIN" ] || [ -x "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" ] || [ -x "$LOCALAPPDATA/Google/Chrome/Application/chrome.exe" ]; else [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; fi; }

MSG_DEVICE="النسخة التجريبية من الاستوديو تعمل على أجهزة ماك بمعالج أبل (M1 وأحدث) وعلى ويندوز (من Git Bash)، وجهازك ليس منها. يمكنك إكمال مونتاجك كالمعتاد بمهارة المونتاج."
MSG_NOT_INSTALLED="الاستوديو غير مثبّت بعد على هذا الجهاز."

# ماك بمعالج أبل؟ (حتى لو الطرفية تعمل تحت Rosetta)
device_ok(){
  [ "$OS" = win ] && return 0
  [ "$(uname -s)" = Darwin ] || return 1
  [ "$(uname -m)" = arm64 ] && return 0
  [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ]
}

node_major(){ "$1" -e 'process.stdout.write(process.versions.node.split(".")[0])' 2>/dev/null; }
# أحدث node موجود (تطبيقات سطح المكتب تبدأ بمسار ناقص، وقد يكون بالجهاز أكثر من نسخة: brew وnvm)
find_node(){
  local n v best="" bv=-1
  for n in "$(command -v node 2>/dev/null)" /opt/homebrew/bin/node /usr/local/bin/node "/c/Program Files/nodejs/node.exe" \
           "$(ls -d "$HOME"/.nvm/versions/node/*/bin/node 2>/dev/null | sort -V | tail -1)"; do
    [ -n "$n" ] && [ -x "$n" ] || continue
    v="$(node_major "$n")"; case "$v" in ""|*[!0-9]*) v=0 ;; esac
    [ "$v" -gt "$bv" ] && { best="$n"; bv="$v"; }
  done
  [ -n "$best" ] && { echo "$best"; return 0; }
  return 1
}

# النسخة المثبّتة موجودة وقابلة للتشغيل؟
installed(){ [ -f "$APP/studio/start.mjs" ] && [ -f "$APP/manifest.json" ]; }
