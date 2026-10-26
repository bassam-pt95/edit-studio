#!/bin/bash
# ═══ المحرّك الثاني: ريموشن (تايم-لاين حي بدل رسم فريمات) ═══
#   ./04b_remotion.sh <work> setup            → يجهّز المشروع بمجلد الشغل ويربطه بمحرّك الرسم المشترك
#   ./04b_remotion.sh <work> engine           → ينزّل المحرّك المشترك (~400 ميقا، مرة وحدة لكل المقاطع) — بعد موافقته فقط
#   ./04b_remotion.sh <work> sync             → يحدّث البيانات والأصول فقط (بلا تنزيل)
#   ./04b_remotion.sh <work> studio [port]    → يفتح الاستوديو الحي
#   ./04b_remotion.sh <work> render [out.mp4] → يطلّع MP4 مباشرة (بلا فريمات)
# المشاهد تُكتب بـ<work>/Scenes.tsx — وينسخ للمشروع مع كل تشغيل (لا تعدّل نسخة remotion/src).
# المحرّك نسخة وحدة بمجلد بياناته: <VEB_HOME>/remotion-shared — و<work>/remotion/node_modules رابط له.
#   مجلد شغل قديم فيه node_modules حقيقي يُستخدم كما هو.
#   ويندوز: الرابط وصلة مجلد (junction) يسويها node؛ لو ما انربط (القرص مو NTFS محلي) يوقف بـexit 14.
case "$OSTYPE" in msys*|cygwin*) [ "$(command -v find)" = /usr/bin/find ] || export PATH="$HOME/bin:/mingw64/bin:/usr/bin:$PATH";; esac   # ويندوز: bash بلا login يبدا PATH بـSystem32: find حق ويندوز (ولو ادوات Git بالـPATH تجي بعدها)، وما فيه ~/bin حق python3؛ فلو find مو /usr/bin/find نحط ~/bin وادوات Git اول مثل login
set -e
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) export PYTHONUTF8=1 PYTHONIOENCODING=utf-8 ;; esac   # ويندوز: بايثون بـUTF-8 لا بترميز النظام
W="$(cd "$1" && pwd)"; CMD="${2:-setup}"; ARG="$3"
TPL="$(cd "$(dirname "$0")/remotion-template" && pwd)"
SK="$(cd "$(dirname "$0")" && pwd)"   # مجلد السكربتات
R="$W/remotion"
H="$HOME"; case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) [ -n "$USERPROFILE" ] && H="$(cygpath -u "$USERPROFILE")" ;; esac   # ويندوز: البيت من USERPROFILE مثل بايثون وnode، فمتغير HOME عام ما يقسم البيانات لمجلدين
VD="$H/Documents/video-edit"   # مجلد البيانات بلا VEB_HOME
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*)   # ويندوز: نفس قاعدة الاستوديو (platform.mjs dataHomeDefault و_common.sh و_paths.py/_paths.js):
  #   C:/EditStudio لو <البيت>/Documents/video-edit فيه حروف غير انجليزية او onedrive او /appdata/، او OneDrive ماخذ المستندات
  veb_default(){ local d="$H/Documents/video-edit" od
    if printf '%s' "$d" | LC_ALL=C grep -q '[^ -~]' || printf '%s' "$d" | grep -qiE 'onedrive|/appdata/'; then printf 'C:/EditStudio'; return; fi
    for od in "$OneDrive" "$OneDriveConsumer" "$OneDriveCommercial"; do [ -n "$od" ] && [ -d "$(cygpath -u "$od")/Documents" ] && { printf 'C:/EditStudio'; return; }; done
    printf '%s' "$d"; }
  [ -n "$VEB_HOME" ] || VD="$(veb_default)" ;; esac
SHARED="${VEB_HOME:-$VD}/remotion-shared"
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*)   # ويندوز: مسارات C:/ لبايثون وnode وffmpeg، فتشتغل حتى مع MSYS_NO_PATHCONV=1 او MSYS2_ARG_CONV_EXCL='*' (يوقفون تحويل /c/...)
  W="$(cygpath -m "$W")"; TPL="$(cygpath -m "$TPL")"; SK="$(cygpath -m "$SK")"; R="$W/remotion"; SHARED="$(cygpath -m "$SHARED")" ;; esac

engine_ready(){ [ -f "$SHARED/node_modules/remotion/package.json" ] && [ -f "$SHARED/node_modules/@remotion/cli/package.json" ]; }

