#!/bin/bash
# package.sh — يلقى آخر ملف «B Studio» نزّله المستخدم، ويطبع مجلده (اللي فيه «ملفات لكلود/install.sh»).
#   bash package.sh   ← المسار والخروج 0 · ما لقى شي ← «none» والخروج 14
#   bash package.sh --installer   ← مسار install.sh نفسه بدل المجلد (اسم «ملفات لكلود» ممكن يتخربط لما ينفك على ويندوز)
#   يدوّر في التنزيلات وسطح المكتب، الأحدث أول: مجلد مفكوك يستخدمه كما هو، وملف zip يفكّه في مجلد مؤقت.
#   ويندوز: التنزيلات وسطح المكتب من ويندوز نفسه (قد تكون داخل OneDrive)، والـzip يتفك بـPowerShell بترميز UTF-8
#   (unzip حق Git Bash يخربط الأسماء العربية)، ونلقى install.sh باسمه الإنجليزي لا باسم المجلد العربي.
set -u
INST=0; [ "${1:-}" = --installer ] && INST=1
WIN=0; case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) WIN=1 ;; esac
# ويندوز (Git Bash): المسار ينطبع بشكل ويندوز (C:/…) عشان أي برنامج يقراه، مو بس bash
out(){ if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }
# لقى install.sh: يطبع مجلد الحزمة (فوق «ملفات لكلود»)، او install.sh نفسه مع --installer
found(){ if [ $INST -eq 1 ]; then out "$1"; else out "$(dirname "$(dirname "$1")")"; fi; exit 0; }
# install.sh اللي جنبه edit-studio/SKILL.md، بدون الاعتماد على الاسم العربي: Extract All في Explorer يحط الحزمة
# داخل مجلد زيادة، والاسم يتخربط لو الـ zip من الماك بدون علامة UTF-8. يشتغل على ويندوز بس، ولو البحث بالاسم ما لقى شي
pkg_marker(){ find "$1" -maxdepth 4 -name install.sh -print 2>/dev/null | while IFS= read -r i; do [ -f "$(dirname "$i")/edit-studio/SKILL.md" ] && { echo "$i"; break; }; done; }
# الماك (غير ويندوز)، مثل قبل: مجلد «ملفات لكلود» الحقيقي (فيه install.sh وجنبه edit-studio/SKILL.md) بحث بالأسماء الإنجليزية بعمق 4،
# فيشتغل لو الحزمة داخل مجلد ثاني، أو لو انخربط اسم المجلد العربي. يطبع install.sh (found يطبع المجلد اللي فوقه)
pkg_root(){
  local p
  while IFS= read -r p; do
    [ -f "$(dirname "$p")/edit-studio/SKILL.md" ] || continue
    # اسم المجلد انخربط بفك الـzip؟ نرجّعه (المهارة تنادي «ملفات لكلود/install.sh» بالاسم)
    if [ "$(basename "$(dirname "$p")")" != "ملفات لكلود" ] && [ -n "${2:-}" ] && [ ! -e "$(dirname "$(dirname "$p")")/ملفات لكلود" ]; then
      mv "$(dirname "$p")" "$(dirname "$(dirname "$p")")/ملفات لكلود" 2>/dev/null
      p="$(dirname "$(dirname "$p")")/ملفات لكلود/install.sh"
    fi
    echo "$p"; return 0
  done < <(find "$1" -maxdepth 4 -name install.sh -type f 2>/dev/null)
  return 1
}
DIRS=("$HOME/Downloads" "$HOME/Desktop")
# ويندوز: وبعدها مجلدات التنزيلات وسطح المكتب الحقيقية من ويندوز (OneDrive او المستخدم ممكن ينقلها برا مجلد المستخدم)، بلا تكرار.
# PowerShell وحدة للاثنين، وUTF-8 عشان اسم مستخدم عربي
if [ $WIN -eq 1 ]; then
  while IFS= read -r w; do
    w="$(cygpath -u "$w" 2>/dev/null)"; [ -n "$w" ] || continue
    n=0; for d in "${DIRS[@]}"; do [ "$(printf '%s' "$d" | tr 'A-Z' 'a-z')" = "$(printf '%s' "$w" | tr 'A-Z' 'a-z')" ] && n=1; done
    [ $n -eq 0 ] && DIRS+=("$w")
  done < <("${SYSTEMROOT:+$SYSTEMROOT/System32/WindowsPowerShell/v1.0/}powershell.exe" -NoProfile -NonInteractive -Command "[Console]::OutputEncoding=[Text.UTF8Encoding]::new(\$false); (New-Object -ComObject Shell.Application).Namespace('shell:Downloads').Self.Path; [Environment]::GetFolderPath('Desktop')" </dev/null 2>/dev/null | tr -d '\r')
fi
for d in "${DIRS[@]}"; do
  while IFS= read -r f; do
    if [ -d "$f" ]; then
      p="$f/ملفات لكلود/install.sh"; [ -f "$p" ] || p=""
      [ -z "$p" ] && [ $WIN -eq 1 ] && p="$(pkg_marker "$f")"
      [ $WIN -eq 0 ] && p="$(pkg_root "$f")"   # الماك: بحث العلامة يقرر، مثل قبل
      [ -n "$p" ] && found "$p"
    fi
    if [ -f "$f" ] && [[ "$f" == *.zip ]]; then
      t="$(mktemp -d)" || continue
      if command -v ditto >/dev/null 2>&1; then ditto -x -k "$f" "$t" 2>/dev/null || { rm -rf "$t"; continue; }
      elif command -v cygpath >/dev/null 2>&1 && command -v powershell.exe >/dev/null 2>&1; then
        # ويندوز: unzip حق Git Bash يخربط الاسماء العربية، و.NET يفكها UTF-8 (حتى zip الماك اللي بدون علامة UTF-8)
        Z="$(cygpath -w "$f")" T="$(cygpath -w "$t")" powershell.exe -NoProfile -Command 'Add-Type -AssemblyName System.IO.Compression.FileSystem; [IO.Compression.ZipFile]::ExtractToDirectory($env:Z, $env:T, [Text.Encoding]::UTF8)' </dev/null >/dev/null 2>&1 || { rm -rf "$t"; continue; }
      else unzip -q "$f" -d "$t" 2>/dev/null || { rm -rf "$t"; continue; }; fi
      p="$(find "$t" -maxdepth 3 -path '*/ملفات لكلود/install.sh' -print -quit)"
      [ -n "$p" ] || { [ $WIN -eq 1 ] && p="$(pkg_marker "$t")"; }
      [ $WIN -eq 0 ] && p="$(pkg_root "$t" fix)"   # الماك: بحث العلامة، واسم «ملفات لكلود» المخربط يرجع، مثل قبل
      [ -n "$p" ] && found "$p"
      rm -rf "$t"   # ما لقى الحزمة في هذا الملف: نشيل مجلد الفك عشان ما تتراكم مجلدات tmp.* مع كل تشغيل
    fi
  done < <(ls -td "$d"/*"B Studio"* "$d"/*"استوديو المونتاج"* 2>/dev/null)   # the old name: a download made before 1.0.3
done
echo none; exit 14
