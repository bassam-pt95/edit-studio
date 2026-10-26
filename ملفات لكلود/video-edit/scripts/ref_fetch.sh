#!/bin/bash
# ref_fetch.sh <رابط pin.it>  →  يحفظ شبكة إطارات (20 لقطة) باسم g_<المعرّف>.jpg بمجلد refs/ عند المستخدم
case "$OSTYPE" in msys*|cygwin*) [ "$(command -v find)" = /usr/bin/find ] || export PATH="$HOME/bin:/mingw64/bin:/usr/bin:$PATH";; esac   # ويندوز: bash بلا login يبدا PATH بـSystem32: find حق ويندوز (ولو ادوات Git بالـPATH تجي بعدها)، وما فيه ~/bin حق python3؛ فلو find مو /usr/bin/find نحط ~/bin وادوات Git اول مثل login
set -e
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) export PYTHONUTF8=1 PYTHONIOENCODING=utf-8 ;; esac   # ويندوز: بايثون بـUTF-8 لا بترميز النظام
PY=python3   # حساب FPS تحت ينادي $PY
L="$1"; ID="${L##*/}"
# ويندوز: المعرف بلا ?utm_source… وبلا رموز ممنوعة باسم الملف، والا ffmpeg ما يكتب g_<المعرف>.jpg
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) ID="${L%%\?*}"; ID="${ID%/}"; ID="${ID##*/}"; ID="$(printf '%s' "$ID" | tr ':*"<>|\\' '-------')" ;; esac
SK="$(cd "$(dirname "$0")" && pwd)"   # مجلد السكربتات
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) SK="$(cygpath -m "$SK")" ;; esac   # ويندوز: مسارات C:/ للادوات الاصلية، فتشتغل حتى مع MSYS_NO_PATHCONV=1 او MSYS2_ARG_CONV_EXCL='*'
D="$(python3 -c 'import sys;sys.path.insert(0,sys.argv[1]);import _paths;_paths.ensure();print(_paths.data("refs"))' "$SK")"   # refs/ بمجلد بيانات المستخدم
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125 Safari/537.36'
# ويندوز: curl حق Git (Schannel) ورا برنامج حماية يفحص HTTPS او بروكسي يطيح بخطا 35 لو خادم فحص الغاء الشهادة ما ينوصل: --ssl-revoke-best-effort يسمح بهالشي بس،
# و-S مع ملف للخطا: لو طاح نطبع سطر curl والسبب الغالب بدل ما يطلع ساكت. على الماك cu هو curl نفسه بنفس الاوامر
CT=; CE=
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) CT="-S --ssl-revoke-best-effort"; CE="$(mktemp)"; trap 'rm -f "$CE"' EXIT ;; esac
cu(){ if [ -z "$CE" ]; then curl "$@"; else curl $CT "$@" 2>"$CE" || { r=$?; tail -1 "$CE" >&2; grep -qE '\((35|60)\)|revocation|CRYPT_E' "$CE" && echo "السبب غالبا برنامج حماية يفحص HTTPS او بروكسي، مو انقطاع النت" >&2; return $r; }; fi; }
H=$(cu -sL -A "$UA" "$L")
V=$(printf '%s' "$H" | grep -o 'https://v1\.pinimg\.com/videos/[^"'"'"']*_720w\.mp4' | head -1)
[ -z "$V" ] && { echo "ما لقيت فيديو في $L"; exit 1; }
T="$(mktemp -d)/ref.mp4"
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) T="$(cygpath -m "$T")" ;; esac   # ويندوز: curl وffmpeg ادوات اصلية، مثل SK فوق
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) ;; *) trap 'rm -rf "${T%/*}"' EXIT ;; esac   # الماك (مثل الحالي): المجلد المؤقت ينمسح عند الخروج، حتى لو التنزيل طاح
cu -sL -o "$T" "$V"
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$T")
FPS=$($PY -c "print(max(0.2,min(4,20/$DUR)))")
ffmpeg -v error -i "$T" -vf "fps=$FPS,scale=220:-1,tile=5x4" -frames:v 1 -q:v 6 -y "$D/g_$ID.jpg"
rm -f "$T"; echo "حُفظ: $D/g_$ID.jpg  (المدة ${DUR%.*} ث)"
