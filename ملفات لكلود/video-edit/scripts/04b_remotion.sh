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
set -e
. "$(cd "$(dirname "$0")" && pwd)/_common.sh"; ve_set_python
W="$(cd "$1" && pwd)"; CMD="${2:-setup}"; ARG="$3"
TPL="$(cd "$(dirname "$0")/remotion-template" && pwd)"
R="$W/remotion"
SHARED="$(veb_home)/remotion-shared"

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
  if [ "$VE_WIN" = 1 ]; then
    # ويندوز: وصلة مجلد (junction) — ما تحتاج صلاحية مدير، لكن لازم القرص NTFS محلّي (مو شبكة ولا exFAT/FAT32)
    [ -f "$R/node_modules/remotion/package.json" ] && return       # الوصلة شغّالة
    D="$(ve_win_drive "$R")"
    case "$D" in
      ""|"Fixed NTFS"|"Removable NTFS"|"Fixed ReFS") ;;
      *) echo "⛔ مجلد الشغل على قرص «${D}» — ربط محرّك الرسم (junction) يحتاج قرص NTFS محلّي."
         echo "   انقل مجلد الشغل إلى قرص محلّي مثل C:\\ ثم أعد: bash scripts/04b_remotion.sh \"$W\" setup"; exit 14 ;;
    esac
    case "$(ve_win_drive "$SHARED")" in Network*) echo "⛔ مجلد محرّك الرسم ($SHARED) على قرص شبكة — الـjunction ما يوصل لها. اضبط VEB_HOME على قرص محلّي."; exit 14 ;; esac
    # Node يشيل الوصلة المكسورة (الوصلة نفسها لا الهدف) ويسوي الجديدة ويتأكد إنها توصل — بلا cmd //c mklink اللي يخرّبه Git Bash
    ve_junction "$SHARED/node_modules" "$R/node_modules" \
      || { echo "❌ ما قدرت أربط محرّك الرسم: $R/node_modules ← $SHARED/node_modules"; exit 14; }
  else
    # مجلد حقيقي بلا ريموشن = تنزيل قديم ما كمل — يُشال ويُربط بدله
    [ -d "$R/node_modules" ] && [ ! -L "$R/node_modules" ] && rm -rf "$R/node_modules"
    # mac-only: فرع غير ويندوز (فرع ويندوز فوق يسوي junction)
    ln -sfn "$SHARED/node_modules" "$R/node_modules"
  fi
}

