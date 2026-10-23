#!/bin/bash
# montage.sh — مهارة المونتاج عند المستخدم مقارنةً بالنسخة اللي تجي مع الاستوديو (في ملف «استوديو المونتاج» نفسه، ويركّبها install.sh).
#   الاستوديو ما يحمل نسخة منها (حد كلود: 200 ملف للمهارة)؛ يحمل بصمتها بس (montage-versions.json).
#   bash montage.sh check <مجلد مهارة المونتاج>   يطبع ويخرج: same 0 (نفس اللي جت معه) · older 12 (أقدم)
#                                                  · other 13 (نسخة غيرها: اتركها) · missing 14 (ما فيه SKILL.md)
#   bash montage.sh print <مجلد>   البصمة (نفس tools/montage-print.mjs)
set -u
source "$(dirname "$0")/_common.sh"
INFO="$PKG_DIR/montage-versions.json"

# desktop.ini وThumbs.db وehthumbs.db يكتبها Explorer فجأة في المجلد، فما تُحسب (SS-23)
# shasum على الماك؛ على ويندوز (Git Bash) قد لا يوجد، وsha256sum يطبع نفس السطر
if command -v shasum >/dev/null 2>&1; then SHA=(shasum -a 256); else SHA=(sha256sum); fi
print(){
  (cd "$1" && find . \( -name __pycache__ -o -name node_modules \) -prune -o -type f ! -name .DS_Store ! -iname desktop.ini ! -iname Thumbs.db ! -iname ehthumbs.db ! -name '*.pyc' -print0 \
    | LC_ALL=C sort -z | xargs -0 "${SHA[@]}" | /usr/bin/sed -E 's/^([0-9a-f]{64}) [ *]/\1  /' | "${SHA[@]}" | cut -c1-16)   # sha256sum على ويندوز يكتب «*» قبل الاسم
}
# البصمات من الملف: current ثم older (سطر لكل وحدة)
prints(){ /usr/bin/sed -n "s/.*\"$1\": *\[*\([^]]*\)\]*.*/\1/p" "$INFO" | tr -d '" ' | tr ',' '\n' | /usr/bin/grep -v '^$'; }

case "${1:-}" in
  print) [ -d "${2:-}" ] || { echo "missing"; exit 14; }; print "$2" ;;
  check)
    [ -f "${2:-}/SKILL.md" ] || { echo "missing"; exit 14; }
    [ -f "$INFO" ] || { echo "other"; exit 13; }
    p="$(print "$2")"
    if prints current | /usr/bin/grep -qx "$p"; then echo "same"; exit 0; fi
    if prints older | /usr/bin/grep -qx "$p"; then echo "older"; exit 12; fi
    echo "other"; exit 13 ;;
  *) echo "usage: bash montage.sh check <dir> | print <dir>"; exit 1 ;;
esac
