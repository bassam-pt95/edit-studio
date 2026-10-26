# _common.sh — مشترك بين سكربتات «B Studio» (يُقرأ بـ source، لا يُشغَّل وحده)
#   SCRIPTS_DIR : مجلد هذه السكربتات      PKG_DIR : المجلد فوقه (مجلد المهارة، أو مجلد التثبيت app)
#   DATA        : مجلد الاستوديو داخله (STUDIO_DATA أو $VEB/studio)   APP : النسخة المثبّتة ($DATA/app)
STUDIO_NAME="B Studio"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
# النظام: ماك، أو ويندوز من Git Bash (اللي يشتغل فيه كلود على ويندوز)
case "$(uname -s)" in Darwin) OS=mac ;; MINGW*|MSYS*|CYGWIN*) OS=win ;; *) OS=other ;; esac
# مجلد المستخدم. ويندوز: من USERPROFILE مثل بايثون (expanduser) وnode (os.homedir)، فمتغير HOME عام (Emacs او R) ما يقسم البيانات لمجلدين
UHOME="$HOME"; [ "$OS" = win ] && [ -n "${USERPROFILE:-}" ] && UHOME="$(cygpath -u "$USERPROFILE")"
# متغير بيئة ويندوز لمجلد، بشكل Git Bash (/c/…). فاضي لو غير موجود. (Git Bash يعطي المتغيرات بحروف كبيرة أحياناً فنجرّب الشكلين)
wenv(){
  local v k
  for k in "$1" "$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"; do v="$(printenv "$k" 2>/dev/null)"; [ -n "$v" ] && break; done
  [ -n "$v" ] || return 0
  if command -v cygpath >/dev/null 2>&1; then cygpath -u "$v" 2>/dev/null || printf '%s' "$v"; else printf '%s' "$v"; fi
}
# مسار للطباعة وللبرامج التي ما تفهم مسارات Git Bash مثل /c/… (node وpython وJSON): على ويندوز C:/…، وعلى الماك المسار نفسه
wp(){ if [ "$OS" = win ] && command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
# مجلد بيانات مهارة المونتاج. على ويندوز: لو مجلد المستخدم فيه حروف غير إنجليزية (أو OneDrive نقل «المستندات») نستخدم C:/EditStudio،
# لأن OpenCV وmediapipe ما يفتحون مسارات عربية والمزامنة تقفل الملفات. نفس قاعدة dataHomeDefault بـserver/platform.mjs و_paths.py: لازم تتطابق
veb_default(){
  local d="$UHOME/Documents/video-edit" od k
  if [ "$OS" != win ]; then printf '%s' "$d"; return; fi     # uname غير ويندوز (Darwin ولينكس): دائماً ~/Documents/video-edit
  if printf '%s' "$d" | LC_ALL=C grep -q '[^ -~]' || printf '%s' "$d" | grep -qiE 'onedrive|/appdata/'; then printf 'C:/EditStudio'; return; fi
  for k in OneDrive OneDriveConsumer OneDriveCommercial; do
    od="$(wenv "$k")"
    [ -n "$od" ] && [ -d "$od/Documents" ] && { printf 'C:/EditStudio'; return; }
  done
  printf '%s' "$d"
}
#   VEB         : مجلد بيانات مهارة المونتاج (VEB_HOME أو ~/Documents/video-edit؛ ويندوز: انظر veb_default)
#   DATA        : مجلد الاستوديو داخله (STUDIO_DATA أو $VEB/studio)   APP : النسخة المثبّتة ($DATA/app)
VEB="${VEB_HOME:-$(veb_default)}"
OWN_DATA="${VEB_HOME:-}${STUDIO_DATA:-}"     # المستخدم سمّى مجلده بنفسه (قبل ما نصدّر VEB_HOME تحت): ما ندوّر على مجلد قديم
# كل برنامج نشغّله (node، python) يقرا نفس المجلد: على ويندوز نسلّمه لهم بشكل C:/…
if [ "$OS" = win ] && [ -z "${VEB_HOME:-}" ]; then export VEB_HOME="$(wp "$VEB")"; fi
DATA="${STUDIO_DATA:-$VEB/studio}"
APP="$DATA/app"
PROJECTS="$DATA/projects"
# ويندوز: 0.9.6 كان يحط البيانات كلها في المستندات (Documents/video-edit)، ومن 1.0.0 ممكن veb_default يختار C:/EditStudio،
# فالمشاريع القديمة تختفي من الاستوديو. install.sh ينقلها (old_plan)، وstudio.sh list يقول وين مجلد قديم فيه مشاريع ما انتقلت
# فيه مشاريع؟ مجلد ظاهر (مو .mohrer) في studio/projects (الاستوديو) أو projects (مهارة المونتاج)
has_projects(){ find "$1/studio/projects" "$1/projects" -mindepth 1 -maxdepth 1 -type d ! -name '.*' 2>/dev/null | grep -q .; }
# نفس المجلد؟ ويندوز: C:/x و/c/x وC:\x والحروف الكبيرة والصغيرة نفس الشي
dir_key(){ showpath "$1" | tr '[:upper:]\\' '[:lower:]/' | sed 's#/*$##'; }
# مجلدات بيانات 0.9.6 الموجودة وهي غير $VEB، سطر لكل واحد: Documents/video-edit ببيت المستخدم وبمستندات OneDrive. ويندوز بس
old_homes(){
  [ "$OS" = win ] && [ -z "$OWN_DATA" ] || return 0
  local d k od seen="|$(dir_key "$VEB")|"
  { printf '%s\n' "$UHOME/Documents/video-edit" "$HOME/Documents/video-edit"
    for k in OneDrive OneDriveConsumer OneDriveCommercial; do od="$(wenv "$k")"; [ -n "$od" ] && printf '%s\n' "$od/Documents/video-edit"; done
  } | while IFS= read -r d; do
    [ -d "$d" ] && [ ! -L "$d" ] || continue                  # اختصار (junction) لمجلد ثاني: مو مجلد قديم
    k="$(dir_key "$d")"
    case "$seen" in *"|$k|"*) continue ;; esac
    seen="$seen$k|"; printf '%s\n' "$d"
  done
}
# وش نسوي بمجلد قديم $1 والجديد $2: move لو الجديد مو موجود (المجلد كله ينتقل)، merge لو الجديد بلا مشاريع (المشاريع بس)،
# keep لو الجديد فيه مشاريع (ما نلمس شي)، ولا شي لو القديم ما فيه مشاريع
old_plan(){
  has_projects "$1" || return 0
  if has_projects "$2"; then echo keep; elif [ -e "$2" ]; then echo merge; else echo move; fi
}
# بايثون يقرأ الملفات UTF-8 بكل الأنظمة (على ويندوز الافتراضي ترميز النظام، فالملف اللي فيه عربي يوقّف pip أو السكربت)
export PYTHONUTF8=1
if [ "$OS" = win ]; then
  PY="$DATA/py/Scripts/python.exe"; PYBIN=python      # venv على ويندوز يحط بايثون في Scripts، واسم بايثون الجهاز python
  DESK_EXT="lnk"; CHROME_WIN="/c/Program Files/Google/Chrome/Application/chrome.exe"
  # بايثون يقرا ويكتب الملفات ومخرجاته UTF-8 (الافتراضي على ويندوز ترميز النظام، فالعربي يوقف pip او السكربت)
  export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
  # بايثون مهارة المونتاج (venv يبنيه 00_setup.sh) فيه التفريغ وكاشف الوجه: الاستوديو ياخذه بمساره، مو من متغيرات تنحط بمكان ثاني
  MPY="$VEB/tools/py/Scripts/python.exe"
  if [ -x "$MPY" ]; then MPYW="$(cygpath -w "$MPY")"; export MOHRER_STT_PYTHON="${MOHRER_STT_PYTHON:-$MPYW}" MOHRER_FACE_PYTHON="${MOHRER_FACE_PYTHON:-$MPYW}"; fi
  # winget يكتب PATH بالريجستري بس، والـbash الشغال (وتطبيق كلود اللي شغله) يكمل بالقديم. refresh_path_win يقرا Path حق الجهاز والمستخدم
  # (UTF-8 عشان اسم مستخدم عربي) ويضيف اللي مو فيه بالاخر، مع WinGet\Links، وبلا WindowsApps (اختصار بايثون حق المتجر).
  # نفس refresh_path في 00_setup.sh حق مهارة المونتاج. PowerShell بمساره من SYSTEMROOT، لو PATH ناقص حتى System32
  refresh_path_win(){ local p d m; m="$(shopt -p nocasematch)"; shopt -s nocasematch
    p="$("${SYSTEMROOT:+$SYSTEMROOT/System32/WindowsPowerShell/v1.0/}powershell.exe" -NoProfile -NonInteractive -Command "[Console]::OutputEncoding=[Text.UTF8Encoding]::new(\$false); [Environment]::GetEnvironmentVariable('Path','Machine')+';'+[Environment]::GetEnvironmentVariable('Path','User')" </dev/null 2>/dev/null | tr -d '\r')"
    [ -n "$LOCALAPPDATA" ] && p="$p;$LOCALAPPDATA\\Microsoft\\WinGet\\Links"
    while IFS= read -r d; do d="${d%/}"
      case "$d" in ""|*/windowsapps) continue ;; esac
      case ":$PATH:" in *":$d:"*) ;; *) PATH="$PATH:$d" ;; esac
    done < <(cygpath -u -p "$p" 2>/dev/null | tr ':' '\n')
    eval "$m"; export PATH; hash -r; }
