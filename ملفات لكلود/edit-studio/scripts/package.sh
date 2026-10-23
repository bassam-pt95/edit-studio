#!/bin/bash
# package.sh — يلقى آخر ملف «استوديو المونتاج» نزّله المستخدم، ويطبع مجلده (اللي فيه «ملفات لكلود/install.sh»).
#   bash package.sh   ← المسار والخروج 0 · ما لقى شي ← «none» والخروج 14
#   يدوّر في التنزيلات وسطح المكتب، الأحدث أول: مجلد مفكوك يستخدمه كما هو، وملف zip يفكّه في مجلد مؤقت.
#   ويندوز: التنزيلات وسطح المكتب من ويندوز نفسه (قد تكون داخل OneDrive)، والـzip يتفك بـPowerShell بترميز UTF-8
#   (unzip حق Git Bash يخربط الأسماء العربية)، ونلقى install.sh باسمه الإنجليزي لا باسم المجلد العربي.
set -u
. "$(dirname "$0")/_common.sh"
# المسار ينطبع بشكل ويندوز (C:/…) عشان أي برنامج يقراه، مو بس bash (الماك: المسار نفسه)
out(){ wp "$1"; echo; }
# من مجلد: مجلد «ملفات لكلود» الحقيقي (فيه install.sh وجنبه edit-studio/SKILL.md) بحث بالأسماء الإنجليزية بعمق 4،
# فيشتغل لو Explorer حط الحزمة داخل مجلد ثاني، أو لو انخربط اسم المجلد العربي. يطبع المجلد اللي فوقه
pkg_root(){
  local p
  while IFS= read -r p; do
    [ -f "$(dirname "$p")/edit-studio/SKILL.md" ] || continue
    # اسم المجلد انخربط بفك الـzip؟ نرجّعه (المهارة تنادي «ملفات لكلود/install.sh» بالاسم)
    if [ "$(basename "$(dirname "$p")")" != "ملفات لكلود" ] && [ -n "${2:-}" ] && [ ! -e "$(dirname "$(dirname "$p")")/ملفات لكلود" ]; then
      mv "$(dirname "$p")" "$(dirname "$(dirname "$p")")/ملفات لكلود" 2>/dev/null
      p="$(dirname "$(dirname "$p")")/ملفات لكلود/install.sh"
    fi
    dirname "$(dirname "$p")"; return 0
  done < <(find "$1" -maxdepth 4 -name install.sh -type f 2>/dev/null)
  return 1
}
# فك zip: ماك ditto؛ ويندوز PowerShell بـUTF-8 (يحتاج .NET 4.7.2، أي ويندوز 10 محدّث) وإن فشل unzip حق Git Bash
unzip_to(){
  if [ "$OS" = win ] && command -v powershell.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
    ZIPW="$(cygpath -w "$1")" DESTW="$(cygpath -w "$2")" powershell.exe -NoProfile -Command 'Add-Type -AssemblyName System.IO.Compression.FileSystem; [IO.Compression.ZipFile]::ExtractToDirectory($env:ZIPW,$env:DESTW,[Text.Encoding]::UTF8)' >/dev/null 2>&1 && return 0
  fi
  if command -v ditto >/dev/null 2>&1; then ditto -x -k "$1" "$2" 2>/dev/null; return; fi
  unzip -q "$1" -d "$2" 2>/dev/null
}
SEEN=""      # (darwin: التنزيلات وسطح المكتب في البيت؛ ويندوز: من ويندوز نفسه، والبيت احتياط)
for d in "$(downloads_dir)" "$(desk_dir)" "$HOME/Downloads" "$HOME/Desktop"; do
  [ -d "$d" ] || continue
  case "
$SEEN
" in *"
$d
"*) continue ;; esac
  SEEN="$SEEN
$d"
  while IFS= read -r f; do
    if [ -d "$f" ]; then r="$(pkg_root "$f")" && { out "$r"; exit 0; }; fi
    if [ -f "$f" ] && [[ "$f" == *.zip ]]; then
      t="$(mktemp -d)"
      unzip_to "$f" "$t" || continue
      r="$(pkg_root "$t" fix)" && { out "$r"; exit 0; }
    fi
  done < <(ls -td "$d"/*"استوديو المونتاج"* 2>/dev/null)
done
echo none; exit 14
