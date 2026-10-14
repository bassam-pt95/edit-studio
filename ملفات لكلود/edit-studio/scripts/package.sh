#!/bin/bash
# package.sh — يلقى آخر ملف «استوديو المونتاج» نزّله المستخدم، ويطبع مجلده (اللي فيه «ملفات لكلود/install.sh»).
#   bash package.sh   ← المسار والخروج 0 · ما لقى شي ← «none» والخروج 14
#   يدوّر في التنزيلات وسطح المكتب، الأحدث أول: مجلد مفكوك يستخدمه كما هو، وملف zip يفكّه في مجلد مؤقت.
set -u
# ويندوز (Git Bash): المسار ينطبع بشكل ويندوز (C:/…) عشان أي برنامج يقراه، مو بس bash
out(){ if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }
for d in "$HOME/Downloads" "$HOME/Desktop"; do
  while IFS= read -r f; do
    if [ -d "$f" ] && [ -f "$f/ملفات لكلود/install.sh" ]; then out "$f"; exit 0; fi
    if [ -f "$f" ] && [[ "$f" == *.zip ]]; then
      t="$(mktemp -d)"
      if command -v ditto >/dev/null 2>&1; then ditto -x -k "$f" "$t" 2>/dev/null || continue; else unzip -q "$f" -d "$t" 2>/dev/null || continue; fi   # ويندوز: unzip حق Git Bash
      p="$(find "$t" -maxdepth 3 -path '*/ملفات لكلود/install.sh' -print -quit)"
      [ -n "$p" ] && { out "$(dirname "$(dirname "$p")")"; exit 0; }
    fi
  done < <(ls -td "$d"/*"استوديو المونتاج"* 2>/dev/null)
done
echo none; exit 14