install_engine(){
  engine_ready && { echo "محرّك الرسم منزّل من قبل: $SHARED"; return; }
  mkdir -p "$SHARED"
  cp "$TPL/../remotion-shared/package.json" "$TPL/../remotion-shared/package-lock.json" "$SHARED/"
  echo "⏬ تنزيل محرّك الرسم (~400 ميقا، مرة وحدة لكل المقاطع) بـ${SHARED}…"
  ( cd "$SHARED" && npm ci --no-audit --no-fund --loglevel=error && npx --no-install remotion browser ensure >/dev/null ) \
    || { echo "❌ فشل التنزيل"; exit 12; }
  echo "✅ المحرّك جاهز."
}

link_engine(){
  mkdir -p "$R"
  if [ -d "$R/node_modules" ] && [ ! -L "$R/node_modules" ] && [ -f "$R/node_modules/remotion/package.json" ]; then
    echo "مكتبات المشروع الخاصة موجودة — تُستخدم كما هي."; return; fi
  if ! engine_ready; then
    echo "⛔ محرّك الرسم غير منزّل بعد: ~400 ميقا مرة وحدة لكل المقاطع، بـ$SHARED"
    echo "   اطلب موافقة المستخدم على التنزيل، ثم شغّل: bash scripts/04b_remotion.sh \"$W\" engine"
    exit 13
  fi
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)   # ويندوز: وصلة مجلد (junction) — ما تحتاج صلاحية مدير
      [ -f "$R/node_modules/remotion/package.json" ] && return       # الوصلة شغّالة
      # node يسوي الوصلة ويتاكد منها (لا cmd mklink: Git Bash يقلب /J الى J:/). lstat بـnode يشوف الوصلة رابط:
      #   القديمة او المكسورة تنشال بـunlink (الرابط نفسه بس، المحرك ما ينلمس)، والمجلد الحقيقي بلا ريموشن ينشال مثل الماك.
      node -e 'const fs=require("fs"),p=require("path");const[t,l]=process.argv.slice(1);try{const s=fs.lstatSync(l);s.isSymbolicLink()?fs.unlinkSync(l):fs.rmSync(l,{recursive:true,force:true})}catch(e){if(e.code!=="ENOENT")throw e}fs.symlinkSync(t,l,"junction");fs.statSync(p.join(l,"remotion","package.json"))' \
        "$(cygpath -w "$SHARED/node_modules")" "$(cygpath -w "$R/node_modules")" \
        || { echo "❌ ما قدرت اربط محرك الرسم بمجلد الشغل (القرص لازم NTFS محلي): $R"; exit 14; } ;;
    *) # مجلد حقيقي بلا ريموشن = تنزيل قديم ما كمل — يُشال ويُربط بدله
       [ -d "$R/node_modules" ] && [ ! -L "$R/node_modules" ] && rm -rf "$R/node_modules"
       ln -sfn "$SHARED/node_modules" "$R/node_modules" ;;
  esac
}

# سطر اوامر ريموشن: npx remotion. ويندوز: npx يمر على remotion.cmd وcmd.exe، فمسار شغل فيه & او ^ ينقسم ويطيح
#   الاستوديو والرندر؛ node يشغل سكربت الـCLI نفسه (bin حق @remotion/cli) بدون cmd.exe.
#   و_loopback.cjs يخلي خوادم ريموشن على 127.0.0.1 بس: ريموشن يفتحها على كل الشبكات ('::')، فتطلع نافذة الجدار الناري
#   لـnode.exe باول رندر، ولو انسمح ينفتح المشروع للشبكة.
remotion_cli(){
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
      RCLI="$(node -p 'const d=process.argv[1],b=require(d+"/package.json").bin;require("path").join(d,typeof b==="string"?b:b.remotion)' "$(cygpath -m "$R/node_modules/@remotion/cli")" 2>/dev/null)" \
        || { echo "❌ ما لقيت سطر اوامر ريموشن (@remotion/cli) بـ$R/node_modules"; exit 13; }
      RUN=(node --require "$(cygpath -m "$SK/_loopback.cjs")" "$RCLI") ;;
    *) RUN=(npx remotion) ;;
  esac
}

