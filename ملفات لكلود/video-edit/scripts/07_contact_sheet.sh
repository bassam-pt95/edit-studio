#!/bin/bash
# ورقة تواصل: يجمع لقطات كثيرة بصورة وحدة — كلود يشوفها بقراءة وحدة بدل عشر قراءات (توفير توكنز كبير).
# ./07_contact_sheet.sh <workdir> <sheet.jpg> <t1> <t2> ...    (المصدر: ad-final.mp4 إن وُجد، وإلا مجلد prev/)
case "$OSTYPE" in msys*|cygwin*) [ "$(command -v find)" = /usr/bin/find ] || export PATH="$HOME/bin:/mingw64/bin:/usr/bin:$PATH";; esac   # ويندوز: bash بلا login يبدا PATH بـSystem32: find حق ويندوز (ولو ادوات Git بالـPATH تجي بعدها)، وما فيه ~/bin حق python3؛ فلو find مو /usr/bin/find نحط ~/bin وادوات Git اول مثل login
set -e
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) export PYTHONUTF8=1 PYTHONIOENCODING=utf-8 ;; esac   # ويندوز: بايثون بـUTF-8 لا بترميز النظام
W="$(cd "$1" && pwd)"; OUT="$2"; shift 2
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) W="$(cygpath -m "$W")"; OUT="$(cygpath -m "$OUT")" ;; esac   # ويندوز: مسارات C:/ للادوات الاصلية، فتشتغل حتى مع MSYS_NO_PATHCONV=1 او MSYS2_ARG_CONV_EXCL='*'
C="$W"; case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) C="$W/.cache"; mkdir -p "$C"; attrib +h "$(cygpath -w "$C")" >/dev/null 2>&1 || true ;; esac   # ويندوز: النقطة ما تخبي .sheet بالمستكشف، فينحط بمجلد .cache مخفي
TMP="$C/.sheet"; rm -rf "$TMP"; mkdir -p "$TMP"; i=0; IN=()
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) ;; *) trap 'rm -rf "$TMP"' EXIT ;; esac   # الماك: لو ffmpeg فشل بنص الطريق ما يبقى .sheet بمجلد الشغل
FONT=""; case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) F="$(cygpath -m "${WINDIR:-C:/Windows}")/Fonts/arial.ttf"; [ -f "$F" ] && FONT="fontfile='${F%%:*}\:${F#*:}':" ;; esac   # ويندوز: ffmpeg حق gyan بلا fontconfig، وdrawtext بلا خط يطيح
for t in "$@"; do
  i=$((i+1)); f="$TMP/$(printf %02d $i).jpg"
  if [ -f "$W/ad-final.mp4" ]; then ffmpeg -v error -ss "$t" -i "$W/ad-final.mp4" -frames:v 1 -vf "scale=300:-1" -y "$f"
  else ffmpeg -v error -i "$W/prev/t$(printf %.2f $t).jpg" -vf "scale=300:-1" -y "$f"; fi
  ffmpeg -v error -i "$f" -vf "drawtext=${FONT}text='${t}s':x=8:y=8:fontsize=20:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=5" -y "$f.l.jpg" 2>/dev/null || cp "$f" "$f.l.jpg"
  IN+=(-i "$f.l.jpg")
done
if [ "$i" -eq 1 ]; then cp "$TMP/01.jpg.l.jpg" "$OUT"   # لقطة وحدة: hstack يبي لقطتين على الاقل
else ffmpeg -v error "${IN[@]}" -filter_complex "hstack=inputs=$i" -y "$OUT"; fi
rm -rf "$TMP"; echo "✅ $OUT  ($i لقطة)"