sync_all(){
  mkdir -p "$R/src" "$R/public"
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
  STYLE="$($PY -c "import json,os,sys;p=os.path.join(sys.argv[1],'style.json');print(json.load(open(p,encoding='utf-8-sig')).get('style','simple') if os.path.exists(p) else 'simple')" "$W")"
  case "$STYLE" in collage|documentary|board|vox) KIT=collage ;; *) KIT=simple ;; esac
  SD="$(cd "$(dirname "$0")/.." && pwd)/styles/$KIT"
  if [ -d "$SD/kit" ]; then cp "$SD"/kit/*.tsx "$R/src/"; fi
  if [ -d "$SD/assets" ]; then find "$SD/assets" -type f ! -name '*.md' -exec cp {} "$R/public/" \;; fi
  # أصول المقطع نفسه (صور Pexels · صوره · الكتاب): <work>/assets/*
  [ -d "$W/assets" ] && find "$W/assets" -type f -exec cp {} "$R/public/" \;
  echo "الأسلوب: $STYLE"

  cp "$W/caps.json" "$R/src/caps.json"
  $PY - "$W" "$R" <<'PY'
import json, os, sys
W, R = sys.argv[1], sys.argv[2]
def rd(name, dflt):
    p = os.path.join(W, name)
    return json.load(open(p, encoding="utf-8-sig")) if os.path.exists(p) else dflt   # utf-8-sig: PowerShell يكتب JSON ببصمة BOM
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
json.dump(proj, open(os.path.join(R, "src", "project.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("project.json → المدة", proj["total"], "+ ختام", proj["outro"], "· مؤثرات:", "نعم" if proj["sfx"] else "لا")
PY
  [ -f "$W/cutz.mp4" ] && cp "$W/cutz.mp4" "$R/public/video.mp4"          # للمعاينة بالاستوديو
  # ⛔ القاعدة ٩٠ — الرندر يقرأ وسيطاً 4:4:4 لا المقصوص 4:2:0.
  #    مفكّك ريموشن (swscale) يفقد ‎-1.7 سطوع بفكّ 4:2:0، وصفراً بفكّ 4:4:4 — مقيس على مقطع حقيقي.
  #    crf 8 = خطأ 0.6 مقابل الفكّ الدقيق، وحجمه ≈ ٥٣٠ ميقا لثلاث دقايق. يُبنى مرة ويُعاد لو تغيّر cutz.
  if [ -f "$W/cutz.mp4" ]; then
    if [ ! -f "$W/.cutz444.mp4" ] || [ "$W/cutz.mp4" -nt "$W/.cutz444.mp4" ]; then
      echo "🎨 وسيط 4:4:4 للرندر (مرة وحدة، ~دقيقتين)…"
      ve_unhide "$W/.cutz444.mp4"   # ويندوز: ما تنكتب فوق ملف مخفي
      ffmpeg -y -v error -i "$W/cutz.mp4" -vf format=yuv444p -c:v libx264 -crf 8 -preset fast \
        -colorspace bt709 -color_primaries bt709 -color_trc bt709 -color_range tv -an "$W/.cutz444.mp4"
      ve_hide "$W/.cutz444.mp4"     # ويندوز: النقطة ما تخفي الملف عن Explorer (~530 ميقا)
    fi
    cp "$W/.cutz444.mp4" "$R/public/video444.mp4"
  fi
  # ويندوز: NTFS يفرّق بين الهمزة/المدّة المركّبة وغير المركّبة (NFC/NFD)؛ ملف جاي من ماك أو zip يصير اسمه NFD وScenes.tsx يكتبه NFC فيرجع 404
  if [ "$VE_WIN" = 1 ]; then
    $PY -c "import os,sys,unicodedata as u;d=sys.argv[1]
for f in os.listdir(d):
    n=u.normalize('NFC',f)
    if n!=f and not os.path.exists(os.path.join(d,n)): os.rename(os.path.join(d,f),os.path.join(d,n))" "$R/public"
  fi
  [ -f "$W/sfx.wav" ]  && cp "$W/sfx.wav"  "$R/public/sfx.wav"
  [ -f "$W/voice.wav" ] && cp "$W/voice.wav" "$R/public/voice.wav"   # للمعاينة بالاستوديو فقط
  LOGO="$($PY -c "import json,os,sys;p=os.path.join(sys.argv[1],'theme.json');print(json.load(open(p,encoding='utf-8-sig')).get('logo','logo.png') if os.path.exists(p) else 'logo.png')" "$W")"
  [ -f "$W/$LOGO" ] && cp "$W/$LOGO" "$R/public/logo.png"
  # ⛔ الشعار المفقود كان يُسقط الرندر كله — نعلنه بـproject.json فتتخطّاه المكوّنات
  if [ ! -f "$R/public/logo.png" ]; then
    echo "⚠️  ما فيه شعار بـ$W — يُرسم بدونه"
    $PY -c "import json,sys;p=sys.argv[1];d=json.load(open(p,encoding='utf-8'));d['logo']=False;json.dump(d,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=1)" "$R/src/project.json"
  fi
  echo "✅ البيانات والأصول محدّثة بـ$R"
}

case "$CMD" in
  setup) sync_all; link_engine; echo "✅ جاهز." ;;
  engine) install_engine; link_engine ;;
  sync) sync_all ;;
  studio)
    sync_all; link_engine; PORT="${ARG:-3000}"
    echo "🎬 الاستوديو على http://localhost:$PORT"
    ( cd "$R" && npx remotion studio --port "$PORT" ) ;;
  render|render-test)
    sync_all; link_engine; OUT="${ARG:-$W/ad-final.mp4}"
    FR=(); [ "$CMD" = render-test ] && { [ -n "$4" ] || { echo "render-test <out.mp4> <بداية-نهاية بالفريمات>"; exit 2; }; FR=(--frames="$4"); }
    grep -q '"guides": true' "$R/src/project.json" && \
      echo "⚠️  أدلّة المنطقة الآمنة شغّالة — تنطبع بالفيديو. شيل guides من safe.json قبل التسليم." 
    # ⛔ الصورة تُرندر صامتة بـPNG (القاعدتان ١٩ و٢٨)، والصوت يُلصق بعدها كما هو.
    SIL="$W/.remotion-silent.mp4"
    # ⛔ امسح الناتج القديم قبل الرندر: رندر فشل (ENOSPC — القرص امتلأ) وبقي ad-final.mp4 القديم، فانفحص وانسلّم
    #    على إنه الجديد (صارت فعلاً: نسخة مسلَّمة بالصورة القديمة). ويوقف لو القرص أقل من 25 قيقا.
    ve_free_out "$OUT"   # ويندوز: الناتج القديم مفتوح بمشغّل → رسالة بالعربي بدل Device or resource busy
    rm -f "$OUT" "$SIL"
    FREE=$(df -Pk "$W" | awk 'NR==2{print int($4/1048576)}')
    if [ "${FREE:-0}" -lt 25 ]; then echo "❌ القرص فيه ${FREE} قيقا بس — الرندر يحتاج ~20 (إطارات PNG). نظّف مجلدات remotion-webpack-bundle المؤقتة أولاً"; exit 3; fi
    # ويندوز: Remotion يكتب إطاراته (~20 قيقا) ومتصفحه المؤقت بـ%TEMP% (غالباً C:)، مو بقرص مجلد الشغل اللي فحصناه فوق.
    #   نوجّه TMP/TEMP لمجلد مؤقت داخل مجلد الشغل ويُمسح بعد الرندر؛ ولو مجلد الشغل بـOneDrive (يزامن 20 قيقا) نفحص قرص %TEMP% نفسه.
    TENV=()
    if [ "$VE_WIN" = 1 ]; then
      case "$W" in
        *[Oo]ne[Dd]rive*)
          TMPD="$(node -e 'process.stdout.write(require("os").tmpdir())' 2>/dev/null | tr -d '\r')"; TMPD="$(cygpath -u "$TMPD" 2>/dev/null || true)"
          if [ -n "$TMPD" ] && [ -d "$TMPD" ]; then
            TFREE=$(df -Pk "$TMPD" | awk 'NR==2{print int($4/1048576)}')
            if [ "${TFREE:-0}" -lt 25 ]; then echo "❌ قرص المجلد المؤقت (%TEMP%) فيه ${TFREE} قيقا بس — الرندر يحتاج ~20. نظّفه أو شغّل الرندر من مجلد شغل خارج OneDrive"; exit 3; fi
          fi ;;
        *)
          RT="$W/.rtmp"; rm -rf "$RT"; mkdir -p "$RT"; trap 'rm -rf "$RT"' EXIT
          TENV=(env "TMP=$(cygpath -w "$RT")" "TEMP=$(cygpath -w "$RT")") ;;
      esac
      # جدار حماية ويندوز: أول رندر يشغّل سيرفراً محلياً بـnode.exe فيطلع سؤال، ولو انضغط «إلغاء» يفشل الرندر
      FWF="$(veb_home)/.firewall-told"
      if [ ! -f "$FWF" ]; then
        echo "ℹ️  أول رندر على ويندوز: ممكن تطلع نافذة جدار الحماية تسأل عن node.exe — اضغط «السماح» (Allow). لو ضغطت «إلغاء» أعد الرندر."
        mkdir -p "$(dirname "$FWF")" && : > "$FWF" || true
      fi
    fi
    # ⛔ جودة ثابتة ١٤ ميقابت — crf 18 خلّى ريموشن يضغط لـ٤٫٨ ميقابت (٢٤٪ من مصدر ٢٠) بمقطعين،
    #    لأن الخلفية الغامقة تنضغط بسهولة فينزل كل الإطار. قاعدة «لا تحت ثلث المصدر».
    # ⛔ --color-space bt709 إلزامي (القاعدة ٩٠): بدونه يرمّز بمصفوفة 601 بلا وسم، فكل مشغّل HD يفكّه غلط (ميل لوني شافه بعينه).
    ( cd "$R" && "${TENV[@]}" npx remotion render Ad "$SIL" --codec h264 --video-bitrate 14M --image-format png --muted --color-space bt709 "${FR[@]}" )
    if [ -f "$W/voice.wav" ]; then
      MIX="$W/voice.wav"
      if [ -f "$W/sfx.wav" ]; then
        MIX="$W/.remotion-mix.wav"
        ffmpeg -y -v error -i "$W/voice.wav" -i "$W/sfx.wav" \
          -filter_complex "[0:a][1:a]amix=inputs=2:duration=first:normalize=0[a]" \
          -map "[a]" -c:a pcm_s24le -ar 48000 "$MIX"
      fi
      # الأوسمة كاملة داخل الستريم نفسه (primaries · transfer · matrix · range) — نسخ بلا إعادة ترميز
      ffmpeg -y -v error -i "$SIL" -i "$MIX" -map 0:v -map 1:a -c:v copy \
        -bsf:v "h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1:video_full_range_flag=0" \
        -c:a aac -b:a 256k -shortest "$OUT"
      rm -f "$W/.remotion-mix.wav"
    else
      echo "⚠️  ما فيه voice.wav — سلّمت الصورة بلا صوت"; cp "$SIL" "$OUT"
    fi
    rm -f "$SIL"
    echo "✅ $OUT"
    ffprobe -v error -show_entries format=duration,size -show_entries stream=width,height -of default=nw=1 "$OUT"
    echo "— تحقّق إلزامي: قارن صوت الناتج بـvoice.wav (ارتباط ≥ 0.999) قبل التسليم."
    # ⛔ الفحصان بعد كل رندر (القاعدتان ١٩ و٩٠) — «رندر نجح» ما يعني «صورته وصوته سليمان»
    SK="$(cd "$(dirname "$0")" && pwd)"
    if [ "$CMD" = render-test ]; then
      A0="${4%-*}"; $PY "$SK/21_color_check.py" "$W" "$OUT" --at "$($PY -c "print(round(($A0+30)/30,2))")" --offset "$($PY -c "print(round($A0/30,3))")" || true
    else
      $PY "$SK/21_color_check.py" "$W" "$OUT" || echo "⛔ اللون تغيّر — لا تسلّم"
      [ -f "$W/voice.wav" ] && { $PY "$SK/20_voice_check.py" "$W" "$OUT" || echo "⛔ الصوت تغيّر — لا تسلّم"; }
    fi
    ;;
  *) echo "أوامر: setup | engine | sync | studio | render | render-test"; exit 2 ;;
esac
