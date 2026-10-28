#!/bin/bash
# install.sh — يركّب «B Studio» و«مهارة المونتاج» على هذا الجهاز (ماك، أو ويندوز من Git Bash): ينسخ المجلدين اللي جنبه إلى مهارات كلود (~/.claude/skills).
#   كلود يشغّله لما يقول المستخدم «ركّب B Studio» أو «حدّث الاستوديو»:   bash "<هذا المجلد>/install.sh"
#   ما ينزّل شي من النت وما يحذف شي: النسخة القديمة من أي وحدة منهم تروح لسلة المهملات (ويندوز: لمجلد «edit-studio-old» ببيت المستخدم).
#   والدليل اللي جنب هالمجلد ينحط على سطح المكتب (القديم يروح مع النسخ القديمة).
#   وبعد المهارتين يسجّل المكوّن الإضافي لمحادثات Claude Code (سوق edit-studio داخل مجلد المهارة)، ولو ما قدر يطبع الأمرين للمستخدم.
#   يطبع سطر لكل مهارة (✓ ركّبتها · ↺ حدّثتها · = نفسها) وآخر سطر وين يكمّل كلود. أي ✗ = وقف، والخروج 1.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) WIN=1 ;; *) WIN=0 ;; esac
# ويندوز ما له ~/.Trash، وسلة المحذوفات ما تنوصل من هنا بأمان: القديم ينتقل لمجلد ظاهر يحذفه المستخدم متى شاء
if [ "$WIN" = 1 ]; then TRASH="${STUDIO_TRASH:-$HOME/edit-studio-old}"; BIN="مجلد النسخ القديمة ($TRASH)"; else TRASH="$HOME/.Trash"; BIN="سلة المهملات"; fi
# WSL (لينكس داخل ويندوز): الاستوديو ما يشتغل منه، فنوقف برسالة واضحة بدل ما يفشل التركيب بنصه
if [ "$WIN" = 0 ] && [ "$(uname -s)" != Darwin ] && { [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; }; then
  echo "✗ هذي الطرفية WSL (لينكس داخل ويندوز)، والاستوديو ما يشتغل منها. شغّل Claude Code من Git Bash (Git for Windows) على ويندوز نفسه، وأعد التركيب."
  exit 1
fi
# ويندوز: سطح المكتب الحقيقي من ويندوز نفسه (قد يكون داخل OneDrive أو باسم عربي)، مو بالضرورة ~/Desktop
desk_dir(){
  if [ -n "${STUDIO_DESKTOP:-}" ]; then printf '%s' "$STUDIO_DESKTOP"; return; fi
  # (HOME غير بيت المستخدم الحقيقي، مثل تجربة؟ نبقى على HOME)
  if [ "$WIN" = 1 ] && command -v powershell.exe >/dev/null 2>&1 && [ "$(printenv USERPROFILE 2>/dev/null | tr '[:upper:]\\' '[:lower:]/')" = "$(cygpath -w "$HOME" 2>/dev/null | tr '[:upper:]\\' '[:lower:]/')" ]; then
    local d; d="$(powershell.exe -NoProfile -Command "[Environment]::GetFolderPath('Desktop')" 2>/dev/null | tr -d '\r')"
    if [ -n "$d" ]; then command -v cygpath >/dev/null 2>&1 && d="$(cygpath -u "$d" 2>/dev/null || printf '%s' "$d")"; [ -d "$d" ] && { printf '%s' "$d"; return; }; fi
  fi
  printf '%s' "$HOME/Desktop"      # ماك (uname Darwin) ولينكس، وويندوز لو ما انعرف المجلد
}
STAMP="$(date +%Y-%m-%d-%H%M%S)"
mkdir -p "$DEST" "$TRASH"

# ملفات يكتبها Finder وExplorer بالمجلد (desktop.ini وThumbs.db) ما تُحسب فرقاً
same(){ diff -rq -x .DS_Store -x __pycache__ -x desktop.ini -x Thumbs.db -x ehthumbs.db "$1" "$2" >/dev/null 2>&1; }

# من النسخة التجريبية الأولى (كان اسمها غير): يوقف الاستوديو القديم، ينقل مجلد البيانات بمشاريعه للاسم الجديد
# ويخلي مكانه اختصار له (أي مسار قديم يظل يشتغل)، والمهارتين وتطبيق سطح المكتب بأسمائهم القديمة لسلة المهملات.
OLD_DATA="$HOME/Documents/video-editor-bassam"; NEW_DATA="${VEB_HOME:-$HOME/Documents/video-edit}"   # mac-only: the first version was Mac only (used when WIN=0)
if [ "$WIN" = 0 ] && [ -d "$OLD_DATA" ] && [ ! -L "$OLD_DATA" ] && [ ! -e "$NEW_DATA" ]; then   # النسخة الأولى كانت للماك بس
  OLD_START="$OLD_DATA/studio/app/studio/start.mjs"
  if [ -f "$OLD_START" ]; then
    for n in "$(command -v node 2>/dev/null)" /opt/homebrew/bin/node /usr/local/bin/node; do
      [ -n "$n" ] && [ -x "$n" ] && { "$n" "$OLD_START" --stop >/dev/null 2>&1 || true; break; }
    done
  fi
  mv "$OLD_DATA" "$NEW_DATA" && ln -s "$NEW_DATA" "$OLD_DATA"   # mac-only: the first version was Mac only (WIN=0 above)
  echo "→ مشاريعك انتقلت للمجلد الجديد: $NEW_DATA"
fi
# ويندوز من 0.9.6: البيانات كانت في المستندات (Documents/video-edit)، ومن 1.0.0 ممكن تصير C:/EditStudio (اسم مستخدم بالعربي أو
# المستندات في OneDrive: veb_default في _common.sh)، فمشاريعه القديمة اختفت من الاستوديو. القرار من _common.sh (old_homes وold_plan):
# move: الجديد مو موجود، فالمجلد كله ينتقل. merge: الجديد موجود بلا مشاريع، فتنتقل المشاريع والمقاطع المعتمدة بس. keep: الجديد فيه مشاريع
# فما نلمس شي (studio.sh list يقول وين القديم). قبلها نوقف الاستوديو القديم بأمره هو (start.mjs --stop) وما نوقف شي غيره.
# نفس القرص: mv. قرص ثاني: نسخة نتأكد إنها كاملة، والقديم يروح لمجلد النسخ القديمة. ما ينحذف شي
COMMON="$HERE/edit-studio/scripts/_common.sh"
if [ "$WIN" = 1 ] && [ -f "$COMMON" ] && ! grep -q $'\r' "$COMMON"; then
  drive_of(){ local w; w="$(cygpath -w "$1" 2>/dev/null || printf '%s' "$1")"; case "$w" in [A-Za-z]:*) printf '%s' "${w%%:*}" | tr '[:upper:]' '[:lower:]' ;; esac; }
  winpath(){ cygpath -w "$1" 2>/dev/null || printf '%s' "$1"; }
  # نسخة تنحط باسم مؤقت وتتسمّى بعد ما تطلع مطابقة، فما يبقى نص مشروع باسمه الحقيقي
  copy_in(){
    if cp -R "$1" "$2.copying" 2>/dev/null && same "$1" "$2.copying" && mv "$2.copying" "$2"; then return 0; fi
    [ -e "$2.copying" ] && mv "$2.copying" "$TRASH/$(basename "$2") نسخة ناقصة $STAMP" 2>/dev/null
    return 1
  }
  PLANS="$(bash -c '. "$1" >/dev/null 2>&1; old_homes | while IFS= read -r o; do printf "%s|%s|%s\n" "$(old_plan "$o" "$VEB")" "$o" "$VEB"; done' _ "$COMMON" 2>/dev/null || true)"
  while IFS='|' read -r what old new; do
    case "$what" in move|merge) ;; *) continue ;; esac
    ostart="$old/studio/app/studio/start.mjs"
    if [ -f "$ostart" ] && command -v node >/dev/null 2>&1; then
      STUDIO_DATA="$(cygpath -m "$old/studio" 2>/dev/null || printf '%s' "$old/studio")" node "$(cygpath -m "$ostart" 2>/dev/null || printf '%s' "$ostart")" --stop >/dev/null 2>&1 || true
    fi
    d1="$(drive_of "$old")"; one_drive=0
    [ -n "$d1" ] && [ "$d1" = "$(drive_of "$new")" ] && one_drive=1
    ok=1; done_line="→ مشاريعك القديمة انتقلت للمجلد الجديد: $(winpath "$new")"
    if [ "$what" = move ]; then
      mkdir -p "$(dirname "$new")" 2>/dev/null || true
      if [ "$one_drive" = 1 ]; then mv "$old" "$new" 2>/dev/null || ok=0
      elif copy_in "$old" "$new"; then
        mv "$old" "$TRASH/video-edit قديم $STAMP" 2>/dev/null && done_line="${done_line}، والمجلد القديم في $BIN"
      else ok=0; fi
      # إعدادات الاستوديو تحفظ مساراته كاملة (المشاريع، المعتمدة، التصوير): اللي تحت المجلد القديم تصير تحت الجديد
      if [ "$ok" = 1 ] && [ -f "$new/studio/home/prefs.json" ] && command -v node >/dev/null 2>&1; then
        node -e 'const fs=require("fs"),[f,o,n]=process.argv.slice(1),sl=(p)=>p.replace(/\\/g,"/").replace(/\/+$/,""),O=sl(o),N=sl(n);