else
  PY="$DATA/py/bin/python"; PYBIN=python3
  DESK_EXT="app"
  export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
fi
# ويندوز: curl حق Git (Schannel) يفحص الغاء الشهادة، وورا برنامج حماية يفحص HTTPS او بروكسي يطيح بخطا 35 لو خادم الفحص ما ينوصل.
# --ssl-revoke-best-effort يسمح بهالشي بس (سلسلة الشهادة واسم الموقع تنفحص). نص مو مصفوفة: المصفوفة الفاضية مع set -u تطيح على bash 3.2 بالماك
CURL_TLS=""; [ "$OS" = win ] && CURL_TLS="--ssl-revoke-best-effort"
# ويندوز: يطبع اخر سطر من خطا curl (الملف $1)، ولو الخطا من الشهادة يقول السبب الغالب. على الماك ما يطبع شي
curl_why(){ [ "$OS" = win ] || return 0; [ -s "$1" ] && tail -1 "$1"; grep -qE '\((35|60)\)|revocation|CRYPT_E' "$1" 2>/dev/null && echo "السبب غالبا برنامج حماية يفحص HTTPS او بروكسي، مو انقطاع النت"; return 0; }
# ويندوز (setup وdoctor بس): PYBIN = بايثون venv المونتاج لو يشتغل، والا اول python او python3 حقيقي في PATH، والا py -3.12، والا فاضي.
# python وpython3 في WindowsApps اختصارات المتجر: تعدي command -v وتطبع «Python was not found»، فما تنحسب
resolve_pybin(){
  local c
  PYBIN=""
  if "$MPY" -c 'import sys' </dev/null >/dev/null 2>&1; then PYBIN="$MPY"; return 0; fi
  while IFS= read -r c; do
    case "$(printf '%s' "$c" | tr 'A-Z' 'a-z')" in ""|*/windowsapps/*) continue ;; esac
    "$c" -c 'import sys' </dev/null >/dev/null 2>&1 && { PYBIN="$c"; return 0; }
  done <<< "$(type -aP python python3)"
  c="$(py -3.12 -c 'import sys;print(sys.executable)' </dev/null 2>/dev/null | tr -d '\r')"
  [ -n "$c" ] && PYBIN="$(cygpath -u "$c")"
  return 0
}
# ويندوز (setup وdoctor): اول ما تنقص اداة، PATH ينقرا من الريجستري مرة وحدة ويرجع 0 فالفحص ينعاد (الفحص العادي ما يشغل PowerShell).
# الماك: يرجع 1 وما يسوي شي
path_again(){ [ "$OS" = win ] && [ -z "$PATH_AGAIN" ] && PATH_AGAIN=1 && refresh_path_win; }
# سطح المكتب. ويندوز: المجلد الحقيقي من ويندوز (OneDrive ممكن ينقله برا مجلد المستخدم)، UTF-8 عشان اسم مستخدم عربي.
# PowerShell ياخذ ثلث ثانية تقريبا: كل سكربت يناديها مرة وحدة. ما رد: مجلد المستخدم/Desktop. الماك: $HOME/Desktop
desktop_dir(){
  local w=""
  [ "$OS" = win ] && w="$("${SYSTEMROOT:+$SYSTEMROOT/System32/WindowsPowerShell/v1.0/}powershell.exe" -NoProfile -NonInteractive -Command "[Console]::OutputEncoding=[Text.UTF8Encoding]::new(\$false); [Environment]::GetFolderPath('Desktop')" </dev/null 2>/dev/null | tr -d '\r')"
  if [ -n "$w" ]; then cygpath -u "$w"; else printf '%s' "$UHOME/Desktop"; fi
}
# مسار للعرض. ويندوز: بشكل C:/… (مثل package.sh) عشان ينلصق في python -c او node -e او JSON، مو /c/… حق bash
showpath(){ if [ "$OS" = win ]; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
# بصمة ملف (shasum على الماك، sha256sum على ويندوز)
sha256_of(){ if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d" " -f1; else sha256sum "$1" | cut -d" " -f1 | tr -d '*'; fi; }
# يفتح الاستوديو بنافذة لحاله: كروم بدون تبويبات ولا شريط عنوان (--app، نفس المحرّك فاللون والتصدير ما يتغيرون).
# على ويندوز لو ما فيه كروم يفتحها Edge (من نفس المحرّك وموجود بكل ويندوز). ولو ما فيه ولا واحد: المتصفح الأساسي.
CHROME_MAC="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
# المتصفح اللي يفتح به الاستوديو ويصدّر: كروم ثم Edge (مسار Git Bash). نفس الملف ينفحص بـdoctor وينمرَّر للتصدير (export_chrome)
app_browser_win(){
  local c pf pf86 la named=""
  pf="$(wenv ProgramFiles)"; pf86="$(wenv 'ProgramFiles(x86)')"; la="$(wenv LOCALAPPDATA)"
  if [ -n "${CHROME:-}" ]; then named="$CHROME"; command -v cygpath >/dev/null 2>&1 && named="$(cygpath -u "$CHROME" 2>/dev/null || printf '%s' "$CHROME")"; fi
  for c in "$named" "$CHROME_WIN" "$pf/Google/Chrome/Application/chrome.exe" "$pf86/Google/Chrome/Application/chrome.exe" \
           "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" "$la/Google/Chrome/Application/chrome.exe" \
           "$pf86/Microsoft/Edge/Application/msedge.exe" "$pf/Microsoft/Edge/Application/msedge.exe" \
           "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" "/c/Program Files/Microsoft/Edge/Application/msedge.exe"; do
    [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return 0; }
  done
  return 1
}
# ويندوز: التصدير (export.mjs) ياخذ مسار المتصفح من CHROME، وإلا يجرّب مسار الماك ويفشل. نعطيه نفس الملف اللي لقيناه (بشكل C:\…)
export_chrome(){
  [ "$OS" = win ] || return 0
  local b; b="$(app_browser_win)" || return 0
  if command -v cygpath >/dev/null 2>&1; then export CHROME="$(cygpath -w "$b")"; else export CHROME="$b"; fi
}
open_url(){
  if [ "$OS" = win ]; then
    local b; b="$(app_browser_win)"
    if [ -n "$b" ]; then "$b" --app="$1" >/dev/null 2>&1 & else cmd.exe //c start "" "$1" >/dev/null 2>&1; fi
  elif [ -x "$CHROME_MAC" ]; then
    # كروم شغّال: ياخذ الطلب ويفتح النافذة. مقفول: يشتغل ومعه النافذة
    if pgrep -xq "Google Chrome"; then "$CHROME_MAC" --app="$1" >/dev/null 2>&1 &
    else open -a "Google Chrome" --args --app="$1" 2>/dev/null || open "$1"; fi   # mac-only: Chrome launcher
  else open "$1"; fi
}
# ويندوز: يكفي كروم أو Edge (التصدير يستخدم نفس الملف اللي يفتح به الاستوديو)
has_chrome(){ if [ "$OS" = win ]; then app_browser_win >/dev/null; else [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; fi; }

MSG_DEVICE="النسخة التجريبية من الاستوديو تعمل على أجهزة ماك بمعالج أبل (M1 وأحدث) وعلى ويندوز (من Git Bash)، وجهازك ليس منها. يمكنك إكمال مونتاجك كالمعتاد بمهارة المونتاج."
MSG_NOT_INSTALLED="الاستوديو غير مثبّت بعد على هذا الجهاز."
# WSL (لينكس داخل ويندوز): الاستوديو ومهارة المونتاج يشتغلون على ويندوز من Git Bash، مو من WSL
IS_WSL=0
if [ "$OS" = other ] && { grep -qi microsoft /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; }; then
  IS_WSL=1
  MSG_DEVICE="هذا WSL (لينكس داخل ويندوز)، والاستوديو ومهارة المونتاج لا يعملان فيه. على ويندوز يعملان من Git Bash: شغل الامر من Git Bash على ويندوز نفسه."
fi

# ماك بمعالج أبل؟ (حتى لو الطرفية تعمل تحت Rosetta)
device_ok(){
  [ "$OS" = win ] && return 0
  [ "$(uname -s)" = Darwin ] || return 1
  [ "$(uname -m)" = arm64 ] && return 0
  [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ]
}
# ويندوز على معالج ARM؟ device_ok يقبله، بس كاشف الوجه والتفريغ ما لها نسخة ARM. Git Bash x64 بالمحاكاة يشوف AMD64،
# فـPROCESSOR_IDENTIFIER (فيه ARM) يكمل الفحص
win_arm(){
  [ "$OS" = win ] || return 1
  case "${PROCESSOR_ARCHITECTURE:-} ${PROCESSOR_ARCHITEW6432:-}" in *ARM64*) return 0 ;; esac
  case "${PROCESSOR_IDENTIFIER:-}" in *ARM*) return 0 ;; esac
  return 1
}
MSG_ARM="ويندوز على معالج ARM: كاشف الوجه والتفريغ (mediapipe وctranslate2) ما لها نسخة ARM. ركب Python 3.12 نسخة x64 (تشتغل بالمحاكاة وابطا)"

# كلود (تطبيق سطح المكتب) يحفظ PATH وقت تشغيله، فأي أداة ثبّتناها بعدها (winget: Node، ffmpeg، Python) ما تنشاف.
# نقرا PATH الجديد من سجل ويندوز ونضيف الناقص (ويندوز بس، وبلا حذف شي)
refresh_path(){ [ "$OS" = win ] && refresh_path_win; return 0; }   # نفس refresh_path_win (فرع ويندوز فوق)

# ويندوز: «الحماية من برامج الفدية» (Controlled Folder Access) شغّالة؟ تمنع node وffmpeg وpython من الكتابة في المستندات وسطح المكتب
MSG_CFA="الحماية من برامج الفدية (Controlled Folder Access) شغّالة: لو ffmpeg أو node أو python انمنعوا من الكتابة في «المستندات»، افتح أمان ويندوز ثم الحماية من الفيروسات ثم الحماية من برامج الفدية ثم السماح لتطبيق، وأضف node.exe وffmpeg.exe وpython.exe. أو خلّ البيانات خارج المستندات (VEB_HOME=C:/EditStudio)"
cfa_enabled(){
  [ "$OS" = win ] && command -v powershell.exe >/dev/null 2>&1 || return 1
  [ "$(powershell.exe -NoProfile -Command '(Get-MpPreference).EnableControlledFolderAccess' 2>/dev/null | tr -d '\r')" = 1 ]
}

# مجلدات ويندوز الحقيقية: سطح المكتب والتنزيلات قد تكون منقولة (OneDrive، قرص ثاني، مجلد بالعربي). ماك: ~/Desktop و~/Downloads
# بيت المستخدم الحقيقي؟ (لو HOME انغيّر لمجلد ثاني، مثل تجربة، ما نسأل ويندوز عن مجلدات المستخدم الأصلي)
home_is_profile(){ [ "$(wenv USERPROFILE | tr '[:upper:]' '[:lower:]')" = "$(printf '%s' "$HOME" | tr '[:upper:]' '[:lower:]')" ]; }
win_known_dir(){   # $1 = Desktop أو Downloads
  local d
  home_is_profile || return 1
  command -v powershell.exe >/dev/null 2>&1 || return 1
  if [ "$1" = Downloads ]; then
    d="$(powershell.exe -NoProfile -Command "(New-Object -ComObject Shell.Application).Namespace('shell:Downloads').Self.Path" 2>/dev/null | tr -d '\r')"
  else
    d="$(powershell.exe -NoProfile -Command "[Environment]::GetFolderPath('$1')" 2>/dev/null | tr -d '\r')"
  fi
  [ -n "$d" ] || return 1
  if command -v cygpath >/dev/null 2>&1; then cygpath -u "$d" 2>/dev/null || printf '%s' "$d"; else printf '%s' "$d"; fi
}
desk_dir(){
  [ -n "${STUDIO_DESKTOP:-}" ] && { printf '%s' "$STUDIO_DESKTOP"; return; }
  if [ "$OS" = win ]; then
    local d; d="$(win_known_dir Desktop)" && [ -d "$d" ] && { printf '%s' "$d"; return; }
    if home_is_profile; then d="$(wenv OneDrive)/Desktop"; [ -d "$d" ] && { printf '%s' "$d"; return; }; fi
  fi
  printf '%s' "$HOME/Desktop"      # ماك (uname Darwin) ولينكس، وويندوز لو ما انعرف المجلد
}
downloads_dir(){
  if [ "$OS" = win ]; then
    local d; d="$(win_known_dir Downloads)" && [ -d "$d" ] && { printf '%s' "$d"; return; }
  fi
  printf '%s' "$HOME/Downloads"
}

# بايثون حقيقي؟ على ويندوز «python» الافتراضي اختصار المتجر (WindowsApps\python.exe): موجود بالـPATH لكنه ما يشغّل شي.
# نمرّ على كل ما بالـPATH بهالاسم (قد يكون الاختصار قبل بايثون الحقيقي) ونرجّع الأول اللي يشتغل في PY_FOUND
python_real(){
  local p
  PY_FOUND=""
  while IFS= read -r p; do
    case "$p" in */WindowsApps/*|*\\WindowsApps\\*) continue ;; esac
    "$p" -c 'import sys' >/dev/null 2>&1 && { PY_FOUND="$p"; return 0; }
  done < <(type -ap "$1" 2>/dev/null)
  return 1
}
# هل عند الجهاز بايثون يشتغل؟ وعلى ويندوز يضبط PYBIN عليه (اسمه لو هو الأول بالـPATH، وإلا مساره الكامل؛ أو اللي يدلّ عليه py -3 لو بايثون ما انضاف للـPATH)
have_python(){
  if [ "$OS" != win ]; then command -v "$PYBIN" >/dev/null 2>&1; return; fi
  local e n
  for n in python python3; do
    if python_real "$n"; then
      if [ "$(command -v "$n" 2>/dev/null)" = "$PY_FOUND" ]; then PYBIN="$n"; else PYBIN="$PY_FOUND"; fi
      return 0
    fi
  done
  if command -v py >/dev/null 2>&1; then
    e="$(py -3 -c 'import sys;print(sys.executable)' 2>/dev/null | tr -d '\r')"
    if [ -n "$e" ]; then
      command -v cygpath >/dev/null 2>&1 && e="$(cygpath -u "$e" 2>/dev/null || printf '%s' "$e")"
      [ -x "$e" ] && { PYBIN="$e"; return 0; }
    fi
  fi
  return 1
}

node_major(){ "$1" -e 'process.stdout.write(process.versions.node.split(".")[0])' 2>/dev/null; }
# أحدث node موجود (تطبيقات سطح المكتب تبدأ بمسار ناقص، وقد يكون بالجهاز أكثر من نسخة: brew وnvm)
find_node_once(){
  local n v best="" bv=-1 W=()
  # ويندوز: ومكان node حق مديري النسخ (nvm-windows وVolta وfnm)، لو PATH قديم ما فيه. ${W[@]+…}: مصفوفة فاضية مع set -u على bash 3.2
  [ "$OS" = win ] && W=("${NVM_SYMLINK:+$(cygpath -u "$NVM_SYMLINK")/node.exe}" /c/nvm4w/nodejs/node.exe \
    "${LOCALAPPDATA:+$(cygpath -u "$LOCALAPPDATA")/Volta/bin/node.exe}" \
    "$(ls -d "$(cygpath -u "${APPDATA:-/nonexistent}")"/fnm/node-versions/*/installation/node.exe 2>/dev/null | sort -V | tail -1)")
  for n in "$(command -v node 2>/dev/null)" /opt/homebrew/bin/node /usr/local/bin/node "/c/Program Files/nodejs/node.exe" \
           "$(ls -d "$HOME"/.nvm/versions/node/*/bin/node 2>/dev/null | sort -V | tail -1)" ${W[@]+"${W[@]}"}; do
    [ -n "$n" ] && [ -x "$n" ] || continue
    v="$(node_major "$n")"; case "$v" in ""|*[!0-9]*) v=0 ;; esac
    [ "$v" -gt "$bv" ] && { best="$n"; bv="$v"; }
  done
  [ -n "$best" ] && { echo "$best"; return 0; }
  return 1
}
find_node(){
  find_node_once && return 0
  # ثبّته للتو ولسا كلود ما شاف PATH الجديد؟ نقرا PATH من السجل ونعيد (ويندوز بس)
  [ "$OS" = win ] || return 1
  refresh_path; find_node_once
}

# النسخة المثبّتة موجودة وقابلة للتشغيل؟
installed(){ [ -f "$APP/studio/start.mjs" ] && [ -f "$APP/manifest.json" ]; }
