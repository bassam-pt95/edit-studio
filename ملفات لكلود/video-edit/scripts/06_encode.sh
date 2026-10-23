#!/bin/bash
# ./06_encode.sh <workdir> [اسم_الملف]   → يجمّع الفريمات + الصوت + المؤثرات
set -e
. "$(cd "$(dirname "$0")" && pwd)/_common.sh"; ve_set_python
W="$(cd "$1" && pwd)"; OUT="${2:-$W/ad-final.mp4}"
# المسار يدخل بايثون بـsys.argv (Git Bash ما يحوّل المسارات اللي داخل نص الكود)
DUR=$($PY -c "import json,os,sys;d=sys.argv[1];c=json.load(open(os.path.join(d,'caps.json'),encoding='utf-8-sig'));s=json.load(open(os.path.join(d,'sfx.json'),encoding='utf-8-sig'));print(round(c['total']+s['outro'],3))" "$W")
FADE=$($PY -c "print(round($DUR-0.6,3))")
ve_free_out "$OUT"
ffmpeg -v error -stats -framerate 30 -i "$W/out/%05d.jpg" -i "$W/cutz.mp4" -i "$W/sfx.wav" \
 -filter_complex "[0:v]format=yuv420p[vo];[1:a]apad=pad_dur=8[a0];[a0][2:a]amix=inputs=2:duration=first:normalize=0[am];[am]atrim=0:$DUR,asetpts=PTS-STARTPTS,afade=t=out:st=$FADE:d=0.6[ao]" \
 -map "[vo]" -map "[ao]" -c:v libx264 -preset slow -crf 18 -maxrate 14M -bufsize 28M \
 -profile:v high -level 4.0 -pix_fmt yuv420p -r 30 -c:a aac -b:a 160k -ar 48000 \
 -movflags +faststart -y "$OUT"
echo "✅ $OUT"
ffprobe -v error -show_entries format=duration,size -show_entries stream=width,height -of default=nw=1 "$OUT"
