#!/bin/bash
# install.sh — يركّب «استوديو المونتاج» و«مهارة المونتاج» على هذا الجهاز (ماك، أو ويندوز من Git Bash): ينسخ المجلدين اللي جنبه إلى مهارات كلود (~/.claude/skills).
#   كلود يشغّله لما يقول المستخدم «ركّب استوديو المونتاج» أو «حدّث الاستوديو»:   bash "<هذا المجلد>/install.sh"
#   ما ينزّل شي من النت وما يحذف شي: النسخة القديمة من أي وحدة منهم تروح لسلة المهملات (ويندوز: لمجلد «edit-studio-old» ببيت المستخدم).
#   والدليل اللي جنب هالمجلد ينحط على سطح المكتب (القديم يروح مع النسخ القديمة).
#   يطبع سطر لكل مهارة (✓ ركّبتها · ↺ حدّثتها · = نفسها) وآخر سطر وين يكمّل كلود. أي ✗ = وقف، والخروج 1.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) WIN=1 ;; *) WIN=0 ;; esac
# ويندوز ما له ~/.Trash، وسلة المحذوفات ما تنوصل من هنا بأمان: القديم ينتقل لمجلد ظاهر يحذفه المستخدم متى شاء
if [ "$WIN" = 1 ]; then TRASH="${STUDIO_TRASH:-$HOME/edit-studio-old}"; BIN="مجلد النسخ القديمة ($TRASH)"; else TRASH="$HOME/.Trash"; BIN="سلة المهملات"; fi
STAMP="$(date +%Y-%m-%d-%H%M%S)"
mkdir -p "$DEST" "$TRASH"

same(){ diff -rq -x .DS_Store -x __pycache__ "$1" "$2" >/dev/null 2>&1; }

# من النسخة التجريبية الأولى (كان اسمها غير): يوقف الاستوديو القديم، ينقل مجلد البيانات بمشاريعه للاسم الجديد
# ويخلي مكانه اختصار له (أي مسار قديم يظل يشتغل)، والمهارتين وتطبيق سطح المكتب بأسمائهم القديمة لسلة المهملات.
OLD_DATA="$HOME/Documents/video-editor-bassam"; NEW_DATA="${VEB_HOME:-$HOME/Documents/video-edit}"
if [ "$WIN" = 0 ] && [ -d "$OLD_DATA" ] && [ ! -L "$OLD_DATA" ] && [ ! -e "$NEW_DATA" ]; then   # النسخة الأولى كانت للماك بس
  OLD_START="$OLD_DATA/studio/app/studio/start.mjs"
  if [ -f "$OLD_START" ]; then
    for n in "$(command -v node 2>/dev/null)" /opt/homebrew/bin/node /usr/local/bin/node; do
      [ -n "$n" ] && [ -x "$n" ] && { "$n" "$OLD_START" --stop >/dev/null 2>&1 || true; break; }
    done
  fi
  mv "$OLD_DATA" "$NEW_DATA" && ln -s "$NEW_DATA" "$OLD_DATA"
  echo "→ مشاريعك انتقلت للمجلد الجديد: $NEW_DATA"
fi
for old in bassam-studio video-editor-bassam; do
  if [ -e "$DEST/$old" ] || [ -L "$DEST/$old" ]; then
    chmod -R u+w "$DEST/$old" 2>/dev/null || true
    mv "$DEST/$old" "$TRASH/$old قديمة $STAMP"
    echo "↺ $old: الاسم القديم، راح ل$BIN"
  fi
done
if [ -d "$HOME/Desktop/Bassam Studio.app" ]; then
  mv "$HOME/Desktop/Bassam Studio.app" "$TRASH/Bassam Studio قديم $STAMP.app"
  echo "↺ تطبيق سطح المكتب القديم راح لسلة المهملات (الجديد ينسوّى بالتركيب)"
fi

for name in video-edit edit-studio; do
  src="$HERE/$name"; dst="$DEST/$name"
  [ -f "$src/SKILL.md" ] || { echo "✗ $name ناقصة من الملف: نزّل «استوديو المونتاج» من جديد"; exit 1; }
  if [ -e "$dst" ] && same "$src" "$dst"; then echo "= $name: نفس النسخة اللي عنده"; continue; fi
  done_msg="✓ $name: ركّبتها"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    chmod -R u+w "$dst" 2>/dev/null || true
    mv "$dst" "$TRASH/$name قديمة $STAMP"
    done_msg="↺ $name: حدّثتها (القديمة في $BIN)"
  fi
  if [ "$WIN" = 1 ]; then cp -R "$src" "$dst"; else ditto --noqtn "$src" "$dst"; fi
  xattr -cr "$dst" 2>/dev/null || true
  same "$src" "$dst" || { echo "✗ $name: النسخ ما كمل"; exit 1; }
  echo "$done_msg"
done
# الدليل: ينحط على سطح المكتب، والقديم يروح مع النسخ القديمة (فكل تحديث يجي بدليله)
GUIDE="$HERE/../دليل استوديو المونتاج.pdf"; DESK="${STUDIO_DESKTOP:-$HOME/Desktop}"
if [ -f "$GUIDE" ] && [ -d "$DESK" ]; then
  G="$DESK/دليل استوديو المونتاج.pdf"
  if [ -f "$G" ] && cmp -s "$GUIDE" "$G"; then echo "= الدليل: نفسه اللي على سطح المكتب"
  else
    gmsg="✓ الدليل: على سطح المكتب («دليل استوديو المونتاج»)"
    if [ -e "$G" ]; then mv "$G" "$TRASH/دليل استوديو المونتاج قديم $STAMP.pdf"; gmsg="↺ الدليل: حدّثته على سطح المكتب (القديم في $BIN)"; fi
    if cp "$GUIDE" "$G" 2>/dev/null; then echo "$gmsg"; else echo "! الدليل ما انحط على سطح المكتب، تلقاه بصفحة المستودع"; fi
  fi
fi
echo "التالي لكلود: اقرأ $DEST/edit-studio/SKILL.md ونفّذه من الخطوة 1 (المستخدم طلب التركيب)."
