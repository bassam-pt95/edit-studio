#!/bin/bash
# لوحة الآليات — صورة واحدة فيها لقطة من كل آلية بالمقطع، تُحفظ جنب التسليم.
#   ./15_board.sh "<اسم المقطع>" <مسار.mp4> [مسار الخرج.jpg]
# ليش: الأسماء تُنسى، الصور لا. لمّا يقول «متراكب مع شي قديم» تُفتح اللوحة ويُقرَّر بثانية.
case "$OSTYPE" in msys*|cygwin*) [ "$(command -v find)" = /usr/bin/find ] || export PATH="$HOME/bin:/mingw64/bin:/usr/bin:$PATH";; esac   # ويندوز: bash بلا login يبدا PATH بـSystem32: find حق ويندوز (ولو ادوات Git بالـPATH تجي بعدها)، وما فيه ~/bin حق python3؛ فلو find مو /usr/bin/find نحط ~/bin وادوات Git اول مثل login
set -e
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) export PYTHONUTF8=1 PYTHONIOENCODING=utf-8 ;; esac   # ويندوز: بايثون بـUTF-8 لا بترميز النظام
PY=python3   # حلقة اللقطات تحت تنادي $PY
NAME="$1"; VID="$2"; SAFE="$NAME"
SK="$(cd "$(dirname "$0")" && pwd)"   # مجلد السكربتات
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) SK="$(cygpath -m "$SK")"; VID="$(cygpath -m "$VID")" ;; esac   # ويندوز: مسارات C:/ للادوات الاصلية، فتشتغل حتى مع MSYS_NO_PATHCONV=1 او MSYS2_ARG_CONV_EXCL='*'
# ويندوز: اسم اللوحة بلا الرموز الممنوعة (: ? * " < > |) — «:» تخبي الصورة بـstream مخفي. NAME يبقى للبحث بالسجل
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) [ -n "$3" ] || SAFE="$(python3 -c 'import sys;sys.path.insert(0,sys.argv[1]);import _paths;print(_paths.safe_name(sys.argv[2]))' "$SK" "$NAME")" ;; esac
OUT="${3:-$(dirname "$VID")/.لوحة-$SAFE.jpg}"
K="$(python3 -c 'import sys;sys.path.insert(0,sys.argv[1]);import _paths;print(_paths.HOME)' "$SK")"   # مجلد بيانات المستخدم
# المسار والاسم يدخلون بايثون كـarguments مو داخل الكود (ويندوز ما يحول /c/... داخل الكود، و\U بمسار C:\Users يكسره)
TIMES=$(python3 - "$K" "$NAME" <<'PY'
import json,os,sys
K,NAME=sys.argv[1],sys.argv[2]
M=json.load(open(os.path.join(K,'mechanisms.json'),encoding='utf-8-sig'))
v=[x for x in M['videos'] if x['name']==NAME]
if not v: sys.exit('❌ ما لقيت المقطع بالسجل: '+NAME)
seen=[];out=[]
for c in v[0]['mechs']:
    if c in seen: continue
    seen.append(c)
    u = [w for w in M['mechs'][c].get('used', []) if w[0] == v[0]['id']]
    if u: out.append(str(u[0][1]))
print(' '.join(out))
PY
)
[ -z "$TIMES" ] && { echo "❌ ما فيه أوقات مسجّلة"; exit 2; }
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VID")
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT; i=0; IN=""
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) TMP="$(cygpath -m "$TMP")"; OUT="$(cygpath -m "$OUT")" ;; esac   # ويندوز: مثل VID فوق
for t in $TIMES; do
  i=$((i+1)); P=$(printf "%02d" $i)
  # +1.9 ث: الرسمة تكون استقرّت — التقاطها وهي داخلة يعطي لقطة نصف مرسومة
  ffmpeg -v error -ss "$($PY -c "print(max(0,min($t+1.9,$DUR-0.6)))")" -i "$VID" -frames:v 1 -vf scale=260:-1 -y "$TMP/f$P.jpg"
done
N=$i; COLS=5; ROWS=$(( (N+COLS-1)/COLS ))
# ويندوز: النقطة ما تخبي اللوحة بالمستكشف مثل الماك، فتنخبي بـattrib +h. ffmpeg -y ما يكتب فوق ملف مخفي، فتنكشف قبله
HIDE=0; case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) case "$(basename "$OUT")" in .*) HIDE=1 ;; esac ;; esac
[ $HIDE = 1 ] && [ -f "$OUT" ] && { attrib -h "$(cygpath -w "$OUT")" >/dev/null 2>&1 || true; }
# نمط مرقم (f01، f02…) مو -pattern_type glob: نسخ ffmpeg لويندوز ما تدعم glob
ffmpeg -v error -i "$TMP/f%02d.jpg" -vf "tile=${COLS}x${ROWS}:padding=8:color=#17181A" -frames:v 1 -pix_fmt yuvj420p -huffman optimal -y "$OUT"
[ $HIDE = 1 ] && { attrib +h "$(cygpath -w "$OUT")" >/dev/null 2>&1 || true; }
echo "✅ $OUT  ($N آلية)"