const fix=(v)=>{if(typeof v!=="string")return v;const s=sl(v),k=s.toLowerCase(),ok=O.toLowerCase();return k===ok||k.startsWith(ok+"/")?N+s.slice(O.length):v;};
const walk=(x)=>Array.isArray(x)?x.map(walk):x&&typeof x==="object"?Object.fromEntries(Object.entries(x).map(([k,v])=>[k,walk(v)])):fix(x);
const t=fs.readFileSync(f,"utf8").replace(/^\uFEFF/,"");fs.writeFileSync(f,JSON.stringify(walk(JSON.parse(t)),null,1)+"\n");' \
          "$(cygpath -m "$new/studio/home/prefs.json" 2>/dev/null || printf '%s' "$new/studio/home/prefs.json")" \
          "$(cygpath -m "$old" 2>/dev/null || printf '%s' "$old")" "$(cygpath -m "$new" 2>/dev/null || printf '%s' "$new")" >/dev/null 2>&1 || true
      fi
    else
      for sub in studio/projects projects studio/approved; do
        [ -d "$old/$sub" ] || continue
        mkdir -p "$new/$sub" 2>/dev/null || true
        for e in "$old/$sub"/*; do                  # المخفي (.mohrer) يبقى مكانه
          [ -e "$e" ] || continue
          t="$new/$sub/$(basename "$e")"
          [ -e "$t" ] && continue
          if [ "$one_drive" = 1 ]; then mv "$e" "$t" 2>/dev/null || ok=0
          else copy_in "$e" "$t" || ok=0; fi
        done
      done
      # قرص ثاني: المشاريع انتسخت، فالقديم كله لمجلد النسخ القديمة (نفس القرص: باقيه أدوات ونسخة الاستوديو القديمة، يبقى مكانه)
      if [ "$ok" = 1 ] && [ "$one_drive" = 0 ]; then
        mv "$old" "$TRASH/video-edit قديم $STAMP" 2>/dev/null && done_line="${done_line}، والمجلد القديم في $BIN"
      fi
    fi
    if [ "$ok" = 1 ]; then echo "$done_line"
    else echo "! ما قدرت أنقل كل مشاريعك القديمة من $(winpath "$old"): سكّر الاستوديو وأي برنامج فاتح ملف منها، وأعد التركيب"; fi
  done <<< "$PLANS"
fi
for old in bassam-studio video-editor-bassam; do
  if [ -e "$DEST/$old" ] || [ -L "$DEST/$old" ]; then
    chmod -R u+w "$DEST/$old" 2>/dev/null || true
    mv "$DEST/$old" "$TRASH/$old قديمة $STAMP"
    echo "↺ $old: الاسم القديم، راح ل$BIN"
  fi
done
if [ -d "$HOME/Desktop/Bassam Studio.app" ]; then   # mac-only: the first version's app, a Mac app
  mv "$HOME/Desktop/Bassam Studio.app" "$TRASH/Bassam Studio قديم $STAMP.app"
  echo "↺ تطبيق سطح المكتب القديم راح لسلة المهملات (الجديد ينسوّى بالتركيب)"
fi

for name in video-edit edit-studio; do
  src="$HERE/$name"; dst="$DEST/$name"
  [ -f "$src/SKILL.md" ] || { echo "✗ $name ناقصة من الملف: نزّل «B Studio» من جديد"; exit 1; }
  # git على ويندوز يحوّل نهايات الأسطر إلى CRLF عند النسخ (autocrlf)، فتنكسر السكربتات وبصمات الملفات
  if grep -rlI $'\r' "$src" --include='*.sh' >/dev/null 2>&1; then
    echo "✗ $name: ملفاتها نهايات أسطرها CRLF (git حوّلها عند النسخ). انسخ المستودع من جديد بـ: git clone -c core.autocrlf=false <الرابط> ، أو نزّل الملف المضغوط بدل النسخ"
    exit 1
  fi
  if [ -e "$dst" ] && same "$src" "$dst"; then echo "= $name: نفس النسخة اللي عنده"; continue; fi
  done_msg="✓ $name: ركّبتها"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    chmod -R u+w "$dst" 2>/dev/null || true
    mv "$dst" "$TRASH/$name قديمة $STAMP" || { echo "✗ $name: ما قدرت أنقل النسخة القديمة. سكّر أي طرفية أو محرر أو برنامج فاتح شي داخل $dst وأعد التركيب"; exit 1; }
    done_msg="↺ $name: حدّثتها (القديمة في $BIN)"
  fi
  if [ "$WIN" = 1 ]; then cp -R "$src" "$dst"; else ditto --noqtn "$src" "$dst"; fi
  xattr -cr "$dst" 2>/dev/null || true
  same "$src" "$dst" || { echo "✗ $name: النسخ ما كمل"; exit 1; }
  echo "$done_msg"
done
# الدليل: ينحط على سطح المكتب، والقديم يروح مع النسخ القديمة (فكل تحديث يجي بدليله)
GUIDE="$HERE/../دليل B Studio.pdf"; DESK="$(desk_dir)"
if [ -f "$GUIDE" ] && [ -d "$DESK" ]; then
  G="$DESK/دليل B Studio.pdf"
  if [ -f "$G" ] && cmp -s "$GUIDE" "$G"; then echo "= الدليل: نفسه اللي على سطح المكتب"
  else
    gmsg="✓ الدليل: على سطح المكتب («دليل B Studio»)"
    if [ -e "$G" ]; then mv "$G" "$TRASH/دليل B Studio قديم $STAMP.pdf"; gmsg="↺ الدليل: حدّثته على سطح المكتب (القديم في $BIN)"; fi
    if cp "$GUIDE" "$G" 2>/dev/null; then echo "$gmsg"; else echo "! الدليل ما انحط على سطح المكتب، تلقاه بصفحة المستودع"; fi
  fi
fi
# الاسم القديم (قبل 1.0.3): «استوديو المونتاج» وتطبيقه «Edit Studio». الدليل القديم والتطبيق القديم يروحون مع النسخ القديمة،
# والتطبيق الجديد «B Studio» ينسوّى بالتركيب (setup.sh)
if [ -d "$DESK" ]; then
  OG="$DESK/دليل استوديو المونتاج.pdf"
  [ -f "$OG" ] && mv "$OG" "$TRASH/دليل استوديو المونتاج قديم $STAMP.pdf" && echo "↺ الدليل بالاسم القديم راح ل$BIN"
  for oa in "$DESK/Edit Studio.app" "$DESK/Edit Studio.lnk"; do
    [ -e "$oa" ] || continue
    mv "$oa" "$TRASH/$(basename "$oa" | sed "s/^Edit Studio/Edit Studio قديم $STAMP/")" && echo "↺ تطبيق سطح المكتب بالاسم القديم راح ل$BIN (الجديد «B Studio» ينسوّى بالتركيب)"
  done
fi
# المكوّن الإضافي لمحادثات Claude (plugin): داخل مجلد المهارة سوق صغير اسمه edit-studio فيه المكوّن edit-studio،
# يخلّي أي محادثة من Claude Code تعدّل المقطع المفتوح بالاستوديو بأدواته. نسجّل السوق من المجلد اللي ركّبناه ونركّب المكوّن.
# المكوّن يقرا من المجلد نفسه، فالتحديث (اللي يشغّل هذا الملف من جديد) يكفي، وإعادة التشغيل ما تضر.
# لو claude مو موجود أو رفض الأمر، نطبع الأمرين ويشغّلهم المستخدم بنفسه.
PLUG="$DEST/edit-studio"
# ويندوز: claude برنامج ويندوز عادي، ما يفهم /c/Users/... (مسار Git Bash)؛ ننطيه C:/Users/... (cygpath -m)، وللطباعة C:\Users\... لأن المستخدم قد يشغّله من PowerShell
PLUG_ARG="$PLUG"; PLUG_SHOW="$PLUG"
if [ "$WIN" = 1 ] && command -v cygpath >/dev/null 2>&1; then PLUG_ARG="$(cygpath -m "$PLUG")"; PLUG_SHOW="$(cygpath -w "$PLUG")"; fi
if [ -f "$PLUG/.claude-plugin/marketplace.json" ]; then
  if command -v claude >/dev/null 2>&1 \
     && claude plugin marketplace add "$PLUG_ARG" >/dev/null 2>&1 \
     && claude plugin install edit-studio@edit-studio >/dev/null 2>&1; then
    echo "✓ المكوّن الإضافي: جاهز (أي محادثة من Claude Code تقدر تعدّل المقطع المفتوح بالاستوديو؛ ابدأ محادثة جديدة)"
  else
    echo "! المكوّن الإضافي (لمحادثات Claude Code) ما انركّب من هنا. شغّل هذين الأمرين بنفسك بالطرفية:"
    echo "    claude plugin marketplace add \"$PLUG_SHOW\""
    echo "    claude plugin install edit-studio@edit-studio"
  fi
fi
# Codex: نفس أدوات الاستوديو لمحادثة Codex (codex mcp add). يشتغل فقط لو Codex موجود، ويعيد التسجيل عند كل تحديث ليلحق المسار الجديد.
# لو رفض الأمر نطبعه ويشغّله المستخدم بنفسه. ما نلمس شي غير خادم اسمه edit-studio.
LAUNCH="$PLUG/plugins/edit-studio/mcp/studio.mjs"
if [ -f "$LAUNCH" ]; then
  CODEX_BIN="${STUDIO_CODEX:-}"
  if [ -z "$CODEX_BIN" ]; then
    if command -v codex >/dev/null 2>&1; then CODEX_BIN="codex"
    elif [ -x /Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex ]; then CODEX_BIN="/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"; fi   # mac-only: Codex inside the ChatGPT app
  fi
  if [ -n "$CODEX_BIN" ]; then
    LAUNCH_ARG="$LAUNCH"; LAUNCH_SHOW="$LAUNCH"
    if [ "$WIN" = 1 ] && command -v cygpath >/dev/null 2>&1; then LAUNCH_ARG="$(cygpath -m "$LAUNCH")"; LAUNCH_SHOW="$(cygpath -w "$LAUNCH")"; fi
    "$CODEX_BIN" mcp remove edit-studio >/dev/null 2>&1 || true
    if "$CODEX_BIN" mcp add edit-studio -- node "$LAUNCH_ARG" >/dev/null 2>&1; then
      echo "✓ Codex: جاهز (أي محادثة من Codex تقدر تعدّل المقطع المفتوح بالاستوديو؛ ابدأ محادثة جديدة)"
    else
      echo "! Codex ما انربط من هنا. شغّل هذا الأمر بنفسك بالطرفية:"
      echo "    codex mcp add edit-studio -- node \"$LAUNCH_SHOW\""
    fi
  fi
fi
echo "التالي لكلود: اقرأ $DEST/edit-studio/SKILL.md ونفّذه من الخطوة 1 (المستخدم طلب التركيب)."
