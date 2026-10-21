#!/bin/bash
# _common.sh — مشترك بين سكربتات المهارة (يُقرأ بـ source من كل سكربت، لا يُشغَّل وحده)
#   VE_WIN=1 على ويندوز (Git Bash)، وإلا 0. على الماك كل شي هنا لا يغيّر سلوك السكربتات.
#   ve_set_python   → يحدد PY (ويندوز: أول بايثون يشتغل فعلاً، لا اختصار متجر مايكروسوفت؛ غيره: python3)
#   veb_home        → مجلد بيانات المستخدم (نفس اللي يطلّعه _paths.py)
#   ve_safe_name    → اسم ملف سليم (ويندوز فقط: يستبدل | > < " * ? : \ / ويشيل النقطة والمسافة الأخيرة)
#   ve_junction     → وصلة مجلد بـNode (junction على ويندوز بلا صلاحية مدير؛ ما نمر على cmd //c mklink)
#   ve_hide / ve_unhide / ve_free_out → أدوات ويندوز الصغيرة (ملف مخفي · ملف مفتوح ببرنامج ثاني)
# مسارات بايثون تُمرَّر دايماً بـsys.argv: Git Bash يحوّل مسارات الـarguments بس، ما يحوّل اللي داخل نص الكود.

# بايثون يقرأ ويكتب UTF-8 على كل الأنظمة (على ويندوز الافتراضي ترميز النظام cp1252 فأي عربي يطيّح)
export PYTHONUTF8=1

case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) VE_WIN=1 ;; *) VE_WIN=0 ;; esac

# ويندوز فوق WSL: bash اللي يشتغل لينكس مو Git Bash، وبايثون/ffmpeg اللي يلقاهم غير اللي تقصده المهارة
if [ "$(uname -s)" = Linux ] && grep -qi microsoft "${VE_PROC_VERSION:-/proc/version}" 2>/dev/null; then
  echo "⛔ هذا bash داخل WSL (لينكس فوق ويندوز) — المهارة على ويندوز تشتغل من Git Bash بس." >&2
  echo "   شغّلها من «Git for Windows»: \"C:\\Program Files\\Git\\bin\\bash.exe\" scripts/<السكربت>.sh" >&2
  exit 1
fi

if [ "$VE_WIN" = 1 ]; then
  # لو متغير تعطيل تحويل المسارات مضبوط بالبيئة، ffmpeg وpython وnode يستلمون /c/... فما يلقون الملفات
  unset MSYS_NO_PATHCONV MSYS2_ARG_CONV_EXCL
  # لو انفتح bash بلا login يبدأ PATH بـsystem32 (find وsort وmktemp وdf وawk تصير أدوات ويندوز، مو أدوات Git)
  export PATH="${VE_MSYS_BIN:-/usr/bin:/mingw64/bin}:$PATH"   # VE_MSYS_BIN: للاختبارات بس
fi

