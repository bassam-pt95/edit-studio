#!/bin/bash
# ./06_encode.sh <workdir> [اسم_الملف]   → يجمّع الفريمات + الصوت + المؤثرات
case "$OSTYPE" in msys*|cygwin*) [ "$(command -v find)" = /usr/bin/find ] || export PATH="$HOME/bin:/mingw64/bin:/usr/bin:$PATH";; esac   # ويندوز: bash بلا login يبدا PATH بـSystem32: find حق ويندوز (ولو ادوات Git بالـPATH تجي بعدها)، وما فيه ~/bin حق python3؛ فلو find مو /usr/bin/find نحط ~/bin وادوات Git اول مثل login
set -e
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) export PYTHONUTF8=1 PYTHONIOENCODING=utf-8 ;; esac   # ويندوز: بايثون بـUTF-8 لا بترميز النظام
W="$(cd "$1" && pwd)"; OUT="${2:-$W/ad-final.mp4}"
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) W="$(cygpath -m "$W")"; OUT="$(cygpath -m "$OUT")" ;; esac   # ويندوز: مسارات C:/ للادوات الاصلية، فتشتغل حتى مع MSYS_NO_PATHCONV=1 او MSYS2_ARG_CONV_EXCL='*'
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*)   # ويندوز: ffmpeg -y ما يكتب فوق ملف مفتوح ببرنامج ما يسمح بالكتابة.
  #   فتحه للاضافة بلا كتابة يكشفه بدون ما يغير الملف (حتى تاريخه).
  if [ -e "$OUT" ] && ! { true >> "$OUT"; } 2>/dev/null; then
    echo "⛔ الفيديو $(basename "$OUT") مفتوح ببرنامج ثاني (مشغل او معاينة المستكشف). سكره وعيد المحاولة"; exit 4; fi ;;
esac
DUR=$(python3 -c 'import json,sys;c=json.load(open(sys.argv[1],encoding="utf-8-sig"));s=json.load(open(sys.argv[2],encoding="utf-8-sig"));print(round(c["total"]+s["outro"],3))' "$W/caps.json" "$W/sfx.json")
FADE=$(python3 -c "print(round($DUR-0.6,3))")
ffmpeg -v error -stats -framerate 30 -i "$W/out/%05d.png" -i "$W/cutz.mp4" -i "$W/sfx.wav" \
 -filter_complex "[0:v]scale=out_color_matrix=bt709:out_range=tv:flags=accurate_rnd+full_chroma_int,format=yuv420p,setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=tv[vo];[1:a]apad=pad_dur=8[a0];[a0][2:a]amix=inputs=2:duration=first:normalize=0[am];[am]atrim=0:$DUR,asetpts=PTS-STARTPTS,afade=t=out:st=$FADE:d=0.6[ao]" \
 -map "[vo]" -map "[ao]" -c:v libx264 -preset slow -crf 18 -maxrate 14M -bufsize 28M \
 -profile:v high -level 4.0 -pix_fmt yuv420p -r 30 -colorspace bt709 -color_primaries bt709 -color_trc bt709 -color_range tv \
 -c:a aac -b:a 160k -ar 48000 \
 -movflags +faststart -y "$OUT"
echo "✅ $OUT"
ffprobe -v error -show_entries format=duration,size -show_entries stream=width,height -of default=nw=1 "$OUT"
