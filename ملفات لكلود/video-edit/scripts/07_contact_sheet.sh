#!/bin/bash
# ورقة تواصل: يجمع لقطات كثيرة بصورة وحدة — كلود يشوفها بقراءة وحدة بدل عشر قراءات (توفير توكنز كبير).
# ./07_contact_sheet.sh <workdir> <sheet.jpg> <t1> <t2> ...    (المصدر: ad-final.mp4 إن وُجد، وإلا مجلد prev/)
set -e
. "$(cd "$(dirname "$0")" && pwd)/_common.sh"
W="$(cd "$1" && pwd)"; OUT="$2"; shift 2
TMP="$W/.sheet"; rm -rf "$TMP"; mkdir -p "$TMP"; i=0; INS=()
trap 'rm -rf "$TMP"' EXIT
# ويندوز: نسخة ffmpeg من gyan.dev بلا إعداد fontconfig، فـdrawtext بلا fontfile ينهار (Segmentation fault)
FONT=""
if [ "$VE_WIN" = 1 ]; then WD="${WINDIR:-C:/Windows}"; WD="${WD//\\//}"; FONT="fontfile='${WD/:/\\:}/Fonts/arial.ttf':"; fi
for t in "$@"; do
  i=$((i+1)); f="$TMP/$(printf %02d $i).jpg"
  if [ -f "$W/ad-final.mp4" ]; then ffmpeg -v error -ss "$t" -i "$W/ad-final.mp4" -frames:v 1 -vf "scale=300:-1" -y "$f"
  else ffmpeg -v error -i "$W/prev/t$(printf %.2f $t).jpg" -vf "scale=300:-1" -y "$f"; fi
  ffmpeg -v error -i "$f" -vf "drawtext=${FONT}text='${t}s':x=8:y=8:fontsize=20:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=5" -y "$f.l.jpg" 2>/dev/null || cp "$f" "$f.l.jpg"
  # مصفوفة لا نص: المسار اللي فيه مسافة (C:\Users\Ahmed Ali) ينقسم لو انلصق بنص
  INS+=(-i "$f.l.jpg")
done
if [ "$i" -eq 1 ]; then cp "$TMP/01.jpg.l.jpg" "$OUT"   # hstack ما يقبل مدخل واحد
else ffmpeg -v error "${INS[@]}" -filter_complex "hstack=inputs=$i" -y "$OUT"; fi
rm -rf "$TMP"; echo "✅ $OUT  ($i لقطة)"
