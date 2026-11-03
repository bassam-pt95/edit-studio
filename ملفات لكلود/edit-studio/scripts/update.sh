#!/bin/bash
# update.sh — يحدّث «B Studio» ومهارة المونتاج من آخر إصدار بالمستودع على GitHub (ماك، أو ويندوز من Git Bash).
#   bash update.sh           ← يسأل الاستوديو أول: يصدّر أو يبني؟ يوقف بلا ما ينزّل شي (خروج 17). بعدها ينزّل ملف آخر إصدار
#                              بعلامته (tag)، ويطابق بصمته (SHA-256) المنشورة مع الإصدار قبل ما يشغّل منه أي شي، ويشغّل install.sh
#                              حقه (القديمة تروح لسلة المهملات، وعلى ويندوز لمجلد ~/edit-studio-old)، ثم setup.sh --install حق
#                              النسخة الجديدة (الاستوديو نفسه وأدواته). آخر سطر للمستخدم نفسه.
#   bash update.sh --check   ← بس يقارن: «same <النسخة>» أو «newer <اللي عنده> <الجديدة>»
#   الإصدار (tools/release-assets.mjs): edit-studio-<النسخة>.tar.gz وSHA256SUMS (سطر واحد: «<البصمة>  edit-studio-<النسخة>.tar.gz»).
#   آخر إصدار: <الإصدارات>/latest/download/SHA256SUMS، وملفه: <الإصدارات>/download/v<النسخة>/<الملف> (بالعلامة، مو «آخر شي»).
#   خروج 0 تمام · 15 ما فيه نت أو المستودع ما ينوصل · 16 النسخة المنزّلة ناقصة أو غير اللي يقولها الإصدار · 17 الاستوديو مشغول
#   (ما تنزّل شي) · 18 الملف ما يطابق بصمته (ما تشغّل منه شي) · 11 و12 من setup.sh (ويندوز: سكّر كلود وافتحه · الاستوديو مشغول).
#   مشاريع المستخدم وإعداداته ما تنلمس. (مراجعة 1.0.19: S9 الإصدار الموقّع ببصمته، I4 لا يوقف شغل، I5 يكمّل التركيب)
set -u
. "$(dirname "$0")/_common.sh"
REPO="${STUDIO_REPO:-https://github.com/bassam-pt95/edit-studio}"
RELEASES="${STUDIO_RELEASES:-$REPO/releases}"
# ويندوز: curl حق Git for Windows (Schannel) يفحص إلغاء الشهادة، وبعض مضادات الفيروسات والبروكسي تمنع الفحص فيفشل بلا سبب واضح.
# --ssl-revoke-best-effort يخلّيه يكمّل لو ما قدر يوصل لخادم الإلغاء (الشهادة نفسها تنفحص). والخطأ ينطبع ولا ينخفي
ver_of(){ sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" 2>/dev/null | head -1; }
CUR="$(ver_of "$PKG_DIR/manifest.json")"
# a copy given by hand before a release (a test copy) can be newer than the repository: an update never goes back
older(){ [ -n "$1" ] && [ -n "$2" ] && [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$1" ]; }
T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT
ERR=/dev/null; [ "$OS" = win ] && ERR="$T/curl.err"   # ويندوز: خطا curl يبان (curl_why)، مو يختفي
# SHA256SUMS حق آخر إصدار ← SHA وFILE وNEW (النسخة من اسم الملف)
latest(){
  curl -fsSL $CURL_TLS --max-time 30 "$RELEASES/latest/download/SHA256SUMS" -o "$T/SHA256SUMS" 2>"$ERR" || { echo "ما قدرت أوصل للمستودع: تأكد من النت وجرّب بعد شوي."; curl_why "$ERR"; exit 15; }
  read -r SHA FILE NEW <<< "$(sed -n 's/^\([0-9a-f]\{64\}\) [ *]\(edit-studio-\([0-9][0-9.]*[0-9]\)\.tar\.gz\)[[:space:]]*$/\1 \2 \3/p' "$T/SHA256SUMS" | head -1)"
  [ -n "${NEW:-}" ] || { echo "ما قدرت أقرأ رقم النسخة من المستودع."; exit 15; }
}

if [ "${1:-}" = "--check" ]; then
  latest
  if [ "$NEW" = "$CUR" ] || older "$NEW" "$CUR"; then echo "same $CUR"; else echo "newer ${CUR:-?} $NEW"; fi
  exit 0
fi

# ── الاستوديو شغّال يصدّر أو يبني أو المونتير يشتغل؟ ما ننزّل شي ولا نوقف شي (start.mjs اللي جنب هالسكربت: نفس نسخته)
NODE="$(find_node 2>/dev/null)" || NODE=""
if [ -n "$NODE" ] && [ -f "$PKG_DIR/studio/start.mjs" ]; then
  BUSY="$("$NODE" "$PKG_DIR/studio/start.mjs" --busy 2>/dev/null)"
  if [ $? -eq 4 ]; then
    printf '%s\n' "$BUSY" | sed -n '2,$p'
    echo "ما حدّثت شي ولا وقّفت شي. قل «حدّث الاستوديو» بعد ما يخلص."
    exit 17
  fi
fi

latest
echo "النسخة اللي عندك: ${CUR:-?} · آخر إصدار بالمستودع: $NEW"
if older "$NEW" "$CUR"; then echo "عندك نسخة أحدث (${CUR}) من اللي بالمستودع (${NEW}): ما فيه تحديث، وما أرجّعك لنسخة أقدم."; exit 0; fi
echo "أنزّل الإصدار $NEW من $REPO …"
curl -fsSL $CURL_TLS --max-time 600 "$RELEASES/download/v$NEW/$FILE" -o "$T/$FILE" 2>"$ERR" || { echo "ما قدرت أنزّل النسخة: تأكد من النت وجرّب بعد شوي."; curl_why "$ERR"; exit 15; }
GOT="$(sha256_of "$T/$FILE")"
if [ "$GOT" != "$SHA" ]; then
  echo "الملف المنزّل ما يطابق بصمته المنشورة مع الإصدار (SHA-256)، فما شغّلت منه شي ولا تغيّر شي عندك. جرّب بعد شوي، ولو تكرر أرسل هالسطر لبسام:"
  echo "  $FILE: المنشورة $SHA · المنزّلة ${GOT:-؟}"
  exit 18
fi
echo "البصمة (SHA-256) مطابقة: $SHA"
mkdir -p "$T/x" && tar -xzf "$T/$FILE" -C "$T/x" 2>/dev/null || { echo "الملف المنزّل ما انفك."; exit 16; }
INS="$(find "$T/x" -maxdepth 3 -path '*/ملفات لكلود/install.sh' -print -quit)"
[ -n "$INS" ] && [ -f "$(dirname "$INS")/edit-studio/SKILL.md" ] || { echo "النسخة المنزّلة ناقصة (ما فيها ملف التركيب)."; exit 16; }
GOTV="$(ver_of "$(dirname "$INS")/edit-studio/manifest.json")"
[ "$GOTV" = "$NEW" ] || { echo "الملف المنزّل نسخته ${GOTV:-؟} والإصدار يقول $NEW: ما شغّلت منه شي."; exit 16; }
# التركيب ينقل مجلد المهارة القديم (وهذا السكربت داخله) للسلة (ويندوز: لمجلد ~/edit-studio-old): نكمّل من سكربت صغير بالمجلد المؤقت،
# وهو يشغّل install.sh ثم setup.sh --install حق المهارة الجديدة، ويكتب آخر سطر للمستخدم، وينظّف وراه
DEST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
cat > "$T/run.sh" <<'RUN'
INS="$1"; T="$2"; DEST="$3"; NEW="$4"
fin(){ rm -rf "${T:?}" 2>/dev/null || true; exit "$1"; }
bash "$INS" || { echo "❌ ما اكتمل تركيب المهارتين: النسخة اللي عندك باقية. قل «حدّث الاستوديو» مرة ثانية."; fin 1; }
bash "$DEST/edit-studio/scripts/setup.sh" --install; rc=$?
case $rc in
  0)  echo "✅ تحدّث B Studio إلى ${NEW}. افتحه من «B Studio» على سطح المكتب، ومشاريعك كما هي." ;;
  11) echo "تحدّثت المهارات إلى ${NEW}، وباقي خطوة: سكّر Claude وافتحه، وقل «حدّث الاستوديو» مرة ثانية يكمّل." ;;
  12) echo "تحدّثت المهارات إلى ${NEW}، والاستوديو نفسه يتحدّث بعد ما يخلص شغله: قل «حدّث الاستوديو» بعد ما يخلص." ;;
  *)  echo "تحدّثت المهارات إلى ${NEW}، وتثبيت الاستوديو ما اكتمل (الخروج ${rc}): قل «حدّث الاستوديو» مرة ثانية، ولو تكرر أرسل الأسطر اللي فوق لبسام." ;;
esac
fin $rc
RUN
trap - EXIT
cd "$HOME" 2>/dev/null || cd /
exec bash "$T/run.sh" "$INS" "$T" "$DEST" "$NEW"