# بايثون شغّال فعلاً: يجرب python3 ثم python ثم py -3، ويقدّم اللي مو بمجلد WindowsApps
# (اختصار المتجر هناك يطبع «Python was not found» ويرجع 9009؛ بايثون المتجر الحقيقي يمر لو ما لقينا غيره)
ve_pick_python(){
  local pass c exe
  PY=""
  for pass in 1 2; do
    for c in python3 python "py -3"; do
      exe="$(command -v ${c%% *} 2>/dev/null)" || continue
      case "$exe" in */[Ww]indows[Aa]pps/*) [ "$pass" = 1 ] && continue ;; *) [ "$pass" = 2 ] && continue ;; esac
      if $c -c 'import sys; sys.exit(0)' >/dev/null 2>&1; then PY="$c"; return 0; fi
    done
  done
  return 1
}
ve_set_python(){
  if [ "$VE_WIN" = 1 ]; then
    ve_pick_python || { echo "⛔ ما لقيت Python شغّال (اختصار متجر مايكروسوفت ما يحسب) — شغّل: bash scripts/00_setup.sh" >&2; exit 1; }
  else
    PY=python3
  fi
}

# مجلد بيانات المستخدم. ويندوز: نسأل _paths.py نفسه (يقرأ USERPROFILE لا HOME، فما ينقسم المجلد بين بايثون وbash)
veb_home(){
  if [ -n "$VEB_HOME" ] || [ "$VE_WIN" != 1 ]; then printf '%s\n' "${VEB_HOME:-$HOME/Documents/video-edit}"; return 0; fi
  local h
  h="$(${PY:-python} -c 'import sys;sys.path.insert(0,sys.argv[1]);import _paths;print(_paths.HOME)' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" 2>/dev/null | tr -d '\r')"
  if [ -n "$h" ]; then cygpath -u "$h" 2>/dev/null || printf '%s\n' "$h"; else printf '%s\n' "$HOME/Documents/video-edit"; fi
}

# اسم ملف سليم على ويندوز (على الماك يرجع كما هو)
ve_safe_name(){
  local n="$1"
  if [ "$VE_WIN" != 1 ]; then printf '%s' "$n"; return 0; fi
  n="$(printf '%s' "$n" | tr -d '\000-\037' | tr '|><"*?:\\/' '_________')"
  while :; do case "$n" in *.|*" ") n="${n%?}" ;; *) break ;; esac; done
  case "$(printf '%s' "${n%%.*}" | tr 'a-z' 'A-Z')" in CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9]) n="_$n" ;; esac
  printf '%s' "${n:-out}"
}

# وصلة مجلد: Node يشيل القديم (الوصلة نفسها لا الهدف) ويسوي junction ويتأكد إنها توصل للهدف
ve_junction(){
  node -e '
const fs=require("fs"),path=require("path");const [t,l]=process.argv.slice(1);
const die=(e)=>{console.error(String(e&&e.message||e));process.exit(1)};
try{const s=fs.lstatSync(l);if(s.isSymbolicLink())fs.unlinkSync(l);else if(s.isDirectory())fs.rmSync(l,{recursive:true,force:true});else fs.unlinkSync(l)}catch(e){if(e.code!=="ENOENT")die(e)}
try{fs.symlinkSync(path.resolve(t),l,"junction")}catch(e){die(e)}
try{if(fs.realpathSync(l).toLowerCase()!==fs.realpathSync(t).toLowerCase())die("the link does not lead to the target")}catch(e){die(e)}
' "$1" "$2"
}

# ملف مخفي بويندوز (اللي يبدأ بنقطة ما يخفيه Explorer). الكتابة فوق ملف مخفي ترفضها ويندوز، فنكشفه قبل ما نكتب
ve_hide(){ [ "$VE_WIN" = 1 ] && [ -e "$1" ] && attrib +h "$(cygpath -w "$1")" >/dev/null 2>&1; return 0; }
ve_unhide(){ [ "$VE_WIN" = 1 ] && [ -e "$1" ] && attrib -h "$(cygpath -w "$1")" >/dev/null 2>&1; return 0; }

# ويندوز: لو الناتج القديم مفتوح ببرنامج (مشغّل فيديو) ما ينمسح، فنوقف برسالة بدل خطأ إنجليزي غامض
ve_free_out(){
  [ "$VE_WIN" = 1 ] || return 0
  [ -e "$1" ] || return 0
  rm -f "$1" 2>/dev/null || { echo "⛔ الملف مفتوح ببرنامج ثاني: $(basename "$1") — سكّره وأعد التشغيل" >&2; exit 4; }
}

# ويندوز: بعد winget المسار الجديد يكتبه السجل بس، وهذا الـbash يبقى على القديم
ve_refresh_win_path(){
  [ "$VE_WIN" = 1 ] || return 0
  local raw p u IFS
  raw="$(powershell.exe -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','Machine')+';'+[Environment]::GetEnvironmentVariable('Path','User')" 2>/dev/null | tr -d '\r')"
  [ -n "$raw" ] || return 0
  IFS=';'
  for p in $raw; do
    [ -n "$p" ] || continue
    u="$(cygpath -u "$p" 2>/dev/null)" || continue
    case ":$PATH:" in *":$u:"*) ;; *) PATH="$PATH:$u" ;; esac
  done
  export PATH
}

# ويندوز: نوع القرص ونظام ملفاته لمسار («Fixed NTFS» · «Network ...»)، وفاضي لو ما عرفنا
ve_win_drive(){
  local m dl
  m="$(cygpath -m "$1" 2>/dev/null)" || return 0
  case "$m" in //*) echo "Network UNC"; return 0 ;; [A-Za-z]:*) dl="${m%%:*}" ;; *) return 0 ;; esac
  powershell.exe -NoProfile -Command "[System.IO.DriveInfo]::new('${dl}:\\') | ForEach-Object { \$_.DriveType.ToString() + ' ' + \$_.DriveFormat }" 2>/dev/null | tr -d '\r'
}
