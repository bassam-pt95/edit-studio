#!/bin/bash
# update.sh — يحدّث «استوديو المونتاج» ومهارة المونتاج من المستودع على GitHub (ماك، أو ويندوز من Git Bash).
#   bash update.sh           ← ينزّل آخر نسخة ويشغّل install.sh حقها (القديمة تروح لسلة المهملات، وعلى ويندوز لمجلد «edit-studio-old» ببيت المستخدم)، وآخر سطر وين يكمّل كلود
#                              (install.sh حقها يسجّل المكوّن الإضافي لمحادثات Claude Code ويركّبه، ولو ما قدر يطبع الأمرين للمستخدم)
#   bash update.sh --check   ← بس يقارن: «same <النسخة>» أو «newer <اللي عنده> <الجديدة>»
#   خروج 0 تمام · 15 ما فيه نت أو المستودع ما ينوصل · 16 النسخة المنزّلة ناقصة. مشاريع المستخدم وإعداداته ما تنلمس.
set -u
. "$(dirname "$0")/_common.sh"
REPO="${STUDIO_REPO:-https://github.com/bassam-pt95/edit-studio}"
RAW="${STUDIO_REPO_RAW:-https://raw.githubusercontent.com/bassam-pt95/edit-studio/main}"
TARBALL="${STUDIO_TARBALL:-$REPO/archive/refs/heads/main.tar.gz}"
FOR_ENC="%D9%85%D9%84%D9%81%D8%A7%D8%AA%20%D9%84%D9%83%D9%84%D9%88%D8%AF"     # «ملفات لكلود» بترميز الروابط
# ويندوز: curl حق Git for Windows (Schannel) يفحص إلغاء الشهادة، وبعض مضادات الفيروسات والبروكسي تمنع الفحص فيفشل بلا سبب واضح.
# --ssl-revoke-best-effort يخلّيه يكمّل لو ما قدر يوصل لخادم الإلغاء (الشهادة نفسها تنفحص). والخطأ ينطبع ولا ينخفي
CURL_X=(); [ "$OS" = win ] && CURL_X=(--ssl-revoke-best-effort)
ver_of(){ sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" 2>/dev/null | head -1; }
CUR="$(ver_of "$PKG_DIR/manifest.json")"

if [ "${1:-}" = "--check" ]; then
  T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT
  curl -fsSL ${CURL_X[@]+"${CURL_X[@]}"} --max-time 30 "$RAW/$FOR_ENC/edit-studio/manifest.json" -o "$T/m.json" 2>"$T/curl.err" || { echo "ما قدرت أوصل للمستودع: تأكد من النت وجرّب بعد شوي."; [ "$OS" = win ] && tail -n 2 "$T/curl.err"; exit 15; }
  NEW="$(ver_of "$T/m.json")"
  [ -n "$NEW" ] || { echo "ما قدرت أقرأ رقم النسخة من المستودع."; exit 15; }
  if [ "$NEW" = "$CUR" ]; then echo "same $CUR"; else echo "newer ${CUR:-?} $NEW"; fi
  exit 0
fi

T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT
echo "أنزّل آخر نسخة من $REPO …"
curl -fsSL ${CURL_X[@]+"${CURL_X[@]}"} --max-time 600 "$TARBALL" -o "$T/studio.tar.gz" 2>"$T/curl.err" || { echo "ما قدرت أنزّل النسخة: تأكد من النت وجرّب بعد شوي."; [ "$OS" = win ] && tail -n 2 "$T/curl.err"; exit 15; }
tar -xzf "$T/studio.tar.gz" -C "$T" 2>/dev/null || { echo "الملف المنزّل ما انفك."; exit 16; }
INS="$(find "$T" -maxdepth 3 -path '*/ملفات لكلود/install.sh' -print -quit)"
[ -n "$INS" ] && [ -f "$(dirname "$INS")/edit-studio/SKILL.md" ] || { echo "النسخة المنزّلة ناقصة (ما فيها ملف التركيب)."; exit 16; }
NEW="$(ver_of "$(dirname "$INS")/edit-studio/manifest.json")"
echo "النسخة اللي عندك: ${CUR:-?} · النسخة بالمستودع: ${NEW:-?}"
# التركيب ينقل مجلد المهارة القديم (وهذا السكربت داخله) للسلة: نكمّل من سكربت صغير بالمجلد المؤقت، وهو ينظّف وراه
printf '%s\n' 'bash "$1"; rc=$?; rm -rf "${2:?}" 2>/dev/null || true; exit $rc' > "$T/run.sh"
trap - EXIT
cd "$HOME" 2>/dev/null || cd /
exec bash "$T/run.sh" "$INS" "$T"
