#!/bin/bash
# لوحة الآليات — صورة واحدة فيها لقطة من كل آلية بالمقطع، تُحفظ جنب التسليم.
#   ./15_board.sh "<اسم المقطع>" <مسار.mp4> [مسار الخرج.jpg]
# ليش: الأسماء تُنسى، الصور لا. لمّا يقول «متراكب مع شي قديم» تُفتح اللوحة ويُقرَّر بثانية.
set -e
SK="$(cd "$(dirname "$0")" && pwd)"
. "$SK/_common.sh"; ve_set_python
NAME="$1"; VID="$2"
# اسم الملف يُنظَّف على ويندوز (: ? " * ... ممنوعة)، أما البحث بالسجل فبالاسم الأصلي
OUT="${3:-$(dirname "$VID")/.لوحة-$(ve_safe_name "$NAME").jpg}"
# كل المسارات والأسماء تدخل بايثون بـsys.argv: لا حقن نص (اسم فيه ' ) ولا مسار ويندوز يتحوّل لـ\U بنص الكود
K="$($PY -c 'import sys;sys.path.insert(0,sys.argv[1]);import _paths;print(_paths.HOME)' "$SK")"   # مجلد بيانات المستخدم
read -r -d '' PYTIMES <<'PY' || true
import json, sys
K, NAME = sys.argv[1], sys.argv[2]
M = json.load(open(K + '/mechanisms.json', encoding='utf-8-sig'))
v = [x for x in M['videos'] if x['name'] == NAME]
if not v: sys.exit('❌ ما لقيت المقطع بالسجل: ' + NAME)
seen = []; out = []
for c in v[0]['mechs']:
    if c in seen: continue
    seen.append(c)
    u = [w for w in M['mechs'][c].get('used', []) if w[0] == v[0]['id']]
    if u: out.append(str(u[0][1]))
print(' '.join(out))
PY
TIMES=$($PY -c "$PYTIMES" "$K" "$NAME")
[ -z "$TIMES" ] && { echo "❌ ما فيه أوقات مسجّلة"; exit 2; }
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VID")
TMP=$(mktemp -d); i=0; IN=""
trap 'rm -rf "$TMP"' EXIT
for t in $TIMES; do
  i=$((i+1)); P=$(printf "%02d" $i)
  # +1.9 ث: الرسمة تكون استقرّت — التقاطها وهي داخلة يعطي لقطة نصف مرسومة
  ffmpeg -v error -ss "$($PY -c "print(max(0,min($t+1.9,$DUR-0.6)))")" -i "$VID" -frames:v 1 -vf scale=260:-1 -y "$TMP/f$P.jpg"
done
N=$i; COLS=5; ROWS=$(( (N+COLS-1)/COLS ))
# أسماء مرقّمة f%02d لا glob: ويندوز ما يدعم -pattern_type glob، وgit-bash يخرّب النجمة
ve_unhide "$OUT"   # ويندوز يرفض الكتابة فوق ملف مخفي (لوحة قديمة)
ffmpeg -v error -framerate 1 -i "$TMP/f%02d.jpg" -vf "tile=${COLS}x${ROWS}:padding=8:color=#17181A" -frames:v 1 -pix_fmt yuvj420p -huffman optimal -y "$OUT"
ve_hide "$OUT"     # ويندوز: النقطة ما تخفي الملف، فنخفيه بصفة الملف
rm -rf "$TMP"
echo "✅ $OUT  ($N آلية)"