sync_all(){
  mkdir -p "$R/src" "$R/public"
  # الوسطاء (.cutz444.mp4 و.remotion-*) بـC. ويندوز: النقطة ما تخبي الملف بالمستكشف، وملف مخفي ffmpeg -y ما يكتب فوقه،
  #   فتنحط بمجلد .cache مخفي. .cutz444.mp4 قديم بمجلد الشغل ينتقل له (mv يحفظ تاريخه، فما ينبني من جديد).
  C="$W"; case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) C="$W/.cache"; mkdir -p "$C"; attrib +h "$(cygpath -w "$C")" >/dev/null 2>&1 || true
    if [ -f "$W/.cutz444.mp4" ] && [ ! -f "$C/.cutz444.mp4" ]; then mv "$W/.cutz444.mp4" "$C/"; fi ;; esac
  # ملفات الهيكل: تُحدَّث دائماً ما عدا اللي يعدّله المستخدم
  for f in package.json tsconfig.json remotion.config.ts .gitignore README.md; do
    [ -f "$TPL/$f" ] && cp "$TPL/$f" "$R/$f"; done
  for f in index.ts Root.tsx Ad.tsx theme.ts font.ts stage.ts util.tsx Chrome.tsx Captions.tsx Outro.tsx Guides.tsx; do
    cp "$TPL/src/$f" "$R/src/$f"; done
  # المشاهد: المصدر الوحيد <work>/Scenes.tsx (الفواحص تقرأه من هنا) — ينسخ للمشروع بكل تشغيل.
  #   أول مرة ينسخ القالب الفاضي (وضع «قص وكابشن بس» يبقى فاضي كذا).
  [ -f "$W/Scenes.tsx" ] || cp "$TPL/src/Scenes.tsx" "$W/Scenes.tsx"
  cp "$W/Scenes.tsx" "$R/src/Scenes.tsx"
  # الأسلوب: <work>/style.json ← {"style": "simple" | "collage"} (الافتراضي simple)
  #   «documentary» و«board» انشالوا من المهارة: مجلد شغل قديم مكتوب فيه واحد منهم يكمّل بعُدّة الكولاج
  #   (بلا ./editorial ولا ./board).
  STYLE="$(python3 -c 'import json,os,sys;p=sys.argv[1];print(json.load(open(p,encoding="utf-8-sig")).get("style","simple") if os.path.exists(p) else "simple")' "$W/style.json")"
  case "$STYLE" in collage|documentary|board|vox) KIT=collage ;; *) KIT=simple ;; esac
  SD="$(cd "$(dirname "$0")/.." && pwd)/styles/$KIT"
  case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) SD="$(cygpath -m "$SD")" ;; esac   # ويندوز: مثل W فوق
  if [ -d "$SD/kit" ]; then cp "$SD"/kit/*.tsx "$R/src/"; fi
  if [ -d "$SD/assets" ]; then find "$SD/assets" -type f ! -name '*.md' -exec cp {} "$R/public/" \;; fi
  # أصول المقطع نفسه (صور Pexels · صوره · الكتاب): <work>/assets/*
  [ -d "$W/assets" ] && find "$W/assets" -type f -exec cp {} "$R/public/" \;
  # ويندوز: NTFS يفرق بين NFC وNFD (APFS لا)، فاسم عربي جاي من ماك او zip منه (ا + همزة منفصلة)
  #   ما يلقاه staticFile بالاسم اللي يكتبه Claude: كل ملف اسمه مو NFC بـpublic ياخذ اسمه NFC كمان (رابط صلب،
  #   او نسخة لو القرص ما يدعمه) ويبقى باسمه الاصلي، فـScenes.tsx يلقاه بالصيغتين مثل الماك.
  #   الا لو الاسم NFC له ملفه بـassets (صورة حطها Claude بويندوز بنفس الاسم): يبقى له
  case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) python3 - "$R/public" "$SD/assets" "$W/assets" <<'PY'
import os, sys, shutil, unicodedata
d, k = sys.argv[1], os.path.normcase   # NTFS ما يفرق بين الحروف الكبيرة والصغيرة
own = {}   # ملفات assets بالترتيب اللي ينسخها فيه find فوق (الكيت بلا .md، ثم المقطع)
for i, a in enumerate(sys.argv[2:]):
    for r, _, fs in os.walk(a):
        for x in fs:
            if i or not x.endswith(".md"): own[k(x)] = os.path.join(r, x)
for f in os.listdir(d):
    n = unicodedata.normalize("NFC", f)
    s, t = os.path.join(d, f), os.path.join(d, n)
    if n == f or not os.path.isfile(s): continue
    if k(n) in own:
        if os.path.exists(t) and os.path.samefile(s, t):   # رابط من مزامنة قديمة: cp كتب الملفين بنفس المكان
            os.remove(t); shutil.copy2(own[k(n)], os.path.join(d, os.path.basename(own[k(n)])))
            if k(f) in own: shutil.copy2(own[k(f)], s)
        continue
    if os.path.exists(t) and os.path.samefile(s, t): continue
    if os.path.exists(t): os.remove(t)   # نسخة قديمة من مزامنة سابقة
    try: os.link(s, t)
    except OSError: shutil.copy2(s, t)
PY
  ;; esac
  echo "الأسلوب: $STYLE"

  cp "$W/caps.json" "$R/src/caps.json"
  python3 - "$W" "$R" <<'PY'
import json, os, sys
W, R = sys.argv[1], sys.argv[2]
def rd(name, dflt):
    p = os.path.join(W, name)
    return json.load(open(p, encoding="utf-8-sig")) if os.path.exists(p) else dflt
caps  = json.load(open(os.path.join(W, "caps.json"), encoding="utf-8-sig"))
theme = rd("theme.json", {})
sfx   = rd("sfx.json", {})
proj = {
  "theme": {k: theme.get(k) for k in ("bg","ink","acc","clay","mut","sand","sky","warm","cream","font","fontDisplay","fontLocal","handle","faceAnchor","faceX","captionSize","captionWeight","captionMaxW","captionBottom","captionBottomWide","captionStyle","maxLines") if theme.get(k) is not None},
  "total": round(caps["total"], 3),
  "outro": float(sfx.get("outro", 0.0)),   # الافتراضي بلا كرت نهاية — المقطع يخلص على وجهه
  "sfx":   os.path.exists(os.path.join(W, "sfx.wav")),
  "stage": rd("stage.json", [{"s":0, "e":9999, "m":"FULL"}]),
  "outro_copy": rd("outro.json", {"line":"", "recap":[], "cta_top":"", "cta_word":"", "tail":""}),
  "guides": bool(rd("safe.json", {}).get("guides", False)),   # true → أدلّة المنطقة الآمنة بالاستوديو
  "rects": rd("rects.json", {}),
  "capMove": rd("capmove.json", []),                           # [[من, إلى, bottom]] — كابشن يتزحزح عن رقم مهم بلقطة                              # مستطيلات مخصّصة (من حارس الوجه)
  # إطار المقطع: theme.json ← frame (tall · wide · square) → المقاس، ووين وجهه بالعرضي (faceSide)
  "size": {"wide": [1920, 1080], "square": [1080, 1080]}.get(theme.get("frame"), [1080, 1920]),
  "faceSide": theme.get("faceSide", "right"),
}
# ملمس الخلفية: من هويته (bgStyle)، وهوية قديمة ما فيها المفتاح تاخذ «حبيبات». الاستوديو يقرأه من هنا لما يفتح المقطع.
proj["theme"]["bgStyle"] = theme.get("bgStyle") if theme.get("bgStyle") in ("grain", "lines", "dots", "both", "live") else "grain"
with open(os.path.join(R, "src", "project.json"), "w", encoding="utf-8") as f:
    json.dump(proj, f, ensure_ascii=False, indent=1)
print("project.json → المدة", proj["total"], "+ ختام", proj["outro"], "· مؤثرات:", "نعم" if proj["sfx"] else "لا")
PY
  [ -f "$W/cutz.mp4" ] && cp "$W/cutz.mp4" "$R/public/video.mp4"          # للمعاينة بالاستوديو
  # ⛔ القاعدة ٩٠ — الرندر يقرأ وسيطاً 4:4:4 لا المقصوص 4:2:0.
  #    مفكّك ريموشن (swscale) يفقد ‎-1.7 سطوع بفكّ 4:2:0، وصفراً بفكّ 4:4:4 — مقيس على مقطع حقيقي.
  #    crf 8 = خطأ 0.6 مقابل الفكّ الدقيق، وحجمه ≈ ٥٣٠ ميقا لثلاث دقايق. يُبنى مرة ويُعاد لو تغيّر cutz.
  #    ويندوز: NVENC (h264_nvenc high444p constqp 4) يبنيه اسرع (T1: ‏9.8 ← 5.8 ث) بس ملفه 3.8× والرندر منه ابطا ~4 ث كل مرة
  #    (97 ← 101 ث، مقيس 4 مقابل 5 مرات)، فيبقى x264: الوسيط ينبني مرة والرندر يقراه اكثر من مرة (P2-5).
  if [ -f "$W/cutz.mp4" ]; then
    if [ ! -f "$C/.cutz444.mp4" ] || [ "$W/cutz.mp4" -nt "$C/.cutz444.mp4" ]; then
      echo "🎨 وسيط 4:4:4 للرندر (مرة وحدة، ~دقيقتين)…"
      ffmpeg -y -v error -i "$W/cutz.mp4" -vf format=yuv444p -c:v libx264 -crf 8 -preset fast \
        -colorspace bt709 -color_primaries bt709 -color_trc bt709 -color_range tv -an "$C/.cutz444.mp4"
    fi
    case "$(uname -s)" in
      MINGW*|MSYS*|CYGWIN*)   # ويندوز: رابط صلب بدل نسخة (R داخل W فنفس الدرايف). ffmpeg -y فوق يكتب بنفس الملف فالرابط يتبعه.
        ln -f "$C/.cutz444.mp4" "$R/public/video444.mp4" 2>/dev/null || cp "$C/.cutz444.mp4" "$R/public/video444.mp4" ;;
      *)
    cp "$C/.cutz444.mp4" "$R/public/video444.mp4"
    esac
  fi
  [ -f "$W/sfx.wav" ]  && cp "$W/sfx.wav"  "$R/public/sfx.wav"
  [ -f "$W/voice.wav" ] && cp "$W/voice.wav" "$R/public/voice.wav"   # للمعاينة بالاستوديو فقط
  LOGO="$(python3 -c 'import json,os,sys;p=sys.argv[1];print(json.load(open(p,encoding="utf-8-sig")).get("logo","logo.png") if os.path.exists(p) else "logo.png")' "$W/theme.json")"
  [ -f "$W/$LOGO" ] && cp "$W/$LOGO" "$R/public/logo.png"
  # ⛔ الشعار المفقود كان يُسقط الرندر كله — نعلنه بـproject.json فتتخطّاه المكوّنات
  if [ ! -f "$R/public/logo.png" ]; then
    echo "⚠️  ما فيه شعار بـ$W — يُرسم بدونه"
    python3 -c "import json,sys;p=sys.argv[1];d=json.load(open(p,encoding='utf-8-sig'));d['logo']=False;json.dump(d,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=1)" "$R/src/project.json"
  fi
  echo "✅ البيانات والأصول محدّثة بـ$R"
}

case "$CMD" in
  setup) sync_all; link_engine; echo "✅ جاهز." ;;
  engine) install_engine; link_engine ;;
  sync) sync_all ;;
  studio)
    sync_all; link_engine; remotion_cli; PORT="${ARG:-3000}"
    echo "🎬 الاستوديو على http://localhost:$PORT"
    ( cd "$R" && "${RUN[@]}" studio --port "$PORT" ) ;;
  render|render-test)
    sync_all; link_engine; remotion_cli; OUT="${ARG:-$W/ad-final.mp4}"
    case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) OUT="$(cygpath -m "$OUT")" ;; esac   # ويندوز: مثل W فوق
    FR=(); [ "$CMD" = render-test ] && { [ -n "$4" ] || { echo "render-test <out.mp4> <بداية-نهاية بالفريمات>"; exit 2; }; FR=(--frames="$4"); }
    grep -q '"guides": true' "$R/src/project.json" && \
      echo "⚠️  أدلّة المنطقة الآمنة شغّالة — تنطبع بالفيديو. شيل guides من safe.json قبل التسليم." 
    case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*)   # ويندوز: الناتج القديم مفتوح بمشغل ما يسمح بالحذف = rm تحت يطيح.
      #   اعادة التسمية تحتاج نفس صلاحية الحذف، فتكشفه بدون ما تلمس الملف.
      if [ -e "$OUT" ] && ! { mv -f "$OUT" "$OUT.busy" 2>/dev/null && mv -f "$OUT.busy" "$OUT"; }; then
        echo "⛔ الفيديو $(basename "$OUT") مفتوح ببرنامج ثاني (مشغل او معاينة المستكشف). سكره وعيد المحاولة"; exit 4; fi ;;
    esac
    # ⛔ الصورة تُرندر صامتة بـPNG (القاعدتان ١٩ و٢٨)، والصوت يُلصق بعدها كما هو.
    SIL="$C/.remotion-silent.mp4"
    # ⛔ امسح الناتج القديم قبل الرندر: رندر فشل (ENOSPC — القرص امتلأ) وبقي ad-final.mp4 القديم، فانفحص وانسلّم
    #    على إنه الجديد (صارت فعلاً: نسخة مسلَّمة بالصورة القديمة). ويوقف لو القرص أقل من 25 قيقا.
    rm -f "$OUT" "$SIL"
    FREE=$(df -Pk "$W" | awk 'NR==2{print int($4/1048576)}')
    if [ "${FREE:-0}" -lt 25 ]; then echo "❌ القرص فيه ${FREE} قيقا بس — الرندر يحتاج ~20 (إطارات PNG). نظّف مجلدات remotion-webpack-bundle المؤقتة أولاً"; exit 3; fi
    # ⛔ جودة ثابتة ١٤ ميقابت — crf 18 خلّى ريموشن يضغط لـ٤٫٨ ميقابت (٢٤٪ من مصدر ٢٠) بمقطعين،
    #    لأن الخلفية الغامقة تنضغط بسهولة فينزل كل الإطار. قاعدة «لا تحت ثلث المصدر».
    # ⛔ --color-space bt709 إلزامي (القاعدة ٩٠): بدونه يرمّز بمصفوفة 601 بلا وسم، فكل مشغّل HD يفكّه غلط (ميل لوني شافه بعينه).
    case "$(uname -s)" in
      MINGW*|MSYS*|CYGWIN*)   # ويندوز: نص خيوط المعالج (ريموشن ياخذ 8 بس) و4 خيوط لفك الفيديو بدل 2 — مقيس: 16 من 32 = رندر T1 كامل 88.6 ث بدل 96.2.
        #   بالنسبة لا برقم: ريموشن يوقف لو الرقم اكبر من خيوط الجهاز. REMOTION_CONCURRENCY وREMOTION_OTV_THREADS يغيرونها.
        # ويندوز: ريموشن يبني حزمته وينسخ public/ ويفتح بروفايل كروم بمجلد TEMP، والبروفايل يبقى بعده (~3 ميقا كل رندر).
        #   TEMP هنا <work>/.rtmp: نفس درايف الشغل اللي فحصنا مساحته فوق، وينمسح عند الخروج (ولو فشل الرندر) وببداية الرندر الجاي.
        #   مسار TEMP فيه حروف مو انجليزية = node يطيح بعد الرندر (0xC0000409 فيرجع 127، مجرب): مجلد شغل اسمه عربي ياخذ
        #   <VEB_HOME>/.rtmp/<رقم من مساره>، ولو هذا بعد مو انجليزي يبقى TEMP مثل ما هو.
        nonascii(){ printf %s "$1" | LC_ALL=C grep -q '[^ -~]'; }
        RTMP="$W/.rtmp"
        nonascii "$RTMP" && RTMP="${VEB_HOME:-$VD}/.rtmp/$(printf %s "$W" | cksum | cut -d' ' -f1)"
        nonascii "$RTMP" && RTMP=""
        # ويندوز: ريموشن ينسخ public/ كله لكل رندر (بالماك يربطه)، والرندر ما يقرا video.mp4 وvoice.wav وsfx.wav (معاينة بس، Ad.tsx).
        #   فيرندر من <work>/remotion/.public-render: روابط صلبة لباقي الملفات، والثلاثة تنضاف بس لو ملف tsx غير Ad.tsx يذكرها.
        #   public/ نفسه ما ينلمس: الاستوديو و24_cut_align يقرونه.
        PUB="$R/.public-render"
        rtmp_clean(){ rm -rf "$PUB" 2>/dev/null || true; [ -n "$RTMP" ] || return 0; for i in 1 2 3; do rm -rf "$RTMP" 2>/dev/null && return 0; sleep 2; done; echo "⚠️  ما قدرت امسح $RTMP — امسحه بيدك"; }
        rtmp_clean; [ -z "$RTMP" ] || mkdir -p "$RTMP"; trap rtmp_clean EXIT
        mkdir -p "$PUB"; SKIP=" "
        for f in video.mp4 voice.wav sfx.wav; do grep -lF "$f" "$R"/src/*.tsx | grep -qv '/Ad\.tsx$' || SKIP="$SKIP$f "; done
        ( cd "$R/public" && find . -type f ) | while IFS= read -r f; do f="${f#./}"; case "$SKIP" in *" $f "*) continue ;; esac
          mkdir -p "$PUB/$(dirname "$f")"; ln -f "$R/public/$f" "$PUB/$f" 2>/dev/null || cp "$R/public/$f" "$PUB/$f"; done
        # ويندوز: REMOTION_FONT_STRICT يخلي font.ts يوقف الرندر لو خط الكابشن ما تحمل، بدل كابشن بخط بديل بصمت (الاستوديو ما ياخذه).
        ( cd "$R" && { [ -z "$RTMP" ] || export TEMP="$(cygpath -w "$RTMP")" TMP="$(cygpath -w "$RTMP")"; } && REMOTION_FONT_STRICT=1 "${RUN[@]}" render Ad "$SIL" --codec h264 --video-bitrate 14M --image-format png --muted --color-space bt709 \
            --concurrency="${REMOTION_CONCURRENCY:-50%}" --offthreadvideo-video-threads="${REMOTION_OTV_THREADS:-4}" --public-dir="$(cygpath -w "$PUB")" "${FR[@]}" ) ;;
      *)
    ( cd "$R" && npx remotion render Ad "$SIL" --codec h264 --video-bitrate 14M --image-format png --muted --color-space bt709 "${FR[@]}" )
    esac
    if [ -f "$W/voice.wav" ]; then
      MIX="$W/voice.wav"
      if [ -f "$W/sfx.wav" ]; then
        MIX="$C/.remotion-mix.wav"
        ffmpeg -y -v error -i "$W/voice.wav" -i "$W/sfx.wav" \
          -filter_complex "[0:a][1:a]amix=inputs=2:duration=first:normalize=0[a]" \
          -map "[a]" -c:a pcm_s24le -ar 48000 "$MIX"
      fi
      # الأوسمة كاملة داخل الستريم نفسه (primaries · transfer · matrix · range) — نسخ بلا إعادة ترميز
      ffmpeg -y -v error -i "$SIL" -i "$MIX" -map 0:v -map 1:a -c:v copy \
        -bsf:v "h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1:video_full_range_flag=0" \
        -c:a aac -b:a 256k -shortest "$OUT"
      rm -f "$C/.remotion-mix.wav"
    else
      echo "⚠️  ما فيه voice.wav — سلّمت الصورة بلا صوت"; cp "$SIL" "$OUT"
    fi
    rm -f "$SIL"
    echo "✅ $OUT"
    ffprobe -v error -show_entries format=duration,size -show_entries stream=width,height -of default=nw=1 "$OUT"
    echo "— تحقّق إلزامي: قارن صوت الناتج بـvoice.wav (ارتباط ≥ 0.999) قبل التسليم."
    # ⛔ الفحصان بعد كل رندر (القاعدتان ١٩ و٩٠) — «رندر نجح» ما يعني «صورته وصوته سليمان»
    if [ "$CMD" = render-test ]; then
      A0="${4%-*}"; python3 "$SK/21_color_check.py" "$W" "$OUT" --at "$(python3 -c "print(round(($A0+30)/30,2))")" --offset "$(python3 -c "print(round($A0/30,3))")" || true
    else
      # 21 يخرج 3 لو لونه تغيّر و2 لو ما قدر يقرأ (ملف ناقص · فريمات ما انقرت): خطأ القراءة ما ينقال عنه «اللون تغيّر»
      CRC=0; python3 "$SK/21_color_check.py" "$W" "$OUT" || CRC=$?
      case "$CRC" in 0) ;; 3) echo "⛔ اللون تغيّر — لا تسلّم" ;; *) echo "⛔ فحص اللون ما تم (السبب فوق) — لا تسلّم قبل ما ينفحص" ;; esac
      # 20 يخرج 3 لو صوته تغيّر و4 لو ما قدر يقرأ الملف: خطأ القراءة ما ينقال عنه «الصوت تغيّر»
      if [ -f "$W/voice.wav" ]; then VRC=0; python3 "$SK/20_voice_check.py" "$W" "$OUT" || VRC=$?
        case "$VRC" in 0) ;; 3) echo "⛔ الصوت تغيّر — لا تسلّم" ;; *) echo "⛔ فحص الصوت ما تم (السبب فوق) — لا تسلّم قبل ما ينفحص" ;; esac; fi
    fi
    ;;
  *) echo "أوامر: setup | engine | sync | studio | render | render-test"; exit 2 ;;
esac
